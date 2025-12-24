import express from 'express';
import { authenticate } from '../middleware/auth.js';
import {
  getProfile,
  getProfileStats,
  updatePreferences,
  getFavorites,
} from '../controllers/profileController.js';

const router = express.Router();

/**
 * IMPORTANTE: Ordine delle route
 * Le route specifiche devono essere definite PRIMA di quelle con parametri
 */

/**
 * GET /api/v1/profile
 * Profilo utente completo
 * RF8: Visualizzazione tutte le iterazioni
 * Autenticazione: Richiesta
 */
router.get('/', authenticate, getProfile);

/**
 * GET /api/v1/profile/stats
 * Statistiche dettagliate utente
 * RF8: Statistiche utente
 * Autenticazione: Richiesta
 */
router.get('/stats', authenticate, getProfileStats);

/**
 * PUT /api/v1/profile/preferences
 * Aggiorna preferenze utente
 * Body: {preferenze: [array stringhe]}
 * RF8: Gestione preferenze
 * Autenticazione: Richiesta
 */
router.put('/preferences', authenticate, updatePreferences);

/**
 * GET /api/v1/profile/favorites
 * Lista preferiti con disponibilità tempo reale
 * RF8: Preferiti con disponibilità tempo reale
 * Autenticazione: Richiesta
 */
router.get('/favorites', authenticate, getFavorites);

export default router;


