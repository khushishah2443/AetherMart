sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf

systemctl daemon-reload

# Run this on Node 1 only
sudo galera_new_cluster

# Run this on Node 2 & 3
sudo systemctl start mariadb

SHOW STATUS LIKE 'wsrep_cluster_size';

INSERT INTO Customers (customer_id, first_name, last_name, email, city, state, zipcode) VALUES (999, 'Test', 'Customer', 'test@failover.com', 'ClusterCity', 'HA', '99999');

SELECT * FROM Customers WHERE customer_id = 999;

SELECT * FROM Customers WHERE customer_id = 999;


--On NODE 2
sudo systemctl stop mariadb

--On Node 1 & 3
mariadb

SHOW STATUS LIKE 'wsrep_cluster_size';

SELECT * FROM Customers WHERE customer_id = 999;

INSERT INTO Customers (customer_id, first_name, last_name, email, city, state, zipcode) VALUES (888, 'Failover', 'Success', 'active@cluster.com', 'OnlineTown', 'OK', '88888');

SELECT * FROM Customers WHERE customer_id = 888;

-- ON NODE 2
sudo systemctl start mariadb

--On Node 1 & 3
SHOW STATUS LIKE 'wsrep_cluster_size';

-- ON NODE 2
USE aethermart_db;
SELECT * FROM Customers WHERE customer_id = 999;
SELECT * FROM Customers WHERE customer_id = 888;