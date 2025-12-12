/**
 * 站点控制器
 * 处理站点相关的 HTTP 请求
 */

import { SiteService } from "../services/siteService.js";

const siteService = new SiteService();

/**
 * 获取所有站点列表
 */
export async function listSites(req, res, next) {
  try {
    const sites = await siteService.listSites();
    res.json({
      success: true,
      data: sites,
      count: sites.length,
    });
  } catch (error) {
    next(error);
  }
}

/**
 * 生成站点索引
 */
export async function generateIndex(req, res, next) {
  try {
    const index = await siteService.generateIndex();
    res.json({
      success: true,
      data: index,
    });
  } catch (error) {
    next(error);
  }
}

/**
 * 获取单个站点数据
 */
export async function getSite(req, res, next) {
  try {
    const { filename } = req.params;
    const site = await siteService.getSite(filename);
    res.json({
      success: true,
      data: site,
    });
  } catch (error) {
    next(error);
  }
}

/**
 * 创建站点
 */
export async function createSite(req, res, next) {
  try {
    const { filename } = req.body;
    const siteData = req.body;

    // 如果提供了 filename，使用它；否则从 name 生成
    const finalFilename = filename || siteService.generateFilename(siteData.name);

    // 移除 filename 字段（如果存在），因为它不是站点数据的一部分
    delete siteData.filename;

    const site = await siteService.createSite(finalFilename, siteData);
    res.status(201).json({
      success: true,
      data: site,
      filename: finalFilename,
    });
  } catch (error) {
    next(error);
  }
}

/**
 * 更新站点
 */
export async function updateSite(req, res, next) {
  try {
    const { filename } = req.params;
    const siteData = req.body;

    // 移除 filename 字段（如果存在）
    delete siteData.filename;

    const site = await siteService.updateSite(filename, siteData);
    res.json({
      success: true,
      data: site,
    });
  } catch (error) {
    next(error);
  }
}

/**
 * 删除站点
 */
export async function deleteSite(req, res, next) {
  try {
    const { filename } = req.params;
    const result = await siteService.deleteSite(filename);
    res.json({
      success: true,
      data: result,
    });
  } catch (error) {
    next(error);
  }
}

