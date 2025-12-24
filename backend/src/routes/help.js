import express from 'express';
import { authenticate } from '../middleware/auth.js';
import {
  getHelp,
  getTutorial,
  getSafetyRules,
  contactMunicipality,
} from '../controllers/helpController.js';

const router = express.Router();

/**
 * GET /api/v1/help
 * Help e tutorial generale
 * Query: ?section=... (opz)
 * RF7: Help e tutorial
 * Autenticazione: Opzionale
 */
router.get('/', getHelp);

/**
 * GET /api/v1/help/tutorial
 * Tutorial iniziale
 * RF7: Tutorial iniziale
 * Autenticazione: Opzionale
 */
router.get('/tutorial', getTutorial);

/**
 * GET /api/v1/help/safety-rules
 * Norme sicurezza parchi
 * RF7: Norme sicurezza parchi
 * Autenticazione: Opzionale
 */
router.get('/safety-rules', getSafetyRules);

/**
 * POST /api/v1/help/contact
 * Contatto ente comunale
 * Body: {oggetto (required), messaggio (required), tipoRichiesta (opz)}
 * RF7: Contatto ente comunale
 * Autenticazione: Richiesta
 */
router.post('/contact', authenticate, contactMunicipality);

export default router;

