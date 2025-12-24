import express from 'express';
import https from 'https';
import http from 'http';
import helmet from 'helmet';
import cors from 'cors';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import config from './config/env.js';
import { connectDB, disconnectDB } from './config/database.js';
import { loadTLSOptions } from './config/tls.js';
import logger from './utils/logger.js';
import healthRoutes from './routes/health.js';
import authRoutes from './routes/auth.js';
import lockerRoutes from './routes/lockers.js';
import cellRoutes from './routes/cells.js';
import depositRoutes from './routes/deposits.js';
import borrowRoutes from './routes/borrows.js';
import profileRoutes from './routes/profile.js';
import historyRoutes from './routes/history.js';
import notificationRoutes from './routes/notifications.js';
import donationRoutes from './routes/donations.js';
import adminDonationRoutes from './routes/admin/donations.js';
import reportRoutes from './routes/reports.js';
import helpRoutes from './routes/help.js';
import adminReportRoutes from './routes/admin/reports.js';
import operatorRoutes from './routes/admin/operators.js';
import adminLockerRoutes from './routes/admin/lockers.js';
import reportingRoutes from './routes/admin/reporting.js';
import categoryRoutes from './routes/admin/categories.js';
import { notFound } from './middleware/notFound.js';
import { errorHandler } from './middleware/errorHandler.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Create Express app
const app = express();

// Security middleware
app.use(helmet());

// CORS configuration
app.use(
  cors({
    origin: config.corsOrigin,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
  })
);

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Serve uploaded files (foto) - implementazione reale
app.use('/uploads', express.static(join(__dirname, '../uploads')));

// Request logging middleware
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.originalUrl}`, {
    ip: req.ip,
    userAgent: req.get('user-agent'),
  });
  next();
});

// Routes
app.use('/', healthRoutes);
app.use(`/api/${config.apiVersion}`, healthRoutes);
app.use(`/api/${config.apiVersion}/auth`, authRoutes);
app.use(`/api/${config.apiVersion}/lockers`, lockerRoutes);
app.use(`/api/${config.apiVersion}/cells`, cellRoutes);
app.use(`/api/${config.apiVersion}/deposits`, depositRoutes);
app.use(`/api/${config.apiVersion}/borrows`, borrowRoutes);
app.use(`/api/${config.apiVersion}/profile`, profileRoutes);
app.use(`/api/${config.apiVersion}/history`, historyRoutes);
app.use(`/api/${config.apiVersion}/notifications`, notificationRoutes);
app.use(`/api/${config.apiVersion}/donations`, donationRoutes);
app.use(`/api/${config.apiVersion}/admin/donations`, adminDonationRoutes);
app.use(`/api/${config.apiVersion}/reports`, reportRoutes);
app.use(`/api/${config.apiVersion}/help`, helpRoutes);
app.use(`/api/${config.apiVersion}/admin/reports`, adminReportRoutes);
app.use(`/api/${config.apiVersion}/admin`, operatorRoutes);
app.use(`/api/${config.apiVersion}/admin/lockers`, adminLockerRoutes);
app.use(`/api/${config.apiVersion}/admin/reporting`, reportingRoutes);
app.use(`/api/${config.apiVersion}/admin/categories`, categoryRoutes);

// 404 handler (must be after all routes)
app.use(notFound);

// Error handler (must be last)
app.use(errorHandler);

// Create HTTP or HTTPS server
let server;
const tlsOptions = loadTLSOptions();

if (tlsOptions) {
  server = https.createServer(tlsOptions, app);
  logger.info(`HTTPS server configured`);
} else {
  server = http.createServer(app);
  logger.info(`HTTP server configured (TLS disabled or certificates not found)`);
}

// Start server
const port = tlsOptions ? config.httpsPort : config.port;

/**
 * Start the server
 */
async function startServer() {
  try {
    // Connect to MongoDB
    await connectDB();

    // Start HTTP/HTTPS server
    server.listen(port, () => {
      const protocol = tlsOptions ? 'https' : 'http';
      logger.info(`=================================`);
      logger.info(`${config.appName} v${config.appVersion}`);
      logger.info(`=================================`);
      logger.info(`Server running on ${protocol}://localhost:${port}`);
      logger.info(`Environment: ${config.nodeEnv}`);
      logger.info(`API Version: ${config.apiVersion}`);
      logger.info(`Health check: ${protocol}://localhost:${port}/health`);
      logger.info(`=================================`);
    });
  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
}

/**
 * Graceful shutdown
 */
async function shutdown() {
  logger.info('Shutting down server...');

  // Close server
  server.close(async () => {
    logger.info('HTTP server closed');

    // Disconnect from MongoDB
    try {
      await disconnectDB();
    } catch (error) {
      logger.error('Error disconnecting from MongoDB:', error);
    }

    logger.info('Server shutdown complete');
    process.exit(0);
  });

  // Force shutdown after 10 seconds
  setTimeout(() => {
    logger.error('Forced shutdown after timeout');
    process.exit(1);
  }, 10000);
}

// Handle graceful shutdown
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception:', error);
  shutdown();
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
  shutdown();
});

// Start the server
startServer();

export default app;

