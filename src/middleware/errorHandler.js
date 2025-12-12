/**
 * 错误处理中间件
 */

import { logger } from "../utils/logger.js";

/**
 * 404 处理
 */
export function notFoundHandler(req, res) {
  res.status(404).json({
    success: false,
    error: "Not Found",
    message: `路径 ${req.path} 不存在`,
  });
}

/**
 * 错误处理
 */
export function errorHandler(err, req, res, _next) {
  logger.error("请求处理错误", {
    error: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
  });

  const statusCode = err.statusCode || 500;
  const message = err.message || "Internal Server Error";

  res.status(statusCode).json({
    success: false,
    error: message,
    ...(process.env.NODE_ENV === "development" && { stack: err.stack }),
  });
}

