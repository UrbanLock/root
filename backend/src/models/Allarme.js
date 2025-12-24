import mongoose from 'mongoose';
import logger from '../utils/logger.js';

const allarmeSchema = new mongoose.Schema(
  {
    allarmeId: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    lockerId: {
      type: String,
      required: true,
      index: true,
    },
    sensoreId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Sensore',
      default: null,
      index: true,
    },
    tipo: {
      type: String,
      required: true,
      enum: [
        'temperatura',
        'umidita',
        'movimento',
        'apertura',
        'peso',
        'batteria',
        'guasto',
        'altro',
      ],
      trim: true,
      index: true,
    },
    severita: {
      type: String,
      enum: ['bassa', 'media', 'alta', 'critica'],
      default: 'media',
      index: true,
    },
    descrizione: {
      type: String,
      required: true,
      trim: true,
    },
    stato: {
      type: String,
      enum: ['attivo', 'risolto', 'falso_allarme'],
      default: 'attivo',
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
    operatoreRisoluzioneId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    azioneIntrapresa: {
      type: String,
      default: null,
      trim: true,
    },
  },
  {
    timestamps: false,
    collection: 'allarme',
  }
);

// Index per performance
allarmeSchema.index({ lockerId: 1, stato: 1 });
allarmeSchema.index({ sensoreId: 1 });
allarmeSchema.index({ tipo: 1, severita: 1 });
allarmeSchema.index({ stato: 1, severita: -1, dataCreazione: -1 });
allarmeSchema.index({ dataCreazione: -1 });

// Metodo per rimuovere campi interni dalla serializzazione (GDPR RNF5)
allarmeSchema.methods.toJSON = function () {
  const allarmeObject = this.toObject();
  delete allarmeObject.__v;
  return allarmeObject;
};

/**
 * Metodo statico: genera allarmeId univoco
 * Formato: "ALL-001", "ALL-002", ecc.
 */
allarmeSchema.statics.generateAllarmeId = async function () {
  const lastAllarme = await this.findOne({}, { allarmeId: 1 })
    .sort({ allarmeId: -1 })
    .lean();

  if (!lastAllarme || !lastAllarme.allarmeId) {
    return 'ALL-001';
  }

  const match = lastAllarme.allarmeId.match(/ALL-(\d+)/);
  if (match) {
    const lastNumber = parseInt(match[1], 10);
    const nextNumber = lastNumber + 1;
    return `ALL-${nextNumber.toString().padStart(3, '0')}`;
  }

  return 'ALL-001';
};

const Allarme = mongoose.model('Allarme', allarmeSchema);

export default Allarme;

