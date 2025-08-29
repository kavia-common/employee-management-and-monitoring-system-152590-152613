-- 002_seed_data.sql
-- Seed baseline reference data and sample records for development.
USE `myapp`;

-- Seed roles
INSERT INTO roles (name, description)
VALUES 
  ('SUPER_ADMIN', 'Platform super administrator'),
  ('MANAGER', 'Department or project manager'),
  ('TEAM_LEAD', 'Team leader'),
  ('EMPLOYEE', 'Regular employee')
ON DUPLICATE KEY UPDATE description = VALUES(description);

-- Seed users (password_hash should be set by backend; demo only)
INSERT INTO users (uid, email, password_hash, first_name, last_name, phone, is_active)
VALUES
  ('ext-superadmin-uid', 'superadmin@example.com', '$2b$10$examplehashsuperadmin', 'Super', 'Admin', '+10000000001', 1),
  ('ext-manager-uid', 'manager@example.com', '$2b$10$examplehashmanager', 'Manny', 'Ger', '+10000000002', 1),
  ('ext-lead-uid', 'lead@example.com', '$2b$10$examplehashlead', 'Lea', 'Der', '+10000000003', 1),
  ('ext-employee-uid', 'employee@example.com', '$2b$10$examplehashemployee', 'Em', 'Ployee', '+10000000004', 1)
ON DUPLICATE KEY UPDATE first_name = VALUES(first_name), last_name = VALUES(last_name);

-- Map roles
INSERT INTO user_roles (user_id, role_id, assigned_at)
SELECT u.id, r.id, NOW()
FROM users u
JOIN roles r
WHERE (u.email = 'superadmin@example.com' AND r.name = 'SUPER_ADMIN')
   OR (u.email = 'manager@example.com' AND r.name = 'MANAGER')
   OR (u.email = 'lead@example.com' AND r.name = 'TEAM_LEAD')
   OR (u.email = 'employee@example.com' AND r.name = 'EMPLOYEE');

-- Seed a sample project
INSERT INTO projects (name, description, status, start_date, owner_id)
SELECT 'Onboarding Project', 'Initial onboarding and setup project', 'ACTIVE', CURDATE(), u.id
FROM users u
WHERE u.email = 'manager@example.com'
LIMIT 1;

-- Seed sample tasks
INSERT INTO tasks (project_id, title, description, priority, status, created_by, assignee_id, due_date)
SELECT p.id, 'Setup repository', 'Initialize monorepo and CI', 'HIGH', 'IN_PROGRESS', creator.id, assignee.id, DATE_ADD(NOW(), INTERVAL 7 DAY)
FROM projects p
JOIN users creator ON creator.email = 'manager@example.com'
JOIN users assignee ON assignee.email = 'lead@example.com'
LIMIT 1;

INSERT INTO tasks (project_id, title, description, priority, status, created_by, assignee_id, due_date)
SELECT p.id, 'Prepare database schema', 'Design normalized schema and migrations', 'CRITICAL', 'TODO', creator.id, assignee.id, DATE_ADD(NOW(), INTERVAL 5 DAY)
FROM projects p
JOIN users creator ON creator.email = 'lead@example.com'
JOIN users assignee ON assignee.email = 'employee@example.com'
LIMIT 1;

-- Seed a meeting and participants
INSERT INTO meetings (title, description, organizer_id, start_time, end_time, location, status)
SELECT 'Kickoff Meeting', 'Project kickoff and scope alignment', organizer.id, DATE_ADD(NOW(), INTERVAL 1 DAY), DATE_ADD(NOW(), INTERVAL 1 DAY + 1 HOUR), 'Conference Room A', 'SCHEDULED'
FROM users organizer
WHERE organizer.email = 'manager@example.com'
LIMIT 1;

INSERT INTO meeting_participants (meeting_id, user_id, response)
SELECT m.id, u.id, 'INVITED'
FROM meetings m
CROSS JOIN users u
WHERE m.title = 'Kickoff Meeting'
  AND u.email IN ('lead@example.com', 'employee@example.com');

-- Seed attendance sample
INSERT INTO attendance (user_id, check_in_time, method, latitude, longitude, note)
SELECT u.id, DATE_SUB(NOW(), INTERVAL 2 HOUR), 'MANUAL', NULL, NULL, 'Morning check-in'
FROM users u
WHERE u.email = 'employee@example.com'
LIMIT 1;

-- Seed a leave request
INSERT INTO leaves (user_id, approver_id, type, status, start_date, end_date, reason)
SELECT requester.id, approver.id, 'ANNUAL', 'PENDING', DATE_ADD(CURDATE(), INTERVAL 10 DAY), DATE_ADD(CURDATE(), INTERVAL 12 DAY), 'Family event'
FROM users requester
JOIN users approver ON approver.email = 'manager@example.com'
WHERE requester.email = 'employee@example.com'
LIMIT 1;

-- Seed a notification
INSERT INTO notifications (user_id, title, body, channel, is_read, metadata)
SELECT u.id, 'Welcome', 'Your account has been created successfully.', 'IN_APP', 0, JSON_OBJECT('action', 'open_dashboard')
FROM users u
WHERE u.email = 'employee@example.com'
LIMIT 1;

-- Seed a report job
INSERT INTO reports (created_by, type, parameters, status)
SELECT u.id, 'ATTENDANCE', JSON_OBJECT('range', 'last_7_days'), 'QUEUED'
FROM users u
WHERE u.email = 'manager@example.com'
LIMIT 1;
