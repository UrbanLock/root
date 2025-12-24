import jwt from 'jsonwebtoken';
import config from '../config/env.js';

/**
 * Genera access token e refresh token per un utente
 * RNF4: Token sicuri, non loggare mai tokens completi
 * @param {Object} user - Oggetto utente
 * @returns {Object} { accessToken, refreshToken }
 */
export function generateTokens(user) {
  const accessTokenPayload = {
    userId: user._id.toString(),
    utenteId: user.utenteId,
    ruolo: user.ruolo,
  };

  const refreshTokenPayload = {
    userId: user._id.toString(),
    type: 'refresh',
  };

  const accessToken = jwt.sign(accessTokenPayload, config.jwtSecret, {
    expiresIn: config.jwtAccessExpiresIn,
  });

  const refreshToken = jwt.sign(refreshTokenPayload, config.jwtSecret, {
    expiresIn: config.jwtRefreshExpiresIn,
  });

  return {
    accessToken,
    refreshToken,
  };
}

/**
 * Genera solo access token (per refresh)
 * @param {Object} user - Oggetto utente
 * @returns {string} accessToken
 */
export function generateAccessToken(user) {
  const payload = {
    userId: user._id.toString(),
    utenteId: user.utenteId,
    ruolo: user.ruolo,
  };

  return jwt.sign(payload, config.jwtSecret, {
    expiresIn: config.jwtAccessExpiresIn,
  });
}

/**
 * Verifica e decodifica un JWT token
 * @param {string} token - JWT token da verificare
 * @param {string} type - Tipo token ('access' o 'refresh')
 * @returns {Object} Payload decodificato
 * @throws {Error} Se token invalido o scaduto
 */
export function verifyToken(token, type = 'access') {
  try {
    const decoded = jwt.verify(token, config.jwtSecret);

    // Se è refresh token, verifica che abbia type: 'refresh'
    if (type === 'refresh' && decoded.type !== 'refresh') {
      throw new Error('Invalid token type');
    }

    return decoded;
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      throw new Error('Token expired');
    } else if (error.name === 'JsonWebTokenError') {
      throw new Error('Invalid token');
    }
    throw error;
  }
}

export default {
  generateTokens,
  generateAccessToken,
  verifyToken,
};

