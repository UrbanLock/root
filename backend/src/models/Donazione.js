import mongoose from 'mongoose';
import logger from '../utils/logger.js';

const donazioneSchema = new mongoose.Schema(
  {
    donazioneId: {
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
    lockerId: {
      type: String,
      default: null,
      index: true,
    },
    cellaId: {
      type: String,
      default: null,
      index: true,
    },
    nomeOggetto: {
      type: String,
      required: true,
      trim: true,
    },
    tipoAttrezzatura: {
      type: String,
      required: true,
      enum: ['sportiva', 'elettronica', 'abbigliamento', 'libri', 'giochi', 'altro'],
      trim: true,
    },
    categoria: {
      type: String,
      default: null,
      trim: true,
    },
    descrizione: {
      type: String,
      required: true,
      trim: true,
    },
    fotoUrl: {
      type: String,
      default: null,
    },
    stato: {
      type: String,
      enum: ['da_visionare', 'in_valutazione', 'in_ritiro', 'concluso', 'rifiutato'],
      default: 'da_visionare',
      index: true,
    },
    dataCreazione: {
      type: Date,
      default: Date.now,
      index: true,
    },
    dataRitiro: {
      type: Date,
      default: null,
    },
    motivoRifiuto: {
      type: String,
      default: null,
      trim: true,
    },
    operatoreAssegnatoId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
      index: true,
    },
    documentazioneUrl: {
      type: String,
      default: null,
    },
    noteOperatore: {
      type: String,
      default: null,
      trim: true,
    },
    dataAggiornamento: {
      type: Date,
      default: Date.now,
    },
  },
  {
    timestamps: false, // Usiamo dataCreazione manuale
    collection: 'donazione', // Nome collezione MongoDB
  }
);

// Index per performance
donazioneSchema.index({ utenteId: 1, stato: 1 });
donazioneSchema.index({ utenteId: 1, dataCreazione: -1 });
donazioneSchema.index({ stato: 1, dataCreazione: -1 });
donazioneSchema.index({ operatoreAssegnatoId: 1 });

// Metodo per rimuovere campi interni dalla serializzazione (GDPR RNF5)
donazioneSchema.methods.toJSON = function () {
  const donazioneObject = this.toObject();
  delete donazioneObject.__v;
  return donazioneObject;
};

/**
 * Metodo statico: genera donazioneId univoco
 * Formato: "DON-001", "DON-002", ecc.
 */
donazioneSchema.statics.generateDonazioneId = async function () {
  const lastDonazione = await this.findOne({}, { donazioneId: 1 })
    .sort({ donazioneId: -1 })
    .lean();

  if (!lastDonazione || !lastDonazione.donazioneId) {
    return 'DON-001';
  }

  // Estrai numero da donazioneId (es. "DON-001" -> 1)
  const match = lastDonazione.donazioneId.match(/DON-(\d+)/);
  if (match) {
    const lastNumber = parseInt(match[1], 10);
    const nextNumber = lastNumber + 1;
    return `DON-${nextNumber.toString().padStart(3, '0')}`;
  }

  // Fallback se formato non riconosciuto
  return 'DON-001';
};

const Donazione = mongoose.model('Donazione', donazioneSchema);

export default Donazione;


