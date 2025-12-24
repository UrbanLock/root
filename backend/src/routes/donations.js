import express from 'express';
import { authenticate } from '../middleware/auth.js';
import {
  createDonation,
  getDonations,
  getDonationById,
  updateDonation,
  deleteDonation,
  schedulePickup,
} from '../controllers/donationController.js';

const router = express.Router();

/**
 * IMPORTANTE: Ordine delle route
 * Le route specifiche devono essere definite PRIMA di quelle con parametri
 */

/**
 * POST /api/v1/donations
 * Creare donazione
 * Body: {nomeOggetto, tipoAttrezzatura, categoria (opz), descrizione, photo (opz), lockerId (opz)}
 * RF6: Creare donazione
 * Autenticazione: Richiesta
 */
router.post('/', authenticate, createDonation);

/**
 * GET /api/v1/donations
 * Lista donazioni utente
 * Query: ?page=1&limit=20&status=...
 * RF6: Lista donazioni utente
 * Autenticazione: Richiesta
 */
router.get('/', authenticate, getDonations);

/**
 * GET /api/v1/donations/:id
 * Dettaglio donazione
 * RF6: Dettaglio donazione
 * Autenticazione: Richiesta
 */
router.get('/:id', authenticate, getDonationById);

/**
 * PUT /api/v1/donations/:id
 * Modificare donazione
 * Body: {nomeOggetto (opz), tipoAttrezzatura (opz), categoria (opz), descrizione (opz), photo (opz)}
 * RF6: Modificare donazione
 * Autenticazione: Richiesta
 */
router.put('/:id', authenticate, updateDonation);

/**
 * DELETE /api/v1/donations/:id
 * Cancellare donazione
 * RF6: Cancellare donazione
 * Autenticazione: Richiesta
 */
router.delete('/:id', authenticate, deleteDonation);

/**
 * POST /api/v1/donations/:id/schedule-pickup
 * Concordare data/orario ritiro
 * Body: {dataRitiro (required), note (opz)}
 * RF6: Concordare data/orario ritiro
 * Autenticazione: Richiesta
 */
router.post('/:id/schedule-pickup', authenticate, schedulePickup);

export default router;


