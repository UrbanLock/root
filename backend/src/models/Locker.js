import mongoose from 'mongoose';

const lockerSchema = new mongoose.Schema(
  {
    lockerId: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    nome: {
      type: String,
      required: true,
      trim: true,
    },
    coordinate: {
      lat: {
        type: Number,
        required: true,
      },
      lng: {
        type: Number,
        required: true,
      },
    },
    stato: {
      type: String,
      enum: ['attivo', 'manutenzione', 'disattivo'],
      default: 'attivo',
      index: true,
    },
    dimensione: {
      type: String,
      enum: ['small', 'medium', 'large'],
      default: 'medium',
    },
    // RF2: Campo opzionale per tipologia locker (se presente nel DB)
    tipo: {
      type: String,
      enum: ['sportivi', 'personali', 'petFriendly', 'commerciali', 'cicloturistici'],
      sparse: true, // Permette null ma mantiene unique se presente
    },
    // RF2: Descrizione opzionale
    descrizione: {
      type: String,
      trim: true,
    },
    // RF2: Data ripristino se in manutenzione
    dataRipristino: {
      type: Date,
      default: null,
    },
    // RF2: Stato online/offline
    online: {
      type: Boolean,
      default: true,
    },
    operatoreCreatoreId: {
      type: String,
      default: null,
    },
    dataCreazione: {
      type: Date,
      default: Date.now,
    },
    // Campi per manutenzione (RF14)
    inManutenzione: {
      type: Boolean,
      default: false,
      index: true,
    },
    motivoManutenzione: {
      type: String,
      default: null,
      trim: true,
    },
    dataFineManutenzionePrevista: {
      type: Date,
      default: null,
    },
    dataUltimaManutenzione: {
      type: Date,
      default: null,
    },
    dataAggiornamento: {
      type: Date,
      default: Date.now,
    },
  },
  {
    timestamps: false, // Usiamo dataCreazione manuale
    collection: 'locker', // Nome collezione MongoDB
  }
);

// Index per ricerca rapida
lockerSchema.index({ lockerId: 1 });
lockerSchema.index({ stato: 1 });
// RF2: Index geospaziale per ricerche per distanza
lockerSchema.index({ coordinate: '2dsphere' });

// Virtual: isActive getter
lockerSchema.virtual('isActive').get(function () {
  return this.stato === 'attivo';
});

// Metodo per formattare per frontend
lockerSchema.methods.toJSON = function () {
  const lockerObject = this.toObject({ virtuals: true });
  return lockerObject;
};

// Metodo statico: conta celle totali per locker
lockerSchema.statics.getTotalCells = async function (lockerId) {
  const Cell = mongoose.model('Cell');
  return await Cell.countDocuments({ lockerId });
};

// Metodo statico: conta celle disponibili (stato: "libera")
lockerSchema.statics.getAvailableCells = async function (lockerId) {
  const Cell = mongoose.model('Cell');
  return await Cell.countDocuments({ lockerId, stato: 'libera' });
};

// Metodo statico: genera lockerId sequenziale
lockerSchema.statics.generateLockerId = async function () {
  const lastLocker = await this.findOne({}, { lockerId: 1 })
    .sort({ lockerId: -1 })
    .lean();

  if (!lastLocker || !lastLocker.lockerId) {
    return 'LCK-001';
  }

  // Estrai numero da lockerId (es. "LCK-001" -> 1)
  const match = lastLocker.lockerId.match(/LCK-(\d+)/);
  if (match) {
    const nextNumber = parseInt(match[1], 10) + 1;
    return `LCK-${nextNumber.toString().padStart(3, '0')}`;
  }

  // Fallback se formato non valido
  return 'LCK-001';
};

const Locker = mongoose.model('Locker', lockerSchema);

export default Locker;



