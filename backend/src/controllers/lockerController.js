import Locker from '../models/Locker.js';
import Cell from '../models/Cell.js';
import { NotFoundError, ValidationError } from '../middleware/errorHandler.js';
import logger from '../utils/logger.js';

/**
 * Tariffe per grandezza cella (modalità guadagno)
 */
const TARIFFE = {
  piccola: { perOra: 0.5, perGiorno: 5 },
  media: { perOra: 1, perGiorno: 10 },
  grande: { perOra: 2, perGiorno: 20 },
  extra_large: { perOra: 3, perGiorno: 30 },
};

/**
 * Mapping grandezza DB → Frontend
 */
const GRANDEZZA_MAPPING = {
  piccola: 'small',
  media: 'medium',
  grande: 'large',
  extra_large: 'extraLarge',
};

/**
 * Mapping tipo DB → Frontend
 */
const TIPO_MAPPING = {
  ordini: 'pickup',
  deposito: 'deposit',
  prestito: 'borrow',
};

/**
 * Determina tipo locker da dimensione o campo tipo
 */
function determinaTipoLocker(locker) {
  // Se campo tipo presente, usalo
  if (locker.tipo) {
    return locker.tipo;
  }

  // Altrimenti mapping da dimensione
  const dimensioneMapping = {
    small: 'personali',
    medium: 'personali',
    large: 'sportivi',
  };

  return dimensioneMapping[locker.dimensione] || 'personali';
}

/**
 * Calcola prezzo da grandezza o campo costo
 */
function calcolaPrezzo(grandezza, costo) {
  // Se campo costo presente e diverso da 0, usalo come base
  if (costo && costo > 0) {
    // Calcola proporzionalmente alla tariffa media
    const tariffaMedia = TARIFFE.media;
    const moltiplicatore = costo / tariffaMedia.perOra;
    return {
      pricePerHour: costo,
      pricePerDay: tariffaMedia.perGiorno * moltiplicatore,
    };
  }

  // Altrimenti usa tariffa standard per grandezza
  const tariffa = TARIFFE[grandezza] || TARIFFE.media;
  return {
    pricePerHour: tariffa.perOra,
    pricePerDay: tariffa.perGiorno,
  };
}

/**
 * Estrai numero cella da cellaId
 * Es. "CEL-001-1" → "Cella 1"
 */
function estraiNumeroCella(cellaId) {
  const match = cellaId.match(/CEL-[\w-]+-(\d+)/);
  if (match) {
    return `Cella ${parseInt(match[1], 10)}`;
  }
  return cellaId; // Fallback
}

/**
 * GET /api/v1/lockers
 * Lista tutti i locker con filtri opzionali
 * RF2: Disponibilità tempo reale, filtri tipologia
 */
export async function getAllLockers(req, res, next) {
  try {
    const { type } = req.query;

    // Filtro stato: mostra attivi e in manutenzione (RF2)
    const statoFilter = { $in: ['attivo', 'manutenzione'] };

    // Query base
    let query = { stato: statoFilter };

    // Filtro tipologia se presente (RF2)
    if (type) {
      const tipiValidi = ['sportivi', 'personali', 'petFriendly', 'commerciali', 'cicloturistici'];
      if (!tipiValidi.includes(type)) {
        throw new ValidationError(`Tipo locker non valido. Valori accettati: ${tipiValidi.join(', ')}`);
      }

      // Se campo tipo presente nel DB, filtra per tipo
      // Altrimenti filtra per dimensione (mapping)
      if (type === 'sportivi') {
        query.$or = [{ tipo: 'sportivi' }, { dimensione: 'large' }];
      } else if (type === 'personali') {
        query.$or = [{ tipo: 'personali' }, { dimensione: { $in: ['small', 'medium'] } }];
      } else {
        query.tipo = type;
      }
    }

    // Trova locker
    const lockers = await Locker.find(query).lean();

    // Calcola disponibilità per ogni locker (tempo reale - RF2)
    const lockersFormattati = await Promise.all(
      lockers.map(async (locker) => {
        const totalCells = await Locker.getTotalCells(locker.lockerId);
        const availableCells = await Locker.getAvailableCells(locker.lockerId);
        const tipo = determinaTipoLocker(locker);
        const availabilityPercentage = totalCells > 0 ? (availableCells / totalCells) * 100 : 0;

        return {
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
          stato: locker.stato, // RF2: Include stato
          dataRipristino: locker.dataRipristino || null, // RF2: Data ripristino se in manutenzione
          online: locker.online !== undefined ? locker.online : true, // RF2: Stato online/offline
        };
      })
    );

    logger.info(`Lista locker: ${lockersFormattati.length} trovati${type ? ` (filtro: ${type})` : ''}`);

    res.json({
      success: true,
      data: {
        lockers: lockersFormattati,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/lockers/:id
 * Dettaglio locker
 */
export async function getLockerById(req, res, next) {
  try {
    const { id } = req.params;

    const locker = await Locker.findOne({ lockerId: id }).lean();

    if (!locker) {
      throw new NotFoundError(`Locker con ID ${id} non trovato`);
    }

    // Calcola disponibilità (tempo reale - RF2)
    const totalCells = await Locker.getTotalCells(locker.lockerId);
    const availableCells = await Locker.getAvailableCells(locker.lockerId);
    const tipo = determinaTipoLocker(locker);
    const availabilityPercentage = totalCells > 0 ? (availableCells / totalCells) * 100 : 0;

    const lockerFormattato = {
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
      dimensione: locker.dimensione,
      dataRipristino: locker.dataRipristino || null,
      online: locker.online !== undefined ? locker.online : true,
      dataCreazione: locker.dataCreazione,
    };

    logger.info(`Dettaglio locker: ${locker.lockerId}`);

    res.json({
      success: true,
      data: {
        locker: lockerFormattato,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/lockers/:id/cells
 * Lista celle di un locker con filtri opzionali
 */
export async function getLockerCells(req, res, next) {
  try {
    const { id } = req.params;
    const { type } = req.query;

    // Verifica che locker esista
    const locker = await Locker.findOne({ lockerId: id });
    if (!locker) {
      throw new NotFoundError(`Locker con ID ${id} non trovato`);
    }

    // Query base
    let query = { lockerId: id };

    // Filtro tipo cella se presente
    if (type) {
      const tipiValidi = ['deposit', 'borrow', 'pickup'];
      if (!tipiValidi.includes(type)) {
        throw new ValidationError(`Tipo cella non valido. Valori accettati: ${tipiValidi.join(', ')}`);
      }

      // Mapping inverso: frontend → DB
      const tipoMapping = {
        deposit: 'deposito',
        borrow: 'prestito',
        pickup: 'ordini',
      };
      query.tipo = tipoMapping[type];
    }

    // Trova celle
    const cells = await Cell.find(query).lean();

    // Formatta celle per frontend
    const cellsFormattate = cells.map((cell) => {
      const prezzo = calcolaPrezzo(cell.grandezza, cell.costo);
      const cellNumber = estraiNumeroCella(cell.cellaId);

      const cellFormattata = {
        id: cell.cellaId,
        cellNumber,
        type: TIPO_MAPPING[cell.tipo] || cell.tipo,
        size: GRANDEZZA_MAPPING[cell.grandezza] || cell.grandezza,
        isAvailable: cell.stato === 'libera',
        stato: cell.stato, // Aggiungi lo stato per il frontend
        pricePerHour: prezzo.pricePerHour,
        pricePerDay: prezzo.pricePerDay,
        grandezza: cell.grandezza,
        richiede_foto: cell.richiede_foto,
        categoria: cell.categoria || null,
        peso: cell.peso,
      };

      // Aggiungi campi opzionali per tipo borrow/pickup
      if (cell.tipo === 'prestito' || cell.tipo === 'ordini') {
        cellFormattata.itemName = cell.categoria || null;
        cellFormattata.itemDescription = cell.categoria || null;
        cellFormattata.itemImageUrl = cell.fotoUrl || null;
      }

      // Campi opzionali per tipo pickup (futuro)
      if (cell.tipo === 'ordini') {
        cellFormattata.storeName = null; // Futuro
        cellFormattata.availableUntil = null; // Futuro
      }

      // Campi opzionali per tipo borrow (futuro)
      if (cell.tipo === 'prestito') {
        cellFormattata.borrowDuration = null; // Futuro
      }

      return cellFormattata;
    });

    logger.info(`Celle locker ${id}: ${cellsFormattate.length} trovate${type ? ` (filtro: ${type})` : ''}`);

    res.json({
      success: true,
      data: {
        cells: cellsFormattate,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/lockers/:id/cells/stats
 * Statistiche celle per locker
 * RF2: Calcolo disponibilità tempo reale
 */
export async function getLockerCellStats(req, res, next) {
  try {
    const { id } = req.params;

    // Verifica che locker esista
    const locker = await Locker.findOne({ lockerId: id });
    if (!locker) {
      throw new NotFoundError(`Locker con ID ${id} non trovato`);
    }

    // Aggrega celle per tipo e stato (tempo reale - RF2)
    const totalCells = await Cell.countDocuments({ lockerId: id });
    const availableBorrowCells = await Cell.countDocuments({
      lockerId: id,
      tipo: 'prestito',
      stato: 'libera',
    });
    const availableDepositCells = await Cell.countDocuments({
      lockerId: id,
      tipo: 'deposito',
      stato: 'libera',
    });
    const availablePickupCells = await Cell.countDocuments({
      lockerId: id,
      tipo: 'ordini',
      stato: 'libera',
    });
    const totalAvailable = await Cell.countDocuments({
      lockerId: id,
      stato: 'libera',
    });

    const stats = {
      totalCells,
      availableBorrowCells,
      availableDepositCells,
      availablePickupCells,
      totalAvailable,
    };

    logger.info(`Statistiche celle locker ${id}`);

    res.json({
      success: true,
      data: {
        stats,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * PUT /api/v1/lockers/:id
 * Aggiorna locker (RF13)
 */
export async function updateLocker(req, res, next) {
  try {
    const { id } = req.params;
    const updateData = req.body;

    logger.info(`Aggiornamento locker ${id}:`, { updateData });

    // Campi che possono essere aggiornati
    const allowedFields = [
      'nome',
      'coordinate',
      'stato',
      'dimensione',
      'tipo',
      'descrizione',
      'dataRipristino',
      'online',
      'operatoreCreatoreId',
    ];

    // Filtra solo i campi consentiti
    const filteredUpdate = {};
    for (const field of allowedFields) {
      if (updateData[field] !== undefined) {
        filteredUpdate[field] = updateData[field];
      }
    }

    logger.info(`Campi filtrati per aggiornamento:`, { filteredUpdate });

    // Se coordinate è un oggetto, mantienilo come oggetto
    if (updateData.coordinate && typeof updateData.coordinate === 'object') {
      filteredUpdate.coordinate = updateData.coordinate;
    }

    // Verifica che ci sia almeno un campo da aggiornare
    if (Object.keys(filteredUpdate).length === 0) {
      throw new ValidationError('Nessun campo valido da aggiornare');
    }

    // Trova e aggiorna il locker
    const locker = await Locker.findOneAndUpdate(
      { lockerId: id },
      { $set: filteredUpdate },
      { new: true, runValidators: true }
    );

    if (!locker) {
      throw new NotFoundError(`Locker con ID ${id} non trovato`);
    }

    logger.info(`Locker ${id} aggiornato con successo: ${Object.keys(filteredUpdate).join(', ')}`);

    // Calcola disponibilità per la risposta
    const totalCells = await Locker.getTotalCells(locker.lockerId);
    const availableCells = await Locker.getAvailableCells(locker.lockerId);
    const tipo = determinaTipoLocker(locker);
    const availabilityPercentage = totalCells > 0 ? (availableCells / totalCells) * 100 : 0;

    const lockerFormattato = {
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
      dimensione: locker.dimensione,
      dataRipristino: locker.dataRipristino || null,
      online: locker.online !== undefined ? locker.online : true,
      dataCreazione: locker.dataCreazione,
    };

    res.json({
      success: true,
      data: {
        locker: lockerFormattato,
      },
    });
  } catch (error) {
    next(error);
  }
}

export default {
  getAllLockers,
  getLockerById,
  getLockerCells,
  getLockerCellStats,
  updateLocker,
};

