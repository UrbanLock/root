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
import config from '../config/env.js';

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

    // Genera noleggioId
    const noleggioId = await Noleggio.generateNoleggioId();

    // Genera Bluetooth token (QR code non più utilizzato)
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
 * Supporta sia cell_id (legacy) che pairingId (nuovo flusso backend-centric)
 */
/**
 * POST /api/v1/cells/open
 * Apre una cella tramite pairingId o cell_id
 * 
 * **SICUREZZA - TUTTI I CONTROLLI CRITICI SONO LATO BACKEND:**
 * - Verifica pairingId esiste e appartiene all'utente autenticato
 * - Verifica pairingId è ancora attivo
 * - Verifica cella è ancora assegnata all'utente
 * - Verifica foto se richiesta
 * - Verifica QR/Bluetooth token se presente
 * 
 * Il frontend non può aprire celle senza pairingId valido verificato dal backend.
 */
export async function openCell(req, res, next) {
  try {
    const { cell_id, pairingId, cellId, lockerId, photo } = req.body;
    const userId = req.user.userId; // Da middleware auth

    let noleggio;

    // Nuovo flusso: verifica tramite pairingId (backend-centric)
    if (pairingId) {
      if (!cellId || !lockerId) {
        throw new ValidationError(
          'pairingId richiede anche cellId e lockerId'
        );
      }

      // Trova Noleggio tramite pairingId (che è il noleggioId)
      noleggio = await Noleggio.findOne({
        noleggioId: pairingId,
        utenteId: userId,
        cellaId: cellId,
        lockerId: lockerId,
      });

      if (!noleggio) {
        throw new NotFoundError(
          `Accoppiamento non trovato per pairingId ${pairingId}`
        );
      }

      // Verifica che pairingId sia ancora valido e attivo
      if (noleggio.stato !== 'attivo') {
        throw new ValidationError(
          `Accoppiamento ${pairingId} non è più attivo (stato: ${noleggio.stato})`
        );
      }

      // Verifica che la cella sia ancora assegnata all'utente
      const cell = await Cell.findOne({ cellaId: cellId });
      if (!cell || cell.stato !== 'occupata') {
        throw new ValidationError(
          `Cella ${cellId} non è più assegnata all'utente`
        );
      }
    } else {
      // Flusso legacy: verifica tramite cell_id
      if (!cell_id) {
        throw new ValidationError(
          'cell_id o pairingId è obbligatorio'
        );
      }

      // Trova Noleggio per cellaId e utenteId (verifica proprietà)
      noleggio = await Noleggio.findOne({
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
    }

    const cell_id_final = pairingId ? cellId : cell_id;

    // Trova Cell per verifiche
    const cell = await Cell.findOne({ cellaId: cell_id_final });
    if (!cell) {
      throw new NotFoundError(`Cella ${cell_id_final} non trovata`);
    }

    // NOTA: La foto NON è obbligatoria per l'apertura di una cella
    // La foto è opzionale e viene usata solo per segnalare anomalie
    // Se richiesta_foto è true, la foto può essere fornita ma non è obbligatoria per aprire
    // La foto obbligatoria si applica solo a depositi/restituzioni specifici, non all'apertura

    // RF3: Verifica Bluetooth token se presente (QR code non più utilizzato)
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

    // ========== APERTURA LOCKER FISICO ==========
    // In produzione: invia comando al locker fisico tramite API/Bluetooth
    // Il locker fisico riceverà il comando e aprirà la cella meccanicamente
    try {
      // TODO PRODUZIONE: Sostituire con chiamata API reale al locker
      // Esempio:
      //   const lockerHardwareService = require('../services/lockerHardwareService');
      //   await lockerHardwareService.openCell(lockerId, cell_id_final);
      //   // Il locker fisico aprirà la cella e invierà conferma tramite sensore
      
      // ========== MOCK TESTING - RIMUOVERE IN PRODUZIONE ==========
      // ATTENZIONE: Questo è solo per testing durante lo sviluppo
      // In produzione, rimuovere questo blocco e implementare la chiamata reale al locker
      logger.info(
        `[MOCK] ⚠️ SIMULAZIONE apertura locker fisico: lockerId=${lockerId}, cellId=${cell_id_final}`
      );
      logger.info(
        `[MOCK] ⚠️ In produzione, questo sarà sostituito con chiamata API reale al locker hardware`
      );
      // Simula invio comando al locker (in produzione sarà reale)
      // Il locker fisico riceverà il comando e aprirà la cella
      // ========== FINE MOCK APERTURA ==========
      
      // ========== MOCK CHIUSURA AUTOMATICA - RIMUOVERE IN PRODUZIONE ==========
      // ATTENZIONE: Questo è solo per testing durante lo sviluppo
      // In produzione: il locker fisico invierà notifica di chiusura tramite sensore
      // quando lo sportello viene effettivamente chiuso dall'utente
      // 
      // Per testing: simula chiusura automatica dopo 5 secondi dall'apertura
      // Questo permette di testare il flusso completo senza locker fisico
      setTimeout(async () => {
        try {
          const noleggioUpdated = await Noleggio.findOne({
            noleggioId: noleggio.noleggioId,
          });
          
          if (noleggioUpdated && noleggioUpdated.cellaAperta && !noleggioUpdated.cellaChiusa) {
            // ========== MOCK: Simula chiusura automatica dopo 5 secondi ==========
            // In produzione: questo stato verrà aggiornato dal locker fisico
            // quando il sensore rileva che lo sportello è stato chiuso
            noleggioUpdated.cellaChiusa = true;
            noleggioUpdated.dataChiusura = new Date();
            noleggioUpdated.dataAggiornamento = new Date();
            await noleggioUpdated.save();
            
            logger.info(
              `[MOCK] ⚠️ Chiusura automatica simulata per cella ${cell_id_final} - Noleggio: ${noleggio.noleggioId}`
            );
            logger.info(
              `[MOCK] ⚠️ In produzione, questo sarà rilevato dal sensore del locker fisico`
            );
            // ========== FINE MOCK CHIUSURA ==========
          }
        } catch (error) {
          logger.error(`[MOCK] Errore chiusura automatica mock: ${error.message}`);
        }
      }, 5000); // 5 secondi per testing - RIMUOVERE IN PRODUZIONE
      // ========== FINE MOCK CHIUSURA AUTOMATICA ==========
    } catch (error) {
      logger.error(`Errore apertura locker fisico: ${error.message}`);
      throw new ValidationError(
        'Errore nell\'apertura fisica della cella. Riprova più tardi.'
      );
    }

    // Aggiorna stato: cella aperta, in attesa chiusura
    noleggio.dataAggiornamento = new Date();
    // Marca che la cella è stata aperta fisicamente
    noleggio.cellaAperta = true;
    noleggio.dataApertura = new Date();
    noleggio.cellaChiusa = false; // Reset stato chiusura
    noleggio.dataChiusura = null;
    await noleggio.save();

    logger.info(
      `Cella aperta: ${cell_id_final} - Noleggio: ${noleggio.noleggioId}, Utente: ${userId}${pairingId ? ` (pairingId: ${pairingId})` : ''}`
    );

    res.json({
      success: true,
      data: {
        cell_id: cell_id_final,
        door_opened: true,
        bluetoothToken: noleggio.bluetoothToken,
        message: 'Cella aperta con successo',
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

    // Verifica che la cella sia stata aperta
    if (!noleggio.cellaAperta) {
      throw new ValidationError(
        'Cella non è stata aperta. Impossibile chiudere.'
      );
    }

    // Verifica che la cella non sia già chiusa
    if (noleggio.cellaChiusa) {
      // Già chiusa, restituisci successo
      return res.json({
        success: true,
        data: {
          cell_closed: true,
          already_closed: true,
          message: 'Cella già chiusa',
        },
      });
    }

    // Aggiorna stato: cella chiusa
    noleggio.cellaChiusa = true;
    noleggio.dataChiusura = new Date();
    noleggio.dataAggiornamento = new Date();
    await noleggio.save();

    logger.info(
      `Cella chiusa: ${cell_id} - Noleggio: ${noleggio.noleggioId}, Utente: ${userId}`
    );

    res.json({
      success: true,
      data: {
        cell_closed: true,
        already_closed: false,
        message: 'Cella chiusa con successo',
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

/**
 * POST /api/v1/cells/verify-bluetooth-pairing
 * Verifica accoppiamento Bluetooth e assegna cella
 * RF3: Verifica prossimità e autorizzazione backend
 * 
 * **SICUREZZA - TUTTI I CONTROLLI CRITICI SONO LATO BACKEND:**
 * - Verifica UUID Bluetooth corrisponde al locker (match esatto normalizzato)
 * - Verifica prossimità tramite RSSI (se fornito)
 * - Verifica prossimità tramite geolocalizzazione (se fornita)
 * - Verifica cella esiste e è disponibile
 * - Verifica tipo cella corrisponde
 * - Verifica utente autenticato (middleware auth)
 * - Assegna cella solo dopo tutte le verifiche
 * 
 * Il frontend fa solo un pre-filtro per UX (matching esatto), ma la verifica finale
 * rigorosa è sempre fatta dal backend. Non fidarsi mai dei controlli frontend.
 */
export async function verifyBluetoothPairing(req, res, next) {
  try {
    const {
      lockerId,
      cellId,
      bluetoothUuid,
      bluetoothRssi,
      deviceName,
      geolocation,
    } = req.body;
    const userId = req.user.userId; // Da middleware auth

    // Validazione input
    if (!lockerId) {
      throw new ValidationError('lockerId è obbligatorio');
    }
    if (!cellId) {
      throw new ValidationError('cellId è obbligatorio');
    }
    if (!bluetoothUuid) {
      throw new ValidationError('bluetoothUuid è obbligatorio');
    }

    // 1. Verifica che locker esista e abbia UUID Bluetooth configurato
    const locker = await Locker.findOne({ lockerId }).lean();
    if (!locker) {
      throw new NotFoundError(`Locker ${lockerId} non trovato`);
    }

    if (!locker.bluetoothUuid) {
      throw new ValidationError(
        `Locker ${lockerId} non ha UUID Bluetooth configurato`
      );
    }

    // ========== MOCK MODE - SOLO PER TESTING/DEVELOPMENT ==========
    // Se BLUETOOTH_MOCK_MODE=true, bypassa tutte le verifiche di prossimità
    // ATTENZIONE: Usare solo durante sviluppo/testing, NON in produzione
    if (config.bluetoothMockMode) {
      logger.warn(
        `[MOCK MODE] Bluetooth mock attivo - bypass verifiche UUID/RSSI/geolocalizzazione per locker ${lockerId}`
      );
      // In modalità mock, salta tutte le verifiche di prossimità
      // ma verifica comunque che locker e cella esistano
    } else {
      // ========== VERIFICHE NORMALI (PRODUZIONE) ==========
      // 2. Verifica che UUID corrisponda al locker (CONTROLLO CRITICO - solo backend)
      // SICUREZZA: Richiediamo solo UUID esatto. Il nome Bluetooth è facilmente spoofabile e non viene usato.
      // Normalizza UUID (rimuovi trattini e due punti per confronto)
      const normalizeUuid = (uuid) => uuid.replace(/[-:]/g, '').toLowerCase();
      const lockerUuidNormalized = normalizeUuid(locker.bluetoothUuid);
      const receivedUuidNormalized = normalizeUuid(bluetoothUuid);

      // Verifica UUID esatto normalizzato (unico metodo di verifica sicuro)
      if (lockerUuidNormalized !== receivedUuidNormalized) {
        throw new ValidationError(
          'UUID Bluetooth non corrisponde al locker richiesto. Verifica di essere vicino al locker corretto e che il Bluetooth sia attivo.'
        );
      }

      // 3. Verifica prossimità tramite RSSI (priorità - più affidabile del GPS)
      // RSSI tipico: -30 a -90 dBm
      // -30 a -50: molto vicino
      // -50 a -70: vicino
      // -70 a -90: lontano
      let rssiValid = false;
      if (bluetoothRssi !== undefined && bluetoothRssi !== null) {
        const MAX_RSSI_THRESHOLD = -80; // Soglia massima (più negativo = più lontano)
        if (bluetoothRssi < MAX_RSSI_THRESHOLD) {
          throw new ValidationError(
            'Dispositivo troppo distante dal locker. Avvicinati per continuare.'
          );
        }
        // RSSI valido indica prossimità (più affidabile del GPS)
        rssiValid = true;
      }

      // 4. Verifica prossimità tramite geolocalizzazione (solo se RSSI non disponibile o dubbio)
      // NOTA: La geolocalizzazione può essere imprecisa (GPS indoor, errori di posizionamento)
      // Se RSSI è buono (es. > -70 dBm), la geolocalizzazione è solo un controllo aggiuntivo
      // e non dovrebbe bloccare se c'è un RSSI valido
      if (geolocation && geolocation.lat && geolocation.lng) {
        const lockerLat = locker.coordinate.lat;
        const lockerLng = locker.coordinate.lng;
        const userLat = geolocation.lat;
        const userLng = geolocation.lng;

        // Calcola distanza in metri (formula Haversine)
        const R = 6371000; // Raggio Terra in metri
        const dLat = ((userLat - lockerLat) * Math.PI) / 180;
        const dLng = ((userLng - lockerLng) * Math.PI) / 180;
        const a =
          Math.sin(dLat / 2) * Math.sin(dLat / 2) +
          Math.cos((lockerLat * Math.PI) / 180) *
            Math.cos((userLat * Math.PI) / 180) *
            Math.sin(dLng / 2) *
            Math.sin(dLng / 2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        const distance = R * c; // Distanza in metri

        // Se RSSI è valido e buono (vicino), la geolocalizzazione è solo informativa
        // Se RSSI non è disponibile, usa geolocalizzazione con soglia più permissiva
        const MAX_DISTANCE_METERS = rssiValid ? 200 : 50; // 200m se RSSI valido, 50m altrimenti
        
        if (distance > MAX_DISTANCE_METERS) {
          // Se RSSI è valido e buono, log warning ma non bloccare
          if (rssiValid && bluetoothRssi > -70) {
            logger.warn(
              `Geolocalizzazione indica distanza ${Math.round(distance)}m ma RSSI ${bluetoothRssi} dBm indica prossimità. Usando RSSI come verifica principale.`
            );
            // Non bloccare se RSSI è buono
          } else {
            // Se RSSI non è valido o è debole, usa geolocalizzazione
            throw new ValidationError(
              `Troppo distante dal locker (${Math.round(distance)}m). Avvicinati per continuare.`
            );
          }
        }
      }
      // ========== FINE VERIFICHE NORMALI ==========
    }
    // ========== FINE MOCK MODE ==========

    // 5. Verifica che la cella esista e sia disponibile
    const cell = await Cell.findOne({
      cellaId: cellId,
      lockerId: lockerId,
    });

    if (!cell) {
      throw new NotFoundError(
        `Cella ${cellId} non trovata nel locker ${lockerId}`
      );
    }

    if (cell.stato !== 'libera') {
      throw new ValidationError(
        `Cella ${cellId} non è disponibile (stato: ${cell.stato})`
      );
    }

    // 6. Verifica tipo cella (deve essere "prestito" per borrow)
    const tipoMapping = {
      borrow: 'prestito',
      deposited: 'deposito',
      pickup: 'ordini',
    };

    // Determina tipo dalla cella o dal body (priorità al body se presente)
    const expectedType = req.body.type || 'borrow'; // Default borrow per prestito
    const tipoDB = tipoMapping[expectedType] || 'prestito';

    if (cell.tipo !== tipoDB) {
      throw new ValidationError(
        `Cella ${cellId} non è di tipo ${tipoDB} (tipo attuale: ${cell.tipo})`
      );
    }

    // ========== CAMBIO STATO CELLA - SUBITO ALL'ASSEGNAZIONE ==========
    // IMPORTANTE: Lo stato viene cambiato SUBITO quando viene assegnata la cella,
    // prima di creare il Noleggio. Questo previene doppie assegnazioni simultanee.
    // Se due utenti cercano di assegnare la stessa cella contemporaneamente,
    // solo il primo riuscirà (stato "libera"), il secondo riceverà errore (stato "occupata").
    cell.stato = 'occupata';
    await cell.save();
    logger.info(
      `Cella ${cellId} impostata a "occupata" - Assegnazione in corso per utente ${userId}`
    );
    // ========== FINE CAMBIO STATO ==========

    // 7. Crea Noleggio (assegna cella)
    const now = new Date();
    const dataInizio = now;
    const oraInizio = formatTime(now);

    // Genera noleggioId
    const noleggioId = await Noleggio.generateNoleggioId();

    // Genera Bluetooth token (QR code non più utilizzato)
    const bluetoothToken = Noleggio.generateBluetoothToken();

    // Crea Noleggio
    const noleggio = new Noleggio({
      noleggioId,
      utenteId: userId,
      cellaId: cellId,
      lockerId,
      tipo: tipoDB,
      stato: 'attivo',
      dataInizio,
      oraInizio,
      costo: 0, // Prestito è gratuito
      bluetoothToken,
      geolocalizzazione: geolocation || null,
    });

    await noleggio.save();

    // 9. Formatta come ActiveCell per frontend
    const activeCell = await formatNoleggioAsActiveCell(noleggio);

    logger.info(
      `Accoppiamento Bluetooth verificato: ${noleggioId} - Utente: ${userId}, Locker: ${lockerId}, Cella: ${cellId}`
    );

    // 10. Restituisci risultato
    res.status(201).json({
      success: true,
      data: {
        verified: true,
        pairingId: noleggioId, // Usa noleggioId come pairingId
        cellAssigned: activeCell,
        message: 'Accoppiamento verificato. Cella assegnata.',
      },
    });
  } catch (error) {
    // Se è un ValidationError o NotFoundError, restituisci formato standard
    if (error.name === 'ValidationError' || error.name === 'NotFoundError') {
      return res.status(400).json({
        success: false,
        data: {
          verified: false,
          reason: error.name === 'ValidationError' ? 'validation_error' : 'not_found',
          message: error.message,
        },
      });
    }

    // Altrimenti passa all'error handler
    next(error);
  }
}

/**
 * GET /api/v1/cells/:cellId/door-status
 * Verifica stato apertura/chiusura sportello
 * Utilizzato per polling dal frontend (chiamato ogni 2 secondi)
 * 
 * **SICUREZZA - TUTTI I CONTROLLI CRITICI SONO LATO BACKEND:**
 * - Verifica che la cella appartenga all'utente autenticato
 * - Verifica che il noleggio sia attivo
 * - Restituisce solo informazioni autorizzate
 * 
 * **MOCK MODE:**
 * - In modalità mock, lo stato viene aggiornato automaticamente dopo 5 secondi dall'apertura
 * - In produzione, lo stato verrà aggiornato dal locker fisico tramite sensore
 */
export async function getDoorStatus(req, res, next) {
  try {
    const { cellId } = req.params;
    const userId = req.user.userId; // Da middleware auth

    if (!cellId) {
      throw new ValidationError('cellId è obbligatorio');
    }

    // Trova Noleggio per cellaId e utenteId
    const noleggio = await Noleggio.findOne({
      cellaId: cellId,
      utenteId: userId,
      stato: 'attivo',
    });

    if (!noleggio) {
      throw new NotFoundError(
        `Noleggio attivo non trovato per cella ${cellId} e utente corrente`
      );
    }

    // ========== MOCK MODE - SOLO PER TESTING ==========
    // NOTA: In produzione, lo stato verrà aggiornato dal locker fisico
    // quando il sensore rileva la chiusura dello sportello
    // Il mock in openCell() aggiorna automaticamente lo stato dopo 5 secondi
    // ========== FINE MOCK MODE ==========

    // Restituisci stato sportello
    res.json({
      success: true,
      data: {
        cellId,
        doorOpened: noleggio.cellaAperta || false,
        doorClosed: noleggio.cellaChiusa || false,
        openedAt: noleggio.dataApertura ? noleggio.dataApertura.toISOString() : null,
        closedAt: noleggio.dataChiusura ? noleggio.dataChiusura.toISOString() : null,
        // Calcola tempo trascorso dall'apertura (in secondi)
        secondsSinceOpen: noleggio.dataApertura
          ? Math.floor((new Date() - noleggio.dataApertura) / 1000)
          : null,
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
  verifyBluetoothPairing,
  getDoorStatus,
};

