import mongoose from 'mongoose';
import logger from '../utils/logger.js';

const notificaSchema = new mongoose.Schema(
  {
    notificaId: {
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
    tipo: {
      type: String,
      enum: [
        'apertura_chiusura',
        'chiusura_temporanea',
        'nuova_postazione',
        'reminder_donazione',
        'reminder_restituzione',
        'sistema',
        'altro',
      ],
      required: true,
      index: true,
    },
    titolo: {
      type: String,
      required: true,
      trim: true,
    },
    messaggio: {
      type: String,
      required: true,
      trim: true,
    },
    payload: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },
    letta: {
      type: Boolean,
      default: false,
      index: true,
    },
    dataCreazione: {
      type: Date,
      default: Date.now,
      index: true,
    },
    dataLettura: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: false, // Usiamo dataCreazione manuale
    collection: 'notifica', // Nome collezione MongoDB
  }
);

// Index per performance
notificaSchema.index({ utenteId: 1, letta: 1 });
notificaSchema.index({ utenteId: 1, dataCreazione: -1 });
notificaSchema.index({ utenteId: 1, tipo: 1 });

// Metodo per rimuovere campi interni dalla serializzazione (GDPR RNF5)
notificaSchema.methods.toJSON = function () {
  const notificaObject = this.toObject();
  delete notificaObject.__v;
  return notificaObject;
};

/**
 * Metodo statico: genera notificaId univoco
 * Formato: "NOT-001", "NOT-002", ecc.
 */
notificaSchema.statics.generateNotificaId = async function () {
  const lastNotifica = await this.findOne({}, { notificaId: 1 })
    .sort({ notificaId: -1 })
    .lean();

  if (!lastNotifica || !lastNotifica.notificaId) {
    return 'NOT-001';
  }

  // Estrai numero da notificaId (es. "NOT-001" -> 1)
  const match = lastNotifica.notificaId.match(/NOT-(\d+)/);
  if (match) {
    const lastNumber = parseInt(match[1], 10);
    const nextNumber = lastNumber + 1;
    return `NOT-${nextNumber.toString().padStart(3, '0')}`;
  }

  // Fallback se formato non riconosciuto
  return 'NOT-001';
};

const Notifica = mongoose.model('Notifica', notificaSchema);

export default Notifica;


