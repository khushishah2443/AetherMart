-- FILE: security.sql
-- Description: Defines data governance tables (lineage, quality), PII masking views,
--              RBAC roles and permissions, and an RBAC audit view for AetherMart Milestone 6.
-- This script should be run after core schema creation (milestone1, milestone2, milestone4).

-- Ensure we are using the correct database
USE aethermart_db;

-- =======================================================
-- 1. Data Governance Tables (Lineage & Quality Logs)
--    These tables are designed to be populated by ETL processes, triggers,
--    or data quality routines to track data flow and issues.
-- =======================================================

-- Table for Data Lineage Tracking
-- Tracks the origin, transformations, and movement of data.
CREATE TABLE IF NOT EXISTS data_lineage_tracker (
    batch_id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    source_system VARCHAR(50),
    target_system VARCHAR(50),
    records_moved INT(11),
    status VARCHAR(200), -- E.g., 'Success', 'Failure', 'In Progress'
    transfer_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    -- Additional fields could include: entity_name, entity_id, operation_type, notes
);
SELECT 'Table data_lineage_tracker created or already exists.' AS Message;

-- Table for Data Quality Logs
-- Records detected data quality issues, their type, severity, and status.
CREATE TABLE IF NOT EXISTS data_quality_logs (
    log_id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(50),
    issue_type VARCHAR(50), -- E.g., 'Invalid Email Format', 'Missing Value', 'Duplicate Record'
    record_id INT(11),      -- The ID of the record that has the quality issue (can be NULL if issue is table-wide)
    detected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    -- Additional fields could include: field_name, detected_value, expected_value, severity, status, notes
);
SELECT 'Table data_quality_logs created or already exists.' AS Message;


-- =======================================================
-- 2. PII Masking View (v_customers_masked)
--    Creates a view that obfuscates sensitive Personally Identifiable Information (PII)
--    for users without direct access to raw PII, ensuring privacy.
-- =====================================================================================
DROP VIEW IF EXISTS v_customers_masked;
CREATE VIEW v_customers_masked AS
SELECT
    customer_id,
    first_name,
    last_name,
    CONCAT(first_name, ' ', last_name) AS full_name, -- Combined for convenience
    CONCAT(SUBSTRING(email, 1, 3), '***@***.com') AS email, -- Masked email
    CONCAT('***-***-', RIGHT(phone_number, 4)) AS phone_number, -- Masked phone
    '*** Masked Address ***' AS address, -- Masked address
    registration_date
FROM Customers;
SELECT 'View v_customers_masked created.' AS Message;


-- =======================================================
-- 3. Governance Summary Report View (v_governance_summary_report)
--    A conceptual view to aggregate high-level governance metrics.
--    (Note: This is a placeholder; actual logic would be more complex)
-- =======================================================
DROP VIEW IF EXISTS v_governance_summary_report;
CREATE VIEW v_governance_summary_report AS
SELECT
    (SELECT COUNT(*) FROM data_lineage_tracker) AS total_lineage_records,
    (SELECT COUNT(*) FROM data_quality_logs WHERE status = 'Open') AS open_data_quality_issues,
    (SELECT COUNT(DISTINCT customer_id) FROM Customers) AS total_customers_tracked,
    (SELECT MAX(transfer_date) FROM data_lineage_tracker) AS last_data_transfer,
    (SELECT MAX(detected_at) FROM data_quality_logs) AS last_quality_issue_detected;
    -- In a real scenario, this would join and aggregate more complex data.
SELECT 'View v_governance_summary_report created.' AS Message;


-- =======================================================
-- 4. RBAC Audit View (v_rbac_audit)
--    A view to track user authentication and DML activities for auditing purposes.
--    Leverages MariaDB's general_log (if enabled) or system tables.
--    NOTE: Requires general_log to be enabled in MariaDB configuration for full DML auditing.
--    For demo, we can rely on information_schema or simpler logs.
-- =======================================================
DROP VIEW IF EXISTS v_rbac_audit;
CREATE VIEW v_rbac_audit AS
SELECT
    event_time AS timestamp,
    user_host AS user_and_host,
    command_type AS action,
    argument AS query_executed
FROM mysql.general_log
WHERE command_type IN ('Query', 'Connect')
AND event_time > NOW() - INTERVAL 1 DAY -- Adjust interval as needed
ORDER BY event_time DESC;
-- Fallback if general_log is not enabled or for simpler systems:
-- Alternatively, you might track connections/disconnections from information_schema.PROCESSLIST
-- Or rely on specific triggers to log DML on sensitive tables.
SELECT 'View v_rbac_audit created (requires mysql.general_log for full functionality).' AS Message;


-- =======================================================
-- 5. Role-Based Access Control (RBAC) Setup
--    Creating distinct users/roles and granting specific permissions.
--    NOTE: Passwords should be changed for production.
-- =======================================================

-- Create Users (if they don't exist)
CREATE USER IF NOT EXISTS 'alex'@'localhost' IDENTIFIED BY 'alex_pass'; -- CTO
CREATE USER IF NOT EXISTS 'sarah'@'localhost' IDENTIFIED BY 'sarah_pass'; -- Operations Lead
CREATE USER IF NOT EXISTS 'maria'@'localhost' IDENTIFIED BY 'maria_pass'; -- Marketing Lead
CREATE USER IF NOT EXISTS 'finance'@'localhost' IDENTIFIED BY 'finance_pass'; -- Financial Analyst
-- The 'mongo_sync_user' will be handled by the Python script's connection
SELECT 'RBAC Users created or already exist.' AS Message;

-- Grant Permissions

-- Alex (CTO): Full Admin/Root Access (for demonstration and oversight)
GRANT ALL PRIVILEGES ON aethermart_db.* TO 'alex'@'localhost';
GRANT SELECT ON mysql.general_log TO 'alex'@'localhost'; -- For v_rbac_audit
FLUSH PRIVILEGES;
SELECT 'Permissions granted for Alex (CTO).' AS Message;


-- Sarah (Operations Lead): Read/Write to Core Operational Tables
GRANT SELECT, INSERT, UPDATE, DELETE ON aethermart_db.Customers TO 'sarah'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON aethermart_db.Products TO 'sarah'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON aethermart_db.Orders TO 'sarah'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON aethermart_db.Order_Items TO 'sarah'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON aethermart_db.Reviews TO 'sarah'@'localhost';
-- Sarah should also be able to read Lineage/Quality logs for operational awareness
GRANT SELECT ON aethermart_db.data_lineage_tracker TO 'sarah'@'localhost';
GRANT SELECT ON aethermart_db.data_quality_logs TO 'sarah'@'localhost';
FLUSH PRIVILEGES;
SELECT 'Permissions granted for Sarah (Operations Lead).' AS Message;


-- Maria (Marketing Lead): Read-only Analytical Access, PII Protected
GRANT SELECT ON aethermart_db.Products TO 'maria'@'localhost';
GRANT SELECT ON aethermart_db.Orders TO 'maria'@'localhost';
GRANT SELECT ON aethermart_db.Reviews TO 'maria'@'localhost';
GRANT SELECT ON aethermart_db.v_customers_masked TO 'maria'@'localhost'; -- Access via masked view
-- Deny direct access to raw PII tables for Maria
REVOKE SELECT ON aethermart_db.Customers FROM 'maria'@'localhost';
FLUSH PRIVILEGES;
SELECT 'Permissions granted for Maria (Marketing Lead).' AS Message;


-- Finance Analyst: Read-only for Financial Reporting
GRANT SELECT ON aethermart_db.Orders TO 'finance'@'localhost';
GRANT SELECT ON aethermart_db.Order_Items TO 'finance'@'localhost';
GRANT SELECT ON aethermart_db.Products TO 'finance'@'localhost'; -- For product costs in orders
FLUSH PRIVILEGES;
SELECT 'Permissions granted for Finance Analyst.' AS Message;


-- Special User for MongoDB Sync Worker (Requires access to sync queues)
-- This user is defined in milestone1.sql or orchestrator.py for consistency.
-- Assuming 'mongo_sync_user' is created by milestone1.sql / orchestrator.py.
-- If not, add: CREATE USER IF NOT EXISTS 'mongo_sync_user'@'localhost' IDENTIFIED BY 'sync_worker_pass';
GRANT SELECT, INSERT, UPDATE, DELETE ON aethermart_db.customer_sync_queue TO 'mongo_sync_user'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON aethermart_db.product_sync_queue TO 'mongo_sync_user'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON aethermart_db.review_sync_queue TO 'mongo_sync_user'@'localhost';
FLUSH PRIVILEGES;
SELECT 'Permissions granted for mongo_sync_user (Sync Worker).' AS Message;


-- =======================================================
-- FINAL STATUS MESSAGE
-- =======================================================
SELECT 'security.sql execution complete. Governance, PII Masking, RBAC, and Audit components configured.' AS Message;