import Segnalazione from '../models/Segnalazione.js';
import Locker from '../models/Locker.js';
import Cell from '../models/Cell.js';
import User from '../models/User.js';
import mongoose from 'mongoose';
import {
  NotFoundError,
  ValidationError,
  UnauthorizedError,
} from '../middleware/errorHandler.js';
import logger from '../utils/logger.js';
import { savePhoto, deletePhoto } from '../utils/photoStorage.js';

/**
 * Formatta Segnalazione come ReportResponse per frontend
 */
async function formatReportResponse(segnalazione, options = {}) {
  const response = {
    id: segnalazione.segnalazioneId,
    category: segnalazione.categoria,
    description: segnalazione.descrizione,
    photoUrl: segnalazione.fotoUrl || null,
    priority: segnalazione.priorita,
    status: segnalazione.stato,
    createdAt: segnalazione.dataCreazione,
    resolvedAt: segnalazione.dataRisoluzione || null,
    operatorResponse: segnalazione.rispostaOperatore || null,
    lockerId: segnalazione.lockerId || null,
    lockerName: null,
    lockerType: null,
    lockerPosition: null,
    cellaId: segnalazione.cellaId || null,
    assignedOperatorId: segnalazione.operatoreAssegnatoId
      ? segnalazione.operatoreAssegnatoId.toString()
      : null,
    assignedOperatorName: null,
  };

  // Popola locker se presente
  if (segnalazione.lockerId) {
    const locker = await Locker.findOne({ lockerId: segnalazione.lockerId }).lean();
    if (locker) {
      response.lockerName = locker.nome;
      response.lockerType = locker.tipo;
      response.lockerPosition = locker.coordinate || null;
    }
  }

  // Popola operatore se presente
  if (segnalazione.operatoreAssegnatoId) {
    const operatore = await User.findById(
      segnalazione.operatoreAssegnatoId
    ).lean();
    if (operatore) {
      response.assignedOperatorName = `${operatore.nome} ${operatore.cognome}`;
    }
  }

  return response;
}

/**
 * POST /api/v1/reports
 * Creare segnalazione
 * RF7: Creare segnalazione
 */
export async function createReport(req, res, next) {
  try {
    const { lockerId, cellaId, categoria, descrizione, photo } = req.body;
    const userId = req.user.userId;

    // Converti userId (stringa) in ObjectId
    const userObjectId = new mongoose.Types.ObjectId(userId);

    // Validazione campi obbligatori
    if (!categoria) {
      throw new ValidationError('categoria è obbligatoria');
    }
    if (!descrizione) {
      throw new ValidationError('descrizione è obbligatoria');
    }

    // Valida categoria
    const categorieValide = [
      'anomalia',
      'guasto',
      'vandalismo',
      'pulizia',
      'sicurezza',
      'altro',
    ];
    if (!categorieValide.includes(categoria)) {
      throw new ValidationError(
        `categoria non valida. Valori accettati: ${categorieValide.join(', ')}`
      );
    }

    // Valida lockerId se presente
    if (lockerId) {
      const locker = await Locker.findOne({ lockerId }).lean();
      if (!locker) {
        throw new NotFoundError(`Locker ${lockerId} non trovato`);
      }
    }

    // Valida cellaId se presente
    if (cellaId) {
      if (!lockerId) {
        throw new ValidationError(
          'lockerId è obbligatorio se cellaId è specificato'
        );
      }
      const cella = await Cell.findOne({
        cellaId,
        lockerId,
      }).lean();
      if (!cella) {
        throw new NotFoundError(
          `Cella ${cellaId} non trovata o non appartiene al locker ${lockerId}`
        );
      }
    }

    // Genera segnalazioneId prima di salvare foto
    const segnalazioneId = await Segnalazione.generateSegnalazioneId();

    // Salva foto se presente
    let fotoUrl = null;
    if (photo) {
      try {
        fotoUrl = await savePhoto(photo, segnalazioneId);
      } catch (error) {
        throw new ValidationError(`Errore salvataggio foto: ${error.message}`);
      }
    }

    // Crea Segnalazione
    const segnalazione = new Segnalazione({
      segnalazioneId,
      utenteId: userObjectId,
      lockerId: lockerId || null,
      cellaId: cellaId || null,
      categoria,
      descrizione,
      fotoUrl,
      priorita: 'media',
      stato: 'aperta',
      dataCreazione: new Date(),
      dataRisoluzione: null,
      operatoreAssegnatoId: null,
      interventoManutenzioneId: null,
      noteOperatore: null,
      rispostaOperatore: null,
      dataAggiornamento: new Date(),
    });

    await segnalazione.save();

    // Formatta risposta
    const reportResponse = await formatReportResponse(segnalazione);

    logger.info(`Segnalazione creata: ${segnalazioneId} per utente ${userId}`);

    res.status(201).json({
      success: true,
      data: {
        report: reportResponse,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/reports
 * Lista segnalazioni utente
 * RF7: Lista segnalazioni utente
 */
export async function getReports(req, res, next) {
  try {
    const userId = req.user.userId;
    const { page = 1, limit = 20, categoria, stato } = req.query;

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

    // Costruisci query
    const query = {
      utenteId: userObjectId,
    };

    // Filtro categoria
    if (categoria) {
      const categorieValide = [
        'anomalia',
        'guasto',
        'vandalismo',
        'pulizia',
        'sicurezza',
        'altro',
      ];
      if (!categorieValide.includes(categoria)) {
        throw new ValidationError(
          `categoria non valida. Valori accettati: ${categorieValide.join(', ')}`
        );
      }
      query.categoria = categoria;
    }

    // Filtro stato
    if (stato) {
      const statiValidi = [
        'aperta',
        'in_analisi',
        'assegnata',
        'in_lavorazione',
        'risolta',
        'chiusa',
      ];
      if (!statiValidi.includes(stato)) {
        throw new ValidationError(
          `stato non valido. Valori accettati: ${statiValidi.join(', ')}`
        );
      }
      query.stato = stato;
    }

    // Calcola skip
    const skip = (pageNum - 1) * limitNum;

    // Trova segnalazioni con paginazione
    const segnalazioni = await Segnalazione.find(query)
      .sort({ dataCreazione: -1 })
      .skip(skip)
      .limit(limitNum)
      .lean();

    // Formatta risposte
    const items = await Promise.all(
      segnalazioni.map((segnalazione) => formatReportResponse(segnalazione))
    );

    // Calcola total per paginazione
    const total = await Segnalazione.countDocuments(query);
    const totalPages = Math.ceil(total / limitNum);

    logger.info(
      `Segnalazioni recuperate per utente ${userId}: ${items.length} items (page ${pageNum}/${totalPages})`
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
 * GET /api/v1/reports/:id
 * Dettaglio segnalazione
 * RF7: Dettaglio segnalazione
 */
export async function getReportById(req, res, next) {
  try {
    const userId = req.user.userId;
    const { id } = req.params;

    // Converti userId (stringa) in ObjectId
    const userObjectId = new mongoose.Types.ObjectId(userId);

    // Trova Segnalazione per segnalazioneId e utenteId (verifica ownership)
    const segnalazione = await Segnalazione.findOne({
      segnalazioneId: id,
      utenteId: userObjectId,
    }).lean();

    if (!segnalazione) {
      throw new NotFoundError('Segnalazione non trovata');
    }

    // Formatta risposta
    const reportResponse = await formatReportResponse(segnalazione);

    logger.info(`Dettaglio segnalazione ${id} recuperato per utente ${userId}`);

    res.json({
      success: true,
      data: {
        report: reportResponse,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * PUT /api/v1/reports/:id
 * Modificare segnalazione
 * RF7: Modificare segnalazione
 */
export async function updateReport(req, res, next) {
  try {
    const userId = req.user.userId;
    const { id } = req.params;
    const { categoria, descrizione, photo } = req.body;

    // Converti userId (stringa) in ObjectId
    const userObjectId = new mongoose.Types.ObjectId(userId);

    // Trova Segnalazione per segnalazioneId e utenteId (verifica ownership)
    const segnalazione = await Segnalazione.findOne({
      segnalazioneId: id,
      utenteId: userObjectId,
    });

    if (!segnalazione) {
      throw new NotFoundError('Segnalazione non trovata');
    }

    // Verifica stato: solo "aperta" può essere modificata
    if (segnalazione.stato !== 'aperta') {
      throw new ValidationError(
        `Non è possibile modificare segnalazione in stato ${segnalazione.stato}`
      );
    }

    // Valida categoria se presente
    if (categoria) {
      const categorieValide = [
        'anomalia',
        'guasto',
        'vandalismo',
        'pulizia',
        'sicurezza',
        'altro',
      ];
      if (!categorieValide.includes(categoria)) {
        throw new ValidationError(
          `categoria non valida. Valori accettati: ${categorieValide.join(', ')}`
        );
      }
    }

    // Aggiorna solo campi presenti nel body
    if (categoria !== undefined) {
      segnalazione.categoria = categoria;
    }
    if (descrizione !== undefined) {
      segnalazione.descrizione = descrizione;
    }

    // Gestione foto: se presente, salva nuova foto (sostituisce esistente)
    if (photo) {
      try {
        // Elimina foto esistente se presente
        if (segnalazione.fotoUrl) {
          await deletePhoto(segnalazione.fotoUrl);
        }

        // Salva nuova foto
        const nuovaFotoUrl = await savePhoto(photo, segnalazione.segnalazioneId);
        segnalazione.fotoUrl = nuovaFotoUrl;
      } catch (error) {
        throw new ValidationError(`Errore salvataggio foto: ${error.message}`);
      }
    }

    segnalazione.dataAggiornamento = new Date();
    await segnalazione.save();

    // Formatta risposta
    const reportResponse = await formatReportResponse(segnalazione);

    logger.info(`Segnalazione ${id} aggiornata per utente ${userId}`);

    res.json({
      success: true,
      data: {
        report: reportResponse,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * DELETE /api/v1/reports/:id
 * Cancellare segnalazione
 * RF7: Cancellare segnalazione
 */
export async function deleteReport(req, res, next) {
  try {
    const userId = req.user.userId;
    const { id } = req.params;

    // Converti userId (stringa) in ObjectId
    const userObjectId = new mongoose.Types.ObjectId(userId);

    // Trova Segnalazione per segnalazioneId e utenteId (verifica ownership)
    const segnalazione = await Segnalazione.findOne({
      segnalazioneId: id,
      utenteId: userObjectId,
    });

    if (!segnalazione) {
      throw new NotFoundError('Segnalazione non trovata');
    }

    // Verifica stato: solo "aperta" può essere cancellata
    if (segnalazione.stato !== 'aperta') {
      throw new ValidationError(
        `Non è possibile cancellare segnalazione in stato ${segnalazione.stato}`
      );
    }

    // Elimina foto associata se presente
    if (segnalazione.fotoUrl) {
      try {
        await deletePhoto(segnalazione.fotoUrl);
      } catch (error) {
        logger.warn(`Errore eliminazione foto per segnalazione ${id}:`, error);
        // Non bloccare eliminazione se foto non eliminata
      }
    }

    // Elimina Segnalazione
    await Segnalazione.deleteOne({ _id: segnalazione._id });

    logger.info(`Segnalazione ${id} eliminata per utente ${userId}`);

    res.json({
      success: true,
      data: {
        message: 'Segnalazione eliminata con successo',
      },
    });
  } catch (error) {
    next(error);
  }
}

export default {
  createReport,
  getReports,
  getReportById,
  updateReport,
  deleteReport,
};

