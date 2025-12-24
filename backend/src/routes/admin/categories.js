import express from 'express';
import {
  getAllCategories,
  createCategory,
  getCategoryById,
  updateCategory,
  deleteCategory,
} from '../../controllers/categoryController.js';
import { authenticate } from '../../middleware/auth.js';
import { requireAdmin } from '../../middleware/admin.js';

const router = express.Router();

/**
 * GET /api/v1/admin/categories
 * Lista tutte le categorie locker
 * RF20: Lista categorie locker
 */
router.get('/', authenticate, requireAdmin, getAllCategories);

/**
 * POST /api/v1/admin/categories
 * Crea nuova categoria locker
 * RF20: Crea categoria locker
 */
router.post('/', authenticate, requireAdmin, createCategory);

/**
 * GET /api/v1/admin/categories/:id
 * Dettaglio categoria locker
 * RF20: Dettaglio categoria locker
 */
router.get('/:id', authenticate, requireAdmin, getCategoryById);

/**
 * PUT /api/v1/admin/categories/:id
 * Aggiorna categoria locker
 * RF20: Aggiorna categoria locker
 */
router.put('/:id', authenticate, requireAdmin, updateCategory);

/**
 * DELETE /api/v1/admin/categories/:id
 * Elimina categoria locker
 * RF20: Elimina categoria locker
 */
router.delete('/:id', authenticate, requireAdmin, deleteCategory);

export default router;

