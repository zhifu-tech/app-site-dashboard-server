/**
 * 规则文件控制器
 * 处理规则文件相关的 HTTP 请求
 */

import { readFile } from "fs/promises";
import { join } from "path";
import { appConfig } from "../config/index.js";
import { logger } from "../utils/logger.js";

/**
 * 获取 Dashboard 站点创建规则
 */
export async function getDashboardNewSiteRules(req, res, next) {
  try {
    // 从 data 目录读取规则文件
    const rulesPath = join(appConfig.dataDir, "dashboard-new-site.mdc");
    
    logger.info("获取规则文件", { path: rulesPath });
    
    try {
      const content = await readFile(rulesPath, "utf-8");
      logger.info("规则文件读取成功", { length: content.length });
      res.json({
        success: true,
        data: content,
      });
    } catch (error) {
      if (error.code === "ENOENT") {
        logger.warn("规则文件不存在", { path: rulesPath, error: error.message });
        res.status(404).json({
          success: false,
          error: `规则文件不存在: ${rulesPath}`,
        });
      } else {
        logger.error("读取规则文件失败", { path: rulesPath, error: error.message });
        throw error;
      }
    }
  } catch (error) {
    logger.error("获取规则文件失败", { error: error.message, stack: error.stack });
    next(error);
  }
}

