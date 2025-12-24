import mongoose from 'mongoose';
import logger from '../utils/logger.js';

const categoriaLockerSchema = new mongoose.Schema(
  {
    categoriaId: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    nome: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      index: true,
    },
    descrizione: {
      type: String,
      default: null,
      trim: true,
    },
    icona: {
      type: String,
      default: null,
    },
    colore: {
      type: String,
      default: null,
      trim: true,
    },
    caratteristiche: {
      type: [String],
      default: [],
    },
    attiva: {
      type: Boolean,
      default: true,
      index: true,
    },
    dataCreazione: {
      type: Date,
      default: Date.now,
    },
    dataModifica: {
      type: Date,
      default: Date.now,
    },
  },
  {
    timestamps: false,
    collection: 'categoria_locker',
  }
);

// Index
categoriaLockerSchema.index({ nome: 1 });
categoriaLockerSchema.index({ attiva: 1 });

// Metodo per rimuovere campi interni dalla serializzazione (GDPR RNF5)
categoriaLockerSchema.methods.toJSON = function () {
  const categoriaObject = this.toObject();
  delete categoriaObject.__v;
  return categoriaObject;
};

/**
 * Metodo statico: genera categoriaId univoco
 * Formato: "CAT-001", "CAT-002", ecc.
 */
categoriaLockerSchema.statics.generateCategoriaId = async function () {
  const lastCategoria = await this.findOne({}, { categoriaId: 1 })
    .sort({ categoriaId: -1 })
    .lean();

  if (!lastCategoria || !lastCategoria.categoriaId) {
    return 'CAT-001';
  }

  const match = lastCategoria.categoriaId.match(/CAT-(\d+)/);
  if (match) {
    const lastNumber = parseInt(match[1], 10);
    const nextNumber = lastNumber + 1;
    return `CAT-${nextNumber.toString().padStart(3, '0')}`;
  }

  return 'CAT-001';
};

const CategoriaLocker = mongoose.model('CategoriaLocker', categoriaLockerSchema);

export default CategoriaLocker;

