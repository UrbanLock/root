import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Load .env file
dotenv.config({ path: join(__dirname, '../../.env') });

/**
 * Validates required environment variables
 * @throws {Error} If required variables are missing
 */
function validateEnv() {
  const required = ['MONGODB_URI'];
  const missing = required.filter(key => !process.env[key]);

  if (missing.length > 0) {
    throw new Error(
      `Missing required environment variables: ${missing.join(', ')}\n` +
      'Please check your .env file or set them in the environment.'
    );
  }
}

/**
 * Environment configuration object
 */
const config = {
  // Server
  nodeEnv: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT || '3000', 10),
  httpsPort: parseInt(process.env.HTTPS_PORT || '3443', 10),

  // MongoDB
  mongodbUri: process.env.MONGODB_URI_PROD || process.env.MONGODB_URI || 'mongodb://localhost:27017/Null',

  // TLS
  tlsEnabled: process.env.TLS_ENABLED === 'true',
  tlsKeyPath: process.env.TLS_KEY_PATH || './certificates/key.pem',
  tlsCertPath: process.env.TLS_CERT_PATH || './certificates/cert.pem',

  // API
  apiVersion: process.env.API_VERSION || 'v1',
  apiBaseUrl: process.env.API_BASE_URL || 'https://api.null.app',

  // CORS
  corsOrigin: process.env.CORS_ORIGIN 
    ? process.env.CORS_ORIGIN.split(',').map(origin => origin.trim())
    : ['http://localhost:3000'],

  // Logging
  logLevel: process.env.LOG_LEVEL || 'info',

  // JWT
  jwtSecret: process.env.JWT_SECRET || 'default-secret-key-change-in-production',
  jwtAccessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN || '15m',
  jwtRefreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d',

  // App info
  appName: 'NULL Backend',
  appVersion: '1.0.0',
};

// Validate in production
if (config.nodeEnv === 'production') {
  validateEnv();
}

export default config;

