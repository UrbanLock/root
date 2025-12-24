import express from 'express';
import { authenticate } from '../../middleware/auth.js';
import { requireAdmin } from '../../middleware/admin.js';
import {
  getAllReports,
  getReportById,
  updatePriority,
  assignToMaintenance,
  updateStatus,
  getReportsStats,
} from '../../controllers/reportAdminController.js';

const router = express.Router();

/**
 * IMPORTANTE: Ordine delle route
 * Le route specifiche devono essere definite PRIMA di quelle con parametri
 */

/**
 * GET /api/v1/admin/reports/stats
 * Statistiche segnalazioni
 * Query: ?periodo=... (opz, "giorno"/"settimana"/"mese"/"anno")
 * RF15: Statistiche segnalazioni
 * Autenticazione: Richiesta
 * Middleware: Admin (operatore o admin)
 */
router.get('/stats', authenticate, requireAdmin, getReportsStats);

/**
 * GET /api/v1/admin/reports
 * Lista tutte le segnalazioni
 * Query: ?page=1&limit=20&categoria=...&stato=...&priorita=...&operatoreId=...
 * RF15: Lista tutte le segnalazioni
 * Autenticazione: Richiesta
 * Middleware: Admin (operatore o admin)
 */
router.get('/', authenticate, requireAdmin, getAllReports);

/**
 * GET /api/v1/admin/reports/:id
 * Dettaglio segnalazione
 * RF15: Dettaglio segnalazione
 * Autenticazione: Richiesta
 * Middleware: Admin (operatore o admin)
 */
router.get('/:id', authenticate, requireAdmin, getReportById);

/**
 * PUT /api/v1/admin/reports/:id/priority
 * Classificazione priorità
 * Body: {priorita (required)}
 * RF15: Classificazione priorità
 * Autenticazione: Richiesta
 * Middleware: Admin (operatore o admin)
 */
router.put('/:id/priority', authenticate, requireAdmin, updatePriority);

/**
 * PUT /api/v1/admin/reports/:id/assign
 * Assegnare a intervento manutentivo
 * Body: {interventoManutenzioneId (required), noteOperatore (opz)}
 * RF15: Assegnare a intervento manutentivo
 * Autenticazione: Richiesta
 * Middleware: Admin (operatore o admin)
 */
router.put('/:id/assign', authenticate, requireAdmin, assignToMaintenance);

/**
 * PUT /api/v1/admin/reports/:id/status
 * Tracciamento stato
 * Body: {stato (required), rispostaOperatore (opz), noteOperatore (opz)}
 * RF15: Tracciamento stato
 * Autenticazione: Richiesta
 * Middleware: Admin (operatore o admin)
 */
router.put('/:id/status', authenticate, requireAdmin, updateStatus);

export default router;

