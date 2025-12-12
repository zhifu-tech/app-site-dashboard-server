# 数据同步策略文档

## 概述

本文档说明 `site-dashboard-server` 项目的数据同步策略和管理方式。数据文件采用 **混合方案**，即初始数据随代码提交到 Git，运行时数据通过 API 动态管理，支持双向同步。

## 数据存储位置

### 开发环境（本地）

- **路径**: `site-dashboard-server/data/`
- **格式**: 每个站点一个 YAML 文件（如 `site-chatgpt.yml`）
- **管理**: 提交到 Git，随代码版本控制

### 生产环境（服务器）

- **路径**: `/opt/site-dashboard-server/data/`（通过 Docker volume 挂载到容器内的 `/app/data`）
- **格式**: 与本地相同，YAML 文件格式
- **管理**: 通过 API 动态管理，或通过同步脚本同步

## 数据同步命令

### 基本用法

```bash
# 查看数据同步帮助
./scripts/site-dashboard-server.sh sync-data help

# 将本地数据同步到服务器
./scripts/site-dashboard-server.sh sync-data up
# 或
./scripts/site-dashboard-server.sh sync-data to-server

# 将服务器数据同步回本地（智能合并）
./scripts/site-dashboard-server.sh sync-data down
# 或
./scripts/site-dashboard-server.sh sync-data from-server
```

## 同步方向说明

### 1. 本地 → 服务器 (`sync-data up`)

**用途**: 将本地开发的数据同步到生产服务器

**行为**:

- 检查本地数据目录和文件
- 创建服务器数据目录（如果不存在）
- 同步所有 `site-*.yml` 文件到服务器
- 验证同步结果（文件数量对比）

**使用场景**:

- 首次部署数据
- 本地开发完成后同步到服务器
- 批量更新服务器数据

**示例**:

```bash
./scripts/site-dashboard-server.sh sync-data up
```

**输出示例**:

```sh
同步数据到服务器...

本地数据文件: 11 个

准备服务器数据目录...
同步数据文件...
验证同步结果...

✓ 数据同步成功！

同步统计:
  本地文件: 11
  服务器文件: 11
  服务器路径: /opt/site-dashboard-server/data
```

### 2. 服务器 → 本地 (`sync-data down`)

**用途**: 将服务器上的数据同步回本地，并进行智能合并

**行为**:

- 检查服务器数据目录
- 下载服务器数据到临时目录
- **智能合并**:
  - 服务器文件优先：如果文件在服务器和本地都存在，使用服务器版本（覆盖本地）
  - 新增服务器文件：服务器上有但本地没有的文件，会添加到本地
  - 保留本地独有：本地有但服务器没有的文件，会保留在本地
- 清理临时目录
- **自动删除所有备份目录**（`data.backup.*`）

**使用场景**:

- 服务器上通过 API 创建了新站点，需要同步回本地
- 服务器上的数据被修改，需要同步回本地并提交到 Git
- 多人协作时，同步其他人的更改

**示例**:

```bash
./scripts/site-dashboard-server.sh sync-data down
```

**输出示例**:

```sh
同步数据回本地（智能合并）...

服务器数据文件: 12 个
本地数据文件: 11 个

下载服务器数据到临时目录...
已下载 12 个服务器文件

合并数据文件...
清理备份目录...
已删除: data.backup.20251211_234610

✓ 数据合并完成！

合并统计:
  更新文件: 11 (服务器版本覆盖本地)
  新增文件: 1 (服务器新增)
  保留文件: 0 (本地独有)
  最终文件数: 12
  数据路径: /path/to/site-dashboard-server/data
```

## 合并策略详解

### 智能合并逻辑

当执行 `sync-data down` 时，系统会执行以下合并策略：

1. **服务器文件优先原则**
   - 如果文件在服务器和本地都存在，使用服务器版本
   - 这确保服务器上的最新更改会被保留

2. **新增文件处理**
   - 服务器上有但本地没有的文件，会添加到本地
   - 适用于通过 API 在服务器上创建的新站点

3. **保留本地独有文件**
   - 本地有但服务器没有的文件，会保留在本地
   - 适用于本地开发但尚未同步到服务器的文件

### 合并流程

```sh
1. 下载服务器数据到临时目录
   └─ 避免直接覆盖，确保安全

2. 遍历服务器文件
   ├─ 文件在本地存在 → 更新（使用服务器版本）
   └─ 文件在本地不存在 → 新增

3. 遍历本地文件
   └─ 文件在服务器不存在 → 保留本地版本

4. 清理临时目录

5. 删除所有备份目录（data.backup.*）
```

## 数据管理流程

### 开发流程

1. **本地开发**

   ```bash
   # 在本地修改数据文件
   vim data/site-example.yml
   ```

2. **提交到 Git**

   ```bash
   git add data/site-example.yml
   git commit -m "feat: 添加新站点"
   ```

3. **同步到服务器**

   ```bash
   ./scripts/site-dashboard-server.sh sync-data up
   ```

4. **部署代码**（如果需要）

   ```bash
   ./scripts/site-dashboard-server.sh docker-deploy
   ```

### 服务器数据变更流程

1. **通过 API 在服务器上创建/更新站点**

   ```bash
   curl -X POST http://server:3002/api/sites \
     -H "Content-Type: application/json" \
     -d '{"name":"New Site", "url":"https://example.com"}'
   ```

2. **同步回本地**

   ```bash
   ./scripts/site-dashboard-server.sh sync-data down
   ```

3. **提交到 Git**

   ```bash
   git add data/site-new-site.yml
   git commit -m "feat: 从服务器同步新站点"
   ```

## 备份目录管理

### 自动清理

- 执行 `sync-data down` 时，会自动删除所有 `data.backup.*` 目录
- 备份目录在智能合并过程中不再需要，因为合并策略确保不会丢失数据

### 手动清理

如果需要手动清理备份目录：

```bash
# 查找所有备份目录
find . -maxdepth 1 -type d -name "data.backup.*"

# 删除所有备份目录
find . -maxdepth 1 -type d -name "data.backup.*" -exec rm -rf {} +
```

## 数据文件格式

数据文件使用 YAML 格式，每个文件代表一个站点：

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

文件命名规范：

- 必须以 `site-` 开头
- 必须以 `.yml` 结尾
- 示例: `site-chatgpt.yml`, `site-cursor.yml`

## 注意事项

### 1. 数据冲突处理

- **服务器优先**: 当文件在服务器和本地都存在时，使用服务器版本
- **建议**: 在服务器上修改数据后，及时同步回本地并提交到 Git

### 2. Git 版本控制

- 数据文件应该提交到 Git（`.gitignore` 中不忽略 `data/*.yml`）
- 运行时生成的文件（如 `sites.json`）会被忽略

### 3. 数据一致性

- 定期执行 `sync-data down` 确保本地和服务器数据一致
- 在部署前执行 `sync-data up` 确保服务器有最新数据

### 4. 错误处理

如果同步失败：

- 检查网络连接
- 检查服务器数据目录权限
- 查看脚本输出的错误信息
- 使用手动同步命令（脚本会提供）

## 故障排查

### 问题：同步失败，提示权限错误

**解决方案**:

```bash
# 检查服务器目录权限
ssh root@server "ls -la /opt/site-dashboard-server/data"

# 确保目录存在且可写
ssh root@server "mkdir -p /opt/site-dashboard-server/data && chmod 755 /opt/site-dashboard-server/data"
```

### 问题：合并后文件数量不对

**检查**:

1. 查看合并统计信息
2. 检查是否有文件被意外删除
3. 验证服务器和本地的文件列表

### 问题：备份目录没有被删除

**解决方案**:

```bash
# 手动删除备份目录
find . -maxdepth 1 -type d -name "data.backup.*" -exec rm -rf {} +
```

## 最佳实践

1. **开发时**: 在本地修改数据，提交到 Git，然后同步到服务器
2. **生产时**: 通过 API 管理数据，定期同步回本地并提交到 Git
3. **协作时**: 定期执行 `sync-data down` 获取最新数据
4. **部署前**: 执行 `sync-data up` 确保服务器有最新数据
5. **定期备份**: 虽然备份目录会自动清理，但建议定期提交到 Git 作为备份

## 相关文档

- [API 文档](API.md) - API 接口说明
- [部署文档](DEPLOY.md) - 部署指南
- [常见问题](FAQ.md) - 常见问题解答
