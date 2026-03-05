import pymysql
import pymongo
import sys
import time
import logging
import urllib.parse
from datetime import datetime, date
import decimal

# --- CONFIGURATION ---
MONGO_HOST = "172.31.30.142" 
MONGO_PORT = 27017

# --- MONGODB SECURITY ---
MONGO_DB_NAME = "aethermart_profiles"
MONGO_USER = "aethermart_admin" 
MONGO_PASS = "alex_pass"       
MONGO_AUTH_DB = "admin"        

# --- MARIADB CONFIGURATION ---
MARIA_DB_HOST = "localhost"
MARIA_DB_USER = "alex" 
MARIA_DB_PASS = "alex_pass"
MARIA_DB_NAME = "aethermart_db"

# --- LOGGING ---
LOG_FILE = "realtime_sync.log"
logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - [Mongo Sync Worker] - %(message)s'
)

def get_maria_connection():
    try:
        conn = pymysql.connect(
            host=MARIA_DB_HOST, user=MARIA_DB_USER, password=MARIA_DB_PASS,
            database=MARIA_DB_NAME, cursorclass=pymysql.cursors.DictCursor, autocommit=True
        )
        return conn
    except Exception as e:
        logging.error(f"Error connecting to MariaDB: {e}")
        return None

def get_mongo_collection(collection_name):
    try:
        username = urllib.parse.quote_plus(MONGO_USER)
        password = urllib.parse.quote_plus(MONGO_PASS)
        mongo_uri = f"mongodb://{username}:{password}@{MONGO_HOST}:{MONGO_PORT}/?authSource={MONGO_AUTH_DB}"
        client = pymongo.MongoClient(mongo_uri, serverSelectionTimeoutMS=5000)
        return client[MONGO_DB_NAME][collection_name]
    except Exception as e:
        logging.error(f"Error connecting to MongoDB: {e}")
        return None

def clean_value(value):
    """Helper to strip whitespace/newlines from strings."""
    if isinstance(value, str):
        return value.strip()
    return value

def process_queue(queue_table, mongo_collection_name, id_field, mongo_id_field, data_fields):
    maria_conn = get_maria_connection()
    mongo_coll = get_mongo_collection(mongo_collection_name)

    if maria_conn is None or mongo_coll is None:
        print(f"❌ Connection failed for {queue_table}")
        return

    try:
        with maria_conn.cursor() as cursor:
            print(f"Checking {queue_table}...")
            cursor.execute(f"SELECT * FROM {queue_table} WHERE sync_status = 'PENDING'")
            pending_jobs = cursor.fetchall()

            if not pending_jobs:
                print(f"No pending jobs in {queue_table}.")
                return

            for job in pending_jobs:
                queue_id = job['queue_id']
                item_id = job[id_field]
                
                # The document to set, starting with the SQL ID for identification
                # We will build this carefully based on existing MongoDB schema from migrate.py
                update_set_doc = {
                    mongo_id_field: item_id, # Ensure the identifying field is always present
                    "last_synced_at": datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                }
                
                # --- Specific Mapping Logic based on your MongoDB Schema from migrate.py ---
                if queue_table == "customer_sync_queue":
                    # Map MariaDB first_name, last_name to MongoDB full_name
                    first_name = clean_value(job.get("first_name", ""))
                    last_name = clean_value(job.get("last_name", ""))
                    update_set_doc["full_name"] = f"{first_name} {last_name}".strip()
                    
                    # Map MariaDB city, state, zipcode to MongoDB location sub-document
                    update_set_doc["location.city"] = clean_value(job.get("city"))
                    update_set_doc["location.state"] = clean_value(job.get("state"))
                    update_set_doc["location.zip"] = clean_value(job.get("zipcode")) # Assuming 'zip' key for zipcode in location
                    
                    # Map other direct fields
                    update_set_doc["email"] = clean_value(job.get("email"))
                    # Note: registration_date is typically set once during initial migration, 
                    # not updated by the sync queue unless you specifically want to sync it.
                    # customer_preferences, social_media_handles, recent_activity_log are also generally not updated here.

                elif queue_table == "product_sync_queue":
                    # Map MariaDB fields directly to MongoDB fields for products
                    update_set_doc["name"] = clean_value(job.get("product_name")) # Mapping to 'name' as per your migrate.py
                    update_set_doc["price"] = float(job.get("price")) if job.get("price") is not None else 0.0
                    # If 'category' can change, you'd add it here if category_name is in your product_sync_queue
                    # update_set_doc["category"] = clean_value(job.get("category_name")) # If category_name is in queue
                    
                elif queue_table == "review_sync_queue":
                    # Map MariaDB fields directly to MongoDB fields for reviews
                    update_set_doc["customer_id_sql"] = job.get("customer_id") # Direct ID from MariaDB, keeping _sql suffix
                    update_set_doc["product_id_sql"] = job.get("product_id") # Direct ID from MariaDB, keeping _sql suffix
                    update_set_doc["rating"] = float(job.get("rating")) if job.get("rating") is not None else 0.0
                    update_set_doc["review_text"] = clean_value(job.get("review_text"))
                    # Convert date to ISODate string format if that's what migrate.py did
                    review_date_val = job.get("review_date")
                    if isinstance(review_date_val, (datetime, date)):
                        update_set_doc["review_date"] = review_date_val.isoformat() # or .strftime('%Y-%m-%d')
                    else:
                        update_set_doc["review_date"] = review_date_val


                try:
                    # Filter by the mongo_id_field (e.g., customer_id_sql)
                    # Use $set to update specific fields without overwriting the entire document
                    mongo_coll.update_one(
                        {mongo_id_field: item_id},
                        {"$set": update_set_doc},
                        upsert=True # upsert: true will create a new doc if no match found
                    )
                    
                    cursor.execute(f"UPDATE {queue_table} SET sync_status = 'COMPLETED' WHERE queue_id = %s", (queue_id,))
                    print(f"✅ Synced {queue_table} Item {item_id} (using {mongo_id_field})")
                except Exception as e:
                    logging.error(f"Sync failed for {item_id}: {e}")
                    cursor.execute(f"UPDATE {queue_table} SET sync_status = 'FAILED' WHERE queue_id = %s", (queue_id,))

    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        if maria_conn: maria_conn.close()

if __name__ == "__main__":
    # The 'data_fields' here are no longer used for direct mapping
    # but rather indicate which fields from the SQL job should be available
    # for custom mapping logic within process_queue.
    sync_jobs = [
        {
            "queue_table": "product_sync_queue",
            "mongo_collection": "product_catalog",
            "id_field": "product_id",
            "mongo_id_field": "product_id_sql",
            "data_fields": ["product_name", "price"] # These are the fields from SQL queue
        },
        {
            "queue_table": "customer_sync_queue",
            "mongo_collection": "customer_profiles",
            "id_field": "customer_id",
            "mongo_id_field": "customer_id_sql",
            "data_fields": ["first_name", "last_name", "email", "city", "state", "zipcode"] # These are fields from SQL queue
        },
        {
            "queue_table": "review_sync_queue",
            "mongo_collection": "reviews",
            "id_field": "review_id",
            "mongo_id_field": "review_id_sql",
            "data_fields": ["customer_id", "product_id", "rating", "review_text", "review_date"] # These are fields from SQL queue
        }
    ]

    for job in sync_jobs:
        process_queue(
            job["queue_table"], 
            job["mongo_collection"], 
            job["id_field"], 
            job["mongo_id_field"], 
            job["data_fields"]
        )
    
    print("\nReal-time sync worker finished.")