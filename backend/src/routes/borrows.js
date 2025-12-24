import express from 'express';
import { authenticate } from '../middleware/auth.js';
import {
  getAvailableBorrows,
  createBorrow,
  returnBorrow,
  getActiveBorrows,
} from '../controllers/borrowController.js';

const router = express.Router();

/**
 * IMPORTANTE: Ordine delle route
 * Le route specifiche devono essere definite PRIMA di quelle con parametri
 * altrimenti Express le matcha in modo errato
 */

/**
 * GET /api/v1/borrows/available
 * Visualizza oggetti disponibili per prestito
 * Query params: ?lockerId=...&categoria=...&grandezza=...
 * RF3: Visualizzazione oggetti disponibili per prestito
 * Autenticazione: Opzionale (pubblico per RF2 mappa)
 */
router.get('/available', getAvailableBorrows);

/**
 * GET /api/v1/borrows/active
 * Lista prestiti attivi utente
 * RF3: Gestione prestiti attivi
 * RF4: Prestiti attivi utente
 * Autenticazione: Richiesta
 */
router.get('/active', authenticate, getActiveBorrows);

/**
 * POST /api/v1/borrows
 * Richiedere prestito oggetto
 * Body: {lockerId, cellaId (opz), tipoOggetto (opz), descrizione (opz), duration (opz, default "7d"), photo (opz), geolocalizzazione (opz)}
 * RF3: Creazione prestito con registrazione automatica
 * RF4: Richiesta prestito oggetto
 * Autenticazione: Richiesta
 */
router.post('/', authenticate, createBorrow);

/**
 * POST /api/v1/borrows/:id/return
 * Restituire oggetto
 * Parametro: :id (noleggioId)
 * Body: {photo (base64 REQUIRED se cella richiede_foto=true, opzionale altrimenti)}
 * RF3: Restituzione prestito
 * RF4: Restituzione vano con verifica foto obbligatoria
 * Autenticazione: Richiesta
 */
router.post('/:id/return', authenticate, returnBorrow);

export default router;


