import Noleggio from '../models/Noleggio.js';
import Cell from '../models/Cell.js';
import Locker from '../models/Locker.js';
import {
  NotFoundError,
  ValidationError,
  UnauthorizedError,
} from '../middleware/errorHandler.js';
import logger from '../utils/logger.js';
import { savePhoto } from '../utils/photoStorage.js';

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
 * Formatta ora in formato HH:mm
 */
function formatTime(date) {
  return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
}

/**
 * Calcola cellNumber da cellaId
 */
function extractCellNumber(cellaId) {
  const match = cellaId.match(/CEL-[\w-]+-(\d+)/);
  if (match) {
    return `Cella ${parseInt(match[1], 10)}`;
  }
  return cellaId;
}

/**
 * Determina lockerType da locker
 */
function determinaLockerType(locker) {
  if (!locker) return 'personali';

  if (locker.tipo) {
    return locker.tipo;
  }

  // Mapping da dimensione se tipo non presente
  const dimensioneMapping = {
    small: 'personali',
    medium: 'personali',
    large: 'sportivi',
  };
  return dimensioneMapping[locker.dimensione] || 'personali';
}

/**
 * Mapping tipo DB → Frontend
 */
const TIPO_MAPPING = {
  deposito: 'deposited',
  prestito: 'borrow',
  ordini: 'pickup',
};

/**
 * Formatta noleggio come ActiveCell per frontend
 */
async function formatNoleggioAsActiveCell(noleggio) {
  const locker = await Locker.findOne({ lockerId: noleggio.lockerId }).lean();
  const cellNumber = extractCellNumber(noleggio.cellaId);
  const lockerType = determinaLockerType(locker);

  return {
    id: noleggio.noleggioId,
    lockerId: noleggio.lockerId,
    lockerName: locker?.nome || 'Locker',
    lockerType: lockerType,
    cellNumber: cellNumber,
    cellId: noleggio.cellaId,
    startTime: noleggio.dataInizio,
    endTime: noleggio.dataFine || null,
    type: TIPO_MAPPING[noleggio.tipo] || 'deposited',
  };
}

/**
 * POST /api/v1/cells/request
 * Richiedere nuova cella per deposito/prestito/pickup
 * RF3: Registrazione automatica giorno/orario/utente/ID armadietto
 */
export async function requestCell(req, res, next) {
  try {
    const { lockerId, type, photo } = req.body;
    const userId = req.user.userId; // Da middleware auth

    // Validazione input
    if (!lockerId) {
      throw new ValidationError('lockerId è obbligatorio');
    }

    if (!type) {
      throw new ValidationError('type è obbligatorio (deposited, borrow, pickup)');
    }

    const tipoMapping = {
      deposited: 'deposito',
      borrow: 'prestito',
      pickup: 'ordini',
    };

    const tipoDB = tipoMapping[type];
    if (!tipoDB) {
      throw new ValidationError(
        `type non valido. Valori accettati: ${Object.keys(tipoMapping).join(', ')}`
      );
    }

    // Trova cella disponibile per lockerId e tipo (stato "libera")
    const cell = await Cell.findOne({
      lockerId,
      tipo: tipoDB,
      stato: 'libera',
    });

    if (!cell) {
      throw new NotFoundError(
        `Nessuna cella disponibile per locker ${lockerId} e tipo ${type}`
      );
    }

    // Verifica che locker esista
    const locker = await Locker.findOne({ lockerId });
    if (!locker) {
      throw new NotFoundError(`Locker ${lockerId} non trovato`);
    }

    // RF3: Registra geolocalizzazione se presente
    const geolocalizzazione = req.body.geolocalizzazione || null;

    // RF3: Registrazione automatica
    const now = new Date();
    const dataInizio = now;
    const oraInizio = formatTime(now);

    // Calcola costo se tipo deposito
    let costo = 0;
    if (tipoDB === 'deposito') {
      // Calcolo costo basato su tariffe (default 1 ora)
      const tariffa = TARIFFE[cell.grandezza] || TARIFFE.media;
      costo = tariffa.perOra;
    }

    // Genera noleggioId (DEVE essere prima di generateQRCode)
    const noleggioId = await Noleggio.generateNoleggioId();

    // RF3: Genera QR code e Bluetooth token (implementazione reale)
    // Nota: qrCode può essere stringa o oggetto {data, image}
    const qrCode = await Noleggio.generateQRCode(noleggioId, cell.cellaId, lockerId);
    const bluetoothToken = Noleggio.generateBluetoothToken();

    // Crea Noleggio
    const noleggio = new Noleggio({
      noleggioId,
      utenteId: userId,
      cellaId: cell.cellaId,
      lockerId,
      tipo: tipoDB,
      stato: 'attivo',
      dataInizio,
      oraInizio,
      costo,
      qrCode,
      bluetoothToken,
      geolocalizzazione,
      // Salva foto su filesystem (implementazione reale)
      fotoAnomalia: photo ? await savePhoto(photo, noleggioId) : null,
    });

    await noleggio.save();

    // Aggiorna Cell stato a "occupata"
    cell.stato = 'occupata';
    await cell.save();

    // RF3: Log registrazione automatica
    logger.info(
      `Noleggio creato: ${noleggioId} - Utente: ${userId}, Cella: ${cell.cellaId}, Locker: ${lockerId}, Tipo: ${tipoDB}, Data: ${dataInizio.toISOString()}, Ora: ${oraInizio}`
    );

    // Formatta come ActiveCell per frontend
    const activeCell = await formatNoleggioAsActiveCell(noleggio);

    res.status(201).json({
      success: true,
      data: {
        cell: activeCell,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * POST /api/v1/cells/open
 * Sbloccare cella (apertura vano)
 * RF3: Scansione QR/Bluetooth, geolocalizzazione attiva, gestione errori
 */
export async function openCell(req, res, next) {
  try {
    const { cell_id, photo } = req.body;
    const userId = req.user.userId; // Da middleware auth

    if (!cell_id) {
      throw new ValidationError('cell_id è obbligatorio');
    }

    // Trova Noleggio per cellaId e utenteId (verifica proprietà)
    const noleggio = await Noleggio.findOne({
      cellaId: cell_id,
      utenteId: userId,
    });

    if (!noleggio) {
      throw new NotFoundError(
        `Noleggio non trovato per cella ${cell_id} e utente corrente`
      );
    }

    // Verifica stato "attivo"
    if (noleggio.stato !== 'attivo') {
      throw new ValidationError(
        `Noleggio ${noleggio.noleggioId} non è attivo (stato: ${noleggio.stato})`
      );
    }

    // Trova Cell per verificare richiede_foto
    const cell = await Cell.findOne({ cellaId: cell_id });
    if (!cell) {
      throw new NotFoundError(`Cella ${cell_id} non trovata`);
    }

    // RF3: Verifica foto se richiesta
    if (cell.richiede_foto && !photo) {
      throw new ValidationError(
        'Foto obbligatoria per questa cella (richiede_foto: true)'
      );
    }

    // RF3: Verifica QR/Bluetooth token se presente
    // Nota: qrCode può essere stringa o oggetto {data, image}
    if (noleggio.qrCode && req.body.qrCode) {
      const qrCodeData = typeof noleggio.qrCode === 'object' && noleggio.qrCode.data
        ? noleggio.qrCode.data
        : noleggio.qrCode;
      
      if (qrCodeData !== req.body.qrCode) {
        throw new ValidationError('QR code non valido');
      }
    }

    if (noleggio.bluetoothToken && req.body.bluetoothToken) {
      if (noleggio.bluetoothToken !== req.body.bluetoothToken) {
        throw new ValidationError('Bluetooth token non valido');
      }
    }

    // RF3: Registra geolocalizzazione se presente
    if (req.body.geolocalizzazione) {
      noleggio.geolocalizzazione = req.body.geolocalizzazione;
    }

    // RF3: Salva foto anomalia se presente (implementazione reale)
    if (photo) {
      noleggio.fotoAnomalia = await savePhoto(photo, noleggio.noleggioId);
    }

    // Aggiorna dataAggiornamento
    noleggio.dataAggiornamento = new Date();
    await noleggio.save();

    logger.info(
      `Cella aperta: ${cell_id} - Noleggio: ${noleggio.noleggioId}, Utente: ${userId}`
    );

    // Estrai dati QR code (può essere stringa o oggetto con data/image)
    let qrCodeData = noleggio.qrCode;
    let qrCodeImage = null;
    if (typeof noleggio.qrCode === 'object' && noleggio.qrCode.data) {
      qrCodeData = noleggio.qrCode.data;
      qrCodeImage = noleggio.qrCode.image;
    }

    res.json({
      success: true,
      data: {
        cell_id: cell_id,
        door_opened: true,
        qrCode: qrCodeData,
        qrCodeImage: qrCodeImage, // Immagine base64 per visualizzazione
        bluetoothToken: noleggio.bluetoothToken,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * POST /api/v1/cells/close
 * Notificare chiusura sportello
 * RF3: Notifica chiusura sportello
 */
export async function closeCell(req, res, next) {
  try {
    const { cell_id, door_closed } = req.body;
    const userId = req.user.userId; // Da middleware auth

    if (!cell_id) {
      throw new ValidationError('cell_id è obbligatorio');
    }

    if (door_closed !== true) {
      throw new ValidationError('door_closed deve essere true');
    }

    // Trova Noleggio per cellaId e utenteId
    const noleggio = await Noleggio.findOne({
      cellaId: cell_id,
      utenteId: userId,
    });

    if (!noleggio) {
      throw new NotFoundError(
        `Noleggio non trovato per cella ${cell_id} e utente corrente`
      );
    }

    // Verifica stato "attivo"
    if (noleggio.stato !== 'attivo') {
      throw new ValidationError(
        `Noleggio ${noleggio.noleggioId} non è attivo (stato: ${noleggio.stato})`
      );
    }

    // Aggiorna dataAggiornamento (NON termina noleggio - rimane attivo per ritiro)
    noleggio.dataAggiornamento = new Date();
    await noleggio.save();

    logger.info(
      `Cella chiusa: ${cell_id} - Noleggio: ${noleggio.noleggioId}, Utente: ${userId}`
    );

    res.json({
      success: true,
      data: {
        cell_closed: true,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * POST /api/v1/cells/return
 * Restituire vano (per prestiti e ordini)
 * RF4: Restituzione vano
 */
export async function returnCell(req, res, next) {
  try {
    const { cell_id, photo } = req.body;
    const userId = req.user.userId; // Da middleware auth

    if (!cell_id) {
      throw new ValidationError('cell_id è obbligatorio');
    }

    // Trova Noleggio per cellaId e utenteId
    const noleggio = await Noleggio.findOne({
      cellaId: cell_id,
      utenteId: userId,
    });

    if (!noleggio) {
      throw new NotFoundError(
        `Noleggio non trovato per cella ${cell_id} e utente corrente`
      );
    }

    // Verifica tipo "prestito" o "ordini" (solo per restituzione)
    if (noleggio.tipo !== 'prestito' && noleggio.tipo !== 'ordini') {
      throw new ValidationError(
        `Restituzione valida solo per tipo "prestito" o "ordini" (tipo attuale: ${noleggio.tipo})`
      );
    }

    // Verifica stato "attivo"
    if (noleggio.stato !== 'attivo') {
      throw new ValidationError(
        `Noleggio ${noleggio.noleggioId} non è attivo (stato: ${noleggio.stato})`
      );
    }

    // Trova Cell per verificare richiede_foto
    const cell = await Cell.findOne({ cellaId: cell_id });
    if (!cell) {
      throw new NotFoundError(`Cella ${cell_id} non trovata`);
    }

    // RF4: Verifica foto se richiesta
    if (cell.richiede_foto && !photo) {
      throw new ValidationError(
        'Foto obbligatoria per restituzione (richiede_foto: true)'
      );
    }

    // RF4: Salva foto anomalia se presente (implementazione reale)
    if (photo) {
      noleggio.fotoAnomalia = await savePhoto(photo, noleggio.noleggioId);
    }

    // RF4: Termina noleggio
    const now = new Date();
    noleggio.stato = 'terminato';
    noleggio.dataFine = now;
    noleggio.oraFine = formatTime(now);
    noleggio.dataAggiornamento = now;

    // Calcola costo finale se necessario
    let finalCost = 0;
    if (noleggio.tipo === 'prestito') {
      // Per prestiti, costo può essere 0 o calcolato in base a durata
      finalCost = noleggio.costo || 0;
    }

    await noleggio.save();

    // RF4: Libera cella (Cell stato "libera")
    cell.stato = 'libera';
    await cell.save();

    logger.info(
      `Cella restituita: ${cell_id} - Noleggio: ${noleggio.noleggioId}, Utente: ${userId}, Tipo: ${noleggio.tipo}`
    );

    res.json({
      success: true,
      data: {
        cell_returned: true,
        finalCost: finalCost,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/cells/active
 * Lista celle attive utente
 * RF9: Base per storico
 */
export async function getActiveCells(req, res, next) {
  try {
    const userId = req.user.userId; // Da middleware auth

    // Trova tutti Noleggio per utenteId con stato "attivo"
    const noleggi = await Noleggio.find({
      utenteId: userId,
      stato: 'attivo',
    })
      .sort({ dataInizio: -1 }) // Ordina per dataInizio DESC
      .lean();

    // Formatta come ActiveCell array
    const activeCells = await Promise.all(
      noleggi.map((noleggio) => formatNoleggioAsActiveCell(noleggio))
    );

    logger.info(`Celle attive utente ${userId}: ${activeCells.length} trovate`);

    res.json({
      success: true,
      data: {
        cells: activeCells,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/cells/history
 * Storico utilizzi
 * RF9: Storico utilizzo completo
 */
export async function getHistory(req, res, next) {
  try {
    const userId = req.user.userId; // Da middleware auth
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    // Trova tutti Noleggio per utenteId con stato "terminato" o "annullato"
    const query = {
      utenteId: userId,
      stato: { $in: ['terminato', 'annullato'] },
    };

    const [noleggi, total] = await Promise.all([
      Noleggio.find(query)
        .sort({ dataInizio: -1 }) // Ordina per dataInizio DESC
        .skip(skip)
        .limit(limit)
        .lean(),
      Noleggio.countDocuments(query),
    ]);

    // Formatta come ActiveCell array
    const historyCells = await Promise.all(
      noleggi.map((noleggio) => formatNoleggioAsActiveCell(noleggio))
    );

    const totalPages = Math.ceil(total / limit);

    logger.info(
      `Storico utilizzi utente ${userId}: ${historyCells.length} trovati (pagina ${page}/${totalPages})`
    );

    res.json({
      success: true,
      data: {
        cells: historyCells,
        pagination: {
          page,
          limit,
          total,
          totalPages,
        },
      },
    });
  } catch (error) {
    next(error);
  }
}

export default {
  requestCell,
  openCell,
  closeCell,
  returnCell,
  getActiveCells,
  getHistory,
};

