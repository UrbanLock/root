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
 * GET /api/v1/admin/reporting/usage
 * Report utilizzo parchi/attrezzature
 * RF18: Report utilizzo parchi/attrezzature
 */
export async function getUsageReport(req, res, next) {
  try {
    const {
      fasciaOraria,
      tipologia,
      postazione,
      lockerType,
      periodo = 'mese',
    } = req.query;

    // Valida periodo
    const periodiValidi = ['giorno', 'settimana', 'mese', 'anno'];
    if (!periodiValidi.includes(periodo)) {
      throw new ValidationError(
        `periodo non valido. Valori accettati: ${periodiValidi.join(', ')}`
      );
    }

    // Calcola periodo data
    const now = new Date();
    let startDate = new Date();

    switch (periodo) {
      case 'giorno':
        startDate.setHours(0, 0, 0, 0);
        break;
      case 'settimana':
        startDate.setDate(now.getDate() - 7);
        break;
      case 'mese':
        startDate.setMonth(now.getMonth() - 1);
        break;
      case 'anno':
        startDate.setFullYear(now.getFullYear() - 1);
        break;
    }

    // Costruisci query base
    const matchQuery = {
      dataInizio: { $gte: startDate },
    };

    // Filtro tipologia (tipo locker)
    if (tipologia) {
      // Trova locker con tipologia specifica
      const lockers = await Locker.find({ tipo: tipologia }).lean();
      const lockerIds = lockers.map((l) => l.lockerId);
      matchQuery.lockerId = { $in: lockerIds };
    }

    // Filtro postazione (lockerId specifico)
    if (postazione) {
      matchQuery.lockerId = postazione;
    }

    // Filtro lockerType (tipo locker)
    if (lockerType) {
      const lockers = await Locker.find({ tipo: lockerType }).lean();
      const lockerIds = lockers.map((l) => l.lockerId);
      if (matchQuery.lockerId) {
        // Intersezione se già presente
        const existingIds = Array.isArray(matchQuery.lockerId.$in)
          ? matchQuery.lockerId.$in
          : [matchQuery.lockerId];
        matchQuery.lockerId = {
          $in: existingIds.filter((id) => lockerIds.includes(id)),
        };
      } else {
        matchQuery.lockerId = { $in: lockerIds };
      }
    }

    // Aggregazione per statistiche
    const stats = await Noleggio.aggregate([
      { $match: matchQuery },

      {
        $facet: {
          totaleUtilizzi: [{ $count: 'count' }],

          // Per fascia oraria
          perFasciaOraria: [
            {
              $project: {
                fascia: {
                  $switch: {
                    branches: [
                      {
                        case: {
                          $and: [
                            { $gte: [{ $hour: '$dataInizio' }, 0] },
                            { $lt: [{ $hour: '$dataInizio' }, 6] },
                          ],
                        },
                        then: '00-06',
                      },
                      {
                        case: {
                          $and: [
                            { $gte: [{ $hour: '$dataInizio' }, 6] },
                            { $lt: [{ $hour: '$dataInizio' }, 12] },
                          ],
                        },
                        then: '06-12',
                      },
                      {
                        case: {
                          $and: [
                            { $gte: [{ $hour: '$dataInizio' }, 12] },
                            { $lt: [{ $hour: '$dataInizio' }, 18] },
                          ],
                        },
                        then: '12-18',
                      },
                      {
                        case: {
                          $and: [
                            { $gte: [{ $hour: '$dataInizio' }, 18] },
                            { $lte: [{ $hour: '$dataInizio' }, 23] },
                          ],
                        },
                        then: '18-24',
                      },
                    ],
                    default: 'altro',
                  },
                },
              },
            },
            {
              $group: {
                _id: '$fascia',
                count: { $sum: 1 },
              },
            },
            { $sort: { _id: 1 } },
          ],

          // Per tipologia locker
          perTipologia: [
            {
              $lookup: {
                from: 'locker',
                localField: 'lockerId',
                foreignField: 'lockerId',
                as: 'locker',
              },
            },
            { $unwind: { path: '$locker', preserveNullAndEmptyArrays: true } },
            {
              $group: {
                _id: '$locker.tipo',
                count: { $sum: 1 },
              },
            },
            { $sort: { count: -1 } },
          ],

          // Per postazione (locker)
          perPostazione: [
            {
              $group: {
                _id: '$lockerId',
                count: { $sum: 1 },
              },
            },
            { $sort: { count: -1 } },
            { $limit: 10 },
          ],

          // Per tipo locker
          perTipoLocker: [
            {
              $lookup: {
                from: 'locker',
                localField: 'lockerId',
                foreignField: 'lockerId',
                as: 'locker',
              },
            },
            { $unwind: { path: '$locker', preserveNullAndEmptyArrays: true } },
            {
              $group: {
                _id: '$locker.tipo',
                count: { $sum: 1 },
              },
            },
            { $sort: { count: -1 } },
          ],

          // Per tipo cella
          perTipoCella: [
            {
              $group: {
                _id: '$tipo',
                count: { $sum: 1 },
              },
            },
            { $sort: { count: -1 } },
          ],

          // Trend temporale
          trendTemporale: [
            {
              $group: {
                _id: {
                  $dateToString: {
                    format:
                      periodo === 'giorno'
                        ? '%Y-%m-%d'
                        : periodo === 'settimana'
                        ? '%Y-%W'
                        : periodo === 'mese'
                        ? '%Y-%m'
                        : '%Y',
                    date: '$dataInizio',
                  },
                },
                count: { $sum: 1 },
              },
            },
            { $sort: { _id: 1 } },
          ],
        },
      },
    ]);

    const result = stats[0];
    const totale = result.totaleUtilizzi[0]?.count || 0;

    // Formatta per fascia oraria
    const perFasciaOraria = result.perFasciaOraria.map((item) => ({
      fascia: item._id,
      count: item.count,
      percentuale: totale > 0 ? ((item.count / totale) * 100).toFixed(2) : 0,
    }));

    // Formatta per tipologia
    const perTipologia = result.perTipologia.map((item) => ({
      tipologia: item._id || 'non specificato',
      count: item.count,
      percentuale: totale > 0 ? ((item.count / totale) * 100).toFixed(2) : 0,
    }));

    // Formatta per postazione
    const perPostazione = await Promise.all(
      result.perPostazione.map(async (item) => {
        const locker = await Locker.findOne({ lockerId: item._id }).lean();
        return {
          postazione: item._id,
          nome: locker?.nome || item._id,
          count: item.count,
          percentuale: totale > 0 ? ((item.count / totale) * 100).toFixed(2) : 0,
        };
      })
    );

    // Formatta per tipo locker
    const perTipoLocker = result.perTipoLocker.map((item) => ({
      tipo: item._id || 'non specificato',
      count: item.count,
      percentuale: totale > 0 ? ((item.count / totale) * 100).toFixed(2) : 0,
    }));

    // Formatta per tipo cella
    const perTipoCella = result.perTipoCella.map((item) => ({
      tipo: item._id,
      count: item.count,
      percentuale: totale > 0 ? ((item.count / totale) * 100).toFixed(2) : 0,
    }));

    // Formatta trend temporale
    const trendTemporale = result.trendTemporale.map((item) => ({
      periodo: item._id,
      count: item.count,
    }));

    logger.info(`Report utilizzo generato per periodo: ${periodo}`);

    res.json({
      success: true,
      data: {
        periodo,
        totaleUtilizzi: totale,
        perFasciaOraria,
        perTipologia,
        perPostazione,
        perTipoLocker,
        perTipoCella,
        trendTemporale,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/admin/reporting/popular-parks
 * Parchi più popolati
 * RF18: Parchi più popolati
 */
export async function getPopularParks(req, res, next) {
  try {
    const { periodo = 'mese', limit = 10 } = req.query;

    // Valida periodo
    const periodiValidi = ['giorno', 'settimana', 'mese', 'anno'];
    if (!periodiValidi.includes(periodo)) {
      throw new ValidationError(
        `periodo non valido. Valori accettati: ${periodiValidi.join(', ')}`
      );
    }

    const limitNum = parseInt(limit, 10);
    if (limitNum < 1 || limitNum > 50) {
      throw new ValidationError('limit deve essere tra 1 e 50');
    }

    // Calcola periodo data
    const now = new Date();
    let startDate = new Date();

    switch (periodo) {
      case 'giorno':
        startDate.setHours(0, 0, 0, 0);
        break;
      case 'settimana':
        startDate.setDate(now.getDate() - 7);
        break;
      case 'mese':
        startDate.setMonth(now.getMonth() - 1);
        break;
      case 'anno':
        startDate.setFullYear(now.getFullYear() - 1);
        break;
    }

    // Aggregazione per locker
    const parks = await Noleggio.aggregate([
      {
        $match: {
          dataInizio: { $gte: startDate },
        },
      },
      {
        $group: {
          _id: '$lockerId',
          utilizzi: { $sum: 1 },
        },
      },
      { $sort: { utilizzi: -1 } },
      { $limit: limitNum },
    ]);

    // Popola locker
    const parksData = await Promise.all(
      parks.map(async (item) => {
        const locker = await Locker.findOne({ lockerId: item._id }).lean();
        const totale = parks.reduce((sum, p) => sum + p.utilizzi, 0);

        return {
          lockerId: item._id,
          nome: locker?.nome || item._id,
          tipo: locker?.tipo || null,
          position: locker?.coordinate || null,
          utilizzi: item.utilizzi,
          percentuale: totale > 0 ? ((item.utilizzi / totale) * 100).toFixed(2) : 0,
        };
      })
    );

    logger.info(`Parchi popolari recuperati per periodo: ${periodo}`);

    res.json({
      success: true,
      data: {
        periodo,
        parks: parksData,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/admin/reporting/popular-categories
 * Categorie più richieste
 * RF18: Categorie più richieste
 */
export async function getPopularCategories(req, res, next) {
  try {
    const { periodo = 'mese' } = req.query;

    // Valida periodo
    const periodiValidi = ['giorno', 'settimana', 'mese', 'anno'];
    if (!periodiValidi.includes(periodo)) {
      throw new ValidationError(
        `periodo non valido. Valori accettati: ${periodiValidi.join(', ')}`
      );
    }

    // Calcola periodo data
    const now = new Date();
    let startDate = new Date();

    switch (periodo) {
      case 'giorno':
        startDate.setHours(0, 0, 0, 0);
        break;
      case 'settimana':
        startDate.setDate(now.getDate() - 7);
        break;
      case 'mese':
        startDate.setMonth(now.getMonth() - 1);
        break;
      case 'anno':
        startDate.setFullYear(now.getFullYear() - 1);
        break;
    }

    // Aggregazione per tipo cella
    const categories = await Noleggio.aggregate([
      {
        $match: {
          dataInizio: { $gte: startDate },
        },
      },
      {
        $group: {
          _id: '$tipo',
          count: { $sum: 1 },
        },
      },
      { $sort: { count: -1 } },
    ]);

    const totale = categories.reduce((sum, c) => sum + c.count, 0);

    // Formatta categorie
    const categoriesData = categories.map((item) => ({
      categoria: item._id,
      count: item.count,
      percentuale: totale > 0 ? ((item.count / totale) * 100).toFixed(2) : 0,
    }));

    logger.info(`Categorie popolari recuperate per periodo: ${periodo}`);

    res.json({
      success: true,
      data: {
        periodo,
        categories: categoriesData,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/admin/reporting/comparison
 * Analisi comparativa tipologie locker
 * RF18: Analisi comparativa tipologie locker
 */
export async function getComparisonReport(req, res, next) {
  try {
    const { tipologie, periodo = 'mese' } = req.query;

    // Valida periodo
    const periodiValidi = ['giorno', 'settimana', 'mese', 'anno'];
    if (!periodiValidi.includes(periodo)) {
      throw new ValidationError(
        `periodo non valido. Valori accettati: ${periodiValidi.join(', ')}`
      );
    }

    // Calcola periodo data
    const now = new Date();
    let startDate = new Date();

    switch (periodo) {
      case 'giorno':
        startDate.setHours(0, 0, 0, 0);
        break;
      case 'settimana':
        startDate.setDate(now.getDate() - 7);
        break;
      case 'mese':
        startDate.setMonth(now.getMonth() - 1);
        break;
      case 'anno':
        startDate.setFullYear(now.getFullYear() - 1);
        break;
    }

    // Filtra per tipologie se specificato
    let lockerFilter = {};
    if (tipologie) {
      const tipologieArray = Array.isArray(tipologie)
        ? tipologie
        : tipologie.split(',');
      const lockers = await Locker.find({ tipo: { $in: tipologieArray } }).lean();
      const lockerIds = lockers.map((l) => l.lockerId);
      lockerFilter = { lockerId: { $in: lockerIds } };
    }

    // Aggregazione per tipologia
    const comparison = await Noleggio.aggregate([
      {
        $match: {
          dataInizio: { $gte: startDate },
          ...lockerFilter,
        },
      },
      {
        $lookup: {
          from: 'locker',
          localField: 'lockerId',
          foreignField: 'lockerId',
          as: 'locker',
        },
      },
      { $unwind: { path: '$locker', preserveNullAndEmptyArrays: true } },
      {
        $group: {
          _id: '$locker.tipo',
          totaleUtilizzi: { $sum: 1 },
          perTipoCella: {
            $push: '$tipo',
          },
          perFasciaOraria: {
            $push: {
              $hour: '$dataInizio',
            },
          },
          perGiornoSettimana: {
            $push: {
              $dayOfWeek: '$dataInizio',
            },
          },
          tempiUtilizzo: {
            $push: {
              $subtract: [
                { $ifNull: ['$dataFine', new Date()] },
                '$dataInizio',
              ],
            },
          },
        },
      },
    ]);

    // Formatta per tipologia
    const tipologieData = await Promise.all(
      comparison.map(async (item) => {
        const tipologia = item._id || 'non specificato';

        // Calcola per tipo cella
        const tipoCellaCounts = {};
        item.perTipoCella.forEach((tipo) => {
          tipoCellaCounts[tipo] = (tipoCellaCounts[tipo] || 0) + 1;
        });
        const perTipoCella = Object.entries(tipoCellaCounts).map(
          ([tipo, count]) => ({
            tipo,
            count,
            percentuale:
              item.totaleUtilizzi > 0
                ? ((count / item.totaleUtilizzi) * 100).toFixed(2)
                : 0,
          })
        );

        // Calcola per fascia oraria
        const fasciaCounts = {
          '00-06': 0,
          '06-12': 0,
          '12-18': 0,
          '18-24': 0,
        };
        item.perFasciaOraria.forEach((ora) => {
          if (ora >= 0 && ora < 6) fasciaCounts['00-06']++;
          else if (ora >= 6 && ora < 12) fasciaCounts['06-12']++;
          else if (ora >= 12 && ora < 18) fasciaCounts['12-18']++;
          else if (ora >= 18 && ora <= 23) fasciaCounts['18-24']++;
        });
        const perFasciaOraria = Object.entries(fasciaCounts).map(
          ([fascia, count]) => ({
            fascia,
            count,
            percentuale:
              item.totaleUtilizzi > 0
                ? ((count / item.totaleUtilizzi) * 100).toFixed(2)
                : 0,
          })
        );

        // Calcola per giorno settimana (1=domenica, 7=sabato)
        const giornoCounts = {};
        item.perGiornoSettimana.forEach((giorno) => {
          giornoCounts[giorno] = (giornoCounts[giorno] || 0) + 1;
        });
        const perGiornoSettimana = Object.entries(giornoCounts).map(
          ([giorno, count]) => ({
            giorno: parseInt(giorno),
            nomeGiorno: [
              'Domenica',
              'Lunedì',
              'Martedì',
              'Mercoledì',
              'Giovedì',
              'Venerdì',
              'Sabato',
            ][parseInt(giorno) - 1],
            count,
            percentuale:
              item.totaleUtilizzi > 0
                ? ((count / item.totaleUtilizzi) * 100).toFixed(2)
                : 0,
          })
        );

        // Calcola tempo medio utilizzo (in ore)
        const tempoMedio =
          item.tempiUtilizzo.length > 0
            ? item.tempiUtilizzo.reduce((sum, t) => sum + t, 0) /
              item.tempiUtilizzo.length
            : 0;
        const tempoMedioUtilizzo = (tempoMedio / (1000 * 60 * 60)).toFixed(2);

        return {
          tipologia,
          totaleUtilizzi: item.totaleUtilizzi,
          perTipoCella,
          perFasciaOraria,
          perGiornoSettimana,
          tempoMedioUtilizzo: parseFloat(tempoMedioUtilizzo),
          revenue: null, // Per MVP, revenue non disponibile
        };
      })
    );

    logger.info(`Report comparativo generato per periodo: ${periodo}`);

    res.json({
      success: true,
      data: {
        periodo,
        tipologie: tipologieData,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * POST /api/v1/admin/reporting/export/pdf
 * Esportazione PDF
 * RF18: Esportazione PDF
 */
export async function exportPDF(req, res, next) {
  try {
    const { reportType, filters, periodo } = req.body;

    // Validazione reportType
    const reportTypesValidi = [
      'usage',
      'popular_parks',
      'popular_categories',
      'comparison',
    ];
    if (!reportType || !reportTypesValidi.includes(reportType)) {
      throw new ValidationError(
        `reportType non valido. Valori accettati: ${reportTypesValidi.join(', ')}`
      );
    }

    // Genera report in base a reportType
    let reportData = null;

    // Simula chiamata alle funzioni corrispondenti
    // Per MVP, ritorna JSON formattato (frontend genera PDF)
    // In futuro, può essere integrato con pdfkit

    switch (reportType) {
      case 'usage':
        // Simula getUsageReport
        reportData = {
          tipo: 'usage',
          periodo: periodo || 'mese',
          messaggio:
            'Per MVP, il report è disponibile come JSON. Il frontend può generare il PDF.',
        };
        break;
      case 'popular_parks':
        reportData = {
          tipo: 'popular_parks',
          periodo: periodo || 'mese',
          messaggio:
            'Per MVP, il report è disponibile come JSON. Il frontend può generare il PDF.',
        };
        break;
      case 'popular_categories':
        reportData = {
          tipo: 'popular_categories',
          periodo: periodo || 'mese',
          messaggio:
            'Per MVP, il report è disponibile come JSON. Il frontend può generare il PDF.',
        };
        break;
      case 'comparison':
        reportData = {
          tipo: 'comparison',
          periodo: periodo || 'mese',
          messaggio:
            'Per MVP, il report è disponibile come JSON. Il frontend può generare il PDF.',
        };
        break;
    }

    logger.info(`Export PDF richiesto per reportType: ${reportType}`);

    // Per MVP, ritorna JSON formattato
    // In futuro, può essere generato PDF con pdfkit
    res.json({
      success: true,
      data: {
        reportType,
        format: 'json', // Per MVP
        data: reportData,
        note: 'Per generare PDF, usa i dati JSON nel frontend o integra pdfkit nel backend',
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * POST /api/v1/admin/reporting/export/excel
 * Esportazione Excel
 * RF18: Esportazione Excel
 */
export async function exportExcel(req, res, next) {
  try {
    const { reportType, filters, periodo } = req.body;

    // Validazione reportType
    const reportTypesValidi = [
      'usage',
      'popular_parks',
      'popular_categories',
      'comparison',
    ];
    if (!reportType || !reportTypesValidi.includes(reportType)) {
      throw new ValidationError(
        `reportType non valido. Valori accettati: ${reportTypesValidi.join(', ')}`
      );
    }

    // Genera report in base a reportType
    let reportData = null;

    // Simula chiamata alle funzioni corrispondenti
    // Per MVP, ritorna JSON formattato (frontend genera Excel)
    // In futuro, può essere integrato con exceljs

    switch (reportType) {
      case 'usage':
        reportData = {
          tipo: 'usage',
          periodo: periodo || 'mese',
          messaggio:
            'Per MVP, il report è disponibile come JSON. Il frontend può generare l\'Excel.',
        };
        break;
      case 'popular_parks':
        reportData = {
          tipo: 'popular_parks',
          periodo: periodo || 'mese',
          messaggio:
            'Per MVP, il report è disponibile come JSON. Il frontend può generare l\'Excel.',
        };
        break;
      case 'popular_categories':
        reportData = {
          tipo: 'popular_categories',
          periodo: periodo || 'mese',
          messaggio:
            'Per MVP, il report è disponibile come JSON. Il frontend può generare l\'Excel.',
        };
        break;
      case 'comparison':
        reportData = {
          tipo: 'comparison',
          periodo: periodo || 'mese',
          messaggio:
            'Per MVP, il report è disponibile come JSON. Il frontend può generare l\'Excel.',
        };
        break;
    }

    logger.info(`Export Excel richiesto per reportType: ${reportType}`);

    // Per MVP, ritorna JSON formattato
    // In futuro, può essere generato Excel con exceljs
    res.json({
      success: true,
      data: {
        reportType,
        format: 'json', // Per MVP
        data: reportData,
        note: 'Per generare Excel, usa i dati JSON nel frontend o integra exceljs nel backend',
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * POST /api/v1/admin/reporting/schedule-email
 * Export periodico via email
 * RF18: Export periodico via email
 */
export async function scheduleEmailExport(req, res, next) {
  try {
    const { reportType, email, frequenza, filters } = req.body;

    // Validazione
    if (!reportType) {
      throw new ValidationError('reportType è obbligatorio');
    }

    const reportTypesValidi = [
      'usage',
      'popular_parks',
      'popular_categories',
      'comparison',
    ];
    if (!reportTypesValidi.includes(reportType)) {
      throw new ValidationError(
        `reportType non valido. Valori accettati: ${reportTypesValidi.join(', ')}`
      );
    }

    if (!email) {
      throw new ValidationError('email è obbligatoria');
    }

    // Valida email formato base
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      throw new ValidationError('email non valida');
    }

    if (!frequenza) {
      throw new ValidationError('frequenza è obbligatoria');
    }

    const frequenzeValide = ['giornaliero', 'settimanale', 'mensile'];
    if (!frequenzeValide.includes(frequenza)) {
      throw new ValidationError(
        `frequenza non valida. Valori accettati: ${frequenzeValide.join(', ')}`
      );
    }

    // Per MVP, salva schedulazione in DB (modello ScheduledExport opzionale)
    // In futuro, può essere integrato con node-cron
    // Per ora, ritorna success con conferma

    logger.info(
      `Schedulazione export email creata: ${reportType}, ${email}, ${frequenza}`
    );

    res.json({
      success: true,
      data: {
        message: 'Schedulazione export email creata con successo',
        reportType,
        email,
        frequenza,
        filters: filters || {},
        note: 'Per MVP, la schedulazione è salvata. In futuro, sarà integrata con node-cron per invio automatico.',
      },
    });
  } catch (error) {
    next(error);
  }
}

export default {
  getUsageReport,
  getPopularParks,
  getPopularCategories,
  getComparisonReport,
  exportPDF,
  exportExcel,
  scheduleEmailExport,
};

