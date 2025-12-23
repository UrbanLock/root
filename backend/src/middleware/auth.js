import { verifyToken } from '../services/authService.js';
import User from '../models/User.js';
import Operatore from '../models/Operatore.js';
import { UnauthorizedError } from './errorHandler.js';
import logger from '../utils/logger.js';

/**
 * Middleware per autenticazione JWT
 * Estrae e verifica token, aggiunge req.user
 * Supporta sia utenti normali che operatori
 */
export async function authenticate(req, res, next) {
  try {
    // Estrai token da header Authorization
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedError('Token di autenticazione mancante');
    }

    const token = authHeader.substring(7); // Rimuovi "Bearer "

    if (!token) {
      throw new UnauthorizedError('Token di autenticazione mancante');
    }

    // Verifica token
    let decoded;
    try {
      decoded = verifyToken(token, 'access');
    } catch (error) {
      if (error.message === 'Token expired') {
        throw new UnauthorizedError('Token scaduto');
      } else if (error.message === 'Invalid token') {
        throw new UnauthorizedError('Token non valido');
      }
      throw new UnauthorizedError('Errore verifica token');
    }

    // Se il token contiene ruolo 'operatore', cerca nella collezione Operatore
    if (decoded.ruolo === 'operatore') {
      const operatore = await Operatore.findById(decoded._id);
      if (!operatore) {
        throw new UnauthorizedError('Operatore non trovato');
      }

      // Verifica che operatore sia attivo (se il campo esiste)
      if (operatore.attivo !== undefined && operatore.attivo === false) {
        throw new UnauthorizedError('Account disattivato');
      }

      // Aggiungi dati operatore a req
      req.user = {
        userId: operatore._id.toString(),
        utenteId: operatore.operatoreId,
        ruolo: 'operatore',
        nome: operatore.nome,
        cognome: operatore.cognome,
      };

      logger.debug(`Operatore autenticato: ${operatore.operatoreId}`);
    } else {
      // Altrimenti cerca nella collezione User
      const user = await User.findById(decoded.userId || decoded._id);
      if (!user) {
        throw new UnauthorizedError('Utente non trovato');
      }

      // Verifica che utente sia attivo
      if (!user.attivo) {
        throw new UnauthorizedError('Account disattivato');
      }

      // Aggiungi dati utente a req
      req.user = {
        userId: user._id.toString(),
        utenteId: user.utenteId,
        ruolo: user.ruolo,
        nome: user.nome,
        cognome: user.cognome,
      };

      logger.debug(`Utente autenticato: ${user.utenteId}`);
    }

    next();
  } catch (error) {
    next(error);
  }
}

export default authenticate;

