import User from '../models/User.js';
import { generateTokens, generateAccessToken, verifyToken } from '../services/authService.js';
import { ValidationError, UnauthorizedError, NotFoundError } from '../middleware/errorHandler.js';
import logger from '../utils/logger.js';

/**
 * Login utente
 * 
 * ⚠️ MOCK SPID/CIE: Autenticazione semplificata per testing
 * Implementazione reale: Richiede integrazione con provider SPID/CIE
 * Vedi MOCK_IMPLEMENTAZIONI.md per dettagli
 * POST /api/v1/auth/login
 */
export async function login(req, res, next) {
  try {
    const { codiceFiscale, tipoAutenticazione, nome, cognome } = req.body;

    // Cerca utente esistente
    let user = await User.findOne({ codiceFiscale: codiceFiscale.toUpperCase() });

    // Se utente non esiste, crea nuovo
    if (!user) {
      // Genera utenteId sequenziale
      const utenteId = await User.generateUtenteId();

      // Se nome/cognome non forniti, usa valori di default
      const userNome = nome || 'Utente';
      const userCognome = cognome || 'Anonimo';

      user = new User({
        utenteId,
        nome: userNome,
        cognome: userCognome,
        codiceFiscale: codiceFiscale.toUpperCase(),
        tipoAutenticazione,
        ruolo: 'utente',
        attivo: true,
      });

      await user.save();
      logger.info(`Nuovo utente creato: ${utenteId} (${userNome} ${userCognome})`);
    } else {
      // Verifica che utente sia attivo
      if (!user.attivo) {
        throw new UnauthorizedError('Account disattivato');
      }

      // Aggiorna tipo autenticazione se diverso
      if (user.tipoAutenticazione !== tipoAutenticazione) {
        user.tipoAutenticazione = tipoAutenticazione;
        await user.save();
      }
    }

    // Genera tokens
    const tokens = generateTokens(user);

    // Salva refresh token nell'utente (opzionale, per revoca)
    user.refreshToken = tokens.refreshToken;
    await user.updateLastAccess();

    // Calcola expiresIn in secondi
    const expiresIn = 15 * 60; // 15 minuti in secondi

    logger.info(`Login utente: ${user.utenteId} (${user.nome} ${user.cognome})`);

    res.json({
      success: true,
      data: {
        user: {
          utenteId: user.utenteId,
          nome: user.nome,
          cognome: user.cognome,
          ruolo: user.ruolo,
        },
        tokens: {
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
          expiresIn,
        },
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * Refresh access token
 * POST /api/v1/auth/refresh
 */
export async function refreshToken(req, res, next) {
  try {
    const { refreshToken: refreshTokenValue } = req.body;

    if (!refreshTokenValue) {
      throw new ValidationError('Refresh token richiesto');
    }

    // Verifica refresh token
    let decoded;
    try {
      decoded = verifyToken(refreshTokenValue, 'refresh');
    } catch (error) {
      throw new UnauthorizedError('Refresh token invalido o scaduto');
    }

    // Trova utente
    const user = await User.findById(decoded.userId);
    if (!user) {
      throw new NotFoundError('Utente non trovato');
    }

    // Verifica che utente sia attivo
    if (!user.attivo) {
      throw new UnauthorizedError('Account disattivato');
    }

    // Verifica che refresh token corrisponda (se salvato in DB)
    if (user.refreshToken && user.refreshToken !== refreshTokenValue) {
      throw new UnauthorizedError('Refresh token non valido');
    }

    // Genera nuovo access token
    const accessToken = generateAccessToken(user);

    // Calcola expiresIn
    const expiresIn = 15 * 60; // 15 minuti in secondi

    logger.info(`Refresh token per utente: ${user.utenteId}`);

    res.json({
      success: true,
      data: {
        accessToken,
        expiresIn,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * Ottieni info utente corrente
 * GET /api/v1/auth/me
 */
export async function getMe(req, res, next) {
  try {
    // req.user è impostato dal middleware authenticate
    const userId = req.user.userId;

    const user = await User.findById(userId);
    if (!user) {
      throw new NotFoundError('Utente non trovato');
    }

    // toJSON() rimuove automaticamente campi sensibili
    res.json({
      success: true,
      data: {
        user: user.toJSON(),
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * Logout utente
 * POST /api/v1/auth/logout
 */
export async function logout(req, res, next) {
  try {
    const userId = req.user.userId;

    const user = await User.findById(userId);
    if (user) {
      // Invalida refresh token rimuovendolo
      user.refreshToken = null;
      await user.save();
      logger.info(`Logout utente: ${user.utenteId}`);
    }

    res.json({
      success: true,
      message: 'Logout effettuato con successo',
    });
  } catch (error) {
    next(error);
  }
}

export default {
  login,
  refreshToken,
  getMe,
  logout,
};



