import mongoose from 'mongoose';

const operatoreSchema = new mongoose.Schema(
  {
    operatoreId: {
      type: String,
      required: false, // Rendi opzionale per compatibilità
      unique: true,
    },
    nome: {
      type: String,
      required: false, // Rendi opzionale per compatibilità
      trim: true,
    },
    cognome: {
      type: String,
      required: false, // Rendi opzionale per compatibilità
      trim: true,
    },
    username: {
      type: String,
      required: false, // Rendi opzionale per compatibilità
      unique: true,
      trim: true,
      // Non forzare lowercase qui, gestiamolo nella query
    },
    passwordHash: {
      type: String,
      required: false, // Rendi opzionale per compatibilità
      select: false, // Non includere di default nelle query
    },
    attivo: {
      type: Boolean,
      default: true,
      required: false, // Campo opzionale
    },
    ultimoAccesso: {
      type: Date,
      required: false, // Campo opzionale
    },
    refreshToken: {
      type: String,
      default: null,
      required: false, // Campo opzionale
      select: false, // Non includere di default nelle query
    },
  },
  {
    timestamps: false,
    collection: 'operatori', // Nome collezione MongoDB esistente
    strict: false, // Permetti campi aggiuntivi non definiti nello schema
  }
);

// Index per ricerca rapida
operatoreSchema.index({ operatoreId: 1 }, { unique: true });
operatoreSchema.index({ username: 1 }, { unique: true });

// Metodo per rimuovere campi sensibili dalla serializzazione
operatoreSchema.methods.toJSON = function () {
  const operatoreObject = this.toObject();
  delete operatoreObject.passwordHash;
  delete operatoreObject.refreshToken;
  delete operatoreObject.__v;
  return operatoreObject;
};

// Metodo per aggiornare ultimo accesso
operatoreSchema.methods.updateLastAccess = function () {
  this.ultimoAccesso = new Date();
  return this.save();
};

// Metodo virtuale per nome completo
operatoreSchema.virtual('nomeCompleto').get(function () {
  return `${this.nome} ${this.cognome}`;
});

const Operatore = mongoose.model('Operatore', operatoreSchema);

export default Operatore;

