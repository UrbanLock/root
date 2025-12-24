import mongoose from 'mongoose';
import logger from '../utils/logger.js';

const operatoreSchema = new mongoose.Schema(
  {
    operatoreId: {
      type: String,
      required: false, // Opzionale per compatibilità con dati esistenti
      unique: true,
      sparse: true,
      index: true,
      trim: true,
    },
    // Campi per autenticazione username/password
    username: {
      type: String,
      required: false, // Opzionale per compatibilità con dati esistenti
      unique: true,
      sparse: true,
      index: true,
      trim: true,
      lowercase: true,
    },
    passwordHash: {
      type: String,
      required: false, // Opzionale per compatibilità con dati esistenti
      select: false, // Non includere di default nelle query
    },
    nome: {
      type: String,
      required: false, // Opzionale per compatibilità con dati esistenti
      trim: true,
    },
    cognome: {
      type: String,
      required: false, // Opzionale per compatibilità con dati esistenti
      trim: true,
    },
    attivo: {
      type: Boolean,
      default: true,
      index: true,
    },
    // Campi legacy (per compatibilità con struttura esistente)
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: false, // Opzionale per compatibilità
      unique: true,
      sparse: true,
      index: true,
    },
    matricola: {
      type: String,
      default: null,
      unique: true,
      sparse: true,
      index: true,
      trim: true,
    },
    reparto: {
      type: String,
      enum: ['manutenzione', 'logistica', 'amministrazione', 'altro'],
      default: null,
      trim: true,
      index: true,
    },
    specializzazione: {
      type: String,
      default: null,
      trim: true,
    },
    dataAssunzione: {
      type: Date,
      default: null,
    },
    stato: {
      type: String,
      enum: ['attivo', 'inattivo', 'sospeso'],
      default: 'attivo',
      index: true,
    },
    permessi: {
      type: [String],
      enum: [
        'gestione_locker',
        'gestione_celle',
        'reportistica',
        'gestione_operatori',
      ],
      default: [],
    },
    ultimoAccesso: {
      type: Date,
      default: null,
    },
    refreshToken: {
      type: String,
      default: null,
      select: false, // Non includere di default nelle query
    },
    note: {
      type: String,
      default: null,
      trim: true,
    },
  },
  {
    timestamps: false,
    collection: 'operatore',
    strict: false, // Permette campi aggiuntivi non definiti nello schema
  }
);

// Index
// Nota: username, operatoreId, userId, matricola, stato, reparto, attivo hanno già index: true nel campo
// Non serve definirli di nuovo qui

// Metodo per rimuovere campi interni dalla serializzazione (GDPR RNF5)
operatoreSchema.methods.toJSON = function () {
  const operatoreObject = this.toObject();
  delete operatoreObject.__v;
  return operatoreObject;
};

/**
 * Metodo statico: genera operatoreId univoco
 * Formato: "OPR-001", "OPR-002", ecc.
 */
operatoreSchema.statics.generateOperatoreId = async function () {
  const lastOperatore = await this.findOne({}, { operatoreId: 1 })
    .sort({ operatoreId: -1 })
    .lean();

  if (!lastOperatore || !lastOperatore.operatoreId) {
    return 'OPR-001';
  }

  const match = lastOperatore.operatoreId.match(/OPR-(\d+)/);
  if (match) {
    const lastNumber = parseInt(match[1], 10);
    const nextNumber = lastNumber + 1;
    return `OPR-${nextNumber.toString().padStart(3, '0')}`;
  }

  return 'OPR-001';
};

const Operatore = mongoose.model('Operatore', operatoreSchema);

export default Operatore;

