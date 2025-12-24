import User from '../models/User.js';
import Locker from '../models/Locker.js';
import Cell from '../models/Cell.js';
import Segnalazione from '../models/Segnalazione.js';
import Donazione from '../models/Donazione.js';
import Allarme from '../models/Allarme.js';
import Noleggio from '../models/Noleggio.js';
import AuditOperatore from '../models/AuditOperatore.js';
import mongoose from 'mongoose';
import {
  NotFoundError,
  ValidationError,
  UnauthorizedError,
} from '../middleware/errorHandler.js';
import logger from '../utils/logger.js';
import { generateTokens } from '../services/authService.js';
import { getAllDonations } from './donationAdminController.js';
import { getAllReports } from './reportAdminController.js';

/**
 * POST /api/v1/admin/login
 * Login operatore
 * RF13: Login operatore
 */
export async function adminLogin(req, res, next) {
  try {
    const { codiceFiscale, password, tipoAutenticazione = 'spid' } = req.body;

    if (!codiceFiscale) {
      throw new ValidationError('codiceFiscale è obbligatorio');
    }

    // Cerca User con codiceFiscale e ruolo operatore o admin
    const user = await User.findOne({
      codiceFiscale: codiceFiscale.toUpperCase(),
    });

    if (!user) {
      throw new UnauthorizedError('Operatore non trovato');
    }

    // Verifica ruolo
    if (user.ruolo !== 'operatore' && user.ruolo !== 'admin') {
      throw new UnauthorizedError(
        'Accesso negato: richiesto ruolo operatore o admin'
      );
    }

    // Verifica che utente sia attivo
    if (!user.attivo) {
      throw new UnauthorizedError('Account disattivato');
    }

    // Genera tokens
    const tokens = generateTokens(user);

    // Aggiorna ultimo accesso
    user.ultimoAccesso = new Date();
    await user.save();

    // Crea audit per login
    try {
      const auditId = await AuditOperatore.generateAuditId();
      await AuditOperatore.create({
        auditId,
        operatoreId: user._id,
        azione: 'login',
        entita: 'sistema',
        timestamp: new Date(),
        ipAddress: req.ip,
        userAgent: req.get('user-agent'),
      });
    } catch (auditError) {
      logger.warn('Errore creazione audit login:', auditError);
      // Non bloccare login se audit fallisce
    }

    logger.info(`Login operatore: ${user.utenteId} (${user.nome} ${user.cognome})`);

    res.json({
      success: true,
      data: {
        user: {
          userId: user._id.toString(),
          utenteId: user.utenteId,
          nome: user.nome,
          cognome: user.cognome,
          ruolo: user.ruolo,
        },
        tokens: {
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
          expiresIn: process.env.JWT_ACCESS_EXPIRES_IN || '1h',
        },
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/admin/dashboard
 * Dashboard operatore
 * RF13: Dashboard operatore
 */
export async function getDashboard(req, res, next) {
  try {
    const operatoreId = req.user.userId;

    // Converti operatoreId (stringa) in ObjectId
    const operatoreObjectId = new mongoose.Types.ObjectId(operatoreId);

    // Calcola statistiche dashboard
    const [
      totaleLocker,
      totaleCelle,
      segnalazioniAperte,
      donazioniInAttesa,
      allarmiAttivi,
      interventiInCorso,
      utilizzoUltimi7Giorni,
      lockerPiuUtilizzati,
    ] = await Promise.all([
      // Totale locker (attivi/inattivi)
      Locker.aggregate([
        {
          $group: {
            _id: '$stato',
            count: { $sum: 1 },
          },
        },
      ]),

      // Totale celle (disponibili/occupate)
      Cell.aggregate([
        {
          $facet: {
            disponibili: [
              { $match: { disponibile: true } },
              { $count: 'count' },
            ],
            occupate: [
              { $match: { disponibile: false } },
              { $count: 'count' },
            ],
          },
        },
      ]),

      // Segnalazioni aperte (per priorità)
      Segnalazione.aggregate([
        {
          $match: { stato: { $in: ['aperta', 'in_analisi', 'assegnata'] } },
        },
        {
          $group: {
            _id: '$priorita',
            count: { $sum: 1 },
          },
        },
      ]),

      // Donazioni in attesa
      Donazione.countDocuments({
        stato: { $in: ['da_visionare', 'in_valutazione'] },
      }),

      // Allarmi attivi (per severità)
      Allarme.aggregate([
        {
          $match: { stato: 'attivo' },
        },
        {
          $group: {
            _id: '$severita',
            count: { $sum: 1 },
          },
        },
      ]),

      // Interventi manutenzione in corso
      Segnalazione.countDocuments({
        interventoManutenzioneId: { $ne: null },
        stato: { $in: ['assegnata', 'in_lavorazione'] },
      }),

      // Utilizzo ultimi 7 giorni
      Noleggio.aggregate([
        {
          $match: {
            dataInizio: {
              $gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000),
            },
          },
        },
        {
          $group: {
            _id: {
              $dateToString: { format: '%Y-%m-%d', date: '$dataInizio' },
            },
            count: { $sum: 1 },
          },
        },
        { $sort: { _id: 1 } },
      ]),

      // Locker più utilizzati (top 5)
      Noleggio.aggregate([
        {
          $match: {
            dataInizio: {
              $gte: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000),
            },
          },
        },
        {
          $group: {
            _id: '$lockerId',
            utilizzi: { $sum: 1 },
          },
        },
        { $sort: { utilizzi: -1 } },
        { $limit: 5 },
      ]),
    ]);

    // Formatta totale locker
    const lockerStats = {
      attivi: 0,
      inattivi: 0,
    };
    totaleLocker.forEach((item) => {
      if (item._id === 'attivo') {
        lockerStats.attivi = item.count;
      } else {
        lockerStats.inattivi += item.count;
      }
    });

    // Formatta totale celle
    const celleStats = {
      disponibili:
        totaleCelle[0]?.disponibili[0]?.count || 0,
      occupate: totaleCelle[0]?.occupate[0]?.count || 0,
    };

    // Formatta segnalazioni aperte
    const segnalazioniStats = {
      alta: 0,
      media: 0,
      bassa: 0,
    };
    segnalazioniAperte.forEach((item) => {
      segnalazioniStats[item._id] = item.count;
    });

    // Formatta allarmi attivi
    const allarmiStats = {
      critica: 0,
      alta: 0,
      media: 0,
      bassa: 0,
    };
    allarmiAttivi.forEach((item) => {
      allarmiStats[item._id] = item.count;
    });

    // Formatta utilizzo ultimi 7 giorni
    const utilizzo7Giorni = utilizzoUltimi7Giorni.map((item) => ({
      data: item._id,
      count: item.count,
    }));

    // Popola locker più utilizzati
    const lockerUtilizzati = await Promise.all(
      lockerPiuUtilizzati.map(async (item) => {
        const locker = await Locker.findOne({ lockerId: item._id }).lean();
        return {
          lockerId: item._id,
          nome: locker?.nome || item._id,
          utilizzi: item.utilizzi,
        };
      })
    );

    // Crea audit per accesso dashboard
    try {
      const auditId = await AuditOperatore.generateAuditId();
      await AuditOperatore.create({
        auditId,
        operatoreId: operatoreObjectId,
        azione: 'altro',
        entita: 'dashboard',
        dettagli: { accesso: 'dashboard' },
        timestamp: new Date(),
        ipAddress: req.ip,
        userAgent: req.get('user-agent'),
      });
    } catch (auditError) {
      logger.warn('Errore creazione audit dashboard:', auditError);
    }

    logger.info(`Dashboard recuperata per operatore ${operatoreId}`);

    res.json({
      success: true,
      data: {
        totaleLocker: lockerStats,
        totaleCelle: celleStats,
        segnalazioniAperte: segnalazioniStats,
        donazioniInAttesa,
        allarmiAttivi: allarmiStats,
        interventiInCorso,
        utilizzoUltimi7Giorni: utilizzo7Giorni,
        lockerPiuUtilizzati: lockerUtilizzati,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/admin/map
 * Mappa lato operatore
 * RF13: Mappa lato operatore
 */
export async function getAdminMap(req, res, next) {
  try {
    // Trova tutti i locker con stato completo
    const lockers = await Locker.find({}).lean();

    // Popola celle e allarmi per ogni locker
    const mapData = await Promise.all(
      lockers.map(async (locker) => {
        // Conta celle disponibili/occupate
        const celle = await Cell.find({ lockerId: locker.lockerId }).lean();
        const celleStats = {
          totale: celle.length,
          disponibili: celle.filter((c) => c.disponibile).length,
          occupate: celle.filter((c) => !c.disponibile).length,
        };

        // Conta allarmi attivi
        const allarmiCount = await Allarme.countDocuments({
          lockerId: locker.lockerId,
          stato: 'attivo',
        });

        return {
          id: locker.lockerId,
          nome: locker.nome,
          tipo: locker.tipo || null,
          position: locker.coordinate || null,
          status: locker.online ? 'online' : 'offline',
          inMaintenance: locker.stato === 'manutenzione',
          cells: celleStats,
          activeAlarms: allarmiCount,
        };
      })
    );

    logger.info(`Mappa admin recuperata: ${mapData.length} locker`);

    res.json({
      success: true,
      data: {
        lockers: mapData,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/admin/interventions
 * Interventi manutentivi
 * RF13: Interventi manutentivi
 */
export async function getInterventions(req, res, next) {
  try {
    const { page = 1, limit = 20, stato } = req.query;

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
    const query = {
      interventoManutenzioneId: { $ne: null },
    };

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

    // Calcola skip
    const skip = (pageNum - 1) * limitNum;

    // Trova segnalazioni con intervento
    const segnalazioni = await Segnalazione.find(query)
      .sort({ priorita: -1, dataCreazione: -1 })
      .skip(skip)
      .limit(limitNum)
      .lean();

    // Formatta risposte
    const items = await Promise.all(
      segnalazioni.map(async (segnalazione) => {
        const locker = await Locker.findOne({
          lockerId: segnalazione.lockerId,
        }).lean();
        const operatore = segnalazione.operatoreAssegnatoId
          ? await User.findById(segnalazione.operatoreAssegnatoId).lean()
          : null;

        return {
          id: segnalazione.segnalazioneId,
          interventoId: segnalazione.interventoManutenzioneId,
          categoria: segnalazione.categoria,
          descrizione: segnalazione.descrizione,
          priorita: segnalazione.priorita,
          stato: segnalazione.stato,
          lockerId: segnalazione.lockerId,
          lockerName: locker?.nome || null,
          assignedOperatorId: segnalazione.operatoreAssegnatoId
            ? segnalazione.operatoreAssegnatoId.toString()
            : null,
          assignedOperatorName: operatore
            ? `${operatore.nome} ${operatore.cognome}`
            : null,
          createdAt: segnalazione.dataCreazione,
        };
      })
    );

    // Calcola total
    const total = await Segnalazione.countDocuments(query);
    const totalPages = Math.ceil(total / limitNum);

    logger.info(
      `Interventi recuperati: ${items.length} items (page ${pageNum}/${totalPages})`
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
 * GET /api/v1/admin/donations
 * Pagina donazioni
 * RF13: Pagina donazioni
 */
export async function getAdminDonations(req, res, next) {
  try {
    // Riusa getAllDonations da donationAdminController
    // Passa req e res direttamente
    await getAllDonations(req, res, next);
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/admin/tickets
 * Pagina ticket/segnalazioni
 * RF13: Pagina ticket/segnalazioni
 */
export async function getAdminTickets(req, res, next) {
  try {
    // Riusa getAllReports da reportAdminController
    // Passa req e res direttamente
    await getAllReports(req, res, next);
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/admin/reporting
 * Pagina reportistica
 * RF13: Pagina reportistica
 */
export async function getAdminReporting(req, res, next) {
  try {
    // Ritorna link/endpoint per reportistica
    res.json({
      success: true,
      data: {
        endpoints: {
          usage: '/api/v1/admin/reporting/usage',
          popularParks: '/api/v1/admin/reporting/popular-parks',
          popularCategories: '/api/v1/admin/reporting/popular-categories',
          comparison: '/api/v1/admin/reporting/comparison',
          exportPDF: '/api/v1/admin/reporting/export/pdf',
          exportExcel: '/api/v1/admin/reporting/export/excel',
          scheduleEmail: '/api/v1/admin/reporting/schedule-email',
        },
      },
    });
  } catch (error) {
    next(error);
  }
}

export default {
  adminLogin,
  getDashboard,
  getAdminMap,
  getInterventions,
  getAdminDonations,
  getAdminTickets,
  getAdminReporting,
};

