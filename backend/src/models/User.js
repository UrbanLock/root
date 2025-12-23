import mongoose from 'mongoose';

const userSchema = new mongoose.Schema(
  {
    utenteId: {
      type: String,
      required: true,
      unique: true,
    },
    nome: {
      type: String,
      required: true,
      trim: true,
    },
    cognome: {
      type: String,
      required: true,
      trim: true,
    },
    codiceFiscale: {
      type: String,
      required: true,
      unique: true,
      uppercase: true,
      trim: true,
    },
    email: {
      type: String,
      sparse: true, // Permette null ma mantiene unique se presente
      lowercase: true,
      trim: true,
    },
    telefono: {
      type: String,
      trim: true,
    },
    dataRegistrazione: {
      type: Date,
      default: Date.now,
    },
    // Campi aggiuntivi per autenticazione (non nel DB originale ma necessari)
    tipoAutenticazione: {
      type: String,
      enum: ['spid', 'cie'],
      default: 'spid',
    },
    ruolo: {
      type: String,
      enum: ['utente', 'operatore', 'admin'],
      default: 'utente',
    },
    attivo: {
      type: Boolean,
      default: true,
    },
    ultimoAccesso: {
      type: Date,
      default: Date.now,
    },
    refreshToken: {
      type: String,
      default: null,
      select: false, // Non includere di default nelle query
    },
    // Campi per autenticazione operatori (username/password)
    username: {
      type: String,
      sparse: true, // Permette null ma mantiene unique se presente
      trim: true,
      lowercase: true,
    },
    password: {
      type: String,
      select: false, // Non includere di default nelle query
    },
    // RF1: Supporto account "figli" per minori collegati a genitore
    genitoreId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
      sparse: true, // Permette null ma mantiene index se presente
    },
  },
  {
    timestamps: false, // Usiamo dataRegistrazione manuale
    collection: 'utente', // Nome collezione MongoDB
  }
);

// Index per ricerca rapida
// utenteId e codiceFiscale hanno già index automatico da unique: true
userSchema.index({ genitoreId: 1 }); // Index per ricerca account figli (RF1)
userSchema.index({ username: 1 }, { unique: true, sparse: true }); // Index per username operatori

// Metodo per rimuovere campi sensibili dalla serializzazione (GDPR RNF5)
userSchema.methods.toJSON = function () {
  const userObject = this.toObject({ virtuals: true }); // Include virtuals (nomeCompleto)
  delete userObject.refreshToken; // RNF4: Non esporre token
  delete userObject.__v;
  // GDPR RNF5: Minimizzazione dati - esporre solo dati necessari
  // Campi sensibili come codiceFiscale potrebbero essere rimossi in futuro se non necessari
  return userObject;
};

// Metodo per aggiornare ultimo accesso
userSchema.methods.updateLastAccess = function () {
  this.ultimoAccesso = new Date();
  return this.save();
};

// Metodo per ottenere nome completo
userSchema.virtual('nomeCompleto').get(function () {
  return `${this.nome} ${this.cognome}`;
});

// Metodo statico per generare utenteId sequenziale
userSchema.statics.generateUtenteId = async function () {
  const lastUser = await this.findOne({}, { utenteId: 1 })
    .sort({ utenteId: -1 })
    .lean();

  if (!lastUser || !lastUser.utenteId) {
    return 'USR-001';
  }

  // Estrai numero da utenteId (es. "USR-001" -> 1)
  const match = lastUser.utenteId.match(/USR-(\d+)/);
  if (match) {
    const nextNumber = parseInt(match[1], 10) + 1;
    return `USR-${nextNumber.toString().padStart(3, '0')}`;
  }

  // Fallback se formato non valido
  return 'USR-001';
};

const User = mongoose.model('User', userSchema);

export default User;

