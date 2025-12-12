/**
 * 日志工具
 */

/**
 * 日志级别
 */
const LOG_LEVELS = {
  ERROR: 0,
  WARN: 1,
  INFO: 2,
  DEBUG: 3,
};

const currentLevel = LOG_LEVELS[process.env.LOG_LEVEL?.toUpperCase()] ?? LOG_LEVELS.INFO;

/**
 * 格式化日志消息
 */
function formatMessage(level, message, data = {}) {
  const timestamp = new Date().toISOString();
  const dataStr = Object.keys(data).length > 0 ? ` ${JSON.stringify(data)}` : "";
  return `[${timestamp}] [${level}] ${message}${dataStr}`;
}

/**
 * 日志工具
 */
export const logger = {
  error(message, data) {
    if (currentLevel >= LOG_LEVELS.ERROR) {
      console.error(formatMessage("ERROR", message, data));
    }
  },

  warn(message, data) {
    if (currentLevel >= LOG_LEVELS.WARN) {
      console.warn(formatMessage("WARN", message, data));
    }
  },

  info(message, data) {
    if (currentLevel >= LOG_LEVELS.INFO) {
      console.log(formatMessage("INFO", message, data));
    }
  },

  debug(message, data) {
    if (currentLevel >= LOG_LEVELS.DEBUG) {
      console.log(formatMessage("DEBUG", message, data));
    }
  },
};

