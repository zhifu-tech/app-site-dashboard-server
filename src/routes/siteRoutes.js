/**
 * 站点路由
 */

import express from "express";
import {
  listSites,
  generateIndex,
  getSite,
  createSite,
  updateSite,
  deleteSite,
} from "../controllers/siteController.js";

const router = express.Router();

/**
 * GET /api/sites
 * 获取所有站点文件列表
 */
router.get("/", listSites);

/**
 * POST /api/sites/index
 * 生成站点索引文件
 */
router.post("/index", generateIndex);

/**
 * GET /api/sites/:filename
 * 获取单个站点数据
 */
router.get("/:filename", getSite);

/**
 * POST /api/sites
 * 创建新站点
 */
router.post("/", createSite);

/**
 * PUT /api/sites/:filename
 * 更新站点数据
 */
router.put("/:filename", updateSite);

/**
 * PATCH /api/sites/:filename
 * 部分更新站点数据
 */
router.patch("/:filename", updateSite);

/**
 * DELETE /api/sites/:filename
 * 删除站点
 */
router.delete("/:filename", deleteSite);

export default router;

