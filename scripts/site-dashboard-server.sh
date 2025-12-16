#!/bin/bash

# ============================================
# Site Dashboard Server - 统一管理脚本
# ============================================
# 整合所有部署和管理功能
# 使用方法: ./scripts/site-dashboard-server.sh [command]
# ============================================

# 严格模式：遇到错误立即退出，使用未定义变量报错，管道中任一命令失败则整个管道失败
set -euo pipefail

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ============================================
# 配置变量
# ============================================

# 服务器配置（导出供共用脚本使用）
export SERVER_HOST="${SERVER_HOST:-8.138.183.116}"
export SERVER_USER="${SERVER_USER:-root}"
export SERVER_PORT="${SERVER_PORT:-22}"
export APP_DIR="${APP_DIR:-/opt/site-dashboard-server}"
export APP_PORT="${APP_PORT:-3002}"

# Docker 配置
readonly DOCKER_IMAGE_NAME="site-dashboard-server"
readonly DOCKER_COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"

# Nginx 配置
readonly NGINX_CONF_PATH="/etc/nginx/conf.d/site-dashboard-server.conf"
readonly SSL_CERT_DIR="/etc/nginx/ssl"

# ============================================
# 辅助函数
# ============================================

# 加载共用脚本库（必须在 trap 之前加载，以便使用 safe_exit）
APP_COMMON_DIR="$(cd "$PROJECT_ROOT/../app-common" && pwd)"
[ -f "$APP_COMMON_DIR/scripts/common-utils.sh" ] && source "$APP_COMMON_DIR/scripts/common-utils.sh"
[ -f "$APP_COMMON_DIR/scripts/ssh-utils.sh" ] && source "$APP_COMMON_DIR/scripts/ssh-utils.sh"

# 设置清理 trap（脚本退出时清理临时文件，必须在加载 common-utils.sh 之后）
trap 'safe_exit $?' EXIT INT TERM

# 自动初始化 SSH 连接（在加载共用脚本后）
init_ssh_connection

# ============================================
# 欢迎界面
# ============================================
show_welcome() {
  echo ""
  echo -e "${CYAN}"
  # 从 welcome.txt 读取欢迎画面
  local welcome_file="$APP_COMMON_DIR/welcome.txt"
  if [ -f "$welcome_file" ]; then
    cat "$welcome_file"
  else
    # 如果文件不存在，使用默认的 ASCII 艺术字
    echo "ZHIFU"
  fi
  echo -e "${NC}"
  echo -e "${CYAN}              Site Dashboard Server - API 服务@Zhifu's Tech${NC}"
  echo ""
  local cmd="${1:-help}"
  echo -e "${YELLOW}版本: 1.0.0${NC}"
  echo -e "${YELLOW}服务器: ${SERVER_HOST:-未配置}${NC}"
  echo -e "${YELLOW}端口: ${APP_PORT:-未配置}${NC}"
  echo -e "${YELLOW}命令: ${cmd}${NC}"
  echo ""
}

# ============================================
# 命令函数
# ============================================

# 本地开发
cmd_dev() {
  print_info "启动开发服务器..."
  cd "$PROJECT_ROOT" || return 1
  npm run dev
}

# 启动服务
cmd_start() {
  print_info "启动服务..."
  cd "$PROJECT_ROOT" || return 1
  npm start
}

# Docker 构建
cmd_docker_build() {
  print_info "构建 Docker 镜像..."
  cd "$PROJECT_ROOT" || return 1
  
  check_file_exists "Dockerfile" "未找到 Dockerfile" || return 1
  
  local build_platform="${BUILD_PLATFORM:-linux/amd64}"
  
  if ! docker build --platform "$build_platform" -t "${DOCKER_IMAGE_NAME}:latest" .; then
    print_error "Docker 镜像构建失败"
    echo ""
    print_warning "可能的解决方案："
    echo "1. 配置 Docker 镜像加速器（推荐）"
    echo "   - macOS: Docker Desktop → Settings → Docker Engine → 添加 registry-mirrors"
    echo "   - Linux: 编辑 /etc/docker/daemon.json 添加 registry-mirrors"
    echo ""
    echo "2. 手动拉取基础镜像："
    echo "   docker pull --platform $build_platform node:18-alpine"
    echo ""
    echo "3. 查看详细错误信息："
    echo "   docker build --platform $build_platform -t $DOCKER_IMAGE_NAME:latest ."
    return 1
  fi
  
  local success_msg="Docker 镜像构建完成（平台: ${build_platform}）"
  print_success "$success_msg"
}

# Docker 启动
cmd_docker_up() {
  print_info "启动 Docker 容器..."
  cd "$PROJECT_ROOT" || return 1
  docker-compose -f "$DOCKER_COMPOSE_FILE" up -d
  print_success "Docker 容器已启动"
  echo ""
  print_info "访问地址: http://localhost:${APP_PORT:-3002}"
}

# Docker 停止
cmd_docker_down() {
  print_info "停止 Docker 容器..."
  cd "$PROJECT_ROOT" || return 1
  docker-compose -f "$DOCKER_COMPOSE_FILE" down
  print_success "Docker 容器已停止"
}

# Docker 日志
cmd_docker_logs() {
  print_info "查看 Docker 容器日志..."
  cd "$PROJECT_ROOT" || return 1
  docker-compose -f "$DOCKER_COMPOSE_FILE" logs -f --tail=100
}

# 部署到服务器
cmd_deploy() {
  print_info "部署到服务器..."
  cd "$PROJECT_ROOT" || return 1

  check_file_exists "package.json" "未找到 package.json，请确保在项目根目录执行" || return 1

  # 创建临时部署目录
  local temp_deploy_dir
  temp_deploy_dir=$(mktemp -d)
  register_cleanup "$temp_deploy_dir"
  print_info "创建临时目录: ${temp_deploy_dir}"

  # 复制文件
  print_info "复制文件..."
  cp -r src "$temp_deploy_dir/"
  cp package.json package-lock.json "$temp_deploy_dir/" 2>/dev/null || true
  cp server.js "$temp_deploy_dir/"
  cp .env "$temp_deploy_dir/" 2>/dev/null || true
  cp example.env "$temp_deploy_dir/" 2>/dev/null || true

  # 上传到服务器
  print_info "上传文件到服务器..."
  ssh $SSH_OPTIONS -p "${SERVER_PORT}" "$SSH_TARGET" "mkdir -p $APP_DIR"
  scp $SSH_OPTIONS -r -P "${SERVER_PORT}" "$temp_deploy_dir"/* "$SSH_TARGET:$APP_DIR/"

  # 在服务器上安装依赖并重启服务
  print_info "在服务器上安装依赖..."
  ssh $SSH_OPTIONS -p "${SERVER_PORT}" "$SSH_TARGET" "cd $APP_DIR && npm ci --only=production"

  print_info "重启服务..."
  ssh $SSH_OPTIONS -p "${SERVER_PORT}" "$SSH_TARGET" "cd $APP_DIR && pm2 restart site-dashboard-server || pm2 start server.js --name site-dashboard-server"

  print_success "部署完成"
}

# Docker 部署
cmd_docker_deploy() {
  print_info "Docker 部署到服务器..."
  cd "$PROJECT_ROOT" || return 1

  # 构建镜像
  if ! cmd_docker_build; then
    return 1
  fi

  # 保存镜像
  print_info "保存 Docker 镜像..."
  local temp_image_file="/tmp/site-dashboard-server.tar.gz"
  register_cleanup "$temp_image_file"
  
  if ! docker save "${DOCKER_IMAGE_NAME}:latest" | gzip > "$temp_image_file"; then
    print_error "镜像保存失败"
    return 1
  fi

  # 上传镜像
  print_info "上传镜像到服务器..."
  local remote_image_file="/tmp/site-dashboard-server.tar.gz"
  if ! scp $SSH_OPTIONS -P "${SERVER_PORT}" "$temp_image_file" "${SSH_TARGET}:${remote_image_file}"; then
    print_error "镜像上传失败"
    return 1
  fi

  # 在服务器上加载镜像并运行
  print_info "在服务器上加载镜像..."
  ssh $SSH_OPTIONS -p "${SERVER_PORT}" "$SSH_TARGET" "docker load < ${remote_image_file}"

  print_info "运行容器..."
  ssh $SSH_OPTIONS -p "${SERVER_PORT}" "$SSH_TARGET" "docker stop ${DOCKER_IMAGE_NAME} 2>/dev/null || true"
  ssh $SSH_OPTIONS -p "${SERVER_PORT}" "$SSH_TARGET" "docker rm ${DOCKER_IMAGE_NAME} 2>/dev/null || true"
  
  # 检查服务器上是否有 SSL 证书
  local ssl_key_path="/etc/nginx/ssl/site-dashboard-server.key"
  local ssl_cert_path="/etc/nginx/ssl/site-dashboard-server.crt"
  local has_ssl
  has_ssl=$(ssh $SSH_OPTIONS -p "${SERVER_PORT}" "$SSH_TARGET" "test -f $ssl_key_path && test -f $ssl_cert_path && echo 'yes' || echo 'no'")
  
  # 构建 Docker 运行命令
  local docker_cmd="docker run -d --platform linux/amd64 --name ${DOCKER_IMAGE_NAME} -p 127.0.0.1:${APP_PORT:-3002}:3002 -v ${APP_DIR}/data:/app/data --restart unless-stopped"
  
  # 如果存在 SSL 证书，挂载并启用 HTTPS
  if [ "$has_ssl" = "yes" ]; then
    print_info "检测到 SSL 证书，启用 HTTPS 模式"
    docker_cmd="$docker_cmd -v $ssl_key_path:/app/ssl/server.key:ro -v $ssl_cert_path:/app/ssl/server.crt:ro -e HTTPS_ENABLED=true -e SSL_KEY_PATH=/app/ssl/server.key -e SSL_CERT_PATH=/app/ssl/server.crt"
  else
    print_warning "未检测到 SSL 证书，使用 HTTP 模式"
    print_info "提示：如需启用 HTTPS，请将 SSL 证书放置在服务器上的以下路径："
    echo "  私钥: $ssl_key_path"
    echo "  证书: $ssl_cert_path"
  fi
  
  docker_cmd="$docker_cmd ${DOCKER_IMAGE_NAME}:latest"
  
  ssh $SSH_OPTIONS -p "${SERVER_PORT}" "$SSH_TARGET" "$docker_cmd"

  # 清理服务器上的临时文件
  ssh $SSH_OPTIONS -p "${SERVER_PORT}" "$SSH_TARGET" "rm -f ${remote_image_file}"
  
  echo ""
  print_success "Docker 部署完成"
  echo ""
  print_info "容器信息："
  echo "  容器名称: ${DOCKER_IMAGE_NAME}"
  echo "  端口映射: 127.0.0.1:${APP_PORT:-3002}:3002"
  echo "  平台: linux/amd64"
  echo ""
  print_info "访问地址："
  echo "  本地访问: http://127.0.0.1:${APP_PORT:-3002}/api/health"
  echo "  外部访问: http://${SERVER_HOST}:${APP_PORT:-3002}/api/health"
  echo ""
  print_info "提示：如果使用 Nginx 反向代理，请运行："
  echo "  ./scripts/site-dashboard-server.sh update-nginx"
}

# ============================================
# SSH 配置管理
# ============================================

# 更新 SSH 公钥到服务器
cmd_update_ssh_key() {
  print_info "更新 SSH 公钥到服务器 ${SERVER_HOST}..."
  echo ""
  
  if ! update_ssh_key_to_server; then
    print_error "SSH 公钥更新失败"
    return 1
  fi
  
  echo ""
  print_success "SSH 登录认证信息已更新！"
  print_info "现在可以使用 SSH 密钥无密码登录服务器"
}

# ============================================
# Nginx 配置管理
# ============================================

# 加载 Nginx 共用脚本库（SSH 脚本已在上面加载）
[ -f "$APP_COMMON_DIR/scripts/nginx-utils.sh" ] && source "$APP_COMMON_DIR/scripts/nginx-utils.sh"
[ -f "$APP_COMMON_DIR/scripts/nginx-update.sh" ] && source "$APP_COMMON_DIR/scripts/nginx-update.sh"

# 更新 Nginx 配置
cmd_update_nginx() {
  # 确定配置文件路径
  local nginx_local_conf="${1:-$SCRIPT_DIR/site-dashboard-server.nginx.conf}"
  if ! check_file_exists "$nginx_local_conf" "配置文件不存在"; then
    echo ""
    echo "可用的配置文件："
    ls -1 "$SCRIPT_DIR"/*.nginx*.conf 2>/dev/null || echo "  无"
    return 1
  fi

  print_info "更新 Nginx 配置到服务器 ${SERVER_HOST}..."
  echo ""

  # 检查 SSL 证书目录
  local ssl_cert_name="api.site-dashboard.zhifu.tech"
  local ssl_cert_local_dir="$APP_COMMON_DIR/ssl/${ssl_cert_name}_nginx"
  local ssl_cert_key="$ssl_cert_local_dir/${ssl_cert_name}.key"
  local ssl_cert_bundle_crt="$ssl_cert_local_dir/${ssl_cert_name}_bundle.crt"
  local ssl_cert_bundle_pem="$ssl_cert_local_dir/${ssl_cert_name}_bundle.pem"
  
  local ssl_cert_files_exist=false
  if [ -f "$ssl_cert_key" ] && ([ -f "$ssl_cert_bundle_crt" ] || [ -f "$ssl_cert_bundle_pem" ]); then
    ssl_cert_files_exist=true
  fi

  # 使用共用脚本库更新配置（包含 SSL 证书）
  if [ "$ssl_cert_files_exist" = "true" ]; then
    update_nginx_config \
      "$nginx_local_conf" \
      "$NGINX_CONF_PATH" \
      "$SSH_OPTIONS" \
      "$SERVER_PORT" \
      "$SSH_TARGET" \
      "ssh_exec" \
      "$ssl_cert_name" \
      "$ssl_cert_local_dir" \
      "$SSL_CERT_DIR"
  else
    # 不使用 SSL 证书的简化版本
    prepare_nginx_server "$NGINX_CONF_PATH" "ssh_exec" "$SSH_TARGET"
    print_info "上传配置文件..."
    scp $SSH_OPTIONS -P "${SERVER_PORT}" "$nginx_local_conf" "${SSH_TARGET}:${NGINX_CONF_PATH}"
    test_and_reload_nginx "$NGINX_CONF_PATH" "ssh_exec" "$SSH_TARGET"
  fi

  echo ""
  print_success "Nginx 配置更新完成！"
  print_info "配置文件: ${NGINX_CONF_PATH}"
  [ "$ssl_cert_files_exist" = "true" ] && print_info "SSL 证书: ${SSL_CERT_DIR}/${ssl_cert_name}.*"
  echo ""
  print_info "提示: 确保后端服务（3002 端口）正在运行"
  print_info "访问地址: https://api.site-dashboard.zhifu.tech/api/health（根据配置的域名）"
}

# 启动 Nginx
cmd_start_nginx() {
  print_info "检查并启动 Nginx..."
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
    
    # 处理 data 目录下的文件（所有文件类型）
    if [[ "$file" != ${rel_data_dir}/* ]]; then
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
  done < <(git -C "$PROJECT_ROOT" status --porcelain "$rel_data_dir" 2>/dev/null)
  
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
      echo "  - 同步 data/ 目录下的所有文件（包括 .yml、.mdc 等所有类型）"
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
  
  # 统计本地数据文件（所有文件）
  local file_count
  file_count=$(find "$DATA_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "$file_count" -eq 0 ]; then
    print_warning "数据目录为空: $DATA_DIR"
    echo "数据目录: $DATA_DIR"
    exit 1
  fi
  
  echo -e "${YELLOW}本地数据文件总数: ${file_count} 个${NC}"
  echo ""
  
  # 确保服务器上的数据目录存在
  print_info "准备服务器数据目录..."
  if ! ssh $SSH_OPTIONS -p "${SERVER_PORT}" "$SSH_TARGET" "mkdir -p $APP_DIR/data"; then
    print_error "无法创建服务器数据目录"
    return 1
  fi
  
  # 根据 Git 变更决定同步策略（强制模式时跳过）
  if [ "$force" = "true" ]; then
    # 强制模式：同步所有文件
    print_info "同步所有数据文件（强制模式）..."
    local sync_count=0
    while IFS= read -r file; do
      if [ -f "$file" ]; then
        if scp $SSH_OPTIONS -P "${SERVER_PORT}" "$file" "$SSH_TARGET:$APP_DIR/data/" 2>/dev/null; then
          sync_count=$((sync_count + 1))
          print_success "$(basename "$file")"
        else
          print_error "同步失败: $(basename "$file")"
        fi
      fi
    done < <(find "$DATA_DIR" -type f)
    
    if [ "$sync_count" -eq 0 ]; then
      print_error "数据文件同步失败"
      return 1
    fi
  elif [ "$use_git" = "true" ] && ([ "$added_count" -gt 0 ] || [ "$modified_count" -gt 0 ] || [ "$deleted_count" -gt 0 ]); then
    # 只同步变更的文件
    print_info "同步变更的文件..."
    local sync_count=0
    
    # 同步新增和修改的文件
    for file in $GIT_ADDED_FILES $GIT_MODIFIED_FILES; do
      if [ -n "$file" ] && [ -f "$file" ]; then
        if scp $SSH_OPTIONS -P "${SERVER_PORT}" "$file" "$SSH_TARGET:$APP_DIR/data/" 2>/dev/null; then
          sync_count=$((sync_count + 1))
          print_success "$(basename "$file")"
        else
          print_error "同步失败: $(basename "$file")"
        fi
      fi
    done
    
    # 删除服务器上已删除的文件
    if [ "$deleted_count" -gt 0 ]; then
      print_info "删除服务器上的文件..."
      echo "$GIT_DELETED_FILES" | while IFS= read -r git_file; do
        if [ -n "$git_file" ]; then
          local filename
          filename=$(basename "$git_file")
          if ssh $SSH_OPTIONS -p "${SERVER_PORT}" "$SSH_TARGET" "rm -f $APP_DIR/data/$filename" 2>/dev/null; then
            print_error "$filename (已删除)"
          fi
        fi
      done
    fi
    
    echo ""
    print_success "已同步 $sync_count 个变更文件"
  else
    # 同步所有文件（无 Git 或无可检测的变更）
    print_info "同步所有数据文件..."
    local sync_count=0
    while IFS= read -r file; do
      if [ -f "$file" ]; then
        if scp $SSH_OPTIONS -P "${SERVER_PORT}" "$file" "$SSH_TARGET:$APP_DIR/data/" 2>/dev/null; then
          sync_count=$((sync_count + 1))
          print_success "$(basename "$file")"
        else
          print_error "同步失败: $(basename "$file")"
        fi
      fi
    done < <(find "$DATA_DIR" -type f)
    
    if [ "$sync_count" -eq 0 ]; then
      print_error "数据文件同步失败"
      return 1
    fi
  fi
  
  # 验证同步结果
  print_info "验证同步结果..."
  local remote_count
  remote_count=$(ssh $SSH_OPTIONS -p "${SERVER_PORT}" "$SSH_TARGET" "find $APP_DIR/data -type f 2>/dev/null | wc -l | tr -d ' '")
  
  echo ""
  print_info "同步统计:"
  echo "  本地文件总数: $file_count"
  echo "  服务器文件总数: $remote_count"
  echo "  服务器路径: $APP_DIR/data"
  
  if [ "$force" = "true" ]; then
    echo ""
    print_info "提示: 已使用强制模式同步所有文件"
  elif [ "$use_git" = "true" ]; then
    echo ""
    print_info "提示: 基于 Git 变更检测，只同步了变更的文件"
    print_info "如需同步所有文件，请使用 --force 选项或先提交所有变更到 Git"
  fi
  
  print_success "数据同步成功！"
}

# 同步数据回本地（服务器 → 本地，智能合并）
cmd_sync_data_from_server() {
  print_info "同步数据回本地（智能合并）..."
  echo ""
  
  local data_dir="$PROJECT_ROOT/data"
  
  # 检查服务器数据目录
  print_info "检查服务器数据目录..."
  local server_data_exists
  server_data_exists=$(ssh $SSH_OPTIONS -p "${SERVER_PORT}" "$SSH_TARGET" "test -d $APP_DIR/data && echo 'yes' || echo 'no'")
  
  if [ "$server_data_exists" != "yes" ]; then
    print_error "服务器数据目录不存在: $APP_DIR/data"
    return 1
  fi
  
  # 统计服务器数据文件（所有文件）
  local remote_count
  remote_count=$(ssh $SSH_OPTIONS -p "${SERVER_PORT}" "$SSH_TARGET" "find $APP_DIR/data -type f 2>/dev/null | wc -l | tr -d ' '")
  
  if [ "$remote_count" -eq 0 ]; then
    print_warning "服务器上未找到数据文件"
    echo "服务器路径: $APP_DIR/data"
    return 1
  fi
  
  print_info "服务器数据文件: ${remote_count} 个"
  echo ""
  
  # 确保本地数据目录存在
  print_info "准备本地数据目录..."
  if ! mkdir -p "$data_dir"; then
    print_error "无法创建本地数据目录"
    return 1
  fi
  
  # 统计本地数据文件（所有文件）
  local local_count
  local_count=$(find "$data_dir" -type f 2>/dev/null | wc -l | tr -d ' ')
  print_info "本地数据文件: ${local_count} 个"
  echo ""
  
  # 创建临时目录用于下载服务器数据
  local temp_server_data
  temp_server_data=$(mktemp -d)
  register_cleanup "$temp_server_data"
  print_info "下载服务器数据到临时目录..."
  
  # 下载服务器数据到临时目录（所有文件）
  # 先获取服务器上的文件列表，然后逐个下载
  local remote_files
  remote_files=$(ssh $SSH_OPTIONS -p "${SERVER_PORT}" "$SSH_TARGET" "find $APP_DIR/data -type f" 2>/dev/null)
  
  if [ -z "$remote_files" ]; then
    print_warning "服务器上未找到文件"
    return 1
  fi
  
  echo "$remote_files" | while IFS= read -r remote_file; do
    if [ -n "$remote_file" ]; then
      local filename
      filename=$(basename "$remote_file")
      scp $SSH_OPTIONS -P "${SERVER_PORT}" "$SSH_TARGET:$remote_file" "$temp_server_data/" 2>/dev/null || true
    fi
  done
  
  local server_downloaded_count
  server_downloaded_count=$(find "$temp_server_data" -type f 2>/dev/null | wc -l | tr -d ' ')
  print_success "已下载 $server_downloaded_count 个服务器文件"
  echo ""
  
  # 智能合并数据
  print_info "合并数据文件..."
  
  # 统计合并信息
  local updated_count=0
  local added_count=0
  local kept_local_count=0
  
  # 处理服务器上的文件（更新或新增）- 所有文件类型
  while IFS= read -r server_file; do
    [ ! -f "$server_file" ] && continue
    
    local filename
    filename=$(basename "$server_file")
    local local_file="$data_dir/$filename"
    
    if [ -f "$local_file" ]; then
      # 文件存在，使用服务器版本（服务器优先）
      cp "$server_file" "$local_file"
      updated_count=$((updated_count + 1))
    else
      # 文件不存在，新增
      cp "$server_file" "$local_file"
      added_count=$((added_count + 1))
    fi
  done < <(find "$temp_server_data" -type f)
  
  # 保留本地独有的文件（服务器上没有的文件）- 所有文件类型
  while IFS= read -r local_file; do
    [ ! -f "$local_file" ] && continue
    
    local filename
    filename=$(basename "$local_file")
    local server_file="$temp_server_data/$filename"
    
    if [ ! -f "$server_file" ]; then
      # 服务器上没有此文件，保留本地版本
      kept_local_count=$((kept_local_count + 1))
    fi
  done < <(find "$data_dir" -type f)
  
  # 删除所有备份目录
  print_info "清理备份目录..."
  local backup_dirs
  backup_dirs=$(find "$PROJECT_ROOT" -maxdepth 1 -type d -name "data.backup.*" 2>/dev/null)
  if [ -n "$backup_dirs" ]; then
    echo "$backup_dirs" | while IFS= read -r backup_dir; do
      [ -d "$backup_dir" ] && rm -rf "$backup_dir" && print_info "已删除: $(basename "$backup_dir")"
    done
  else
    print_info "未找到备份目录"
  fi
  echo ""
  
  # 验证合并结果（所有文件）
  local final_count
  final_count=$(find "$data_dir" -type f 2>/dev/null | wc -l | tr -d ' ')
  
  print_success "数据合并完成！"
  echo ""
  print_info "合并统计:"
  echo "  更新文件: $updated_count (服务器版本覆盖本地)"
  echo "  新增文件: $added_count (服务器新增)"
  echo "  保留文件: $kept_local_count (本地独有)"
  echo "  最终文件数: $final_count"
  echo "  数据路径: $data_dir"
  echo ""
  
  if [ "$final_count" -eq 0 ]; then
    print_warning "合并后没有数据文件，请检查"
    return 1
  fi
}

# 显示帮助信息
cmd_help() {
  echo -e "${CYAN}Site Dashboard Server - 使用帮助${NC}"
  echo ""
  echo -e "${YELLOW}用法:${NC}"
  echo "  ./scripts/site-dashboard-server.sh [command]"
  echo ""
  echo -e "${YELLOW}可用命令:${NC}"
  echo ""
  echo -e "  ${GREEN}开发命令:${NC}"
  echo -e "  ${GREEN}dev${NC}             启动开发服务器（自动重启）"
  echo -e "  ${GREEN}start${NC}           启动生产服务器"
  echo ""
  echo -e "  ${GREEN}SSH 配置:${NC}"
  echo -e "  ${GREEN}update-ssh-key${NC}  更新 SSH 公钥到服务器"
  echo ""
  echo -e "  ${GREEN}Nginx 配置:${NC}"
  echo -e "  ${GREEN}update-nginx${NC}    更新 Nginx 配置文件到服务器"
  echo -e "  ${GREEN}start-nginx${NC}     启动 Nginx 服务"
  echo ""
  echo -e "  ${GREEN}Docker 命令:${NC}"
  echo -e "  ${GREEN}docker-build${NC}    构建 Docker 镜像"
  echo -e "  ${GREEN}docker-up${NC}       启动 Docker 容器"
  echo -e "  ${GREEN}docker-down${NC}     停止 Docker 容器"
  echo -e "  ${GREEN}docker-logs${NC}     查看 Docker 容器日志"
  echo -e "  ${GREEN}docker-deploy${NC}   部署到服务器（Docker 方式）"
  echo ""
  echo -e "  ${GREEN}数据同步:${NC}"
  echo -e "  ${GREEN}sync-data up${NC}    将本地数据同步到服务器"
  echo -e "  ${GREEN}sync-data down${NC}  将服务器数据同步回本地"
  echo ""
  echo -e "  ${GREEN}help${NC}            显示此帮助信息"
  echo ""
  echo -e "${YELLOW}示例:${NC}"
  echo "  ./scripts/site-dashboard-server.sh update-ssh-key"
  echo "  ./scripts/site-dashboard-server.sh update-nginx"
  echo "  ./scripts/site-dashboard-server.sh docker-deploy"
  echo ""
}

# ============================================
# 主程序
# ============================================
main() {
  show_welcome "${1:-}"
  COMMAND="${1:-help}"

  case "$COMMAND" in
    dev)
      cmd_dev
      ;;
    start)
      cmd_start
      ;;
    update-ssh-key)
      cmd_update_ssh_key
      ;;
    update-nginx)
      cmd_update_nginx "${2:-}"
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

