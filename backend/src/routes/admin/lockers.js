import express from 'express';
import {
  getAllLockers,
  updateLockerStatus,
  setMaintenance,
  restoreLocker,
  getLockerProtocol,
  registerSupply,
  logMaintenance,
  getAllCommercialCells,
  assignCommercialCell,
  updateCommercialCell,
  getCommercialCellUsage,
} from '../../controllers/adminController.js';
import { authenticate } from '../../middleware/auth.js';
import { requireAdmin } from '../../middleware/admin.js';

const router = express.Router();

/**
 * GET /api/v1/admin/lockers
 * Lista tutti i locker
 * RF14: Lista tutti i locker
 */
router.get('/', authenticate, requireAdmin, getAllLockers);

/**
 * PUT /api/v1/admin/lockers/:id/status
 * Modificare stato online/offline
 * RF14: Modificare stato online/offline
 */
router.put('/:id/status', authenticate, requireAdmin, updateLockerStatus);

/**
 * PUT /api/v1/admin/lockers/:id/maintenance
 * Impostare manutenzione
 * RF14: Impostare manutenzione
 */
router.put('/:id/maintenance', authenticate, requireAdmin, setMaintenance);

/**
 * PUT /api/v1/admin/lockers/:id/restore
 * Ripristinare locker
 * RF14: Ripristinare locker
 */
router.put('/:id/restore', authenticate, requireAdmin, restoreLocker);

/**
 * GET /api/v1/admin/lockers/:id/protocol
 * Protocollo rifornimento/manutenzione
 * RF14: Protocollo rifornimento/manutenzione
 */
router.get('/:id/protocol', authenticate, requireAdmin, getLockerProtocol);

/**
 * POST /api/v1/admin/lockers/:id/supply
 * Registrare rifornimento
 * RF14: Registrare rifornimento
 */
router.post('/:id/supply', authenticate, requireAdmin, registerSupply);

/**
 * POST /api/v1/admin/lockers/:id/maintenance-log
 * Log manutenzione
 * RF14: Log manutenzione
 */
router.post(
  '/:id/maintenance-log',
  authenticate,
  requireAdmin,
  logMaintenance
);

/**
 * GET /api/v1/admin/commercial-cells
 * Lista celle commerciali
 * RF17: Lista celle commerciali
 */
router.get(
  '/commercial-cells',
  authenticate,
  requireAdmin,
  getAllCommercialCells
);

/**
 * POST /api/v1/admin/commercial-cells/assign
 * Assegnare cella a negozio
 * RF17: Assegnare cella a negozio
 */
router.post(
  '/commercial-cells/assign',
  authenticate,
  requireAdmin,
  assignCommercialCell
);

/**
 * PUT /api/v1/admin/commercial-cells/:id
 * Modificare assegnazione
 * RF17: Modificare assegnazione
 */
router.put(
  '/commercial-cells/:id',
  authenticate,
  requireAdmin,
  updateCommercialCell
);

/**
 * GET /api/v1/admin/commercial-cells/:id/usage
 * Utilizzo cella commerciale
 * RF17: Utilizzo cella commerciale
 */
router.get(
  '/commercial-cells/:id/usage',
  authenticate,
  requireAdmin,
  getCommercialCellUsage
);

export default router;

