import express from 'express';
import {
  getAllLockers,
  getLockerById,
  getLockerCells,
  getLockerCellStats,
  updateLocker,
} from '../controllers/lockerController.js';
import { authenticate } from '../middleware/auth.js';

const router = express.Router();

/**
 * GET /api/v1/lockers
 * Lista tutti i locker con filtri opzionali
 * Query params: ?type=sportivi|personali|petFriendly|commerciali|cicloturistici
 * RF2: Pubblica per mappa postazioni
 */
router.get('/', getAllLockers);

/**
 * GET /api/v1/lockers/:id/cells/stats
 * Statistiche celle per locker
 * Parametro: :id (lockerId)
 * RF2: Calcolo disponibilità tempo reale
 * IMPORTANTE: Route specifica prima di route generiche
 */
router.get('/:id/cells/stats', getLockerCellStats);

/**
 * GET /api/v1/lockers/:id/cells
 * Lista celle di un locker con filtri opzionali
 * Parametro: :id (lockerId)
 * Query params: ?type=deposit|borrow|pickup
 * IMPORTANTE: Route specifica prima di route generiche
 */
router.get('/:id/cells', getLockerCells);

/**
 * PUT /api/v1/lockers/:id
 * Aggiorna locker (RF13)
 * Parametro: :id (lockerId)
 * Body: { nome?, coordinate?, stato?, dimensione?, tipo?, descrizione?, dataRipristino?, online?, operatoreCreatoreId? }
 * Richiede autenticazione
 * IMPORTANTE: Route PUT prima di GET /:id per evitare conflitti
 */
router.put('/:id', authenticate, updateLocker);

/**
 * GET /api/v1/lockers/:id
 * Dettaglio locker
 * Parametro: :id (lockerId)
 */
router.get('/:id', getLockerById);

export default router;

