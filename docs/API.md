# Site Dashboard Server API 文档

## 基础信息

- **Base URL**: `http://localhost:3002/api`
- **Content-Type**: `application/json`

## API 端点

### 健康检查

#### GET /api/health

检查服务健康状态。

**响应示例：**
```json
{
  "success": true,
  "status": "ok",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "service": "site-dashboard-server"
}
```

---

### 站点管理

#### GET /api/sites

获取所有站点文件列表。

**响应示例：**
```json
{
  "success": true,
  "data": [
    "site-chatgpt.yml",
    "site-cursor.yml",
    "site-discord.yml"
  ],
  "count": 3
}
```

---

#### GET /api/sites/:filename

获取单个站点数据。

**路径参数：**
- `filename`: 站点文件名（如 `site-chatgpt.yml` 或 `chatgpt`）

**响应示例：**
```json
{
  "success": true,
  "data": {
    "name": "ChatGPT",
    "url": "https://chatgpt.com/",
    "icon": "💬",
    "description": "OpenAI 开发的对话式人工智能助手",
    "links": [
      {
        "text": "OpenAI 官网",
        "url": "https://openai.com/"
      }
    ],
    "tags": [
      "AI工具",
      "ChatGPT",
      "对话助手"
    ]
  }
}
```

**错误响应：**
```json
{
  "success": false,
  "error": "站点文件不存在: site-example.yml"
}
```

---

#### POST /api/sites

创建新站点。

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

**响应示例：**
```json
{
  "success": true,
  "data": {
    "name": "新站点",
    "url": "https://example.com/",
    ...
  },
  "filename": "site-example.yml"
}
```

**错误响应：**
```json
{
  "success": false,
  "error": "数据验证失败: name 字段是必需的，且必须是非空字符串"
}
```

---

#### PUT /api/sites/:filename

完整更新站点数据。

**路径参数：**
- `filename`: 站点文件名

**请求体：**（完整的站点数据对象）

**响应示例：**
```json
{
  "success": true,
  "data": {
    "name": "更新后的站点",
    ...
  }
}
```

---

#### PATCH /api/sites/:filename

部分更新站点数据。

**路径参数：**
- `filename`: 站点文件名

**请求体：**（部分字段）

**响应示例：**
```json
{
  "success": true,
  "data": {
    ...
  }
}
```

---

#### DELETE /api/sites/:filename

删除站点。

**路径参数：**
- `filename`: 站点文件名

**响应示例：**
```json
{
  "success": true,
  "data": {
    "success": true,
    "filename": "site-example.yml"
  }
}
```

---

#### POST /api/sites/index

生成站点索引文件。

**响应示例：**
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

---

## 数据格式

### 站点数据格式

```yaml
name: 站点名称              # 必需，字符串
url: https://example.com/   # 必需，有效的 HTTP/HTTPS URL
icon: 🔗                    # 可选，字符串
description: 站点描述       # 可选，字符串
links:                      # 可选，数组
  - text: 链接文本          # 必需
    url: https://...        # 必需
tags:                       # 可选，数组
  - 标签1
  - 标签2
```

### 验证规则

- `name`: 必需，非空字符串
- `url`: 必需，有效的 HTTP/HTTPS URL（必须以 `http://` 或 `https://` 开头）
- `links`: 可选，必须是数组
- `tags`: 可选，必须是数组

---

## 错误处理

所有错误响应格式：

```json
{
  "success": false,
  "error": "错误消息"
}
```

常见错误码：

- `400`: 请求参数错误
- `404`: 资源不存在
- `500`: 服务器内部错误

---

## 使用示例

### cURL 示例

```bash
# 获取所有站点
curl http://localhost:3002/api/sites

# 获取单个站点
curl http://localhost:3002/api/sites/site-chatgpt.yml

# 创建站点
curl -X POST http://localhost:3002/api/sites \
  -H "Content-Type: application/json" \
  -d '{
    "name": "新站点",
    "url": "https://example.com/",
    "icon": "🔗",
    "description": "站点描述"
  }'

# 更新站点
curl -X PUT http://localhost:3002/api/sites/site-example.yml \
  -H "Content-Type: application/json" \
  -d '{
    "name": "更新后的站点",
    "url": "https://example.com/"
  }'

# 删除站点
curl -X DELETE http://localhost:3002/api/sites/site-example.yml

# 生成索引
curl -X POST http://localhost:3002/api/sites/index
```

### JavaScript 示例

```javascript
// 获取所有站点
const sites = await fetch('http://localhost:3002/api/sites')
  .then(res => res.json());

// 创建站点
const newSite = await fetch('http://localhost:3002/api/sites', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    name: '新站点',
    url: 'https://example.com/',
    icon: '🔗',
    description: '站点描述'
  })
}).then(res => res.json());

// 更新站点
const updatedSite = await fetch('http://localhost:3002/api/sites/site-example.yml', {
  method: 'PUT',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    name: '更新后的站点',
    url: 'https://example.com/'
  })
}).then(res => res.json());

// 删除站点
const result = await fetch('http://localhost:3002/api/sites/site-example.yml', {
  method: 'DELETE'
}).then(res => res.json());
```
