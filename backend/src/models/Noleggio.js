import mongoose from 'mongoose';
import QRCode from 'qrcode';
import { randomUUID } from 'crypto';
import logger from '../utils/logger.js';

const noleggioSchema = new mongoose.Schema(
  {
    noleggioId: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    utenteId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    cellaId: {
      type: String,
      required: true,
      index: true,
    },
    lockerId: {
      type: String,
      required: true,
      index: true,
    },
    tipo: {
      type: String,
      enum: ['deposito', 'prestito', 'ordini'],
      default: 'deposito',
      index: true,
    },
    stato: {
      type: String,
      enum: ['attivo', 'terminato', 'annullato'],
      default: 'attivo',
      index: true,
    },
    dataInizio: {
      type: Date,
      required: true,
      index: true,
    },
    oraInizio: {
      type: String,
      required: true,
      match: /^([0-1][0-9]|2[0-3]):[0-5][0-9]$/, // HH:mm format
    },
    dataFine: {
      type: Date,
      default: null,
    },
    oraFine: {
      type: String,
      default: null,
      match: /^([0-1][0-9]|2[0-3]):[0-5][0-9]$/, // HH:mm format
    },
    costo: {
      type: Number,
      default: 0,
    },
    // RF3: Supporto QR/Bluetooth
    qrCode: {
      type: String,
      default: null,
    },
    bluetoothToken: {
      type: String,
      default: null,
    },
    // RF3: Geolocalizzazione attiva
    geolocalizzazione: {
      lat: {
        type: Number,
        default: null,
      },
      lng: {
        type: Number,
        default: null,
      },
    },
    // RF3: Segnalazione anomalie
    fotoAnomalia: {
      type: String,
      default: null,
    },
    // RF3: Gestione errori
    messaggioErrore: {
      type: String,
      default: null,
    },
    dataCreazione: {
      type: Date,
      default: Date.now,
    },
    dataAggiornamento: {
      type: Date,
      default: Date.now,
    },
  },
  {
    timestamps: false, // Usiamo dataCreazione/dataAggiornamento manuali
    collection: 'noleggio', // Nome collezione MongoDB
  }
);

// Index composti per query frequenti (i singoli index sono già definiti con index: true)
noleggioSchema.index({ utenteId: 1, stato: 1 }); // Query celle attive
noleggioSchema.index({ cellaId: 1, stato: 1 }); // Query celle occupate

// Virtual: isActive getter
noleggioSchema.virtual('isActive').get(function () {
  return this.stato === 'attivo';
});

// Metodo: calcola durata
noleggioSchema.methods.getDuration = function () {
  if (!this.dataInizio) return null;
  const end = this.dataFine || new Date();
  return end - this.dataInizio;
};

// Metodo: formatta come ActiveCell per frontend
noleggioSchema.methods.toActiveCellFormat = async function () {
  const Locker = mongoose.model('Locker');
  const locker = await Locker.findOne({ lockerId: this.lockerId }).lean();

  // Calcola cellNumber da cellaId (es. "CEL-001-1" → "Cella 1")
  const cellNumberMatch = this.cellaId.match(/CEL-[\w-]+-(\d+)/);
  const cellNumber = cellNumberMatch
    ? `Cella ${parseInt(cellNumberMatch[1], 10)}`
    : this.cellaId;

  // Mapping tipo DB → Frontend
  const tipoMapping = {
    deposito: 'deposited',
    prestito: 'borrow',
    ordini: 'pickup',
  };

  // Determina lockerType da locker
  let lockerType = 'personali'; // default
  if (locker) {
    if (locker.tipo) {
      lockerType = locker.tipo;
    } else {
      // Mapping da dimensione se tipo non presente
      const dimensioneMapping = {
        small: 'personali',
        medium: 'personali',
        large: 'sportivi',
      };
      lockerType = dimensioneMapping[locker.dimensione] || 'personali';
    }
  }

  return {
    id: this.noleggioId,
    lockerId: this.lockerId,
    lockerName: locker?.nome || 'Locker',
    lockerType: lockerType,
    cellNumber: cellNumber,
    cellId: this.cellaId,
    startTime: this.dataInizio,
    endTime: this.dataFine || null,
    type: tipoMapping[this.tipo] || 'deposited',
  };
};

// Metodo: toJSON formatta per frontend
noleggioSchema.methods.toJSON = function () {
  const noleggioObject = this.toObject({ virtuals: true });
  // GDPR RNF5: Non esporre dati sensibili
  delete noleggioObject.messaggioErrore; // Rimuovi messaggi errore interni
  return noleggioObject;
};

// Metodo statico: genera noleggioId sequenziale
noleggioSchema.statics.generateNoleggioId = async function () {
  const lastNoleggio = await this.findOne({}, { noleggioId: 1 })
    .sort({ noleggioId: -1 })
    .lean();

  if (!lastNoleggio || !lastNoleggio.noleggioId) {
    return 'NOL-001';
  }

  const match = lastNoleggio.noleggioId.match(/NOL-(\d+)/);
  if (match) {
    const nextNumber = parseInt(match[1], 10) + 1;
    return `NOL-${nextNumber.toString().padStart(3, '0')}`;
  }

  return 'NOL-001';
};

/**
 * Metodo statico: genera QR code reale (RF3)
 * 
 * ✅ IMPLEMENTAZIONE REALE
 * Genera QR code con dati noleggio per scanner reale
 * 
 * @param {String} noleggioId - ID noleggio
 * @param {String} cellaId - ID cella
 * @param {String} lockerId - ID locker
 * @returns {Promise<String>} QR code come stringa JSON (per scanner) o base64 (per visualizzazione)
 */
noleggioSchema.statics.generateQRCode = async function (noleggioId, cellaId, lockerId) {
  try {
    // Crea oggetto con dati noleggio per QR code
    const qrData = {
      noleggioId,
      cellaId,
      lockerId,
      timestamp: Date.now(),
      type: 'cell_access',
      version: '1.0',
    };

    // Genera QR code come stringa JSON (per scanner reale)
    // Lo scanner leggerà questa stringa e potrà validare il noleggio
    const qrCodeString = JSON.stringify(qrData);
    
    // Genera anche QR code come immagine base64 per visualizzazione (opzionale)
    // Può essere usato per mostrare QR code nell'app
    try {
      const qrCodeBase64 = await QRCode.toDataURL(qrCodeString, {
        errorCorrectionLevel: 'M',
        type: 'image/png',
        quality: 0.92,
        margin: 1,
        width: 256,
      });
      
      // Ritorna oggetto con entrambi i formati
      return {
        data: qrCodeString, // Per scanner/validazione
        image: qrCodeBase64, // Per visualizzazione
      };
    } catch (error) {
      // Se errore generazione immagine, ritorna solo stringa
      logger.warn('Errore generazione immagine QR code, uso solo stringa:', error);
      return qrCodeString;
    }
  } catch (error) {
    // Fallback a stringa semplice se errore
    logger.error('Errore generazione QR code:', error);
    return `QR-${noleggioId}-${Date.now()}`;
  }
};

/**
 * Metodo statico: genera Bluetooth token reale (RF3)
 * 
 * ✅ IMPLEMENTAZIONE REALE (UUID v4)
 * Genera UUID v4 standard per Bluetooth (compatibile con hardware reale)
 * 
 * Nota: L'integrazione completa con hardware Bluetooth richiede:
 * - Hardware Bluetooth sui locker
 * - Protocollo di comunicazione definito
 * - Libreria Bluetooth specifica (es: noble per Node.js)
 * 
 * @returns {String} UUID v4 standard per Bluetooth
 */
noleggioSchema.statics.generateBluetoothToken = function () {
  // Genera UUID v4 standard (RFC 4122)
  // Compatibile con hardware Bluetooth reale
  return randomUUID();
};

// Pre-save hook: aggiorna dataAggiornamento
noleggioSchema.pre('save', function (next) {
  this.dataAggiornamento = new Date();
  next();
});

const Noleggio = mongoose.model('Noleggio', noleggioSchema);

export default Noleggio;

