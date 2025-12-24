import mongoose from 'mongoose';
import logger from '../utils/logger.js';

const auditOperatoreSchema = new mongoose.Schema(
  {
    auditId: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    operatoreId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    azione: {
      type: String,
      required: true,
      enum: [
        'login',
        'logout',
        'creazione_locker',
        'modifica_locker',
        'eliminazione_locker',
        'modifica_stato',
        'manutenzione',
        'rifornimento',
        'assegnazione_cella',
        'modifica_categoria',
        'export_report',
        'altro',
      ],
      trim: true,
      index: true,
    },
    entita: {
      type: String,
      default: null,
      trim: true,
      index: true,
    },
    entitaId: {
      type: String,
      default: null,
      index: true,
    },
    dettagli: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },
    timestamp: {
      type: Date,
      default: Date.now,
      index: true,
    },
    ipAddress: {
      type: String,
      default: null,
    },
    userAgent: {
      type: String,
      default: null,
    },
  },
  {
    timestamps: false,
    collection: 'audit_operatore',
  }
);

// Index per performance
auditOperatoreSchema.index({ operatoreId: 1, timestamp: -1 });
auditOperatoreSchema.index({ azione: 1, timestamp: -1 });
auditOperatoreSchema.index({ entita: 1, entitaId: 1 });
auditOperatoreSchema.index({ timestamp: -1 });

// Metodo per rimuovere campi interni dalla serializzazione (GDPR RNF5)
auditOperatoreSchema.methods.toJSON = function () {
  const auditObject = this.toObject();
  delete auditObject.__v;
  return auditObject;
};

/**
 * Metodo statico: genera auditId univoco
 * Formato: "AUD-001", "AUD-002", ecc.
 */
auditOperatoreSchema.statics.generateAuditId = async function () {
  const lastAudit = await this.findOne({}, { auditId: 1 })
    .sort({ auditId: -1 })
    .lean();

  if (!lastAudit || !lastAudit.auditId) {
    return 'AUD-001';
  }

  const match = lastAudit.auditId.match(/AUD-(\d+)/);
  if (match) {
    const lastNumber = parseInt(match[1], 10);
    const nextNumber = lastNumber + 1;
    return `AUD-${nextNumber.toString().padStart(3, '0')}`;
  }

  return 'AUD-001';
};

const AuditOperatore = mongoose.model('AuditOperatore', auditOperatoreSchema);

export default AuditOperatore;

