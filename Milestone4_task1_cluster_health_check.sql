-- =====================================================================
-- Milestone 4: Task 1 - Cluster Troubleshooting Dashboard
--
-- How to Use: Run this script on any node in your Galera cluster
-- to get a real-time health check.
-- =====================================================================

-- 1. Check Cluster Size: This is the most important check.
-- The value should equal the number of nodes you expect to be online (e.g., 3).
-- If this number is lower than expected, a node has disconnected.
SHOW GLOBAL STATUS LIKE 'wsrep_cluster_size';

-- 2. Check Node State: This tells you the health of the CURRENT node.
-- The value should be 'Synced' (or 4).
-- If it says 'Donor' or 'Joined', it's in the process of syncing.
SHOW GLOBAL STATUS LIKE 'wsrep_local_state_comment';

-- 3. Check Cluster Status: This confirms the cluster is stable.
-- The value should be 'Primary'.
-- If it says 'non-Primary' or 'split-brain', you have a major network issue.
SHOW GLOBAL STATUS LIKE 'wsrep_cluster_status';

-- 4. Check if Node is Ready: This confirms the node is online and ready for queries.
-- The value should be 'ON'.
SHOW GLOBAL STATUS LIKE 'wsrep_ready';

-- 5. Check for Network Issues: These numbers should be 0.
-- If they are high, it means the network is unstable and the cluster
-- is having trouble communicating.
SHOW GLOBAL STATUS LIKE 'wsrep_local_send_queue_avg';
SHOW GLOBAL STATUS LIKE 'wsrep_flow_control_paused';

-- 6. Check for Node Disconnects:
-- A high number here means nodes are frequently dropping from the cluster.
SHOW GLOBAL STATUS LIKE 'wsrep_cluster_state_uuid';
-- (If this UUID is different across nodes, they are not in sync)

-- 7. How to find the *detailed* error log:
-- If any of the above look wrong, the first place to find the *reason*
-- is the system journal. Exit MariaDB and run this in your terminal:
--
-- sudo journalctl -xeu mariadb.service
--
-- This log will tell you *why* a node failed to join or disconnected.
