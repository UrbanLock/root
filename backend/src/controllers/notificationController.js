import Notifica from '../models/Notifica.js';
import User from '../models/User.js';
import mongoose from 'mongoose';
import {
  NotFoundError,
  ValidationError,
  UnauthorizedError,
} from '../middleware/errorHandler.js';
import logger from '../utils/logger.js';

/**
 * Tipi notifica validi
 */
const TIPI_NOTIFICA = [
  'apertura_chiusura',
  'chiusura_temporanea',
  'nuova_postazione',
  'reminder_donazione',
  'reminder_restituzione',
  'sistema',
  'altro',
];

/**
 * GET /api/v1/notifications
 * Lista notifiche utente
 * RF5: Lista notifiche utente
 */
export async function getNotifications(req, res, next) {
  try {
    const userId = req.user.userId;
    const { page = 1, limit = 20, read = 'all', type } = req.query;

    // Converti userId (stringa) in ObjectId
    const userObjectId = new mongoose.Types.ObjectId(userId);

    // Valida paginazione
    const pageNum = parseInt(page, 10);
    const limitNum = parseInt(limit, 10);

    if (pageNum < 1) {
      throw new ValidationError('page deve essere >= 1');
    }

    if (limitNum < 1 || limitNum > 100) {
      throw new ValidationError('limit deve essere tra 1 e 100');
    }

    // Valida filtro read
    const validReadValues = ['true', 'false', 'all'];
    if (!validReadValues.includes(read)) {
      throw new ValidationError(
        `read deve essere uno di: ${validReadValues.join(', ')}`
      );
    }

    // Valida filtro type
    if (type && !TIPI_NOTIFICA.includes(type)) {
      throw new ValidationError(
        `tipo non valido. Valori accettati: ${TIPI_NOTIFICA.join(', ')}`
      );
    }

    // Costruisci query
    const query = {
      utenteId: userObjectId,
    };

    // Filtro letta
    if (read !== 'all') {
      query.letta = read === 'true';
    }

    // Filtro tipo
    if (type) {
      query.tipo = type;
    }

    // Calcola skip
    const skip = (pageNum - 1) * limitNum;

    // Trova notifiche con paginazione
    const notifiche = await Notifica.find(query)
      .sort({ dataCreazione: -1 })
      .skip(skip)
      .limit(limitNum)
      .lean();

    // Formatta risposte
    const items = notifiche.map((notifica) => ({
      id: notifica.notificaId,
      type: notifica.tipo,
      title: notifica.titolo,
      body: notifica.messaggio,
      payload: notifica.payload || {},
      isRead: notifica.letta,
      timestamp: notifica.dataCreazione,
      readAt: notifica.dataLettura || null,
    }));

    // Calcola total per paginazione
    const total = await Notifica.countDocuments(query);
    const totalPages = Math.ceil(total / limitNum);

    logger.info(
      `Notifiche recuperate per utente ${userId}: ${items.length} items (page ${pageNum}/${totalPages})`
    );

    res.json({
      success: true,
      data: {
        items,
        pagination: {
          page: pageNum,
          limit: limitNum,
          total,
          totalPages,
        },
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/notifications/unread
 * Notifiche non lette
 * RF5: Notifiche non lette
 */
export async function getUnreadNotifications(req, res, next) {
  try {
    const userId = req.user.userId;
    const { page = 1, limit = 20 } = req.query;

    // Converti userId (stringa) in ObjectId
    const userObjectId = new mongoose.Types.ObjectId(userId);

    // Valida paginazione
    const pageNum = parseInt(page, 10);
    const limitNum = parseInt(limit, 10);

    if (pageNum < 1) {
      throw new ValidationError('page deve essere >= 1');
    }

    if (limitNum < 1 || limitNum > 100) {
      throw new ValidationError('limit deve essere tra 1 e 100');
    }

    // Query per notifiche non lette
    const query = {
      utenteId: userObjectId,
      letta: false,
    };

    // Calcola skip
    const skip = (pageNum - 1) * limitNum;

    // Trova notifiche non lette con paginazione
    const notifiche = await Notifica.find(query)
      .sort({ dataCreazione: -1 })
      .skip(skip)
      .limit(limitNum)
      .lean();

    // Formatta risposte
    const items = notifiche.map((notifica) => ({
      id: notifica.notificaId,
      type: notifica.tipo,
      title: notifica.titolo,
      body: notifica.messaggio,
      payload: notifica.payload || {},
      isRead: false,
      timestamp: notifica.dataCreazione,
      readAt: null,
    }));

    // Calcola total per paginazione
    const total = await Notifica.countDocuments(query);
    const totalPages = Math.ceil(total / limitNum);

    logger.info(
      `Notifiche non lette recuperate per utente ${userId}: ${items.length} items`
    );

    res.json({
      success: true,
      data: {
        items,
        pagination: {
          page: pageNum,
          limit: limitNum,
          total,
          totalPages,
        },
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * PUT /api/v1/notifications/:id/read
 * Marca come letta
 * RF5: Marca come letta
 */
export async function markAsRead(req, res, next) {
  try {
    const userId = req.user.userId;
    const { id } = req.params;

    // Converti userId (stringa) in ObjectId
    const userObjectId = new mongoose.Types.ObjectId(userId);

    // Trova notifica per notificaId e utenteId (verifica ownership)
    const notifica = await Notifica.findOne({
      notificaId: id,
      utenteId: userObjectId,
    });

    if (!notifica) {
      throw new NotFoundError('Notifica non trovata');
    }

    // Se già letta, ritorna success senza modifiche
    if (notifica.letta) {
      logger.info(
        `Notifica ${id} già letta per utente ${userId}, skip aggiornamento`
      );
      return res.json({
        success: true,
        data: {
          notification: {
            id: notifica.notificaId,
            type: notifica.tipo,
            title: notifica.titolo,
            body: notifica.messaggio,
            payload: notifica.payload || {},
            isRead: true,
            timestamp: notifica.dataCreazione,
            readAt: notifica.dataLettura || null,
          },
        },
      });
    }

    // Aggiorna come letta
    notifica.letta = true;
    notifica.dataLettura = new Date();
    await notifica.save();

    logger.info(`Notifica ${id} marcata come letta per utente ${userId}`);

    res.json({
      success: true,
      data: {
        notification: {
          id: notifica.notificaId,
          type: notifica.tipo,
          title: notifica.titolo,
          body: notifica.messaggio,
          payload: notifica.payload || {},
          isRead: true,
          timestamp: notifica.dataCreazione,
          readAt: notifica.dataLettura,
        },
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * POST /api/v1/notifications/preferences
 * Aggiorna preferenze notifiche
 * RF5: Gestione preferenze notifiche
 */
export async function updateNotificationPreferences(req, res, next) {
  try {
    const userId = req.user.userId;
    const { preferenze } = req.body;

    // Converti userId (stringa) in ObjectId
    const userObjectId = new mongoose.Types.ObjectId(userId);

    // Valida preferenze
    if (!preferenze || typeof preferenze !== 'object') {
      throw new ValidationError('preferenze deve essere un oggetto');
    }

    // Valida chiavi e valori
    const preferenzeKeys = Object.keys(preferenze);
    const invalidKeys = preferenzeKeys.filter(
      (key) => !TIPI_NOTIFICA.includes(key)
    );

    if (invalidKeys.length > 0) {
      throw new ValidationError(
        `Chiavi preferenze invalide: ${invalidKeys.join(', ')}. Valori accettati: ${TIPI_NOTIFICA.join(', ')}`
      );
    }

    const invalidValues = preferenzeKeys.filter(
      (key) => typeof preferenze[key] !== 'boolean'
    );

    if (invalidValues.length > 0) {
      throw new ValidationError(
        `Valori preferenze devono essere boolean. Chiavi invalide: ${invalidValues.join(', ')}`
      );
    }

    // Trova e aggiorna User
    const user = await User.findById(userObjectId);
    if (!user) {
      throw new NotFoundError('Utente non trovato');
    }

    // Aggiorna preferenzeNotifiche
    user.preferenzeNotifiche = preferenze;
    await user.save();

    logger.info(
      `Preferenze notifiche aggiornate per utente ${userId}: ${JSON.stringify(preferenze)}`
    );

    res.json({
      success: true,
      data: {
        preferenze: user.preferenzeNotifiche || {},
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * DELETE /api/v1/notifications/:id
 * Elimina notifica
 * RF5: Elimina notifica
 */
export async function deleteNotification(req, res, next) {
  try {
    const userId = req.user.userId;
    const { id } = req.params;

    // Converti userId (stringa) in ObjectId
    const userObjectId = new mongoose.Types.ObjectId(userId);

    // Trova notifica per notificaId e utenteId (verifica ownership)
    const notifica = await Notifica.findOne({
      notificaId: id,
      utenteId: userObjectId,
    });

    if (!notifica) {
      throw new NotFoundError('Notifica non trovata');
    }

    // Elimina notifica
    await Notifica.deleteOne({ _id: notifica._id });

    logger.info(`Notifica ${id} eliminata per utente ${userId}`);

    res.json({
      success: true,
      data: {
        message: 'Notifica eliminata con successo',
      },
    });
  } catch (error) {
    next(error);
  }
}

export default {
  getNotifications,
  getUnreadNotifications,
  markAsRead,
  updateNotificationPreferences,
  deleteNotification,
};


