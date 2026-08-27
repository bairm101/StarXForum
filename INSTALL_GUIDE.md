# StarXForum 完整安装部署教程（v1.5.9）

StarXForum 是一个基于 Flutter + MySQL + Redis 的社区论坛系统。后端支持双引擎（Java Spring Boot / Rust Axum），前端支持两套 UI（原版 UI、新版 UI），可通过 Nginx 反向代理对外提供服务。

- 开源地址：https://github.com/bairm101/StarXForum
- 协议：MIT License

---

## 一、架构总览

用户浏览器 / APK → HTTPS → Nginx → 后端服务（Java 或 Rust，同一套数据库）→ MySQL + Redis + uploads 媒体目录

分层说明：

- 接入层：Nginx，负责 HTTPS、反向代理、上传体积限制、静态资源加速
- 后端：Java 与 Rust 二选一，共用完全相同的数据库结构与 API 接口，可随时切换
- 存储：MySQL（业务数据，24 张表）、Redis（验证码、会话、缓存）、本地磁盘（上传的图片/视频/文件）
- 前端：Flutter 构建，支持 Web / Android / Windows / iOS，两套 UI 均连接同一套接口

### 双引擎对比

| 指标 | Java Spring Boot | Rust Axum |
|------|------------------|-----------|
| 内存占用 | 约 500MB-1GB | 约 8-50MB |
| 启动时间 | 5-10 秒 | 小于 100ms |
| 发布包大小 | 约 60MB（JAR） | 约 9MB（单二进制） |
| 运行依赖 | 需 JDK 17 | 无任何外部依赖 |
| 成熟度 | 生产级、功能最全 | 功能与 Java 对齐 |
| 适用场景 | 首次部署、功能优先 | 资源受限、追求性能 |

两个引擎使用完全相同的数据库、API 和数据格式，切换时前后端零改动。

### 两套 UI 说明

- 原版 UI：`forum-client-source.zip`，目录结构为 `client/`
- 新版 UI：`forum-client-newui-source.zip`，目录结构为 `newui/`

两套 UI 功能一致，新版 UI 调整了交互与视觉。打包产物中 `forum-web.zip` 与 `forum-app-arm64.apk` 采用新版 UI 构建，如需原版 UI 产物请用其源码自行构建（见"前端构建"章节）。

---

## 二、系统要求

- 操作系统：Ubuntu 20.04+ / Debian 11+ / CentOS 8+
- 最低配置：1 核 CPU / 1GB 内存 / 20GB 磁盘
- 推荐配置：2 核 CPU / 2GB 内存 / 40GB 磁盘
- 必需软件：
  - MySQL 5.7 或 8.0
  - Redis 5.0+
  - Nginx 1.18+
  - JDK 17（仅 Java 引擎）
  - Rust 工具链（仅 Rust 引擎编译时需要）

---

## 三、一键安装（推荐）

一条命令完成：下载预编译文件 → 配置 → 创建服务 → 注册管理员。

国内服务器：

```
curl -sSL https://res.starxx.cn/forumres/install.sh | sudo bash
```

海外服务器（脚本会自动探测并切换到 GitHub 源）：

```
curl -sSL https://raw.githubusercontent.com/bairm101/StarXForum/main/install.sh | sudo bash
```

脚本交互流程：

1. 选择后端引擎：1=Java，2=Rust
2. 选择安装方式：1=快捷安装（预编译包），2=编译安装（自动安装工具链并编译）
3. 填写监听端口、安装目录、MySQL 地址/端口/库名/用户名/密码、Redis 配置
4. 选择数据库初始化：1=脚本自动建库并导入 24 张表结构（需 MySQL root 密码），2=使用已建好的数据库
5. 设置初始管理员账号与密码（至少 8 位）
6. 确认后自动下载、部署、启动并做健康检查

安装完成后会输出 API 地址与管理信息。第一个注册的用户自动成为站长（OWNER）。

---

## 四、手动安装（分步）

需要更细粒度控制时，按以下步骤逐步操作。

### 4.1 安装前置软件

```
apt update && apt install -y mysql-server redis-server nginx
systemctl enable --now mysql redis-server nginx
mysql_secure_installation
```

### 4.2 创建数据库与用户

执行 SQL（把"你的密码"替换为实际密码）：

```sql
CREATE DATABASE luntan CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'luntan'@'127.0.0.1' IDENTIFIED BY '你的密码';
GRANT ALL PRIVILEGES ON luntan.* TO 'luntan'@'127.0.0.1';
FLUSH PRIVILEGES;
```

导入表结构（24 张表）：

```
wget https://res.starxx.cn/forumres/schema.sql -O /tmp/schema.sql
mysql -u luntan -p你的密码 luntan < /tmp/schema.sql
rm /tmp/schema.sql
```

### 4.3 创建运行目录

```
mkdir -p /opt/forum/uploads /opt/forum/logs
useradd -r -s /sbin/nologin forum
chown -R forum:forum /opt/forum
```

---

## 五、Java 后端安装

### 5.1 安装 JDK

```
apt install -y openjdk-17-jdk-headless
java -version
```

### 5.2 下载 JAR

```
wget https://res.starxx.cn/forumres/forum-server.jar -O /opt/forum/forum-server.jar
chown forum:forum /opt/forum/forum-server.jar
chmod +x /opt/forum/forum-server.jar
```

### 5.3 创建配置 .env

内容如下（替换密码与密钥）：

```
SERVER_PORT=8080
DB_HOST=127.0.0.1
DB_PORT=3306
DB_NAME=luntan
DB_USERNAME=luntan
DB_PASSWORD=你的数据库密码
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
JWT_SECRET=你的64字符随机密钥
JWT_EXPIRATION_SECONDS=604800
UPLOAD_DIR=/opt/forum/uploads
CORS_ORIGINS=https://forum.starxx.cn
```

设置权限并生成密钥：

```
chmod 600 /opt/forum/.env
head -c 48 /dev/urandom | base64 | tr -d '\n' | head -c 64
```

### 5.4 创建 systemd 服务

```
[Unit]
Description=Forum Server Java
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
```

```
systemctl daemon-reload
systemctl enable --now forum-java
systemctl status forum-java
```

---

## 六、Rust 后端安装

### 6.1 安装 Rust 工具链（仅编译需要）

```
export RUSTUP_DIST_SERVER=https://rsproxy.cn
export RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup
curl --proto '=https' --tlsv1.2 -sSf https://rsproxy.cn/rustup-init.sh | sh -s -- -y --profile minimal
source $HOME/.cargo/env
```

配置 crates 国内镜像（~/.cargo/config.toml）：

```
[source.crates-io]
replace-with = 'rsproxy-sparse'

[source.rsproxy-sparse]
registry = "sparse+https://rsproxy.cn/index/"
```

### 6.2 下载二进制

```
wget https://res.starxx.cn/forumres/forum-server-rust -O /opt/forum/forum-server-rust
chmod +x /opt/forum/forum-server-rust
```

### 6.3 创建配置 .env

```
DATABASE_URL=mysql://luntan:你的密码@127.0.0.1:3306/luntan
REDIS_URL=redis://127.0.0.1:6379
JWT_SECRET=你的64字符随机密钥
SERVER_HOST=127.0.0.1
SERVER_PORT=8080
UPLOAD_DIR=/opt/forum/uploads
RUST_LOG=info
```

```
chmod 600 /opt/forum/.env
```

### 6.4 创建 systemd 服务

```
[Unit]
Description=Forum Server Rust
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
```

```
systemctl daemon-reload
systemctl enable --now forum-rust
systemctl status forum-rust
```

---

## 七、Nginx 反向代理

需两个站点：API 站点与 Web 站点。

### 7.1 API 站点（forumapi.starxx.cn）

```
server {
    listen 443 ssl;
    server_name forumapi.starxx.cn;
    client_max_body_size 50m;

    ssl_certificate /etc/letsencrypt/live/forumapi.starxx.cn/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/forumapi.starxx.cn/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        client_max_body_size 50m;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }
}
```

注意：本系统上传文件上限默认图片 5MB、视频 15MB（后台可调），分片上传支持最大到数十 MB 的较大文件，请确保 `client_max_body_size` 覆盖实际需要。

### 7.2 Web 站点（forum.starxx.cn）

```
server {
    listen 443 ssl;
    server_name forum.starxx.cn;

    ssl_certificate /etc/letsencrypt/live/forum.starxx.cn/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/forum.starxx.cn/privkey.pem;

    root /www/wwwroot/forum.starxx.cn;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location ~* \.(js|css|png|jpg|svg|wasm)$ {
        expires 30d;
        add_header Cache-Control "public";
    }
}
```

### 7.3 SSL 证书

```
apt install -y certbot python3-certbot-nginx
certbot --nginx -d forum.starxx.cn -d forumapi.starxx.cn
certbot renew --dry-run
```

---

## 八、Web 前端部署

### 下载预编译包

当前 `forum-web.zip` 为新版 UI 构建：

```
wget https://res.starxx.cn/forumres/forum-web.zip -O /tmp/web.zip
mkdir -p /www/wwwroot/forum.starxx.cn
unzip /tmp/web.zip -d /www/wwwroot/forum.starxx.cn/
chown -R www:www /www/wwwroot/forum.starxx.cn/
```

访问 https://forum.starxx.cn 确认首页正常。

---

## 九、Android APK 构建

需要安装 Flutter SDK 与 Android SDK。

新版 UI：

```
git clone https://github.com/bairm101/StarXForum.git
cd StarXForum/newui
flutter pub get
flutter build apk --release \
  --target-platform android-arm64 \
  --dart-define=API_BASE_URL=https://forumapi.starxx.cn
```

原版 UI：

```
cd StarXForum/client
flutter pub get
flutter build apk --release \
  --target-platform android-arm64 \
  --dart-define=API_BASE_URL=https://forumapi.starxx.cn
```

产物路径均为 `build/app/outputs/flutter-apk/app-release.apk`。

### Web 构建

```
flutter build web --release --dart-define=API_BASE_URL=https://forumapi.starxx.cn
cp -r build/web/* /www/wwwroot/forum.starxx.cn/
```

### Windows 桌面构建

```
flutter build windows --release --dart-define=API_BASE_URL=https://forumapi.starxx.cn
```

---

## 十、初始管理员

服务启动后，调用注册接口注册的第一个用户自动获得站长（OWNER）权限：

```
curl -X POST http://127.0.0.1:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"你的密码至少8位","nickname":"Admin"}'
```

---

## 十一、后台功能（站长/管理员）

登录后在我的页面进入后台，通常包含以下模块：

- 用户管理：搜索（UID/用户名/昵称）、封禁/解封、角色调整（站长/超管/板块管理员/普通用户）、头衔、参数调整（等级/经验/金币/上传配额/签名）、强制退登、签名审核（通过/驳回）、删除用户
- 帖子管理：全部帖子、待审核帖子，支持审核（通过/驳回）、删除、转移板块、全站置顶、锁定/解锁
- 板块管理：新建/编辑/删除板块，设置是否显示、发帖是否需要审核
- 举报处理：查看举报（PENDING），支持解决/驳回，聊天举报含消息记录与截图证据
- 敏感词管理：增删敏感词与替换词
- 操作日志：全部后台操作留痕，可按操作者搜索
- 数据统计：站点总览、每日注册/帖子/评论、活跃用户
- 站点设置：站名、公告、主题、注册开关、算术验证（发帖/评论/邮箱）、SMTP 邮件（含邮箱换绑/忘记密码/新设备验证）、签名审核模式、图片/视频压缩、二次编辑审核、设备验证、图片/视频上传上限、关于页信息
- 维护：统计数据重置、点赞/评论/私信等清理

权限分层：

- 站长（OWNER）：一切权限
- 超级管理员（SUPER_ADMIN）：全站管理，可任命板块管理员
- 板块管理员（ADMIN）：仅能管理其管辖板块的内容

---

## 十二、社区功能列表

- 发帖/编辑/删除，支持 Markdown、话题、隐藏内容（回复可见/登录可见/付费可见）、帖子付费解锁（金币）
- 评论与嵌套回复，点赞/点踩，举报
- 私信：一对一聊天、发送图片、举报聊天（可勾选聊天记录与截图作为证据）、删除会话
- 关注/粉丝/拉黑，关注动态流
- 金币经济：签到得金币、打赏帖子作者（单次最多 2 金币、每人每帖最多 3 次）
- 投票：帖主可为帖子创建投票（单选/多选、截止时间）
- 通知：公告、被回复、被点赞、被关注、被引用、设备登录、审核结果等，支持通知开关
- 收藏：收藏/取消收藏、收藏列表
- 用户主页：资料、帖子、评论、关注列表、拉黑列表，头像/昵称/签名/头衔展示
- 搜索：帖子搜索（标题/内容）与用户搜索（用户名/昵称/UID）切换
- 账号安全：修改密码、修改邮箱（邮箱验证码）、绑定邮箱用于找回密码与设备验证、设备管理（查看/下线/一键退登）、自助注销账号
- 登录支持用户名/邮箱/UID 三种方式；验证码发送有 60 秒冷却；新设备登录可选邮箱二次验证
- 已注销账号：帖子与上传文件删除、评论匿名显示为"账号已注销"、主页显示注销提示

---

## 十三、常见问题

### 登录提示网络错误

后端返回格式与预期不匹配。确认使用最新版后端。正确响应应为 `{"success":false,"message":"...","data":null}` 结构。

### 私信列表出现同一联系人两条

旧版本 Java 与 Rust 写入的会话键格式不一致导致（Java 为下划线、Rust 旧版为冒号）。已在 v1.5.9 统一，并按数据库中的消息对会话键做了规范化。升级后重复项自动消失；若历史数据仍异常，可在数据库中执行：

```
UPDATE messages SET conversation_key = CONCAT(LEAST(sender_id,recipient_id),'_',GREATEST(sender_id,recipient_id));
```

### 附件上传提示不支持的文件类型

支持常见文档与压缩包类型：md/txt/json/csv/pdf/doc/docx/xls/xlsx/ppt/pptx/zip/rar/7z/tar/gz/apk。危险类型（php/exe/dll/js 等）被安全策略禁止。

### 验证码收不到

检查后台站点设置中 SMTP 开关与账号授权码是否正确；同一目标 60 秒内只能发一次，请勿频繁点击。

### 打赏提示"不能打赏自己的帖子"

设计如此：帖子作者不能打赏自己的帖子；单次最多 2 金币、每人每帖最多 3 次。

### Java 与 Rust 如何切换

```
systemctl stop forum-rust && systemctl start forum-java
# 或
systemctl stop forum-java && systemctl start forum-rust
```

两者共用同一数据库与接口，无需改前端。

### Rust 编译失败

清理缓存并使用国内镜像重试：

```
rm -rf ~/.cargo/registry
cargo clean
cargo build --release
```

### 忘记管理员密码

管理员密码为 BCrypt 哈希。用 htpasswd 生成新哈希后更新用户表：

```
htpasswd -bnBC 10 "" 'newpassword123' | tr -d ':\n'
mysql -u root -p -e "UPDATE luntan.users SET password_hash='$2y$10$...' WHERE username='admin';"
```

---

## 十四、备份与升级

### 备份

```
mysqldump -u luntan -p luntan | gzip > /opt/forum/backups/luntan-$(date +%Y%m%d).sql.gz
tar czf /opt/forum/backups/uploads-$(date +%Y%m%d).tar.gz /opt/forum/uploads
```

### 升级

- 后端：用新发布包替换二进制/JAR，重启对应服务即可，数据库结构兼容且启动时自动迁移
- 前端：用新 `forum-web.zip` 覆盖站点目录即可，客户端更新从设置/发布渠道获取新 APK

备份文件默认保留：MySQL 每日自动备份到 `/opt/forum/backups/`。

---

## 十五、下载源

| 文件 | 说明 |
|------|------|
| forum-server.jar | Java 后端 |
| forum-server-rust | Rust 后端 |
| forum-web.zip | 新版 UI Web 前端 |
| forum-app-arm64.apk | 新版 UI Android 包 |
| forum-client-source.zip | 原版 UI Flutter 源码 |
| forum-client-newui-source.zip | 新版 UI Flutter 源码 |
| server-source.zip | Java 后端源码 |
| rust-source.zip | Rust 后端源码 |
| schema.sql | 数据库表结构（24 张表） |
| install.sh | 一键安装脚本 |
| INSTALL_GUIDE.md | 本文档 |

国内源：https://res.starxx.cn/forumres/
GitHub 源：https://raw.githubusercontent.com/bairm101/StarXForum/main/