-- SQL Test File for Theme Validation
-- Testing syntax highlighting for various SQL dialects and features

-- Database and table creation
CREATE DATABASE IF NOT EXISTS user_management_system;
USE user_management_system;

-- User roles enum table
CREATE TABLE user_roles (
    id INT PRIMARY KEY AUTO_INCREMENT,
    role_name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Users table with various constraints
CREATE TABLE users (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    uuid CHAR(36) UNIQUE NOT NULL DEFAULT (UUID()),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE,
    phone_number VARCHAR(20),
    role_id INT NOT NULL,
    status ENUM('active', 'inactive', 'pending', 'suspended') DEFAULT 'pending',
    email_verified BOOLEAN DEFAULT FALSE,
    last_login TIMESTAMP NULL,
    failed_login_attempts INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Foreign key constraints
    FOREIGN KEY (role_id) REFERENCES user_roles(id) ON DELETE RESTRICT,

    -- Check constraints
    CONSTRAINT chk_email_format CHECK (email REGEXP '^[^@]+@[^@]+\.[^@]+$'),
    CONSTRAINT chk_birth_date CHECK (date_of_birth <= CURDATE()),
    CONSTRAINT chk_failed_attempts CHECK (failed_login_attempts >= 0 AND failed_login_attempts <= 10)
);

-- User profiles table with JSON support
CREATE TABLE user_profiles (
    user_id BIGINT PRIMARY KEY,
    bio TEXT,
    avatar_url VARCHAR(500),
    social_links JSON,
    preferences JSON,
    metadata JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- User sessions table
CREATE TABLE user_sessions (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    session_token VARCHAR(255) UNIQUE NOT NULL,
    ip_address INET_ATON,
    user_agent TEXT,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,

    INDEX idx_user_sessions_token (session_token),
    INDEX idx_user_sessions_user_id (user_id),
    INDEX idx_user_sessions_expires (expires_at)
);

-- Audit log table
CREATE TABLE audit_logs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT,
    action VARCHAR(100) NOT NULL,
    table_name VARCHAR(100),
    record_id BIGINT,
    old_values JSON,
    new_values JSON,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,

    INDEX idx_audit_user_id (user_id),
    INDEX idx_audit_action (action),
    INDEX idx_audit_created_at (created_at)
);

-- Insert initial data
INSERT INTO user_roles (role_name, description) VALUES
('admin', 'System administrator with full access'),
('moderator', 'Content moderator with limited admin access'),
('user', 'Standard user with basic access'),
('guest', 'Guest user with read-only access');

-- Sample users data
INSERT INTO users (username, email, password_hash, first_name, last_name, date_of_birth, phone_number, role_id, status, email_verified) VALUES
('admin_user', 'admin@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj1Q.2qhY5bK', 'Admin', 'User', '1990-01-15', '+1-555-0101', 1, 'active', TRUE),
('john_doe', 'john.doe@example.com', '$2b$12$4dMKmr1jN8K9QzQ5Y2Ng9ez8VzxWdJ2BkLgE1HdY8YzK3MnO4pQzK', 'John', 'Doe', '1985-06-22', '+1-555-0102', 3, 'active', TRUE),
('jane_smith', 'jane.smith@example.com', '$2b$12$8vPKjQ3N1zQ7YzKm2Ng9ez8VzxWdJ2BkLgE1HdY8YzK3MnO4pQzK', 'Jane', 'Smith', '1992-03-10', '+1-555-0103', 2, 'active', TRUE),
('guest_user', 'guest@example.com', '$2b$12$2nQz4K8mPjN2zQ9YzKm2Ng9ez8VzxWdJ2BkLgE1HdY8YzK3MnO4pQ', 'Guest', 'User', '1995-12-05', NULL, 4, 'pending', FALSE);

-- Insert user profiles with JSON data
INSERT INTO user_profiles (user_id, bio, avatar_url, social_links, preferences, metadata) VALUES
(1, 'System administrator managing the platform', 'https://example.com/avatars/admin.jpg',
 '{"twitter": "@admin_user", "linkedin": "linkedin.com/in/adminuser"}',
 '{"theme": "dark", "notifications": {"email": true, "push": true}, "language": "en"}',
 '{"department": "IT", "employee_id": "EMP001"}'),

(2, 'Software developer passionate about creating amazing applications', 'https://example.com/avatars/john.jpg',
 '{"github": "github.com/johndoe", "twitter": "@john_dev", "website": "johndoe.dev"}',
 '{"theme": "light", "notifications": {"email": true, "push": false}, "language": "en", "timezone": "America/New_York"}',
 '{"skills": ["JavaScript", "Python", "SQL"], "experience_years": 8}'),

(3, 'Content moderator ensuring quality and safety', 'https://example.com/avatars/jane.jpg',
 '{"linkedin": "linkedin.com/in/janesmith", "instagram": "@jane_content"}',
 '{"theme": "auto", "notifications": {"email": true, "push": true}, "language": "en", "timezone": "America/Los_Angeles"}',
 '{"department": "Content", "specialization": "Community Management"}');

-- Complex queries demonstrating various SQL features

-- 1. Common Table Expression (CTE) with window functions
WITH user_stats AS (
    SELECT
        u.id,
        u.username,
        u.first_name,
        u.last_name,
        ur.role_name,
        u.created_at,
        DATEDIFF(CURDATE(), u.created_at) AS days_since_registration,
        ROW_NUMBER() OVER (PARTITION BY u.role_id ORDER BY u.created_at) AS role_rank,
        COUNT(*) OVER (PARTITION BY u.role_id) AS users_in_role,
        LAG(u.created_at) OVER (ORDER BY u.created_at) AS prev_user_registration
    FROM users u
    JOIN user_roles ur ON u.role_id = ur.id
    WHERE u.status = 'active'
),
role_summary AS (
    SELECT
        role_name,
        COUNT(*) as user_count,
        AVG(days_since_registration) as avg_days_registered,
        MIN(created_at) as first_registration,
        MAX(created_at) as last_registration
    FROM user_stats
    GROUP BY role_name
)
SELECT
    us.*,
    rs.user_count as total_in_role,
    rs.avg_days_registered as role_avg_days
FROM user_stats us
JOIN role_summary rs ON us.role_name = rs.role_name
ORDER BY us.created_at DESC;

-- 2. Recursive CTE for hierarchical data (if we had a hierarchy)
WITH RECURSIVE user_hierarchy AS (
    -- Base case: top-level users (admins)
    SELECT
        id,
        username,
        role_id,
        1 as level,
        CAST(username AS CHAR(1000)) as path
    FROM users
    WHERE role_id = 1

    UNION ALL

    -- Recursive case: users managed by higher-level users
    SELECT
        u.id,
        u.username,
        u.role_id,
        uh.level + 1,
        CONCAT(uh.path, ' -> ', u.username)
    FROM users u
    JOIN user_hierarchy uh ON u.role_id = uh.role_id + 1
    WHERE uh.level < 5
)
SELECT * FROM user_hierarchy ORDER BY level, username;

-- 3. Complex aggregation with multiple joins and subqueries
SELECT
    u.id,
    u.username,
    u.email,
    ur.role_name,
    CASE
        WHEN u.last_login >= DATE_SUB(NOW(), INTERVAL 7 DAY) THEN 'Active'
        WHEN u.last_login >= DATE_SUB(NOW(), INTERVAL 30 DAY) THEN 'Recent'
        WHEN u.last_login IS NOT NULL THEN 'Inactive'
        ELSE 'Never Logged In'
    END AS activity_status,
    COALESCE(session_count.active_sessions, 0) AS active_sessions,
    COALESCE(audit_count.recent_actions, 0) AS recent_actions,
    JSON_EXTRACT(up.preferences, '$.theme') AS preferred_theme,
    JSON_EXTRACT(up.preferences, '$.language') AS preferred_language,
    DATEDIFF(CURDATE(), u.date_of_birth) / 365 AS age_years
FROM users u
LEFT JOIN user_roles ur ON u.role_id = ur.id
LEFT JOIN user_profiles up ON u.id = up.user_id
LEFT JOIN (
    SELECT
        user_id,
        COUNT(*) AS active_sessions
    FROM user_sessions
    WHERE expires_at > NOW()
    GROUP BY user_id
) session_count ON u.id = session_count.user_id
LEFT JOIN (
    SELECT
        user_id,
        COUNT(*) AS recent_actions
    FROM audit_logs
    WHERE created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
    GROUP BY user_id
) audit_count ON u.id = audit_count.user_id
WHERE u.status IN ('active', 'pending')
ORDER BY
    FIELD(ur.role_name, 'admin', 'moderator', 'user', 'guest'),
    u.last_login DESC NULLS LAST;

-- 4. Stored procedures and functions
DELIMITER $$

-- Function to calculate user score
CREATE FUNCTION calculate_user_score(user_id BIGINT)
RETURNS DECIMAL(5,2)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE score DECIMAL(5,2) DEFAULT 0.0;
    DECLARE days_registered INT;
    DECLARE login_frequency DECIMAL(5,2);
    DECLARE recent_actions INT;

    -- Get basic user info
    SELECT DATEDIFF(CURDATE(), created_at) INTO days_registered
    FROM users WHERE id = user_id;

    -- Calculate login frequency (logins per day)
    SELECT COALESCE(COUNT(*) / GREATEST(days_registered, 1), 0) INTO login_frequency
    FROM audit_logs
    WHERE user_id = user_id AND action = 'login';

    -- Get recent activity count
    SELECT COUNT(*) INTO recent_actions
    FROM audit_logs
    WHERE user_id = user_id
    AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY);

    -- Calculate score based on various factors
    SET score = LEAST(100.0,
        (days_registered * 0.1) +
        (login_frequency * 20) +
        (recent_actions * 0.5)
    );

    RETURN score;
END$$

-- Procedure to update user status with audit logging
CREATE PROCEDURE update_user_status(
    IN p_user_id BIGINT,
    IN p_new_status VARCHAR(20),
    IN p_admin_user_id BIGINT,
    IN p_reason TEXT
)
BEGIN
    DECLARE old_status VARCHAR(20);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Get current status
    SELECT status INTO old_status FROM users WHERE id = p_user_id;

    -- Update user status
    UPDATE users
    SET status = p_new_status, updated_at = NOW()
    WHERE id = p_user_id;

    -- Log the change
    INSERT INTO audit_logs (user_id, action, table_name, record_id, old_values, new_values)
    VALUES (
        p_admin_user_id,
        'status_change',
        'users',
        p_user_id,
        JSON_OBJECT('status', old_status),
        JSON_OBJECT('status', p_new_status, 'reason', p_reason)
    );

    COMMIT;
END$$

DELIMITER ;

-- 5. Views for common queries
CREATE VIEW active_user_summary AS
SELECT
    u.id,
    u.username,
    u.email,
    u.first_name,
    u.last_name,
    ur.role_name,
    u.created_at,
    u.last_login,
    calculate_user_score(u.id) AS user_score,
    JSON_EXTRACT(up.preferences, '$.theme') AS theme_preference
FROM users u
JOIN user_roles ur ON u.role_id = ur.id
LEFT JOIN user_profiles up ON u.id = up.user_id
WHERE u.status = 'active' AND u.email_verified = TRUE;

-- Materialized view simulation (MySQL doesn't have materialized views)
CREATE TABLE user_analytics_cache AS
SELECT
    DATE(created_at) as registration_date,
    role_id,
    COUNT(*) as registrations,
    COUNT(CASE WHEN status = 'active' THEN 1 END) as active_users,
    COUNT(CASE WHEN email_verified = TRUE THEN 1 END) as verified_users,
    AVG(failed_login_attempts) as avg_failed_attempts
FROM users
GROUP BY DATE(created_at), role_id;

-- 6. Triggers for automatic audit logging
DELIMITER $$

CREATE TRIGGER users_audit_insert
AFTER INSERT ON users
FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (user_id, action, table_name, record_id, new_values)
    VALUES (
        NEW.id,
        'create',
        'users',
        NEW.id,
        JSON_OBJECT(
            'username', NEW.username,
            'email', NEW.email,
            'status', NEW.status,
            'role_id', NEW.role_id
        )
    );
END$$

CREATE TRIGGER users_audit_update
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (user_id, action, table_name, record_id, old_values, new_values)
    VALUES (
        NEW.id,
        'update',
        'users',
        NEW.id,
        JSON_OBJECT(
            'username', OLD.username,
            'email', OLD.email,
            'status', OLD.status,
            'last_login', OLD.last_login
        ),
        JSON_OBJECT(
            'username', NEW.username,
            'email', NEW.email,
            'status', NEW.status,
            'last_login', NEW.last_login
        )
    );
END$$

DELIMITER ;

-- 7. Advanced query examples

-- Pivot table simulation for user registration by month and role
SELECT
    DATE_FORMAT(created_at, '%Y-%m') as month,
    SUM(CASE WHEN role_id = 1 THEN 1 ELSE 0 END) as admin_registrations,
    SUM(CASE WHEN role_id = 2 THEN 1 ELSE 0 END) as moderator_registrations,
    SUM(CASE WHEN role_id = 3 THEN 1 ELSE 0 END) as user_registrations,
    SUM(CASE WHEN role_id = 4 THEN 1 ELSE 0 END) as guest_registrations,
    COUNT(*) as total_registrations
FROM users
WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
GROUP BY DATE_FORMAT(created_at, '%Y-%m')
ORDER BY month DESC;

-- Running totals and percentages
SELECT
    username,
    created_at,
    ROW_NUMBER() OVER (ORDER BY created_at) as user_number,
    COUNT(*) OVER (ORDER BY created_at ROWS UNBOUNDED PRECEDING) as running_total,
    ROUND(
        100.0 * COUNT(*) OVER (ORDER BY created_at ROWS UNBOUNDED PRECEDING) /
        COUNT(*) OVER (),
        2
    ) as cumulative_percentage
FROM users
ORDER BY created_at;

-- Complex conditional aggregation
SELECT
    ur.role_name,
    COUNT(*) as total_users,
    COUNT(CASE WHEN u.status = 'active' THEN 1 END) as active_users,
    COUNT(CASE WHEN u.email_verified = TRUE THEN 1 END) as verified_users,
    COUNT(CASE WHEN u.last_login >= DATE_SUB(NOW(), INTERVAL 30 DAY) THEN 1 END) as recent_logins,
    ROUND(AVG(DATEDIFF(CURDATE(), u.created_at)), 1) as avg_days_registered,
    MIN(u.created_at) as first_registration,
    MAX(u.created_at) as latest_registration,
    ROUND(100.0 * COUNT(CASE WHEN u.status = 'active' THEN 1 END) / COUNT(*), 2) as active_percentage
FROM user_roles ur
LEFT JOIN users u ON ur.id = u.role_id
GROUP BY ur.id, ur.role_name
HAVING COUNT(*) > 0
ORDER BY total_users DESC;

-- 8. Index optimization examples
CREATE INDEX idx_users_status_verified ON users(status, email_verified);
CREATE INDEX idx_users_role_created ON users(role_id, created_at);
CREATE INDEX idx_users_last_login ON users(last_login);
CREATE INDEX idx_audit_logs_composite ON audit_logs(user_id, action, created_at);

-- JSON field indexing (MySQL 5.7+)
ALTER TABLE user_profiles ADD INDEX idx_theme ((CAST(preferences->'$.theme' AS CHAR(20))));
ALTER TABLE user_profiles ADD INDEX idx_language ((CAST(preferences->'$.language' AS CHAR(10))));

-- 9. Performance analysis queries
EXPLAIN FORMAT=JSON
SELECT u.*, ur.role_name, up.bio
FROM users u
JOIN user_roles ur ON u.role_id = ur.id
LEFT JOIN user_profiles up ON u.id = up.user_id
WHERE u.status = 'active'
AND u.created_at >= DATE_SUB(NOW(), INTERVAL 1 YEAR)
ORDER BY u.last_login DESC
LIMIT 50;

-- 10. Cleanup and maintenance queries
-- Remove expired sessions
DELETE FROM user_sessions WHERE expires_at < NOW();

-- Archive old audit logs
CREATE TABLE audit_logs_archive AS
SELECT * FROM audit_logs
WHERE created_at < DATE_SUB(NOW(), INTERVAL 1 YEAR);

DELETE FROM audit_logs
WHERE created_at < DATE_SUB(NOW(), INTERVAL 1 YEAR);

-- Update statistics
ANALYZE TABLE users, user_profiles, user_sessions, audit_logs;

-- Check for orphaned records
SELECT 'Orphaned profiles' as issue, COUNT(*) as count
FROM user_profiles up
LEFT JOIN users u ON up.user_id = u.id
WHERE u.id IS NULL

UNION ALL

SELECT 'Orphaned sessions' as issue, COUNT(*) as count
FROM user_sessions us
LEFT JOIN users u ON us.user_id = u.id
WHERE u.id IS NULL;

-- Final verification queries
SELECT
    'Database Summary' as info,
    (SELECT COUNT(*) FROM users) as total_users,
    (SELECT COUNT(*) FROM user_roles) as total_roles,
    (SELECT COUNT(*) FROM user_sessions WHERE expires_at > NOW()) as active_sessions,
    (SELECT COUNT(*) FROM audit_logs) as total_audit_logs;
