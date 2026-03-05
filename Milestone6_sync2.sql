-- ============================================================
-- AetherMart M6: Real-time Sync - Consolidated & Order-Corrected
-- Based on your milestone1.sql and generator.py
-- ============================================================
USE aethermart_db;

-- ============================================================
-- 1. PRODUCT SYNC LOGIC (Strictly Matching milestone1.sql)
--    Table: Products (product_id, product_name, price)
-- ============================================================
DROP TABLE IF EXISTS product_sync_queue;
CREATE TABLE product_sync_queue (
    queue_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    product_name VARCHAR(255),
    price DECIMAL(10, 2),
    sync_status VARCHAR(50) DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY idx_sync_status (sync_status)
);

DELIMITER //

DROP PROCEDURE IF EXISTS sp_enqueue_product_sync //
CREATE PROCEDURE sp_enqueue_product_sync(
    IN p_product_id INT,
    IN p_product_name VARCHAR(255),
    IN p_price DECIMAL(10, 2)
)
BEGIN
    INSERT INTO product_sync_queue (product_id, product_name, price, sync_status)
    VALUES (p_product_id, p_product_name, p_price, 'PENDING');
END //

DROP TRIGGER IF EXISTS trg_after_product_insert //
CREATE TRIGGER trg_after_product_insert
AFTER INSERT ON Products
FOR EACH ROW
BEGIN
    CALL sp_enqueue_product_sync(NEW.product_id, NEW.product_name, NEW.price);
END //

DROP TRIGGER IF EXISTS trg_after_product_update //
CREATE TRIGGER trg_after_product_update
AFTER UPDATE ON Products
FOR EACH ROW
BEGIN
    IF OLD.product_name <> NEW.product_name OR
       OLD.price <> NEW.price THEN
        CALL sp_enqueue_product_sync(NEW.product_id, NEW.product_name, NEW.price);
    END IF;
END //

DELIMITER ;

-- ============================================================
-- 2. CUSTOMER SYNC LOGIC (Strictly Matching generator.py)
--    Table: Customers (customer_id, first_name, last_name, email, city, state, zipcode)
-- ============================================================
DROP TABLE IF EXISTS customer_sync_queue;
CREATE TABLE customer_sync_queue (
    queue_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    email VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(50),
    zipcode VARCHAR(20),
    sync_status VARCHAR(50) DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY idx_sync_status (sync_status)
);

DELIMITER //

DROP PROCEDURE IF EXISTS sp_enqueue_customer_sync //
CREATE PROCEDURE sp_enqueue_customer_sync(
    IN p_customer_id INT,
    IN p_first_name VARCHAR(255),
    IN p_last_name VARCHAR(255),
    IN p_email VARCHAR(255),
    IN p_city VARCHAR(100),
    IN p_state VARCHAR(50),
    IN p_zipcode VARCHAR(20)
)
BEGIN
    -- Ensure the order here matches the CREATE TABLE and the IN parameters
    INSERT INTO customer_sync_queue (customer_id, first_name, last_name, email, city, state, zipcode, sync_status)
    VALUES (p_customer_id, p_first_name, p_last_name, p_email, p_city, p_state, p_zipcode, 'PENDING');
END //

DROP TRIGGER IF EXISTS trg_after_customer_insert //
CREATE TRIGGER trg_after_customer_insert
AFTER INSERT ON Customers
FOR EACH ROW
BEGIN
    -- Ensure the order here matches sp_enqueue_customer_sync's IN parameters
    CALL sp_enqueue_customer_sync(NEW.customer_id, NEW.first_name, NEW.last_name, NEW.email, NEW.city, NEW.state, NEW.zipcode);
END //

DROP TRIGGER IF EXISTS trg_after_customer_update //
CREATE TRIGGER trg_after_customer_update
AFTER UPDATE ON Customers
FOR EACH ROW
BEGIN
    IF OLD.first_name <> NEW.first_name OR
       OLD.last_name <> NEW.last_name OR
       OLD.email <> NEW.email OR
       OLD.city <> NEW.city OR
       OLD.state <> NEW.state OR
       OLD.zipcode <> NEW.zipcode THEN
        -- Ensure the order here matches sp_enqueue_customer_sync's IN parameters
        CALL sp_enqueue_customer_sync(NEW.customer_id, NEW.first_name, NEW.last_name, NEW.email, NEW.city, NEW.state, NEW.zipcode);
    END IF;
END //

DELIMITER ;

-- ============================================================
-- 3. REVIEW SYNC LOGIC (Strictly Matching generator.py)
--    Table: Reviews (review_id, customer_id, product_id, rating, review_text, review_date)
-- ============================================================
DROP TABLE IF EXISTS review_sync_queue;
CREATE TABLE review_sync_queue (
    queue_id INT AUTO_INCREMENT PRIMARY KEY,
    review_id INT NOT NULL,
    customer_id INT,
    product_id INT,
    rating DECIMAL(3,2),
    review_text TEXT,
    review_date DATE,
    sync_status VARCHAR(50) DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY idx_sync_status (sync_status)
);

DELIMITER //

DROP PROCEDURE IF EXISTS sp_enqueue_review_sync //
CREATE PROCEDURE sp_enqueue_review_sync(
    IN p_review_id INT,
    IN p_customer_id INT,
    IN p_product_id INT,
    IN p_rating DECIMAL(3,2),
    IN p_review_text TEXT,
    IN p_review_date DATE
)
BEGIN
    -- Ensure the order here matches the CREATE TABLE and the IN parameters
    INSERT INTO review_sync_queue (review_id, customer_id, product_id, rating, review_text, review_date, sync_status)
    VALUES (p_review_id, p_customer_id, p_product_id, p_rating, p_review_text, p_review_date, 'PENDING');
END //

DROP TRIGGER IF EXISTS trg_after_review_insert //
CREATE TRIGGER trg_after_review_insert
AFTER INSERT ON Reviews
FOR EACH ROW
BEGIN
    -- Ensure the order here matches sp_enqueue_review_sync's IN parameters
    CALL sp_enqueue_review_sync(NEW.review_id, NEW.customer_id, NEW.product_id, NEW.rating, NEW.review_text, NEW.review_date);
END //

DROP TRIGGER IF EXISTS trg_after_review_update //
CREATE TRIGGER trg_after_review_update
AFTER UPDATE ON Reviews
FOR EACH ROW
BEGIN
    IF OLD.rating <> NEW.rating OR
       OLD.review_text <> NEW.review_text OR
       OLD.review_date <> NEW.review_date THEN
        -- Ensure the order here matches sp_enqueue_review_sync's IN parameters
        CALL sp_enqueue_review_sync(NEW.review_id, NEW.customer_id, NEW.product_id, NEW.rating, NEW.review_text, NEW.review_date);
    END IF;
END //

DELIMITER ;