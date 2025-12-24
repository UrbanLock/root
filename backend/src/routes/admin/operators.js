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

export default router;

