import express from 'express';
import { authenticate } from '../middleware/auth.js';
import {
  getHistory,
  getHistoryStats,
  getHistorySegnalazioni,
  getHistoryPostazioni,
} from '../controllers/historyController.js';

const router = express.Router();

/**
 * IMPORTANTE: Ordine delle route
 * Le route specifiche devono essere definite PRIMA di quelle con parametri
 */

/**
 * GET /api/v1/history
 * Storico completo utilizzo
 * Query params: ?page=1&limit=20&type=deposito|prestito|ordini|all&fromDate=YYYY-MM-DD&toDate=YYYY-MM-DD
 * RF9: Tracking completo utilizzo
 * Autenticazione: Richiesta
 */
router.get('/', authenticate, getHistory);

/**
 * GET /api/v1/history/stats
 * Statistiche storico
 * RF9: Statistiche attrezzature più usate, parchi preferiti, ore di accesso
 * Autenticazione: Richiesta
 */
router.get('/stats', authenticate, getHistoryStats);

/**
 * GET /api/v1/history/segnalazioni
 * Storico segnalazioni
 * Query params: ?page=1&limit=20
 * RF8: Storico segnalazioni
 * RF9: Storico segnalazioni
 * Autenticazione: Richiesta
 */
router.get('/segnalazioni', authenticate, getHistorySegnalazioni);

/**
 * GET /api/v1/history/postazioni
 * Storico postazioni usate
 * Query params: ?page=1&limit=20
 * RF8: Storico postazioni usate
 * RF9: Storico postazioni
 * Autenticazione: Richiesta
 */
router.get('/postazioni', authenticate, getHistoryPostazioni);

export default router;


