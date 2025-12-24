import mongoose from 'mongoose';
import logger from '../utils/logger.js';

const sensoreSchema = new mongoose.Schema(
  {
    sensoreId: {
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
        'altro',
      ],
      trim: true,
      index: true,
    },
    marca: {
      type: String,
      default: null,
      trim: true,
    },
    modello: {
      type: String,
      default: null,
      trim: true,
    },
    posizione: {
      type: String,
      default: null,
      trim: true,
    },
    stato: {
      type: String,
      enum: ['attivo', 'inattivo', 'guasto'],
      default: 'attivo',
      index: true,
    },
    dataInstallazione: {
      type: Date,
      default: Date.now,
    },
    dataUltimaManutenzione: {
      type: Date,
      default: null,
    },
    sogliaMinima: {
      type: Number,
      default: null,
    },
    sogliaMassima: {
      type: Number,
      default: null,
    },
    unitaMisura: {
      type: String,
      default: null,
      trim: true,
    },
  },
  {
    timestamps: false,
    collection: 'sensore',
  }
);

// Index
sensoreSchema.index({ lockerId: 1, tipo: 1 });
sensoreSchema.index({ stato: 1 });
sensoreSchema.index({ tipo: 1 });

// Metodo per rimuovere campi interni dalla serializzazione (GDPR RNF5)
sensoreSchema.methods.toJSON = function () {
  const sensoreObject = this.toObject();
  delete sensoreObject.__v;
  return sensoreObject;
};

/**
 * Metodo statico: genera sensoreId univoco
 * Formato: "SEN-001", "SEN-002", ecc.
 */
sensoreSchema.statics.generateSensoreId = async function () {
  const lastSensore = await this.findOne({}, { sensoreId: 1 })
    .sort({ sensoreId: -1 })
    .lean();

  if (!lastSensore || !lastSensore.sensoreId) {
    return 'SEN-001';
  }

  const match = lastSensore.sensoreId.match(/SEN-(\d+)/);
  if (match) {
    const lastNumber = parseInt(match[1], 10);
    const nextNumber = lastNumber + 1;
    return `SEN-${nextNumber.toString().padStart(3, '0')}`;
  }

  return 'SEN-001';
};

const Sensore = mongoose.model('Sensore', sensoreSchema);

export default Sensore;

