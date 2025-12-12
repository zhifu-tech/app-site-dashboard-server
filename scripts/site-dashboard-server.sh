#!/bin/bash

# ============================================
# Site Dashboard Server - 统一管理脚本
# ============================================
# 整合所有部署和管理功能
# 使用方法: ./scripts/site-dashboard-server.sh [command]
# ============================================

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ============================================
# 配置变量
# ============================================

# 服务器配置
SERVER_HOST="${SERVER_HOST:-8.138.183.116}"
SERVER_USER="${SERVER_USER:-root}"
SERVER_PORT="${SERVER_PORT:-22}"
APP_DIR="${APP_DIR:-/opt/site-dashboard-server}"
APP_PORT="${APP_PORT:-3002}"

# SSH 配置
SSH_KEY_NAME="id_rsa_site_dashboard"
SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY_NAME"
SSH_ALIAS="site-dashboard-server"

# Docker 配置
DOCKER_IMAGE_NAME="site-dashboard-server"
DOCKER_COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"

# Nginx 配置
NGINX_CONF_PATH="/etc/nginx/conf.d/site-dashboard-server.conf"
SSL_CERT_DIR="/etc/nginx/ssl"

# 颜色输出定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================
# 辅助函数
# ============================================

print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
  echo -e "${RED}✗ $1${NC}"
}

print_info() {
  echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

# 初始化 SSH 连接参数
init_ssh_connection() {
  if [ -f "$SSH_KEY_PATH" ]; then
    SSH_OPTIONS="-i $SSH_KEY_PATH"
    SSH_TARGET="$SERVER_USER@$SERVER_HOST"
  elif ssh -o ConnectTimeout=1 -o BatchMode=yes -p ${SERVER_PORT} "$SSH_ALIAS" "echo" &>/dev/null 2>&1; then
    SSH_OPTIONS=""
    SSH_TARGET="$SSH_ALIAS"
  else
    SSH_OPTIONS=""
    SSH_TARGET="$SERVER_USER@$SERVER_HOST"
  fi
}

# 执行 SSH 命令（统一入口）
# 用法: ssh_exec "command" 或 ssh_exec << 'ENDSSH' ... ENDSSH
ssh_exec() {
  if [ $# -eq 0 ]; then
    # 从标准输入读取（用于 here-document）
    ssh $SSH_OPTIONS -p ${SERVER_PORT} ${SSH_TARGET}
  else
    # 直接执行命令
    ssh $SSH_OPTIONS -p ${SERVER_PORT} ${SSH_TARGET} "$@"
  fi
}

# 自动初始化 SSH 连接
init_ssh_connection

# ============================================
# 欢迎界面
# ============================================
show_welcome() {
  echo ""
  echo -e "${CYAN}"
  cat << "EOF"
 ____          __             ____                       __       __                                 __     
/\  _`\    __ /\ \__         /\  _`\                    /\ \     /\ \                               /\ \    
\ \,\L\_\ /\_\\ \ ,_\     __ \ \ \/\ \     __       ____\ \ \___ \ \ \____    ___      __     _ __  \_\ \   
 \/_\__ \ \/\ \\ \ \/   /'__`\\ \ \ \ \  /'__`\    /',__\\ \  _ `\\ \ '__`\  / __`\  /'__`\  /\`'__\/'_` \  
   /\ \L\ \\ \ \\ \ \_ /\  __/ \ \ \_\ \/\ \L\.\_ /\__, `\\ \ \ \ \\ \ \L\ \/\ \L\ \/\ \L\.\_\ \ \//\ \L\ \ 
   \ `\____\\ \_\\ \__\\ \____\ \ \____/\ \__/.\_\\/\____/ \ \_\ \_\\ \_,__/\ \____/\ \__/.\_\\ \_\\ \___,_\
    \/_____/ \/_/ \/__/ \/____/  \/___/  \/__/\/_/ \/___/   \/_/\/_/ \/___/  \/___/  \/__/\/_/ \/_/ \/__,_ /
                                                                                                            
                                                                                                            
EOF
  echo -e "${NC}"
  echo -e "${CYAN}              Site Dashboard Server - API 服务@Zhifu's Tech${NC}"
  echo ""
  local cmd="${1:-help}"
  echo -e "${YELLOW}版本: 1.0.0${NC}"
  echo -e "${YELLOW}服务器: ${SERVER_HOST}${NC}"
  echo -e "${YELLOW}端口: ${APP_PORT}${NC}"
  echo -e "${YELLOW}命令: ${cmd}${NC}"
  echo ""
}

# ============================================
# 命令函数
# ============================================

# 本地开发
cmd_dev() {
  echo -e "${GREEN}启动开发服务器...${NC}"
  cd "$PROJECT_ROOT"
  npm run dev
}

# 启动服务
cmd_start() {
  echo -e "${GREEN}启动服务...${NC}"
  cd "$PROJECT_ROOT"
  npm start
}

# Docker 构建
cmd_docker_build() {
  echo -e "${GREEN}构建 Docker 镜像...${NC}"
  cd "$PROJECT_ROOT"
  
  # 检查 Dockerfile 是否存在
  if [ ! -f "Dockerfile" ]; then
    print_error "未找到 Dockerfile"
    exit 1
  fi
  
  # 检测目标平台（如果服务器是 AMD64，需要指定平台）
  BUILD_PLATFORM="${BUILD_PLATFORM:-linux/amd64}"
  
  # 尝试构建镜像（指定平台以避免 ARM64/AMD64 不匹配）
  if docker build --platform "$BUILD_PLATFORM" -t "$DOCKER_IMAGE_NAME:latest" .; then
    print_success "Docker 镜像构建完成（平台: $BUILD_PLATFORM）"
  else
    print_error "Docker 镜像构建失败"
    echo ""
    echo -e "${YELLOW}可能的解决方案：${NC}"
    echo "1. 配置 Docker 镜像加速器（推荐）"
    echo "   - macOS: Docker Desktop → Settings → Docker Engine → 添加 registry-mirrors"
    echo "   - Linux: 编辑 /etc/docker/daemon.json 添加 registry-mirrors"
    echo ""
    echo "2. 手动拉取基础镜像："
    echo "   docker pull --platform $BUILD_PLATFORM node:18-alpine"
    echo ""
    echo "3. 查看详细错误信息："
    echo "   docker build --platform $BUILD_PLATFORM -t $DOCKER_IMAGE_NAME:latest ."
    echo ""
    echo "4. 查看 FAQ 文档获取更多帮助："
    echo "   cat docs/FAQ.md"
    exit 1
  fi
}

# Docker 启动
cmd_docker_up() {
  echo -e "${GREEN}启动 Docker 容器...${NC}"
  cd "$PROJECT_ROOT"
  docker-compose -f "$DOCKER_COMPOSE_FILE" up -d
  print_success "Docker 容器已启动"
  echo ""
  echo -e "${YELLOW}访问地址:${NC}"
  echo -e "  ${GREEN}http://localhost:${APP_PORT}${NC}"
}

# Docker 停止
cmd_docker_down() {
  echo -e "${GREEN}停止 Docker 容器...${NC}"
  cd "$PROJECT_ROOT"
  docker-compose -f "$DOCKER_COMPOSE_FILE" down
  print_success "Docker 容器已停止"
}

# Docker 日志
cmd_docker_logs() {
  echo -e "${GREEN}查看 Docker 容器日志...${NC}"
  cd "$PROJECT_ROOT"
  docker-compose -f "$DOCKER_COMPOSE_FILE" logs -f --tail=100
}

# 部署到服务器
cmd_deploy() {
  echo -e "${GREEN}部署到服务器...${NC}"
  cd "$PROJECT_ROOT"

  # 检查必要文件
  if [ ! -f "package.json" ]; then
    print_error "未找到 package.json，请确保在项目根目录执行"
    exit 1
  fi

  # 创建临时部署目录
  TEMP_DEPLOY_DIR=$(mktemp -d)
  echo -e "${YELLOW}创建临时目录: ${TEMP_DEPLOY_DIR}${NC}"

  # 复制文件
  echo -e "${YELLOW}复制文件...${NC}"
  cp -r src "$TEMP_DEPLOY_DIR/"
  cp package.json package-lock.json "$TEMP_DEPLOY_DIR/" 2>/dev/null || true
  cp server.js "$TEMP_DEPLOY_DIR/"
  cp .env "$TEMP_DEPLOY_DIR/" 2>/dev/null || true
  cp example.env "$TEMP_DEPLOY_DIR/" 2>/dev/null || true

  # 上传到服务器
  echo -e "${YELLOW}上传文件到服务器...${NC}"
  ssh $SSH_OPTIONS -p ${SERVER_PORT} "$SSH_TARGET" "mkdir -p $APP_DIR"
  scp $SSH_OPTIONS -r -P ${SERVER_PORT} "$TEMP_DEPLOY_DIR"/* "$SSH_TARGET:$APP_DIR/"

  # 清理临时目录
  rm -rf "$TEMP_DEPLOY_DIR"

  # 在服务器上安装依赖并重启服务
  echo -e "${YELLOW}在服务器上安装依赖...${NC}"
  ssh $SSH_OPTIONS -p ${SERVER_PORT} "$SSH_TARGET" "cd $APP_DIR && npm ci --only=production"

  echo -e "${YELLOW}重启服务...${NC}"
  ssh $SSH_OPTIONS -p ${SERVER_PORT} "$SSH_TARGET" "cd $APP_DIR && pm2 restart site-dashboard-server || pm2 start server.js --name site-dashboard-server"

  print_success "部署完成"
}

# Docker 部署
cmd_docker_deploy() {
  echo -e "${GREEN}Docker 部署到服务器...${NC}"
  cd "$PROJECT_ROOT"

  # 构建镜像
  cmd_docker_build

  # 保存镜像
  echo -e "${YELLOW}保存 Docker 镜像...${NC}"
  docker save "$DOCKER_IMAGE_NAME:latest" | gzip > /tmp/site-dashboard-server.tar.gz

  # 上传镜像
  echo -e "${YELLOW}上传镜像到服务器...${NC}"
  scp $SSH_OPTIONS -P ${SERVER_PORT} /tmp/site-dashboard-server.tar.gz "$SSH_TARGET:/tmp/"

  # 在服务器上加载镜像并运行
  echo -e "${YELLOW}在服务器上加载镜像...${NC}"
  ssh $SSH_OPTIONS -p ${SERVER_PORT} "$SSH_TARGET" "docker load < /tmp/site-dashboard-server.tar.gz"

  echo -e "${YELLOW}运行容器...${NC}"
  ssh $SSH_OPTIONS -p ${SERVER_PORT} "$SSH_TARGET" "docker stop site-dashboard-server 2>/dev/null || true"
  ssh $SSH_OPTIONS -p ${SERVER_PORT} "$SSH_TARGET" "docker rm site-dashboard-server 2>/dev/null || true"
  
  # 检查服务器上是否有 SSL 证书
  SSL_KEY_PATH="/etc/nginx/ssl/site-dashboard-server.key"
  SSL_CERT_PATH="/etc/nginx/ssl/site-dashboard-server.crt"
  HAS_SSL=$(ssh $SSH_OPTIONS -p ${SERVER_PORT} "$SSH_TARGET" "test -f $SSL_KEY_PATH && test -f $SSL_CERT_PATH && echo 'yes' || echo 'no'")
  
  # 构建 Docker 运行命令
  DOCKER_CMD="docker run -d --platform linux/amd64 --name site-dashboard-server -p 127.0.0.1:$APP_PORT:3002 -v $APP_DIR/data:/app/data --restart unless-stopped"
  
  # 如果存在 SSL 证书，挂载并启用 HTTPS
  if [ "$HAS_SSL" = "yes" ]; then
    echo -e "${BLUE}检测到 SSL 证书，启用 HTTPS 模式${NC}"
    DOCKER_CMD="$DOCKER_CMD -v $SSL_KEY_PATH:/app/ssl/server.key:ro -v $SSL_CERT_PATH:/app/ssl/server.crt:ro -e HTTPS_ENABLED=true -e SSL_KEY_PATH=/app/ssl/server.key -e SSL_CERT_PATH=/app/ssl/server.crt"
  else
    echo -e "${YELLOW}未检测到 SSL 证书，使用 HTTP 模式${NC}"
    echo -e "${CYAN}提示：如需启用 HTTPS，请将 SSL 证书放置在服务器上的以下路径：${NC}"
    echo -e "  ${BLUE}私钥: $SSL_KEY_PATH${NC}"
    echo -e "  ${BLUE}证书: $SSL_CERT_PATH${NC}"
  fi
  
  DOCKER_CMD="$DOCKER_CMD $DOCKER_IMAGE_NAME:latest"
  
  ssh $SSH_OPTIONS -p ${SERVER_PORT} "$SSH_TARGET" "$DOCKER_CMD"

  # 清理临时文件
  rm -f /tmp/site-dashboard-server.tar.gz
  ssh $SSH_OPTIONS -p ${SERVER_PORT} "$SSH_TARGET" "rm -f /tmp/site-dashboard-server.tar.gz"
  
  echo ""
  print_success "Docker 部署完成"
  echo ""
  echo -e "${YELLOW}容器信息：${NC}"
  echo -e "  容器名称: ${GREEN}site-dashboard-server${NC}"
  echo -e "  端口映射: ${GREEN}127.0.0.1:${APP_PORT}:3002${NC}"
  echo -e "  平台: ${GREEN}linux/amd64${NC}"
  echo ""
  echo -e "${YELLOW}访问地址：${NC}"
  echo -e "  本地访问: ${GREEN}http://127.0.0.1:${APP_PORT}/api/health${NC}"
  echo -e "  外部访问: ${GREEN}http://${SERVER_HOST}:${APP_PORT}/api/health${NC}"
  echo ""
  echo -e "${CYAN}提示：${NC} 如果使用 Nginx 反向代理，请运行："
  echo -e "${CYAN}  ${BLUE}./scripts/site-dashboard-server.sh update-nginx${NC}"

  print_success "Docker 部署完成"
}

# ============================================
# Nginx 配置管理
# ============================================

# 加载共用脚本库
APP_COMMON_DIR="$(cd "$PROJECT_ROOT/../app-common" && pwd)"
[ -f "$APP_COMMON_DIR/scripts/nginx-utils.sh" ] && source "$APP_COMMON_DIR/scripts/nginx-utils.sh"
[ -f "$APP_COMMON_DIR/scripts/nginx-update.sh" ] && source "$APP_COMMON_DIR/scripts/nginx-update.sh"

# 更新 Nginx 配置
cmd_update_nginx() {
  # 确定配置文件路径
  NGINX_LOCAL_CONF="${1:-$SCRIPT_DIR/site-dashboard-server.nginx.conf}"
  [ -f "$NGINX_LOCAL_CONF" ] || {
    print_error "配置文件不存在: ${NGINX_LOCAL_CONF}"
    echo ""
    echo "可用的配置文件："
    ls -1 "$SCRIPT_DIR"/*.nginx*.conf 2>/dev/null || echo "  无"
    exit 1
  }

  echo -e "${GREEN}更新 Nginx 配置到服务器 ${SERVER_HOST}...${NC}"
  echo ""

  # 检查 SSL 证书目录
  APP_COMMON_DIR="$(cd "$PROJECT_ROOT/../app-common" && pwd)"
  SSL_CERT_NAME="api.site-dashboard.zhifu.tech"
  SSL_CERT_LOCAL_DIR="$APP_COMMON_DIR/ssl/${SSL_CERT_NAME}_nginx"
  SSL_CERT_KEY="$SSL_CERT_LOCAL_DIR/${SSL_CERT_NAME}.key"
  SSL_CERT_BUNDLE_CRT="$SSL_CERT_LOCAL_DIR/${SSL_CERT_NAME}_bundle.crt"
  SSL_CERT_BUNDLE_PEM="$SSL_CERT_LOCAL_DIR/${SSL_CERT_NAME}_bundle.pem"
  
  SSL_CERT_FILES_EXIST=false
  if [ -f "$SSL_CERT_KEY" ] && ([ -f "$SSL_CERT_BUNDLE_CRT" ] || [ -f "$SSL_CERT_BUNDLE_PEM" ]); then
    SSL_CERT_FILES_EXIST=true
  fi

  # 使用共用脚本库更新配置（包含 SSL 证书）
  if [ "$SSL_CERT_FILES_EXIST" = true ]; then
    update_nginx_config \
      "$NGINX_LOCAL_CONF" \
      "$NGINX_CONF_PATH" \
      "$SSH_OPTIONS" \
      "$SERVER_PORT" \
      "$SSH_TARGET" \
      "ssh_exec" \
      "$SSL_CERT_NAME" \
      "$SSL_CERT_LOCAL_DIR" \
      "$SSL_CERT_DIR"
  else
    # 不使用 SSL 证书的简化版本
    prepare_nginx_server "$NGINX_CONF_PATH" "ssh_exec" "$SSH_TARGET"
    echo -e "${YELLOW}上传配置文件...${NC}"
    scp $SSH_OPTIONS -P ${SERVER_PORT} "$NGINX_LOCAL_CONF" ${SSH_TARGET}:${NGINX_CONF_PATH}
    test_and_reload_nginx "$NGINX_CONF_PATH" "ssh_exec" "$SSH_TARGET"
  fi

  echo ""
  print_success "Nginx 配置更新完成！"
  echo -e "${YELLOW}配置文件: ${NGINX_CONF_PATH}${NC}"
  [ "$SSL_CERT_FILES_EXIST" = true ] && echo -e "${YELLOW}SSL 证书: ${SSL_CERT_DIR}/${SSL_CERT_NAME}.*${NC}"
  echo ""
  echo -e "${CYAN}提示:${NC} 确保后端服务（3002 端口）正在运行"
  echo -e "${CYAN}访问地址: ${BLUE}https://api.site-dashboard.zhifu.tech/api/health${NC}（根据配置的域名）"
}

# 启动 Nginx
cmd_start_nginx() {
  echo -e "${GREEN}检查并启动 Nginx...${NC}"
  
  start_nginx_service "ssh_exec" "$SSH_TARGET"

  echo ""
  print_success "Nginx 服务已就绪"
}

# ============================================
# 数据同步功能（双向同步）
# ============================================

# 检测 Git 变更的文件
# 参数：data_dir - 数据目录路径
# 返回：通过全局变量返回变更文件列表
detect_git_changes() {
  local data_dir="$1"
  GIT_ADDED_FILES=""
  GIT_MODIFIED_FILES=""
  GIT_DELETED_FILES=""
  GIT_USE_GIT=false
  
  # 检查是否在 Git 仓库中
  if ! git -C "$PROJECT_ROOT" rev-parse --git-dir > /dev/null 2>&1; then
    return 1
  fi
  
  GIT_USE_GIT=true
  
  # 获取相对于项目根目录的 data 目录路径
  local rel_data_dir=$(cd "$PROJECT_ROOT" && realpath --relative-to="$PROJECT_ROOT" "$data_dir" 2>/dev/null || echo "data")
  
  # 检测所有变更的文件（包括工作区和暂存区）
  cd "$PROJECT_ROOT" || return 1
  while IFS= read -r line; do
    if [ -z "$line" ]; then
      continue
    fi
    
    local status="${line:0:2}"
    local file="${line:3}"
    
    # 只处理 data 目录下的 yml 文件
    if [[ "$file" != ${rel_data_dir}/site-*.yml ]]; then
      continue
    fi
    
    local full_path="$PROJECT_ROOT/$file"
    
    case "$status" in
      "??")
        # 未跟踪的文件（新增）
        if [ -f "$full_path" ]; then
          GIT_ADDED_FILES="${GIT_ADDED_FILES}${full_path}"$'\n'
        fi
        ;;
      " M"|"M "|"MM")
        # 已修改的文件
        if [ -f "$full_path" ]; then
          GIT_MODIFIED_FILES="${GIT_MODIFIED_FILES}${full_path}"$'\n'
        fi
        ;;
      "A "|"AM")
        # 已添加到暂存区的文件（新增或修改）
        if [ -f "$full_path" ]; then
          # 检查是否是新文件
          if git -C "$PROJECT_ROOT" ls-files --error-unmatch "$file" > /dev/null 2>&1; then
            GIT_MODIFIED_FILES="${GIT_MODIFIED_FILES}${full_path}"$'\n'
          else
            GIT_ADDED_FILES="${GIT_ADDED_FILES}${full_path}"$'\n'
          fi
        fi
        ;;
      " D"|"D "|"DD")
        # 已删除的文件
        GIT_DELETED_FILES="${GIT_DELETED_FILES}${file}"$'\n'
        ;;
    esac
  done < <(git -C "$PROJECT_ROOT" status --porcelain "$rel_data_dir/site-*.yml" 2>/dev/null)
  
  # 清理换行符
  GIT_ADDED_FILES=$(echo "$GIT_ADDED_FILES" | grep -v '^$')
  GIT_MODIFIED_FILES=$(echo "$GIT_MODIFIED_FILES" | grep -v '^$')
  GIT_DELETED_FILES=$(echo "$GIT_DELETED_FILES" | grep -v '^$')
  
  return 0
}

# 数据同步主函数
cmd_sync_data() {
  local direction="${1:-help}"
  local force_flag=false
  
  # 解析参数，支持 --force 或 -f
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --force|-f)
        force_flag=true
        shift
        ;;
      *)
        print_error "未知参数: $1"
        echo ""
        echo "使用 'sync-data help' 查看帮助"
        exit 1
        ;;
    esac
  done
  
  case "$direction" in
    up|to-server)
      cmd_sync_data_to_server "$force_flag"
      ;;
    down|from-server)
      cmd_sync_data_from_server
      ;;
    help|--help|-h|"")
      echo -e "${CYAN}数据同步 - 使用帮助${NC}"
      echo ""
      echo -e "${YELLOW}用法:${NC}"
      echo "  ./scripts/site-dashboard-server.sh sync-data [direction] [options]"
      echo ""
      echo -e "${YELLOW}方向:${NC}"
      echo -e "  ${GREEN}up${NC} 或 ${GREEN}to-server${NC}    将本地数据同步到服务器"
      echo -e "  ${GREEN}down${NC} 或 ${GREEN}from-server${NC}  将服务器数据同步回本地"
      echo ""
      echo -e "${YELLOW}选项:${NC}"
      echo -e "  ${GREEN}--force${NC} 或 ${GREEN}-f${NC}    强制同步所有文件（忽略 Git 变更检测）"
      echo ""
      echo -e "${YELLOW}示例:${NC}"
      echo "  ./scripts/site-dashboard-server.sh sync-data up"
      echo "  ./scripts/site-dashboard-server.sh sync-data up --force"
      echo "  ./scripts/site-dashboard-server.sh sync-data down"
      echo ""
      echo -e "${CYAN}说明:${NC}"
      echo "  - 默认情况下，只同步 Git 中变更的文件（新增、修改、删除）"
      echo "  - 使用 --force 选项可以强制同步所有文件（适用于首次同步）"
      echo ""
      ;;
    *)
      print_error "未知方向: $direction"
      echo ""
      echo "使用 'sync-data help' 查看帮助"
      exit 1
      ;;
  esac
}

# 同步数据到服务器（本地 → 服务器）
# 参数：force - 是否强制同步所有文件（忽略 Git 变更检测）
cmd_sync_data_to_server() {
  local force="${1:-false}"
  
  echo -e "${GREEN}同步数据到服务器...${NC}"
  if [ "$force" = "true" ]; then
    echo -e "${YELLOW}强制模式：将同步所有文件${NC}"
  fi
  echo ""
  
  DATA_DIR="$PROJECT_ROOT/data"
  
  # 检查本地数据目录
  if [ ! -d "$DATA_DIR" ]; then
    print_error "本地数据目录不存在: $DATA_DIR"
    exit 1
  fi
  
  # 检测 Git 变更（如果不是强制模式）
  local added_count=0
  local modified_count=0
  local deleted_count=0
  local use_git=false
  
  if [ "$force" != "true" ]; then
    echo -e "${YELLOW}检测 Git 变更...${NC}"
    if detect_git_changes "$DATA_DIR"; then
      use_git=true
      # 安全地计算文件数量（处理空字符串和多行情况）
      if [ -z "$GIT_ADDED_FILES" ] || [ "$GIT_ADDED_FILES" = "" ]; then
        added_count=0
      else
        added_count=$(echo "$GIT_ADDED_FILES" | grep -v '^$' | wc -l | tr -d ' \n')
        [ -z "$added_count" ] && added_count=0
      fi
      if [ -z "$GIT_MODIFIED_FILES" ] || [ "$GIT_MODIFIED_FILES" = "" ]; then
        modified_count=0
      else
        modified_count=$(echo "$GIT_MODIFIED_FILES" | grep -v '^$' | wc -l | tr -d ' \n')
        [ -z "$modified_count" ] && modified_count=0
      fi
      if [ -z "$GIT_DELETED_FILES" ] || [ "$GIT_DELETED_FILES" = "" ]; then
        deleted_count=0
      else
        deleted_count=$(echo "$GIT_DELETED_FILES" | grep -v '^$' | wc -l | tr -d ' \n')
        [ -z "$deleted_count" ] && deleted_count=0
      fi
      
      # 确保所有计数都是数字
      added_count=$((added_count + 0))
      modified_count=$((modified_count + 0))
      deleted_count=$((deleted_count + 0))
    
    echo -e "${BLUE}Git 变更统计:${NC}"
    if [ "$added_count" -gt 0 ]; then
      echo -e "  新增文件: ${GREEN}$added_count${NC}"
      echo "$GIT_ADDED_FILES" | while IFS= read -r file; do
        [ -n "$file" ] && echo -e "    ${GREEN}+${NC} $(basename "$file")"
      done
    fi
    if [ "$modified_count" -gt 0 ]; then
      echo -e "  修改文件: ${YELLOW}$modified_count${NC}"
      echo "$GIT_MODIFIED_FILES" | while IFS= read -r file; do
        [ -n "$file" ] && echo -e "    ${YELLOW}~${NC} $(basename "$file")"
      done
    fi
    if [ "$deleted_count" -gt 0 ]; then
      echo -e "  删除文件: ${RED}$deleted_count${NC}"
      echo "$GIT_DELETED_FILES" | while IFS= read -r file; do
        [ -n "$file" ] && echo -e "    ${RED}-${NC} $(basename "$file")"
      done
    fi
    if [ "$added_count" -eq 0 ] && [ "$modified_count" -eq 0 ] && [ "$deleted_count" -eq 0 ]; then
      echo -e "  ${BLUE}无变更（所有文件已提交到 Git）${NC}"
    fi
      echo ""
    else
      print_warning "不在 Git 仓库中，将同步所有文件"
      echo ""
    fi
  else
    echo -e "${BLUE}跳过 Git 变更检测（强制模式）${NC}"
    echo ""
  fi
  
  # 统计本地数据文件
  YML_COUNT=$(find "$DATA_DIR" -name "site-*.yml" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$YML_COUNT" -eq 0 ]; then
    print_warning "未找到数据文件（site-*.yml）"
    echo "数据目录: $DATA_DIR"
    exit 1
  fi
  
  echo -e "${YELLOW}本地数据文件总数: ${YML_COUNT} 个${NC}"
  echo ""
  
  # 确保服务器上的数据目录存在
  echo -e "${YELLOW}准备服务器数据目录...${NC}"
  ssh $SSH_OPTIONS -p ${SERVER_PORT} "$SSH_TARGET" "mkdir -p $APP_DIR/data" || {
    print_error "无法创建服务器数据目录"
    exit 1
  }
  
  # 根据 Git 变更决定同步策略（强制模式时跳过）
  if [ "$force" = "true" ]; then
    # 强制模式：同步所有文件
    echo -e "${YELLOW}同步所有数据文件（强制模式）...${NC}"
    scp $SSH_OPTIONS -P ${SERVER_PORT} "$DATA_DIR"/site-*.yml "$SSH_TARGET:$APP_DIR/data/" || {
      print_error "数据文件同步失败"
      echo ""
      echo "手动同步命令:"
      echo "  scp $SSH_OPTIONS -P ${SERVER_PORT} $DATA_DIR/site-*.yml $SSH_TARGET:$APP_DIR/data/"
      exit 1
    }
  elif [ "$use_git" = true ] && ([ "$added_count" -gt 0 ] || [ "$modified_count" -gt 0 ] || [ "$deleted_count" -gt 0 ]); then
    # 只同步变更的文件
    echo -e "${YELLOW}同步变更的文件...${NC}"
    local sync_count=0
    
    # 同步新增和修改的文件
    for file in $GIT_ADDED_FILES $GIT_MODIFIED_FILES; do
      if [ -n "$file" ] && [ -f "$file" ]; then
        if scp $SSH_OPTIONS -P ${SERVER_PORT} "$file" "$SSH_TARGET:$APP_DIR/data/" 2>/dev/null; then
          sync_count=$((sync_count + 1))
          echo -e "  ${GREEN}✓${NC} $(basename "$file")"
        else
          print_error "同步失败: $(basename "$file")"
        fi
      fi
    done
    
    # 删除服务器上已删除的文件
    if [ "$deleted_count" -gt 0 ]; then
      echo -e "${YELLOW}删除服务器上的文件...${NC}"
      echo "$GIT_DELETED_FILES" | while IFS= read -r git_file; do
        if [ -n "$git_file" ]; then
          local filename=$(basename "$git_file")
          if ssh $SSH_OPTIONS -p ${SERVER_PORT} "$SSH_TARGET" "rm -f $APP_DIR/data/$filename" 2>/dev/null; then
            echo -e "  ${RED}✗${NC} $filename"
          fi
        fi
      done
    fi
    
    echo ""
    print_success "已同步 $sync_count 个变更文件"
  else
    # 同步所有文件（无 Git 或无可检测的变更）
    echo -e "${YELLOW}同步所有数据文件...${NC}"
    scp $SSH_OPTIONS -P ${SERVER_PORT} "$DATA_DIR"/site-*.yml "$SSH_TARGET:$APP_DIR/data/" || {
      print_error "数据文件同步失败"
      echo ""
      echo "手动同步命令:"
      echo "  scp $SSH_OPTIONS -P ${SERVER_PORT} $DATA_DIR/site-*.yml $SSH_TARGET:$APP_DIR/data/"
      exit 1
    }
  fi
  
  # 验证同步结果
  echo -e "${YELLOW}验证同步结果...${NC}"
  REMOTE_COUNT=$(ssh $SSH_OPTIONS -p ${SERVER_PORT} "$SSH_TARGET" "ls -1 $APP_DIR/data/site-*.yml 2>/dev/null | wc -l | tr -d ' '")
  
  echo ""
  echo -e "${YELLOW}同步统计:${NC}"
  echo -e "  本地文件总数: ${GREEN}$YML_COUNT${NC}"
  echo -e "  服务器文件总数: ${GREEN}$REMOTE_COUNT${NC}"
  echo -e "  服务器路径: ${BLUE}$APP_DIR/data${NC}"
  
  if [ "$force" = "true" ]; then
    echo ""
    echo -e "${CYAN}提示:${NC} 已使用强制模式同步所有文件"
  elif [ "$use_git" = true ]; then
    echo ""
    echo -e "${CYAN}提示:${NC} 基于 Git 变更检测，只同步了变更的文件"
    echo -e "${CYAN}如需同步所有文件，请使用 ${YELLOW}--force${CYAN} 选项或先提交所有变更到 Git${NC}"
  fi
  
  print_success "数据同步成功！"
}

# 同步数据回本地（服务器 → 本地，智能合并）
cmd_sync_data_from_server() {
  echo -e "${GREEN}同步数据回本地（智能合并）...${NC}"
  echo ""
  
  DATA_DIR="$PROJECT_ROOT/data"
  
  # 检查服务器数据目录
  echo -e "${YELLOW}检查服务器数据目录...${NC}"
  SERVER_DATA_EXISTS=$(ssh $SSH_OPTIONS -p ${SERVER_PORT} "$SSH_TARGET" "test -d $APP_DIR/data && echo 'yes' || echo 'no'")
  
  if [ "$SERVER_DATA_EXISTS" != "yes" ]; then
    print_error "服务器数据目录不存在: $APP_DIR/data"
    exit 1
  fi
  
  # 统计服务器数据文件
  REMOTE_COUNT=$(ssh $SSH_OPTIONS -p ${SERVER_PORT} "$SSH_TARGET" "ls -1 $APP_DIR/data/site-*.yml 2>/dev/null | wc -l | tr -d ' '")
  
  if [ "$REMOTE_COUNT" -eq 0 ]; then
    print_warning "服务器上未找到数据文件（site-*.yml）"
    echo "服务器路径: $APP_DIR/data"
    exit 1
  fi
  
  echo -e "${YELLOW}服务器数据文件: ${REMOTE_COUNT} 个${NC}"
  echo ""
  
  # 确保本地数据目录存在
  echo -e "${YELLOW}准备本地数据目录...${NC}"
  mkdir -p "$DATA_DIR" || {
    print_error "无法创建本地数据目录"
    exit 1
  }
  
  # 统计本地数据文件
  LOCAL_COUNT=$(find "$DATA_DIR" -name "site-*.yml" 2>/dev/null | wc -l | tr -d ' ')
  echo -e "${YELLOW}本地数据文件: ${LOCAL_COUNT} 个${NC}"
  echo ""
  
  # 创建临时目录用于下载服务器数据
  TEMP_SERVER_DATA=$(mktemp -d)
  echo -e "${YELLOW}下载服务器数据到临时目录...${NC}"
  
  # 下载服务器数据到临时目录
  scp $SSH_OPTIONS -P ${SERVER_PORT} "$SSH_TARGET:$APP_DIR/data/site-*.yml" "$TEMP_SERVER_DATA/" || {
    print_error "下载服务器数据失败"
    rm -rf "$TEMP_SERVER_DATA"
    exit 1
  }
  
  SERVER_DOWNLOADED_COUNT=$(find "$TEMP_SERVER_DATA" -name "site-*.yml" 2>/dev/null | wc -l | tr -d ' ')
  echo -e "${GREEN}已下载 $SERVER_DOWNLOADED_COUNT 个服务器文件${NC}"
  echo ""
  
  # 智能合并数据
  echo -e "${YELLOW}合并数据文件...${NC}"
  
  # 统计合并信息
  UPDATED_COUNT=0
  ADDED_COUNT=0
  KEPT_LOCAL_COUNT=0
  
  # 处理服务器上的文件（更新或新增）
  for server_file in "$TEMP_SERVER_DATA"/site-*.yml; do
    if [ ! -f "$server_file" ]; then
      continue
    fi
    
    filename=$(basename "$server_file")
    local_file="$DATA_DIR/$filename"
    
    if [ -f "$local_file" ]; then
      # 文件存在，使用服务器版本（服务器优先）
      cp "$server_file" "$local_file"
      UPDATED_COUNT=$((UPDATED_COUNT + 1))
    else
      # 文件不存在，新增
      cp "$server_file" "$local_file"
      ADDED_COUNT=$((ADDED_COUNT + 1))
    fi
  done
  
  # 保留本地独有的文件（服务器上没有的文件）
  for local_file in "$DATA_DIR"/site-*.yml; do
    if [ ! -f "$local_file" ]; then
      continue
    fi
    
    filename=$(basename "$local_file")
    server_file="$TEMP_SERVER_DATA/$filename"
    
    if [ ! -f "$server_file" ]; then
      # 服务器上没有此文件，保留本地版本
      KEPT_LOCAL_COUNT=$((KEPT_LOCAL_COUNT + 1))
    fi
  done
  
  # 清理临时目录
  rm -rf "$TEMP_SERVER_DATA"
  
  # 删除所有备份目录
  echo -e "${YELLOW}清理备份目录...${NC}"
  BACKUP_DIRS=$(find "$PROJECT_ROOT" -maxdepth 1 -type d -name "data.backup.*" 2>/dev/null)
  if [ -n "$BACKUP_DIRS" ]; then
    echo "$BACKUP_DIRS" | while read -r backup_dir; do
      if [ -d "$backup_dir" ]; then
        rm -rf "$backup_dir"
        echo -e "${BLUE}已删除: $(basename "$backup_dir")${NC}"
      fi
    done
  else
    echo -e "${BLUE}未找到备份目录${NC}"
  fi
  echo ""
  
  # 验证合并结果
  FINAL_COUNT=$(find "$DATA_DIR" -name "site-*.yml" 2>/dev/null | wc -l | tr -d ' ')
  
  print_success "数据合并完成！"
  echo ""
  echo -e "${YELLOW}合并统计:${NC}"
  echo -e "  更新文件: ${GREEN}$UPDATED_COUNT${NC} (服务器版本覆盖本地)"
  echo -e "  新增文件: ${GREEN}$ADDED_COUNT${NC} (服务器新增)"
  echo -e "  保留文件: ${GREEN}$KEPT_LOCAL_COUNT${NC} (本地独有)"
  echo -e "  最终文件数: ${GREEN}$FINAL_COUNT${NC}"
  echo -e "  数据路径: ${BLUE}$DATA_DIR${NC}"
  echo ""
  
  if [ "$FINAL_COUNT" -eq 0 ]; then
    print_warning "合并后没有数据文件，请检查"
    exit 1
  fi
}

# 显示帮助信息
cmd_help() {
  echo "Site Dashboard Server - 统一管理脚本"
  echo ""
  echo "使用方法:"
  echo "  ./scripts/site-dashboard-server.sh [command]"
  echo ""
  echo "可用命令:"
  echo "  dev             启动开发服务器（自动重启）"
  echo "  start           启动生产服务器"
  echo ""
  echo "  Nginx 配置:"
  echo "  update-nginx    更新 Nginx 配置文件到服务器"
  echo "  start-nginx     启动 Nginx 服务"
  echo ""
  echo "  Docker 命令:"
  echo "  docker-build    构建 Docker 镜像"
  echo "  docker-up       启动 Docker 容器"
  echo "  docker-down     停止 Docker 容器"
  echo "  docker-logs     查看 Docker 容器日志"
  echo "  docker-deploy   部署到服务器（Docker 方式）"
  echo ""
  echo "  数据同步:"
  echo "  sync-data up    将本地数据同步到服务器"
  echo "  sync-data down  将服务器数据同步回本地"
  echo ""
  echo "  help            显示帮助信息"
  echo ""
  echo "示例:"
  echo "  ./scripts/site-dashboard-server.sh update-nginx"
  echo "  ./scripts/site-dashboard-server.sh docker-deploy"
  echo ""
}

# ============================================
# 主程序
# ============================================
main() {
  show_welcome "$1"
  COMMAND="${1:-help}"

  case "$COMMAND" in
    dev)
      cmd_dev
      ;;
    start)
      cmd_start
      ;;
    update-nginx)
      cmd_update_nginx "$2"
      ;;
    start-nginx)
      cmd_start_nginx
      ;;
    docker-build)
      cmd_docker_build
      ;;
    docker-up)
      cmd_docker_up
      ;;
    docker-down)
      cmd_docker_down
      ;;
    docker-logs)
      cmd_docker_logs
      ;;
    deploy)
      cmd_deploy
      ;;
    docker-deploy)
      cmd_docker_deploy
      ;;
    sync-data)
      shift  # 移除 'sync-data' 命令
      cmd_sync_data "$@"
      ;;
    help|--help|-h)
      cmd_help
      ;;
    *)
      print_error "未知命令: $COMMAND"
      echo ""
      cmd_help
      exit 1
      ;;
  esac
}

# 执行主函数
main "$@"

