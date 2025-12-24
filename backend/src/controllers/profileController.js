import User from '../models/User.js';
import Noleggio from '../models/Noleggio.js';
import Locker from '../models/Locker.js';
import Cell from '../models/Cell.js';
import mongoose from 'mongoose';
import {
  NotFoundError,
  ValidationError,
  UnauthorizedError,
} from '../middleware/errorHandler.js';
import logger from '../utils/logger.js';

/**
 * Estrai numero cella da cellaId
 */
function extractCellNumber(cellaId) {
  const match = cellaId.match(/CEL-[\w-]+-(\d+)/);
  if (match) {
    return `Cella ${parseInt(match[1], 10)}`;
  }
  return cellaId;
}

/**
 * Formatta durata in formato leggibile
 */
function formatDuration(milliseconds) {
  if (!milliseconds || milliseconds <= 0) {
    return '0h';
  }

  const hours = Math.floor(milliseconds / 3600000);
  const days = Math.floor(hours / 24);

  if (days > 0) {
    return `${days}d`;
  } else if (hours > 0) {
    return `${hours}h`;
  } else {
    const minutes = Math.floor(milliseconds / 60000);
    return `${minutes}m`;
  }
}

/**
 * GET /api/v1/profile
 * Profilo utente completo
 * RF8: Visualizzazione tutte le iterazioni
 */
export async function getProfile(req, res, next) {
  try {
    const userId = req.user.userId;

    // Converti userId (stringa) in ObjectId
    const userObjectId = new mongoose.Types.ObjectId(userId);

    // Trova User completo
    const user = await User.findById(userObjectId);
    if (!user) {
      throw new NotFoundError('Utente non trovato');
    }

    // Calcola statistiche base
    const totaleUtilizzi = await Noleggio.countDocuments({
      utenteId: userObjectId,
      stato: { $in: ['attivo', 'terminato'] },
    });

    const totalSpeso = await Noleggio.aggregate([
      {
        $match: {
          utenteId: userObjectId,
          tipo: 'deposito',
        },
      },
      {
        $group: {
          _id: null,
          total: { $sum: '$costo' },
        },
      },
    ]);

    const totaleSpeso = totalSpeso.length > 0 ? totalSpeso[0].total : 0;

    // Locker più usati (top 3)
    const lockerPiuUsati = await Noleggio.aggregate([
      {
        $match: {
          utenteId: userObjectId,
        },
      },
      {
        $group: {
          _id: '$lockerId',
          count: { $sum: 1 },
        },
      },
      {
        $sort: { count: -1 },
      },
      {
        $limit: 3,
      },
      {
        $lookup: {
          from: 'locker',
          localField: '_id',
          foreignField: 'lockerId',
          as: 'locker',
        },
      },
      {
        $unwind: {
          path: '$locker',
          preserveNullAndEmptyArrays: true,
        },
      },
      {
        $project: {
          lockerId: '$_id',
          lockerName: '$locker.nome',
          count: 1,
        },
      },
    ]);

    // Tempo totale utilizzo (solo noleggi terminati)
    const tempoTotaleUtilizzo = await Noleggio.aggregate([
      {
        $match: {
          utenteId: userObjectId,
          stato: 'terminato',
          dataFine: { $ne: null },
        },
      },
      {
        $project: {
          durata: {
            $subtract: ['$dataFine', '$dataInizio'],
          },
        },
      },
      {
        $group: {
          _id: null,
          totalMs: { $sum: '$durata' },
        },
      },
    ]);

    const tempoTotaleOre =
      tempoTotaleUtilizzo.length > 0
        ? Math.round((tempoTotaleUtilizzo[0].totalMs / 3600000) * 100) / 100
        : 0;

    // Conta per tipo
    const totaleDepositi = await Noleggio.countDocuments({
      utenteId: userObjectId,
      tipo: 'deposito',
    });

    const totalePrestiti = await Noleggio.countDocuments({
      utenteId: userObjectId,
      tipo: 'prestito',
    });

    const totaleOrdini = await Noleggio.countDocuments({
      utenteId: userObjectId,
      tipo: 'ordini',
    });

    // Formatta risposta
    const profileResponse = {
      utenteId: user.utenteId,
      nome: user.nome,
      cognome: user.cognome,
      email: user.email || null,
      telefono: user.telefono || null,
      dataRegistrazione: user.dataRegistrazione,
      ultimoAccesso: user.ultimoAccesso,
      ruolo: user.ruolo,
      preferenze: user.preferenze || [],
      statistiche: {
        totaleUtilizzi,
        totaleSpeso,
        lockerPiuUsati: lockerPiuUsati.map((l) => ({
          lockerId: l.lockerId,
          lockerName: l.lockerName || l.lockerId,
          count: l.count,
        })),
        tempoTotaleUtilizzo: tempoTotaleOre,
        totaleDepositi,
        totalePrestiti,
        totaleOrdini,
      },
    };

    logger.info(`Profilo recuperato per utente ${userId}`);

    res.json({
      success: true,
      data: {
        profile: profileResponse,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/profile/stats
 * Statistiche dettagliate utente
 * RF8: Statistiche utente
 */
export async function getProfileStats(req, res, next) {
  try {
    const userId = req.user.userId;

    // Converti userId (stringa) in ObjectId
    const userObjectId = new mongoose.Types.ObjectId(userId);

    // Totale utilizzi per tipo
    const utilizziPerTipo = await Noleggio.aggregate([
      {
        $match: {
          utenteId: userObjectId,
        },
      },
      {
        $group: {
          _id: '$tipo',
          count: { $sum: 1 },
        },
      },
    ]);

    const totaleUtilizzi = utilizziPerTipo.reduce(
      (sum, item) => sum + item.count,
      0
    );

    const totaleDepositi =
      utilizziPerTipo.find((item) => item._id === 'deposito')?.count || 0;
    const totalePrestiti =
      utilizziPerTipo.find((item) => item._id === 'prestito')?.count || 0;
    const totaleOrdini =
      utilizziPerTipo.find((item) => item._id === 'ordini')?.count || 0;

    // Totale speso (solo depositi)
    const totalSpeso = await Noleggio.aggregate([
      {
        $match: {
          utenteId: userObjectId,
          tipo: 'deposito',
        },
      },
      {
        $group: {
          _id: null,
          total: { $sum: '$costo' },
        },
      },
    ]);

    const totaleSpeso = totalSpeso.length > 0 ? totalSpeso[0].total : 0;

    // Locker più usati (top 5)
    const lockerPiuUsati = await Noleggio.aggregate([
      {
        $match: {
          utenteId: userObjectId,
        },
      },
      {
        $group: {
          _id: '$lockerId',
          count: { $sum: 1 },
        },
      },
      {
        $sort: { count: -1 },
      },
      {
        $limit: 5,
      },
      {
        $lookup: {
          from: 'locker',
          localField: '_id',
          foreignField: 'lockerId',
          as: 'locker',
        },
      },
      {
        $unwind: {
          path: '$locker',
          preserveNullAndEmptyArrays: true,
        },
      },
      {
        $project: {
          lockerId: '$_id',
          lockerName: '$locker.nome',
          count: 1,
        },
      },
    ]);

    // Tempo totale utilizzo (solo noleggi terminati)
    const tempoTotaleUtilizzo = await Noleggio.aggregate([
      {
        $match: {
          utenteId: userObjectId,
          stato: 'terminato',
          dataFine: { $ne: null },
        },
      },
      {
        $project: {
          durata: {
            $subtract: ['$dataFine', '$dataInizio'],
          },
        },
      },
      {
        $group: {
          _id: null,
          totalMs: { $sum: '$durata' },
        },
      },
    ]);

    const tempoTotaleOre =
      tempoTotaleUtilizzo.length > 0
        ? Math.round((tempoTotaleUtilizzo[0].totalMs / 3600000) * 100) / 100
        : 0;

    // Media durata utilizzo
    const mediaDurataUtilizzo = await Noleggio.aggregate([
      {
        $match: {
          utenteId: userObjectId,
          stato: 'terminato',
          dataFine: { $ne: null },
        },
      },
      {
        $project: {
          durata: {
            $subtract: ['$dataFine', '$dataInizio'],
          },
        },
      },
      {
        $group: {
          _id: null,
          avgMs: { $avg: '$durata' },
          count: { $sum: 1 },
        },
      },
    ]);

    const mediaDurataOre =
      mediaDurataUtilizzo.length > 0 && mediaDurataUtilizzo[0].count > 0
        ? Math.round((mediaDurataUtilizzo[0].avgMs / 3600000) * 100) / 100
        : 0;

    // Periodo più attivo (mese con più utilizzi)
    const periodoPiuAttivo = await Noleggio.aggregate([
      {
        $match: {
          utenteId: userObjectId,
        },
      },
      {
        $group: {
          _id: {
            mese: { $month: '$dataInizio' },
            anno: { $year: '$dataInizio' },
          },
          count: { $sum: 1 },
        },
      },
      {
        $sort: { count: -1 },
      },
      {
        $limit: 1,
      },
      {
        $project: {
          mese: '$_id.mese',
          anno: '$_id.anno',
          count: 1,
        },
      },
    ]);

    const periodo =
      periodoPiuAttivo.length > 0
        ? {
            mese: periodoPiuAttivo[0].mese,
            anno: periodoPiuAttivo[0].anno,
            count: periodoPiuAttivo[0].count,
          }
        : null;

    // Formatta risposta
    const statsResponse = {
      totaleUtilizzi,
      totaleSpeso,
      lockerPiuUsati: lockerPiuUsati.map((l) => ({
        lockerId: l.lockerId,
        lockerName: l.lockerName || l.lockerId,
        count: l.count,
      })),
      tempoTotaleUtilizzo: tempoTotaleOre,
      totaleDepositi,
      totalePrestiti,
      totaleOrdini,
      mediaDurataUtilizzo: mediaDurataOre,
      periodoPiuAttivo: periodo,
    };

    logger.info(`Statistiche profilo recuperate per utente ${userId}`);

    res.json({
      success: true,
      data: {
        stats: statsResponse,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * PUT /api/v1/profile/preferences
 * Aggiorna preferenze utente
 * RF8: Gestione preferenze
 */
export async function updatePreferences(req, res, next) {
  try {
    const userId = req.user.userId;
    const { preferenze } = req.body;

    // Converti userId (stringa) in ObjectId
    const userObjectId = new mongoose.Types.ObjectId(userId);

    // Valida preferenze
    if (!Array.isArray(preferenze)) {
      throw new ValidationError('preferenze deve essere un array');
    }

    // Valida enum
    const validPreferences = [
      'sportivi',
      'personali',
      'petFriendly',
      'commerciali',
      'cicloturistici',
    ];

    const invalidPreferences = preferenze.filter(
      (p) => !validPreferences.includes(p)
    );

    if (invalidPreferences.length > 0) {
      throw new ValidationError(
        `Preferenze invalide: ${invalidPreferences.join(', ')}. Valori accettati: ${validPreferences.join(', ')}`
      );
    }

    // Aggiorna User
    const user = await User.findById(userObjectId);
    if (!user) {
      throw new NotFoundError('Utente non trovato');
    }

    user.preferenze = preferenze;
    await user.save();

    logger.info(
      `Preferenze aggiornate per utente ${userId}: ${preferenze.join(', ')}`
    );

    res.json({
      success: true,
      data: {
        preferenze: user.preferenze,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/profile/favorites
 * Lista preferiti con disponibilità tempo reale
 * RF8: Preferiti con disponibilità tempo reale
 */
export async function getFavorites(req, res, next) {
  try {
    const userId = req.user.userId;

    // Converti userId (stringa) in ObjectId
    const userObjectId = new mongoose.Types.ObjectId(userId);

    // Carica User con preferenze
    const user = await User.findById(userObjectId);
    if (!user) {
      throw new NotFoundError('Utente non trovato');
    }

    const preferenze = user.preferenze || [];

    // Se preferenze vuoto, ritorna array vuoto
    if (preferenze.length === 0) {
      res.json({
        success: true,
        data: {
          favorites: [],
        },
      });
      return;
    }

    // Per ogni preferenza trova locker corrispondenti
    const lockers = await Locker.find({
      tipo: { $in: preferenze },
      stato: 'attivo',
    }).lean();

    // Calcola disponibilità per ogni locker in parallelo
    const favoritesPromises = lockers.map(async (locker) => {
      // Calcola totalCells e availableCells
      const totalCells = await Cell.countDocuments({
        lockerId: locker.lockerId,
      });

      const availableCells = await Cell.countDocuments({
        lockerId: locker.lockerId,
        stato: 'libera',
      });

      // Calcola percentage
      const percentage =
        totalCells > 0
          ? Math.round((availableCells / totalCells) * 100 * 100) / 100
          : 0;

      // Trova ultimo utilizzo
      const ultimoUtilizzo = await Noleggio.findOne({
        utenteId: userObjectId,
        lockerId: locker.lockerId,
      })
        .sort({ dataInizio: -1 })
        .lean();

      return {
        lockerId: locker.lockerId,
        lockerName: locker.nome,
        lockerType: locker.tipo,
        lockerPosition: locker.coordinate || null,
        disponibilità: {
          totalCells,
          availableCells,
          percentage,
        },
        isFavorite: true,
        lastUsed: ultimoUtilizzo?.dataInizio || null,
      };
    });

    const favorites = await Promise.all(favoritesPromises);

    // Ordina per disponibilità percentage DESC, poi per ultimo utilizzo DESC
    favorites.sort((a, b) => {
      if (a.disponibilità.percentage !== b.disponibilità.percentage) {
        return b.disponibilità.percentage - a.disponibilità.percentage;
      }
      if (a.lastUsed && b.lastUsed) {
        return new Date(b.lastUsed) - new Date(a.lastUsed);
      }
      if (a.lastUsed) return -1;
      if (b.lastUsed) return 1;
      return 0;
    });

    logger.info(
      `Preferiti recuperati per utente ${userId}: ${favorites.length} locker`
    );

    res.json({
      success: true,
      data: {
        favorites,
      },
    });
  } catch (error) {
    next(error);
  }
}

export default {
  getProfile,
  getProfileStats,
  updatePreferences,
  getFavorites,
};

