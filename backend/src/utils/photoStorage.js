/**
 * Utility per gestione upload foto
 * 
 * ✅ IMPLEMENTAZIONE REALE
 * Salva foto su filesystem locale invece di base64 nel DB
 * 
 * Per produzione, considerare:
 * - Cloud Storage (S3, Cloudinary)
 * - Compressione immagini
 * - Validazione dimensioni/tipo
 */

import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import logger from './logger.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Directory upload (relativa a backend/)
const UPLOAD_DIR = path.join(__dirname, '../../uploads/photos');

// Dimensioni massime (5MB)
const MAX_SIZE = 5 * 1024 * 1024;

// Tipi MIME accettati
const ALLOWED_TYPES = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];

/**
 * Crea directory upload se non esiste
 */
async function ensureUploadDir() {
  try {
    await fs.mkdir(UPLOAD_DIR, { recursive: true });
  } catch (error) {
    logger.error('Errore creazione directory upload:', error);
    throw new Error('Impossibile creare directory upload');
  }
}

/**
 * Valida foto base64
 * @param {String} base64Photo - Foto in base64
 * @returns {Object} { valid: boolean, error?: string, buffer?: Buffer, mimeType?: string }
 */
export function validatePhoto(base64Photo) {
  try {
    // Estrai MIME type e dati
    const match = base64Photo.match(/^data:image\/(\w+);base64,(.+)$/);
    if (!match) {
      return { valid: false, error: 'Formato base64 non valido' };
    }

    const mimeType = `image/${match[1]}`;
    const base64Data = match[2];

    // Verifica tipo MIME
    if (!ALLOWED_TYPES.includes(mimeType)) {
      return {
        valid: false,
        error: `Tipo immagine non supportato. Tipi accettati: ${ALLOWED_TYPES.join(', ')}`,
      };
    }

    // Converti base64 a buffer
    const buffer = Buffer.from(base64Data, 'base64');

    // Verifica dimensione
    if (buffer.length > MAX_SIZE) {
      return {
        valid: false,
        error: `Immagine troppo grande. Dimensione massima: ${MAX_SIZE / 1024 / 1024}MB`,
      };
    }

    return { valid: true, buffer, mimeType };
  } catch (error) {
    return { valid: false, error: `Errore validazione foto: ${error.message}` };
  }
}

/**
 * Salva foto su filesystem
 * @param {String} base64Photo - Foto in base64
 * @param {String} noleggioId - ID noleggio per nome file
 * @returns {Promise<String>} URL relativo della foto salvata
 */
export async function savePhoto(base64Photo, noleggioId) {
  try {
    // Valida foto
    const validation = validatePhoto(base64Photo);
    if (!validation.valid) {
      throw new Error(validation.error);
    }

    // Assicura che directory esista
    await ensureUploadDir();

    // Genera nome file univoco
    const timestamp = Date.now();
    const extension = validation.mimeType.split('/')[1] || 'jpg';
    const filename = `photo-${noleggioId}-${timestamp}.${extension}`;
    const filepath = path.join(UPLOAD_DIR, filename);

    // Salva file
    await fs.writeFile(filepath, validation.buffer);

    logger.info(`Foto salvata: ${filename} (${(validation.buffer.length / 1024).toFixed(2)}KB)`);

    // Ritorna URL relativo (per accesso via HTTP)
    return `/uploads/photos/${filename}`;
  } catch (error) {
    logger.error('Errore salvataggio foto:', error);
    throw error;
  }
}

/**
 * Elimina foto dal filesystem
 * @param {String} photoUrl - URL relativo della foto
 * @returns {Promise<Boolean>} true se eliminata, false se non trovata
 */
export async function deletePhoto(photoUrl) {
  try {
    // Estrai nome file da URL
    const filename = path.basename(photoUrl);
    const filepath = path.join(UPLOAD_DIR, filename);

    // Verifica che file esista
    try {
      await fs.access(filepath);
    } catch {
      return false; // File non esiste
    }

    // Elimina file
    await fs.unlink(filepath);
    logger.info(`Foto eliminata: ${filename}`);
    return true;
  } catch (error) {
    logger.error('Errore eliminazione foto:', error);
    return false;
  }
}

/**
 * Verifica se foto esiste
 * @param {String} photoUrl - URL relativo della foto
 * @returns {Promise<Boolean>} true se esiste
 */
export async function photoExists(photoUrl) {
  try {
    const filename = path.basename(photoUrl);
    const filepath = path.join(UPLOAD_DIR, filename);
    await fs.access(filepath);
    return true;
  } catch {
    return false;
  }
}

export default {
  savePhoto,
  deletePhoto,
  photoExists,
};

