-- =====================================================================
-- AetherMart Database Milestone 2 - Automation & Advanced Analytics
--
-- Description:
-- This script builds upon Milestone 1 with advanced database features.
-- 1. Alters tables and creates audit/archive/log tables.
-- 2. Implements a robust, multi-event trigger system for order totals,
--    real-time product rating updates, and default rating assignment.
-- 3. Creates Stored Procedures for analytics and manual data archiving.
--
-- !!! IMPORTANT !!!
-- HOW TO RUN:
-- 1. Ensure this file (milestone2.sql) and your final mile1.sql
--    are in the same directory on your Ubuntu server (e.g., /root/).
-- 2. Run this script using a privileged user like root.
--
--    Example Command:
--    mysql --local-infile=1 -u root -p < milestone2.sql
-- =====================================================================

-- Step 1: Source and Execute the Milestone 1 Script
DROP database aethermart_db;

SOURCE mile1.sql;

-- Use the database for all subsequent commands
USE aethermart_db;

--
-- Step 2: Schema Modifications for Milestone 2
--

-- Safely add the total_amount column to Orders
ALTER TABLE `Orders` DROP COLUMN IF EXISTS `total_amount`;
ALTER TABLE `Orders` ADD COLUMN `total_amount` DECIMAL(10, 2) NOT NULL DEFAULT 0.00;

-- Safely add the current_rating column to Products
ALTER TABLE `Products` DROP COLUMN IF EXISTS `current_rating`;
ALTER TABLE `Products` ADD COLUMN `current_rating` DECIMAL(3, 2) NULL;

-- Drop dependent tables first for clean runs
DROP TABLE IF EXISTS `TR_Product_Price_History`;
DROP TABLE IF EXISTS `TR_Orders_Archive`;
DROP TABLE IF EXISTS `TR_Order_Update_Log`;

-- Create an audit table to log price changes
CREATE TABLE `TR_Product_Price_History` (
  `log_id` INT AUTO_INCREMENT PRIMARY KEY,
  `product_id` BIGINT UNSIGNED NOT NULL,
  `old_price` DECIMAL(10, 2) NOT NULL,
  `new_price` DECIMAL(10, 2) NOT NULL,
  `change_timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`product_id`) REFERENCES `Products`(`product_id`) ON DELETE CASCADE
);

-- Create an archive table for old, completed orders
CREATE TABLE `TR_Orders_Archive` (
  `order_id` BIGINT UNSIGNED PRIMARY KEY,
  `customer_id` BIGINT UNSIGNED NOT NULL,
  `order_date` DATE,
  `total_amount` DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
  `archived_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create a new log table to store the history of order total changes
CREATE TABLE `TR_Order_Update_Log` (
    `log_id` INT AUTO_INCREMENT PRIMARY KEY,
    `order_id` BIGINT UNSIGNED,
    `customer_id` BIGINT UNSIGNED,
    `previous_total` DECIMAL(10, 2),
    `new_total` DECIMAL(10, 2),
    `balance_change` DECIMAL(10, 2),
    `update_timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

DROP TRIGGER IF EXISTS tr_after_order_item_insert;
DROP TRIGGER IF EXISTS tr_after_order_item_update;
DROP TRIGGER IF EXISTS tr_after_order_item_delete;
DROP TRIGGER IF EXISTS tr_before_product_price_update;
DROP TRIGGER IF EXISTS tr_after_review_insert;
DROP TRIGGER IF EXISTS tr_after_review_update;
DROP TRIGGER IF EXISTS tr_after_review_delete;
DROP TRIGGER IF EXISTS tr_before_product_insert_set_rating; 
DROP PROCEDURE IF EXISTS sp_update_order_item_quantity;
DROP PROCEDURE IF EXISTS sp_rank_products_by_price;
DROP PROCEDURE IF EXISTS sp_calculate_running_sales_total;
DROP PROCEDURE IF EXISTS sp_archive_old_orders;

-- ############################################# --
-- ############################################# --
-- TRIGGERS

-- TRIGGER 1: SYSTEM FOR ORDER TOTALS --
DELIMITER $$
CREATE TRIGGER tr_after_order_item_insert
AFTER INSERT ON `Order_Items`
FOR EACH ROW
BEGIN
    UPDATE `Orders`
    SET `total_amount` = `total_amount` + (NEW.quantity * NEW.price)
    WHERE `order_id` = NEW.order_id;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER tr_after_order_item_update
AFTER UPDATE ON `Order_Items`
FOR EACH ROW
BEGIN
    DECLARE quantity_difference INT;
    IF NEW.quantity <> OLD.quantity THEN
        SET quantity_difference = NEW.quantity - OLD.quantity;
        UPDATE `Orders`
        SET `total_amount` = `total_amount` + (quantity_difference * NEW.price)
        WHERE `order_id` = NEW.order_id;
    END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER tr_after_order_item_delete
AFTER DELETE ON `Order_Items`
FOR EACH ROW
BEGIN
    UPDATE `Orders`
    SET `total_amount` = `total_amount` - (OLD.quantity * OLD.price)
    WHERE `order_id` = OLD.order_id;
END$$
DELIMITER ;

UPDATE Orders o
SET total_amount = (
    SELECT SUM(oi.quantity * oi.price)
    FROM Order_Items oi
    WHERE oi.order_id = o.order_id
)
WHERE EXISTS (
    SELECT 1 FROM Order_Items oi WHERE oi.order_id = o.order_id
);

-- Procedure to calculate the running total of sales over time
DELIMITER $$
CREATE PROCEDURE sp_calculate_running_sales_total()
BEGIN
    SELECT
        order_date,
        daily_sales,
        SUM(daily_sales) OVER (ORDER BY order_date ASC) as running_total_sales
    FROM (
        SELECT
            o.order_date,
            SUM(oi.quantity * oi.price) as daily_sales
        FROM `Orders` o
        JOIN `Order_Items` oi ON o.order_id = oi.order_id
        GROUP BY o.order_date
    ) as daily_sales_subquery
    ORDER BY order_date;
END$$
DELIMITER ;

-- Procedure to update quantity and log the changes
DELIMITER $$
CREATE PROCEDURE sp_update_order_item_quantity(IN p_order_item_id BIGINT UNSIGNED, IN p_new_quantity INT)
BEGIN
    DECLARE v_order_id BIGINT UNSIGNED;
    DECLARE v_customer_id BIGINT UNSIGNED;
    DECLARE v_old_total DECIMAL(10, 2);
    DECLARE v_new_total DECIMAL(10, 2);
    DECLARE v_change_amount DECIMAL(10, 2);

    SELECT o.order_id, o.customer_id, o.total_amount INTO v_order_id, v_customer_id, v_old_total
    FROM `Orders` o
    JOIN `Order_Items` oi ON o.order_id = oi.order_id
    WHERE oi.order_item_id = p_order_item_id;

    UPDATE `Order_Items` SET quantity = p_new_quantity WHERE order_item_id = p_order_item_id;

    SELECT total_amount INTO v_new_total FROM `Orders` WHERE order_id = v_order_id;

    SET v_change_amount = v_new_total - v_old_total;

    INSERT INTO `TR_Order_Update_Log` (order_id, customer_id, previous_total, new_total, balance_change)
    VALUES (v_order_id, v_customer_id, v_old_total, v_new_total, v_change_amount);
    
    SELECT
        p_order_item_id AS order_item_id,
        v_old_total AS previous_order_total,
        v_new_total AS new_order_total,
        v_change_amount AS amount_changed;
END$$
DELIMITER ;

CREATE VIEW `V_Order_Balance_Sheet` AS
SELECT
    log_id,
    order_id,
    customer_id,
    previous_total,
    new_total,
    balance_change,
    update_timestamp
FROM `TR_Order_Update_Log`
ORDER BY update_timestamp DESC;

------------------------------------

-- TRIGGER 2 : SYSTEM FOR PRODUCT PRICE AUDITING --
DELIMITER $$
CREATE TRIGGER tr_before_product_price_update
BEFORE UPDATE ON `Products`
FOR EACH ROW
BEGIN
    IF OLD.price <> NEW.price THEN
        INSERT INTO `TR_Product_Price_History` (product_id, old_price, new_price)
        VALUES (OLD.product_id, OLD.price, NEW.price);
    END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER tr_before_product_insert_set_rating
BEFORE INSERT ON `Products`
FOR EACH ROW
BEGIN
    -- If no rating is provided for a new product, set it to the company average
    IF NEW.current_rating IS NULL THEN
        SET NEW.current_rating = f_get_company_avg_rating();
    END IF;
END$$
DELIMITER ;



------------------------------------

-- TRIGGER 3: SYSTEM FOR REAL-TIME PRODUCT RATINGS --
DELIMITER $$
CREATE TRIGGER tr_after_review_insert
AFTER INSERT ON `Reviews`
FOR EACH ROW
BEGIN
    UPDATE `Products`
    SET `current_rating` = (SELECT AVG(rating) FROM `Reviews` WHERE product_id = NEW.product_id AND rating IS NOT NULL)
    WHERE `product_id` = NEW.product_id;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER tr_after_review_update
AFTER UPDATE ON `Reviews`
FOR EACH ROW
BEGIN
    UPDATE `Products`
    SET `current_rating` = (SELECT AVG(rating) FROM `Reviews` WHERE product_id = NEW.product_id AND rating IS NOT NULL)
    WHERE `product_id` = NEW.product_id;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER tr_after_review_delete
AFTER DELETE ON `Reviews`
FOR EACH ROW
BEGIN
    UPDATE `Products`
    SET `current_rating` = (SELECT AVG(rating) FROM `Reviews` WHERE product_id = OLD.product_id AND rating IS NOT NULL)
    WHERE `product_id` = OLD.product_id;
END$$
DELIMITER ;

UPDATE Products p
SET current_rating = (SELECT AVG(r.rating) FROM Reviews r WHERE r.product_id = p.product_id AND r.rating IS NOT NULL)
WHERE EXISTS (SELECT 1 FROM Reviews r WHERE r.product_id = p.product_id);

-- ############################################# --
-- ############################################# --
-- ADDITIONAL SPs

-- PROCEDURE for manual archiving
DELIMITER $$
CREATE PROCEDURE sp_archive_old_orders()
BEGIN
    START TRANSACTION;
    INSERT INTO `TR_Orders_Archive` (order_id, customer_id, order_date, total_amount)
    SELECT order_id, customer_id, order_date, total_amount
    FROM `Orders`
    WHERE `order_date` < DATE_SUB(NOW(), INTERVAL 365 DAY);

    DELETE FROM `Orders`
    WHERE `order_date` < DATE_SUB(NOW(), INTERVAL 365 DAY);
    COMMIT;
    SELECT 'Archiving process complete.' as status;
END$$
DELIMITER ;

-- ############################################# --
-- ############################################# --
-- ADDITIONAL VIEWS
--
DROP VIEW IF EXISTS `V_Order_Balance_Sheet`;
DROP VIEW IF EXISTS `V_Public_Product_Catalog`;

-- UPDATED View for the public catalog, now with live ratings
CREATE VIEW `V_Public_Product_Catalog` AS
SELECT
    p.product_id,
    p.product_name,
    p.price,
    c.category_name,
    p.current_rating
FROM
    `Products` p
JOIN
    `Categories` c ON p.category_id = c.category_id;

-- ############################################# --
-- ############################################# --
-- TABLE PARTITIONING

-- First, we must remove ALL foreign keys related to the tables being partitioned.
ALTER TABLE `Order_Items` DROP FOREIGN KEY `fk_order_items_orders`;
ALTER TABLE `Reviews` DROP FOREIGN KEY `fk_reviews_customers`;
ALTER TABLE `Reviews` DROP FOREIGN KEY `fk_reviews_products`;
ALTER TABLE `Orders` DROP FOREIGN KEY `fk_orders_customers`;

UPDATE `Orders` SET `order_date` = CURDATE() WHERE `order_date` IS NULL; --imp
UPDATE `Reviews` SET `rating` = 0 WHERE `rating` IS NULL;

-- To partition a table, the partitioning key must be in the primary key.
-- We must first modify the primary keys for BOTH tables before applying partitions.
ALTER TABLE `Orders` DROP PRIMARY KEY, ADD PRIMARY KEY (`order_id`, `order_date`);
ALTER TABLE `Customers` DROP PRIMARY KEY, ADD PRIMARY KEY (`customer_id`, `zipcode`);
ALTER TABLE `Reviews` DROP PRIMARY KEY, ADD PRIMARY KEY (`review_id`, `rating`);

-- Partition 1: Partition 'Orders' by RANGE on the order year.
ALTER TABLE `Orders`
PARTITION BY RANGE (YEAR(order_date)) (
    PARTITION p_orders_2022 VALUES LESS THAN (2023),
    PARTITION p_orders_2023 VALUES LESS THAN (2024),
    PARTITION p_orders_2024 VALUES LESS THAN (2025),
    PARTITION p_orders_2025 VALUES LESS THAN (2026),
    PARTITION p_orders_future VALUES LESS THAN MAXVALUE
);

-- Partition 2: Partition 'Customers' by RANGE on the zipcode.
-- This geographically distributes customers into regions based on the first digit of their zipcode.
ALTER TABLE `Customers`
PARTITION BY RANGE COLUMNS(zipcode) (
    PARTITION p_zip1 VALUES LESS THAN ('10000'), -- Zipcodes starting with 1 (e.g., NY, PA)
    PARTITION p_zip2 VALUES LESS THAN ('20000'), -- Zipcodes starting with 2 (e.g., NY, PA)
    PARTITION p_zip3 VALUES LESS THAN ('30000'), -- Zipcodes starting with 2 (e.g., VA, NC)
    PARTITION p_zip4 VALUES LESS THAN ('40000'), -- Zipcodes starting with 3 (e.g., GA, FL)
    PARTITION p_zip5 VALUES LESS THAN ('50000'), -- Zipcodes starting with 4 (e.g., OH, MI)
    PARTITION p_zip6 VALUES LESS THAN ('60000'), -- Zipcodes starting with 5 (e.g., IA, WI)
    PARTITION p_zip7 VALUES LESS THAN ('70000'), -- Zipcodes starting with 6 (e.g., IL, MO)
    PARTITION p_zip8 VALUES LESS THAN ('80000'), -- Zipcodes starting with 7 (e.g., TX, LA)
    PARTITION p_zip9 VALUES LESS THAN ('90000'), -- Zipcodes starting with 8 (e.g., CO, AZ)
    PARTITION p_zip0 VALUES LESS THAN MAXVALUE   -- Zipcodes starting with 9 (e.g., CA, WA)
);

-- Partition 3: Partition 'REVIEWS' by LIST on the ratings.
ALTER TABLE `Reviews`
PARTITION BY LIST(rating) (
    PARTITION p_poor_reviews VALUES IN (1, 2),
    PARTITION p_average_reviews VALUES IN (3),
    PARTITION p_good_reviews VALUES IN (4, 5),
    PARTITION p_unrated VALUES IN (0)
);

GRANT EXECUTE ON PROCEDURE aethermart_db.sp_calculate_running_sales_total TO 'alex'@'localhost';
GRANT EXECUTE ON PROCEDURE aethermart_db.sp_update_order_item_quantity TO 'sarah'@'localhost';
GRANT EXECUTE ON PROCEDURE aethermart_db.sp_archive_old_orders TO 'alex'@'localhost';
--GRANT SELECT ON `aethermart_db`.`V_Order_Balance_Sheet` TO 'sarah'@'localhost', 'alex'@'localhost';
GRANT 'db_admin' TO 'david'@'localhost';
-- GRANT EXECUTE ON PROCEDURE aethermart_db.sp_load_order_items_analytics TO 'alex'@'localhost';
-- GRANT EXECUTE ON PROCEDURE aethermart_db.sp_load_reviews_analytics TO 'alex'@'localhost';
-- GRANT EXECUTE ON PROCEDURE aethermart_db.sp_load_customer_ltv_analytics TO 'alex'@'localhost';

FLUSH PRIVILEGES;

-- SELECT 'Milestone 2 script executed successfully with live ratings and manual archiving.' AS status;

