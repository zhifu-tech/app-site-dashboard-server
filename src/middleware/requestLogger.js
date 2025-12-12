/**
 * 请求日志中间件
 */

import { logger } from "../utils/logger.js";

export function requestLogger(req, res, next) {
  const startTime = Date.now();

  res.on("finish", () => {
    const duration = Date.now() - startTime;
    logger.info("HTTP 请求", {
      method: req.method,
      path: req.path,
      status: res.statusCode,
      duration: `${duration}ms`,
      ip: req.ip,
    });
  });

  next();
}

