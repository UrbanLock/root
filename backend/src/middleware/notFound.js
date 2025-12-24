/**
 * Middleware to handle 404 Not Found errors
 * Should be placed after all routes but before error handler
 */
export function notFound(req, res, next) {
  res.status(404).json({
    success: false,
    error: {
      message: `Route not found: ${req.method} ${req.originalUrl}`,
      code: 'NOT_FOUND',
      statusCode: 404,
    },
  });
}

export default notFound;





