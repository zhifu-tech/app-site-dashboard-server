/**
 * Express 应用配置
 * 配置中间件和路由
 */

import express from "express";
import cors from "cors";
import { appConfig } from "./config/index.js";
import { requestLogger } from "./middleware/requestLogger.js";
import { errorHandler, notFoundHandler } from "./middleware/errorHandler.js";
import routes from "./routes/index.js";
import { logger } from "./utils/logger.js";

/**
 * 创建 Express 应用
 */
export function createApp() {
  const app = express();

  // CORS 配置
  app.use(cors(appConfig.cors));

  // 解析 JSON 请求体
  app.use(express.json({ limit: appConfig.bodyLimit }));

  // 请求日志
  app.use(requestLogger);

  // 路由
  app.use("/api", routes);

  // 404 处理
  app.use(notFoundHandler);

  // 错误处理
  app.use(errorHandler);

  return app;
}

/**
 * 启动服务器
 */
export async function startServer() {
  try {
    const app = createApp();

    app.listen(appConfig.port, appConfig.host, () => {
      logger.info("服务器启动成功", {
        port: appConfig.port,
        host: appConfig.host,
        env: appConfig.nodeEnv,
      });

      const localUrl = `http://localhost:${appConfig.port}`;
      const networkUrl = `http://127.0.0.1:${appConfig.port}`;
      
      console.log("=".repeat(50));
      console.log(`站点仪表板数据管理服务已启动`);
      console.log(`监听地址: ${appConfig.host}:${appConfig.port}`);
      console.log(`环境: ${appConfig.nodeEnv}`);
      console.log(`数据目录: ${appConfig.dataDir}`);
      console.log("");
      console.log(`访问地址:`);
      console.log(`  - 本地访问: ${localUrl}`);
      console.log(`  - 网络访问: ${networkUrl}`);
      console.log("");
      console.log(`API 端点:`);
      console.log(`  - 健康检查: ${localUrl}/api/health`);
      console.log(`  - 站点列表: ${localUrl}/api/sites`);
      console.log(`  - 获取站点: ${localUrl}/api/sites/:filename`);
      console.log(`  - 创建站点: POST ${localUrl}/api/sites`);
      console.log(`  - 更新站点: PUT ${localUrl}/api/sites/:filename`);
      console.log(`  - 删除站点: DELETE ${localUrl}/api/sites/:filename`);
      console.log(`  - 生成索引: POST ${localUrl}/api/sites/index`);
      console.log("=".repeat(50));
    });
  } catch (error) {
    logger.error("服务器启动失败", { error: error.message });
    process.exit(1);
  }
}

