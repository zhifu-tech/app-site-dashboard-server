# Site Dashboard Server

站点仪表板数据管理服务端 - 提供站点数据的 CRUD API。

## 功能特性

- ✅ **完整的 CRUD 操作**：创建、读取、更新、删除站点数据
- ✅ **自动索引生成**：自动生成站点索引文件
- ✅ **数据验证**：YAML 格式验证和数据完整性检查
- ✅ **RESTful API**：标准的 REST API 设计
- ✅ **错误处理**：完善的错误处理和日志记录
- ✅ **CORS 支持**：跨域资源共享支持

## 快速开始

### 安装依赖

```bash
npm install
```

### 配置环境变量

复制示例配置文件：

```bash
cp example.env .env
```

编辑 `.env` 文件，配置服务器参数。

### 启动服务

```bash
# 开发模式（自动重启）
npm run dev

# 生产模式
npm start
```

服务默认运行在 `http://localhost:3002`

**重要提示**：
- ✅ 使用 `http://localhost:3002` 或 `http://127.0.0.1:3002` 访问
- ❌ 不要使用 `http://0.0.0.0:3002`（`0.0.0.0` 是服务器监听地址，不是浏览器访问地址）

### HTTPS 配置（可选）

服务支持 HTTPS 模式，可以通过环境变量配置：

```env
HTTPS_ENABLED=true
SSL_KEY_PATH=./ssl/server.key
SSL_CERT_PATH=./ssl/server.crt
```

**详细配置说明**：请参考 [HTTPS 配置指南](docs/HTTPS_CONFIG.md)

## API 文档

### 健康检查

```http
GET /api/health
```

**响应：**
```json
{
  "success": true,
  "status": "ok",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "service": "site-dashboard-server"
}
```

### 获取站点列表

```http
GET /api/sites
```

**响应：**
```json
{
  "success": true,
  "data": [
    "site-chatgpt.yml",
    "site-cursor.yml",
    ...
  ],
  "count": 11
}
```

### 获取单个站点

```http
GET /api/sites/:filename
```

**参数：**
- `filename`: 站点文件名（如 `site-chatgpt.yml` 或 `chatgpt`）

**响应：**
```json
{
  "success": true,
  "data": {
    "name": "ChatGPT",
    "url": "https://chatgpt.com/",
    "icon": "💬",
    "description": "...",
    "links": [...],
    "tags": [...]
  }
}
```

### 创建站点

```http
POST /api/sites
Content-Type: application/json
```

**请求体：**
```json
{
  "name": "新站点",
  "url": "https://example.com/",
  "icon": "🔗",
  "description": "站点描述",
  "links": [
    {
      "text": "链接文本",
      "url": "https://example.com/link"
    }
  ],
  "tags": ["标签1", "标签2"],
  "filename": "site-example.yml"  // 可选，不提供则自动生成
}
```

**响应：**
```json
{
  "success": true,
  "data": { ... },
  "filename": "site-example.yml"
}
```

### 更新站点

```http
PUT /api/sites/:filename
Content-Type: application/json
```

**请求体：**（完整的站点数据）

```http
PATCH /api/sites/:filename
Content-Type: application/json
```

**请求体：**（部分更新）

### 删除站点

```http
DELETE /api/sites/:filename
```

**响应：**
```json
{
  "success": true,
  "data": {
    "success": true,
    "filename": "site-example.yml"
  }
}
```

### 生成站点索引

```http
POST /api/sites/index
```

**响应：**
```json
{
  "success": true,
  "data": {
    "sites": [
      "site-chatgpt.yml",
      "site-cursor.yml",
      ...
    ],
    "generatedAt": "2024-01-01T00:00:00.000Z"
  }
}
```

## 项目结构

```
site-dashboard-server/
├── src/
│   ├── config/          # 配置文件
│   ├── controllers/     # 控制器
│   ├── services/        # 业务逻辑
│   ├── routes/          # 路由
│   ├── middleware/      # 中间件
│   └── utils/           # 工具函数
├── data/                # 站点数据目录
├── scripts/             # 部署脚本
├── docs/                # 文档
├── server.js            # 服务器入口
└── package.json         # 项目配置
```

## 开发

### 代码规范

```bash
# 检查代码
npm run lint

# 自动修复
npm run lint:fix

# 格式化代码
npm run format

# 检查格式
npm run format:check
```

**注意**：项目使用 ESLint 9（Flat Config），配置文件为 `eslint.config.mjs`。

### PM2 部署

```bash
# 启动
npm run pm2:start

# 停止
npm run pm2:stop

# 重启
npm run pm2:restart

# 查看日志
npm run pm2:logs
```

### Docker 部署

```bash
# 构建 Docker 镜像
./scripts/site-dashboard-server.sh docker-build

# 部署到服务器（自动构建、上传、运行）
./scripts/site-dashboard-server.sh docker-deploy

# 本地调试（开发模式）
./scripts/site-dashboard-server.sh docker-up

# 查看容器日志
./scripts/site-dashboard-server.sh docker-logs

# 停止容器
./scripts/site-dashboard-server.sh docker-down
```

**⚠️ 如果遇到问题，请参考：**
- [常见问题 FAQ](docs/FAQ.md) - 包含 Docker 故障排查、端口冲突、SSH 配置等问题

### 数据同步

数据同步功能支持双向同步，实现本地和服务器数据的智能合并：

```bash
# 将本地数据同步到服务器
./scripts/site-dashboard-server.sh sync-data up

# 将服务器数据同步回本地（智能合并）
./scripts/site-dashboard-server.sh sync-data down
```

**详细文档**：请参考 [数据同步策略文档](docs/data-sync.md)

## 环境变量

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `HOST` | 服务器监听地址 | `0.0.0.0` |
| `PORT` | 服务器端口 | `3002` |
| `NODE_ENV` | 运行环境 | `development` |
| `DATA_DIR` | 数据目录路径 | `./data` |
| `CORS_ORIGIN` | CORS 允许的源 | `*` |
| `BODY_LIMIT` | 请求体大小限制 | `10mb` |
| `LOG_LEVEL` | 日志级别 | `INFO` |

## 数据格式

站点数据使用 YAML 格式：

```yaml
name: 站点名称
url: https://example.com/
icon: 🔗
description: 站点描述
links:
  - text: 链接文本
    url: https://example.com/link
tags:
  - 标签1
  - 标签2
```

## 许可证

MIT

