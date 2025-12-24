import mongoose from 'mongoose';
import logger from '../utils/logger.js';

const segnalazioneSchema = new mongoose.Schema(
  {
    segnalazioneId: {
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
    categoria: {
      type: String,
      required: true,
      enum: ['anomalia', 'guasto', 'vandalismo', 'pulizia', 'sicurezza', 'altro'],
      trim: true,
      index: true,
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
    priorita: {
      type: String,
      enum: ['alta', 'media', 'bassa'],
      default: 'media',
      index: true,
    },
    stato: {
      type: String,
      enum: ['aperta', 'in_analisi', 'assegnata', 'in_lavorazione', 'risolta', 'chiusa'],
      default: 'aperta',
      index: true,
    },
    dataCreazione: {
      type: Date,
      default: Date.now,
      index: true,
    },
    dataRisoluzione: {
      type: Date,
      default: null,
    },
    operatoreAssegnatoId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
      index: true,
    },
    interventoManutenzioneId: {
      type: String,
      default: null,
      index: true,
    },
    noteOperatore: {
      type: String,
      default: null,
      trim: true,
    },
    rispostaOperatore: {
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
    collection: 'segnalazione', // Nome collezione MongoDB
  }
);

// Index per performance
segnalazioneSchema.index({ utenteId: 1, stato: 1 });
segnalazioneSchema.index({ utenteId: 1, dataCreazione: -1 });
segnalazioneSchema.index({ stato: 1, priorita: -1, dataCreazione: -1 });
segnalazioneSchema.index({ categoria: 1, stato: 1 });
segnalazioneSchema.index({ operatoreAssegnatoId: 1, stato: 1 });
segnalazioneSchema.index({ interventoManutenzioneId: 1 });

// Metodo per rimuovere campi interni dalla serializzazione (GDPR RNF5)
segnalazioneSchema.methods.toJSON = function () {
  const segnalazioneObject = this.toObject();
  delete segnalazioneObject.__v;
  return segnalazioneObject;
};

/**
 * Metodo statico: genera segnalazioneId univoco
 * Formato: "SEG-001", "SEG-002", ecc.
 */
segnalazioneSchema.statics.generateSegnalazioneId = async function () {
  const lastSegnalazione = await this.findOne({}, { segnalazioneId: 1 })
    .sort({ segnalazioneId: -1 })
    .lean();

  if (!lastSegnalazione || !lastSegnalazione.segnalazioneId) {
    return 'SEG-001';
  }

  // Estrai numero da segnalazioneId (es. "SEG-001" -> 1)
  const match = lastSegnalazione.segnalazioneId.match(/SEG-(\d+)/);
  if (match) {
    const lastNumber = parseInt(match[1], 10);
    const nextNumber = lastNumber + 1;
    return `SEG-${nextNumber.toString().padStart(3, '0')}`;
  }

  // Fallback se formato non riconosciuto
  return 'SEG-001';
};

const Segnalazione = mongoose.model('Segnalazione', segnalazioneSchema);

export default Segnalazione;

