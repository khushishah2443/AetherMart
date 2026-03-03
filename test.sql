
-- TRIGGER 1 - ORDERS

SELECT * FROM Orders WHERE order_id = 1001;

SELECT * FROM Order_Items WHERE order_id = 1002;

INSERT INTO Order_Items (order_item_id, order_id, product_id, quantity, price) VALUES (99901, 1001, 105, 2, 100.00);

SELECT * FROM Order_Items WHERE order_id = 1001;

SELECT * FROM Orders WHERE order_id = 1001;

CALL sp_update_order_item_quantity(99901, 1);

SELECT * FROM Orders WHERE order_id = 1001;

SELECT * FROM V_Order_Balance_Sheet LIMIT 5;

DELETE FROM Order_Items WHERE order_item_id = 99901;

SELECT * FROM Orders WHERE order_id = 1001;

-- TRIGGER 2 - PRODUCTS

SELECT * FROM Products WHERE product_id = 102;

SELECT * FROM TR_Product_Price_History;

UPDATE Products SET price = 99.99 WHERE product_id = 102;

SELECT * FROM Products WHERE product_id = 102;

SELECT * FROM TR_Product_Price_History;

-- TRIGGER 3 - RATINGS

SELECT * FROM Products WHERE product_id = 101;

INSERT INTO Reviews (review_id, product_id, customer_id, rating, review_date) VALUES (99901, 101, 1, 5, CURDATE());

SELECT current_rating FROM Products WHERE product_id = 101;

UPDATE Reviews SET rating = 1 WHERE review_id = 99901;

SELECT current_rating FROM Products WHERE product_id = 101;

DELETE FROM Reviews WHERE review_id = 99901;

SELECT current_rating FROM Products WHERE product_id = 101;

-- SP - ORDER ARCHIVE

INSERT into Orders(order_id, customer_id, order_date, total_amount) VALUES (99001, 55, '2022-11-25', 100);

CALL sp_archive_old_orders();


-- PARTITIONS 

SELECT partition_name, partition_description, table_rows FROM information_schema.partitions 
WHERE table_schema = 'aethermart_db' AND table_name = 'Customers';

SELECT * FROM Customers PARTITION (p_zip1) LIMIT 20;
SELECT * FROM Customers PARTITION (p_zip6) LIMIT 20;
SELECT * FROM Customers PARTITION (p_zip0) LIMIT 20;

SELECT partition_name, partition_description, table_rows FROM information_schema.partitions 
WHERE table_schema = 'aethermart_db' AND table_name = 'Orders';

SELECT * FROM Orders PARTITION (p_orders_2024) LIMIT 20;
SELECT * FROM Orders PARTITION (p_orders_2025) LIMIT 20;
SELECT * FROM Orders PARTITION (p_orders_2023) LIMIT 20;

SELECT partition_name, partition_description, table_rows FROM information_schema.partitions 
WHERE table_schema = 'aethermart_db' AND table_name = 'Reviews';

SELECT * FROM Reviews PARTITION (p_poor_reviews) LIMIT 20;
SELECT * FROM Reviews PARTITION (p_good_reviews) LIMIT 20;
SELECT * FROM Reviews PARTITION (p_average_reviews) LIMIT 20;
SELECT * FROM Reviews PARTITION (p_unrated) LIMIT 20;