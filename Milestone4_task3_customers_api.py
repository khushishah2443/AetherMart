#!/usr/bin/env python3
"""
AetherMart CUSTOMER Embedding Generator (v1)
STEP 1: This script prepares the Customers table, engineers
a "purchase profile" feature, and loads all vectors.
RUN THIS SCRIPT FIRST.
"""

import pymysql
import google.generativeai as genai
import time
import sys
import os

# =====================================================================
# CONFIGURATION
# =====================================================================
DB_USER = "alex"
DB_PASS = "alex_pass"
DB_HOST = "localhost"
DB_NAME = "aethermart_db"

API_KEY = os.environ.get('GEMINI_API_KEY')
if not API_KEY:
    API_KEY = "AIzaSyCxZvgc-V6iUN66NYlGx7nNfnEPKsduodM" # <-- PASTE YOUR KEY

MODEL_NAME = "models/embedding-001"
EMBEDDING_DIMENSION = 768

DB_CONFIG = {
    'host': DB_HOST,
    'user': DB_USER,
    'password': DB_PASS,
    'database': DB_NAME,
    'charset': 'utf8mb4',
    'cursorclass': pymysql.cursors.DictCursor
}
# =====================================================================

def connect_db():
    """Establish database connection"""
    try:
        connection = pymysql.connect(**DB_CONFIG)
        print("✅ Connected to MariaDB successfully!")
        return connection
    except Exception as e:
        print(f"❌ Error connecting to database: {e}")
        raise

def prepare_customers_table(connection):
    """Prepares the Customers table for embedding."""
    try:
        with connection.cursor() as cursor:
            # --- STEP 1: REMOVE PARTITIONING (Fixes 1506 Error) ---
            # Milestone 2 partitioned Customers by zipcode. We must remove this.
            cursor.execute("""
                SELECT COUNT(*) as count 
                FROM INFORMATION_SCHEMA.PARTITIONS 
                WHERE TABLE_SCHEMA = %s
                AND TABLE_NAME = 'Customers'
                AND PARTITION_NAME IS NOT NULL
            """, (DB_NAME,))
            result = cursor.fetchone()
            
            if result['count'] > 0:
                print("ℹ️  Partitioning found on 'Customers' table.")
                print("   Removing partitioning to enable VECTOR features...")
                cursor.execute("ALTER TABLE Customers REMOVE PARTITIONING")
                connection.commit()
                print("✅ Partitioning removed.")
            else:
                print("ℹ️  'Customers' table is not partitioned. Good to go.")

            # --- STEP 2: REDO THE COLUMN (Starts fresh) ---
            print("🔄 Starting fresh: Dropping old index and column...")
            cursor.execute("DROP INDEX IF EXISTS idx_customer_embedding ON Customers")
            cursor.execute("ALTER TABLE Customers DROP COLUMN IF EXISTS customer_embedding")
            
            # --- STEP 3: Add the column as NULLable ---
            print(f"Adding new 'customer_embedding' VECTOR({EMBEDDING_DIMENSION}) NULL column...")
            cursor.execute(f"""
                ALTER TABLE Customers 
                ADD COLUMN customer_embedding VECTOR({EMBEDDING_DIMENSION}) NULL
            """)
            connection.commit()
            print("✅ Column created successfully.")
            print("ℹ️  Skipping index creation. We will do this manually after.")

    except Exception as e:
        print(f"❌ Error preparing Customers table: {e}")
        raise

def fetch_customer_profiles(connection):
    """
    This is the core FEATURE ENGINEERING step.
    It builds a purchase profile for each customer.
    """
    print("🔄 Building customer purchase profiles...")
    try:
        with connection.cursor() as cursor:
            # This complex query JOINS 5 tables to find all categories
            # a customer has purchased from.
            sql = """
                SELECT 
                    c.customer_id,
                    c.first_name,
                    c.last_name,
                    c.city,
                    c.state,
                    -- Use GROUP_CONCAT to get a unique list of categories
                    GROUP_CONCAT(DISTINCT cat.category_name SEPARATOR ', ') AS purchase_categories
                FROM 
                    Customers c
                LEFT JOIN 
                    Orders o ON c.customer_id = o.customer_id
                LEFT JOIN 
                    Order_Items oi ON o.order_id = oi.order_id
                LEFT JOIN 
                    Products p ON oi.product_id = p.product_id
                LEFT JOIN 
                    Categories cat ON p.category_id = cat.category_id
                WHERE
                    c.customer_embedding IS NULL
                GROUP BY
                    c.customer_id, c.first_name, c.last_name, c.city, c.state
                ORDER BY
                    c.customer_id
            """
            cursor.execute(sql)
            customers = cursor.fetchall()
            print(f"✅ Fetched {len(customers)} customer profiles to be vectorized.")
            return customers
    except Exception as e:
        print(f"❌ Error fetching customer profiles: {e}")
        raise

def generate_embeddings_gemini(customers):
    """Generate embeddings using Google Gemini API"""
    print(f"\n🔄 Initializing Google Gemini API...")
    genai.configure(api_key=API_KEY)
    print(f"🔄 Generating embeddings using {MODEL_NAME}...")
    
    embeddings_data = []
    failed_customers = []
    
    for i, customer in enumerate(customers, 1):
        
        # --- FEATURE ENGINEERING (The "Lookalike" String) ---
        profile = f"Customer {customer['first_name']} from {customer['city']}, {customer['state']}."
        
        if customer['purchase_categories']:
            profile += f" This customer primarily buys: {customer['purchase_categories']}."
        else:
            profile += " This customer has no purchase history."
        
        text_to_embed = profile
        
        try:
            result = genai.embed_content(
                model=MODEL_NAME,
                content=text_to_embed,
                task_type="retrieval_document" # Store this vector
            )
            
            embeddings_data.append({
                'customer_id': customer['customer_id'],
                'embedding': result['embedding']
            })
            
            if i % 10 == 0 or i == len(customers):
                print(f"   Progress: {i}/{len(customers)} customers embedded")
            
            time.sleep(1.1) # Rate limiting
                
        except Exception as e:
            print(f"⚠️  Error embedding customer {customer['customer_id']}: {e}")
            failed_customers.append(customer['customer_id'])
            time.sleep(2)
    
    print(f"\n✅ Generated embeddings for {len(embeddings_data)} customers")
    if failed_customers:
        print(f"⚠️  Failed customers: {failed_customers}")
    
    return embeddings_data

def vector_to_string(vector):
    """Convert vector list to MariaDB VECTOR format string"""
    return '[' + ','.join([f"{v:.8f}" for v in vector]) + ']'

def load_embeddings_to_db(connection, embeddings_data):
    """Load embeddings into MariaDB"""
    print("\n🔄 Loading embeddings into database...")
    
    try:
        with connection.cursor() as cursor:
            update_count = 0
            for data in embeddings_data:
                sql = """
                    UPDATE Customers 
                    SET customer_embedding = VEC_FromText(%s)
                    WHERE customer_id = %s
                """
                cursor.execute(sql, (vector_to_string(data['embedding']), data['customer_id']))
                update_count += 1
                
                if update_count % 10 == 0 or update_count == len(embeddings_data):
                    connection.commit()
                    print(f"   Progress: {update_count}/{len(embeddings_data)} customers updated")
            
            connection.commit()
            print(f"\n✅ Successfully loaded embeddings for {update_count} customers!")
            
    except Exception as e:
        connection.rollback()
        print(f"❌ Error loading embeddings: {e}")
        raise

def main():
    print("=" * 70)
    print("       AetherMart CUSTOMER Embedding Generator")
    print("=" * 70)
    
    connection = None
    try:
        connection = connect_db()
        prepare_customers_table(connection)
        customers = fetch_customer_profiles(connection)
        
        if not customers:
            print("⚠️  No customers found to vectorize (or they are all done).")
            return
        
        print(f"\nThis will vectorize {len(customers)} customers.")
        response = input(f"Proceed? (y/n): ")
        if response.lower() != 'y':
            print("❌ Cancelled by user")
            return
        
        embeddings_data = generate_embeddings_gemini(customers)
        
        if not embeddings_data:
            print("❌ No embeddings generated. Check API key and network.")
            return
        
        load_embeddings_to_db(connection, embeddings_data)
        
        print("\n" + "=" * 70)
        print("✅ CUSTOMER EMBEDDING (STEP 1) COMPLETE!")
        print("   ALL VECTORS ARE LOADED.")
        print("=" * 70)
        print("\n   NEXT STEP: Run the SQL script to build the index:")
        print("   sudo mariadb -u alex -p < create_customer_index.sql")
        
    except KeyboardInterrupt:
        print("\n\n⚠️  Interrupted by user")
    except Exception as e:
        print(f"\n❌ Fatal error: {e}")
    finally:
        if connection:
            connection.close()
            print("\n🔒 Database connection closed")

if __name__ == "__main__":
    main()

