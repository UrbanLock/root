import logger from '../utils/logger.js';
import { createNotification } from '../services/notificationService.js';
import { ValidationError } from '../middleware/errorHandler.js';

/**
 * GET /api/v1/help
 * Help e tutorial generale
 * RF7: Help e tutorial
 */
export async function getHelp(req, res, next) {
  try {
    const { section } = req.query;
    const userId = req.user?.userId; // Opzionale

    // Contenuto help generale (hardcoded per MVP)
    const helpSections = [
      {
        id: 'introduzione',
        title: 'Introduzione',
        content:
          'Benvenuto in NULL, il sistema di smart locker modulari per la Smart City di Trento. NULL ti permette di depositare, prendere in prestito e donare attrezzature sportive e altro materiale in modo sicuro e conveniente.',
        order: 1,
      },
      {
        id: 'funzionalita',
        title: 'Funzionalità Principali',
        content:
          'NULL offre diverse funzionalità:\n\n' +
          '• Deposito: Deposita temporaneamente oggetti in un locker\n' +
          '• Prestito: Prendi in prestito attrezzature sportive disponibili\n' +
          '• Donazioni: Dona attrezzature che non usi più\n' +
          '• Segnalazioni: Segnala problemi o anomalie\n' +
          '• Preferenze: Personalizza la tua esperienza',
        order: 2,
      },
      {
        id: 'faq',
        title: 'FAQ - Domande Frequenti',
        content:
          'Domande frequenti:\n\n' +
          'Q: Come funziona il deposito?\n' +
          'A: Seleziona un locker disponibile, scegli una cella, deposita l\'oggetto e paga la tariffa oraria.\n\n' +
          'Q: I prestiti sono gratuiti?\n' +
          'A: Sì, i prestiti di attrezzature sportive sono completamente gratuiti.\n\n' +
          'Q: Come posso donare attrezzature?\n' +
          'A: Vai alla sezione Donazioni, compila il modulo con foto e descrizione, e un operatore valuterà la tua donazione.\n\n' +
          'Q: Come segnalo un problema?\n' +
          'A: Usa la sezione Segnalazioni per segnalare problemi, guasti o anomalie.',
        order: 3,
      },
      {
        id: 'contatti',
        title: 'Contatti',
        content:
          'Per assistenza o informazioni:\n\n' +
          '• Email: supporto@null.trento.it\n' +
          '• Telefono: 0461 123456\n' +
          '• Orari: Lun-Ven 9:00-18:00\n\n' +
          'Puoi anche contattare direttamente l\'ente comunale tramite l\'app.',
        order: 4,
      },
    ];

    // Se section specificato, ritorna solo quella sezione
    if (section) {
      const sectionData = helpSections.find((s) => s.id === section);
      if (!sectionData) {
        throw new ValidationError(`Sezione "${section}" non trovata`);
      }

      logger.info(`Help sezione "${section}" recuperata${userId ? ` per utente ${userId}` : ''}`);

      return res.json({
        success: true,
        data: {
          section: sectionData,
        },
      });
    }

    // Ritorna tutte le sezioni
    logger.info(`Help completo recuperato${userId ? ` per utente ${userId}` : ''}`);

    res.json({
      success: true,
      data: {
        sections: helpSections,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/help/tutorial
 * Tutorial iniziale
 * RF7: Tutorial iniziale
 */
export async function getTutorial(req, res, next) {
  try {
    const userId = req.user?.userId; // Opzionale

    // Tutorial iniziale (hardcoded per MVP)
    const tutorialSteps = [
      {
        id: 'registrazione',
        title: 'Registrazione',
        description:
          'Per iniziare, registrati tramite SPID o CIE. La registrazione è gratuita e richiede solo pochi minuti.',
        imageUrl: null, // In futuro: URL immagine tutorial
        order: 1,
      },
      {
        id: 'primo_utilizzo',
        title: 'Primo Utilizzo',
        description:
          'Dopo la registrazione, esplora i locker disponibili nella tua zona. Puoi vedere disponibilità in tempo reale e filtrare per tipo di servizio.',
        imageUrl: null,
        order: 2,
      },
      {
        id: 'deposito',
        title: 'Deposito',
        description:
          'Per depositare un oggetto: seleziona un locker, scegli una cella disponibile, inserisci l\'oggetto e chiudi la cella. Verrai addebitato in base alla durata del deposito.',
        imageUrl: null,
        order: 3,
      },
      {
        id: 'prestito',
        title: 'Prestito',
        description:
          'Per prendere in prestito un\'attrezzatura: cerca oggetti disponibili, seleziona quello che ti interessa, scegli la durata (in giorni) e ritira l\'oggetto. I prestiti sono gratuiti!',
        imageUrl: null,
        order: 4,
      },
      {
        id: 'donazione',
        title: 'Donazione',
        description:
          'Per donare attrezzature: compila il modulo di donazione con foto e descrizione. Un operatore valuterà la tua donazione e ti contatterà per concordare il ritiro.',
        imageUrl: null,
        order: 5,
      },
      {
        id: 'segnalazioni',
        title: 'Segnalazioni',
        description:
          'Se noti problemi o anomalie, usa la sezione Segnalazioni. Puoi allegare foto e descrivere il problema. Gli operatori risponderanno il prima possibile.',
        imageUrl: null,
        order: 6,
      },
      {
        id: 'preferenze',
        title: 'Preferenze',
        description:
          'Personalizza la tua esperienza: imposta preferenze per tipo di locker, gestisci notifiche e visualizza il tuo storico di utilizzo.',
        imageUrl: null,
        order: 7,
      },
    ];

    logger.info(`Tutorial recuperato${userId ? ` per utente ${userId}` : ''}`);

    res.json({
      success: true,
      data: {
        steps: tutorialSteps,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/help/safety-rules
 * Norme sicurezza parchi
 * RF7: Norme sicurezza parchi
 */
export async function getSafetyRules(req, res, next) {
  try {
    const userId = req.user?.userId; // Opzionale

    // Norme sicurezza parchi (hardcoded per MVP)
    const safetySections = [
      {
        id: 'norme_generali',
        title: 'Norme Generali',
        content:
          '• Rispetta sempre gli altri utenti e l\'ambiente\n' +
          '• Non danneggiare le attrezzature o i locker\n' +
          '• Mantieni puliti gli spazi comuni\n' +
          '• Segui le indicazioni degli operatori\n' +
          '• In caso di emergenza, chiama il 112',
        order: 1,
      },
      {
        id: 'utilizzo_attrezzature',
        title: 'Utilizzo Attrezzature',
        content:
          '• Usa le attrezzature solo per lo scopo previsto\n' +
          '• Verifica sempre le condizioni prima dell\'uso\n' +
          '• Restituisci le attrezzature in buone condizioni\n' +
          '• Segnala immediatamente eventuali danni\n' +
          '• Non modificare o alterare le attrezzature',
        order: 2,
      },
      {
        id: 'comportamento',
        title: 'Comportamento',
        content:
          '• Sii rispettoso e civile con gli altri utenti\n' +
          '• Non occupare le celle oltre il tempo concordato\n' +
          '• Non lasciare oggetti personali incustoditi\n' +
          '• Mantieni la privacy degli altri utenti\n' +
          '• Segui le regole del parco o area pubblica',
        order: 3,
      },
      {
        id: 'emergenze',
        title: 'Emergenze',
        content:
          'In caso di emergenza:\n\n' +
          '• Chiama immediatamente il 112\n' +
          '• Segnala il problema tramite l\'app\n' +
          '• Non tentare interventi pericolosi\n' +
          '• Segui le indicazioni degli operatori\n' +
          '• Mantieni la calma e aiuta gli altri se possibile',
        order: 4,
      },
      {
        id: 'contatti_emergenza',
        title: 'Contatti Emergenza',
        content:
          '• Emergenze: 112\n' +
          '• Vigili del Fuoco: 115\n' +
          '• Polizia: 113\n' +
          '• Assistenza NULL: 0461 123456\n' +
          '• Email emergenze: emergenze@null.trento.it',
        order: 5,
      },
    ];

    logger.info(`Norme sicurezza recuperate${userId ? ` per utente ${userId}` : ''}`);

    res.json({
      success: true,
      data: {
        sections: safetySections,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * POST /api/v1/help/contact
 * Contatto ente comunale
 * RF7: Contatto ente comunale
 */
export async function contactMunicipality(req, res, next) {
  try {
    const { oggetto, messaggio, tipoRichiesta } = req.body;
    const userId = req.user.userId;

    // Validazione campi obbligatori
    if (!oggetto) {
      throw new ValidationError('oggetto è obbligatorio');
    }
    if (!messaggio) {
      throw new ValidationError('messaggio è obbligatorio');
    }

    // Valida tipoRichiesta se presente
    if (tipoRichiesta) {
      const tipiValidi = ['informazione', 'segnalazione', 'reclamo', 'altro'];
      if (!tipiValidi.includes(tipoRichiesta)) {
        throw new ValidationError(
          `tipoRichiesta non valido. Valori accettati: ${tipiValidi.join(', ')}`
        );
      }
    }

    // Crea notifica in-app per conferma (per MVP)
    // In futuro, può essere integrato con servizio email esterno
    try {
      await createNotification(
        userId,
        'sistema',
        'Richiesta inviata all\'ente comunale',
        `La tua richiesta "${oggetto}" è stata inviata con successo. Riceverai una risposta il prima possibile.`,
        {
          tipoRichiesta: tipoRichiesta || 'altro',
          oggetto,
        }
      );

      logger.info(
        `Richiesta contatto ente comunale inviata da utente ${userId}: ${oggetto}`
      );
    } catch (notificationError) {
      logger.warn(
        `Errore creazione notifica per contatto ente comunale:`,
        notificationError
      );
      // Non bloccare invio se notifica fallisce
    }

    res.json({
      success: true,
      data: {
        message: 'Richiesta inviata con successo',
      },
    });
  } catch (error) {
    next(error);
  }
}

export default {
  getHelp,
  getTutorial,
  getSafetyRules,
  contactMunicipality,
};

