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
      type: mongoose.Schema.Types.Mixed, // Accetta sia ObjectId che String
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
      required: false, // Reso opzionale
      enum: ['anomalia', 'guasto', 'vandalismo', 'pulizia', 'sicurezza', 'altro'],
      default: null,
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
      type: mongoose.Schema.Types.Mixed, // Accetta sia ObjectId che String
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
// Nota: segnalazioneId, utenteId, lockerId, cellaId, categoria, priorita, stato, dataCreazione, operatoreAssegnatoId, interventoManutenzioneId hanno già index: true nel campo
// Manteniamo solo gli indici composti necessari
segnalazioneSchema.index({ utenteId: 1, stato: 1 });
segnalazioneSchema.index({ utenteId: 1, dataCreazione: -1 });
segnalazioneSchema.index({ stato: 1, priorita: -1, dataCreazione: -1 });
segnalazioneSchema.index({ categoria: 1, stato: 1 });
segnalazioneSchema.index({ operatoreAssegnatoId: 1, stato: 1 });

// Metodo per rimuovere campi interni dalla serializzazione (GDPR RNF5)
segnalazioneSchema.methods.toJSON = function () {
  const segnalazioneObject = this.toObject();
  delete segnalazioneObject.__v;
  return segnalazioneObject;
};

/**
 * Metodo statico: genera segnalazioneId univoco
 *
 * Per evitare errori di chiave duplicata (E11000) dovuti a
 * eventuali dati "sporchi" o ambienti multipli, usiamo un
 * identificativo derivato da ObjectId, invece di leggere
 * l'ultimo record dal DB.
 *
 * Formato: SEG-<6caratteri esadecimali>
 * Esempio: SEG-A1B2C3
 */
segnalazioneSchema.statics.generateSegnalazioneId = async function () {
  const objectId = new mongoose.Types.ObjectId().toString();
  const suffix = objectId.slice(-6).toUpperCase();
  return `SEG-${suffix}`;
};

const Segnalazione = mongoose.model('Segnalazione', segnalazioneSchema);

export default Segnalazione;

