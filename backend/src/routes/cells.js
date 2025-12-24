import express from 'express';
import {
  requestCell,
  openCell,
  closeCell,
  returnCell,
  getActiveCells,
  getHistory,
} from '../controllers/cellController.js';
import { authenticate } from '../middleware/auth.js';

const router = express.Router();

/**
 * POST /api/v1/cells/request
 * Richiedere nuova cella per deposito/prestito/pickup
 * RF3: Registrazione automatica
 * Autenticazione: Richiesta
 */
router.post('/request', authenticate, requestCell);

/**
 * POST /api/v1/cells/open
 * Sbloccare cella (apertura vano)
 * RF3: Scansione QR/Bluetooth, geolocalizzazione attiva
 * Autenticazione: Richiesta
 */
router.post('/open', authenticate, openCell);

/**
 * POST /api/v1/cells/close
 * Notificare chiusura sportello
 * RF3: Notifica chiusura sportello
 * Autenticazione: Richiesta
 */
router.post('/close', authenticate, closeCell);

/**
 * POST /api/v1/cells/return
 * Restituire vano (per prestiti e ordini)
 * RF4: Restituzione vano
 * Autenticazione: Richiesta
 */
router.post('/return', authenticate, returnCell);

/**
 * GET /api/v1/cells/active
 * Lista celle attive utente
 * RF9: Base per storico
 * Autenticazione: Richiesta
 */
router.get('/active', authenticate, getActiveCells);

/**
 * GET /api/v1/cells/history
 * Storico utilizzi
 * RF9: Storico utilizzo completo
 * Autenticazione: Richiesta
 * Query params: ?page=1&limit=20
 */
router.get('/history', authenticate, getHistory);

export default router;



