import pymysql
import pymongo
import sys
from datetime import datetime, date, time
from decimal import Decimal
import urllib.parse # <-- Add this import

# --- Configuration ---
# !! REPLACE THIS with your new server's Private IP
MONGO_HOST = "172.31.30.142" 
MONGO_PORT = 27017
MONGO_DB_NAME = "aethermart_profiles" # We'll use the same DB

# Keep these here, but we will use them in the connection string
# MONGO_DB_NAME = "aethermart_profiles" # This line is redundant, already defined above
MONGO_USER = "aethermart_admin" # The user you just created
MONGO_PASS = "alex_pass"       # The password you set
MONGO_AUTH_DB = "admin" 

MARIA_DB_HOST = "localhost"
MARIA_DB_USER = "alex"
MARIA_DB_PASS = "alex_pass"
MARIA_DB_NAME = "aethermart_db"

def connect_to_databases():
    """Connects to both MariaDB and MongoDB, returning connection objects."""
    try:
        maria_conn = pymysql.connect(
            host=MARIA_DB_HOST,
            user=MARIA_DB_USER,
            password=MARIA_DB_PASS,
            database=MARIA_DB_NAME,
            cursorclass=pymysql.cursors.DictCursor
        )
        print("✅ Successfully connected to MariaDB.")
    except Exception as e:
        print(f"❌ FATAL: Error connecting to MariaDB: {e}")
        return None, None

    try:
        # --- CRITICAL FIX HERE: Include authentication in the MongoDB connection URI ---
        username_quoted = urllib.parse.quote_plus(MONGO_USER)
        password_quoted = urllib.parse.quote_plus(MONGO_PASS)
        mongo_uri = f"mongodb://{username_quoted}:{password_quoted}@{MONGO_HOST}:{MONGO_PORT}/?authSource={MONGO_AUTH_DB}"
        
        mongo_client = pymongo.MongoClient(mongo_uri, serverSelectionTimeoutMS=5000)
        mongo_client.admin.command('ping') # Test connection with auth
        mongo_db = mongo_client[MONGO_DB_NAME]
        print(f"✅ Successfully connected to SECURED MongoDB at {MONGO_HOST}.") # Updated message
    except Exception as e:
        print(f"❌ FATAL: Error connecting to MongoDB: {e}")
        if maria_conn: # Ensure MariaDB connection is closed if MongoDB fails
            maria_conn.close()
        return None, None
        
    return maria_conn, mongo_db

# --- Rest of your migrate2.py code (migrate_customers, migrate_products, migrate_reviews, main) remains the same ---
# (You only need to update the connect_to_databases function)

def migrate_customers(maria_conn, mongo_db):
    """
    EXTRACTS Customers from MariaDB.
    TRANSFORMS them into a flexible NoSQL document.
    LOADS them into the 'customer_profiles' collection.
    """
    print("\n--- Starting Customer Migration ---")
    try:
        with maria_conn.cursor() as cursor:
            cursor.execute("SELECT * FROM Customers")
            all_customers = cursor.fetchall()
        
        customer_documents = []
        for row in all_customers:
            # FIX 1: Convert date to datetime
            sql_reg_date = row['registration_date']
            nosql_reg_date = sql_reg_date
            if isinstance(sql_reg_date, date) and not isinstance(sql_reg_date, datetime):
                nosql_reg_date = datetime.combine(sql_reg_date, time.min)
            
            # FIX 2: Clean zipcode data
            sql_zip = row.get('zipcode')
            nosql_zip = sql_zip.strip() if sql_zip else None
            
            # TRANSFORM: Build the rich document
            doc = {
                "customer_id_sql": row['customer_id'],
                "full_name": f"{row['first_name']} {row['last_name']}",
                "email": row['email'],
                "location": {
                    "city": row['city'],
                    "state": row['state'],
                    "zip": nosql_zip
                },
                "registration_date": nosql_reg_date,
                # ENRICHMENT: Add new fields Maria in Marketing wants
                "recent_activity_log": [],
                "customer_preferences": {},
                "social_media_handles": {}
            }
            customer_documents.append(doc)
        
        if customer_documents:
            print(f"Transform complete: {len(customer_documents)} documents prepared.")
            # LOAD: Clear old data and insert new
            collection = mongo_db['customer_profiles']
            collection.delete_many({}) # Clear for a clean run
            result = collection.insert_many(customer_documents)
            print(f"✅ LOAD complete: Successfully inserted {len(result.inserted_ids)} customer profiles.")
        else:
            print("⚠️ No customers found to migrate.")
            
    except Exception as e:
        print(f"❌ ERROR during customer migration: {e}")

def migrate_products(maria_conn, mongo_db):
    """
    EXTRACTS Products+Categories from MariaDB.
    TRANSFORMS them for a flexible catalog.
    LOADS them into the 'product_catalog' collection.
    """
    print("\n--- Starting Product Migration ---")
    try:
        # EXTRACT: Join Products and Categories to get the category name
        sql = """
        SELECT p.*, c.category_name 
        FROM Products p
        LEFT JOIN Categories c ON p.category_id = c.category_id
        """
        with maria_conn.cursor() as cursor:
            cursor.execute(sql)
            all_products = cursor.fetchall()
        
        product_documents = []
        for row in all_products:
            # TRANSFORM: Build the flexible document for Sarah (Product)
            doc = {
                "product_id_sql": row['product_id'],
                "name": row['product_name'],
                "price": float(row['price']), # Convert Decimal to float for JSON/BSON
                "category": row.get('category_name', 'Uncategorized'),
                # "stock_quantity": row['stock_quantity'],
                "sql_current_rating": float(row['current_rating']) if row.get('current_rating') else None,
                
                # ENRICHMENT: The flexible field for specs
                "specifications": {
                    "note": "Flexible attributes (e.g., 'color', 'wifi_spec', 'consultation_hours') go here."
                }
            }
            product_documents.append(doc)
            
        if product_documents:
            print(f"Transform complete: {len(product_documents)} documents prepared.")
            # LOAD: Clear old data and insert new
            collection = mongo_db['product_catalog']
            collection.delete_many({})
            result = collection.insert_many(product_documents)
            print(f"✅ LOAD complete: Successfully inserted {len(result.inserted_ids)} products.")
        else:
            print("⚠️ No products found to migrate.")

    except Exception as e:
        print(f"❌ ERROR during product migration: {e}")

def migrate_reviews(maria_conn, mongo_db):
    """
    EXTRACTS Reviews from MariaDB.
    TRANSFORMS them to be richer (add media/upvotes).
    LOADS them into the 'reviews' collection.
    """
    print("\n--- Starting Review Migration ---")
    try:
        with maria_conn.cursor() as cursor:
            cursor.execute("SELECT * FROM Reviews")
            all_reviews = cursor.fetchall()
            
        review_documents = []
        for row in all_reviews:
            # FIX 1: Convert date to datetime
            sql_review_date = row['review_date']
            nosql_review_date = sql_review_date
            if isinstance(sql_review_date, date) and not isinstance(sql_review_date, datetime):
                nosql_review_date = datetime.combine(sql_review_date, time.min)
                
            # TRANSFORM: Build the richer review document
            doc = {
                "review_id_sql": row['review_id'],
                "product_id_sql": row['product_id'],
                "customer_id_sql": row['customer_id'],
                "rating": row['rating'],
                "review_text": row['review_text'],
                "review_date": nosql_review_date,
                
                # ENRICHMENT: New fields not possible in SQL
                "media_attachments": [], # Placeholder for image/video URLs
                "upvotes": 0
            }
            review_documents.append(doc)
            
        if review_documents:
            print(f"Transform complete: {len(review_documents)} documents prepared.")
            # LOAD: Clear old data and insert new
            collection = mongo_db['reviews']
            collection.delete_many({})
            result = collection.insert_many(review_documents)
            print(f"✅ LOAD complete: Successfully inserted {len(result.inserted_ids)} reviews.")
        else:
            print("⚠️ No reviews found to migrate.")

    except Exception as e:
        print(f"❌ ERROR during review migration: {e}")


def main():
    print("Starting Hybrid Data Integration (MariaDB -> MongoDB)...")
    maria_conn, mongo_db = connect_to_databases()
    
    if maria_conn is None or mongo_db is None:
        print("❌ Aborting due to connection failure.")
        return

    try:
        # Run the ETL for each part
        migrate_customers(maria_conn, mongo_db)
        migrate_products(maria_conn, mongo_db)
        migrate_reviews(maria_conn, mongo_db)
        
        print("\n🎉 Hybrid Integration Script Finished Successfully! 🎉")
        
    except Exception as e:
        print(f"❌ An unexpected error occurred in main: {e}")
    finally:
        # ALWAYS close connections
        if maria_conn is not None:
            maria_conn.close()
            print("\nMariaDB connection closed.")
        if mongo_db is not None: # Changed from if mongo_db: to if mongo_db is not None:
            mongo_db.client.close()
            print("MongoDB connection closed.")

if __name__ == "__main__":
    main()