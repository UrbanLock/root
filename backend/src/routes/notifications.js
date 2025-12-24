import express from 'express';
import { authenticate } from '../middleware/auth.js';
import {
  getNotifications,
  getUnreadNotifications,
  markAsRead,
  updateNotificationPreferences,
  deleteNotification,
} from '../controllers/notificationController.js';

const router = express.Router();

/**
 * IMPORTANTE: Ordine delle route
 * Le route specifiche devono essere definite PRIMA di quelle con parametri
 */

/**
 * GET /api/v1/notifications
 * Lista notifiche utente
 * Query params: ?page=1&limit=20&read=true|false|all&type=...
 * RF5: Lista notifiche utente
 * Autenticazione: Richiesta
 */
router.get('/', authenticate, getNotifications);

/**
 * GET /api/v1/notifications/unread
 * Notifiche non lette
 * Query params: ?page=1&limit=20
 * RF5: Notifiche non lette
 * Autenticazione: Richiesta
 */
router.get('/unread', authenticate, getUnreadNotifications);

/**
 * PUT /api/v1/notifications/:id/read
 * Marca come letta
 * RF5: Marca come letta
 * Autenticazione: Richiesta
 */
router.put('/:id/read', authenticate, markAsRead);

/**
 * POST /api/v1/notifications/preferences
 * Aggiorna preferenze notifiche
 * Body: {preferenze: {tipo:boolean, ...}}
 * RF5: Gestione preferenze notifiche
 * Autenticazione: Richiesta
 */
router.post('/preferences', authenticate, updateNotificationPreferences);

/**
 * DELETE /api/v1/notifications/:id
 * Elimina notifica
 * RF5: Elimina notifica
 * Autenticazione: Richiesta
 */
router.delete('/:id', authenticate, deleteNotification);

export default router;


