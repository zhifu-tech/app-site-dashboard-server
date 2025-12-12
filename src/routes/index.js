/**
 * 路由入口
 */

import express from "express";
import siteRoutes from "./siteRoutes.js";
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

export default router;

