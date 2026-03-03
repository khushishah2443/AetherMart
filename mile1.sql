-- =====================================================================
-- AetherMart Database Milestone 1 Setup (Final Version with RBAC)
--
-- Description:
-- This script handles the entire database setup:
-- 1. Creates the database and all required tables.
-- 2. Loads raw data from CSV files into staging tables.
-- 3. Cleans, transforms, and inserts data into the final tables.
-- 4. Creates User-Defined Functions, Stored Procedures, and Views.
-- 5. Implements Role-Based Access Control (RBAC) for security.
-- 6. Creates user accounts and assigns them to their appropriate roles.
--
-- !!! IMPORTANT !!!
-- BEFORE YOU RUN THIS SCRIPT:
-- 1. You MUST run the MariaDB/MySQL client with the '--local-infile=1' flag enabled.
--    Example Command:
--    mysql --local-infile=1 -u root -p < 01_aethermart_master_setup.sql
-- =====================================================================

-- Create the database if it doesn't exist
CREATE DATABASE IF NOT EXISTS aethermart_db;

-- Use the newly created database
USE aethermart_db;

--
-- Drop objects if they exist to allow for a clean run
--
DROP PROCEDURE IF EXISTS sp_get_total_revenue;
DROP PROCEDURE IF EXISTS sp_get_monthly_revenue;
DROP PROCEDURE IF EXISTS sp_get_orders_in_month;
DROP PROCEDURE IF EXISTS sp_get_orders_by_state;
DROP FUNCTION IF EXISTS f_get_company_avg_rating;
DROP FUNCTION IF EXISTS f_get_product_avg_rating;
DROP VIEW IF EXISTS `V_Customer_Order_History`;
DROP VIEW IF EXISTS `V_Customer_Value_Summary`;
DROP VIEW IF EXISTS `V_Order_Status_Dashboard`;
DROP VIEW IF EXISTS `V_Geographic_Sales_Report`;
DROP VIEW IF EXISTS `V_Sales_And_Reviews_Summary`;
DROP VIEW IF EXISTS `V_Supplier_Performance_Review`;
DROP VIEW IF EXISTS `V_Public_Product_Catalog`;
DROP TABLE IF EXISTS `Reviews`;
DROP TABLE IF EXISTS `Order_Items`;
DROP TABLE IF EXISTS `Orders`;
DROP TABLE IF EXISTS `Products`;
DROP TABLE IF EXISTS `Customers`;
DROP TABLE IF EXISTS `Suppliers`;
DROP TABLE IF EXISTS `Categories`;
DROP TABLE IF EXISTS `reviews_staging`;
DROP TABLE IF EXISTS `order_items_staging`;
DROP TABLE IF EXISTS `orders_staging`;
DROP TABLE IF EXISTS `products_staging`;
DROP TABLE IF EXISTS `customers_staging`;
DROP TABLE IF EXISTS `suppliers_staging`;
DROP TABLE IF EXISTS `categories_staging`;
DROP ROLE IF EXISTS 'db_admin';
DROP ROLE IF EXISTS 'operations_manager';
DROP ROLE IF EXISTS 'customer_relations_manager';
DROP ROLE IF EXISTS 'public_customer';

-- Staging Tables
--
CREATE TABLE `customers_staging` (
  `customer_id` VARCHAR(255),
  `first_name` VARCHAR(255),
  `last_name` VARCHAR(255),
  `email` VARCHAR(255),
  `registration_date` VARCHAR(255),
  `city` VARCHAR(255),
  `state` VARCHAR(255),
  `zipcode` VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `categories_staging` (
  `category_id` VARCHAR(255),
  `category_name` VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `suppliers_staging` (
  `supplier_id` VARCHAR(255),
  `supplier_name` VARCHAR(255),
  `contact_name` VARCHAR(255),
  `contact_email` VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `products_staging` (
    `product_id` VARCHAR(255),
    `product_name` VARCHAR(255),
    `category_id` VARCHAR(255),
    `price` VARCHAR(255),
    `supplier_id` VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `orders_staging` (
  `order_id` VARCHAR(255),
  `customer_id` VARCHAR(255),
  `order_date` VARCHAR(255),
  `total_amount` VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `order_items_staging` (
  `order_item_id` VARCHAR(255),
  `order_id` VARCHAR(255),
  `product_id` VARCHAR(255),
  `quantity` VARCHAR(255),
  `price` VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `reviews_staging` (
  `review_id` VARCHAR(255),
  `product_id` VARCHAR(255),
  `customer_id` VARCHAR(255),
  `rating` VARCHAR(255),
  `review_text` TEXT,
  `review_date` VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Final Normalized Tables
--
CREATE TABLE `Customers` (
  `customer_id` BIGINT UNSIGNED PRIMARY KEY,
  `first_name` VARCHAR(100) NOT NULL,
  `last_name` VARCHAR(100) NOT NULL,
  `email` VARCHAR(255) NOT NULL,
  `registration_date` DATE,
  `city` VARCHAR(100) NOT NULL,
  `state` VARCHAR(10) NOT NULL,
  `zipcode` VARCHAR(20) NOT NULL
  -- `first_name` VARCHAR(201) AS (CONCAT(first_name, ' ', last_name)) VIRTUAL,
  -- `full_address` VARCHAR(132) AS (CONCAT(city, ', ', state, ' ', zipcode)) VIRTUAL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `Categories` (
  `category_id` BIGINT UNSIGNED PRIMARY KEY,
  `category_name` VARCHAR(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `Suppliers` (
  `supplier_id` BIGINT UNSIGNED PRIMARY KEY,
  `supplier_name` VARCHAR(255) NOT NULL,
  `contact_email` VARCHAR(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `Products` (
  `product_id` BIGINT UNSIGNED PRIMARY KEY,
  `product_name` VARCHAR(255) NOT NULL,
  `price` DECIMAL(10, 2) NOT NULL,
  `category_id` BIGINT UNSIGNED NOT NULL,
  `supplier_id` BIGINT UNSIGNED NOT NULL,
  CONSTRAINT `fk_products_categories` FOREIGN KEY (`category_id`) REFERENCES `Categories`(`category_id`),
  CONSTRAINT `fk_products_suppliers` FOREIGN KEY (`supplier_id`) REFERENCES `Suppliers`(`supplier_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `Orders` (
  `order_id` BIGINT UNSIGNED PRIMARY KEY,
  `customer_id` BIGINT UNSIGNED NOT NULL,
  `order_date` DATE,
  `total_amount` DECIMAL(10, 2),
  CONSTRAINT `fk_orders_customers` FOREIGN KEY (`customer_id`) REFERENCES `Customers`(`customer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `Order_Items` (
  `order_item_id` BIGINT UNSIGNED PRIMARY KEY,
  `order_id` BIGINT UNSIGNED NOT NULL,
  `product_id` BIGINT UNSIGNED NOT NULL,
  `quantity` INT NOT NULL,
  `price` DECIMAL(10, 2) NOT NULL,
  CONSTRAINT `fk_order_items_orders` FOREIGN KEY (`order_id`) REFERENCES `Orders`(`order_id`),
  CONSTRAINT `fk_order_items_products` FOREIGN KEY (`product_id`) REFERENCES `Products`(`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `Reviews` (
  `review_id` BIGINT UNSIGNED PRIMARY KEY,
  `product_id` BIGINT UNSIGNED NOT NULL,
  `customer_id` BIGINT UNSIGNED NOT NULL,
  `rating` INT CHECK (rating >= 0 AND rating <= 5),
  `review_text` TEXT,
  `review_date` DATE,
  CONSTRAINT `fk_reviews_products` FOREIGN KEY (`product_id`) REFERENCES `Products`(`product_id`),
  CONSTRAINT `fk_reviews_customers` FOREIGN KEY (`customer_id`) REFERENCES `Customers`(`customer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Data loading from CSV files into staging tables
--
LOAD DATA LOCAL INFILE 'customers.csv'
INTO TABLE `customers_staging`
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@col1, @col2, @col3, @col4, @col5, @col6, @col7, @col8)
SET
  customer_id = TRIM(@col1),
  first_name = TRIM(@col2),
  last_name = TRIM(@col3),
  email = TRIM(@col4),
  registration_date = TRIM(@col5),
  city = TRIM(@col6),
  state = TRIM(@col7),
  zipcode = TRIM(@col8);

LOAD DATA LOCAL INFILE 'categories.csv'
INTO TABLE `categories_staging`
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@col1, @col2)
SET
  category_id = TRIM(@col1),
  category_name = TRIM(@col2);

LOAD DATA LOCAL INFILE 'suppliers.csv'
INTO TABLE `suppliers_staging`
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@col1, @col2, @col3, @col4)
SET
  supplier_id = TRIM(@col1),
  supplier_name = TRIM(@col2),
  contact_name = TRIM(@col3),
  contact_email = TRIM(@col4);

LOAD DATA LOCAL INFILE 'products.csv'
INTO TABLE `products_staging`
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\r\n'  -- FIXED
IGNORE 1 ROWS
(@col1, @col2, @col3, @col4, @col5)
SET
  product_id = TRIM(@col1),
  product_name = TRIM(@col2),
  price = TRIM(@col3),          -- FIXED: was @col4
  category_id = TRIM(@col4),    -- FIXED: was @col3
  supplier_id = TRIM(@col5);

LOAD DATA LOCAL INFILE 'orders.csv'
INTO TABLE `orders_staging`
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@col1, @col2, @col3, @col4)
SET
  order_id = TRIM(@col1),
  customer_id = TRIM(@col2),
  order_date = TRIM(@col3),
  total_amount = TRIM(@col4);

LOAD DATA LOCAL INFILE 'order_items.csv'
INTO TABLE `order_items_staging`
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@col1, @col2, @col3, @col4, @col5)
SET
  order_item_id = TRIM(@col1),
  order_id = TRIM(@col2),
  product_id = TRIM(@col3),
  quantity = TRIM(@col4),
  price = TRIM(@col5);

LOAD DATA LOCAL INFILE 'reviews.csv'
INTO TABLE `reviews_staging`
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@col1, @col2, @col3, @col4, @col5, @col6)
SET
  review_id = TRIM(@col1),
  product_id = TRIM(@col2),
  customer_id = TRIM(@col3),
  rating = TRIM(@col4),
  review_text = TRIM(@col5),
  review_date = TRIM(@col6);

--
-- Insert data from staging tables into final normalized tables
--

SET FOREIGN_KEY_CHECKS=0;

INSERT IGNORE INTO `Customers` (`customer_id`, `first_name`, `last_name`, `email`, `registration_date`, `city`, `state`, `zipcode`)
SELECT
  CAST(customer_id AS UNSIGNED),
  first_name,
  last_name,
  IFNULL(NULLIF(email, ''), 'your_name@tamu.edu'),
  STR_TO_DATE(registration_date, '%Y-%m-%d'),
  city,
  state,
  zipcode
FROM `customers_staging`
WHERE customer_id IS NOT NULL AND customer_id != '' AND customer_id REGEXP '^[0-9]+$';

INSERT IGNORE INTO `Categories` (`category_id`, `category_name`)
SELECT
  CAST(category_id AS UNSIGNED),
  category_name
FROM `categories_staging`
WHERE category_id IS NOT NULL AND category_id != '' AND category_id REGEXP '^[0-9]+$';

INSERT IGNORE INTO `Suppliers` (`supplier_id`, `supplier_name`, `contact_email`)
SELECT
  CAST(supplier_id AS UNSIGNED),
  supplier_name,
  IFNULL(NULLIF(contact_email, ''), 'your_name@tamu.edu')
FROM `suppliers_staging`
WHERE supplier_id IS NOT NULL AND supplier_id != '' AND supplier_id REGEXP '^[0-9]+$';

INSERT IGNORE INTO `Products` (`product_id`, `product_name`, `price`, `category_id`, `supplier_id`)
SELECT
  CAST(ps.product_id AS UNSIGNED),
  ps.product_name,
  CAST(ps.price AS DECIMAL(10, 2)),
  CAST(ps.category_id AS UNSIGNED),
  CAST(ps.supplier_id AS UNSIGNED)
FROM `products_staging` AS ps
WHERE
  ps.product_id IS NOT NULL AND ps.product_id REGEXP '^[0-9]+$'
  AND ps.category_id IS NOT NULL AND ps.category_id REGEXP '^[0-9]+$'
  AND ps.supplier_id IS NOT NULL AND ps.supplier_id REGEXP '^[0-9]+$';

INSERT IGNORE INTO `Orders` (`order_id`, `customer_id`, `order_date`, `total_amount`)
SELECT
  CAST(os.order_id AS UNSIGNED),
  CAST(os.customer_id AS UNSIGNED),
  CASE
    WHEN os.`order_date` REGEXP '^[0-9]{1,2}-[a-zA-Z]{3}-[0-9]{2}$' THEN STR_TO_DATE(os.`order_date`, '%d-%b-%y')
    WHEN os.`order_date` REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{2}$' THEN STR_TO_DATE(os.`order_date`, '%m/%d/%y')
    WHEN os.`order_date` REGEXP '^[a-zA-Z]+ [0-9]{1,2}, [0-9]{4}$' THEN STR_TO_DATE(os.`order_date`, '%M %d, %Y')
    WHEN os.`order_date` REGEXP '^[0-9]{1,2}-[0-9]{1,2}-[0-9]{4}$' THEN STR_TO_DATE(os.`order_date`, '%m-%d-%Y')
    WHEN os.`order_date` REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$' THEN STR_TO_DATE(os.`order_date`, '%m/%d/%Y')
    ELSE STR_TO_DATE(os.`order_date`, '%Y-%m-%d')
  END,
  CAST(os.total_amount AS DECIMAL(10,2))
FROM `orders_staging` AS os
WHERE
  os.order_id IS NOT NULL AND os.order_id REGEXP '^[0-9]+$'
  AND os.customer_id IS NOT NULL AND os.customer_id REGEXP '^[0-9]+$';

INSERT IGNORE INTO `Order_Items` (`order_item_id`, `order_id`, `product_id`, `quantity`, `price`)
SELECT
  CAST(ois.order_item_id AS UNSIGNED),
  CAST(ois.order_id AS UNSIGNED),
  CAST(ois.product_id AS UNSIGNED),
  CAST(ois.quantity AS SIGNED),
  CAST(ois.price AS DECIMAL(10, 2))
FROM `order_items_staging` AS ois
WHERE
  ois.order_item_id IS NOT NULL AND ois.order_item_id REGEXP '^[0-9]+$'
  AND ois.order_id IS NOT NULL AND ois.order_id REGEXP '^[0-9]+$'
  AND ois.product_id IS NOT NULL AND ois.product_id REGEXP '^[0-9]+$';

INSERT IGNORE INTO `Reviews` (`review_id`, `product_id`, `customer_id`, `rating`, `review_text`, `review_date`)
SELECT
  CAST(rs.review_id AS UNSIGNED),
  CAST(rs.product_id AS UNSIGNED),
  CAST(rs.customer_id AS UNSIGNED),
  CASE WHEN rs.rating REGEXP '^[1-5]$' THEN CAST(rs.rating AS SIGNED) ELSE NULL END,
  rs.review_text,
  STR_TO_DATE(rs.review_date, '%Y-%m-%d')
FROM `reviews_staging` AS rs
WHERE
  rs.review_id IS NOT NULL AND rs.review_id REGEXP '^[0-9]+$'
  AND rs.product_id IS NOT NULL AND rs.product_id REGEXP '^[0-9]+$'
  AND rs.customer_id IS NOT NULL AND rs.customer_id REGEXP '^[0-9]+$';

SET FOREIGN_KEY_CHECKS=1;

--
-- Create User-Defined Functions (UDFs)
--

DELIMITER $$
CREATE FUNCTION f_get_company_avg_rating()
RETURNS DECIMAL(3, 2)
DETERMINISTIC
BEGIN
    DECLARE avg_rating DECIMAL(3, 2);
    SELECT AVG(rating) INTO avg_rating FROM `Reviews` WHERE rating IS NOT NULL AND rating BETWEEN 1 AND 5;
    RETURN avg_rating;
END$$
DELIMITER ;

DELIMITER $$
CREATE FUNCTION f_get_product_avg_rating(p_product_id BIGINT UNSIGNED)
RETURNS DECIMAL(3, 2)
DETERMINISTIC
BEGIN
    DECLARE avg_rating DECIMAL(3, 2);
    SELECT AVG(rating) INTO avg_rating FROM `Reviews` WHERE product_id = p_product_id AND rating IS NOT NULL AND rating BETWEEN 1 AND 5;
    RETURN avg_rating;
END$$
DELIMITER ;

--
-- Create Stored Procedures (SPs)
--

DELIMITER $$
CREATE PROCEDURE sp_get_total_revenue()
BEGIN
    SELECT SUM(quantity * price) AS total_revenue FROM `Order_Items`;
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_get_monthly_revenue(IN p_year INT)
BEGIN
    SELECT
        MONTHNAME(o.order_date) AS month,
        SUM(oi.quantity * oi.price) AS monthly_revenue
    FROM `Orders` o
    JOIN `Order_Items` oi ON o.order_id = oi.order_id
    WHERE YEAR(o.order_date) = p_year
    GROUP BY MONTH(o.order_date), MONTHNAME(o.order_date)
    ORDER BY MONTH(o.order_date);
END$$ 
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_get_orders_in_month(IN p_year INT, IN p_month INT)
BEGIN
    SELECT COUNT(order_id) AS total_orders FROM `Orders` WHERE YEAR(order_date) = p_year AND MONTH(order_date) = p_month;
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_get_orders_by_state()
BEGIN
    SELECT
        c.state,
        COUNT(o.order_id) as order_count
    FROM `Orders` o
    JOIN `Customers` c ON o.customer_id = c.customer_id
    GROUP BY c.state
    ORDER BY order_count DESC;
END$$
DELIMITER ;


--
-- Create Views for specific user roles
--
CREATE VIEW `V_Public_Product_Catalog` AS
SELECT
    p.product_id,
    p.product_name,
    p.price,
    c.category_name
FROM
    `Products` p
JOIN
    `Categories` c ON p.category_id = c.category_id;

CREATE VIEW `V_Sales_And_Reviews_Summary` AS
SELECT
    p.product_name,
    c.category_name,
    SUM(oi.quantity) AS total_quantity_sold,
    AVG(r.rating) AS current_rating
FROM `Products` p
JOIN `Categories` c ON p.category_id = c.category_id
LEFT JOIN `Order_Items` oi ON p.product_id = oi.product_id
LEFT JOIN `Reviews` r ON p.product_id = r.product_id
GROUP BY p.product_id, p.product_name, c.category_name
ORDER BY total_quantity_sold DESC;

CREATE VIEW `V_Supplier_Performance_Review` AS
SELECT
    s.supplier_name,
    p.product_name,
    r.rating,
    r.review_text,
    r.review_date
FROM `Suppliers` s
JOIN `Products` p ON s.supplier_id = p.supplier_id
JOIN `Reviews` r ON p.product_id = r.product_id
ORDER BY s.supplier_name, p.product_name, r.review_date DESC;

CREATE VIEW `V_Customer_Value_Summary` AS
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    COUNT(o.order_id) AS total_orders,
    SUM(oi.quantity * oi.price) AS total_spent
FROM `Customers` c
JOIN `Orders` o ON c.customer_id = o.customer_id
JOIN `Order_Items` oi ON o.order_id = oi.order_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.email
ORDER BY total_spent DESC;
    
CREATE VIEW `V_Customer_Order_History` AS
SELECT
    c.customer_id,
    c.first_name,
    o.order_id,
    o.order_date,
    o.total_amount
FROM `Customers` c
JOIN `Orders` o ON c.customer_id = o.customer_id
ORDER BY c.customer_id, o.order_date DESC;

CREATE VIEW `V_Order_Status_Dashboard` AS
SELECT
    o.order_id,
    o.order_date,
    o.total_amount,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.city,
    c.state
FROM `Orders` o
JOIN `Customers` c ON o.customer_id = c.customer_id;
-- WHERE o.status IN ('Processing', 'Pending');

CREATE VIEW `V_Geographic_Sales_Report` AS
SELECT
    c.state,
    c.city,
    COUNT(DISTINCT o.order_id) AS number_of_orders,
    SUM(oi.quantity * oi.price) AS total_revenue
FROM `Customers` c
JOIN `Orders` o ON c.customer_id = o.customer_id
JOIN `Order_Items` oi ON o.order_id = oi.order_id
GROUP BY c.state, c.city
ORDER BY c.state, total_revenue DESC;


--
-- Role-Based Access Control (RBAC) Setup
--
DROP ROLE IF EXISTS 'db_admin', 'operations_manager', 'customer_relations_manager', 'public_customer';

CREATE ROLE 'db_admin', 'operations_manager', 'customer_relations_manager', 'public_customer';

-- Grant permissions to Roles

-- db_admin (for David, Data Architect): Can do almost everything except delete data.
GRANT SELECT, INSERT, UPDATE, CREATE, DROP, INDEX, ALTER, CREATE VIEW, SHOW VIEW, EXECUTE ON `aethermart_db`.* TO 'db_admin';

-- operations_manager (for Sarah): Manages inventory, orders, and suppliers.
GRANT SELECT, INSERT, UPDATE, DELETE ON `aethermart_db`.`Products` TO 'operations_manager';
GRANT SELECT, INSERT, UPDATE, DELETE ON `aethermart_db`.`Suppliers` TO 'operations_manager';
GRANT SELECT, INSERT, UPDATE, DELETE ON `aethermart_db`.`Categories` TO 'operations_manager';
GRANT SELECT, INSERT, UPDATE ON `aethermart_db`.`Orders` TO 'operations_manager'; -- Cannot delete orders
GRANT SELECT, INSERT, UPDATE ON `aethermart_db`.`Order_Items` TO 'operations_manager'; -- Cannot delete order items
GRANT SELECT ON `aethermart_db`.`Customers` TO 'operations_manager'; -- Can see customer info for orders
GRANT SELECT ON `aethermart_db`.`V_Supplier_Performance_Review` TO 'operations_manager';
GRANT SELECT ON `aethermart_db`.`V_Order_Status_Dashboard` TO 'operations_manager';
GRANT EXECUTE ON FUNCTION aethermart_db.f_get_company_avg_rating TO 'operations_manager';
GRANT EXECUTE ON FUNCTION aethermart_db.f_get_product_avg_rating TO 'operations_manager';

-- customer_relations_manager (for Maria): Read-only access to customer and review data.
GRANT SELECT ON `aethermart_db`.`Customers` TO 'customer_relations_manager';
GRANT SELECT ON `aethermart_db`.`Reviews` TO 'customer_relations_manager';
GRANT SELECT ON `aethermart_db`.`Orders` TO 'customer_relations_manager';
GRANT SELECT ON `aethermart_db`.`V_Sales_And_Reviews_Summary` TO 'customer_relations_manager';
GRANT SELECT ON `aethermart_db`.`V_Customer_Order_History` TO 'customer_relations_manager'; -- Safer view without financials
GRANT EXECUTE ON FUNCTION aethermart_db.f_get_company_avg_rating TO 'customer_relations_manager';
GRANT EXECUTE ON FUNCTION aethermart_db.f_get_product_avg_rating TO 'customer_relations_manager';

-- public_customer (for customer_user): Highly restricted access.
GRANT SELECT ON `aethermart_db`.`V_Public_Product_Catalog` TO 'public_customer';


--
-- User and Role Assignment
--
DROP USER IF EXISTS 'alex'@'localhost';
DROP USER IF EXISTS 'david'@'localhost';
DROP USER IF EXISTS 'sarah'@'localhost';
DROP USER IF EXISTS 'maria'@'localhost';
DROP USER IF EXISTS 'customer_user'@'localhost';

CREATE USER 'alex'@'localhost' IDENTIFIED BY 'alex_pass';
CREATE USER 'david'@'localhost' IDENTIFIED BY 'david_pass';
CREATE USER 'sarah'@'localhost' IDENTIFIED BY 'sarah_pass';
CREATE USER 'maria'@'localhost' IDENTIFIED BY 'maria_pass';
CREATE USER 'customer_user'@'localhost' IDENTIFIED BY 'customer_pass';

-- Assign Roles to Users
GRANT ALL PRIVILEGES ON `aethermart_db`.* TO 'alex'@'localhost'; -- Alex remains superuser
GRANT 'db_admin' TO 'david'@'localhost';
GRANT 'operations_manager' TO 'sarah'@'localhost';
GRANT 'customer_relations_manager' TO 'maria'@'localhost';
GRANT 'public_customer' TO 'customer_user'@'localhost';

-- Set default roles for users to activate on login
SET DEFAULT ROLE 'db_admin' FOR 'david'@'localhost';
SET DEFAULT ROLE 'operations_manager' FOR 'sarah'@'localhost';
SET DEFAULT ROLE 'customer_relations_manager' FOR 'maria'@'localhost';
SET DEFAULT ROLE 'public_customer' FOR 'customer_user'@'localhost';


-- Apply the changes
FLUSH PRIVILEGES;

--
-- Clean up staging tables (optional)
--
DROP TABLE IF EXISTS `reviews_staging`;
DROP TABLE IF EXISTS `order_items_staging`;
DROP TABLE IF EXISTS `orders_staging`;
--DROP TABLE IF EXISTS `products_staging`;
DROP TABLE IF EXISTS `customers_staging`;
DROP TABLE IF EXISTS `suppliers_staging`;
DROP TABLE IF EXISTS `categories_staging`;

