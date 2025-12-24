import express from 'express';
import { authenticate } from '../middleware/auth.js';
import {
  createDeposit,
  getActiveDeposits,
  endDeposit,
  extendDeposit,
  processPayment,
} from '../controllers/depositController.js';

const router = express.Router();

/**
 * IMPORTANTE: Ordine delle route
 * Le route specifiche devono essere definite PRIMA di quelle con parametri
 * altrimenti Express le matcha in modo errato
 */

/**
 * GET /api/v1/deposits/active
 * Lista depositi attivi utente
 * RF3: Gestione depositi attivi
 */
router.get('/active', authenticate, getActiveDeposits);

/**
 * POST /api/v1/deposits/payments
 * Processa pagamento (mock)
 * Body: {depositId, amount (opz), paymentMethod (opz)}
 * RF3: Processamento pagamento (mock)
 * NOTA: Nessuna transazione bancaria reale, nessun dato sensibile
 */
router.post('/payments', authenticate, processPayment);

/**
 * POST /api/v1/deposits
 * Crea nuovo deposito
 * Body: {lockerId, cellaId (opz), duration (opz), photo (opz), geolocalizzazione (opz)}
 * RF3: Creazione deposito con registrazione automatica
 */
router.post('/', authenticate, createDeposit);

/**
 * PUT /api/v1/deposits/:id/extend
 * Estende durata deposito
 * Parametro: :id (noleggioId)
 * Body: {duration}
 * RF3: Estensione durata deposito
 */
router.put('/:id/extend', authenticate, extendDeposit);

/**
 * PUT /api/v1/deposits/:id/end
 * Termina deposito (ritiro)
 * Parametro: :id (noleggioId)
 * RF3: Terminazione deposito
 */
router.put('/:id/end', authenticate, endDeposit);

export default router;

