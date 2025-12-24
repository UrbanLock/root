import express from 'express';
import {
  adminLogin,
  getDashboard,
  getAdminMap,
  getInterventions,
  getAdminDonations,
  getAdminTickets,
  getAdminReporting,
} from '../../controllers/operatorController.js';
import {
  getOperators,
  getOperator,
  createOperator,
  updateOperator,
  deleteOperator,
} from '../../controllers/operatorCrudController.js';
import { authenticate } from '../../middleware/auth.js';
import { requireAdmin } from '../../middleware/admin.js';

const router = express.Router();

/**
 * POST /api/v1/admin/login
 * Login operatore
 * RF13: Login operatore
 */
router.post('/login', adminLogin);

/**
 * GET /api/v1/admin/dashboard
 * Dashboard operatore
 * RF13: Dashboard operatore
 */
router.get('/dashboard', authenticate, requireAdmin, getDashboard);

/**
 * GET /api/v1/admin/map
 * Mappa lato operatore
 * RF13: Mappa lato operatore
 */
router.get('/map', authenticate, requireAdmin, getAdminMap);

/**
 * GET /api/v1/admin/interventions
 * Interventi manutentivi
 * RF13: Interventi manutentivi
 */
router.get('/interventions', authenticate, requireAdmin, getInterventions);

/**
 * GET /api/v1/admin/donations
 * Pagina donazioni
 * RF13: Pagina donazioni
 */
router.get('/donations', authenticate, requireAdmin, getAdminDonations);

/**
 * GET /api/v1/admin/tickets
 * Pagina ticket/segnalazioni
 * RF13: Pagina ticket/segnalazioni
 */
router.get('/tickets', authenticate, requireAdmin, getAdminTickets);

/**
 * GET /api/v1/admin/reporting
 * Pagina reportistica
 * RF13: Pagina reportistica
 */
router.get('/reporting', authenticate, requireAdmin, getAdminReporting);

/**
 * CRUD Operators
 * Queste route devono essere definite DOPO le route specifiche sopra
 * per evitare conflitti di routing
 */

/**
 * GET /api/v1/admin/operators
 * Lista tutti gli operatori
 * Query: ?stato=...&reparto=...&search=...
 */
router.get('/operators', authenticate, requireAdmin, getOperators);

/**
 * GET /api/v1/admin/operators/:id
 * Dettaglio operatore
 */
router.get('/operators/:id', authenticate, requireAdmin, getOperator);

/**
 * POST /api/v1/admin/operators
 * Crea nuovo operatore
 */
router.post('/operators', authenticate, requireAdmin, createOperator);

/**
 * PUT /api/v1/admin/operators/:id
 * Aggiorna operatore
 */
router.put('/operators/:id', authenticate, requireAdmin, updateOperator);

/**
 * DELETE /api/v1/admin/operators/:id
 * Elimina operatore
 */
router.delete('/operators/:id', authenticate, requireAdmin, deleteOperator);

export default router;

