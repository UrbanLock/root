import express from 'express';
import { updateCell } from '../controllers/cellController.js';
import { authenticate } from '../middleware/auth.js';

const router = express.Router();

/**
 * PUT /api/v1/cells/:id
 * Aggiorna cella
 * Parametro: :id (cellaId)
 * Body: { categoria?, richiede_foto?, stato?, costo?, grandezza?, tipo?, peso?, fotoUrl?, operatoreCreatoreId? }
 * Richiede autenticazione
 */
router.put('/:id', authenticate, updateCell);

export default router;


