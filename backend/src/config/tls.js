import fs from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import config from './env.js';
import logger from '../utils/logger.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/**
 * Loads TLS certificate and key files
 * @returns {Object|null} TLS options object or null if not enabled/available
 */
export function loadTLSOptions() {
  if (!config.tlsEnabled) {
    logger.info('TLS is disabled');
    return null;
  }

  const keyPath = join(__dirname, '../../', config.tlsKeyPath);
  const certPath = join(__dirname, '../../', config.tlsCertPath);

  try {
    // Check if certificate files exist
    if (!fs.existsSync(keyPath)) {
      logger.warn(`TLS key file not found: ${keyPath}`);
      logger.warn('Server will run without TLS. To enable TLS, generate certificates.');
      return null;
    }

    if (!fs.existsSync(certPath)) {
      logger.warn(`TLS certificate file not found: ${certPath}`);
      logger.warn('Server will run without TLS. To enable TLS, generate certificates.');
      return null;
    }

    // Read certificate files
    const key = fs.readFileSync(keyPath, 'utf8');
    const cert = fs.readFileSync(certPath, 'utf8');

    logger.info('TLS certificates loaded successfully');
    
    return {
      key,
      cert,
    };
  } catch (error) {
    logger.error('Error loading TLS certificates:', error);
    logger.warn('Server will run without TLS');
    return null;
  }
}

/**
 * Checks if TLS certificates exist
 * @returns {boolean}
 */
export function certificatesExist() {
  if (!config.tlsEnabled) {
    return false;
  }

  const keyPath = join(__dirname, '../../', config.tlsKeyPath);
  const certPath = join(__dirname, '../../', config.tlsCertPath);

  return fs.existsSync(keyPath) && fs.existsSync(certPath);
}

export default {
  loadTLSOptions,
  certificatesExist,
};





