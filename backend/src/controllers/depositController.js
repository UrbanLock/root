import Noleggio from '../models/Noleggio.js';
import Cell from '../models/Cell.js';
import Locker from '../models/Locker.js';
import User from '../models/User.js';
import mongoose from 'mongoose';
import {
  NotFoundError,
  ValidationError,
  UnauthorizedError,
} from '../middleware/errorHandler.js';
import logger from '../utils/logger.js';
import { savePhoto } from '../utils/photoStorage.js';
import {
  processMockPayment,
  validatePaymentAmount,
  calculatePaymentAmount,
} from '../services/paymentService.js';
import { notifyAperturaChiusura } from '../services/notificationService.js';

/**
 * Tariffe per grandezza cella (da Sezione 3)
 */
const TARIFFE = {
  piccola: { perOra: 0.5, perGiorno: 5 },
  media: { perOra: 1, perGiorno: 10 },
  grande: { perOra: 2, perGiorno: 20 },
  extra_large: { perOra: 3, perGiorno: 30 },
};

/**
 * Estrai numero cella da cellaId
 * Es. "CEL-001-1" → "Cella 1"
 */
function estraiNumeroCella(cellaId) {
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
 * Parsa durata da stringa (es. "1h", "24h", "7d")
 * @param {string} durationString - Durata in formato "1h" o "7d"
 * @returns {{hours: number, days: number, milliseconds: number} | null}
 */
function parseDuration(durationString) {
  if (!durationString || typeof durationString !== 'string') {
    return null;
  }

  const regex = /^(\d+)(h|d)$/;
  const match = durationString.trim().toLowerCase().match(regex);

  if (!match) {
    return null;
  }

  const number = parseInt(match[1], 10);
  const unit = match[2];

  if (number <= 0) {
    return null;
  }

  if (unit === 'h') {
    return {
      hours: number,
      days: 0,
      milliseconds: number * 3600000, // ore * 3600000 ms
    };
  } else if (unit === 'd') {
    return {
      hours: 0,
      days: number,
      milliseconds: number * 86400000, // giorni * 86400000 ms
    };
  }

  return null;
}

/**
 * Valida durata (minimo 1h, massimo 30d)
 */
function validateDuration(duration) {
  const parsed = parseDuration(duration);
  if (!parsed) {
    throw new ValidationError(
      'Durata non valida. Formato: "1h" (ore) o "7d" (giorni). Es: "1h", "24h", "7d"'
    );
  }

  // Converti tutto in ore per validazione
  const totalHours = parsed.hours + parsed.days * 24;

  if (totalHours < 1) {
    throw new ValidationError('Durata minima: 1 ora');
  }

  if (totalHours > 30 * 24) {
    throw new ValidationError('Durata massima: 30 giorni');
  }

  return parsed;
}

/**
 * Calcola costo basato su grandezza cella e durata
 */
function calcolaCosto(grandezza, duration) {
  const tariffa = TARIFFE[grandezza] || TARIFFE.media;
  const parsed = parseDuration(duration);

  if (!parsed) {
    // Default: 1 ora
    return tariffa.perOra;
  }

  let costo = 0;

  if (parsed.hours > 0) {
    // Calcolo per ore
    costo = tariffa.perOra * parsed.hours;
  } else if (parsed.days > 0) {
    // Calcolo per giorni
    costo = tariffa.perGiorno * parsed.days;
  } else {
    // Default: 1 ora
    costo = tariffa.perOra;
  }

  // Arrotonda a 2 decimali
  return Math.round(costo * 100) / 100;
}

/**
 * Formatta DepositResponse per frontend
 */
async function formattaDepositResponse(noleggio, options = {}) {
  const locker = await Locker.findOne({ lockerId: noleggio.lockerId }).lean();
  const cell = await Cell.findOne({ cellaId: noleggio.cellaId }).lean();

  const cellNumber = estraiNumeroCella(noleggio.cellaId);
  const status = noleggio.stato === 'attivo' ? 'active' : 'ended';

  // Calcola duration da dataInizio e dataFine
  let duration = null;
  if (noleggio.dataInizio && noleggio.dataFine) {
    const diffMs = noleggio.dataFine.getTime() - noleggio.dataInizio.getTime();
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffHours / 24);

    if (diffDays > 0) {
      duration = `${diffDays}d`;
    } else {
      duration = `${diffHours}h`;
    }
  } else if (noleggio.dataInizio) {
    // Se solo dataInizio, usa default 1h
    duration = '1h';
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
    cost: noleggio.costo || 0,
    qrCode: noleggio.qrCode || null,
    bluetoothToken: noleggio.bluetoothToken || null,
    status,
  };

  // Aggiungi campi opzionali
  if (options.remainingTime !== undefined) {
    response.remainingTime = options.remainingTime; // in millisecondi
  }

  if (options.finalCost !== undefined) {
    response.finalCost = options.finalCost;
  }

  if (options.extendedEndTime !== undefined) {
    response.extendedEndTime = options.extendedEndTime;
  }

  if (options.additionalCost !== undefined) {
    response.additionalCost = options.additionalCost;
  }

  if (options.totalCost !== undefined) {
    response.totalCost = options.totalCost;
  }

  return response;
}

/**
 * POST /api/v1/deposits
 * Crea nuovo deposito
 * RF3: Creazione deposito con registrazione automatica
 */
export async function createDeposit(req, res, next) {
  try {
    const { lockerId, cellaId, duration = '1h', photo, geolocalizzazione } = req.body;
    const userId = req.user.userId; // Da middleware auth (ObjectId come stringa)

    // Validazione
    if (!lockerId) {
      throw new ValidationError('lockerId è obbligatorio');
    }

    // Valida durata
    const parsedDuration = validateDuration(duration);

    // Verifica locker esista e sia attivo
    const locker = await Locker.findOne({ lockerId, stato: 'attivo' });
    if (!locker) {
      throw new NotFoundError(`Locker ${lockerId} non trovato o non attivo`);
    }

    // Trova cella disponibile
    let cell;
    if (cellaId) {
      // Se cellaId specificata, verifica che sia disponibile e tipo deposito
      cell = await Cell.findOne({
        cellaId,
        lockerId,
        tipo: 'deposito',
        stato: 'libera',
      });

      if (!cell) {
        throw new NotFoundError(
          `Cella ${cellaId} non disponibile o non di tipo deposito`
        );
      }
    } else {
      // Trova automatica cella deposito disponibile
      cell = await Cell.findOne({
        lockerId,
        tipo: 'deposito',
        stato: 'libera',
      });

      if (!cell) {
        throw new NotFoundError(
          `Nessuna cella deposito disponibile per locker ${lockerId}`
        );
      }
    }

    // Calcola costo
    const costo = calcolaCosto(cell.grandezza, duration);

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

    // Crea Noleggio
    const noleggio = new Noleggio({
      noleggioId,
      utenteId: userObjectId,
      cellaId: cell.cellaId,
      lockerId,
      tipo: 'deposito',
      stato: 'attivo',
      dataInizio,
      oraInizio,
      dataFine,
      oraFine,
      costo,
      qrCode: qrCode?.data || qrCode, // Se oggetto {data, image}, usa data
      bluetoothToken,
      geolocalizzazione: geolocalizzazione || null,
      fotoAnomalia,
    });

    await noleggio.save();

    // Aggiorna Cell stato a "occupata"
    cell.stato = 'occupata';
    await cell.save();

    // RF5: Notifica apertura cella
    try {
      await notifyAperturaChiusura(
        userObjectId,
        lockerId,
        cell.cellaId,
        'apertura',
        noleggioId
      );
    } catch (notificationError) {
      // Non bloccare la creazione del deposito se la notifica fallisce
      logger.warn(`Errore creazione notifica apertura per deposito ${noleggioId}:`, notificationError);
    }

    // Formatta risposta
    const depositResponse = await formattaDepositResponse(noleggio);

    logger.info(`Deposito creato: ${noleggioId} per utente ${userId}, costo: ${costo}€`);

    res.status(201).json({
      success: true,
      data: {
        deposit: depositResponse,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/deposits/active
 * Lista depositi attivi utente
 * RF3: Gestione depositi attivi
 */
export async function getActiveDeposits(req, res, next) {
  try {
    const userId = req.user.userId;

    // Converti userId (stringa) in ObjectId
    const userObjectId = new mongoose.Types.ObjectId(userId);

    // Trova tutti i depositi attivi per utente
    const noleggi = await Noleggio.find({
      utenteId: userObjectId,
      tipo: 'deposito',
      stato: 'attivo',
      tipo: 'deposito',
      stato: 'attivo',
    })
      .sort({ dataInizio: -1 })
      .lean();

    // Formatta risposte
    const deposits = await Promise.all(
      noleggi.map(async (noleggio) => {
        const now = new Date();
        const endTime = noleggio.dataFine || new Date(noleggio.dataInizio.getTime() + 3600000); // Default 1h se mancante
        const remainingTime = Math.max(0, endTime.getTime() - now.getTime());

        return formattaDepositResponse(noleggio, {
          remainingTime: remainingTime > 0 ? remainingTime : 0,
        });
      })
    );

    logger.info(`Depositi attivi recuperati: ${deposits.length} per utente ${userId}`);

    res.json({
      success: true,
      data: {
        deposits,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * PUT /api/v1/deposits/:id/end
 * Termina deposito (ritiro)
 * RF3: Terminazione deposito
 */
export async function endDeposit(req, res, next) {
  try {
    const { id } = req.params;
    const userId = req.user.userId;

    // Trova noleggio
    const noleggio = await Noleggio.findOne({ noleggioId: id });

    if (!noleggio) {
      throw new NotFoundError(`Deposito ${id} non trovato`);
    }

    // Verifica proprietà (confronta ObjectId)
    const userObjectId = new mongoose.Types.ObjectId(userId);
    if (!noleggio.utenteId.equals(userObjectId)) {
      throw new UnauthorizedError('Non autorizzato a terminare questo deposito');
    }

    // Verifica tipo
    if (noleggio.tipo !== 'deposito') {
      throw new ValidationError('Questo noleggio non è un deposito');
    }

    // Verifica stato
    if (noleggio.stato !== 'attivo') {
      throw new ValidationError(`Deposito già ${noleggio.stato}`);
    }

    // Termina noleggio
    const now = new Date();
    noleggio.stato = 'terminato';
    noleggio.dataFine = now;
    noleggio.oraFine = formatTime(now);
    noleggio.dataAggiornamento = now;

    // Calcola costo finale basato su durata effettiva
    const durataEffettivaMs = now.getTime() - noleggio.dataInizio.getTime();
    const durataEffettivaOre = durataEffettivaMs / 3600000;
    const cell = await Cell.findOne({ cellaId: noleggio.cellaId }).lean();
    const tariffa = TARIFFE[cell?.grandezza] || TARIFFE.media;
    const costoFinale = Math.max(tariffa.perOra, Math.round(tariffa.perOra * durataEffettivaOre * 100) / 100);

    noleggio.costo = costoFinale;
    await noleggio.save();

    // Aggiorna Cell stato a "libera"
    await Cell.updateOne({ cellaId: noleggio.cellaId }, { stato: 'libera' });

    // RF5: Notifica chiusura cella
    try {
      await notifyAperturaChiusura(
        userObjectId,
        noleggio.lockerId,
        noleggio.cellaId,
        'chiusura',
        noleggio.noleggioId
      );
    } catch (notificationError) {
      // Non bloccare la chiusura del deposito se la notifica fallisce
      logger.warn(`Errore creazione notifica chiusura per deposito ${id}:`, notificationError);
    }

    // Formatta risposta
    const depositResponse = await formattaDepositResponse(noleggio, {
      finalCost: costoFinale,
    });

    logger.info(`Deposito terminato: ${id}, costo finale: ${costoFinale}€`);

    res.json({
      success: true,
      data: {
        deposit: depositResponse,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * PUT /api/v1/deposits/:id/extend
 * Estende durata deposito
 * RF3: Estensione durata deposito
 */
export async function extendDeposit(req, res, next) {
  try {
    const { id } = req.params;
    const { duration } = req.body;
    const userId = req.user.userId;

    if (!duration) {
      throw new ValidationError('duration è obbligatorio');
    }

    // Valida durata
    const parsedDuration = validateDuration(duration);

    // Trova noleggio
    const noleggio = await Noleggio.findOne({ noleggioId: id });

    if (!noleggio) {
      throw new NotFoundError(`Deposito ${id} non trovato`);
    }

    // Verifica proprietà
    if (noleggio.utenteId.toString() !== userId) {
      throw new UnauthorizedError('Non autorizzato a estendere questo deposito');
    }

    // Verifica tipo
    if (noleggio.tipo !== 'deposito') {
      throw new ValidationError('Questo noleggio non è un deposito');
    }

    // Verifica stato
    if (noleggio.stato !== 'attivo') {
      throw new ValidationError(`Deposito non attivo (stato: ${noleggio.stato})`);
    }

    // Calcola nuovo endTime
    const currentEndTime = noleggio.dataFine || new Date(noleggio.dataInizio.getTime() + 3600000);
    const extendedEndTime = new Date(currentEndTime.getTime() + parsedDuration.milliseconds);
    const extendedOraFine = formatTime(extendedEndTime);

    // Calcola costo aggiuntivo
    const cell = await Cell.findOne({ cellaId: noleggio.cellaId }).lean();
    const additionalCost = calcolaCosto(cell?.grandezza || 'media', duration);

    // Aggiorna noleggio
    noleggio.dataFine = extendedEndTime;
    noleggio.oraFine = extendedOraFine;
    noleggio.costo = (noleggio.costo || 0) + additionalCost;
    noleggio.dataAggiornamento = new Date();
    await noleggio.save();

    // Formatta risposta
    const depositResponse = await formattaDepositResponse(noleggio, {
      extendedEndTime,
      additionalCost,
      totalCost: noleggio.costo,
    });

    logger.info(
      `Deposito esteso: ${id}, durata aggiuntiva: ${duration}, costo aggiuntivo: ${additionalCost}€`
    );

    res.json({
      success: true,
      data: {
        deposit: depositResponse,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * POST /api/v1/payments
 * Processa pagamento (mock)
 * RF3: Processamento pagamento (mock)
 * NOTA: Nessuna transazione bancaria reale, nessun dato sensibile
 */
export async function processPayment(req, res, next) {
  try {
    const { depositId, amount, paymentMethod = 'mock_card' } = req.body;
    const userId = req.user.userId;

    if (!depositId) {
      throw new ValidationError('depositId è obbligatorio');
    }

    // Valida paymentMethod
    const validMethods = ['mock_card', 'mock_wallet', 'mock_bank'];
    if (!validMethods.includes(paymentMethod)) {
      throw new ValidationError(
        `paymentMethod non valido. Valori accettati: ${validMethods.join(', ')}`
      );
    }

    // Trova noleggio
    const noleggio = await Noleggio.findOne({ noleggioId: depositId });

    if (!noleggio) {
      throw new NotFoundError(`Deposito ${depositId} non trovato`);
    }

    // Verifica proprietà
    if (noleggio.utenteId.toString() !== userId) {
      throw new UnauthorizedError('Non autorizzato a pagare questo deposito');
    }

    // Verifica tipo
    if (noleggio.tipo !== 'deposito') {
      throw new ValidationError('Questo noleggio non è un deposito');
    }

    // Verifica stato
    if (noleggio.stato !== 'attivo' && noleggio.stato !== 'terminato') {
      throw new ValidationError(`Deposito non può essere pagato (stato: ${noleggio.stato})`);
    }

    // Calcola amount se non specificato
    let paymentAmount = amount;
    if (!paymentAmount) {
      paymentAmount = calculatePaymentAmount(noleggio);
    }

    // Valida amount
    const expectedAmount = calculatePaymentAmount(noleggio);
    const validation = validatePaymentAmount(paymentAmount, expectedAmount);
    if (!validation.valid) {
      throw new ValidationError(validation.error);
    }

    // Processa pagamento mock
    const paymentResult = await processMockPayment(paymentAmount, paymentMethod, depositId);

    logger.info(
      `Pagamento processato: ${paymentResult.paymentId} per deposito ${depositId}, amount: ${paymentAmount}€`
    );

    res.json({
      success: true,
      data: {
        payment: {
          paymentId: paymentResult.paymentId,
          transactionId: paymentResult.transactionId,
          depositId,
          amount: paymentAmount,
          paymentMethod,
          status: paymentResult.status,
          timestamp: paymentResult.timestamp,
        },
      },
    });
  } catch (error) {
    next(error);
  }
}

export default {
  createDeposit,
  getActiveDeposits,
  endDeposit,
  extendDeposit,
  processPayment,
};

