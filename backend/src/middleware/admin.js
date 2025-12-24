import User from '../models/User.js';
import Operatore from '../models/Operatore.js';
import mongoose from 'mongoose';
import { UnauthorizedError } from './errorHandler.js';
import logger from '../utils/logger.js';

/**
 * Middleware per verificare ruolo admin/operatore
 * Richiede autenticazione (deve essere chiamato dopo authenticate)
 * Supporta sia utenti normali che operatori
 */
export async function requireAdmin(req, res, next) {
  try {
    const userId = req.user?.userId;
    const ruolo = req.user?.ruolo;

    if (!userId) {
      throw new UnauthorizedError('Autenticazione richiesta');
    }

    // Se è già un operatore autenticato (dal middleware authenticate), verifica solo il ruolo
    if (ruolo === 'operatore') {
      // Verifica che l'operatore sia attivo
      const operatore = await Operatore.findById(userId).lean();
      if (!operatore) {
        throw new UnauthorizedError('Operatore non trovato');
      }
      if (operatore.attivo !== undefined && operatore.attivo === false) {
        throw new UnauthorizedError('Account operatore disattivato');
      }
      // Aggiungi ruolo a req.user per uso successivo
      req.user.role = 'operatore';
      next();
      return;
    }

    // Altrimenti, verifica per utenti normali
    // Converti userId (stringa) in ObjectId
    const userObjectId = new mongoose.Types.ObjectId(userId);

    // Trova User
    const user = await User.findById(userObjectId).lean();

    if (!user) {
      throw new UnauthorizedError('Utente non trovato');
    }

    // Verifica ruolo
    if (user.ruolo !== 'operatore' && user.ruolo !== 'admin') {
      logger.warn(
        `Tentativo accesso admin da utente ${userId} con ruolo ${user.ruolo}`
      );
      throw new UnauthorizedError(
        'Accesso negato: richiesto ruolo operatore o admin'
      );
    }

    // Aggiungi ruolo a req.user per uso successivo
    req.user.role = user.ruolo;

    next();
  } catch (error) {
    next(error);
  }
}

export default requireAdmin;


