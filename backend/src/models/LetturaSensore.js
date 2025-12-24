import mongoose from 'mongoose';
import logger from '../utils/logger.js';

const letturaSensoreSchema = new mongoose.Schema(
  {
    letturaId: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    sensoreId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Sensore',
      required: true,
      index: true,
    },
    valore: {
      type: Number,
      required: true,
    },
    unitaMisura: {
      type: String,
      default: null,
      trim: true,
    },
    timestamp: {
      type: Date,
      default: Date.now,
      index: true,
    },
    stato: {
      type: String,
      enum: ['normale', 'warning', 'critico'],
      default: 'normale',
      index: true,
    },
    note: {
      type: String,
      default: null,
      trim: true,
    },
  },
  {
    timestamps: false,
    collection: 'lettura_sensore',
  }
);

// Index per performance
letturaSensoreSchema.index({ sensoreId: 1, timestamp: -1 });
letturaSensoreSchema.index({ timestamp: -1 });
letturaSensoreSchema.index({ stato: 1 });

// Metodo per rimuovere campi interni dalla serializzazione (GDPR RNF5)
letturaSensoreSchema.methods.toJSON = function () {
  const letturaObject = this.toObject();
  delete letturaObject.__v;
  return letturaObject;
};

/**
 * Metodo statico: genera letturaId univoco
 * Formato: "LET-001", "LET-002", ecc.
 */
letturaSensoreSchema.statics.generateLetturaId = async function () {
  const lastLettura = await this.findOne({}, { letturaId: 1 })
    .sort({ letturaId: -1 })
    .lean();

  if (!lastLettura || !lastLettura.letturaId) {
    return 'LET-001';
  }

  const match = lastLettura.letturaId.match(/LET-(\d+)/);
  if (match) {
    const lastNumber = parseInt(match[1], 10);
    const nextNumber = lastNumber + 1;
    return `LET-${nextNumber.toString().padStart(3, '0')}`;
  }

  return 'LET-001';
};

const LetturaSensore = mongoose.model('LetturaSensore', letturaSensoreSchema);

export default LetturaSensore;

