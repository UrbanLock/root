import express from 'express';
import { body, validationResult } from 'express-validator';
import { login, refreshToken, getMe, logout } from '../controllers/authController.js';
import { authenticate } from '../middleware/auth.js';
import { ValidationError } from '../middleware/errorHandler.js';

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
 * POST /api/v1/auth/login
 * Login utente
 * 
 * ⚠️ MOCK SPID/CIE: Autenticazione semplificata per testing
 * Vedi MOCK_IMPLEMENTAZIONI.md per dettagli implementazione reale
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



