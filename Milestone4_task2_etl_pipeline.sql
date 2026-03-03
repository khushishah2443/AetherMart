-- =====================================================================
-- Milestone 4: Task 2 - Advanced ETL/Data Pipeline (v2)
--
-- Objective: To design and implement a robust ETL pipeline.
-- This script creates a separate "Data Warehouse" (aethermart_dw)
-- with a star schema, solving Sarah's analytics performance problem.
--
-- v2 Update: Now includes 'Reviews' data as required by the rubric,
-- creating a new 'fact_reviews' table and a more robust 'dim_date'.
-- =====================================================================

--
-- STEP 1: (DESIGN) CREATE THE NEW DATA WAREHOUSE SCHEMA
--
CREATE DATABASE IF NOT EXISTS aethermart_dw;
USE aethermart_dw;

-- Drop tables in reverse order of dependency for clean re-runs
DROP TABLE IF EXISTS fact_sales;
DROP TABLE IF EXISTS fact_reviews;
DROP TABLE IF EXISTS dim_customer;
DROP TABLE IF EXISTS dim_product;
DROP TABLE IF EXISTS dim_date;

-- Dimension Table 1: Customer
-- Stores the "who"
CREATE TABLE dim_customer (
    customer_key INT PRIMARY KEY,
    customer_id INT, -- Original ID from production DB
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    city VARCHAR(100),
    state VARCHAR(50),
    zipcode VARCHAR(20)
);

-- Dimension Table 2: Product
-- Stores the "what"
CREATE TABLE dim_product (
    product_key INT PRIMARY KEY,
    product_id INT, -- Original ID from production DB
    product_name VARCHAR(255),
    category_name VARCHAR(255),
    supplier_name VARCHAR(255),
    price DECIMAL(10, 2)
);

-- Dimension Table 3: Date
-- Stores the "when"
CREATE TABLE dim_date (
    date_key INT PRIMARY KEY, -- YYYYMMDD format
    full_date DATE,
    `year` INT,
    `quarter` INT,
    `month` INT,
    `day` INT,
    `day_of_week` INT
);

-- Fact Table 1: Sales
-- Stores sales events and metrics
CREATE TABLE fact_sales (
    sales_id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT,
    date_key INT,
    customer_key INT,
    product_key INT,
    quantity INT,
    price_per_unit DECIMAL(10, 2),
    total_sale DECIMAL(10, 2),
    FOREIGN KEY (date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key)
);

-- Fact Table 2: Reviews
-- Stores review events and sentiment metrics
CREATE TABLE fact_reviews (
    review_key INT PRIMARY KEY,
    product_key INT,
    customer_key INT,
    date_key INT,
    rating INT,
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key),
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
    FOREIGN KEY (date_key) REFERENCES dim_date(date_key)
);


--
-- STEP 2: (IMPLEMENT) CREATE THE ETL STORED PROCEDURE
--
USE aethermart_dw;
DROP PROCEDURE IF EXISTS sp_run_etl_pipeline;

DELIMITER $$
CREATE PROCEDURE sp_run_etl_pipeline()
BEGIN
    -- This procedure performs the full ETL process.

    -- 1. Truncate (empty) the DW tables for a fresh load.
    SET FOREIGN_KEY_CHECKS=0;
    TRUNCATE TABLE fact_sales;
    TRUNCATE TABLE fact_reviews;
    TRUNCATE TABLE dim_customer;
    TRUNCATE TABLE dim_product;
    TRUNCATE TABLE dim_date;
    SET FOREIGN_KEY_CHECKS=1;

    -- 2. EXTRACT & TRANSFORM: Customers
    -- Enhanced Data Quality: Use COALESCE to fix missing emails
    -- (from generator.py) and default unknowns.
    INSERT INTO dim_customer (customer_key, customer_id, first_name, last_name, city, state, zipcode)
    SELECT
        customer_id, -- Use original ID as the key
        customer_id,
        COALESCE(first_name, 'Unknown'),
        COALESCE(last_name, 'Unknown'),
        COALESCE(city, 'Unknown'),
        COALESCE(state, 'N/A'),
        COALESCE(zipcode, 'N/A')
    FROM aethermart_db.Customers;

    -- 3. EXTRACT & TRANSFORM: Products
    -- Advanced SQL: Join 3 tables to denormalize.
    INSERT INTO dim_product (product_key, product_id, product_name, category_name, supplier_name, price)
    SELECT
        p.product_id, -- Use original ID as the key
        p.product_id,
        p.product_name,
        c.category_name,
        s.supplier_name,
        p.price
    FROM aethermart_db.Products p
    LEFT JOIN aethermart_db.Categories c ON p.category_id = c.category_id
    LEFT JOIN aethermart_db.Suppliers s ON p.supplier_id = s.supplier_id;

    -- 4. EXTRACT & TRANSFORM: Dates
    -- Advanced/Robust Step: We must get ALL possible dates from *both*
    -- orders and reviews to have a complete date dimension.
    INSERT INTO dim_date (date_key, full_date, `year`, `quarter`, `month`, `day`, `day_of_week`)
    SELECT DISTINCT
        DATE_FORMAT(all_dates.event_date, '%Y%m%d') AS date_key,
        all_dates.event_date AS full_date,
        YEAR(all_dates.event_date) AS `year`,
        QUARTER(all_dates.event_date) AS `quarter`,
        MONTH(all_dates.event_date) AS `month`,
        DAY(all_dates.event_date) AS `day`,
        DAYOFWEEK(all_dates.event_date) AS `day_of_week`
    FROM (
        SELECT order_date AS event_date FROM aethermart_db.Orders
        UNION
        SELECT review_date AS event_date FROM aethermart_db.Reviews
    ) AS all_dates
    WHERE all_dates.event_date IS NOT NULL;

    -- 5. LOAD: Fact Table (Sales)
    -- This is the final step, joining all production tables and linking
    -- to the new dimension keys.
    INSERT INTO fact_sales (order_id, date_key, customer_key, product_key, quantity, price_per_unit, total_sale)
    SELECT
        o.order_id,
        DATE_FORMAT(o.order_date, '%Y%m%d') AS date_key,
        o.customer_id AS customer_key,
        oi.product_id AS product_key,
        oi.quantity,
        oi.price AS price_per_unit,
        (oi.quantity * oi.price) AS total_sale
    FROM
        aethermart_db.Orders o
    JOIN
        aethermart_db.Order_Items oi ON o.order_id = oi.order_id
    WHERE
        o.order_date IS NOT NULL;

    -- 6. LOAD: Fact Table (Reviews)
    -- Enhanced Data Quality: We only load valid reviews.
    -- The trg_set_default_rating in M2 sets invalid ratings to 0.
    INSERT INTO fact_reviews (review_key, product_key, customer_key, date_key, rating)
    SELECT
        r.review_id,
        r.product_id,
        r.customer_id,
        DATE_FORMAT(r.review_date, '%Y%m%d') AS date_key,
        r.rating
    FROM
        aethermart_db.Reviews r
    WHERE
        r.review_date IS NOT NULL AND r.rating > 0; -- Data quality check

    SELECT 'AetherMart Data Warehouse ETL process complete.' as status;

END$$
DELIMITER ;

