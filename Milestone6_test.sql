sudo su -

export MARIA_DB_USER="alex"
export MARIA_DB_PASS="alex_pass"
export MONGO_USER="aethermart_admin"
export MONGO_PASS="alex_pass"
export MONGO_ADMIN_USER="admin" # For orchestrator.py
export MONGO_ADMIN_PASS="password" # For orchestrator.py

source .venv/bin/activate

python3 orchestrator.py
cat aethermart_pipeline.log

nano mongo_sync_worker.py
python3 mongo_sync_worker.py

mariadb -u 'alex' -p
alex_pass
USE aethermart_db;

mongosh -u 'aethermart_admin' -p 
alex_pass
use aethermart_profiles

-- //CUSTOMERS

SELECT * from customer_sync_queue;
SELECT * from Customers limit 5;

INSERT INTO Customers (customer_id, first_name, last_name, email, registration_date, city, state, zipcode)
VALUES (9001, 'Jane', 'Doe', 'jane.doe@example.com', '2024-09-27', 'North Gina', 'PA','06052');

SELECT * FROM Customers WHERE customer_id = 9001;

python3 mongo_sync_worker.py
cat realtime_sync.log

SELECT * from customer_sync_queue;

db.customer_profiles.find({ "customer_id_sql": 9001 }).pretty();

-- //PRODUCTS
 
SELECT * from product_sync_queue;
SELECT * from Products limit 5;

UPDATE Products SET price = 159.99 where product_id = 101;

SELECT * FROM Products where product_id = 101;

python3 mongo_sync_worker.py
cat realtime_sync.log

SELECT * from product_sync_queue;

db.product_catalog.find({ "product_id_sql": 101 }).pretty();

-- //REVIEWS
 
SELECT * from reviews_sync_queue;
SELECT * from Reviews limit 5;

UPDATE Reviews SET rating = 3 WHERE review_id = 3010;

SELECT * from Reviews WHERE review_id = 3010;

python3 mongo_sync_worker.py
cat realtime_sync.log

SELECT * from review_sync_queue;

db.reviews.find({ "review_id_sql": 3010 }).pretty();


mariadb -u maria -p
USE aethermart_db;
SELECT * FROM v_rbac_audit ORDER BY timestamp DESC LIMIT 5;

mariadb -u alex -p
USE aethermart_db;
SELECT * from data_lineage_tracker;
SELECT * from data_quality_logs;
SELECT * FROM v_rbac_audit LIMIT 5;
SELECT * from data_dictionary;
SELECT * FROM v_customers_masked ESC LIMIT 5;
