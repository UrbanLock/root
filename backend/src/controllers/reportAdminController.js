import Segnalazione from '../models/Segnalazione.js';
import User from '../models/User.js';
import Locker from '../models/Locker.js';
import mongoose from 'mongoose';
import {
  NotFoundError,
  ValidationError,
  UnauthorizedError,
} from '../middleware/errorHandler.js';
import logger from '../utils/logger.js';
import { createNotification } from '../services/notificationService.js';

/**
 * Formatta Segnalazione come AdminReportResponse per frontend admin
 */
async function formatAdminReportResponse(segnalazione) {
  const response = {
    id: segnalazione.segnalazioneId,
    userId: segnalazione.utenteId
      ? segnalazione.utenteId.toString()
      : null,
    userName: null,
    userSurname: null,
    userEmail: null,
    userPhone: null,
    category: segnalazione.categoria,
    description: segnalazione.descrizione,
    photoUrl: segnalazione.fotoUrl || null,
    priority: segnalazione.priorita,
    status: segnalazione.stato,
    createdAt: segnalazione.dataCreazione,
    resolvedAt: segnalazione.dataRisoluzione || null,
    operatorResponse: segnalazione.rispostaOperatore || null,
    operatorNotes: segnalazione.noteOperatore || null,
    lockerId: segnalazione.lockerId || null,
    lockerName: null,
    lockerType: null,
    lockerPosition: null,
    cellaId: segnalazione.cellaId || null,
    assignedOperatorId: segnalazione.operatoreAssegnatoId
      ? segnalazione.operatoreAssegnatoId.toString()
      : null,
    assignedOperatorName: null,
    maintenanceInterventionId: segnalazione.interventoManutenzioneId || null,
  };

  // Popola utente
  if (segnalazione.utenteId) {
    try {
      // Converti a ObjectId se necessario
      const userObjectId = segnalazione.utenteId instanceof mongoose.Types.ObjectId
        ? segnalazione.utenteId
        : new mongoose.Types.ObjectId(segnalazione.utenteId);
      
      const user = await User.findById(userObjectId).lean();
      if (user) {
        response.userName = user.nome;
        response.userSurname = user.cognome;
        response.userEmail = user.email || null;
        response.userPhone = user.telefono || null;
      }
    } catch (error) {
      logger.warn(`Errore popolamento utente per segnalazione: ${error.message}`);
      // Continua senza dati utente
    }
  }

  // Popola locker se presente
  if (segnalazione.lockerId) {
    const locker = await Locker.findOne({ lockerId: segnalazione.lockerId }).lean();
    if (locker) {
      response.lockerName = locker.nome;
      response.lockerType = locker.tipo;
      response.lockerPosition = locker.coordinate || null;
    }
  }

  // Popola operatore se presente
  if (segnalazione.operatoreAssegnatoId) {
    const operatore = await User.findById(
      segnalazione.operatoreAssegnatoId
    ).lean();
    if (operatore) {
      response.assignedOperatorName = `${operatore.nome} ${operatore.cognome}`;
    }
  }

  return response;
}

/**
 * GET /api/v1/admin/reports
 * Lista tutte le segnalazioni
 * RF15: Lista tutte le segnalazioni
 */
export async function getAllReports(req, res, next) {
  try {
    const { page = 1, limit = 20, categoria, stato, priorita, operatoreId } =
      req.query;

    // Valida paginazione
    const pageNum = parseInt(page, 10);
    const limitNum = parseInt(limit, 10);

    if (pageNum < 1) {
      throw new ValidationError('page deve essere >= 1');
    }

    if (limitNum < 1 || limitNum > 100) {
      throw new ValidationError('limit deve essere tra 1 e 100');
    }

    // Costruisci query
    const query = {};

    // Filtro categoria
    if (categoria) {
      const categorieValide = [
        'anomalia',
        'guasto',
        'vandalismo',
        'pulizia',
        'sicurezza',
        'altro',
      ];
      if (!categorieValide.includes(categoria)) {
        throw new ValidationError(
          `categoria non valida. Valori accettati: ${categorieValide.join(', ')}`
        );
      }
      query.categoria = categoria;
    }

    // Filtro stato
    if (stato) {
      const statiValidi = [
        'aperta',
        'in_analisi',
        'assegnata',
        'in_lavorazione',
        'risolta',
        'chiusa',
      ];
      if (!statiValidi.includes(stato)) {
        throw new ValidationError(
          `stato non valido. Valori accettati: ${statiValidi.join(', ')}`
        );
      }
      query.stato = stato;
    }

    // Filtro priorità
    if (priorita) {
      const prioritaValide = ['alta', 'media', 'bassa'];
      if (!prioritaValide.includes(priorita)) {
        throw new ValidationError(
          `priorita non valida. Valori accettati: ${prioritaValide.join(', ')}`
        );
      }
      query.priorita = priorita;
    }

    // Filtro operatoreId
    if (operatoreId) {
      try {
        const operatoreObjectId = new mongoose.Types.ObjectId(operatoreId);
        query.operatoreAssegnatoId = operatoreObjectId;
      } catch (error) {
        throw new ValidationError('operatoreId non valido');
      }
    }

    // Calcola skip
    const skip = (pageNum - 1) * limitNum;

    // Trova segnalazioni con paginazione
    // Ordina per priorità DESC poi dataCreazione DESC (priorità alta prima)
    const segnalazioni = await Segnalazione.find(query)
      .sort({ priorita: -1, dataCreazione: -1 })
      .skip(skip)
      .limit(limitNum)
      .lean();

    // Formatta risposte
    const items = await Promise.all(
      segnalazioni.map((segnalazione) => formatAdminReportResponse(segnalazione))
    );

    // Calcola total per paginazione
    const total = await Segnalazione.countDocuments(query);
    const totalPages = Math.ceil(total / limitNum);

    logger.info(
      `Segnalazioni recuperate (admin): ${items.length} items (page ${pageNum}/${totalPages})`
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
 * GET /api/v1/admin/reports/:id
 * Dettaglio segnalazione
 * RF15: Dettaglio segnalazione
 */
export async function getReportById(req, res, next) {
  try {
    const { id } = req.params;

    // Trova Segnalazione
    const segnalazione = await Segnalazione.findOne({
      segnalazioneId: id,
    }).lean();

    if (!segnalazione) {
      throw new NotFoundError('Segnalazione non trovata');
    }

    // Formatta risposta
    const reportResponse = await formatAdminReportResponse(segnalazione);

    logger.info(`Dettaglio segnalazione ${id} recuperato (admin)`);

    res.json({
      success: true,
      data: {
        report: reportResponse,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * PUT /api/v1/admin/reports/:id/priority
 * Classificazione priorità
 * RF15: Classificazione priorità
 */
export async function updatePriority(req, res, next) {
  try {
    const { id } = req.params;
    const { priorita } = req.body;
    const operatoreId = req.user.userId;

    // Converti operatoreId (stringa) in ObjectId
    const operatoreObjectId = new mongoose.Types.ObjectId(operatoreId);

    // Validazione priorita
    if (!priorita) {
      throw new ValidationError('priorita è obbligatoria');
    }

    const prioritaValide = ['alta', 'media', 'bassa'];
    if (!prioritaValide.includes(priorita)) {
      throw new ValidationError(
        `priorita non valida. Valori accettati: ${prioritaValide.join(', ')}`
      );
    }

    // Trova Segnalazione
    const segnalazione = await Segnalazione.findOne({ segnalazioneId: id });

    if (!segnalazione) {
      throw new NotFoundError('Segnalazione non trovata');
    }

    // Aggiorna priorità e operatore (se non già assegnata)
    segnalazione.priorita = priorita;
    if (!segnalazione.operatoreAssegnatoId) {
      segnalazione.operatoreAssegnatoId = operatoreObjectId;
    }
    segnalazione.dataAggiornamento = new Date();

    await segnalazione.save();

    // Formatta risposta
    const reportResponse = await formatAdminReportResponse(segnalazione);

    logger.info(
      `Priorità segnalazione ${id} aggiornata a ${priorita} da operatore ${operatoreId}`
    );

    res.json({
      success: true,
      data: {
        report: reportResponse,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * PUT /api/v1/admin/reports/:id/assign
 * Assegnare a intervento manutentivo
 * RF15: Assegnare a intervento manutentivo
 */
export async function assignToMaintenance(req, res, next) {
  try {
    const { id } = req.params;
    const { interventoManutenzioneId, noteOperatore } = req.body;
    const operatoreId = req.user.userId;

    // Converti operatoreId (stringa) in ObjectId
    const operatoreObjectId = new mongoose.Types.ObjectId(operatoreId);

    // Validazione interventoManutenzioneId
    if (!interventoManutenzioneId) {
      throw new ValidationError('interventoManutenzioneId è obbligatorio');
    }

    // Valida formato (almeno non vuoto)
    if (typeof interventoManutenzioneId !== 'string' || !interventoManutenzioneId.trim()) {
      throw new ValidationError('interventoManutenzioneId non valido');
    }

    // Trova Segnalazione
    const segnalazione = await Segnalazione.findOne({ segnalazioneId: id });

    if (!segnalazione) {
      throw new NotFoundError('Segnalazione non trovata');
    }

    // Aggiorna intervento e stato
    segnalazione.interventoManutenzioneId = interventoManutenzioneId.trim();
    segnalazione.stato = 'assegnata';
    if (!segnalazione.operatoreAssegnatoId) {
      segnalazione.operatoreAssegnatoId = operatoreObjectId;
    }
    if (noteOperatore) {
      segnalazione.noteOperatore = noteOperatore;
    }
    segnalazione.dataAggiornamento = new Date();

    await segnalazione.save();

    // Formatta risposta
    const reportResponse = await formatAdminReportResponse(segnalazione);

    logger.info(
      `Segnalazione ${id} assegnata a intervento ${interventoManutenzioneId} da operatore ${operatoreId}`
    );

    res.json({
      success: true,
      data: {
        report: reportResponse,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * PUT /api/v1/admin/reports/:id/status
 * Tracciamento stato
 * RF15: Tracciamento stato
 */
export async function updateStatus(req, res, next) {
  try {
    const { id } = req.params;
    const { stato, rispostaOperatore, noteOperatore } = req.body;
    const operatoreId = req.user.userId;

    // Converti operatoreId (stringa) in ObjectId
    const operatoreObjectId = new mongoose.Types.ObjectId(operatoreId);

    // Validazione stato
    if (!stato) {
      throw new ValidationError('stato è obbligatorio');
    }

    const statiValidi = [
      'aperta',
      'in_analisi',
      'assegnata',
      'in_lavorazione',
      'risolta',
      'chiusa',
    ];
    if (!statiValidi.includes(stato)) {
      throw new ValidationError(
        `stato non valido. Valori accettati: ${statiValidi.join(', ')}`
      );
    }

    // Trova Segnalazione
    const segnalazione = await Segnalazione.findOne({ segnalazioneId: id });

    if (!segnalazione) {
      throw new NotFoundError('Segnalazione non trovata');
    }

    // Aggiorna stato e campi correlati
    segnalazione.stato = stato;
    if (!segnalazione.operatoreAssegnatoId) {
      segnalazione.operatoreAssegnatoId = operatoreObjectId;
    }
    segnalazione.dataAggiornamento = new Date();

    // Se stato è "risolta" o "chiusa", imposta dataRisoluzione
    if (stato === 'risolta' || stato === 'chiusa') {
      segnalazione.dataRisoluzione = new Date();
    }

    if (rispostaOperatore !== undefined) {
      segnalazione.rispostaOperatore = rispostaOperatore || null;
    }

    if (noteOperatore !== undefined) {
      segnalazione.noteOperatore = noteOperatore || null;
    }

    await segnalazione.save();

    // Crea notifica per utente se segnalazione risolta/chiusa
    if (stato === 'risolta' || stato === 'chiusa') {
      try {
        const operatore = await User.findById(operatoreId).lean();
        const operatoreName = operatore
          ? `${operatore.nome} ${operatore.cognome}`
          : 'Operatore';

        const titolo = `Segnalazione ${stato === 'risolta' ? 'risolta' : 'chiusa'}`;
        const messaggio = rispostaOperatore
          ? rispostaOperatore
          : `La tua segnalazione "${segnalazione.categoria}" è stata ${stato === 'risolta' ? 'risolta' : 'chiusa'} da ${operatoreName}.`;

        await createNotification(
          segnalazione.utenteId,
          'sistema',
          titolo,
          messaggio,
          {
            segnalazioneId: segnalazione.segnalazioneId,
            stato,
            operatoreId,
          }
        );

        logger.info(
          `Notifica creata per segnalazione ${id} ${stato} per utente ${segnalazione.utenteId}`
        );
      } catch (notificationError) {
        logger.warn(
          `Errore creazione notifica per segnalazione ${id}:`,
          notificationError
        );
        // Non bloccare aggiornamento se notifica fallisce
      }
    }

    // Formatta risposta
    const reportResponse = await formatAdminReportResponse(segnalazione);

    logger.info(
      `Stato segnalazione ${id} aggiornato a ${stato} da operatore ${operatoreId}`
    );

    res.json({
      success: true,
      data: {
        report: reportResponse,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/admin/reports/stats
 * Statistiche segnalazioni
 * RF15: Statistiche segnalazioni
 */
export async function getReportsStats(req, res, next) {
  try {
    const { periodo = 'mese' } = req.query;

    // Valida periodo
    const periodiValidi = ['giorno', 'settimana', 'mese', 'anno'];
    if (!periodiValidi.includes(periodo)) {
      throw new ValidationError(
        `periodo non valido. Valori accettati: ${periodiValidi.join(', ')}`
      );
    }

    // Calcola data inizio periodo
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

    // Query base per periodo
    const periodQuery = {
      dataCreazione: { $gte: startDate },
    };

    // Aggregazione per statistiche
    const stats = await Segnalazione.aggregate([
      // Match periodo
      { $match: periodQuery },

      // Fase 1: Totale segnalazioni
      {
        $facet: {
          totale: [{ $count: 'count' }],

          // Per categoria
          perCategoria: [
            {
              $group: {
                _id: '$categoria',
                count: { $sum: 1 },
              },
            },
            { $sort: { count: -1 } },
          ],

          // Per stato
          perStato: [
            {
              $group: {
                _id: '$stato',
                count: { $sum: 1 },
              },
            },
            { $sort: { count: -1 } },
          ],

          // Per priorità
          perPriorita: [
            {
              $group: {
                _id: '$priorita',
                count: { $sum: 1 },
              },
            },
            { $sort: { count: -1 } },
          ],

          // Per locker (top 5)
          perLocker: [
            {
              $match: { lockerId: { $ne: null } },
            },
            {
              $group: {
                _id: '$lockerId',
                count: { $sum: 1 },
              },
            },
            { $sort: { count: -1 } },
            { $limit: 5 },
          ],

          // Tempo medio risoluzione (solo segnalazioni risolte)
          tempoRisoluzione: [
            {
              $match: {
                dataRisoluzione: { $ne: null },
                dataCreazione: { $ne: null },
              },
            },
            {
              $project: {
                tempoRisoluzione: {
                  $subtract: ['$dataRisoluzione', '$dataCreazione'],
                },
              },
            },
            {
              $group: {
                _id: null,
                media: { $avg: '$tempoRisoluzione' },
                count: { $sum: 1 },
              },
            },
          ],
        },
      },
    ]);

    const result = stats[0];

    // Calcola totale
    const totale = result.totale[0]?.count || 0;

    // Formatta per categoria
    const perCategoria = result.perCategoria.map((item) => ({
      categoria: item._id,
      count: item.count,
      percentuale: totale > 0 ? ((item.count / totale) * 100).toFixed(2) : 0,
    }));

    // Formatta per stato
    const perStato = result.perStato.map((item) => ({
      stato: item._id,
      count: item.count,
      percentuale: totale > 0 ? ((item.count / totale) * 100).toFixed(2) : 0,
    }));

    // Formatta per priorità
    const perPriorita = result.perPriorita.map((item) => ({
      priorita: item._id,
      count: item.count,
      percentuale: totale > 0 ? ((item.count / totale) * 100).toFixed(2) : 0,
    }));

    // Formatta per locker
    const perLocker = result.perLocker.map((item) => ({
      lockerId: item._id,
      count: item.count,
    }));

    // Tempo medio risoluzione (in ore)
    const tempoRisoluzione = result.tempoRisoluzione[0]
      ? {
          mediaOre: (result.tempoRisoluzione[0].media / (1000 * 60 * 60)).toFixed(2),
          count: result.tempoRisoluzione[0].count,
        }
      : { mediaOre: 0, count: 0 };

    // Trend temporale (per giorno/settimana/mese in base a periodo)
    let groupFormat = '%Y-%m-%d'; // Default: per giorno
    if (periodo === 'settimana') {
      groupFormat = '%Y-%W'; // Per settimana
    } else if (periodo === 'mese') {
      groupFormat = '%Y-%m'; // Per mese
    } else if (periodo === 'anno') {
      groupFormat = '%Y'; // Per anno
    }

    const trend = await Segnalazione.aggregate([
      { $match: periodQuery },
      {
        $group: {
          _id: {
            $dateToString: {
              format: groupFormat,
              date: '$dataCreazione',
            },
          },
          count: { $sum: 1 },
        },
      },
      { $sort: { _id: 1 } },
    ]);

    const trendTemporale = trend.map((item) => ({
      periodo: item._id,
      count: item.count,
    }));

    logger.info(`Statistiche segnalazioni calcolate per periodo: ${periodo}`);

    res.json({
      success: true,
      data: {
        periodo,
        totale,
        perCategoria,
        perStato,
        perPriorita,
        perLocker,
        tempoRisoluzione,
        trendTemporale,
      },
    });
  } catch (error) {
    next(error);
  }
}

export default {
  getAllReports,
  getReportById,
  updatePriority,
  assignToMaintenance,
  updateStatus,
  getReportsStats,
};

