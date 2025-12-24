import Locker from '../models/Locker.js';
import Cell from '../models/Cell.js';
import User from '../models/User.js';
import Noleggio from '../models/Noleggio.js';
import AuditOperatore from '../models/AuditOperatore.js';
import Allarme from '../models/Allarme.js';
import mongoose from 'mongoose';
import {
  NotFoundError,
  ValidationError,
  UnauthorizedError,
} from '../middleware/errorHandler.js';
import logger from '../utils/logger.js';
import { savePhoto } from '../utils/photoStorage.js';
import { notifyChiusuraTemporanea } from '../services/notificationService.js';

/**
 * Formatta Locker come AdminLockerResponse per frontend admin
 */
async function formatAdminLockerResponse(locker) {
  // Conta celle
  const celle = await Cell.find({ lockerId: locker.lockerId }).lean();
  const celleStats = {
    totale: celle.length,
    disponibili: celle.filter((c) => c.disponibile).length,
    occupate: celle.filter((c) => !c.disponibile).length,
  };

  // Conta allarmi attivi
  const allarmiCount = await Allarme.countDocuments({
    lockerId: locker.lockerId,
    stato: 'attivo',
  });

  return {
    id: locker.lockerId,
    nome: locker.nome,
    tipo: locker.tipo || null,
    position: locker.coordinate || null,
    status: locker.online ? 'online' : 'offline',
    inMaintenance: locker.stato === 'manutenzione',
    maintenanceReason: locker.motivoManutenzione || null,
    maintenanceEndDate: locker.dataFineManutenzionePrevista || null,
    cells: celleStats,
    activeAlarms: allarmiCount,
    lastMaintenance: locker.dataUltimaManutenzione || null,
  };
}

/**
 * GET /api/v1/admin/lockers
 * Lista tutti i locker
 * RF14: Lista tutti i locker
 */
export async function getAllLockers(req, res, next) {
  try {
    const { page = 1, limit = 20, stato, tipo, categoria } = req.query;

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

    // Filtro stato (online/offline)
    if (stato) {
      if (stato === 'online') {
        query.online = true;
      } else if (stato === 'offline') {
        query.online = false;
      } else {
        query.stato = stato;
      }
    }

    // Filtro tipo
    if (tipo) {
      query.tipo = tipo;
    }

    // Filtro categoria (se modello CategoriaLocker disponibile)
    // Per MVP, categoria può essere mappata a tipo
    if (categoria) {
      // Implementazione semplificata: categoria mappata a tipo
      query.tipo = categoria;
    }

    // Calcola skip
    const skip = (pageNum - 1) * limitNum;

    // Trova locker con paginazione
    const lockers = await Locker.find(query)
      .sort({ nome: 1 })
      .skip(skip)
      .limit(limitNum)
      .lean();

    // Formatta risposte
    const items = await Promise.all(
      lockers.map((locker) => formatAdminLockerResponse(locker))
    );

    // Calcola total
    const total = await Locker.countDocuments(query);
    const totalPages = Math.ceil(total / limitNum);

    logger.info(
      `Locker recuperati (admin): ${items.length} items (page ${pageNum}/${totalPages})`
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
 * PUT /api/v1/admin/lockers/:id/status
 * Modificare stato online/offline
 * RF14: Modificare stato online/offline
 */
export async function updateLockerStatus(req, res, next) {
  try {
    const { id } = req.params;
    const { stato } = req.body;
    const operatoreId = req.user.userId;

    // Converti operatoreId (stringa) in ObjectId
    const operatoreObjectId = new mongoose.Types.ObjectId(operatoreId);

    // Validazione stato
    if (!stato) {
      throw new ValidationError('stato è obbligatorio');
    }

    const statiValidi = ['online', 'offline'];
    if (!statiValidi.includes(stato)) {
      throw new ValidationError(
        `stato non valido. Valori accettati: ${statiValidi.join(', ')}`
      );
    }

    // Trova Locker
    const locker = await Locker.findOne({ lockerId: id });

    if (!locker) {
      throw new NotFoundError('Locker non trovato');
    }

    // Aggiorna stato
    locker.online = stato === 'online';
    locker.dataAggiornamento = new Date();

    await locker.save();

    // Crea audit
    try {
      const auditId = await AuditOperatore.generateAuditId();
      await AuditOperatore.create({
        auditId,
        operatoreId: operatoreObjectId,
        azione: 'modifica_stato',
        entita: 'locker',
        entitaId: id,
        dettagli: { stato: stato },
        timestamp: new Date(),
        ipAddress: req.ip,
        userAgent: req.get('user-agent'),
      });
    } catch (auditError) {
      logger.warn('Errore creazione audit modifica stato:', auditError);
    }

    // Formatta risposta
    const lockerResponse = await formatAdminLockerResponse(locker);

    logger.info(
      `Stato locker ${id} aggiornato a ${stato} da operatore ${operatoreId}`
    );

    res.json({
      success: true,
      data: {
        locker: lockerResponse,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * PUT /api/v1/admin/lockers/:id/maintenance
 * Impostare manutenzione
 * RF14: Impostare manutenzione
 */
export async function setMaintenance(req, res, next) {
  try {
    const { id } = req.params;
    const { inManutenzione, motivo, dataFinePrevista } = req.body;
    const operatoreId = req.user.userId;

    // Converti operatoreId (stringa) in ObjectId
    const operatoreObjectId = new mongoose.Types.ObjectId(operatoreId);

    // Validazione
    if (inManutenzione === undefined) {
      throw new ValidationError('inManutenzione è obbligatorio');
    }

    // Trova Locker
    const locker = await Locker.findOne({ lockerId: id });

    if (!locker) {
      throw new NotFoundError('Locker non trovato');
    }

    // Aggiorna manutenzione
    locker.inManutenzione = inManutenzione;
    if (motivo) {
      locker.motivoManutenzione = motivo;
    }
    if (dataFinePrevista) {
      locker.dataFineManutenzionePrevista = new Date(dataFinePrevista);
    }
    if (inManutenzione) {
      locker.stato = 'manutenzione';
    } else if (locker.stato === 'manutenzione') {
      locker.stato = 'attivo';
    }
    locker.dataAggiornamento = new Date();

    await locker.save();

    // Crea audit
    try {
      const auditId = await AuditOperatore.generateAuditId();
      await AuditOperatore.create({
        auditId,
        operatoreId: operatoreObjectId,
        azione: 'manutenzione',
        entita: 'locker',
        entitaId: id,
        dettagli: {
          inManutenzione,
          motivo,
          dataFinePrevista,
        },
        timestamp: new Date(),
        ipAddress: req.ip,
        userAgent: req.get('user-agent'),
      });
    } catch (auditError) {
      logger.warn('Errore creazione audit manutenzione:', auditError);
    }

    // Crea notifica se manutenzione attivata
    if (inManutenzione) {
      try {
        // Trova utenti con prenotazioni attive su questo locker
        const prenotazioniAttive = await Noleggio.find({
          lockerId: id,
          stato: 'attivo',
        }).lean();

        for (const prenotazione of prenotazioniAttive) {
          await notifyChiusuraTemporanea(
            prenotazione.utenteId,
            id,
            motivo || 'Manutenzione programmata'
          );
        }
      } catch (notificationError) {
        logger.warn(
          `Errore creazione notifiche manutenzione per locker ${id}:`,
          notificationError
        );
      }
    }

    // Formatta risposta
    const lockerResponse = await formatAdminLockerResponse(locker);

    logger.info(
      `Manutenzione locker ${id} ${inManutenzione ? 'attivata' : 'disattivata'} da operatore ${operatoreId}`
    );

    res.json({
      success: true,
      data: {
        locker: lockerResponse,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * PUT /api/v1/admin/lockers/:id/restore
 * Ripristinare locker
 * RF14: Ripristinare locker
 */
export async function restoreLocker(req, res, next) {
  try {
    const { id } = req.params;
    const { note } = req.body;
    const operatoreId = req.user.userId;

    // Converti operatoreId (stringa) in ObjectId
    const operatoreObjectId = new mongoose.Types.ObjectId(operatoreId);

    // Trova Locker
    const locker = await Locker.findOne({ lockerId: id });

    if (!locker) {
      throw new NotFoundError('Locker non trovato');
    }

    // Ripristina locker
    locker.inManutenzione = false;
    locker.stato = 'attivo';
    locker.online = true;
    locker.motivoManutenzione = null;
    locker.dataFineManutenzionePrevista = null;
    locker.dataRipristino = new Date();
    locker.dataAggiornamento = new Date();

    await locker.save();

    // Crea audit
    try {
      const auditId = await AuditOperatore.generateAuditId();
      await AuditOperatore.create({
        auditId,
        operatoreId: operatoreObjectId,
        azione: 'manutenzione',
        entita: 'locker',
        entitaId: id,
        dettagli: { azione: 'ripristino', note },
        timestamp: new Date(),
        ipAddress: req.ip,
        userAgent: req.get('user-agent'),
      });
    } catch (auditError) {
      logger.warn('Errore creazione audit ripristino:', auditError);
    }

    // Formatta risposta
    const lockerResponse = await formatAdminLockerResponse(locker);

    logger.info(`Locker ${id} ripristinato da operatore ${operatoreId}`);

    res.json({
      success: true,
      data: {
        locker: lockerResponse,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/admin/lockers/:id/protocol
 * Protocollo rifornimento/manutenzione
 * RF14: Protocollo rifornimento/manutenzione
 */
export async function getLockerProtocol(req, res, next) {
  try {
    const { id } = req.params;
    const { tipologia } = req.query;

    // Validazione tipologia
    if (!tipologia) {
      throw new ValidationError('tipologia è obbligatoria');
    }

    const tipologieValide = ['rifornimento', 'manutenzione'];
    if (!tipologieValide.includes(tipologia)) {
      throw new ValidationError(
        `tipologia non valida. Valori accettati: ${tipologieValide.join(', ')}`
      );
    }

    // Trova Locker
    const locker = await Locker.findOne({ lockerId: id }).lean();

    if (!locker) {
      throw new NotFoundError('Locker non trovato');
    }

    // Genera protocollo in base a tipologia (hardcoded per MVP)
    let protocol = null;

    if (tipologia === 'rifornimento') {
      protocol = {
        tipologia: 'rifornimento',
        passi: [
          {
            ordine: 1,
            titolo: 'Verifica stato locker',
            descrizione: 'Verificare che il locker sia offline e in stato manutenzione',
          },
          {
            ordine: 2,
            titolo: 'Apertura locker',
            descrizione: 'Aprire il locker usando le credenziali di manutenzione',
          },
          {
            ordine: 3,
            titolo: 'Rifornimento celle',
            descrizione: 'Rifornire le celle specificate con materiali necessari',
          },
          {
            ordine: 4,
            titolo: 'Verifica funzionamento',
            descrizione: 'Verificare che tutte le celle funzionino correttamente',
          },
          {
            ordine: 5,
            titolo: 'Chiusura e riattivazione',
            descrizione: 'Chiudere il locker e riattivarlo online',
          },
        ],
        checklist: [
          { item: 'Materiali necessari', completato: false },
          { item: 'Strumenti di manutenzione', completato: false },
          { item: 'Documentazione', completato: false },
        ],
        note: 'Assicurarsi di seguire tutte le procedure di sicurezza durante il rifornimento',
      };
    } else if (tipologia === 'manutenzione') {
      protocol = {
        tipologia: 'manutenzione',
        passi: [
          {
            ordine: 1,
            titolo: 'Diagnosi problema',
            descrizione: 'Identificare il problema specifico del locker',
          },
          {
            ordine: 2,
            titolo: 'Preparazione intervento',
            descrizione: 'Preparare strumenti e materiali necessari',
          },
          {
            ordine: 3,
            titolo: 'Esecuzione intervento',
            descrizione: 'Eseguire le operazioni di manutenzione necessarie',
          },
          {
            ordine: 4,
            titolo: 'Test funzionamento',
            descrizione: 'Testare che il locker funzioni correttamente dopo la manutenzione',
          },
          {
            ordine: 5,
            titolo: 'Documentazione',
            descrizione: 'Documentare l\'intervento eseguito',
          },
        ],
        checklist: [
          { item: 'Strumenti diagnostici', completato: false },
          { item: 'Ricambi necessari', completato: false },
          { item: 'Documentazione tecnica', completato: false },
        ],
        note: 'Seguire le procedure di sicurezza e documentare tutti gli interventi eseguiti',
      };
    }

    logger.info(`Protocollo ${tipologia} recuperato per locker ${id}`);

    res.json({
      success: true,
      data: {
        protocol,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * POST /api/v1/admin/lockers/:id/supply
 * Registrare rifornimento
 * RF14: Registrare rifornimento
 */
export async function registerSupply(req, res, next) {
  try {
    const { id } = req.params;
    const { celleRifornite, materiali, note, foto } = req.body;
    const operatoreId = req.user.userId;

    // Converti operatoreId (stringa) in ObjectId
    const operatoreObjectId = new mongoose.Types.ObjectId(operatoreId);

    // Validazione
    if (!celleRifornite || !Array.isArray(celleRifornite) || celleRifornite.length === 0) {
      throw new ValidationError('celleRifornite è obbligatorio e deve essere un array non vuoto');
    }

    // Trova Locker
    const locker = await Locker.findOne({ lockerId: id });

    if (!locker) {
      throw new NotFoundError('Locker non trovato');
    }

    // Valida celle
    for (const cellaId of celleRifornite) {
      const cella = await Cell.findOne({
        cellaId,
        lockerId: id,
      });
      if (!cella) {
        throw new NotFoundError(
          `Cella ${cellaId} non trovata o non appartiene al locker ${id}`
        );
      }
    }

    // Salva foto se presente
    let fotoUrl = null;
    if (foto) {
      try {
        fotoUrl = await savePhoto(foto, `supply-${id}-${Date.now()}`);
      } catch (error) {
        throw new ValidationError(`Errore salvataggio foto: ${error.message}`);
      }
    }

    // Aggiorna stato celle se necessario
    // Per MVP, possiamo solo loggare il rifornimento
    // In futuro, può essere creato modello ManutenzioneLog

    // Crea audit
    try {
      const auditId = await AuditOperatore.generateAuditId();
      await AuditOperatore.create({
        auditId,
        operatoreId: operatoreObjectId,
        azione: 'rifornimento',
        entita: 'locker',
        entitaId: id,
        dettagli: {
          celleRifornite,
          materiali,
          fotoUrl,
        },
        timestamp: new Date(),
        ipAddress: req.ip,
        userAgent: req.get('user-agent'),
      });
    } catch (auditError) {
      logger.warn('Errore creazione audit rifornimento:', auditError);
    }

    logger.info(
      `Rifornimento locker ${id} registrato da operatore ${operatoreId}: ${celleRifornite.length} celle`
    );

    res.json({
      success: true,
      data: {
        message: 'Rifornimento registrato con successo',
        lockerId: id,
        celleRifornite,
        materiali: materiali || [],
        fotoUrl,
        note: note || null,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * POST /api/v1/admin/lockers/:id/maintenance-log
 * Log manutenzione
 * RF14: Log manutenzione
 */
export async function logMaintenance(req, res, next) {
  try {
    const { id } = req.params;
    const {
      tipoManutenzione,
      descrizione,
      interventiEseguiti,
      materialiUtilizzati,
      durataMinuti,
      costo,
      foto,
      note,
    } = req.body;
    const operatoreId = req.user.userId;

    // Converti operatoreId (stringa) in ObjectId
    const operatoreObjectId = new mongoose.Types.ObjectId(operatoreId);

    // Validazione
    if (!tipoManutenzione) {
      throw new ValidationError('tipoManutenzione è obbligatorio');
    }

    const tipiValidi = ['preventiva', 'correttiva', 'emergenza'];
    if (!tipiValidi.includes(tipoManutenzione)) {
      throw new ValidationError(
        `tipoManutenzione non valido. Valori accettati: ${tipiValidi.join(', ')}`
      );
    }

    if (!descrizione) {
      throw new ValidationError('descrizione è obbligatoria');
    }

    // Trova Locker
    const locker = await Locker.findOne({ lockerId: id });

    if (!locker) {
      throw new NotFoundError('Locker non trovato');
    }

    // Salva foto se presente
    let fotoUrl = null;
    if (foto) {
      try {
        fotoUrl = await savePhoto(foto, `maintenance-${id}-${Date.now()}`);
      } catch (error) {
        throw new ValidationError(`Errore salvataggio foto: ${error.message}`);
      }
    }

    // Aggiorna dataUltimaManutenzione su Locker
    locker.dataUltimaManutenzione = new Date();
    locker.dataAggiornamento = new Date();
    await locker.save();

    // Crea audit (per MVP, usiamo audit come log manutenzione)
    try {
      const auditId = await AuditOperatore.generateAuditId();
      await AuditOperatore.create({
        auditId,
        operatoreId: operatoreObjectId,
        azione: 'manutenzione',
        entita: 'locker',
        entitaId: id,
        dettagli: {
          tipoManutenzione,
          descrizione,
          interventiEseguiti,
          materialiUtilizzati,
          durataMinuti,
          costo,
          fotoUrl,
          note,
        },
        timestamp: new Date(),
        ipAddress: req.ip,
        userAgent: req.get('user-agent'),
      });
    } catch (auditError) {
      logger.warn('Errore creazione audit manutenzione:', auditError);
    }

    logger.info(
      `Manutenzione locker ${id} registrata da operatore ${operatoreId}: ${tipoManutenzione}`
    );

    res.json({
      success: true,
      data: {
        message: 'Manutenzione registrata con successo',
        lockerId: id,
        tipoManutenzione,
        descrizione,
        interventiEseguiti: interventiEseguiti || [],
        materialiUtilizzati: materialiUtilizzati || [],
        durataMinuti: durataMinuti || null,
        costo: costo || null,
        fotoUrl,
        note: note || null,
        dataManutenzione: new Date(),
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/admin/commercial-cells
 * Lista celle commerciali
 * RF17: Lista celle commerciali
 */
export async function getAllCommercialCells(req, res, next) {
  try {
    const { page = 1, limit = 20, assegnata } = req.query;

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
      $or: [{ tipo: 'commerciale' }, { tipo: 'pickup' }],
    };

    // Filtro assegnata
    if (assegnata !== undefined) {
      const isAssegnata = assegnata === 'true' || assegnata === true;
      if (isAssegnata) {
        query.negozioId = { $ne: null };
      } else {
        query.$or = [
          { negozioId: null },
          { negozioId: { $exists: false } },
        ];
      }
    }

    // Calcola skip
    const skip = (pageNum - 1) * limitNum;

    // Trova celle commerciali
    const celle = await Cell.find(query)
      .sort({ lockerId: 1, cellaId: 1 })
      .skip(skip)
      .limit(limitNum)
      .lean();

    // Formatta risposte
    const items = await Promise.all(
      celle.map(async (cella) => {
        const locker = await Locker.findOne({ lockerId: cella.lockerId }).lean();
        let shopName = null;
        if (cella.negozioId) {
          try {
            const shopObjectId = new mongoose.Types.ObjectId(cella.negozioId);
            const shop = await User.findById(shopObjectId).lean();
            if (shop) {
              shopName = `${shop.nome} ${shop.cognome}`;
            }
          } catch (error) {
            // Ignora errori di conversione ObjectId
          }
        }

        return {
          id: cella.cellaId,
          lockerId: cella.lockerId,
          lockerName: locker?.nome || null,
          shopId: cella.negozioId || null,
          shopName,
          startDate: cella.dataInizio || null,
          endDate: cella.dataFine || null,
          status: cella.stato || 'disponibile',
          notes: cella.note || null,
        };
      })
    );

    // Calcola total
    const total = await Cell.countDocuments(query);
    const totalPages = Math.ceil(total / limitNum);

    logger.info(
      `Celle commerciali recuperate: ${items.length} items (page ${pageNum}/${totalPages})`
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
 * POST /api/v1/admin/commercial-cells/assign
 * Assegnare cella a negozio
 * RF17: Assegnare cella a negozio
 */
export async function assignCommercialCell(req, res, next) {
  try {
    const { cellaId, lockerId, negozioId, dataInizio, dataFine, note } =
      req.body;
    const operatoreId = req.user.userId;

    // Converti operatoreId (stringa) in ObjectId
    const operatoreObjectId = new mongoose.Types.ObjectId(operatoreId);

    // Validazione
    if (!cellaId) {
      throw new ValidationError('cellaId è obbligatorio');
    }
    if (!lockerId) {
      throw new ValidationError('lockerId è obbligatorio');
    }
    if (!negozioId) {
      throw new ValidationError('negozioId è obbligatorio');
    }

    // Trova Cell
    const cella = await Cell.findOne({
      cellaId,
      lockerId,
    });

    if (!cella) {
      throw new NotFoundError(
        `Cella ${cellaId} non trovata o non appartiene al locker ${lockerId}`
      );
    }

    // Verifica tipo cella
    if (cella.tipo !== 'commerciale' && cella.tipo !== 'pickup') {
      throw new ValidationError(
        `Cella ${cellaId} non è di tipo commerciale o pickup`
      );
    }

    // Verifica negozioId
    try {
      const negozioObjectId = new mongoose.Types.ObjectId(negozioId);
      const negozio = await User.findById(negozioObjectId).lean();
      if (!negozio) {
        throw new NotFoundError(`Negoziante ${negozioId} non trovato`);
      }
    } catch (error) {
      if (error instanceof NotFoundError) {
        throw error;
      }
      throw new ValidationError('negozioId non valido');
    }

    // Verifica cella non già assegnata
    if (cella.negozioId && cella.negozioId.toString() === negozioId) {
      throw new ValidationError('Cella già assegnata a questo negozio');
    }

    // Aggiorna cella
    cella.negozioId = negozioId;
    if (dataInizio) {
      cella.dataInizio = new Date(dataInizio);
    } else {
      cella.dataInizio = new Date();
    }
    if (dataFine) {
      cella.dataFine = new Date(dataFine);
    }
    cella.stato = 'assegnata';
    if (note) {
      cella.note = note;
    }

    await cella.save();

    // Crea audit
    try {
      const auditId = await AuditOperatore.generateAuditId();
      await AuditOperatore.create({
        auditId,
        operatoreId: operatoreObjectId,
        azione: 'assegnazione_cella',
        entita: 'cella',
        entitaId: cellaId,
        dettagli: {
          lockerId,
          negozioId,
          dataInizio: cella.dataInizio,
          dataFine: cella.dataFine,
        },
        timestamp: new Date(),
        ipAddress: req.ip,
        userAgent: req.get('user-agent'),
      });
    } catch (auditError) {
      logger.warn('Errore creazione audit assegnazione cella:', auditError);
    }

    // Formatta risposta
    const locker = await Locker.findOne({ lockerId }).lean();
    const negozio = await User.findById(negozioId).lean();

    logger.info(
      `Cella commerciale ${cellaId} assegnata a negozio ${negozioId} da operatore ${operatoreId}`
    );

    res.json({
      success: true,
      data: {
        cell: {
          id: cella.cellaId,
          lockerId: cella.lockerId,
          lockerName: locker?.nome || null,
          shopId: cella.negozioId,
          shopName: negozio
            ? `${negozio.nome} ${negozio.cognome}`
            : null,
          startDate: cella.dataInizio,
          endDate: cella.dataFine,
          status: cella.stato,
          notes: cella.note,
        },
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * PUT /api/v1/admin/commercial-cells/:id
 * Modificare assegnazione
 * RF17: Modificare assegnazione
 */
export async function updateCommercialCell(req, res, next) {
  try {
    const { id } = req.params;
    const { negozioId, dataInizio, dataFine, note } = req.body;
    const operatoreId = req.user.userId;

    // Converti operatoreId (stringa) in ObjectId
    const operatoreObjectId = new mongoose.Types.ObjectId(operatoreId);

    // Trova Cell
    const cella = await Cell.findOne({ cellaId: id });

    if (!cella) {
      throw new NotFoundError('Cella non trovata');
    }

    // Verifica tipo cella
    if (cella.tipo !== 'commerciale' && cella.tipo !== 'pickup') {
      throw new ValidationError('Cella non è di tipo commerciale o pickup');
    }

    // Aggiorna campi
    if (negozioId !== undefined) {
      // Verifica negozioId se presente
      if (negozioId) {
        try {
          const negozioObjectId = new mongoose.Types.ObjectId(negozioId);
          const negozio = await User.findById(negozioObjectId).lean();
          if (!negozio) {
            throw new NotFoundError(`Negoziante ${negozioId} non trovato`);
          }
        } catch (error) {
          if (error instanceof NotFoundError) {
            throw error;
          }
          throw new ValidationError('negozioId non valido');
        }
      }
      cella.negozioId = negozioId || null;
    }

    if (dataInizio !== undefined) {
      cella.dataInizio = dataInizio ? new Date(dataInizio) : null;
    }

    if (dataFine !== undefined) {
      cella.dataFine = dataFine ? new Date(dataFine) : null;
    }

    if (note !== undefined) {
      cella.note = note || null;
    }

    await cella.save();

    // Crea audit
    try {
      const auditId = await AuditOperatore.generateAuditId();
      await AuditOperatore.create({
        auditId,
        operatoreId: operatoreObjectId,
        azione: 'assegnazione_cella',
        entita: 'cella',
        entitaId: id,
        dettagli: {
          azione: 'modifica',
          negozioId,
          dataInizio: cella.dataInizio,
          dataFine: cella.dataFine,
        },
        timestamp: new Date(),
        ipAddress: req.ip,
        userAgent: req.get('user-agent'),
      });
    } catch (auditError) {
      logger.warn('Errore creazione audit modifica cella:', auditError);
    }

    // Formatta risposta
    const locker = await Locker.findOne({ lockerId: cella.lockerId }).lean();
    let shopName = null;
    if (cella.negozioId) {
      const negozio = await User.findById(cella.negozioId).lean();
      if (negozio) {
        shopName = `${negozio.nome} ${negozio.cognome}`;
      }
    }

    logger.info(`Cella commerciale ${id} aggiornata da operatore ${operatoreId}`);

    res.json({
      success: true,
      data: {
        cell: {
          id: cella.cellaId,
          lockerId: cella.lockerId,
          lockerName: locker?.nome || null,
          shopId: cella.negozioId || null,
          shopName,
          startDate: cella.dataInizio,
          endDate: cella.dataFine,
          status: cella.stato,
          notes: cella.note,
        },
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * GET /api/v1/admin/commercial-cells/:id/usage
 * Utilizzo cella commerciale
 * RF17: Utilizzo cella commerciale
 */
export async function getCommercialCellUsage(req, res, next) {
  try {
    const { id } = req.params;
    const { periodo = 'mese' } = req.query;

    // Valida periodo
    const periodiValidi = ['giorno', 'settimana', 'mese', 'anno'];
    if (!periodiValidi.includes(periodo)) {
      throw new ValidationError(
        `periodo non valido. Valori accettati: ${periodiValidi.join(', ')}`
      );
    }

    // Trova Cell
    const cella = await Cell.findOne({ cellaId: id }).lean();

    if (!cella) {
      throw new NotFoundError('Cella non trovata');
    }

    // Verifica tipo cella
    if (cella.tipo !== 'commerciale' && cella.tipo !== 'pickup') {
      throw new ValidationError('Cella non è di tipo commerciale o pickup');
    }

    // Calcola periodo data
    const now = new Date();
    let startDate = new Date();

    switch (periodo) {
      case 'giorno':
        startDate.setHours(0, 0, 0, 0);
        break;
      case 'settimana':
        startDate.setDate(now.getDate() - 7);
        break;
      case 'mese':
        startDate.setMonth(now.getMonth() - 1);
        break;
      case 'anno':
        startDate.setFullYear(now.getFullYear() - 1);
        break;
    }

    // Aggregazione utilizzi
    const usageStats = await Noleggio.aggregate([
      {
        $match: {
          cellaId: id,
          tipo: 'pickup',
          dataInizio: { $gte: startDate },
        },
      },
      {
        $facet: {
          totaleUtilizzi: [{ $count: 'count' }],
          perPeriodo: [
            {
              $group: {
                _id: {
                  $dateToString: {
                    format:
                      periodo === 'giorno'
                        ? '%Y-%m-%d'
                        : periodo === 'settimana'
                        ? '%Y-%W'
                        : periodo === 'mese'
                        ? '%Y-%m'
                        : '%Y',
                    date: '$dataInizio',
                  },
                },
                count: { $sum: 1 },
              },
            },
            { $sort: { _id: 1 } },
          ],
          perNegozio: [
            {
              $group: {
                _id: '$negozioId',
                count: { $sum: 1 },
              },
            },
            { $sort: { count: -1 } },
          ],
          tempoMedio: [
            {
              $project: {
                durata: {
                  $subtract: [
                    { $ifNull: ['$dataFine', new Date()] },
                    '$dataInizio',
                  ],
                },
              },
            },
            {
              $group: {
                _id: null,
                media: { $avg: '$durata' },
                count: { $sum: 1 },
              },
            },
          ],
        },
      },
    ]);

    const result = usageStats[0];
    const totale = result.totaleUtilizzi[0]?.count || 0;

    // Formatta per periodo
    const perPeriodo = result.perPeriodo.map((item) => ({
      periodo: item._id,
      count: item.count,
    }));

    // Formatta per negozio
    const perNegozio = await Promise.all(
      result.perNegozio.map(async (item) => {
        if (!item._id) return null;
        try {
          const negozioObjectId = new mongoose.Types.ObjectId(item._id);
          const negozio = await User.findById(negozioObjectId).lean();
          return {
            shopId: item._id,
            shopName: negozio
              ? `${negozio.nome} ${negozio.cognome}`
              : null,
            count: item.count,
          };
        } catch (error) {
          return {
            shopId: item._id,
            shopName: null,
            count: item.count,
          };
        }
      })
    );

    // Tempo medio utilizzo (in ore)
    const tempoMedio = result.tempoMedio[0]
      ? {
          mediaOre: (result.tempoMedio[0].media / (1000 * 60 * 60)).toFixed(2),
          count: result.tempoMedio[0].count,
        }
      : { mediaOre: 0, count: 0 };

    logger.info(`Utilizzo cella commerciale ${id} recuperato per periodo: ${periodo}`);

    res.json({
      success: true,
      data: {
        cellaId: id,
        periodo,
        totaleUtilizzi: totale,
        perPeriodo,
        perNegozio: perNegozio.filter((item) => item !== null),
        tempoMedioUtilizzo: tempoMedio,
      },
    });
  } catch (error) {
    next(error);
  }
}

export default {
  getAllLockers,
  updateLockerStatus,
  setMaintenance,
  restoreLocker,
  getLockerProtocol,
  registerSupply,
  logMaintenance,
  getAllCommercialCells,
  assignCommercialCell,
  updateCommercialCell,
  getCommercialCellUsage,
};

