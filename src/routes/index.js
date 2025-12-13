/**
 * 路由入口
 */

import express from "express";
import siteRoutes from "./siteRoutes.js";
import rulesRoutes from "./rulesRoutes.js";
import { healthCheck } from "../controllers/healthController.js";

const router = express.Router();

/**
 * 健康检查
 */
router.get("/health", healthCheck);

/**
 * 站点 API 路由
 */
router.use("/sites", siteRoutes);

/**
 * 规则文件 API 路由
 */
router.use("/rules", rulesRoutes);

// 调试：列出所有注册的路由
console.log("[Routes] 规则路由已注册: /api/rules");

export default router;

