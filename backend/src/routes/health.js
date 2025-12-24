import express from 'express';
import { isConnected } from '../config/database.js';
import config from '../config/env.js';

const router = express.Router();

// Store server start time for uptime calculation
const serverStartTime = Date.now();

/**
 * GET /health
 * GET /api/v1/health
 * Health check endpoint
 */
router.get(['/health', '/api/v1/health'], (req, res) => {
  const uptime = Math.floor((Date.now() - serverStartTime) / 1000); // seconds
  const dbStatus = isConnected() ? 'connected' : 'disconnected';

  res.json({
    success: true,
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime,
    database: dbStatus,
    version: config.appVersion,
    environment: config.nodeEnv,
  });
});

export default router;





