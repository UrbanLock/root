import express from 'express';
import {
  getUsageReport,
  getPopularParks,
  getPopularCategories,
  getComparisonReport,
  exportPDF,
  exportExcel,
  scheduleEmailExport,
} from '../../controllers/reportingController.js';
import { authenticate } from '../../middleware/auth.js';
import { requireAdmin } from '../../middleware/admin.js';

const router = express.Router();

/**
 * GET /api/v1/admin/reporting/usage
 * Report utilizzo parchi/attrezzature
 * RF18: Report utilizzo parchi/attrezzature
 */
router.get('/usage', authenticate, requireAdmin, getUsageReport);

/**
 * GET /api/v1/admin/reporting/popular-parks
 * Parchi più popolati
 * RF18: Parchi più popolati
 */
router.get('/popular-parks', authenticate, requireAdmin, getPopularParks);

/**
 * GET /api/v1/admin/reporting/popular-categories
 * Categorie più richieste
 * RF18: Categorie più richieste
 */
router.get(
  '/popular-categories',
  authenticate,
  requireAdmin,
  getPopularCategories
);

/**
 * GET /api/v1/admin/reporting/comparison
 * Analisi comparativa tipologie locker
 * RF18: Analisi comparativa tipologie locker
 */
router.get('/comparison', authenticate, requireAdmin, getComparisonReport);

/**
 * POST /api/v1/admin/reporting/export/pdf
 * Esportazione PDF
 * RF18: Esportazione PDF
 */
router.post('/export/pdf', authenticate, requireAdmin, exportPDF);

/**
 * POST /api/v1/admin/reporting/export/excel
 * Esportazione Excel
 * RF18: Esportazione Excel
 */
router.post('/export/excel', authenticate, requireAdmin, exportExcel);

/**
 * POST /api/v1/admin/reporting/schedule-email
 * Export periodico via email
 * RF18: Export periodico via email
 */
router.post(
  '/schedule-email',
  authenticate,
  requireAdmin,
  scheduleEmailExport
);

export default router;

