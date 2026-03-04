mongosh -u 'aethermart_admin' 
alex_pass

// (In Terminal 2)
use aethermart_profiles

// This is the 'show tables' equivalent
show collections

mariadb aethermart_db

db.customer_profiles.find({ "customer_id_sql": 5 }).pretty()
SELECT * FROM Customers WHERE customer_id = ;
SELECT * FROM Customers WHERE customer_id = 5;

db.product_catalog.findOne()
db.product_catalog.findOne({ "product_id_sql": 101 })
SELECT * FROM Products WHERE customer_id = ;
SELECT * FROM Products WHERE customer_id = 101;
SELECT p.product_id, p.product_name, p.price, c.category_name 
FROM Products p 
JOIN Categories c ON p.category_id = c.category_id 
WHERE p.product_id = 101;

db.reviews.findOne().pretty()
db.reviews.findOne({ "review_id_sql": 3001 }).pretty()
SELECT * FROM Reviews WHERE review_id = ;
SELECT * FROM Reviews WHERE review_id = 3001; 

-- For Maria's '360-degree view', we need to add a clickstream event."
db.customer_profiles.updateOne(
  { "customer_id_sql": 5 },
  { 
    $push: { 
      "recent_activity_log": {
        "timestamp": new Date(), 
        "action": "view_product", 
        "product_id": 205
      }
    }
  }
)

DESCRIBE Customers;

-- "Next, for Sarah's 'flexible schema', I'll add completely different specs to two products, 101 and 102.
// (In Terminal 2: MongoDB)
// Add Smart Speaker specs to Product 101

db.product_catalog.updateOne(
  { "product_id_sql": 101 },
  { $set: { "specifications": { "color": "Charcoal", "wifi_standard": "Wi-Fi 6E" } } }
)

// Add *different* Digital Service specs to Product 102

db.product_catalog.updateOne(
  { "product_id_sql": 102 },
  { $set: { "specifications": { "consultation_platform": "Zoom", "duration_hours": 2 } } }
)

// Now, let's view them both
db.product_catalog.find({ "product_id_sql": { $in: [101, 102] } }).pretty()

SELECT product_id, product_name FROM Products WHERE product_id = 101 ;


-- Alex's "Real-Time Analytics" (NoSQL-Only)
--(In Terminal 2: MongoDB)
-- "Finally, for Alex's analytics, we'll run an aggregation on our live customer data." 

db.customer_profiles.aggregate([
  { $group: { _id: "$location.state", count: { $sum: 1 } } },
  { $sort: { count: -1 } }
])

