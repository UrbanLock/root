import Donazione from '../models/Donazione.js';
import User from '../models/User.js';
import Locker from '../models/Locker.js';
import mongoose from 'mongoose';
import {
  NotFoundError,
  ValidationError,
  UnauthorizedError,
} from '../middleware/errorHandler.js';
import logger from '../utils/logger.js';
import { savePhoto, validatePhoto } from '../utils/photoStorage.js';
import { createNotification } from '../services/notificationService.js';

/**
 * Formatta Donazione come AdminDonationResponse per frontend admin
 */
async function formatAdminDonationResponse(donazione) {
  const response = {
    id: donazione.donazioneId,
    userId: donazione.utenteId
      ? donazione.utenteId.toString()
      : null,
    userName: null,
    userSurname: null,
    userEmail: null,
    userPhone: null,
    nomeOggetto: donazione.nomeOggetto,
    tipoAttrezzatura: donazione.tipoAttrezzatura,
    categoria: donazione.categoria || null,
    descrizione: donazione.descrizione,
    photoUrl: donazione.fotoUrl || null,
    status: donazione.stato,
    createdAt: donazione.dataCreazione,
    scheduledPickup: donazione.dataRitiro || null,
    rejectionReason: donazione.motivoRifiuto || null,
    lockerId: donazione.lockerId || null,
    lockerName: null,
    lockerType: null,
    lockerPosition: null,
    assignedOperatorId: donazione.operatoreAssegnatoId
      ? donazione.operatoreAssegnatoId.toString()
      : null,
    assignedOperatorName: null,
    documentationUrl: donazione.documentazioneUrl || null,
    operatorNotes: donazione.noteOperatore || null,
  };

  // Popola utente
  if (donazione.utenteId) {
    const user = await User.findById(donazione.utenteId).lean();
    if (user) {
      response.userName = user.nome;
      response.userSurname = user.cognome;
      response.userEmail = user.email || null;
      response.userPhone = user.telefono || null;
    }
  }

  // Popola locker se presente
  if (donazione.lockerId) {
    const locker = await Locker.findOne({ lockerId: donazione.lockerId }).lean();
    if (locker) {
      response.lockerName = locker.nome;
      response.lockerType = locker.tipo;
      response.lockerPosition = locker.coordinate || null;
    }
  }

  // Popola operatore se presente
  if (donazione.operatoreAssegnatoId) {
    const operatore = await User.findById(
      donazione.operatoreAssegnatoId
    ).lean();
    if (operatore) {
      response.assignedOperatorName = `${operatore.nome} ${operatore.cognome}`;
    }
  }

  return response;
}

/**
 * GET /api/v1/admin/donations
 * Lista tutte le donazioni
 * RF16: Lista tutte le donazioni
 */
export async function getAllDonations(req, res, next) {
  try {
    const { page = 1, limit = 20, status, operatoreId } = req.query;

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
    const query = {};

    // Filtro stato
    if (status) {
      const statiValidi = [
        'da_visionare',
        'in_valutazione',
        'in_ritiro',
        'concluso',
        'rifiutato',
      ];
      if (!statiValidi.includes(status)) {
        throw new ValidationError(
          `stato non valido. Valori accettati: ${statiValidi.join(', ')}`
        );
      }
      query.stato = status;
    }

    // Filtro operatoreId
    if (operatoreId) {
      const operatoreObjectId = new mongoose.Types.ObjectId(operatoreId);
      query.operatoreAssegnatoId = operatoreObjectId;
    }

    // Calcola skip
    const skip = (pageNum - 1) * limitNum;

    // Trova donazioni con paginazione
    const donazioni = await Donazione.find(query)
      .sort({ dataCreazione: -1 })
      .skip(skip)
      .limit(limitNum)
      .lean();

    // Formatta risposte
    const items = await Promise.all(
      donazioni.map((donazione) => formatAdminDonationResponse(donazione))
    );

    // Calcola total per paginazione
    const total = await Donazione.countDocuments(query);
    const totalPages = Math.ceil(total / limitNum);

    logger.info(
      `Donazioni recuperate (admin): ${items.length} items (page ${pageNum}/${totalPages})`
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
 * PUT /api/v1/admin/donations/:id/status
 * Modificare stato donazione
 * RF16: Modificare stato
 */
export async function updateDonationStatus(req, res, next) {
  try {
    const { id } = req.params;
    const { stato, motivoRifiuto, noteOperatore } = req.body;
    const operatoreId = req.user.userId;

    // Converti operatoreId (stringa) in ObjectId
    const operatoreObjectId = new mongoose.Types.ObjectId(operatoreId);

    // Validazione stato
    if (!stato) {
      throw new ValidationError('stato è obbligatorio');
    }

    const statiValidi = [
      'da_visionare',
      'in_valutazione',
      'in_ritiro',
      'concluso',
      'rifiutato',
    ];
    if (!statiValidi.includes(stato)) {
      throw new ValidationError(
        `stato non valido. Valori accettati: ${statiValidi.join(', ')}`
      );
    }

    // Valida motivoRifiuto se stato="rifiutato"
    if (stato === 'rifiutato' && !motivoRifiuto) {
      throw new ValidationError(
        'motivoRifiuto è obbligatorio quando stato è "rifiutato"'
      );
    }

    // Trova Donazione
    const donazione = await Donazione.findOne({ donazioneId: id });

    if (!donazione) {
      throw new NotFoundError('Donazione non trovata');
    }

    // Aggiorna stato e campi correlati
    donazione.stato = stato;
    donazione.operatoreAssegnatoId = operatoreObjectId;
    donazione.dataAggiornamento = new Date();

    if (motivoRifiuto !== undefined) {
      donazione.motivoRifiuto = motivoRifiuto || null;
    }

    if (noteOperatore !== undefined) {
      donazione.noteOperatore = noteOperatore || null;
    }

    await donazione.save();

    // Formatta risposta
    const donationResponse = await formatAdminDonationResponse(donazione);

    logger.info(
      `Stato donazione ${id} aggiornato a ${stato} da operatore ${operatoreId}`
    );

    res.json({
      success: true,
      data: {
        donation: donationResponse,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * POST /api/v1/admin/donations/:id/contact
 * Contatto donatore
 * RF16: Contatto diretto con donatori
 */
export async function contactDonator(req, res, next) {
  try {
    const { id } = req.params;
    const { messaggio, canale = 'interno' } = req.body;
    const operatoreId = req.user.userId;

    // Validazione messaggio
    if (!messaggio) {
      throw new ValidationError('messaggio è obbligatorio');
    }

    // Valida canale
    const canaliValidi = ['email', 'telefono', 'interno'];
    if (!canaliValidi.includes(canale)) {
      throw new ValidationError(
        `canale non valido. Valori accettati: ${canaliValidi.join(', ')}`
      );
    }

    // Trova Donazione
    const donazione = await Donazione.findOne({ donazioneId: id }).lean();

    if (!donazione) {
      throw new NotFoundError('Donazione non trovata');
    }

    // Popola utente
    const user = await User.findById(donazione.utenteId).lean();

    if (!user) {
      throw new NotFoundError('Utente donatore non trovato');
    }

    // Valida canale e dati utente
    if (canale === 'email') {
      if (!user.email) {
        throw new ValidationError('Utente non ha email registrata');
      }
    } else if (canale === 'telefono') {
      if (!user.telefono) {
        throw new ValidationError('Utente non ha telefono registrato');
      }
    }

    // Per MVP, crea notifica in-app
    // In futuro, può essere integrato con servizio email/SMS esterno
    try {
      const operatore = await User.findById(operatoreId).lean();
      const operatoreName = operatore
        ? `${operatore.nome} ${operatore.cognome}`
        : 'Operatore';

      const titolo = `Messaggio da ${operatoreName}`;
      const messaggioNotifica = `Messaggio relativo alla tua donazione "${donazione.nomeOggetto}": ${messaggio}`;

      await createNotification(
        donazione.utenteId,
        'sistema',
        titolo,
        messaggioNotifica,
        {
          donazioneId: donazione.donazioneId,
          canale,
          operatoreId,
        }
      );

      logger.info(
        `Notifica contatto creata per donazione ${id}, canale: ${canale}`
      );
    } catch (notificationError) {
      logger.warn(
        `Errore creazione notifica contatto per donazione ${id}:`,
        notificationError
      );
      // Non bloccare il contatto se notifica fallisce
    }

    // Prepara risposta con dettagli contatto
    const contactDetails = {
      canale,
      messaggio,
      utenteEmail: canale === 'email' ? user.email : null,
      utenteTelefono: canale === 'telefono' ? user.telefono : null,
      notificaInviata: true,
    };

    logger.info(
      `Contatto donatore per donazione ${id}, canale: ${canale}, operatore: ${operatoreId}`
    );

    res.json({
      success: true,
      data: {
        message: 'Contatto inviato con successo',
        contact: contactDetails,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * POST /api/v1/admin/donations/:id/attach-document
 * Allegare documentazione
 * RF16: Allegare documentazione
 */
export async function attachDocument(req, res, next) {
  try {
    const { id } = req.params;
    const { documento, tipoDocumento } = req.body;
    const operatoreId = req.user.userId;

    // Validazione documento
    if (!documento) {
      throw new ValidationError('documento è obbligatorio');
    }

    // Trova Donazione
    const donazione = await Donazione.findOne({ donazioneId: id });

    if (!donazione) {
      throw new NotFoundError('Donazione non trovata');
    }

    // Salva documento (riusa photoStorage per semplicità MVP)
    // In futuro, può essere creato servizio documentStorage separato
    let documentazioneUrl = null;
    try {
      // Valida documento (stesso formato foto base64)
      const validation = validatePhoto(documento);
      if (!validation.valid) {
        throw new ValidationError(
          `Errore validazione documento: ${validation.error}`
        );
      }

      // Salva documento (max size 10MB invece di 5MB)
      const buffer = validation.buffer;
      if (buffer.length > 10 * 1024 * 1024) {
        throw new ValidationError(
          'Documento troppo grande. Dimensione massima: 10MB'
        );
      }

      // Usa savePhoto ma con prefisso diverso per documenti
      documentazioneUrl = await savePhoto(
        documento,
        `${donazione.donazioneId}-doc`
      );
    } catch (error) {
      throw new ValidationError(`Errore salvataggio documento: ${error.message}`);
    }

    // Aggiorna documentazioneUrl
    donazione.documentazioneUrl = documentazioneUrl;
    donazione.dataAggiornamento = new Date();
    if (tipoDocumento) {
      // Aggiungi tipoDocumento a noteOperatore o campo separato
      donazione.noteOperatore = donazione.noteOperatore
        ? `${donazione.noteOperatore}\n[Tipo documento: ${tipoDocumento}]`
        : `[Tipo documento: ${tipoDocumento}]`;
    }

    await donazione.save();

    // Formatta risposta
    const donationResponse = await formatAdminDonationResponse(donazione);

    logger.info(
      `Documentazione allegata a donazione ${id} da operatore ${operatoreId}`
    );

    res.json({
      success: true,
      data: {
        donation: donationResponse,
      },
    });
  } catch (error) {
    next(error);
  }
}

export default {
  getAllDonations,
  updateDonationStatus,
  contactDonator,
  attachDocument,
};

