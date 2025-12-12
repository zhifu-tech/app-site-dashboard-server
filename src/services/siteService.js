/**
 * 站点数据服务
 * 负责站点数据的 CRUD 操作
 */

import { readFile, writeFile, readdir, unlink } from "fs/promises";
import { join } from "path";
import yaml from "js-yaml";
import { appConfig } from "../config/index.js";
import { logger } from "../utils/logger.js";

/**
 * 获取站点文件路径
 */
function getSiteFilePath(filename) {
  if (!filename.endsWith(".yml")) {
    filename = `${filename}.yml`;
  }
  if (!filename.startsWith("site-")) {
    filename = `site-${filename}`;
  }
  return join(appConfig.dataDir, filename);
}

/**
 * 验证站点数据
 */
function validateSiteData(data) {
  const errors = [];

  if (!data.name || typeof data.name !== "string" || data.name.trim().length === 0) {
    errors.push("name 字段是必需的，且必须是非空字符串");
  }

  if (!data.url || typeof data.url !== "string" || data.url.trim().length === 0) {
    errors.push("url 字段是必需的，且必须是非空字符串");
  }

  // 验证 URL 格式（简单验证）
  if (data.url && !/^https?:\/\//.test(data.url)) {
    errors.push("url 必须是有效的 HTTP/HTTPS URL");
  }

  if (data.links && !Array.isArray(data.links)) {
    errors.push("links 必须是数组");
  }

  if (data.tags && !Array.isArray(data.tags)) {
    errors.push("tags 必须是数组");
  }

  return errors;
}

/**
 * 站点服务
 */
export class SiteService {
  /**
   * 获取所有站点文件列表
   */
  async listSites() {
    try {
      const files = await readdir(appConfig.dataDir);
      const siteFiles = files
        .filter((file) => file.startsWith("site-") && file.endsWith(".yml"))
        .sort();

      return siteFiles;
    } catch (error) {
      logger.error("获取站点列表失败", { error: error.message });
      throw new Error("获取站点列表失败");
    }
  }

  /**
   * 生成站点索引
   */
  async generateIndex() {
    try {
      const siteFiles = await this.listSites();
      const index = {
        sites: siteFiles,
        generatedAt: new Date().toISOString(),
      };

      const indexPath = join(appConfig.dataDir, "sites.json");
      await writeFile(indexPath, JSON.stringify(index, null, 2) + "\n", "utf-8");

      logger.info("站点索引生成成功", { count: siteFiles.length });
      return index;
    } catch (error) {
      logger.error("生成站点索引失败", { error: error.message });
      throw new Error("生成站点索引失败");
    }
  }

  /**
   * 获取单个站点数据
   */
  async getSite(filename) {
    try {
      const filePath = getSiteFilePath(filename);
      const content = await readFile(filePath, "utf-8");
      const data = yaml.load(content);

      if (!data) {
        throw new Error("站点数据为空");
      }

      return data;
    } catch (error) {
      if (error.code === "ENOENT") {
        throw new Error(`站点文件不存在: ${filename}`);
      }
      logger.error("获取站点数据失败", { filename, error: error.message });
      throw new Error(`获取站点数据失败: ${error.message}`);
    }
  }

  /**
   * 创建站点
   */
  async createSite(filename, data) {
    try {
      // 验证数据
      const errors = validateSiteData(data);
      if (errors.length > 0) {
        throw new Error(`数据验证失败: ${errors.join("; ")}`);
      }

      const filePath = getSiteFilePath(filename);

      // 检查文件是否已存在
      try {
        await readFile(filePath);
        throw new Error(`站点文件已存在: ${filename}`);
      } catch (error) {
        if (error.code !== "ENOENT") {
          throw error;
        }
      }

      // 写入文件
      const yamlContent = yaml.dump(data, {
        indent: 2,
        lineWidth: -1,
        quotingType: '"',
      });

      await writeFile(filePath, yamlContent, "utf-8");

      logger.info("站点创建成功", { filename });
      return data;
    } catch (error) {
      logger.error("创建站点失败", { filename, error: error.message });
      throw error;
    }
  }

  /**
   * 更新站点
   */
  async updateSite(filename, data) {
    try {
      // 验证数据
      const errors = validateSiteData(data);
      if (errors.length > 0) {
        throw new Error(`数据验证失败: ${errors.join("; ")}`);
      }

      const filePath = getSiteFilePath(filename);

      // 检查文件是否存在
      try {
        await readFile(filePath);
      } catch (error) {
        if (error.code === "ENOENT") {
          throw new Error(`站点文件不存在: ${filename}`);
        }
        throw error;
      }

      // 写入文件
      const yamlContent = yaml.dump(data, {
        indent: 2,
        lineWidth: -1,
        quotingType: '"',
      });

      await writeFile(filePath, yamlContent, "utf-8");

      logger.info("站点更新成功", { filename });
      return data;
    } catch (error) {
      logger.error("更新站点失败", { filename, error: error.message });
      throw error;
    }
  }

  /**
   * 删除站点
   */
  async deleteSite(filename) {
    try {
      const filePath = getSiteFilePath(filename);

      // 检查文件是否存在
      try {
        await readFile(filePath);
      } catch (error) {
        if (error.code === "ENOENT") {
          throw new Error(`站点文件不存在: ${filename}`);
        }
        throw error;
      }

      // 删除文件
      await unlink(filePath);

      logger.info("站点删除成功", { filename });
      return { success: true, filename };
    } catch (error) {
      logger.error("删除站点失败", { filename, error: error.message });
      throw error;
    }
  }

  /**
   * 获取站点文件名（从站点名称生成）
   */
  generateFilename(name) {
    // 将站点名称转换为文件名格式：site-{name}.yml
    const normalizedName = name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "");

    return `site-${normalizedName}.yml`;
  }
}

