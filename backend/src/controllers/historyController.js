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
 * Valida e parsa date
 */
function parseDate(dateString) {
  if (!dateString) return null;
  const date = new Date(dateString);
  if (isNaN(date.getTime())) {
    throw new ValidationError(`Data non valida: ${dateString}`);
  }
  return date;
}

/**
 * GET /api/v1/history
 * Storico completo utilizzo
 * RF9: Tracking completo utilizzo
 */
export async function getHistory(req, res, next) {
  try {
    const userId = req.user.userId;
    const { page = 1, limit = 20, type = 'all', fromDate, toDate } = req.query;

    // Converti userId (stringa) in ObjectId
    const userObjectId = new mongoose.Types.ObjectId(userId);

    // Valida paginazione
    const pageNum = parseInt(page, 10);
    const limitNum = parseInt(limit, 10);

    if (pageNum < 1) {
      throw new ValidationError('page deve essere >= 1');
    }

    if (limitNum < 1 || limitNum > 100) {
      throw new ValidationError('limit deve essere tra 1 e 100');
    }

    // Valida tipo
    const validTypes = ['deposito', 'prestito', 'ordini', 'all'];
    if (!validTypes.includes(type)) {
      throw new ValidationError(
        `tipo non valido. Valori accettati: ${validTypes.join(', ')}`
      );
    }

    // Valida e parsa date
    let fromDateParsed = null;
    let toDateParsed = null;

    if (fromDate) {
      fromDateParsed = parseDate(fromDate);
    }

    if (toDate) {
      toDateParsed = parseDate(toDate);
    }

    if (fromDateParsed && toDateParsed && fromDateParsed > toDateParsed) {
      throw new ValidationError('fromDate deve essere <= toDate');
    }

    // Costruisci query
    const query = {
      utenteId: userObjectId,
    };

    // Filtro tipo
    if (type !== 'all') {
      query.tipo = type;
    }

    // Filtro data
    if (fromDateParsed || toDateParsed) {
      query.dataInizio = {};
      if (fromDateParsed) {
        query.dataInizio.$gte = fromDateParsed;
      }
      if (toDateParsed) {
        query.dataInizio.$lte = toDateParsed;
      }
    }

    // Calcola skip
    const skip = (pageNum - 1) * limitNum;

    // Trova noleggi con paginazione
    const noleggi = await Noleggio.find(query)
      .sort({ dataInizio: -1 })
      .skip(skip)
      .limit(limitNum)
      .lean();

    // Popola locker per ogni noleggio
    const lockerIds = [...new Set(noleggi.map((n) => n.lockerId))];
    const lockers = await Locker.find({ lockerId: { $in: lockerIds } }).lean();
    const lockerMap = new Map(lockers.map((l) => [l.lockerId, l]));

    // Formatta risposte
    const now = new Date();
    const items = noleggi.map((noleggio) => {
      const locker = lockerMap.get(noleggio.lockerId);
      const cellNumber = extractCellNumber(noleggio.cellaId);

      // Calcola durata effettiva
      let duration = 'in corso';
      if (noleggio.dataFine) {
        const durataMs = noleggio.dataFine.getTime() - noleggio.dataInizio.getTime();
        duration = formatDuration(durataMs);
      } else if (noleggio.stato === 'attivo') {
        const durataMs = now.getTime() - noleggio.dataInizio.getTime();
        duration = formatDuration(durataMs) + ' (in corso)';
      }

      return {
        id: noleggio.noleggioId,
        lockerId: noleggio.lockerId,
        lockerName: locker?.nome || null,
        lockerType: locker?.tipo || null,
        lockerPosition: locker?.coordinate || null,
        cellId: noleggio.cellaId,
        cellNumber,
        type: noleggio.tipo,
        status: noleggio.stato,
        startTime: noleggio.dataInizio,
        endTime: noleggio.dataFine || null,
        duration,
        cost: noleggio.costo || 0,
        photoUrl: noleggio.fotoAnomalia || null,
        errorMessage: noleggio.messaggioErrore || null,
      };
    });

    // Calcola total per paginazione
    const total = await Noleggio.countDocuments(query);
    const totalPages = Math.ceil(total / limitNum);

    logger.info(
      `Storico recuperato per utente ${userId}: ${items.length} items (page ${pageNum}/${totalPages})`
    );

    res.json({
      success: true,
      data: {
        items,
        pagination: {
          page: pageNum,
          limit: limitNum,
          total,
          totalPages,
        },
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/history/stats
 * Statistiche storico
 * RF9: Statistiche attrezzature più usate, parchi preferiti, ore di accesso
 */
export async function getHistoryStats(req, res, next) {
  try {
    const userId = req.user.userId;

    // Converti userId (stringa) in ObjectId
    const userObjectId = new mongoose.Types.ObjectId(userId);

    // Totale utilizzi per calcolo percentage
    const totalUtilizzi = await Noleggio.countDocuments({
      utenteId: userObjectId,
    });

    // Attrezzature più usate (categoria celle)
    const attrezzatureAggregation = await Noleggio.aggregate([
      {
        $match: {
          utenteId: userObjectId,
        },
      },
      {
        $lookup: {
          from: 'cella',
          localField: 'cellaId',
          foreignField: 'cellaId',
          as: 'cell',
        },
      },
      {
        $unwind: {
          path: '$cell',
          preserveNullAndEmptyArrays: true,
        },
      },
      {
        $match: {
          'cell.categoria': { $ne: null },
        },
      },
      {
        $group: {
          _id: '$cell.categoria',
          count: { $sum: 1 },
        },
      },
      {
        $sort: { count: -1 },
      },
    ]);

    // Calcola percentage dopo (perché totalUtilizzi è una variabile JavaScript)
    const attrezzaturePiuUsate = attrezzatureAggregation.map((item) => ({
      categoria: item._id,
      count: item.count,
      percentage:
        totalUtilizzi > 0
          ? Math.round((item.count / totalUtilizzi) * 100 * 100) / 100
          : 0,
    }));

    // Parchi preferiti (locker più usati, top 10)
    const parchiAggregation = await Noleggio.aggregate([
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
        $limit: 10,
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

    // Calcola percentage dopo
    const parchiPreferiti = parchiAggregation.map((item) => ({
      lockerId: item.lockerId,
      lockerName: item.lockerName || item.lockerId,
      count: item.count,
      percentage:
        totalUtilizzi > 0
          ? Math.round((item.count / totalUtilizzi) * 100 * 100) / 100
          : 0,
    }));

    // Ore di accesso (distribuzione oraria)
    const oreAccesso = await Noleggio.aggregate([
      {
        $match: {
          utenteId: userObjectId,
        },
      },
      {
        $project: {
          ora: { $hour: '$dataInizio' },
        },
      },
      {
        $group: {
          _id: {
            $switch: {
              branches: [
                { case: { $lt: ['$ora', 6] }, then: '00-06' },
                { case: { $lt: ['$ora', 12] }, then: '06-12' },
                { case: { $lt: ['$ora', 18] }, then: '12-18' },
                { case: { $gte: ['$ora', 18] }, then: '18-24' },
              ],
              default: '18-24',
            },
          },
          count: { $sum: 1 },
        },
      },
    ]);

    // Formatta distribuzione oraria
    const distribuzioneMap = new Map();
    oreAccesso.forEach((item) => {
      distribuzioneMap.set(item._id, item.count);
    });

    const distribuzione = [
      { fascia: '00-06', count: distribuzioneMap.get('00-06') || 0 },
      { fascia: '06-12', count: distribuzioneMap.get('06-12') || 0 },
      { fascia: '12-18', count: distribuzioneMap.get('12-18') || 0 },
      { fascia: '18-24', count: distribuzioneMap.get('18-24') || 0 },
    ];

    // Formatta risposta
    const statsResponse = {
      attrezzaturePiuUsate: attrezzaturePiuUsate.map((item) => ({
        categoria: item.categoria,
        count: item.count,
        percentage: Math.round(item.percentage * 100) / 100,
      })),
      parchiPreferiti: parchiPreferiti.map((item) => ({
        lockerId: item.lockerId,
        lockerName: item.lockerName || item.lockerId,
        count: item.count,
        percentage: Math.round(item.percentage * 100) / 100,
      })),
      oreAccesso: {
        fascia00_06: distribuzioneMap.get('00-06') || 0,
        fascia06_12: distribuzioneMap.get('06-12') || 0,
        fascia12_18: distribuzioneMap.get('12-18') || 0,
        fascia18_24: distribuzioneMap.get('18-24') || 0,
        distribuzione,
      },
    };

    logger.info(`Statistiche storico recuperate per utente ${userId}`);

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
 * GET /api/v1/history/segnalazioni
 * Storico segnalazioni
 * RF8: Storico segnalazioni
 * RF9: Storico segnalazioni
 */
export async function getHistorySegnalazioni(req, res, next) {
  try {
    const userId = req.user.userId;
    const { page = 1, limit = 20 } = req.query;

    // Converti userId (stringa) in ObjectId
    const userObjectId = new mongoose.Types.ObjectId(userId);

    // Valida paginazione
    const pageNum = parseInt(page, 10);
    const limitNum = parseInt(limit, 10);

    if (pageNum < 1) {
      throw new ValidationError('page deve essere >= 1');
    }

    if (limitNum < 1 || limitNum > 100) {
      throw new ValidationError('limit deve essere tra 1 e 100');
    }

    // Trova Noleggio con fotoAnomalia o messaggioErrore (fallback se modello Segnalazione non esiste)
    const query = {
      utenteId: userObjectId,
      $or: [
        { fotoAnomalia: { $ne: null } },
        { messaggioErrore: { $ne: null } },
      ],
    };

    const skip = (pageNum - 1) * limitNum;

    const noleggi = await Noleggio.find(query)
      .sort({ dataCreazione: -1 })
      .skip(skip)
      .limit(limitNum)
      .lean();

    // Formatta come SegnalazioneResponse
    const items = noleggi.map((noleggio) => {
      return {
        id: noleggio.noleggioId,
        lockerId: noleggio.lockerId,
        cellId: noleggio.cellaId,
        type: 'anomalia', // Default type
        description: noleggio.messaggioErrore || 'Anomalia rilevata',
        photoUrl: noleggio.fotoAnomalia || null,
        status: 'aperta', // Default status
        createdAt: noleggio.dataCreazione,
        resolvedAt: null,
      };
    });

    // Calcola total
    const total = await Noleggio.countDocuments(query);
    const totalPages = Math.ceil(total / limitNum);

    logger.info(
      `Storico segnalazioni recuperato per utente ${userId}: ${items.length} items`
    );

    res.json({
      success: true,
      data: {
        items,
        pagination: {
          page: pageNum,
          limit: limitNum,
          total,
          totalPages,
        },
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/history/postazioni
 * Storico postazioni usate
 * RF8: Storico postazioni usate
 * RF9: Storico postazioni
 */
export async function getHistoryPostazioni(req, res, next) {
  try {
    const userId = req.user.userId;
    const { page = 1, limit = 20 } = req.query;

    // Converti userId (stringa) in ObjectId
    const userObjectId = new mongoose.Types.ObjectId(userId);

    // Valida paginazione
    const pageNum = parseInt(page, 10);
    const limitNum = parseInt(limit, 10);

    if (pageNum < 1) {
      throw new ValidationError('page deve essere >= 1');
    }

    if (limitNum < 1 || limitNum > 100) {
      throw new ValidationError('limit deve essere tra 1 e 100');
    }

    // Aggregation per raggruppare per lockerId
    const aggregation = await Noleggio.aggregate([
      {
        $match: {
          utenteId: userObjectId,
        },
      },
      {
        $group: {
          _id: '$lockerId',
          totaleUtilizzi: { $sum: 1 },
          primaDataUtilizzo: { $min: '$dataInizio' },
          ultimaDataUtilizzo: { $max: '$dataInizio' },
          tipiUtilizzo: { $push: '$tipo' },
          durateUtilizzo: {
            $push: {
              $cond: [
                { $ne: ['$dataFine', null] },
                { $subtract: ['$dataFine', '$dataInizio'] },
                null,
              ],
            },
          },
        },
      },
      {
        $sort: { ultimaDataUtilizzo: -1 },
      },
    ]);

    // Popola locker per ogni gruppo
    const lockerIds = aggregation.map((item) => item._id);
    const lockers = await Locker.find({ lockerId: { $in: lockerIds } }).lean();
    const lockerMap = new Map(lockers.map((l) => [l.lockerId, l]));

    // Calcola tipo più frequente e durata media per ogni gruppo
    const postazioni = aggregation.map((item) => {
      const locker = lockerMap.get(item._id);

      // Calcola tipo più frequente (mode)
      const tipoCounts = {};
      item.tipiUtilizzo.forEach((tipo) => {
        tipoCounts[tipo] = (tipoCounts[tipo] || 0) + 1;
      });
      const tipoPiuFrequente = Object.keys(tipoCounts).reduce((a, b) =>
        tipoCounts[a] > tipoCounts[b] ? a : b
      );

      // Calcola durata media (ignora null)
      const durateValide = item.durateUtilizzo.filter((d) => d !== null);
      const durataMediaMs =
        durateValide.length > 0
          ? durateValide.reduce((sum, d) => sum + d, 0) / durateValide.length
          : 0;
      const durataMediaOre = Math.round((durataMediaMs / 3600000) * 100) / 100;

      return {
        lockerId: item._id,
        lockerName: locker?.nome || null,
        lockerType: locker?.tipo || null,
        lockerPosition: locker?.coordinate || null,
        totaleUtilizzi: item.totaleUtilizzi,
        primaDataUtilizzo: item.primaDataUtilizzo,
        ultimaDataUtilizzo: item.ultimaDataUtilizzo,
        tipoPiuFrequente,
        durataMediaUtilizzo: durataMediaOre,
      };
    });

    // Applica paginazione
    const skip = (pageNum - 1) * limitNum;
    const paginatedPostazioni = postazioni.slice(skip, skip + limitNum);
    const total = postazioni.length;
    const totalPages = Math.ceil(total / limitNum);

    logger.info(
      `Storico postazioni recuperato per utente ${userId}: ${paginatedPostazioni.length} postazioni`
    );

    res.json({
      success: true,
      data: {
        postazioni: paginatedPostazioni,
        pagination: {
          page: pageNum,
          limit: limitNum,
          total,
          totalPages,
        },
      },
    });
  } catch (error) {
    next(error);
  }
}

export default {
  getHistory,
  getHistoryStats,
  getHistorySegnalazioni,
  getHistoryPostazioni,
};

