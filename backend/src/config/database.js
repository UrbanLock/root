import mongoose from 'mongoose';
import config from './env.js';
import logger from '../utils/logger.js';

/**
 * Connects to MongoDB database
 * @returns {Promise<void>}
 */
export async function connectDB() {
  try {
    const options = {
      useNewUrlParser: true,
      useUnifiedTopology: true,
      serverSelectionTimeoutMS: 5000, // Timeout after 5s instead of 30s
      socketTimeoutMS: 45000, // Close sockets after 45s of inactivity
    };

    await mongoose.connect(config.mongodbUri, options);

    logger.info(`MongoDB connected: ${config.mongodbUri.replace(/\/\/.*@/, '//***@')}`);
  } catch (error) {
    logger.error('MongoDB connection error:', error);
    throw error;
  }
}

/**
 * Disconnects from MongoDB database
 * @returns {Promise<void>}
 */
export async function disconnectDB() {
  try {
    await mongoose.disconnect();
    logger.info('MongoDB disconnected');
  } catch (error) {
    logger.error('MongoDB disconnection error:', error);
    throw error;
  }
}

/**
 * Checks if MongoDB is connected
 * @returns {boolean}
 */
export function isConnected() {
  return mongoose.connection.readyState === 1;
}

// MongoDB connection event handlers
mongoose.connection.on('connected', () => {
  logger.info('Mongoose connected to MongoDB');
});

mongoose.connection.on('error', (error) => {
  logger.error('Mongoose connection error:', error);
});

mongoose.connection.on('disconnected', () => {
  logger.warn('Mongoose disconnected from MongoDB');
});

// Handle application termination
process.on('SIGINT', async () => {
  await mongoose.connection.close();
  logger.info('MongoDB connection closed through app termination');
  process.exit(0);
});

export default {
  connectDB,
  disconnectDB,
  isConnected,
};





