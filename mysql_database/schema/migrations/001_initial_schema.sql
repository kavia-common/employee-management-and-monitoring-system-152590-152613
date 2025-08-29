-- 001_initial_schema.sql
-- Employee Management & Monitoring System - MySQL Initial Schema
-- Uses normalized structure with proper PKs, FKs, and indexes.
-- IMPORTANT: Do not hardcode credentials here. Connection is configured via env (MYSQL_URL, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DB, MYSQL_PORT).

-- Set sane SQL modes
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- Create database if not exists (idempotent)
CREATE DATABASE IF NOT EXISTS `myapp` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `myapp`;

-- Drop existing tables (safe reset for initial development environments)
-- Comment these lines if you want to preserve existing data.
DROP TABLE IF EXISTS meeting_participants;
DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS reports;
DROP TABLE IF EXISTS leaves;
DROP TABLE IF EXISTS tasks;
DROP TABLE IF EXISTS projects;
DROP TABLE IF EXISTS attendance;
DROP TABLE IF EXISTS meetings;
DROP TABLE IF EXISTS user_roles;
DROP TABLE IF EXISTS roles;
DROP TABLE IF EXISTS users;

-- USERS
CREATE TABLE users (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  uid           VARCHAR(64) NULL, -- optional external auth uid (e.g., Firebase)
  email         VARCHAR(255) NOT NULL,
  password_hash VARCHAR(255) NULL, -- nullable when using external auth providers
  first_name    VARCHAR(100) NOT NULL,
  last_name     VARCHAR(100) NOT NULL,
  phone         VARCHAR(30) NULL,
  avatar_url    VARCHAR(512) NULL,
  is_active     TINYINT(1) NOT NULL DEFAULT 1,
  last_login_at DATETIME NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_users_email (email),
  KEY idx_users_uid (uid),
  KEY idx_users_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ROLES
CREATE TABLE roles (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name        VARCHAR(100) NOT NULL,           -- e.g., SUPER_ADMIN, MANAGER, TEAM_LEAD, EMPLOYEE
  description VARCHAR(255) NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_roles_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- USER_ROLES (many-to-many)
CREATE TABLE user_roles (
  user_id     BIGINT UNSIGNED NOT NULL,
  role_id     BIGINT UNSIGNED NOT NULL,
  assigned_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  assigned_by BIGINT UNSIGNED NULL, -- which user assigned the role
  PRIMARY KEY (user_id, role_id),
  KEY idx_user_roles_role_id (role_id),
  KEY idx_user_roles_assigned_by (assigned_by),
  CONSTRAINT fk_user_roles_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_user_roles_role
    FOREIGN KEY (role_id) REFERENCES roles(id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_user_roles_assigned_by
    FOREIGN KEY (assigned_by) REFERENCES users(id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- PROJECTS
CREATE TABLE projects (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name          VARCHAR(200) NOT NULL,
  description   TEXT NULL,
  status        ENUM('PLANNING','ACTIVE','ON_HOLD','COMPLETED','CANCELLED') NOT NULL DEFAULT 'PLANNING',
  start_date    DATE NULL,
  end_date      DATE NULL,
  owner_id      BIGINT UNSIGNED NULL, -- project owner (user)
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_projects_owner_id (owner_id),
  KEY idx_projects_status (status),
  CONSTRAINT fk_projects_owner
    FOREIGN KEY (owner_id) REFERENCES users(id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- TASKS
CREATE TABLE tasks (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  project_id     BIGINT UNSIGNED NULL,
  title          VARCHAR(255) NOT NULL,
  description    TEXT NULL,
  priority       ENUM('LOW','MEDIUM','HIGH','CRITICAL') NOT NULL DEFAULT 'MEDIUM',
  status         ENUM('TODO','IN_PROGRESS','REVIEW','DONE','BLOCKED') NOT NULL DEFAULT 'TODO',
  created_by     BIGINT UNSIGNED NOT NULL, -- creator user id
  assignee_id    BIGINT UNSIGNED NULL,     -- assigned user id
  due_date       DATETIME NULL,
  started_at     DATETIME NULL,
  completed_at   DATETIME NULL,
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_tasks_project_id (project_id),
  KEY idx_tasks_assignee_id (assignee_id),
  KEY idx_tasks_status (status),
  KEY idx_tasks_priority (priority),
  KEY idx_tasks_due_date (due_date),
  CONSTRAINT fk_tasks_project
    FOREIGN KEY (project_id) REFERENCES projects(id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_tasks_created_by
    FOREIGN KEY (created_by) REFERENCES users(id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_tasks_assignee
    FOREIGN KEY (assignee_id) REFERENCES users(id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- MEETINGS
CREATE TABLE meetings (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  title          VARCHAR(255) NOT NULL,
  description    TEXT NULL,
  organizer_id   BIGINT UNSIGNED NOT NULL, -- user who created/organizes
  start_time     DATETIME NOT NULL,
  end_time       DATETIME NOT NULL,
  location       VARCHAR(255) NULL,        -- physical or virtual link
  status         ENUM('SCHEDULED','IN_PROGRESS','COMPLETED','CANCELLED') NOT NULL DEFAULT 'SCHEDULED',
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_meetings_organizer_id (organizer_id),
  KEY idx_meetings_start_end (start_time, end_time),
  KEY idx_meetings_status (status),
  CONSTRAINT fk_meetings_organizer
    FOREIGN KEY (organizer_id) REFERENCES users(id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_meetings_time CHECK (end_time > start_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- MEETING_PARTICIPANTS (many-to-many between meetings and users with status)
CREATE TABLE meeting_participants (
  meeting_id   BIGINT UNSIGNED NOT NULL,
  user_id      BIGINT UNSIGNED NOT NULL,
  response     ENUM('INVITED','ACCEPTED','DECLINED','TENTATIVE') NOT NULL DEFAULT 'INVITED',
  checked_in_at DATETIME NULL,
  PRIMARY KEY (meeting_id, user_id),
  KEY idx_mp_user_id (user_id),
  KEY idx_mp_response (response),
  CONSTRAINT fk_mp_meeting
    FOREIGN KEY (meeting_id) REFERENCES meetings(id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_mp_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ATTENDANCE
CREATE TABLE attendance (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id        BIGINT UNSIGNED NOT NULL,
  check_in_time  DATETIME NOT NULL,
  check_out_time DATETIME NULL,
  method         ENUM('GPS','MANUAL','FACE') NOT NULL,
  latitude       DECIMAL(10,7) NULL,
  longitude      DECIMAL(10,7) NULL,
  note           VARCHAR(255) NULL,
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_attendance_user_id (user_id),
  KEY idx_attendance_check_in (check_in_time),
  KEY idx_attendance_method (method),
  CONSTRAINT fk_attendance_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_checkout_after_checkin CHECK (check_out_time IS NULL OR check_out_time >= check_in_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- LEAVES
CREATE TABLE leaves (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id        BIGINT UNSIGNED NOT NULL,    -- requester
  approver_id    BIGINT UNSIGNED NULL,        -- approver user
  type           ENUM('SICK','CASUAL','ANNUAL','UNPAID','OTHER') NOT NULL,
  status         ENUM('PENDING','APPROVED','REJECTED','CANCELLED') NOT NULL DEFAULT 'PENDING',
  start_date     DATE NOT NULL,
  end_date       DATE NOT NULL,
  reason         VARCHAR(255) NULL,
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_leaves_user_id (user_id),
  KEY idx_leaves_approver_id (approver_id),
  KEY idx_leaves_status (status),
  CONSTRAINT fk_leaves_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_leaves_approver
    FOREIGN KEY (approver_id) REFERENCES users(id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT chk_leave_dates CHECK (end_date >= start_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- NOTIFICATIONS
CREATE TABLE notifications (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id       BIGINT UNSIGNED NOT NULL, -- recipient
  title         VARCHAR(200) NOT NULL,
  body          VARCHAR(1000) NULL,
  channel       ENUM('EMAIL','DESKTOP','PUSH','SMS','IN_APP') NOT NULL DEFAULT 'IN_APP',
  is_read       TINYINT(1) NOT NULL DEFAULT 0,
  metadata      JSON NULL, -- flexible payload (e.g., deep links)
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  read_at       DATETIME NULL,
  PRIMARY KEY (id),
  KEY idx_notifications_user_id (user_id),
  KEY idx_notifications_is_read (is_read),
  KEY idx_notifications_channel (channel),
  CONSTRAINT fk_notifications_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- REPORTS (analytics snapshots or generated report jobs)
CREATE TABLE reports (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  created_by    BIGINT UNSIGNED NOT NULL,
  type          ENUM('ATTENDANCE','TASKS','PROJECTS','LEAVES','MEETINGS','CUSTOM') NOT NULL,
  parameters    JSON NULL,
  status        ENUM('QUEUED','RUNNING','COMPLETED','FAILED') NOT NULL DEFAULT 'QUEUED',
  result_url    VARCHAR(512) NULL, -- link to exported file or dashboard
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  completed_at  DATETIME NULL,
  PRIMARY KEY (id),
  KEY idx_reports_created_by (created_by),
  KEY idx_reports_status (status),
  KEY idx_reports_type (type),
  CONSTRAINT fk_reports_created_by
    FOREIGN KEY (created_by) REFERENCES users(id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;
