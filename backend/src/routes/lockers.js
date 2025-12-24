import express from 'express';
import {
  getAllLockers,
  getLockerById,
  getLockerCells,
  getLockerCellStats,
} from '../controllers/lockerController.js';
import {
  searchLockers,
  searchNearby,
  searchWithFilters,
  searchWithPreferences,
} from '../controllers/searchController.js';
import { authenticate } from '../middleware/auth.js';

const router = express.Router();

/**
 * GET /api/v1/lockers/search
 * Ricerca testuale locker
 * Query params: ?q=nome
 * RF2: Ricerca testuale completa
 */
router.get('/search', searchLockers);

/**
 * GET /api/v1/lockers/nearby
 * Ricerca locker per distanza
 * Query params: ?lat=46.0748&lng=11.1217&radius=5000
 * RF2: Ricerca per distanza dall'utente
 */
router.get('/nearby', searchNearby);

/**
 * GET /api/v1/lockers
 * Lista tutti i locker con filtri opzionali
 * Query params: ?type=...&category=...&distance=...&lat=...&lng=...&hours=...&available=...&online=...&maintenance=...
 * RF2: Pubblica per mappa postazioni, filtri combinati
 */
router.get('/', (req, res, next) => {
  // Se ci sono filtri avanzati, usa searchWithFilters
  const hasAdvancedFilters =
    req.query.category ||
    req.query.distance ||
    req.query.hours ||
    req.query.available ||
    req.query.online ||
    req.query.maintenance ||
    req.query.preferences;

  if (hasAdvancedFilters) {
    // Se c'è preferences, usa searchWithPreferences
    if (req.query.preferences) {
      // Autenticazione opzionale per preferenze (se utente autenticato, usa preferenze utente)
      // Prova autenticazione, ma continua anche se fallisce
      const authHeader = req.headers.authorization;
      if (authHeader && authHeader.startsWith('Bearer ')) {
        // Se c'è token, prova autenticazione
        return authenticate(req, res, () => {
          // Continua anche se autenticazione fallisce (usa query preferences)
          return searchWithPreferences(req, res, next);
        });
      }
      // Se non c'è token, continua senza autenticazione
      return searchWithPreferences(req, res, next);
    }
    // Altrimenti usa searchWithFilters
    return searchWithFilters(req, res, next);
  }

  // Altrimenti usa getAllLockers (compatibilità retroattiva)
  return getAllLockers(req, res, next);
});

/**
 * GET /api/v1/lockers/:id
 * Dettaglio locker
 * Parametro: :id (lockerId)
 */
router.get('/:id', getLockerById);

/**
 * GET /api/v1/lockers/:id/cells
 * Lista celle di un locker con filtri opzionali
 * Parametro: :id (lockerId)
 * Query params: ?type=deposit|borrow|pickup
 */
router.get('/:id/cells', getLockerCells);

/**
 * GET /api/v1/lockers/:id/cells/stats
 * Statistiche celle per locker
 * Parametro: :id (lockerId)
 * RF2: Calcolo disponibilità tempo reale
 */
router.get('/:id/cells/stats', getLockerCellStats);

export default router;



