/**
 * 应用配置
 */

import dotenv from "dotenv";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/**
 * 应用配置
 */
export const appConfig = {
  // 服务器配置
  host: process.env.HOST || "0.0.0.0",
  port: parseInt(process.env.PORT || "3002", 10),
  nodeEnv: process.env.NODE_ENV || "development",

  // HTTPS 配置
  https: {
    enabled: process.env.HTTPS_ENABLED === "true",
    keyPath: process.env.SSL_KEY_PATH || join(__dirname, "../../ssl/server.key"),
    certPath: process.env.SSL_CERT_PATH || join(__dirname, "../../ssl/server.crt"),
  },

  // 数据目录配置
  dataDir: process.env.DATA_DIR || join(__dirname, "../../data"),

  // CORS 配置
  cors: {
    origin: process.env.CORS_ORIGIN || "*",
    credentials: true,
  },

  // 请求体大小限制
  bodyLimit: process.env.BODY_LIMIT || "10mb",
};

