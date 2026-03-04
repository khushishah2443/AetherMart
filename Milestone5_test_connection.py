import pymysql
import pymongo
import sys
# Import the datetime objects we need for the fix
from datetime import datetime, date, time

# --- Configuration ---
# !! REPLACE THIS with your new server's Private IP
MONGO_HOST = "172.31.30.142" 
MONGO_PORT = 27017

# --- NEW MONGODB SECURITY ---
MONGO_DB_NAME = "aethermart_profiles"
MONGO_COLLECTION_NAME = "customer_activity"
MONGO_USER = "aethermart_admin" # The user you just created
MONGO_PASS = "alex_pass"       # The password you set
MONGO_AUTH_DB = "admin"        # The DB where the user is stored
# -----------------------------

MARIA_DB_HOST = "localhost"
MARIA_DB_USER = "alex" # Using alex's all-privileges account
MARIA_DB_PASS = "alex_pass"
MARIA_DB_NAME = "aethermart_db"

# --- Main Script ---
def main():
    print(f"Connecting to MariaDB at {MARIA_DB_HOST}...")
    try:
        # Connect to MariaDB
        maria_conn = pymysql.connect(
            host=MARIA_DB_HOST,
            user=MARIA_DB_USER,
            password=MARIA_DB_PASS,
            database=MARIA_DB_NAME,
            cursorclass=pymysql.cursors.DictCursor
        )
    except Exception as e:
        print(f"Error connecting to MariaDB: {e}")
        sys.exit(1)

    print(f"Connecting to SECURED MongoDB at {MONGO_HOST}...")
    try:
        # Connect to MongoDB with authentication
        mongo_client = pymongo.MongoClient(
            host=MONGO_HOST,
            port=MONGO_PORT,
            username=MONGO_USER,
            password=MONGO_PASS,
            authSource=MONGO_AUTH_DB,
            serverSelectionTimeoutMS=5000 # 5-second timeout
        )
        # Ping the server to test connection
        mongo_client.admin.command('ping') 
        mongo_db = mongo_client[MONGO_DB_NAME]
        mongo_collection = mongo_db[MONGO_COLLECTION_NAME]
    except Exception as e:
        print(f"Error connecting to MongoDB: {e}")
        maria_conn.close()
        sys.exit(1)

    print("Successfully connected to both databases.")

    # 1. FETCH data from MariaDB
    try:
        with maria_conn.cursor() as cursor:
            # Let's grab customer ID 5
            cursor.execute("SELECT * FROM Customers WHERE customer_id = 5")
            customer_sql_data = cursor.fetchone()

        if not customer_sql_data:
            print("Customer 5 not found in MariaDB.")
            return

        print(f"\nFetched from MariaDB:\n{customer_sql_data}\n")

        # 2. TRANSFORM data and add new unstructured data
        
        # --- FIX 1: Convert datetime.date to datetime.datetime ---
        sql_reg_date = customer_sql_data['registration_date']
        nosql_reg_date = sql_reg_date 
        if isinstance(sql_reg_date, date) and not isinstance(sql_reg_date, datetime):
            nosql_reg_date = datetime.combine(sql_reg_date, time.min)
        
        # --- FIX 2: Clean the zipcode data ---
        sql_zip = customer_sql_data.get('zipcode') # Use .get for safety
        nosql_zip = sql_zip.strip() if sql_zip else None

        # Build the final document for MongoDB
        customer_nosql_doc = {
            "customer_id_sql": customer_sql_data['customer_id'],
            "full_name": f"{customer_sql_data['first_name']} {customer_sql_data['last_name']}",
            "location": {
                "city": customer_sql_data['city'],
                "state": customer_sql_data['state'],
                "zip": nosql_zip
            },
            "registration_date": nosql_reg_date,
            "recent_activity_log": [
                {"timestamp": "2025-11-05T20:10:00Z", "action": "view_product", "product_id": 101},
                {"timestamp": "2025-11-05T20:10:15Z", "action": "add_to_cart", "product_id": 101},
                {"timestamp": "2025-11-05T20:11:30Z", "action": "view_category", "category": "Smart Home"}
            ],
            "customer_preferences": {
                "comm_channel": "email",
                "interests": ["smart_home", "ai_consultations", "wearables"]
            }
        }
        
        print(f"Prepared NoSQL Document:\n{customer_nosql_doc}\n")

        # 3. LOAD data into MongoDB
        result = mongo_collection.update_one(
            {'customer_id_sql': customer_sql_data['customer_id']},
            {'$set': customer_nosql_doc},
            upsert=True
        )
        
        if result.upserted_id:
            print(f"Successfully INSERTED new document with ID: {result.upserted_id}")
        elif result.matched_count > 0:
            print(f"Successfully UPDATED existing document for customer 5.")

    except Exception as e:
        print(f"An error occurred during ETL: {e}")
    finally:
        # Clean up connections
        maria_conn.close()
        mongo_client.close()
        print("\nConnections closed.")

if __name__ == "__main__":
    main()