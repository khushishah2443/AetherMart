source .venv/bin/activate

mariadb
SHOW DATABASES;

mariadb < mile4.sql

SHOW DATABASES;

USE aethermart_dw;

SHOW TABLES;

SELECT COUNT(*) FROM dim_customer;
SELECT COUNT(*) FROM fact_sales;
SELECT COUNT(*) FROM fact_reviews;

CALL sp_run_etl_pipeline();

SELECT COUNT(*) FROM dim_customer;
SELECT COUNT(*) FROM fact_sales;
SELECT COUNT(*) FROM fact_reviews;

SELECT
    d.year,
    p.category_name,
    SUM(f.total_sale) AS total_revenue
FROM
    fact_sales f
JOIN
    dim_product p ON f.product_key = p.product_key
JOIN
    dim_date d ON f.date_key = d.date_key
GROUP BY
    d.year, p.category_name
ORDER BY
    d.year, total_revenue DESC
LIMIT 10;
USE aethermart_db;

python3 semantic_search.py 

-- Products
something for my computer
durable work pants
fun toy for pet
healthy food item
-- Reviews
great battery life
good value
terrible shipping 
tastes like cardboard
-- Customers
customer who buys electronics
customer similar to ID 15
shopper from California interested in health
find someone like customer 37