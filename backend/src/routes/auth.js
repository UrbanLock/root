import express from 'express';
import { body, validationResult } from 'express-validator';
import { login, refreshToken, getMe, logout } from '../controllers/authController.js';
import { operatorLogin } from '../controllers/operatorAuthController.js';
import { authenticate } from '../middleware/auth.js';
import { ValidationError } from '../middleware/errorHandler.js';

import logger from '../utils/logger.js';

const router = express.Router();

/**
 * Middleware per validazione risultati express-validator
 */
const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError(
      errors.array().map((e) => e.msg).join(', ')
    );
  }
  next();
};

/**
 * POST /api/v1/auth/operator/login
 * Login operatore (username/password)
 * IMPORTANTE: Questa route deve essere definita PRIMA di eventuali route parametriche
 */
// Definisci la route con path esplicito
router.post('/operator/login', [
    body('username')
      .notEmpty()
      .withMessage('Username richiesto')
      .isString()
      .withMessage('Username deve essere una stringa')
      .trim()
      .isLength({ min: 3, max: 50 })
      .withMessage('Username deve essere tra 3 e 50 caratteri'),
    body('password')
      .notEmpty()
      .withMessage('Password richiesta')
      .isString()
      .withMessage('Password deve essere una stringa')
      .isLength({ min: 6 })
      .withMessage('Password deve essere di almeno 6 caratteri'),
  ],
  validate,
  operatorLogin
);

// Log quando le route vengono registrate
logger.info('Route /operator/login registrata');

/**
 * POST /api/v1/auth/login
 * Login utente (mock SPID/CIE)
 */
router.post(
  '/login',
  [
    body('codiceFiscale')
      .notEmpty()
      .withMessage('Codice fiscale richiesto')
      .isLength({ min: 16, max: 16 })
      .withMessage('Codice fiscale deve essere di 16 caratteri')
      .matches(/^[A-Z0-9]{16}$/)
      .withMessage('Codice fiscale non valido'),
    body('tipoAutenticazione')
      .notEmpty()
      .withMessage('Tipo autenticazione richiesto')
      .isIn(['spid', 'cie'])
      .withMessage('Tipo autenticazione deve essere "spid" o "cie"'),
    body('nome')
      .optional()
      .isString()
      .withMessage('Nome deve essere una stringa')
      .trim()
      .isLength({ min: 1, max: 100 })
      .withMessage('Nome deve essere tra 1 e 100 caratteri'),
    body('cognome')
      .optional()
      .isString()
      .withMessage('Cognome deve essere una stringa')
      .trim()
      .isLength({ min: 1, max: 100 })
      .withMessage('Cognome deve essere tra 1 e 100 caratteri'),
  ],
  validate,
  login
);

/**
 * POST /api/v1/auth/refresh
 * Refresh access token
 */
router.post(
  '/refresh',
  [
    body('refreshToken')
      .notEmpty()
      .withMessage('Refresh token richiesto')
      .isString()
      .withMessage('Refresh token deve essere una stringa')
      .trim()
      .notEmpty()
      .withMessage('Refresh token non può essere vuoto'),
  ],
  validate,
  refreshToken
);

/**
 * GET /api/v1/auth/me
 * Ottieni info utente corrente
 * Richiede autenticazione
 */
router.get('/me', authenticate, getMe);

/**
 * POST /api/v1/auth/logout
 * Logout utente
 * Richiede autenticazione
 */
router.post('/logout', authenticate, logout);

export default router;

