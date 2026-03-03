INSERT INTO Products (product_id, product_name, category_id, supplier_id, price) VALUES (999, 'Replication Test Product', 1, 1, 123.45);
-- On Replica 1 & 2
SELECT * FROM Products WHERE product_id = 999;

INSERT INTO Products (product_id, product_name, category_id, supplier_id, price) VALUES (9999, 'Replication Test Product', 1, 1, 123.45);

UPDATE Products SET price = 543.21 WHERE product_id = 999;
-- On Replica 1 & 2
SELECT product_name, price FROM Products WHERE product_id = 999;

DELETE FROM Products WHERE product_id = 999;
-- On Replica 1 & 2
SELECT * FROM Products WHERE product_id = 999;


