/**
 * 规则文件路由
 */

import express from "express";
import { getDashboardNewSiteRules } from "../controllers/rulesController.js";
import { logger } from "../utils/logger.js";

const router = express.Router();

/**
 * GET /api/rules/dashboard-new-site
 * 获取 Dashboard 站点创建规则文件内容
 */
router.get("/dashboard-new-site", getDashboardNewSiteRules);

// 调试：确认路由已注册
console.log("[RulesRoutes] 路由已注册: GET /api/rules/dashboard-new-site");

export default router;

