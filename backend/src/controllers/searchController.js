import Locker from '../models/Locker.js';
import Cell from '../models/Cell.js';
import User from '../models/User.js';
import { NotFoundError, ValidationError } from '../middleware/errorHandler.js';
import logger from '../utils/logger.js';

/**
 * Determina tipo locker da dimensione o campo tipo
 * (Duplicato da lockerController per consistenza)
 */
function determinaTipoLocker(locker) {
  if (locker.tipo) {
    return locker.tipo;
  }
  const dimensioneMapping = {
    small: 'personali',
    medium: 'personali',
    large: 'sportivi',
  };
  return dimensioneMapping[locker.dimensione] || 'personali';
}

/**
 * Formatta locker per frontend
 */
async function formattaLocker(locker, options = {}) {
  const totalCells = await Locker.getTotalCells(locker.lockerId);
  const availableCells = await Locker.getAvailableCells(locker.lockerId);
  const tipo = determinaTipoLocker(locker);
  const availabilityPercentage = totalCells > 0 ? (availableCells / totalCells) * 100 : 0;

  const formatted = {
    id: locker.lockerId,
    name: locker.nome,
    position: {
      lat: locker.coordinate.lat,
      lng: locker.coordinate.lng,
    },
    type: tipo,
    totalCells,
    availableCells,
    isActive: locker.stato === 'attivo',
    description: locker.descrizione || null,
    availabilityPercentage: Math.round(availabilityPercentage * 100) / 100,
    stato: locker.stato,
    dataRipristino: locker.dataRipristino || null,
    online: locker.online !== undefined ? locker.online : true,
  };

  // Aggiungi distanza se presente
  if (options.distance !== undefined) {
    formatted.distance = options.distance; // in metri
    formatted.distanceKm = Math.round((options.distance / 1000) * 100) / 100; // in km con 2 decimali
  }

  // Aggiungi isFavorite se presente
  if (options.isFavorite !== undefined) {
    formatted.isFavorite = options.isFavorite;
  }

  return formatted;
}

/**
 * Calcola distanza tra due coordinate (Haversine formula)
 * Ritorna distanza in metri
 */
function calcolaDistanza(lat1, lng1, lat2, lng2) {
  const R = 6371000; // Raggio Terra in metri
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * GET /api/v1/lockers/search
 * Ricerca testuale locker
 * RF2: Ricerca testuale completa
 */
export async function searchLockers(req, res, next) {
  try {
    const { q } = req.query;

    if (!q || q.trim().length === 0) {
      // Se query vuota, ritorna tutti i locker (come getAllLockers)
      const lockers = await Locker.find({
        stato: { $in: ['attivo', 'manutenzione'] },
      }).lean();

      const lockersFormattati = await Promise.all(
        lockers.map((locker) => formattaLocker(locker))
      );

      return res.json({
        success: true,
        data: {
          lockers: lockersFormattati,
        },
      });
    }

    const searchQuery = q.trim();
    const regex = new RegExp(searchQuery, 'i'); // Case-insensitive

    // Ricerca su nome e descrizione locker
    const lockersByNome = await Locker.find({
      $or: [{ nome: regex }, { descrizione: regex }],
      stato: { $in: ['attivo', 'manutenzione'] },
    }).lean();

    // Ricerca su categoria celle (join con Cell)
    const cellsByCategoria = await Cell.find({
      categoria: regex,
      stato: 'libera', // Solo celle disponibili
    }).distinct('lockerId');

    const lockersByCategoria = await Locker.find({
      lockerId: { $in: cellsByCategoria },
      stato: { $in: ['attivo', 'manutenzione'] },
    }).lean();

    // Combina risultati e rimuovi duplicati
    const allLockers = [...lockersByNome, ...lockersByCategoria];
    const uniqueLockers = Array.from(
      new Map(allLockers.map((l) => [l.lockerId, l])).values()
    );

    // Ordina per rilevanza (match nome > match descrizione > match categoria)
    const lockersOrdinati = uniqueLockers.sort((a, b) => {
      const aNomeMatch = a.nome.toLowerCase().includes(searchQuery.toLowerCase()) ? 3 : 0;
      const aDescMatch = a.descrizione?.toLowerCase().includes(searchQuery.toLowerCase()) ? 2 : 0;
      const aScore = aNomeMatch + aDescMatch;

      const bNomeMatch = b.nome.toLowerCase().includes(searchQuery.toLowerCase()) ? 3 : 0;
      const bDescMatch = b.descrizione?.toLowerCase().includes(searchQuery.toLowerCase()) ? 2 : 0;
      const bScore = bNomeMatch + bDescMatch;

      return bScore - aScore; // Ordine decrescente
    });

    // Formatta risultati
    const lockersFormattati = await Promise.all(
      lockersOrdinati.map((locker) => formattaLocker(locker))
    );

    logger.info(`Ricerca testuale: "${searchQuery}" - ${lockersFormattati.length} risultati`);

    res.json({
      success: true,
      data: {
        lockers: lockersFormattati,
        query: searchQuery,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/lockers/nearby
 * Ricerca locker per distanza
 * RF2: Ricerca per distanza dall'utente
 */
export async function searchNearby(req, res, next) {
  try {
    const lat = parseFloat(req.query.lat);
    const lng = parseFloat(req.query.lng);
    const radius = parseFloat(req.query.radius) || 5000; // Default 5000m

    // Validazione coordinate
    if (isNaN(lat) || isNaN(lng)) {
      throw new ValidationError('Coordinate lat e lng richieste e devono essere numeri validi');
    }

    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      throw new ValidationError('Coordinate fuori range: lat [-90, 90], lng [-180, 180]');
    }

    if (isNaN(radius) || radius <= 0) {
      throw new ValidationError('Radius deve essere un numero positivo');
    }

    // Query geospaziale con MongoDB 2dsphere
    const lockers = await Locker.find({
      coordinate: {
        $near: {
          $geometry: {
            type: 'Point',
            coordinates: [lng, lat], // MongoDB usa [lng, lat]
          },
          $maxDistance: radius,
        },
      },
      stato: { $in: ['attivo', 'manutenzione'] },
    }).lean();

    // Calcola distanza effettiva per ogni locker
    const lockersConDistanza = lockers.map((locker) => {
      const distance = calcolaDistanza(
        lat,
        lng,
        locker.coordinate.lat,
        locker.coordinate.lng
      );
      return { ...locker, distance };
    });

    // Ordina per distanza crescente
    lockersConDistanza.sort((a, b) => a.distance - b.distance);

    // Formatta risultati
    const lockersFormattati = await Promise.all(
      lockersConDistanza.map((locker) => formattaLocker(locker, { distance: locker.distance }))
    );

    logger.info(
      `Ricerca nearby: lat=${lat}, lng=${lng}, radius=${radius}m - ${lockersFormattati.length} risultati`
    );

    res.json({
      success: true,
      data: {
        lockers: lockersFormattati,
        location: { lat, lng },
        radius,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/lockers (esteso con filtri)
 * Filtri combinati per locker
 * RF2: Filtri combinati completi
 */
export async function searchWithFilters(req, res, next) {
  try {
    const {
      type,
      category,
      distance,
      lat,
      lng,
      hours,
      available,
      online,
      maintenance,
      page = 1,
      limit = 50,
    } = req.query;

    // Query base
    let query = {
      stato: { $in: ['attivo', 'manutenzione'] },
    };

    // Filtro tipo
    if (type) {
      const tipiValidi = ['sportivi', 'personali', 'petFriendly', 'commerciali', 'cicloturistici'];
      if (!tipiValidi.includes(type)) {
        throw new ValidationError(`Tipo locker non valido. Valori accettati: ${tipiValidi.join(', ')}`);
      }

      if (type === 'sportivi') {
        query.$or = [{ tipo: 'sportivi' }, { dimensione: 'large' }];
      } else if (type === 'personali') {
        query.$or = [{ tipo: 'personali' }, { dimensione: { $in: ['small', 'medium'] } }];
      } else {
        query.tipo = type;
      }
    }

    // Filtro online
    if (online === 'true') {
      query.online = true;
    } else if (online === 'false') {
      query.online = false;
    }

    // Filtro manutenzione
    if (maintenance === 'false') {
      query.stato = 'attivo'; // Escludi manutenzione
    }

    // Filtro distanza (richiede lat/lng)
    let lockers = [];
    if (distance && lat && lng) {
      const latNum = parseFloat(lat);
      const lngNum = parseFloat(lng);
      const distanceNum = parseFloat(distance);

      if (isNaN(latNum) || isNaN(lngNum) || isNaN(distanceNum) || distanceNum <= 0) {
        throw new ValidationError('Coordinate e distanza devono essere numeri validi');
      }

      // Query geospaziale
      const geoQuery = {
        ...query,
        coordinate: {
          $near: {
            $geometry: {
              type: 'Point',
              coordinates: [lngNum, latNum],
            },
            $maxDistance: distanceNum,
          },
        },
      };

      lockers = await Locker.find(geoQuery).lean();
    } else {
      lockers = await Locker.find(query).lean();
    }

    // Filtro categoria contenuti (join con Cell)
    if (category) {
      const categories = category.split(',').map((c) => c.trim());
      const categoryRegex = new RegExp(categories.join('|'), 'i');

      // Trova locker con celle che hanno categoria match
      const cellsByCategoria = await Cell.find({
        categoria: categoryRegex,
        ...(available === 'true' ? { stato: 'libera' } : {}),
      }).distinct('lockerId');

      // Filtra lockers per quelli con celle categoria match
      lockers = lockers.filter((locker) => cellsByCategoria.includes(locker.lockerId));
    }

    // Filtro available (solo locker con celle disponibili)
    if (available === 'true') {
      const lockersConCelle = await Promise.all(
        lockers.map(async (locker) => {
          const availableCells = await Locker.getAvailableCells(locker.lockerId);
          return { locker, availableCells };
        })
      );

      lockers = lockersConCelle
        .filter((item) => item.availableCells > 0)
        .map((item) => item.locker);
    }

    // Filtro orari (se implementato, altrimenti ignora)
    // TODO: Implementare quando campo orariApertura/chiusura sarà disponibile su Locker
    if (hours) {
      // Validazione formato HH:mm-HH:mm
      const hoursRegex = /^(\d{2}):(\d{2})-(\d{2}):(\d{2})$/;
      if (!hoursRegex.test(hours)) {
        throw new ValidationError('Formato orari non valido. Usa HH:mm-HH:mm (es. 09:00-18:00)');
      }
      // Per ora ignora (non implementato nel modello)
      logger.warn('Filtro orari richiesto ma non ancora implementato nel modello Locker');
    }

    // Paginazione
    const pageNum = parseInt(page, 10) || 1;
    const limitNum = parseInt(limit, 10) || 50;
    const skip = (pageNum - 1) * limitNum;

    const lockersPaginated = lockers.slice(skip, skip + limitNum);

    // Formatta risultati
    const lockersFormattati = await Promise.all(
      lockersPaginated.map((locker) => {
        // Calcola distanza se lat/lng presenti
        let distance = undefined;
        if (lat && lng) {
          const latNum = parseFloat(lat);
          const lngNum = parseFloat(lng);
          if (!isNaN(latNum) && !isNaN(lngNum)) {
            distance = calcolaDistanza(latNum, lngNum, locker.coordinate.lat, locker.coordinate.lng);
          }
        }
        return formattaLocker(locker, { distance });
      })
    );

    logger.info(
      `Filtri combinati: ${lockersFormattati.length} risultati (pagina ${pageNum}, limite ${limitNum})`
    );

    res.json({
      success: true,
      data: {
        lockers: lockersFormattati,
        pagination: {
          page: pageNum,
          limit: limitNum,
          total: lockers.length,
          totalPages: Math.ceil(lockers.length / limitNum),
        },
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/lockers?preferences=...
 * Ricerca con preferenze personali
 * RF2: Preferenze personali
 * RF8: Filtri preferenze utente
 */
export async function searchWithPreferences(req, res, next) {
  try {
    const { preferences: preferencesQuery, lat, lng } = req.query;
    const userId = req.user?.userId; // Da middleware auth (opzionale)

    let userPreferences = [];

    // Carica preferenze da utente autenticato o da query
    if (userId) {
      const user = await User.findOne({ utenteId: userId }).lean();
      if (user && user.preferenze && Array.isArray(user.preferenze) && user.preferenze.length > 0) {
        userPreferences = user.preferenze;
        logger.info(`Preferenze utente ${userId}: ${userPreferences.join(', ')}`);
      }
    }

    // Se non autenticato o preferenze non presenti, usa query
    if (userPreferences.length === 0 && preferencesQuery) {
      userPreferences = preferencesQuery.split(',').map((p) => p.trim());
    }

    // Se nessuna preferenza, ritorna tutti i locker (come getAllLockers)
    if (userPreferences.length === 0) {
      const lockers = await Locker.find({
        stato: { $in: ['attivo', 'manutenzione'] },
      }).lean();

      const lockersFormattati = await Promise.all(
        lockers.map((locker) => formattaLocker(locker))
      );

      return res.json({
        success: true,
        data: {
          lockers: lockersFormattati,
        },
      });
    }

    // Applica filtri preferenze (tipologia)
    const query = {
      stato: { $in: ['attivo', 'manutenzione'] },
      $or: [],
    };

    // Costruisci query per ogni preferenza
    for (const pref of userPreferences) {
      if (pref === 'sportivi') {
        query.$or.push({ tipo: 'sportivi' }, { dimensione: 'large' });
      } else if (pref === 'personali') {
        query.$or.push({ tipo: 'personali' }, { dimensione: { $in: ['small', 'medium'] } });
      } else {
        query.$or.push({ tipo: pref });
      }
    }

    let lockers = await Locker.find(query).lean();

    // Filtro distanza se lat/lng presenti
    if (lat && lng) {
      const latNum = parseFloat(lat);
      const lngNum = parseFloat(lng);

      if (!isNaN(latNum) && !isNaN(lngNum)) {
        // Calcola distanza e ordina per preferenze + distanza
        const lockersConDistanza = lockers.map((locker) => {
          const distance = calcolaDistanza(
            latNum,
            lngNum,
            locker.coordinate.lat,
            locker.coordinate.lng
          );
          return { locker, distance };
        });

        // Ordina: prima per preferenze (match tipo), poi per distanza
        lockersConDistanza.sort((a, b) => {
          const aTipo = determinaTipoLocker(a.locker);
          const bTipo = determinaTipoLocker(b.locker);
          const aMatch = userPreferences.includes(aTipo) ? 0 : 1;
          const bMatch = userPreferences.includes(bTipo) ? 0 : 1;

          if (aMatch !== bMatch) {
            return aMatch - bMatch; // Preferenze prima
          }
          return a.distance - b.distance; // Poi distanza
        });

        lockers = lockersConDistanza.map((item) => item.locker);
      }
    } else {
      // Ordina solo per preferenze (locker preferiti prima)
      lockers.sort((a, b) => {
        const aTipo = determinaTipoLocker(a);
        const bTipo = determinaTipoLocker(b);
        const aMatch = userPreferences.includes(aTipo) ? 0 : 1;
        const bMatch = userPreferences.includes(bTipo) ? 0 : 1;
        return aMatch - bMatch;
      });
    }

    // Formatta risultati
    const lockersFormattati = await Promise.all(
      lockers.map((locker) => {
        const tipo = determinaTipoLocker(locker);
        const isFavorite = userPreferences.includes(tipo);
        let distance = undefined;

        if (lat && lng) {
          const latNum = parseFloat(lat);
          const lngNum = parseFloat(lng);
          if (!isNaN(latNum) && !isNaN(lngNum)) {
            distance = calcolaDistanza(latNum, lngNum, locker.coordinate.lat, locker.coordinate.lng);
          }
        }

        return formattaLocker(locker, { isFavorite, distance });
      })
    );

    logger.info(
      `Ricerca preferenze: ${userPreferences.join(', ')} - ${lockersFormattati.length} risultati`
    );

    res.json({
      success: true,
      data: {
        lockers: lockersFormattati,
        preferences: userPreferences,
      },
    });
  } catch (error) {
    next(error);
  }
}

export default {
  searchLockers,
  searchNearby,
  searchWithFilters,
  searchWithPreferences,
};

