# 常见问题 (FAQ)

## 常见问题

### 1. 502 Bad Gateway 错误

**问题**：访问 `http://0.0.0.0:3002/api/health` 时出现 502 错误

**原因**：`0.0.0.0` 是服务器监听所有网络接口的地址，不是浏览器可以访问的地址。

**解决方案**：
- ✅ 使用 `http://localhost:3002` 或 `http://127.0.0.1:3002`
- ❌ 不要使用 `http://0.0.0.0:3002`

### 2. 端口已被占用

**问题**：启动时提示端口 3002 已被占用

**解决方案**：
```bash
# 查看端口占用情况
lsof -i :3002

# 杀死占用端口的进程
kill -9 <PID>

# 或使用其他端口
PORT=3003 npm run dev
```

### 3. 服务器无法启动

**问题**：运行 `npm run dev` 后服务器立即退出

**检查步骤**：
1. 检查 Node.js 版本：`node --version`（需要 >= 16.0.0）
2. 检查依赖是否安装：`npm install`
3. 检查 `.env` 文件是否存在（可选）
4. 查看错误日志

### 4. 数据文件无法读取

**问题**：API 返回数据文件不存在的错误

**解决方案**：
1. 检查 `data/` 目录是否存在
2. 检查文件权限
3. 检查 `DATA_DIR` 环境变量配置

### 5. CORS 错误

**问题**：浏览器控制台出现 CORS 错误

**解决方案**：
1. 检查 `CORS_ORIGIN` 环境变量
2. 确保服务器端 CORS 配置正确
3. 检查请求的 Origin 头

### 6. 模块导入错误

**问题**：`Cannot find module` 错误

**解决方案**：
```bash
# 重新安装依赖
rm -rf node_modules package-lock.json
npm install
```

### 7. Docker 镜像拉取失败

**问题**：执行 `./scripts/site-dashboard-server.sh docker-deploy` 时出现以下错误：
```
ERROR: failed to build: failed to solve: node:18-alpine: failed to resolve source metadata
```

**原因**：无法从 Docker Hub 拉取基础镜像，通常是网络问题或镜像源问题。

**解决方案**（按推荐顺序）：

#### ✅ 方案 1: 配置 Docker 镜像加速器（推荐，5分钟）

**macOS (Docker Desktop)**：
1. 打开 Docker Desktop → Settings（齿轮图标）
2. 选择 "Docker Engine"
3. 在 JSON 配置中添加镜像加速器：
```json
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ]
}
```
4. 点击 "Apply & Restart"
5. 等待 Docker 重启完成

**Linux**：
1. 编辑 `/etc/docker/daemon.json`（如果不存在则创建）：
```json
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ]
}
```
2. 重启 Docker 服务：
```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```
3. 验证配置：
```bash
docker info | grep -A 10 "Registry Mirrors"
```

#### ✅ 方案 2: 手动拉取镜像（临时解决，2分钟）

如果不想配置镜像加速器，可以先手动拉取基础镜像：
```bash
# 拉取基础镜像
docker pull node:18-alpine

# 验证镜像已拉取
docker images | grep node

# 重新执行部署
./scripts/site-dashboard-server.sh docker-deploy
```

#### ✅ 方案 3: 使用代理（如果已有代理）

**macOS (Docker Desktop)**：
1. Docker Desktop → Settings → Resources → Proxies
2. 配置 HTTP/HTTPS 代理
3. 点击 Apply & Restart

**Linux**：
```bash
sudo mkdir -p /etc/systemd/system/docker.service.d

sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=http://proxy.example.com:8080"
Environment="HTTPS_PROXY=http://proxy.example.com:8080"
Environment="NO_PROXY=localhost,127.0.0.1"
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker
```

**验证解决方案**：
```bash
# 测试拉取基础镜像
docker pull node:18-alpine

# 如果成功，应该看到类似输出：
# 18-alpine: Pulling from library/node
# Status: Downloaded newer image for node:18-alpine
```

**常见镜像加速器地址**：
| 提供商 | 镜像地址 |
|--------|---------|
| 中科大 | `https://docker.mirrors.ustc.edu.cn` |
| 网易 | `https://hub-mirror.c.163.com` |
| 百度云 | `https://mirror.baidubce.com` |
| 阿里云 | `https://<your-id>.mirror.aliyuncs.com`（需要登录） |

**其他排查步骤**：
如果以上方案都无法解决：
1. 检查网络连接：`ping docker.io`、`curl -I https://hub.docker.com`
2. 检查 Docker 服务状态：`docker info`、`docker version`
3. 查看详细错误日志：`docker build -t site-dashboard-server:latest . --progress=plain`

### 8. Docker 平台不匹配警告

**问题**：部署时出现警告：
```
WARNING: The requested image's platform (linux/arm64) does not match the detected host platform (linux/amd64/v4)
```

**原因**：在 macOS (ARM64/M1/M2) 上构建的镜像，但服务器是 AMD64 架构。

**解决方案**：

脚本已自动处理此问题，构建时会指定 `--platform linux/amd64`。

如果需要手动构建，可以指定平台：

```bash
# 构建时指定平台
docker build --platform linux/amd64 -t site-dashboard-server:latest .

# 或者设置环境变量
export BUILD_PLATFORM=linux/amd64
./scripts/site-dashboard-server.sh docker-build
```

**注意**：
- ✅ 警告不影响功能，容器可以正常运行（Docker 会自动处理跨平台）
- ✅ 但为了最佳性能，建议在构建时指定正确的平台
- ✅ 脚本已默认使用 `linux/amd64` 平台构建

### 9. SSH 密码重复输入问题

**问题**：执行部署脚本时，需要不断输入服务器密码。

**原因**：
1. SSH 密钥未正确配置
2. SSH 密钥路径不正确
3. SSH 密钥权限不正确

**解决方案**：

1. **检查 SSH 密钥是否存在**：
   ```bash
   ls -la ~/.ssh/id_rsa_site_dashboard*
   ```

2. **如果密钥不存在，创建或复制**：
   ```bash
   # 如果已有其他项目的密钥，可以复制
   cp ~/.ssh/id_rsa_book_excerpt ~/.ssh/id_rsa_site_dashboard
   cp ~/.ssh/id_rsa_book_excerpt.pub ~/.ssh/id_rsa_site_dashboard.pub
   
   # 设置正确的权限
   chmod 600 ~/.ssh/id_rsa_site_dashboard
   chmod 644 ~/.ssh/id_rsa_site_dashboard.pub
   ```

3. **将公钥复制到服务器**：
   ```bash
   ssh-copy-id -i ~/.ssh/id_rsa_site_dashboard.pub root@8.138.183.116
   ```

4. **测试 SSH 连接（应该不需要密码）**：
   ```bash
   ssh -i ~/.ssh/id_rsa_site_dashboard root@8.138.183.116
   ```

5. **配置 SSH 别名（可选，但推荐）**：
   编辑 `~/.ssh/config`：
   ```
   Host site-dashboard-server
       HostName 8.138.183.116
       User root
       Port 22
       IdentityFile ~/.ssh/id_rsa_site_dashboard
   ```

**验证**：
```bash
# 测试 SSH 连接（应该不需要密码）
ssh site-dashboard-server "echo 'SSH 连接成功'"
```

### 10. Docker 端口冲突问题

**问题**：部署时出现错误：
```
Error: bind: address already in use
```

**原因**：同一台服务器上部署了多个应用，端口被占用。

**解决方案**：

1. **使用内部端口映射**（推荐）：
   - 容器端口映射到 `127.0.0.1`（仅本地访问）
   - 使用不同的内部端口（8082, 8081, 3002 等）
   - 通过 Nginx 反向代理统一入口

2. **检查端口占用**：
   ```bash
   # 检查端口占用情况
   netstat -tlnp | grep :80
   ss -tlnp | grep :80
   
   # 查看所有 Docker 容器端口映射
   docker ps --format "table {{.Names}}\t{{.Ports}}"
   ```

3. **停止占用端口的容器**：
   ```bash
   docker stop <container-name>
   docker rm <container-name>
   ```

4. **使用不同的端口**：
   ```bash
   # 修改部署脚本中的端口映射
   # site-dashboard: -p 127.0.0.1:8082:80
   # site-dashboard-server: -p 127.0.0.1:3002:3002
   ```

**多应用部署最佳实践**：
- ✅ 使用 Nginx 反向代理作为统一入口
- ✅ 容器映射到 `127.0.0.1`，避免端口冲突
- ✅ 使用不同域名区分应用（推荐）
- ✅ 详细指南：参考 `site-dashboard/docs/MULTI_APP_DEPLOYMENT.md`

## 调试技巧

### 查看服务器日志

服务器启动时会输出详细的启动信息，包括：
- 监听地址和端口
- 数据目录路径
- 所有 API 端点

### 使用 curl 测试 API

```bash
# 健康检查
curl http://localhost:3002/api/health

# 获取站点列表
curl http://localhost:3002/api/sites

# 获取单个站点
curl http://localhost:3002/api/sites/site-chatgpt.yml
```

### 检查服务器状态

```bash
# 检查端口是否在监听
lsof -i :3002

# 检查进程
ps aux | grep "node.*server.js"
```

## 环境变量配置

确保 `.env` 文件配置正确：

```env
HOST=0.0.0.0
PORT=3002
NODE_ENV=development
DATA_DIR=./data
CORS_ORIGIN=*
```

## 联系支持

如果问题仍然存在，请：
1. 检查服务器日志
2. 检查浏览器控制台错误
3. 提供详细的错误信息
