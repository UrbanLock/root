import Operatore from '../models/Operatore.js';
import { generateTokens, generateAccessToken, verifyToken } from '../services/authService.js';
import { ValidationError, UnauthorizedError, NotFoundError } from '../middleware/errorHandler.js';
import logger from '../utils/logger.js';
import bcrypt from 'bcryptjs';

/**
 * Login operatore (username/password)
 * POST /api/v1/auth/operator/login
 */
export async function operatorLogin(req, res, next) {
  try {
    const { username, password } = req.body;

    // Validazione input base (la validazione dettagliata è già fatta da express-validator)
    if (!username || !password) {
      throw new ValidationError('Username e password richiesti');
    }

    // Normalizza username (trim)
    const searchUsername = username.trim();
    const searchUsernameLower = searchUsername.toLowerCase();
    
    logger.info(`Tentativo login operatore: username="${searchUsername}" (lowercase: "${searchUsernameLower}")`);

    // Cerca operatore per username nella collezione operatori
    // Prova prima con il valore esatto, poi con lowercase, poi case-insensitive
    let operatore = await Operatore.findOne({ 
      $or: [
        { username: searchUsername },
        { username: searchUsernameLower },
        { username: { $regex: new RegExp(`^${searchUsername}$`, 'i') } }
      ]
    }).select('+passwordHash');

    // Se non trovato, prova anche senza select per vedere se esiste
    if (!operatore) {
      const operatoreTest = await Operatore.findOne({ 
        $or: [
          { username: searchUsername },
          { username: searchUsernameLower },
          { username: { $regex: new RegExp(`^${searchUsername}$`, 'i') } }
        ]
      });
      
      if (operatoreTest) {
        logger.warn(`Operatore trovato ma passwordHash non disponibile: ${operatoreTest.operatoreId}`);
        throw new UnauthorizedError('Errore di configurazione account');
      }
      
      logger.warn(`Tentativo login fallito: operatore non trovato (username: "${searchUsername}")`);
      // Log tutti gli operatori disponibili per debug (solo in development)
      if (process.env.NODE_ENV === 'development') {
        const allOperatori = await Operatore.find({}).select('username operatoreId');
        logger.debug(`Operatori disponibili nel DB: ${JSON.stringify(allOperatori.map(op => ({ username: op.username, id: op.operatoreId })))}`);
      }
      throw new UnauthorizedError('Credenziali non valide');
    }

    logger.info(`Operatore trovato: ${operatore.operatoreId} (${operatore.nome} ${operatore.cognome}), username nel DB: "${operatore.username}"`);

    // Verifica che operatore sia attivo (se il campo esiste)
    if (operatore.attivo !== undefined && operatore.attivo === false) {
      logger.warn(`Tentativo login fallito: account disattivato (operatoreId: ${operatore.operatoreId})`);
      throw new UnauthorizedError('Account disattivato');
    }

    // Verifica che passwordHash esista
    if (!operatore.passwordHash) {
      logger.error(`Errore configurazione: password non configurata per operatore ${operatore.operatoreId}`);
      throw new UnauthorizedError('Errore di configurazione account');
    }

    // Verifica password
    logger.info(`Verifica password: passwordHash nel DB="${operatore.passwordHash}", password ricevuta="${password}"`);
    
    // Prova prima con bcrypt (per hash bcrypt reali)
    let isPasswordValid = false;
    try {
      isPasswordValid = await bcrypt.compare(password, operatore.passwordHash);
      logger.info(`Bcrypt compare risultato: ${isPasswordValid}`);
    } catch (error) {
      logger.info(`Bcrypt compare errore: ${error.message}`);
      isPasswordValid = false;
    }

    // Se bcrypt non ha funzionato, prova confronto diretto (per hash di test)
    if (!isPasswordValid) {
      isPasswordValid = (operatore.passwordHash === password);
      logger.info(`Confronto diretto risultato: ${isPasswordValid}`);
    }

    if (!isPasswordValid) {
      logger.warn(`Tentativo login fallito: password non valida (operatoreId: ${operatore.operatoreId})`, {
        passwordHashLength: operatore.passwordHash?.length,
        passwordLength: password?.length,
        passwordHashStartsWith: operatore.passwordHash?.substring(0, 10),
      });
      throw new UnauthorizedError('Credenziali non valide');
    }
    
    logger.info(`Password valida per operatore ${operatore.operatoreId}`);

    // Genera tokens JWT
    // Il token contiene operatoreId come utenteId per compatibilità con il sistema esistente
    const tokenPayload = {
      _id: operatore._id,
      utenteId: operatore.operatoreId,
      ruolo: 'operatore',
    };
    
    const tokens = generateTokens(tokenPayload);

    // Aggiorna operatore: salva refresh token e ultimo accesso
    try {
      operatore.refreshToken = tokens.refreshToken;
      operatore.ultimoAccesso = new Date();
      await operatore.save();
    } catch (saveError) {
      // Se il salvataggio fallisce, logga ma non bloccare il login
      logger.error(`Errore nel salvataggio operatore dopo login: ${saveError.message}`, {
        operatoreId: operatore.operatoreId,
      });
    }

    // Calcola expiresIn in secondi (15 minuti)
    const expiresIn = 15 * 60;

    logger.info(`Login operatore riuscito: ${operatore.operatoreId} (${operatore.nome} ${operatore.cognome})`, {
      operatoreId: operatore.operatoreId,
      ip: req.ip,
    });

    // Restituisci risposta di successo
    res.status(200).json({
      success: true,
      data: {
        user: {
          operatoreId: operatore.operatoreId,
          nome: operatore.nome,
          cognome: operatore.cognome,
          ruolo: 'operatore',
          username: operatore.username,
        },
        tokens: {
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
          expiresIn,
        },
      },
    });
  } catch (error) {
    // Gestione errori centralizzata
    // Gli errori ValidationError e UnauthorizedError vengono già gestiti correttamente
    // Logga solo errori inaspettati
    if (error instanceof ValidationError || error instanceof UnauthorizedError) {
      // Errori di validazione/autenticazione sono già loggati sopra
      next(error);
    } else {
      // Errori inaspettati (database, ecc.)
      logger.error(`Errore inaspettato nel login operatore: ${error.message}`, {
        stack: error.stack,
        username: req.body?.username,
        ip: req.ip,
      });
      next(error);
    }
  }
}

export default {
  operatorLogin,
};

