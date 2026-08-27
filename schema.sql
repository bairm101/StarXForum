
/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
DROP TABLE IF EXISTS `blacklists`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `blacklists` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `blocked_id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_blacklist` (`user_id`,`blocked_id`),
  KEY `idx_blk_user` (`user_id`),
  KEY `idx_blk_target` (`blocked_id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `boards`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `boards` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `description` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `name` varchar(50) COLLATE utf8mb4_general_ci NOT NULL,
  `post_count` int NOT NULL,
  `sort_order` int NOT NULL,
  `visible` bit(1) NOT NULL,
  `require_moderation` bit(1) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UK7pat9n19tjsdksl6c01d0rjtn` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `comments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `comments` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `content` text COLLATE utf8mb4_general_ci NOT NULL,
  `deleted` bit(1) NOT NULL,
  `like_count` int NOT NULL,
  `author_id` bigint NOT NULL,
  `parent_id` bigint DEFAULT NULL,
  `post_id` bigint NOT NULL,
  `dislike_count` int NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_comments_post` (`post_id`),
  KEY `idx_comments_author` (`author_id`),
  KEY `idx_comments_parent` (`parent_id`),
  CONSTRAINT `FKh4c7lvsc298whoyd4w9ta25cr` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`),
  CONSTRAINT `FKlri30okf66phtcgbe5pok7cc0` FOREIGN KEY (`parent_id`) REFERENCES `comments` (`id`),
  CONSTRAINT `FKn2na60ukhs76ibtpt9burkm27` FOREIGN KEY (`author_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=66 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `dislikes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `dislikes` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `target_id` bigint NOT NULL,
  `target_type` enum('COMMENT','POST') COLLATE utf8mb4_general_ci NOT NULL,
  `user_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_dislikes_user_target` (`user_id`,`target_type`,`target_id`),
  KEY `idx_dislikes_target` (`target_type`,`target_id`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `favorites`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `favorites` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `post_id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UKfr75lh3x7bxymrtmwdvh7j8hl` (`user_id`,`post_id`),
  KEY `idx_fav_user` (`user_id`),
  KEY `idx_fav_post` (`post_id`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `follows`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `follows` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `following_id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_follow` (`user_id`,`following_id`),
  KEY `idx_follow_user` (`user_id`),
  KEY `idx_follow_target` (`following_id`)
) ENGINE=InnoDB AUTO_INCREMENT=17 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `likes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `likes` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `target_id` bigint NOT NULL,
  `target_type` enum('COMMENT','POST') COLLATE utf8mb4_general_ci NOT NULL,
  `user_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_likes_user_target` (`user_id`,`target_type`,`target_id`),
  KEY `idx_likes_target` (`target_type`,`target_id`)
) ENGINE=InnoDB AUTO_INCREMENT=25 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `messages` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `content` text COLLATE utf8mb4_general_ci NOT NULL,
  `conversation_key` varchar(64) COLLATE utf8mb4_general_ci NOT NULL,
  `deleted_by_recipient` bit(1) NOT NULL,
  `deleted_by_sender` bit(1) NOT NULL,
  `read_flag` bit(1) NOT NULL,
  `recipient_id` bigint NOT NULL,
  `sender_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_messages_conversation` (`conversation_key`,`created_at`),
  KEY `idx_messages_recipient` (`recipient_id`,`read_flag`),
  KEY `idx_messages_sender` (`sender_id`),
  CONSTRAINT `FK4ui4nnwntodh6wjvck53dbk9m` FOREIGN KEY (`sender_id`) REFERENCES `users` (`id`),
  CONSTRAINT `FKhdkwfnspwb3s60j27vpg0rpg6` FOREIGN KEY (`recipient_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `notification_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notification_settings` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `enable_announcement` bit(1) NOT NULL,
  `enable_comment` bit(1) NOT NULL,
  `enable_device_login` bit(1) NOT NULL,
  `enable_like` bit(1) NOT NULL,
  `enable_moderation` bit(1) NOT NULL,
  `user_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UKm9ggfvif86mvq5382j88cequn` (`user_id`),
  KEY `idx_notif_setting_user` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notifications` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `content` varchar(500) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `read_flag` bit(1) NOT NULL,
  `ref_id` bigint DEFAULT NULL,
  `title` varchar(128) COLLATE utf8mb4_general_ci NOT NULL,
  `type` enum('ANNOUNCEMENT','COMMENT','DEVICE_LOGIN','LIKE','MENTION','MODERATION_APPROVED','MODERATION_REJECTED','REPORT') COLLATE utf8mb4_general_ci NOT NULL,
  `user_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_notif_user` (`user_id`,`read_flag`),
  KEY `idx_notif_user_created` (`user_id`,`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=76 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `operation_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `operation_logs` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `action` varchar(32) COLLATE utf8mb4_general_ci NOT NULL,
  `detail` varchar(1000) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `operator_id` bigint NOT NULL,
  `operator_name` varchar(64) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `target` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_oplog_user` (`operator_id`),
  KEY `idx_oplog_created` (`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=35 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `poll_options`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `poll_options` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `option_text` varchar(200) COLLATE utf8mb4_general_ci NOT NULL,
  `poll_id` bigint NOT NULL,
  `vote_count` int NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_pollopt_poll` (`poll_id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `poll_votes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `poll_votes` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `option_id` bigint NOT NULL,
  `poll_id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UKby74t3g6apehqx430lhk1wu06` (`poll_id`,`user_id`,`option_id`),
  KEY `idx_vote_poll_user` (`poll_id`,`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `polls`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `polls` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `deadline` datetime(6) DEFAULT NULL,
  `multiple` bit(1) NOT NULL,
  `post_id` bigint NOT NULL,
  `question` varchar(200) COLLATE utf8mb4_general_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_poll_post` (`post_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `post_revisions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `post_revisions` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `content` longtext COLLATE utf8mb4_general_ci NOT NULL,
  `editor_id` bigint DEFAULT NULL,
  `post_id` bigint NOT NULL,
  `title` varchar(200) COLLATE utf8mb4_general_ci NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_rev_post` (`post_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `post_unlocks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `post_unlocks` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `amount` bigint NOT NULL,
  `post_id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UK9dcok2r1gtfpkwdbhjl8tcw1y` (`post_id`,`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `posts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `posts` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `comment_count` int NOT NULL,
  `content` longtext COLLATE utf8mb4_general_ci NOT NULL,
  `deleted` bit(1) NOT NULL,
  `last_activity_at` datetime(6) NOT NULL,
  `like_count` int NOT NULL,
  `locked` bit(1) NOT NULL,
  `pinned` bit(1) NOT NULL,
  `title` varchar(200) COLLATE utf8mb4_general_ci NOT NULL,
  `view_count` int NOT NULL,
  `author_id` bigint NOT NULL,
  `board_id` bigint NOT NULL,
  `tip_count` int NOT NULL,
  `total_tip_gold` bigint NOT NULL,
  `status` enum('APPROVED','PENDING','REJECTED') COLLATE utf8mb4_general_ci NOT NULL,
  `board_pinned` bit(1) NOT NULL,
  `gate_price` bigint NOT NULL,
  `gate_type` varchar(16) COLLATE utf8mb4_general_ci NOT NULL,
  `gated_content` longtext COLLATE utf8mb4_general_ci,
  `thumbnail_url` varchar(500) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `dislike_count` int NOT NULL,
  `topics` varchar(500) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `puid` varchar(16) COLLATE utf8mb4_general_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UK5c8421o4g1rayx0l178p5m1op` (`puid`),
  KEY `idx_posts_board` (`board_id`),
  KEY `idx_posts_author` (`author_id`),
  KEY `idx_posts_last_activity` (`last_activity_at`),
  KEY `idx_posts_deleted` (`deleted`),
  FULLTEXT KEY `ft_posts_title_content` (`title`,`content`) /*!50100 WITH PARSER `ngram` */ ,
  CONSTRAINT `FK6xvn0811tkyo3nfjk2xvqx6ns` FOREIGN KEY (`author_id`) REFERENCES `users` (`id`),
  CONSTRAINT `FK78qo1gxd85rcxqojt2cpcmuj6` FOREIGN KEY (`board_id`) REFERENCES `boards` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=48 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `reports`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reports` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `handle_note` varchar(500) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `handled_by` bigint DEFAULT NULL,
  `reason` varchar(500) COLLATE utf8mb4_general_ci NOT NULL,
  `reporter_id` bigint NOT NULL,
  `status` enum('PENDING','REJECTED','RESOLVED') COLLATE utf8mb4_general_ci NOT NULL,
  `target_id` bigint NOT NULL,
  `target_type` enum('COMMENT','POST','USER') COLLATE utf8mb4_general_ci NOT NULL,
  `evidence_json` text COLLATE utf8mb4_general_ci,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_reports_user_target` (`reporter_id`,`target_type`,`target_id`),
  KEY `idx_reports_status` (`status`,`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `sensitive_words`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sensitive_words` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `enabled` bit(1) NOT NULL,
  `replacement` varchar(32) COLLATE utf8mb4_general_ci NOT NULL,
  `word` varchar(64) COLLATE utf8mb4_general_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UKbjs19wyvvsdx2baxrvi7frds9` (`word`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `site_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `site_settings` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `allow_register` bit(1) NOT NULL,
  `announcement` varchar(500) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `site_description` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `site_name` varchar(64) COLLATE utf8mb4_general_ci NOT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `arithmetic_comment_enabled` bit(1) NOT NULL,
  `arithmetic_email_enabled` bit(1) NOT NULL,
  `arithmetic_post_enabled` bit(1) NOT NULL,
  `default_theme` varchar(16) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `email_verification_enabled` bit(1) NOT NULL,
  `footer_icp` varchar(128) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `footer_links_json` text COLLATE utf8mb4_general_ci,
  `footer_text` varchar(500) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `image_compress_enabled` bit(1) NOT NULL,
  `image_max_mb` int NOT NULL,
  `page_title` varchar(128) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `role_upload_quota_json` text COLLATE utf8mb4_general_ci,
  `signature_audit_mode` varchar(16) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `smtp_enabled` bit(1) NOT NULL,
  `smtp_host` varchar(128) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `smtp_password` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `smtp_port` int DEFAULT NULL,
  `smtp_ssl` bit(1) NOT NULL,
  `smtp_username` varchar(128) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `video_compress_enabled` bit(1) NOT NULL,
  `video_max_mb` int NOT NULL,
  `post_edit_audit_enabled` bit(1) NOT NULL,
  `device_verification_enabled` bit(1) NOT NULL,
  `about_icp` varchar(128) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `contact_email` varchar(128) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `official_website` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `auto_refresh_seconds` int NOT NULL,
  `web_share_base_url` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `tips`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tips` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `amount` bigint NOT NULL,
  `post_id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_tips_post` (`post_id`),
  KEY `idx_tips_user` (`user_id`),
  KEY `idx_tips_user_post` (`user_id`,`post_id`),
  CONSTRAINT `FKljvlwt8ooklvnpn1a78v5oi6d` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `FKmo40d8l2d0ev47kkkww3pxifm` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `upload_records`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `upload_records` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `path` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `size_bytes` bigint NOT NULL,
  `type` varchar(16) COLLATE utf8mb4_general_ci NOT NULL,
  `user_id` bigint NOT NULL,
  `content_type` varchar(128) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `original_name` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `public_code` varchar(32) COLLATE utf8mb4_general_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UKnoan0vadevwd4mw5iuihput5c` (`public_code`),
  KEY `idx_upload_user` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=42 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `user_sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_sessions` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `device_id` varchar(64) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `device_name` varchar(128) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `last_seen_at` datetime(6) DEFAULT NULL,
  `created_at2` datetime(6) NOT NULL,
  `revoked` bit(1) NOT NULL,
  `sid` varchar(64) COLLATE utf8mb4_general_ci NOT NULL,
  `user_agent` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `user_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UK31wown8jik2t2vha8oru4nc3p` (`sid`),
  KEY `idx_sessions_user` (`user_id`),
  KEY `idx_sessions_device` (`user_id`,`device_id`)
) ENGINE=InnoDB AUTO_INCREMENT=76 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `avatar_url` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `comment_count` int NOT NULL,
  `email` varchar(128) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `nickname` varchar(32) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `password_hash` varchar(100) COLLATE utf8mb4_general_ci NOT NULL,
  `post_count` int NOT NULL,
  `role` enum('ADMIN','OWNER','SUPER_ADMIN','USER') COLLATE utf8mb4_general_ci NOT NULL,
  `signature` varchar(200) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `status` enum('ACTIVE','BANNED','CANCELLED') COLLATE utf8mb4_general_ci NOT NULL,
  `username` varchar(32) COLLATE utf8mb4_general_ci NOT NULL,
  `checkin_streak` int NOT NULL,
  `exp` int NOT NULL,
  `gold` bigint NOT NULL,
  `last_checkin_date` date DEFAULT NULL,
  `level` int NOT NULL,
  `level_up_at` datetime(6) DEFAULT NULL,
  `managed_board_id` bigint DEFAULT NULL,
  `title` varchar(32) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `email_verified` bit(1) NOT NULL,
  `pending_signature` varchar(200) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `ranking_weight` double NOT NULL,
  `signature_approved_once` bit(1) NOT NULL,
  `max_upload_mb` int DEFAULT NULL,
  `failed_login_count` int NOT NULL,
  `locked_until` datetime(6) DEFAULT NULL,
  `uid` varchar(32) COLLATE utf8mb4_general_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_users_username` (`username`),
  UNIQUE KEY `idx_users_email` (`email`),
  UNIQUE KEY `UKefqukogbk7i0poucwoy2qie74` (`uid`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

