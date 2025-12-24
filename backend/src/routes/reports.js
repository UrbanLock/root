import express from 'express';
import { authenticate } from '../middleware/auth.js';
import {
  createReport,
  getReports,
  getReportById,
  updateReport,
  deleteReport,
} from '../controllers/reportController.js';

const router = express.Router();

/**
 * IMPORTANTE: Ordine delle route
 * Le route specifiche devono essere definite PRIMA di quelle con parametri
 */

/**
 * POST /api/v1/reports
 * Creare segnalazione
 * Body: {lockerId (opz), cellaId (opz), categoria (required), descrizione (required), photo (opz)}
 * RF7: Creare segnalazione
 * Autenticazione: Richiesta
 */
router.post('/', authenticate, createReport);

/**
 * GET /api/v1/reports
 * Lista segnalazioni utente
 * Query: ?page=1&limit=20&categoria=...&stato=...
 * RF7: Lista segnalazioni utente
 * Autenticazione: Richiesta
 */
router.get('/', authenticate, getReports);

/**
 * GET /api/v1/reports/:id
 * Dettaglio segnalazione
 * RF7: Dettaglio segnalazione
 * Autenticazione: Richiesta
 */
router.get('/:id', authenticate, getReportById);

/**
 * PUT /api/v1/reports/:id
 * Modificare segnalazione
 * Body: {categoria (opz), descrizione (opz), photo (opz)}
 * RF7: Modificare segnalazione
 * Autenticazione: Richiesta
 */
router.put('/:id', authenticate, updateReport);

/**
 * DELETE /api/v1/reports/:id
 * Cancellare segnalazione
 * RF7: Cancellare segnalazione
 * Autenticazione: Richiesta
 */
router.delete('/:id', authenticate, deleteReport);

export default router;

