#!/bin/bash
# ============================================================
#  StarXForum 一键安装脚本
#  支持 Java(Spring Boot) / Rust(Axum) 双引擎可选
#  支持编译安装(源码) 或 快捷安装(预编译二进制)
# ============================================================
set -uo pipefail
# 说明：不使用 set -e，改为对每个可能失败的命令显式处理，
# 避免下载中途失败时脚本静默退出、无任何报错。

# ---------- 颜色 ----------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ---------- 常量 ----------
DEFAULT_DIR="/opt/forum"
SCRIPT_VER="1.2.0"
GITHUB_REPO="bairm101/StarXForum"
GITHUB_BRANCH="main"

# 下载源（运行时自动检测）
CN_BASE="https://res.starxx.cn/forumres"
GH_BASE="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}"
DOWNLOAD_BASE=""

# ---------- 用户可覆盖的变量 ----------
INSTALL_DIR="${FORUM_DIR:-$DEFAULT_DIR}"
BACKEND_TYPE=""        # java | rust
INSTALL_MODE=""        # source | binary
SERVER_PORT="8080"
DB_HOST="127.0.0.1"
DB_PORT="3306"
DB_NAME="luntan"
DB_USERNAME="luntan"
DB_PASSWORD=""
DB_ROOT_PASS=""
DB_AUTO_INIT="no"
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
    echo "  ║     StarXForum 一键安装 v${SCRIPT_VER}        ║"
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
    local input
    read -r -p "$(echo -e "${CYAN}$prompt${NC}${default:+ [${default}]}: ")" input
    eval "$var=\"\${input:-$default}\""
}

ask_secret() {
    local prompt="$1" var="$2"
    local input
    read -r -s -p "$(echo -e "${CYAN}$prompt${NC}: ")" input
    echo ""
    eval "$var=\"\$input\""
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "请以 root 身份运行此脚本：sudo bash $0"
    fi
}

check_deps() {
    local cmd
    for cmd in curl wget tar gzip unzip; do
        if ! command -v "$cmd" &>/dev/null; then
            warn "安装缺失工具: $cmd"
            if command -v apt-get &>/dev/null; then
                apt-get update -qq && apt-get install -y -qq "$cmd" || error "无法安装 $cmd，请手动安装后重试"
            elif command -v yum &>/dev/null; then
                yum install -y "$cmd" || error "无法安装 $cmd，请手动安装后重试"
            else
                error "未找到 apt/yum，请手动安装 $cmd 后重试"
            fi
        fi
    done
}

# ---------- 健壮下载（带重试，失败给出明确报错而非静默退出） ----------
download() {
    local url="$1" dest="$2" desc="$3"
    info "正在下载 ${desc} ..."
    local attempt
    for attempt in 1 2 3; do
        rm -f "$dest"
        if wget "$url" -O "$dest" && [[ -s "$dest" ]]; then
            info "${desc} 下载完成"
            return 0
        fi
        warn "${desc} 第 ${attempt}/3 次下载未成功，5 秒后重试..."
        sleep 5
    done
    error "${desc} 下载失败，请检查网络后重试。URL: ${url}"
}

# ---------- 自动检测下载源 ----------
detect_download_source() {
    step "检测最佳下载源..."

    local cn_code
    cn_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout 3 --max-time 5 \
        "${CN_BASE}/schema.sql" 2>/dev/null) || cn_code="000"

    if [[ "$cn_code" == "200" ]]; then
        DOWNLOAD_BASE="$CN_BASE"
        info "使用国内镜像: ${CN_BASE}"
        return
    fi

    local gh_code
    gh_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout 5 --max-time 10 \
        "${GH_BASE}/schema.sql" 2>/dev/null) || gh_code="000"

    if [[ "$gh_code" == "200" ]]; then
        DOWNLOAD_BASE="$GH_BASE"
        info "使用 GitHub 源: ${GH_BASE}"
        return
    fi

    DOWNLOAD_BASE="$CN_BASE"
    warn "无法自动检测下载源，默认使用国内源"
    warn "如果下载失败请检查网络或设置代理"
}

generate_jwt_secret() {
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
    echo -e "     • 内存占用较高 (~500MB)，启动 ~10 秒"
    echo -e "     • 编译安装需要 JDK 17 + Maven"
    echo -e "  ${GREEN}2) Rust (Axum)${NC}"
    echo -e "     • 极致性能、内存占用极低 (~8MB)，启动 <100ms"
    echo -e "     • 单二进制文件，部署最简单"
    echo -e "     • 编译安装需要 Rust 工具链（首次约 10-20 分钟）"
    echo ""
    local choice
    while true; do
        read -r -p "$(echo -e "${CYAN}请选择 [1/2]:${NC} ")" choice
        case $choice in
            1) BACKEND_TYPE="java"; break ;;
            2) BACKEND_TYPE="rust"; break ;;
            *) warn "请输入 1 或 2" ;;
        esac
    done

    echo ""
    echo -e "${BOLD}选择安装方式:${NC}"
    echo -e "  ${GREEN}1) 快捷安装${NC} — 下载预编译文件直接运行（推荐，~30 秒）"
    echo -e "  ${GREEN}2) 编译安装${NC} — 下载源码在本地编译"
    echo ""
    while true; do
        read -r -p "$(echo -e "${CYAN}请选择 [1/2]:${NC} ")" choice
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
    echo "  CORS 控制哪些网站可以调用你的 API。"
    echo "  没有域名、只用 IP+端口访问 → 直接回车用 * 即可。"
    echo "  有域名时填你的前端域名，例如:"
    echo "    https://forum.starxx.cn,http://192.168.1.100:8080"
    ask "允许的来源（* = 允许所有，推荐新手）" CORS_ORIGINS "*"

    step "初始管理员账户"
    ask "管理员用户名" ADMIN_USER "admin"
    while true; do
        ask_secret "管理员密码（至少 8 位）" ADMIN_PASS
        if [[ ${#ADMIN_PASS} -ge 8 ]]; then break; fi
        warn "密码长度不足 8 位，请重新输入"
    done

    UPLOAD_DIR="${INSTALL_DIR}/uploads"

    echo ""
    echo -e "${BOLD}数据库初始化:${NC}"
    echo "  1) 自动创建 — 脚本连接 MySQL 创建库+用户+导入表结构（需 MySQL root 密码）"
    echo "  2) 手动创建 — 你已自行创建好数据库和用户"
    echo ""
    local db_init_choice
    while true; do
        read -r -p "$(echo -e "${CYAN}请选择 [1/2]:${NC} ")" db_init_choice
        case $db_init_choice in
            1) DB_AUTO_INIT="yes"; ask_secret "MySQL root 密码" DB_ROOT_PASS; break ;;
            2) DB_AUTO_INIT="no"; break ;;
            *) warn "请输入 1 或 2" ;;
        esac
    done

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
    local confirm
    read -r -p "$(echo -e "${YELLOW}确认以上配置并开始安装? [y/N]:${NC} ")" confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { warn "已取消安装"; exit 0; }
}

# ============================================================
# 数据库初始化
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
    local sql="CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'127.0.0.1' IDENTIFIED BY '${DB_PASSWORD}'; GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USERNAME}'@'127.0.0.1'; FLUSH PRIVILEGES;"
    if ! mysql -h"$DB_HOST" -P"$DB_PORT" -u root -p"$DB_ROOT_PASS" -e "$sql" 2>/dev/null; then
        if ! mysql -h"$DB_HOST" -P"$DB_PORT" -u root -e "$sql" 2>/dev/null; then
            error "无法连接 MySQL，请检查 root 密码"
        fi
    fi

    info "下载并导入表结构..."
    local schema_file="/tmp/forum_schema.sql"
    download "${DOWNLOAD_BASE}/schema.sql" "$schema_file" "数据库表结构"

    if ! mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USERNAME" -p"$DB_PASSWORD" "$DB_NAME" < "$schema_file"; then
        error "表结构导入失败，请检查数据库配置"
    fi
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
    # 构造 Rust 引擎所需的 URL 格式
    local db_url="mysql://${DB_USERNAME}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
    local redis_url
    if [[ -n "$REDIS_PASSWORD" ]]; then
        redis_url="redis://:${REDIS_PASSWORD}@${REDIS_HOST}:${REDIS_PORT}"
    else
        redis_url="redis://${REDIS_HOST}:${REDIS_PORT}"
    fi
    cat > "${INSTALL_DIR}/.env" << ENVEOF
# StarXForum 运行时配置 — 自动生成（同时兼容 Java / Rust 双引擎）
# ---- 通用 ----
SERVER_HOST=127.0.0.1
SERVER_PORT=${SERVER_PORT}
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRATION_SECONDS=${JWT_EXPIRATION}
UPLOAD_DIR=${UPLOAD_DIR}
MAX_UPLOAD_SIZE=10485760
CORS_ORIGINS=${CORS_ORIGINS}
RUST_LOG=info
ENVIRONMENT=production
# ---- Java 引擎（Spring Boot 读取） ----
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_NAME=${DB_NAME}
DB_USERNAME=${DB_USERNAME}
DB_PASSWORD=${DB_PASSWORD}
REDIS_HOST=${REDIS_HOST}
REDIS_PORT=${REDIS_PORT}
REDIS_PASSWORD=${REDIS_PASSWORD}
# ---- Rust 引擎（Axum 读取） ----
DATABASE_URL=${db_url}
REDIS_URL=${redis_url}
ENVEOF
    chmod 600 "${INSTALL_DIR}/.env"
    info ".env 配置文件已写入（双引擎兼容）"
}

# ============================================================
# 安装 JDK + Maven（Java 源码编译用）
# ============================================================
install_java_toolchain() {
    step "安装 JDK 17 和 Maven"
    if command -v java &>/dev/null && java -version 2>&1 | grep -qE '"(17|21)\.'; then
        info "JDK 已安装: $(java -version 2>&1 | head -1)"
    else
        if command -v apt-get &>/dev/null; then
            apt-get install -y openjdk-17-jdk-headless 2>/dev/null
        elif command -v yum &>/dev/null; then
            yum install -y java-17-openjdk-devel 2>/dev/null
        fi
        if ! command -v java &>/dev/null; then
            error "无法自动安装 JDK 17，请手动安装后重试"
        fi
        info "JDK 17 安装完成"
    fi

    if command -v mvn &>/dev/null; then
        info "Maven 已安装: $(mvn --version | head -1)"
    else
        local maven_ver="3.9.6"
        download "https://archive.apache.org/dist/maven/maven-3/${maven_ver}/binaries/apache-maven-${maven_ver}-bin.tar.gz" /tmp/maven.tgz "Maven"
        tar -xzf /tmp/maven.tgz -C /opt/ || error "Maven 解压失败"
        ln -sf "/opt/apache-maven-${maven_ver}/bin/mvn" /usr/local/bin/mvn
        rm -f /tmp/maven.tgz
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
    else
        export RUSTUP_DIST_SERVER=https://rsproxy.cn
        export RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup
        if ! curl --proto '=https' --tlsv1.2 -sSf https://rsproxy.cn/rustup-init.sh | sh -s -- -y --profile minimal; then
            error "Rust 工具链安装失败，请检查网络"
        fi
        info "Rust 安装完成"
    fi
    # shellcheck disable=SC1090
    [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
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
Description=StarXForum Server (${BACKEND_TYPE})
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
    mkdir -p "$INSTALL_DIR"/uploads "$INSTALL_DIR"/logs

    if [[ "$INSTALL_MODE" == "binary" ]]; then
        download "${DOWNLOAD_BASE}/forum-server.jar" "${INSTALL_DIR}/forum-server.jar" "Java 后端 JAR"
    else
        install_java_toolchain
        info "下载源码..."
        rm -rf /tmp/forum-build && mkdir -p /tmp/forum-build
        download "${DOWNLOAD_BASE}/server-source.zip" /tmp/forum-build/server-source.zip "Java 源码"
        if ! unzip -qo /tmp/forum-build/server-source.zip -d /tmp/forum-build; then
            error "源码解压失败"
        fi
        cd /tmp/forum-build/server || error "源码目录结构异常（缺少 server/ 目录）"
        info "Maven 编译中（约 3 分钟）..."
        if ! mvn package -q -DskipTests; then
            error "Maven 编译失败，请查看上方输出"
        fi
        cp target/forum-server.jar "$INSTALL_DIR/forum-server.jar" || error "复制 JAR 失败"
        cd / && rm -rf /tmp/forum-build
    fi

    chmod +x "${INSTALL_DIR}/forum-server.jar"
    write_env

    id -u forum &>/dev/null || useradd -r -s /sbin/nologin forum
    create_systemd "forum-java" "/usr/bin/java -Xms512m -Xmx1g -Dfile.encoding=UTF-8 -Duser.timezone=Asia/Shanghai -jar ${INSTALL_DIR}/forum-server.jar" "$INSTALL_DIR" "forum"
    chown -R forum:forum "$INSTALL_DIR"
}

# ============================================================
# Rust 后端安装
# ============================================================
install_rust() {
    step "安装 Rust 后端"
    mkdir -p "$INSTALL_DIR"/uploads

    if [[ "$INSTALL_MODE" == "binary" ]]; then
        download "${DOWNLOAD_BASE}/forum-server-rust" "${INSTALL_DIR}/forum-server-rust" "Rust 后端二进制"
    else
        install_rust_toolchain
        # shellcheck disable=SC1090
        [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
        info "下载源码..."
        rm -rf /tmp/forum-build && mkdir -p /tmp/forum-build
        download "${DOWNLOAD_BASE}/rust-source.zip" /tmp/forum-build/rust-source.zip "Rust 源码"
        if ! unzip -qo /tmp/forum-build/rust-source.zip -d /tmp/forum-build; then
            error "源码解压失败"
        fi
        cd /tmp/forum-build/server-rust || error "源码目录结构异常（缺少 server-rust/ 目录）"
        info "Cargo 编译中（首次约 10-20 分钟）..."
        if ! cargo build --release; then
            error "Cargo 编译失败，请查看上方输出"
        fi
        cp target/release/forum-server-rust "$INSTALL_DIR/forum-server-rust" || error "复制二进制失败"
        cd / && rm -rf /tmp/forum-build
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
    sleep 5

    local health_url="http://127.0.0.1:${SERVER_PORT}/api/health"
    local i
    for i in $(seq 1 12); do
        if curl -s -o /dev/null -w "%{http_code}" "$health_url" 2>/dev/null | grep -q "200"; then
            break
        fi
        sleep 5
    done

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
    detect_download_source
    collect_config

    case "$BACKEND_TYPE" in
        java) install_java ;;
        rust) install_rust ;;
        *) error "未知的后端引擎: $BACKEND_TYPE" ;;
    esac

    init_database

    if ! systemctl start "forum-${BACKEND_TYPE}"; then
        warn "服务启动命令返回非零，继续尝试健康检查..."
    fi

    create_admin

    step "验证安装"
    local health_code
    health_code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${SERVER_PORT}/api/health" 2>/dev/null)
    if [[ "$health_code" == "200" ]]; then
        echo -e "${GREEN}${BOLD}"
        echo "  ╔═══════════════════════════════════════╗"
        echo "  ║         安装成功！                     ║"
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