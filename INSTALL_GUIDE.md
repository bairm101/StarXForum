# StarXForum - 完整安装部署教程

> **版本**: v1.5.1+40 | **双引擎**: Java Spring Boot / Rust Axum | **前端**: Flutter Web + Android
>
> **开源地址**: [https://github.com/bairm101/StarXForum](https://github.com/bairm101/StarXForum)
> **协议**: MIT License

---

## 目录

- [架构概览](#架构概览)
- [一键安装（推荐）](#一键安装)
- [手动安装](#手动安装)
  - [Java 后端](#java-后端安装)
  - [Rust 后端安装](#rust-后端安装)
- [Nginx 反向代理配置](#nginx-反向代理)
- [SSL 证书](#ssl-证书)
- [Web 前端部署](#web-前端部署)
- [Android APK 构建](#android-apk-构建)
- [常见问题](#常见问题)
- [从源码构建](#从源码构建)

---

## 架构概览

```
用户浏览器/APK
    ↓ HTTPS
Nginx (forum.starxx.cn)          ← Web 前端静态文件
Nginx (forumapi.starxx.cn)       ← API 反向代理
    ↓ http://127.0.0.1:8080
后端服务 (Java 或 Rust)
    ↓
MySQL + Redis + /uploads/
```
    ↓
MySQL + Redis + /uploads/
```

### 双引擎对比

| 指标 | Java Spring Boot | Rust Axum |
|------|-----------------|-----------|
| 内存占用 | ~500MB | ~8MB |
| 启动时间 | 5-10 秒 | <100ms |
| JAR/二进制大小 | 61MB | 7MB |
| 成熟度 | 生产级、功能最全 | 功能对齐中 |
| 适合场景 | 首次部署、功能优先 | 资源受限、性能优先 |

> 两个引擎使用**完全相同**的数据库结构和 API 接口，可随时切换。

---

## 一键安装

### 快捷安装（推荐）

一条命令完成：下载预编译文件 → 配置 → 创建服务 → 注册管理员

```bash
curl -sSL https://res.starxx.cn/forumres/install.sh | sudo bash
```

脚本会交互式引导你：
1. 选择后端引擎（Java 或 Rust）
2. 选择安装方式（快捷/编译）
3. 输入数据库、Redis、端口等配置
4. 自动创建管理员账户
5. 自动生成 systemd 服务并启动

### 编译安装

选择"编译安装"模式，脚本会自动：
- Java: 安装 JDK 17 + Maven → 下载源码 → `mvn package`
- Rust: 安装 Rust 工具链 → 配置国内镜像 → `cargo build --release`

---

## 手动安装

如果需要更细粒度控制，可以按以下步骤操作。

### 前置要求

| 软件 | 最低版本 | 用途 |
|------|---------|------|
| MySQL | 5.7+ / 8.0 | 数据库 |
| Redis | 5.0+ | 缓存/会话 |
| Nginx | 1.18+ | 反向代理/Web 服务 |

### 数据库准备

```sql
-- 登录 MySQL
mysql -u root -p

-- 创建数据库和用户
CREATE DATABASE luntan CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'luntan'@'127.0.0.1' IDENTIFIED BY '你的密码';
GRANT ALL PRIVILEGES ON luntan.* TO 'luntan'@'127.0.0.1';
FLUSH PRIVILEGES;
EXIT;
```

---

## Java 后端安装

### 1. 安装 JDK 17

```bash
apt update && apt install -y openjdk-17-jdk-headless
java -version  # 确认输出 17.x
```

### 2. 下载并运行

```bash
# 创建目录
mkdir -p /opt/forum/{uploads,logs}

# 下载 jar
wget https://res.starxx.cn/forumres/forum-server.jar -O /opt/forum/forum-server.jar

# 创建配置文件
cat > /opt/forum/.env << 'EOF'
SERVER_PORT=8080
DB_HOST=127.0.0.1
DB_PORT=3306
DB_NAME=luntan
DB_USERNAME=luntan
DB_PASSWORD=你的密码
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
JWT_SECRET=你的64字符随机密钥
JWT_EXPIRATION_SECONDS=604800
UPLOAD_DIR=/opt/forum/uploads
CORS_ORIGINS=https://forum.starxx.cn,https://www.forum.starxx.cn
EOF

chmod 600 /opt/forum/.env
```

### 3. 创建 systemd 服务

```bash
cat > /etc/systemd/system/forum-java.service << 'EOF'
[Unit]
Description=Forum Server (Java)
After=network.target mysql.service redis.service

[Service]
Type=simple
User=forum
Group=forum
WorkingDirectory=/opt/forum
EnvironmentFile=/opt/forum/.env
ExecStart=/usr/bin/java -Xms512m -Xmx1g -Dfile.encoding=UTF-8 -Duser.timezone=Asia/Shanghai -jar /opt/forum/forum-server.jar
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 创建运行用户
useradd -r -s /sbin/nologin forum
chown -R forum:forum /opt/forum

# 启动
systemctl daemon-reload
systemctl enable --now forum-java
```

### 4. 从源码编译

```bash
# 安装 Maven
wget https://archive.apache.org/dist/maven/maven-3/3.9.6/binaries/apache-maven-3.9.6-bin.tar.gz -O /tmp/maven.tgz
tar -xzf /tmp/maven.tgz -C /opt/
ln -s /opt/apache-maven-3.9.6/bin/mvn /usr/local/bin/mvn

# 克隆源码并编译
git clone https://github.com/你的用户名/forum.git /tmp/forum-build
cd /tmp/forum-build/server
mvn package -DskipTests

# 部署
cp target/forum-server.jar /opt/forum/forum-server.jar
systemctl restart forum-java
```

---

## Rust 后端安装

### 1. 安装 Rust 工具链

```bash
# 使用国内镜像加速
export RUSTUP_DIST_SERVER=https://rsproxy.cn
export RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup
curl --proto '=https' --tlsv1.2 -sSf https://rsproxy.cn/rustup-init.sh | sh -s -- -y
source $HOME/.cargo/env

# 配置 crates.io 国内镜像
cat > ~/.cargo/config.toml << 'EOF'
[source.crates-io]
replace-with = 'rsproxy-sparse'

[source.rsproxy-sparse]
registry = "sparse+https://rsproxy.cn/index/"
EOF
```

### 2. 快捷安装（预编译二进制）

```bash
mkdir -p /opt/forum/uploads
wget https://res.starxx.cn/forumres/forum-server-rust -O /opt/forum/forum-server-rust
chmod +x /opt/forum/forum-server-rust
```

### 3. 从源码编译

```bash
git clone https://github.com/你的用户名/forum.git /tmp/forum-rust
cd /tmp/forum-rust/server-rust  # 或 server
cargo build --release
cp target/release/forum-server-rust /opt/forum/forum-server-rust
```

首次编译约 5-20 分钟（取决于网络和硬件）。

### 4. 配置和启动

```bash
cat > /opt/forum/.env << 'EOF'
DATABASE_URL=mysql://luntan:密码@127.0.0.1:3306/luntan
REDIS_URL=redis://127.0.0.1:6379
JWT_SECRET=你的64字符随机密钥
JWT_EXPIRATION_SECONDS=604800
SERVER_HOST=127.0.0.1
SERVER_PORT=8080
UPLOAD_DIR=/opt/forum/uploads
RUST_LOG=info
EOF

chmod 600 /opt/forum/.env

cat > /etc/systemd/system/forum-rust.service << 'EOF'
[Unit]
Description=Forum Server (Rust)
After=network.target mysql.service redis.service

[Service]
Type=simple
WorkingDirectory=/opt/forum
EnvironmentFile=/opt/forum/.env
ExecStart=/opt/forum/forum-server-rust
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now forum-rust
```

---

## Nginx 反向代理

### API 域名（forumapi.starxx.cn）

在宝塔面板或 Nginx 中添加站点：

```nginx
server {
    listen 443 ssl;
    server_name forumapi.starxx.cn;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;

    # 反向代理到后端
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket 支持
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # 大文件上传
        client_max_body_size 50m;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }

    # 媒体文件直接由 Nginx 提供（性能更好）
    location /uploads {
        alias /opt/forum/uploads;
        expires 30d;
        add_header Cache-Control "public";
    }
}
```

### Web 前端域名（forum.starxx.cn）

```nginx
server {
    listen 443 ssl;
    server_name forum.starxx.cn;
    root /www/wwwroot/forum.starxx.cn;
    index index.html;

    # Flutter Web SPA 路由支持
    location / {
        try_files $uri $uri/ /index.html;
    }

    # 静态资源缓存
    location ~* \.(js|css|png|jpg|svg|wasm)$ {
        expires 30d;
        add_header Cache-Control "public";
    }
}
```

---

## SSL 证书

使用 Let's Encrypt 免费证书：

```bash
# 安装 certbot
apt install certbot python3-certbot-nginx

# 申请证书
certbot --nginx -d forum.starxx.cn -d forumapi.starxx.cn

# 自动续期（crontab 已自动添加）
certbot renew --dry-run
```

或在宝塔面板 → SSL → Let's Encrypt 一键申请。

---

## Web 前端部署

### 方式一：下载预编译包

```bash
# 下载 web 包
wget https://res.starxx.cn/forumres/forum-web.zip -O /tmp/web.zip

# 解压到站点目录
mkdir -p /www/wwwroot/forum.starxx.cn
unzip /tmp/web.zip -d /www/wwwroot/forum.starxx.cn/
chown -R www:www /www/wwwroot/forum.starxx.cn/
```

### 方式二：从源码编译

```bash
# 安装 Flutter SDK (如未安装)
# 参考 https://docs.flutter.dev/get-started/install/linux

# 克隆项目
git clone https://github.com/你的用户名/forum.git /tmp/forum-client
cd /tmp/forum-client/client

# 安装依赖
flutter pub get

# 构建 Web 版本
flutter build web --release \
  --dart-define=API_BASE_URL=https://forumapi.starxx.cn

# 复制到站点目录
cp -r build/web/* /www/wwwroot/forum.starxx.cn/
```

---

## Android APK 构建

```bash
cd /tmp/forum-client/client

# 构建 arm64 APK
flutter build apk --release \
  --target-platform android-arm64 \
  --dart-define=API_BASE_URL=https://forumapi.starxx.cn

# 输出位置
ls build/app/outputs/flutter-apk/app-release.apk
```

---

## 常见问题

### Q: 登录提示"网络错误"

**A**: 后端返回格式与预期不匹配。确认使用的是最新版本后端。

验证方式：
```bash
curl -X POST https://forumapi.starxx.cn/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"wrong"}'
```

正确响应应为 `{"success":false,"message":"...","data":null}`。

### Q: 评论无法显示子回复

**A**: 确保评论接口返回树形结构（`replies` 数组嵌套在主评论内）。

验证方式：
```bash
curl https://forumapi.starxx.cn/api/posts/1/comments | jq '.data.items[0].replies'
```

### Q: 视频无法播放

**A**: 确认媒体接口支持 Range 请求（HTTP 206）：

```bash
curl -s -o /dev/null -w "%{http_code}" \
  -H "Range: bytes=0-1023" \
  https://forumapi.starxx.cn/media/你的媒体码
```

应返回 `206`。

### Q: Rust 编译失败

**A**: 确保使用国内镜像并清理缓存重试：

```bash
rm -rf ~/.cargo/registry
cargo clean
cargo build --release
```

### Q: 如何切换 Java ↔ Rust

两个后端使用同一数据库和 API 接口，直接停止一个启动另一个即可：

```bash
systemctl stop forum-rust && systemctl start forum-java
# 或反过来
systemctl stop forum-java && systemctl start forum-rust
```

无需修改前端或数据库。

### Q: 忘记管理员密码

目前需通过数据库重置（密码为 BCrypt 哈希）：

```bash
# 使用 htpasswd 生成新密码哈希
htpasswd -bnBC 10 "" 'newpassword123' | tr -d ':\n'
# 输出类似: $2y$10$xxxxx...

# 更新数据库
mysql -u root -p -e "UPDATE luntan.users SET password_hash='$2y$10$...' WHERE username='admin';"
```

---

## 文件结构参考

```
/opt/forum/
├── .env                    # 环境变量配置（600 权限）
├── uploads/                # 用户上传文件
├── logs/                   # 应用日志
└── forum-server.jar        # Java 后端（或 forum-server-rust）

/www/wwwroot/forum.starxx.cn/
├── index.html              # Flutter Web 入口
├── main.dart.js            # Dart 编译产物
├── assets/                 # 静态资源
└── ...
```

---

## 从源码构建

### Java 后端

```bash
git clone https://github.com/bairm101/StarXForum.git
cd StarXForum/server

# 需要 JDK 17 + Maven 3.6+
mvn package -DskipTests

# 产物: target/forum-server.jar
```

### Rust 后端

```bash
git clone https://github.com/bairm101/StarXForum.git
cd StarXForum/server-rust  # 或 server

# 需要 Rust 1.70+（推荐使用国内镜像加速）
cargo build --release

# 产物: target/release/forum-server-rust
```

### Flutter 客户端（全平台）

```bash
git clone https://github.com/bairm101/StarXForum.git
cd StarXForum/client

flutter pub get

# Android arm64 APK
flutter build apk --release --target-platform android-arm64 \
  --dart-define=API_BASE_URL=https://你的API地址

# Web
flutter build web --release \
  --dart-define=API_BASE_URL=https://你的API地址

# Windows
flutter build windows --release \
  --dart-define=API_BASE_URL=https://你的API地址

# iOS（需 macOS）
flutter build ios --release \
  --dart-define=API_BASE_URL=https://你的API地址
```

### 快捷安装脚本下载源说明

安装脚本自动检测最佳下载源：

| 环境 | 使用源 | 说明 |
|------|--------|------|
| 国内服务器 | res.starxx.cn | CDN 加速，速度快 |
| 海外服务器 | raw.githubusercontent.com | GitHub 直连 |
| 都不通 | 默认国内源 | 可配代理后重试 |

无需手动选择，脚本自动探测并切换。

---

## 许可证

本项目基于 [MIT License](LICENSE) 开源。

```
MIT License

Copyright (c) 2026 bairm101

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 开源地址

**GitHub**: [https://github.com/bairm101/StarXForum](https://github.com/bairm101/StarXForum)
