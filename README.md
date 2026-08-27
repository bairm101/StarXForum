# Forum 论坛系统

一个功能完整的社区论坛系统：**Spring Boot 3 后端 + Flutter 客户端**（Web / Android / Windows）。

- 多板块发帖/回帖、Markdown、图片/视频/文件上传（大文件分片上传）、隐藏内容、投票、话题、收藏
- 点赞/踩（互斥）、评论互动、打赏、@提及、私信、举报、关注/粉丝/拉黑
- 签到升级、等级/金币、扫码登录、设备管理（含一键退登）、通知中心（系统通知置顶）
- JWT 鉴权、登录锁定与限流、敏感词过滤（频繁使用自动降权）、CORS 白名单、举报审核、操作日志
- 完整管理后台：审核 / 用户 / 板块 / 站点 / 统计 / 敏感词 / 举报 / 日志 / 缓存清理

## 快速开始

后端一键部署（Ubuntu 22.04）见 **[部署指南 DEPLOY.md](DEPLOY.md)**；软件打包方法见 **[软件端打包教程](软件端打包教程.md)**。

```bash
# 脚本会自动安装 Java17 与 ffmpeg；需预先安装 MySQL8 / Redis
sudo bash scripts/deploy/forum-install.sh
```

客户端源码在 `client/`，使用 Flutter 构建：

```bash
cd client
flutter pub get
flutter run -d chrome   # Web
flutter build apk       # Android
flutter build windows   # Windows
```

## 目录

| 目录 | 说明 |
|---|---|
| `server/` | Spring Boot 后端 |
| `client/` | Flutter 客户端 |
| `scripts/deploy/` | 一键部署脚本 |
| `DEPLOY.md` | 完整部署指南 |
| `软件端打包教程.md` | 软件打包教程 |

## 技术栈

Java 17 · Spring Boot 3 · Spring Security · JPA · MySQL 8 · Redis 7 · Flutter
