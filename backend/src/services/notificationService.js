import Notifica from '../models/Notifica.js';
import User from '../models/User.js';
import Noleggio from '../models/Noleggio.js';
import Locker from '../models/Locker.js';
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
 * Verifica se l'utente ha abilitato le notifiche per un tipo specifico
 * Default: true (se preferenza non presente, notifica abilitata)
 */
async function shouldNotifyUser(utenteId, tipo) {
  try {
    const user = await User.findById(utenteId).lean();
    if (!user) {
      return false; // Utente non trovato, non notificare
    }

    const preferenze = user.preferenzeNotifiche || {};
    
    // Se preferenza non presente, default true
    if (preferenze[tipo] === undefined) {
      return true;
    }

    // Ritorna valore preferenza
    return preferenze[tipo] === true;
  } catch (error) {
    logger.error(`Errore verifica preferenze notifiche per utente ${utenteId}:`, error);
    // In caso di errore, default true (notifica abilitata)
    return true;
  }
}

/**
 * Crea una nuova notifica
 * Verifica preferenze utente prima di creare
 */
export async function createNotification(
  utenteId,
  tipo,
  titolo,
  messaggio,
  payload = {}
) {
  try {
    // Verifica preferenze utente
    const shouldNotify = await shouldNotifyUser(utenteId, tipo);
    if (!shouldNotify) {
      logger.info(
        `Notifica tipo ${tipo} disabilitata per utente ${utenteId}, skip`
      );
      return null;
    }

    // Genera notificaId
    const notificaId = await Notifica.generateNotificaId();

    // Crea notifica
    const notifica = new Notifica({
      notificaId,
      utenteId,
      tipo,
      titolo,
      messaggio,
      payload,
      letta: false,
      dataCreazione: new Date(),
      dataLettura: null,
    });

    await notifica.save();

    logger.info(
      `Notifica creata: ${notificaId} per utente ${utenteId}, tipo: ${tipo}`
    );

    return notifica;
  } catch (error) {
    logger.error(`Errore creazione notifica per utente ${utenteId}:`, error);
    throw error;
  }
}

/**
 * Notifica apertura/chiusura cella
 * RF5: Avvisi durante apertura/chiusura
 */
export async function notifyAperturaChiusura(
  utenteId,
  lockerId,
  cellaId,
  tipoOperazione,
  noleggioId = null
) {
  try {
    // Recupera locker per nome
    const locker = await Locker.findOne({ lockerId }).lean();
    const lockerName = locker?.nome || lockerId;

    // Estrai numero cella
    const cellNumberMatch = cellaId.match(/CEL-[\w-]+-(\d+)/);
    const cellNumber = cellNumberMatch
      ? `Cella ${parseInt(cellNumberMatch[1], 10)}`
      : cellaId;

    const titolo =
      tipoOperazione === 'apertura' ? 'Cella aperta' : 'Cella chiusa';
    const messaggio = `La ${cellNumber} del locker ${lockerName} è stata ${tipoOperazione === 'apertura' ? 'aperta' : 'chiusa'}`;

    return await createNotification(
      utenteId,
      'apertura_chiusura',
      titolo,
      messaggio,
      {
        lockerId,
        cellaId,
        noleggioId,
        tipoOperazione,
      }
    );
  } catch (error) {
    logger.error(
      `Errore notifica apertura/chiusura per utente ${utenteId}:`,
      error
    );
    throw error;
  }
}

/**
 * Notifica chiusura temporanea locker
 * RF5: Chiusure temporanee
 */
export async function notifyChiusuraTemporanea(
  utenteId,
  lockerId,
  motivo,
  dataRiapertura = null
) {
  try {
    // Recupera locker per nome
    const locker = await Locker.findOne({ lockerId }).lean();
    const lockerName = locker?.nome || lockerId;

    const dataRiaperturaStr = dataRiapertura
      ? new Date(dataRiapertura).toLocaleString('it-IT')
      : 'data da definire';

    const titolo = 'Locker temporaneamente chiuso';
    const messaggio = `Il locker ${lockerName} è temporaneamente chiuso: ${motivo}. Riapertura prevista: ${dataRiaperturaStr}`;

    return await createNotification(
      utenteId,
      'chiusura_temporanea',
      titolo,
      messaggio,
      {
        lockerId,
        motivo,
        dataRiapertura,
      }
    );
  } catch (error) {
    logger.error(
      `Errore notifica chiusura temporanea per utente ${utenteId}:`,
      error
    );
    throw error;
  }
}

/**
 * Notifica nuova postazione
 * RF5: Nuove postazioni
 */
export async function notifyNuovaPostazione(utenteId, lockerId) {
  try {
    // Recupera locker per nome
    const locker = await Locker.findOne({ lockerId }).lean();
    const lockerName = locker?.nome || lockerId;

    const titolo = 'Nuova postazione disponibile';
    const messaggio = `Un nuovo locker è disponibile nella tua zona: ${lockerName}`;

    return await createNotification(
      utenteId,
      'nuova_postazione',
      titolo,
      messaggio,
      {
        lockerId,
      }
    );
  } catch (error) {
    logger.error(
      `Errore notifica nuova postazione per utente ${utenteId}:`,
      error
    );
    throw error;
  }
}

/**
 * Notifica reminder donazione
 * RF5: Reminder appuntamenti donazioni
 */
export async function notifyReminderDonazione(
  utenteId,
  dataAppuntamento,
  lockerId = null
) {
  try {
    const dataAppuntamentoStr = new Date(dataAppuntamento).toLocaleString(
      'it-IT'
    );

    const titolo = 'Promemoria appuntamento donazione';
    const messaggio = `Ricorda: hai un appuntamento per la donazione il ${dataAppuntamentoStr}`;

    return await createNotification(
      utenteId,
      'reminder_donazione',
      titolo,
      messaggio,
      {
        dataAppuntamento,
        lockerId,
      }
    );
  } catch (error) {
    logger.error(
      `Errore notifica reminder donazione per utente ${utenteId}:`,
      error
    );
    throw error;
  }
}

/**
 * Notifica reminder restituzione
 * RF5: Reminder restituzione materiale
 */
export async function notifyReminderRestituzione(
  utenteId,
  noleggioId,
  dataScadenza
) {
  try {
    const dataScadenzaStr = new Date(dataScadenza).toLocaleString('it-IT');

    const titolo = 'Promemoria restituzione materiale';
    const messaggio = `Ricorda di restituire il materiale entro ${dataScadenzaStr}`;

    return await createNotification(
      utenteId,
      'reminder_restituzione',
      titolo,
      messaggio,
      {
        noleggioId,
        dataScadenza,
      }
    );
  } catch (error) {
    logger.error(
      `Errore notifica reminder restituzione per utente ${utenteId}:`,
      error
    );
    throw error;
  }
}

/**
 * Controlla e invia reminder automatici per prestiti in scadenza
 * Può essere chiamata da cron job o scheduler
 */
export async function checkAndSendReminders() {
  try {
    const now = new Date();
    const in24Hours = new Date(now.getTime() + 24 * 60 * 60 * 1000); // 24 ore da ora

    // Trova prestiti attivi che scadono entro 24 ore
    const prestitiInScadenza = await Noleggio.find({
      tipo: 'prestito',
      stato: 'attivo',
      dataFine: {
        $gte: now,
        $lte: in24Hours,
      },
    }).lean();

    logger.info(
      `Trovati ${prestitiInScadenza.length} prestiti in scadenza per reminder`
    );

    let notificheCreate = 0;

    for (const prestito of prestitiInScadenza) {
      try {
        // Verifica se esiste già notifica reminder per questo noleggioId
        const notificaEsistente = await Notifica.findOne({
          utenteId: prestito.utenteId,
          tipo: 'reminder_restituzione',
          'payload.noleggioId': prestito.noleggioId,
        }).lean();

        if (notificaEsistente) {
          logger.info(
            `Notifica reminder già esistente per noleggio ${prestito.noleggioId}, skip`
          );
          continue;
        }

        // Crea notifica reminder
        await notifyReminderRestituzione(
          prestito.utenteId,
          prestito.noleggioId,
          prestito.dataFine
        );

        notificheCreate++;
      } catch (error) {
        logger.error(
          `Errore creazione reminder per noleggio ${prestito.noleggioId}:`,
          error
        );
        // Continua con gli altri prestiti anche se uno fallisce
      }
    }

    logger.info(
      `Reminder automatici: ${notificheCreate} notifiche create su ${prestitiInScadenza.length} prestiti`
    );

    return {
      prestitiTrovati: prestitiInScadenza.length,
      notificheCreate,
    };
  } catch (error) {
    logger.error('Errore controllo reminder automatici:', error);
    throw error;
  }
}

export default {
  createNotification,
  notifyAperturaChiusura,
  notifyChiusuraTemporanea,
  notifyNuovaPostazione,
  notifyReminderDonazione,
  notifyReminderRestituzione,
  checkAndSendReminders,
};


