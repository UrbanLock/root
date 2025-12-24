import Donazione from '../models/Donazione.js';
import Locker from '../models/Locker.js';
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
 * Formatta Donazione come DonationResponse per frontend
 */
async function formatDonationResponse(donazione, options = {}) {
  const response = {
    id: donazione.donazioneId,
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
  };

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
 * POST /api/v1/donations
 * Creare donazione
 * RF6: Creare donazione
 */
export async function createDonation(req, res, next) {
  try {
    const {
      nomeOggetto,
      tipoAttrezzatura,
      categoria,
      descrizione,
      photo,
      lockerId,
    } = req.body;
    const userId = req.user.userId;

    // Converti userId (stringa) in ObjectId
    const userObjectId = new mongoose.Types.ObjectId(userId);

    // Validazione campi obbligatori
    if (!nomeOggetto) {
      throw new ValidationError('nomeOggetto è obbligatorio');
    }
    if (!tipoAttrezzatura) {
      throw new ValidationError('tipoAttrezzatura è obbligatorio');
    }
    if (!descrizione) {
      throw new ValidationError('descrizione è obbligatoria');
    }

    // Valida tipoAttrezzatura
    const tipiValidi = [
      'sportiva',
      'elettronica',
      'abbigliamento',
      'libri',
      'giochi',
      'altro',
    ];
    if (!tipiValidi.includes(tipoAttrezzatura)) {
      throw new ValidationError(
        `tipoAttrezzatura non valido. Valori accettati: ${tipiValidi.join(', ')}`
      );
    }

    // Valida lockerId se presente
    if (lockerId) {
      const locker = await Locker.findOne({
        lockerId,
        stato: 'attivo',
      }).lean();
      if (!locker) {
        throw new NotFoundError(`Locker ${lockerId} non trovato o non attivo`);
      }
    }

    // Genera donazioneId prima di salvare foto
    const donazioneId = await Donazione.generateDonazioneId();

    // Salva foto se presente
    let fotoUrl = null;
    if (photo) {
      try {
        fotoUrl = await savePhoto(photo, donazioneId);
      } catch (error) {
        throw new ValidationError(`Errore salvataggio foto: ${error.message}`);
      }
    }

    // Crea Donazione
    const donazione = new Donazione({
      donazioneId,
      utenteId: userObjectId,
      lockerId: lockerId || null,
      cellaId: null,
      nomeOggetto,
      tipoAttrezzatura,
      categoria: categoria || null,
      descrizione,
      fotoUrl,
      stato: 'da_visionare',
      dataCreazione: new Date(),
      dataRitiro: null,
      motivoRifiuto: null,
      operatoreAssegnatoId: null,
      documentazioneUrl: null,
      noteOperatore: null,
      dataAggiornamento: new Date(),
    });

    await donazione.save();

    // Formatta risposta
    const donationResponse = await formatDonationResponse(donazione);

    logger.info(`Donazione creata: ${donazioneId} per utente ${userId}`);

    res.status(201).json({
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
 * GET /api/v1/donations
 * Lista donazioni utente
 * RF6: Lista donazioni utente
 */
export async function getDonations(req, res, next) {
  try {
    const userId = req.user.userId;
    const { page = 1, limit = 20, status } = req.query;

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
      donazioni.map((donazione) => formatDonationResponse(donazione))
    );

    // Calcola total per paginazione
    const total = await Donazione.countDocuments(query);
    const totalPages = Math.ceil(total / limitNum);

    logger.info(
      `Donazioni recuperate per utente ${userId}: ${items.length} items (page ${pageNum}/${totalPages})`
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
 * GET /api/v1/donations/:id
 * Dettaglio donazione
 * RF6: Dettaglio donazione
 */
export async function getDonationById(req, res, next) {
  try {
    const userId = req.user.userId;
    const { id } = req.params;

    // Converti userId (stringa) in ObjectId
    const userObjectId = new mongoose.Types.ObjectId(userId);

    // Trova Donazione per donazioneId e utenteId (verifica ownership)
    const donazione = await Donazione.findOne({
      donazioneId: id,
      utenteId: userObjectId,
    }).lean();

    if (!donazione) {
      throw new NotFoundError('Donazione non trovata');
    }

    // Formatta risposta
    const donationResponse = await formatDonationResponse(donazione);

    logger.info(`Dettaglio donazione ${id} recuperato per utente ${userId}`);

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
 * PUT /api/v1/donations/:id
 * Modificare donazione
 * RF6: Modificare donazione
 */
export async function updateDonation(req, res, next) {
  try {
    const userId = req.user.userId;
    const { id } = req.params;
    const { nomeOggetto, tipoAttrezzatura, categoria, descrizione, photo } =
      req.body;

    // Converti userId (stringa) in ObjectId
    const userObjectId = new mongoose.Types.ObjectId(userId);

    // Trova Donazione per donazioneId e utenteId (verifica ownership)
    const donazione = await Donazione.findOne({
      donazioneId: id,
      utenteId: userObjectId,
    });

    if (!donazione) {
      throw new NotFoundError('Donazione non trovata');
    }

    // Verifica stato: solo "da_visionare" può essere modificata
    if (donazione.stato !== 'da_visionare') {
      throw new ValidationError(
        `Non è possibile modificare donazione in stato ${donazione.stato}`
      );
    }

    // Valida tipoAttrezzatura se presente
    if (tipoAttrezzatura) {
      const tipiValidi = [
        'sportiva',
        'elettronica',
        'abbigliamento',
        'libri',
        'giochi',
        'altro',
      ];
      if (!tipiValidi.includes(tipoAttrezzatura)) {
        throw new ValidationError(
          `tipoAttrezzatura non valido. Valori accettati: ${tipiValidi.join(', ')}`
        );
      }
    }

    // Aggiorna solo campi presenti nel body
    if (nomeOggetto !== undefined) {
      donazione.nomeOggetto = nomeOggetto;
    }
    if (tipoAttrezzatura !== undefined) {
      donazione.tipoAttrezzatura = tipoAttrezzatura;
    }
    if (categoria !== undefined) {
      donazione.categoria = categoria || null;
    }
    if (descrizione !== undefined) {
      donazione.descrizione = descrizione;
    }

    // Gestione foto: se presente, salva nuova foto (sostituisce esistente)
    if (photo) {
      try {
        // Elimina foto esistente se presente
        if (donazione.fotoUrl) {
          await deletePhoto(donazione.fotoUrl);
        }

        // Salva nuova foto
        const nuovaFotoUrl = await savePhoto(photo, donazione.donazioneId);
        donazione.fotoUrl = nuovaFotoUrl;
      } catch (error) {
        throw new ValidationError(`Errore salvataggio foto: ${error.message}`);
      }
    }

    donazione.dataAggiornamento = new Date();
    await donazione.save();

    // Formatta risposta
    const donationResponse = await formatDonationResponse(donazione);

    logger.info(`Donazione ${id} aggiornata per utente ${userId}`);

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
 * DELETE /api/v1/donations/:id
 * Cancellare donazione
 * RF6: Cancellare donazione
 */
export async function deleteDonation(req, res, next) {
  try {
    const userId = req.user.userId;
    const { id } = req.params;

    // Converti userId (stringa) in ObjectId
    const userObjectId = new mongoose.Types.ObjectId(userId);

    // Trova Donazione per donazioneId e utenteId (verifica ownership)
    const donazione = await Donazione.findOne({
      donazioneId: id,
      utenteId: userObjectId,
    });

    if (!donazione) {
      throw new NotFoundError('Donazione non trovata');
    }

    // Verifica stato: solo "da_visionare" può essere cancellata
    if (donazione.stato !== 'da_visionare') {
      throw new ValidationError(
        `Non è possibile cancellare donazione in stato ${donazione.stato}`
      );
    }

    // Elimina foto associata se presente
    if (donazione.fotoUrl) {
      try {
        await deletePhoto(donazione.fotoUrl);
      } catch (error) {
        logger.warn(`Errore eliminazione foto per donazione ${id}:`, error);
        // Non bloccare eliminazione se foto non eliminata
      }
    }

    // Elimina Donazione
    await Donazione.deleteOne({ _id: donazione._id });

    logger.info(`Donazione ${id} eliminata per utente ${userId}`);

    res.json({
      success: true,
      data: {
        message: 'Donazione eliminata con successo',
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * POST /api/v1/donations/:id/schedule-pickup
 * Concordare data/orario ritiro
 * RF6: Concordare data/orario ritiro
 */
export async function schedulePickup(req, res, next) {
  try {
    const userId = req.user.userId;
    const { id } = req.params;
    const { dataRitiro, note } = req.body;

    // Converti userId (stringa) in ObjectId
    const userObjectId = new mongoose.Types.ObjectId(userId);

    // Validazione dataRitiro
    if (!dataRitiro) {
      throw new ValidationError('dataRitiro è obbligatoria');
    }

    const dataRitiroParsed = new Date(dataRitiro);
    if (isNaN(dataRitiroParsed.getTime())) {
      throw new ValidationError('dataRitiro non valida');
    }

    // Verifica che dataRitiro sia futura
    const now = new Date();
    if (dataRitiroParsed <= now) {
      throw new ValidationError('dataRitiro deve essere una data futura');
    }

    // Trova Donazione per donazioneId e utenteId (verifica ownership)
    const donazione = await Donazione.findOne({
      donazioneId: id,
      utenteId: userObjectId,
    });

    if (!donazione) {
      throw new NotFoundError('Donazione non trovata');
    }

    // Verifica stato: solo "in_valutazione" può concordare ritiro
    if (donazione.stato !== 'in_valutazione') {
      throw new ValidationError(
        `Non è possibile concordare ritiro per donazione in stato ${donazione.stato}`
      );
    }

    // Aggiorna dataRitiro e stato
    donazione.dataRitiro = dataRitiroParsed;
    donazione.stato = 'in_ritiro';
    donazione.dataAggiornamento = new Date();
    if (note) {
      // Aggiungi note a noteOperatore se presente, altrimenti crea campo temporaneo
      donazione.noteOperatore = note;
    }

    await donazione.save();

    // Formatta risposta
    const donationResponse = await formatDonationResponse(donazione);

    logger.info(
      `Ritiro concordato per donazione ${id}: ${dataRitiroParsed.toISOString()}`
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
  createDonation,
  getDonations,
  getDonationById,
  updateDonation,
  deleteDonation,
  schedulePickup,
};

