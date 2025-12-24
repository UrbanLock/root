import Noleggio from '../models/Noleggio.js';
import Cell from '../models/Cell.js';
import Locker from '../models/Locker.js';
import mongoose from 'mongoose';
import {
  NotFoundError,
  ValidationError,
  UnauthorizedError,
} from '../middleware/errorHandler.js';
import logger from '../utils/logger.js';
import { savePhoto } from '../utils/photoStorage.js';

/**
 * Estrai numero cella da cellaId
 * Es. "CEL-001-1" → "Cella 1"
 */
function extractCellNumber(cellaId) {
  const match = cellaId.match(/CEL-[\w-]+-(\d+)/);
  if (match) {
    return `Cella ${parseInt(match[1], 10)}`;
  }
  return cellaId; // Fallback
}

/**
 * Formatta ora in HH:mm
 */
function formatTime(date) {
  const hours = date.getHours().toString().padStart(2, '0');
  const minutes = date.getMinutes().toString().padStart(2, '0');
  return `${hours}:${minutes}`;
}

/**
 * Parsa durata prestiti da stringa (solo giorni, es. "1d", "7d", "14d")
 * @param {string} durationString - Durata in formato "1d" o "7d"
 * @returns {{days: number, milliseconds: number} | null}
 */
function parseBorrowDuration(durationString) {
  if (!durationString || typeof durationString !== 'string') {
    return null;
  }

  const regex = /^(\d+)(d)$/;
  const match = durationString.trim().toLowerCase().match(regex);

  if (!match) {
    return null;
  }

  const number = parseInt(match[1], 10);
  const unit = match[2];

  if (number <= 0) {
    return null;
  }

  if (unit === 'd') {
    return {
      days: number,
      milliseconds: number * 86400000, // giorni * 86400000 ms
    };
  }

  return null;
}

/**
 * Valida durata prestiti (minimo 1d, massimo 30d, solo giorni)
 */
function validateBorrowDuration(duration) {
  const parsed = parseBorrowDuration(duration);
  if (!parsed) {
    throw new ValidationError(
      'Durata non valida. Formato: "1d" (giorni). Es: "1d", "7d", "14d", "30d". Prestiti usano solo giorni, non ore.'
    );
  }

  if (parsed.days < 1) {
    throw new ValidationError('Durata minimo 1 giorno');
  }

  if (parsed.days > 30) {
    throw new ValidationError('Durata massimo 30 giorni');
  }

  return parsed;
}

/**
 * Formatta BorrowResponse per frontend
 */
async function formatBorrowResponse(noleggio, options = {}) {
  const locker = await Locker.findOne({ lockerId: noleggio.lockerId }).lean();
  const cell = await Cell.findOne({ cellaId: noleggio.cellaId }).lean();

  const cellNumber = extractCellNumber(noleggio.cellaId);
  const status = noleggio.stato === 'attivo' ? 'active' : 'returned';

  // Calcola duration da dataInizio e dataFine
  let duration = null;
  if (noleggio.dataInizio && noleggio.dataFine) {
    const diffMs = noleggio.dataFine.getTime() - noleggio.dataInizio.getTime();
    const diffDays = Math.floor(diffMs / 86400000);
    duration = `${diffDays}d`;
  } else if (noleggio.dataInizio) {
    // Se solo dataInizio, usa default 7d
    duration = '7d';
  }

  const response = {
    id: noleggio.noleggioId,
    lockerId: noleggio.lockerId,
    lockerName: locker?.nome || null,
    cellId: noleggio.cellaId,
    cellNumber,
    startTime: noleggio.dataInizio,
    endTime: noleggio.dataFine || null,
    duration,
    cost: 0, // Prestiti sempre gratuiti
    qrCode: noleggio.qrCode || null,
    bluetoothToken: noleggio.bluetoothToken || null,
    status,
  };

  // Aggiungi campi opzionali
  if (options.tipoOggetto !== undefined) {
    response.tipoOggetto = options.tipoOggetto;
  }

  if (options.descrizione !== undefined) {
    response.descrizione = options.descrizione;
  }

  if (options.remainingTime !== undefined) {
    response.remainingTime = options.remainingTime; // in millisecondi
  }

  if (options.photoUrl !== undefined) {
    response.photoUrl = options.photoUrl;
  }

  return response;
}

/**
 * Formatta AvailableBorrowResponse per frontend
 */
function formatAvailableBorrowResponse(cell, locker) {
  const cellNumber = extractCellNumber(cell.cellaId);

  return {
    cellaId: cell.cellaId,
    lockerId: cell.lockerId,
    lockerName: locker?.nome || null,
    lockerType: locker?.tipo || 'personali',
    lockerPosition: locker?.coordinate || null,
    cellNumber,
    grandezza: cell.grandezza,
    categoria: cell.categoria || null,
    richiedeFoto: cell.richiede_foto || false,
    isAvailable: cell.stato === 'libera',
  };
}

/**
 * GET /api/v1/borrows/available
 * Visualizza oggetti disponibili per prestito
 * RF3: Visualizzazione oggetti disponibili per prestito
 */
export async function getAvailableBorrows(req, res, next) {
  try {
    const { lockerId, categoria, grandezza } = req.query;

    // Query base: celle tipo "prestito" stato "libera"
    const query = {
      tipo: 'prestito',
      stato: 'libera',
    };

    // Filtri opzionali
    if (lockerId) {
      query.lockerId = lockerId;
    }

    if (categoria) {
      query.categoria = categoria;
    }

    if (grandezza) {
      query.grandezza = grandezza;
    }

    // Trova celle disponibili
    const cells = await Cell.find(query).lean();

    // Raggruppa per lockerId per popolare locker
    const lockerIds = [...new Set(cells.map((c) => c.lockerId))];
    const lockers = await Locker.find({ lockerId: { $in: lockerIds } }).lean();
    const lockerMap = new Map(lockers.map((l) => [l.lockerId, l]));

    // Formatta risposta
    const availableBorrows = cells.map((cell) => {
      const locker = lockerMap.get(cell.lockerId);
      return formatAvailableBorrowResponse(cell, locker);
    });

    // Ordina per lockerId e cellaId
    availableBorrows.sort((a, b) => {
      if (a.lockerId !== b.lockerId) {
        return a.lockerId.localeCompare(b.lockerId);
      }
      return a.cellaId.localeCompare(b.cellaId);
    });

    logger.info(
      `Oggetti disponibili per prestito trovati: ${availableBorrows.length} (filtri: lockerId=${lockerId || 'tutti'}, categoria=${categoria || 'tutte'}, grandezza=${grandezza || 'tutte'})`
    );

    res.json({
      success: true,
      data: {
        availableBorrows,
        count: availableBorrows.length,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * POST /api/v1/borrows
 * Richiedere prestito oggetto
 * RF3: Creazione prestito con registrazione automatica
 * RF4: Richiesta prestito oggetto
 */
export async function createBorrow(req, res, next) {
  try {
    const {
      lockerId,
      cellaId,
      tipoOggetto,
      descrizione,
      duration = '7d',
      photo,
      geolocalizzazione,
    } = req.body;
    const userId = req.user.userId; // Da middleware auth (ObjectId come stringa)

    // Validazione
    if (!lockerId) {
      throw new ValidationError('lockerId è obbligatorio');
    }

    // Valida durata (solo giorni)
    const parsedDuration = validateBorrowDuration(duration);

    // Verifica locker esista e sia attivo
    const locker = await Locker.findOne({ lockerId, stato: 'attivo' });
    if (!locker) {
      throw new NotFoundError(`Locker ${lockerId} non trovato o non attivo`);
    }

    // Trova cella disponibile
    let cell;
    if (cellaId) {
      // Se cellaId specificata, verifica che sia disponibile e tipo prestito
      cell = await Cell.findOne({
        cellaId,
        lockerId,
        tipo: 'prestito',
        stato: 'libera',
      });

      if (!cell) {
        throw new NotFoundError(
          `Cella ${cellaId} non disponibile o non di tipo prestito`
        );
      }
    } else {
      // Trova automatica cella prestito disponibile
      cell = await Cell.findOne({
        lockerId,
        tipo: 'prestito',
        stato: 'libera',
      });

      if (!cell) {
        throw new NotFoundError(
          `Nessuna cella prestito disponibile per locker ${lockerId}`
        );
      }
    }

    // Calcola endTime
    const now = new Date();
    const dataInizio = now;
    const oraInizio = formatTime(now);
    const dataFine = new Date(now.getTime() + parsedDuration.milliseconds);
    const oraFine = formatTime(dataFine);

    // Genera noleggioId
    const noleggioId = await Noleggio.generateNoleggioId();

    // Genera QR code e Bluetooth token (implementazione reale)
    const qrCode = await Noleggio.generateQRCode(noleggioId, cell.cellaId, lockerId);
    const bluetoothToken = Noleggio.generateBluetoothToken();

    // Salva foto anomalia se presente
    let fotoAnomalia = null;
    if (photo) {
      fotoAnomalia = await savePhoto(photo, noleggioId);
    }

    // Converti userId (stringa) in ObjectId
    const userObjectId = new mongoose.Types.ObjectId(userId);

    // Crea Noleggio (prestito, costo = 0)
    const noleggio = new Noleggio({
      noleggioId,
      utenteId: userObjectId,
      cellaId: cell.cellaId,
      lockerId,
      tipo: 'prestito',
      stato: 'attivo',
      dataInizio,
      oraInizio,
      dataFine,
      oraFine,
      costo: 0, // Prestiti sempre gratuiti
      qrCode: qrCode?.data || qrCode, // Se oggetto {data, image}, usa data
      bluetoothToken,
      geolocalizzazione: geolocalizzazione || null,
      fotoAnomalia,
    });

    await noleggio.save();

    // Aggiorna Cell stato a "occupata"
    cell.stato = 'occupata';
    await cell.save();

    // Formatta risposta
    const borrowResponse = await formatBorrowResponse(noleggio, {
      tipoOggetto: tipoOggetto || null,
      descrizione: descrizione || null,
    });

    logger.info(
      `Prestito creato: ${noleggioId} per utente ${userId}, durata: ${duration}`
    );

    res.status(201).json({
      success: true,
      data: {
        borrow: borrowResponse,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * POST /api/v1/borrows/:id/return
 * Restituire oggetto
 * RF3: Restituzione prestito
 * RF4: Restituzione vano con verifica foto obbligatoria
 */
export async function returnBorrow(req, res, next) {
  try {
    const { id } = req.params;
    const { photo } = req.body;
    const userId = req.user.userId;

    // Trova noleggio
    const noleggio = await Noleggio.findOne({ noleggioId: id });

    if (!noleggio) {
      throw new NotFoundError(`Prestito ${id} non trovato`);
    }

    // Verifica proprietà
    if (noleggio.utenteId.toString() !== userId) {
      throw new UnauthorizedError('Non autorizzato a restituire questo prestito');
    }

    // Verifica tipo
    if (noleggio.tipo !== 'prestito') {
      throw new ValidationError('Questo noleggio non è un prestito');
    }

    // Verifica stato
    if (noleggio.stato !== 'attivo') {
      throw new ValidationError(`Prestito non attivo (stato: ${noleggio.stato})`);
    }

    // Trova Cell associata
    const cell = await Cell.findOne({ cellaId: noleggio.cellaId });

    if (!cell) {
      throw new NotFoundError(`Cella ${noleggio.cellaId} non trovata`);
    }

    // RF4: Verifica foto obbligatoria se cella richiede_foto === true
    let fotoUrl = null;
    if (cell.richiede_foto === true) {
      if (!photo) {
        throw new ValidationError(
          'Foto obbligatoria per la restituzione. Questa cella richiede una foto per verificare lo stato dell\'oggetto.'
        );
      }
      // Salva foto restituzione
      fotoUrl = await savePhoto(photo, noleggio.noleggioId);
    } else if (photo) {
      // Foto opzionale se richiede_foto === false, ma se presente la salva
      fotoUrl = await savePhoto(photo, noleggio.noleggioId);
    }

    // Termina noleggio
    const now = new Date();
    noleggio.stato = 'terminato';
    noleggio.dataFine = now;
    noleggio.oraFine = formatTime(now);
    noleggio.dataAggiornamento = new Date();

    // Aggiorna fotoAnomalia se foto presente
    if (fotoUrl) {
      noleggio.fotoAnomalia = fotoUrl;
    }

    await noleggio.save();

    // Aggiorna Cell stato a "libera"
    cell.stato = 'libera';
    await cell.save();

    // Formatta risposta
    const borrowResponse = await formatBorrowResponse(noleggio, {
      tipoOggetto: null, // Non salvato nel modello, ma potrebbe essere esteso
      descrizione: null,
      photoUrl: fotoUrl || null,
    });

    logger.info(
      `Prestito restituito: ${id} per utente ${userId}${fotoUrl ? ' (con foto)' : ''}`
    );

    res.json({
      success: true,
      data: {
        borrow: borrowResponse,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/borrows/active
 * Lista prestiti attivi utente
 * RF3: Gestione prestiti attivi
 * RF4: Prestiti attivi utente
 */
export async function getActiveBorrows(req, res, next) {
  try {
    const userId = req.user.userId;

    // Converti userId (stringa) in ObjectId
    const userObjectId = new mongoose.Types.ObjectId(userId);

    // Trova tutti i prestiti attivi per utente
    const noleggi = await Noleggio.find({
      utenteId: userObjectId,
      tipo: 'prestito',
      stato: 'attivo',
    })
      .sort({ dataInizio: -1 }) // DESC
      .lean();

    // Popola locker per ogni noleggio
    const lockerIds = [...new Set(noleggi.map((n) => n.lockerId))];
    const lockers = await Locker.find({ lockerId: { $in: lockerIds } }).lean();
    const lockerMap = new Map(lockers.map((l) => [l.lockerId, l]));

    // Formatta risposte
    const borrows = await Promise.all(
      noleggi.map(async (noleggio) => {
        const locker = lockerMap.get(noleggio.lockerId);
        const borrowResponse = await formatBorrowResponse(noleggio, {
          tipoOggetto: null,
          descrizione: null,
        });

        // Calcola tempo rimanente
        if (noleggio.dataFine) {
          const now = new Date();
          const remainingTime = noleggio.dataFine.getTime() - now.getTime();
          borrowResponse.remainingTime = remainingTime > 0 ? remainingTime : 0;
        }

        return borrowResponse;
      })
    );

    logger.info(`Prestiti attivi trovati per utente ${userId}: ${borrows.length}`);

    res.json({
      success: true,
      data: {
        borrows,
        count: borrows.length,
      },
    });
  } catch (error) {
    next(error);
  }
}

export default {
  getAvailableBorrows,
  createBorrow,
  returnBorrow,
  getActiveBorrows,
};

