#!/bin/bash
# ============================================================
#  Forum 一键安装脚本
#  支持 Java(Spring Boot) / Rust(Axum) 双引擎可选
#  支持编译安装(源码) 或 快捷安装(预编译二进制)
# ============================================================
set -euo pipefail

# ---------- 颜色 ----------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ---------- 常量 ----------
DEFAULT_DIR="/opt/forum"
SCRIPT_VER="1.1.0"
GITHUB_REPO="bairm101/StarXForum"
GITHUB_BRANCH="main"

# 下载源（运行时自动检测）
CN_BASE="https://res.starxx.cn/forumres"
GH_BASE="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}"
DOWNLOAD_BASE=""

# ---------- 用户可覆盖的变量（环境变量方式） ----------
INSTALL_DIR="${FORUM_DIR:-$DEFAULT_DIR}"
BACKEND_TYPE=""        # java | rust
INSTALL_MODE=""        # source | binary
SERVER_PORT="8080"
DB_HOST="127.0.0.1"
DB_PORT="3306"
DB_NAME="luntan"
DB_USERNAME="luntan"
DB_PASSWORD=""
REDIS_HOST="127.0.0.1"
REDIS_PORT="6379"
REDIS_PASSWORD=""
JWT_SECRET=""
JWT_EXPIRATION="604800"
UPLOAD_DIR=""
CORS_ORIGINS="*"
ADMIN_USER=""
ADMIN_PASS=""

# ---------- 工具函数 ----------
banner() {
    echo -e "${CYAN}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║       Forum Server 一键安装 v${SCRIPT_VER}      ║"
    echo "  ║   Java Spring Boot / Rust Axum 双引擎     ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${NC}"
}

info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
step()    { echo -e "\n${BOLD}${BLUE}━━ $* ━━${NC}\n"; }

ask() {
    local prompt="$1" var="$2" default="${3:-}"
    read -p "$(echo -e "${CYAN}$prompt${NC}${default:+ [${default}]}: ")" input
    eval "$var=\"\${input:-$default}\""
}

ask_secret() {
    local prompt="$1" var="$2"
    read -sp "$(echo -e "${CYAN}$prompt${NC}: ")" input
    echo ""
    eval "$var=\"\$input\""
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "请以 root 身份运行此脚本：sudo bash $0"
    fi
}

check_deps() {
    for cmd in curl wget tar gzip unzip; do
        if ! command -v "$cmd" &>/dev/null; then
            warn "安装缺失工具: $cmd"
            apt-get update -qq && apt-get install -y -qq "$cmd" || {
                yum install -y "$cmd" || error "无法安装 $cmd，请手动安装后重试"
            }
        fi
    done
}

# ---------- 自动检测下载源 ----------
detect_download_source() {
    step "检测最佳下载源..."

    # 测试国内源（超时 3 秒）
    local cn_code
    cn_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout 3 --max-time 5 \
        "${CN_BASE}/schema.sql" 2>/dev/null) || cn_code="000"

    if [[ "$cn_code" == "200" ]]; then
        DOWNLOAD_BASE="$CN_BASE"
        info "使用国内镜像: ${CN_BASE}"
        return
    fi

    # 国内不可达，尝试 GitHub
    local gh_code
    gh_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout 5 --max-time 10 \
        "${GH_BASE}/schema.sql" 2>/dev/null) || gh_code="000"

    if [[ "$gh_code" == "200" ]]; then
        DOWNLOAD_BASE="$GH_BASE"
        info "使用 GitHub Releases: ${GH_BASE}"
        return
    fi

    # 都不通，默认用国内源（用户可能后续配置代理）
    DOWNLOAD_BASE="$CN_BASE"
    warn "无法自动检测下载源，默认使用国内源"
    warn "如果下载失败请检查网络或设置代理"
}

# 统一下载函数
dl() {
    local remote="$1" local_file="$2"
    wget -q --show-progress "${DOWNLOAD_BASE}/${remote}" -O "$local_file"
}

generate_jwt_secret() {
    # 生成 64 字符随机密钥
    head -c 48 /dev/urandom | base64 | tr -d '\n' | tr '+/' '-_' | head -c 64
}

# ============================================================
# 交互式配置收集
# ============================================================
collect_config() {
    step "基本配置"

    echo -e "${BOLD}选择后端引擎:${NC}"
    echo -e "  ${GREEN}1) Java (Spring Boot)${NC}"
    echo -e "     • 成熟稳定、生态丰富"
    echo -e "     • 内存占用较高 (~500MB)"
    echo -e "     • 启动时间 ~10 秒"
    echo -e "     • 需要安装 JDK 17 + Maven"
    echo -e "  ${GREEN}2) Rust (Axum)${NC}"
    echo -e "     • 极致性能、内存占用极低 (~8MB)"
    echo -e "     • 启动时间 <100ms"
    echo -e "     • 编译需要 Rust 工具链 (~5 分钟)"
    echo -e "     • 单二进制文件，部署最简单"
    echo ""
    while true; do
        read -p "$(echo -e "${CYAN}请选择 [1/2]:${NC} ")" choice
        case $choice in
            1) BACKEND_TYPE="java"; break ;;
            2) BACKEND_TYPE="rust"; break ;;
            *) warn "请输入 1 或 2" ;;
        esac
    done

    echo ""
    echo -e "${BOLD}选择安装方式:${NC}"
    echo -e "  ${GREEN}1) 快捷安装${NC} — 下载预编译文件直接运行（推荐）"
    echo -e "     • 最快，~30 秒完成"
    echo -e "  ${GREEN}2) 编译安装${NC} — 下载源码在本地编译"
    echo -e "     • Java: mvn package (~3 分钟)"
    echo -e "     • Rust: cargo build (~15 分钟首次)"
    echo ""
    while true; do
        read -p "$(echo -e "${CYAN}请选择 [1/2]:${NC} ")" choice
        case $choice in
            1) INSTALL_MODE="binary"; break ;;
            2) INSTALL_MODE="source"; break ;;
            *) warn "请输入 1 或 2" ;;
        esac
    done

    echo ""
    ask "服务端监听端口" SERVER_PORT "8080"
    ask "安装目录" INSTALL_DIR "$DEFAULT_DIR"

    step "数据库配置（MySQL）"
    warn "请确保 MySQL 已安装且正在运行"
    ask "MySQL 地址" DB_HOST "127.0.0.1"
    ask "MySQL 端口" DB_PORT "3306"
    ask "数据库名" DB_NAME "luntan"
    ask "数据库用户名" DB_USERNAME "luntan"
    ask_secret "数据库密码" DB_PASSWORD

    step "Redis 配置"
    ask "Redis 地址" REDIS_HOST "127.0.0.1"
    ask "Redis 端口" REDIS_PORT "6379"
    ask_secret "Redis 密码（无密码留空）" REDIS_PASSWORD

    step "安全配置"
    JWT_SECRET=$(generate_jwt_secret)
    info "JWT 密钥已自动生成（64 字符随机）"

    step "CORS 跨域配置"
    echo -e "  CORS 控制哪些网站可以调用你的 API。"
    echo -e "  如果没有域名、只用 IP+端口访问 → 直接回车用 * 即可。"
    echo -e "  有域名时填你的前端域名，例如:"
    echo -e "    https://forum.starxx.cn,http://192.168.1.100:8080"
    ask "允许的来源（* = 允许所有，推荐新手）" CORS_ORIGINS "*"

    step "初始管理员账户"
    ask "管理员用户名" ADMIN_USER "admin"
    while true; do
        ask_secret "管理员密码（至少 8 位）" ADMIN_PASS
        if [[ ${#ADMIN_PASS} -ge 8 ]]; then break; fi
        warn "密码长度不足 8 位，请重新输入"
    done

    UPLOAD_DIR="${INSTALL_DIR}/uploads"

    # 数据库初始化选项
    echo ""
    echo -e "${BOLD}数据库初始化:${NC}"
    echo -e "  1) 自动创建 — 脚本连接 MySQL 创建库+用户+导入表结构"
    echo -e "     （需要提供 MySQL root 密码）"
    echo -e "  2) 手动创建 — 你已自行创建好数据库和用户"
    echo ""
    while true; do
        read -p "$(echo -e "${CYAN}请选择 [1/2]:${NC} ")" db_init_choice
        case $db_init_choice in
            1) DB_AUTO_INIT="yes"; ask_secret "MySQL root 密码" DB_ROOT_PASS; break ;;
            2) DB_AUTO_INIT="no"; break ;;
            *) warn "请输入 1 或 2" ;;
        esac
    done

    # 确认
    echo ""
    echo -e "${BOLD}${CYAN}━━ 配置确认 ━━${NC}"
    echo "  引擎:       $BACKEND_TYPE"
    echo "  安装方式:   $INSTALL_MODE"
    echo "  安装目录:   $INSTALL_DIR"
    echo "  端口:       $SERVER_PORT"
    echo "  数据库:     $DB_USERNAME@${DB_HOST}:${DB_PORT}/${DB_NAME}"
    echo "  Redis:      ${REDIS_HOST}:${REDIS_PORT}"
    echo "  上传目录:   $UPLOAD_DIR"
    echo "  CORS:       $CORS_ORIGINS"
    echo ""
    read -p "$(echo -e "${YELLOW}确认以上配置并开始安装? [y/N]:${NC} ")" confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { warn "已取消安装"; exit 0; }
}

# ============================================================
# 数据库初始化（建库 + 建用户 + 导入表结构）
# ============================================================
init_database() {
    if [[ "$DB_AUTO_INIT" != "yes" ]]; then
        info "跳过数据库自动创建（用户选择手动创建）"
        if ! mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USERNAME" -p"$DB_PASSWORD" -e "SELECT 1" &>/dev/null; then
            error "无法连接 MySQL，请检查配置"
        fi
        info "MySQL 连接验证通过"
        return
    fi

    info "创建数据库和用户..."
    mysql -h"$DB_HOST" -P"$DB_PORT" -u root -p"$DB_ROOT_PASS" \
        -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'127.0.0.1' IDENTIFIED BY '${DB_PASSWORD}'; GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USERNAME}'@'127.0.0.1'; FLUSH PRIVILEGES;" 2>/dev/null \
    || mysql -h"$DB_HOST" -P"$DB_PORT" -u root \
        -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'127.0.0.1' IDENTIFIED BY '${DB_PASSWORD}'; GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USERNAME}'@'127.0.0.1'; FLUSH PRIVILEGES;" 2>/dev/null \
    || error "无法连接 MySQL，请检查 root 密码"

    info "下载并导入表结构..."
    local schema_file="/tmp/forum_schema.sql"
    wget -q "${DOWNLOAD_BASE}/schema.sql" -O "$schema_file" || error "表结构文件下载失败"

    mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USERNAME" -p"$DB_PASSWORD" "$DB_NAME" < "$schema_file"
    rm -f "$schema_file"

    local table_count
    table_count=$(mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USERNAME" -p"$DB_PASSWORD" "$DB_NAME" \
        -Nse "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='${DB_NAME}'")
    info "数据库初始化完成，共 ${table_count} 张表"
}

# ============================================================
# 写入 .env 配置文件
# ============================================================
write_env() {
    cat > "${INSTALL_DIR}/.env" << ENVEOF
# Forum Server 运行时配置 — 自动生成
SERVER_HOST=127.0.0.1
SERVER_PORT=${SERVER_PORT}
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_NAME=${DB_NAME}
DB_USERNAME=${DB_USERNAME}
DB_PASSWORD=${DB_PASSWORD}
REDIS_HOST=${REDIS_HOST}
REDIS_PORT=${REDIS_PORT}
REDIS_PASSWORD=${REDIS_PASSWORD}
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRATION_SECONDS=${JWT_EXPIRATION}
UPLOAD_DIR=${UPLOAD_DIR}
MAX_UPLOAD_SIZE=10485760
CORS_ORIGINS=${CORS_ORIGINS}
RUST_LOG=info
ENVIRONMENT=production
ENVEOF
    chmod 600 "${INSTALL_DIR}/.env"
    info ".env 配置文件已写入"
}

# ============================================================
# 安装 JDK + Maven（Java 源码编译用）
# ============================================================
install_java_toolchain() {
    step "安装 JDK 17 和 Maven"
    if command -v java &>/dev/null && java -version 2>&1 | grep -q "17\|21"; then
        info "JDK 已安装: $(java -version 2>&1 | head -1)"
    else
        apt-get install -y openjdk-17-jdk-headless 2>/dev/null || \
        yum install -y java-17-openjdk-devel 2>/dev/null || \
        error "无法自动安装 JDK 17，请手动安装后重试"
        info "JDK 17 安装完成"
    fi

    if command -v mvn &>/dev/null; then
        info "Maven 已安装: $(mvn --version | head -1)"
    else
        local maven_ver="3.9.6"
        wget -q "https://archive.apache.org/dist/maven/maven-3/${maven_ver}/binaries/apache-maven-${maven_ver}-bin.tar.gz" -O /tmp/maven.tgz
        tar -xzf /tmp/maven.tgz -C /opt/
        ln -sf "/opt/apache-maven-${maven_ver}/bin/mvn" /usr/local/bin/mvn
        rm /tmp/maven.tgz
        info "Maven ${maven_ver} 安装完成"
    fi
}

# ============================================================
# 安装 Rust 工具链（Rust 源码编译用）
# ============================================================
install_rust_toolchain() {
    step "安装 Rust 工具链"
    if command -v cargo &>/dev/null; then
        info "Rust 已安装: $(rustc --version)"
        return
    fi
    # 使用国内镜像加速
    export RUSTUP_DIST_SERVER=https://rsproxy.cn
    export RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup
    curl --proto '=https' --tlsv1.2 -sSf https://rsproxy.cn/rustup-init.sh | sh -s -- -y --profile minimal
    source "$HOME/.cargo/env"
    info "Rust $(rustc --version) 安装完成"
    # 配置 crates.io 国内镜像
    mkdir -p ~/.cargo
    cat > ~/.cargo/config.toml << 'EOF'
[source.crates-io]
replace-with = 'rsproxy-sparse'

[source.rsproxy-sparse]
registry = "sparse+https://rsproxy.cn/index/"
EOF
    info "crates.io 国内镜像已配置"
}

# ============================================================
# 创建 systemd 服务
# ============================================================
create_systemd() {
    local svc_name="$1" exec_path="$2" work_dir="$3" user="${4:-root}"

    cat > "/etc/systemd/system/${svc_name}.service" << EOF
[Unit]
Description=Forum Server (${BACKEND_TYPE})
After=network.target mysql.service redis.service

[Service]
Type=simple
User=${user}
Group=${user}
WorkingDirectory=${work_dir}
EnvironmentFile=-${work_dir}/.env
Environment="RUST_LOG=info"
ExecStart=${exec_path}
Restart=always
RestartSec=10
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "${svc_name}" >/dev/null 2>&1
    info "systemd 服务 ${svc_name} 已创建并启用自启"
}

# ============================================================
# Java 后端安装
# ============================================================
install_java() {
    step "安装 Java 后端"

    mkdir -p "$INSTALL_DIR"/{uploads,logs}

    if [[ "$INSTALL_MODE" == "binary" ]]; then
        # ---- 快捷安装 ----
        info "下载预编译 JAR..."
        wget -q --show-progress "${DOWNLOAD_BASE}/forum-server.jar" -O "${INSTALL_DIR}/forum-server.jar"
    else
        # ---- 编译安装 ----
        install_java_toolchain
        info "克隆源码..."
        mkdir -p /tmp/forum-build
        cd /tmp/forum-build
        # 下载源码压缩包
        wget -q "${DOWNLOAD_BASE}/server-source.zip" -O server-source.zip || {
            error "源码下载失败，请检查网络"
        }
        unzip -qo server-source.zip
        cd server
        info "Maven 编译中（约 3 分钟）..."
        mvn package -q -DskipTests
        cp target/forum-server.jar "$INSTALL_DIR/forum-server.jar"
        rm -rf /tmp/forum-build
    fi

    chmod +x "${INSTALL_DIR}/forum-server.jar"
    write_env
    create_systemd "forum-java" "/usr/bin/java -Xms512m -Xmx1g -Dfile.encoding=UTF-8 -Duser.timezone=Asia/Shanghai -jar ${INSTALL_DIR}/forum-server.jar" "$INSTALL_DIR" "forum"

    # 创建 forum 用户
    id -u forum &>/dev/null || useradd -r -s /sbin/nologin forum
    chown -R forum:forum "$INSTALL_DIR"
}

# ============================================================
# Rust 后端安装
# ============================================================
install_rust() {
    step "安装 Rust 后端"

    mkdir -p "$INSTALL_DIR"/uploads

    if [[ "$INSTALL_MODE" == "binary" ]]; then
        info "下载预编译二进制..."
        wget -q --show-progress "${DOWNLOAD_BASE}/forum-server-rust" -O "${INSTALL_DIR}/forum-server-rust"
    else
        install_rust_toolchain
        source "$HOME/.cargo/env"
        info "下载源码..."
        mkdir -p /tmp/forum-build
        cd /tmp/forum-build
        wget -q "${DOWNLOAD_BASE}/server-source.zip" -O server-source.zip || error "源码下载失败"
        unzip -qo server-source.zip
        cd server-rust || cd server
        # 确保 Cargo.toml 有国内镜像
        mkdir -p ~/.cargo
        cat > ~/.cargo/config.toml << 'EOF'
[source.crates-io]
replace-with = 'rsproxy-sparse'

[source.rsproxy-sparse]
registry = "sparse+https://rsproxy.cn/index/"
EOF
        info "Cargo 编译中（首次约 10-20 分钟）..."
        cargo build --release
        cp target/release/forum-server-rust "$INSTALL_DIR/forum-server-rust"
        rm -rf /tmp/forum-build
    fi

    chmod +x "${INSTALL_DIR}/forum-server-rust"
    write_env
    create_systemd "forum-rust" "${INSTALL_DIR}/forum-server-rust" "$INSTALL_DIR" "root"
}

# ============================================================
# 创建初始管理员账户
# ============================================================
create_admin() {
    step "创建初始管理员账户"

    # 等待服务启动
    sleep 5

    # 先检查服务是否正常
    local health_url="http://127.0.0.1:${SERVER_PORT}/api/health"
    for i in $(seq 1 12); do
        if curl -s -o /dev/null -w "%{http_code}" "$health_url" | grep -q "200"; then
            break
        fi
        sleep 5
    done

    # 注册管理员
    local reg_body="{\"username\":\"${ADMIN_USER}\",\"password\":\"${ADMIN_PASS}\",\"nickname\":\"Admin\"}"
    local reg_resp
    reg_resp=$(curl -s -w "|%{http_code}" -X POST \
        "http://127.0.0.1:${SERVER_PORT}/api/auth/register" \
        -H "Content-Type: application/json" \
        -d "$reg_body" 2>/dev/null)
    local code="${reg_resp##*|}"

    if [[ "$code" == "200" ]]; then
        info "管理员账户 ${ADMIN_USER} 创建成功"
    elif [[ "$code" == "400" ]] || echo "$reg_resp" | grep -q "already exists"; then
        warn "用户名 ${ADMIN_USER} 已存在，跳过创建"
    else
        warn "管理员创建可能失败 (HTTP $code)，请手动注册"
    fi
}

# ============================================================
# 主流程
# ============================================================
main() {
    # curl|bash 时 stdin 是管道，read 会立即 EOF；重定向到终端
    if ! [ -t 0 ]; then
        exec < /dev/tty
    fi

    banner
    check_root
    check_deps
    collect_config

    case "$BACKEND_TYPE" in
        java) install_java ;;
        rust) install_rust ;;
    esac

    init_database

    systemctl start "forum-${BACKEND_TYPE}" 2>/dev/null || true

    create_admin

    step "验证安装"
    local health_code
    health_code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${SERVER_PORT}/api/health")
    if [[ "$health_code" == "200" ]]; then
        echo -e "${GREEN}${BOLD}"
        echo "  ╔═══════════════════════════════════════╗"
        echo "  ║         ✅ 安装成功！                  ║"
        echo "  ╠═══════════════════════════════════════╣"
        echo "  ║  API 地址: http://127.0.0.1:${SERVER_PORT}   ║"
        echo "  ║  管理员:   ${ADMIN_USER}                     ║"
        echo "  ║  引擎:     ${BACKEND_TYPE^^}                    ║"
        echo "  ╚═══════════════════════════════════════╝"
        echo -e "${NC}"
    else
        error "服务健康检查失败 (HTTP $health_code)，请查看日志：journalctl -u forum-${BACKEND_TYPE}"
    fi

    echo ""
    info "后续操作："
    echo "  1. 配置 Nginx 反向代理到 http://127.0.0.1:${SERVER_PORT}"
    echo "  2. 申请 SSL 证书"
    echo "  3. 部署前端 Web 文件到站点目录"
    echo ""
    info "常用命令："
    echo "  journalctl -u forum-${BACKEND_TYPE} -f    # 查看日志"
    echo "  systemctl restart forum-${BACKEND_TYPE}   # 重启服务"
    echo ""
}

main "$@"
