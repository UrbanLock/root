import mongoose from 'mongoose';

const donationSchema = new mongoose.Schema(
  {
    donazioneId: {
      type: String,
      required: true,
      unique: true,
    },
    utenteId: {
      type: String,
      required: true,
    },
    cellaId: {
      type: String,
      default: null,
    },
    lockerId: {
      type: String,
      default: null,
    },
    descrizione: {
      type: String,
      trim: true,
    },
    categoria: {
      type: String,
      trim: true,
    },
    stato: {
      type: String,
      enum: ['daVisionare', 'inValutazione', 'accettata', 'rifiutata'],
      default: 'daVisionare',
    },
    fotoUrl: {
      type: String,
      default: null,
    },
    isComunePickup: {
      type: Boolean,
      default: false,
    },
    dataCreazione: {
      type: Date,
      default: Date.now,
    },
  },
  {
    timestamps: false,
    collection: 'donazione',
  }
);

// Index per ricerca rapida
donationSchema.index({ donazioneId: 1 }, { unique: true });
donationSchema.index({ utenteId: 1 });
donationSchema.index({ stato: 1 });
donationSchema.index({ cellaId: 1 });

const Donation = mongoose.model('Donation', donationSchema);

export default Donation;



