import Operatore from '../models/Operatore.js';
import { ValidationError, NotFoundError, UnauthorizedError } from '../middleware/errorHandler.js';
import logger from '../utils/logger.js';

/**
 * GET /api/v1/admin/operators
 * Lista tutti gli operatori
 */
export async function getOperators(req, res, next) {
  try {
    const { stato, reparto, search } = req.query;
    
    // Costruisci query
    const query = {};
    
    if (stato) {
      query.stato = stato;
    }
    
    if (reparto) {
      query.reparto = reparto;
    }
    
    if (search) {
      query.$or = [
        { operatoreId: { $regex: search, $options: 'i' } },
        { matricola: { $regex: search, $options: 'i' } },
      ];
    }
    
    const operatori = await Operatore.find(query)
      .select('-passwordHash -refreshToken')
      .populate('userId', 'nome cognome email codiceFiscale')
      .sort({ operatoreId: 1 })
      .lean();
    
    res.status(200).json({
      success: true,
      data: {
        operators: operatori,
        count: operatori.length,
      },
    });
  } catch (error) {
    logger.error(`Errore nel recupero operatori: ${error.message}`, {
      stack: error.stack,
    });
    next(error);
  }
}

/**
 * GET /api/v1/admin/operators/:id
 * Dettaglio operatore
 */
export async function getOperator(req, res, next) {
  try {
    const { id } = req.params;
    
    // Cerca per operatoreId o _id
    const operatore = await Operatore.findOne({
      $or: [
        { operatoreId: id },
        { _id: id },
      ],
    })
      .select('-passwordHash -refreshToken')
      .populate('userId', 'nome cognome email codiceFiscale')
      .lean();
    
    if (!operatore) {
      throw new NotFoundError('Operatore non trovato');
    }
    
    res.status(200).json({
      success: true,
      data: {
        operator: operatore,
      },
    });
  } catch (error) {
    if (error instanceof NotFoundError) {
      next(error);
    } else {
      logger.error(`Errore nel recupero operatore: ${error.message}`, {
        stack: error.stack,
        id: req.params.id,
      });
      next(error);
    }
  }
}

/**
 * POST /api/v1/admin/operators
 * Crea nuovo operatore
 */
export async function createOperator(req, res, next) {
  try {
    const {
      userId,
      matricola,
      reparto,
      specializzazione,
      dataAssunzione,
      stato,
      permessi,
      note,
    } = req.body;
    
    // Validazione
    if (!userId) {
      throw new ValidationError('userId è obbligatorio');
    }
    
    // Genera operatoreId
    const operatoreId = await Operatore.generateOperatoreId();
    
    // Crea operatore
    const operatore = new Operatore({
      operatoreId,
      userId,
      matricola: matricola || null,
      reparto: reparto || null,
      specializzazione: specializzazione || null,
      dataAssunzione: dataAssunzione ? new Date(dataAssunzione) : null,
      stato: stato || 'attivo',
      permessi: permessi || [],
      note: note || null,
    });
    
    await operatore.save();
    
    // Popola userId per la risposta
    await operatore.populate('userId', 'nome cognome email codiceFiscale');
    
    logger.info(`Operatore creato: ${operatore.operatoreId}`, {
      operatoreId: operatore.operatoreId,
      userId: operatore.userId,
    });
    
    res.status(201).json({
      success: true,
      data: {
        operator: operatore.toJSON(),
      },
    });
  } catch (error) {
    if (error instanceof ValidationError) {
      next(error);
    } else if (error.code === 11000) {
      // Duplicate key error
      const field = Object.keys(error.keyPattern)[0];
      throw new ValidationError(`${field} già esistente`);
    } else {
      logger.error(`Errore nella creazione operatore: ${error.message}`, {
        stack: error.stack,
      });
      next(error);
    }
  }
}

/**
 * PUT /api/v1/admin/operators/:id
 * Aggiorna operatore
 */
export async function updateOperator(req, res, next) {
  try {
    const { id } = req.params;
    const {
      matricola,
      reparto,
      specializzazione,
      dataAssunzione,
      stato,
      permessi,
      note,
    } = req.body;
    
    // Cerca operatore
    const operatore = await Operatore.findOne({
      $or: [
        { operatoreId: id },
        { _id: id },
      ],
    });
    
    if (!operatore) {
      throw new NotFoundError('Operatore non trovato');
    }
    
    // Aggiorna campi
    if (matricola !== undefined) operatore.matricola = matricola || null;
    if (reparto !== undefined) operatore.reparto = reparto || null;
    if (specializzazione !== undefined) operatore.specializzazione = specializzazione || null;
    if (dataAssunzione !== undefined) operatore.dataAssunzione = dataAssunzione ? new Date(dataAssunzione) : null;
    if (stato !== undefined) operatore.stato = stato;
    if (permessi !== undefined) operatore.permessi = permessi;
    if (note !== undefined) operatore.note = note || null;
    
    await operatore.save();
    
    // Popola userId per la risposta
    await operatore.populate('userId', 'nome cognome email codiceFiscale');
    
    logger.info(`Operatore aggiornato: ${operatore.operatoreId}`, {
      operatoreId: operatore.operatoreId,
    });
    
    res.status(200).json({
      success: true,
      data: {
        operator: operatore.toJSON(),
      },
    });
  } catch (error) {
    if (error instanceof NotFoundError || error instanceof ValidationError) {
      next(error);
    } else if (error.code === 11000) {
      // Duplicate key error
      const field = Object.keys(error.keyPattern)[0];
      throw new ValidationError(`${field} già esistente`);
    } else {
      logger.error(`Errore nell'aggiornamento operatore: ${error.message}`, {
        stack: error.stack,
        id: req.params.id,
      });
      next(error);
    }
  }
}

/**
 * DELETE /api/v1/admin/operators/:id
 * Elimina operatore
 */
export async function deleteOperator(req, res, next) {
  try {
    const { id } = req.params;
    
    // Cerca operatore
    const operatore = await Operatore.findOne({
      $or: [
        { operatoreId: id },
        { _id: id },
      ],
    });
    
    if (!operatore) {
      throw new NotFoundError('Operatore non trovato');
    }
    
    await operatore.deleteOne();
    
    logger.info(`Operatore eliminato: ${operatore.operatoreId}`, {
      operatoreId: operatore.operatoreId,
    });
    
    res.status(200).json({
      success: true,
      message: 'Operatore eliminato con successo',
    });
  } catch (error) {
    if (error instanceof NotFoundError) {
      next(error);
    } else {
      logger.error(`Errore nell'eliminazione operatore: ${error.message}`, {
        stack: error.stack,
        id: req.params.id,
      });
      next(error);
    }
  }
}

