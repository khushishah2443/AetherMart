#!/usr/bin/env python3
"""
Product Description Vector Embedding Generator using Google Gemini API
Generates embeddings and loads them into MariaDB
"""

import pymysql
import google.generativeai as genai
import time
import sys

# =====================================================================
# CONFIGURATION - EDIT THESE VALUES
# =====================================================================
DB_USER = "alex"
DB_PASS = "alex_pass"
DB_HOST = "localhost"
DB_NAME = "aethermart_db"

API_KEY = "AIzaSyCxZvgc-V6iUN66NYlGx7nNfnEPKsduodM"  # <-- PASTE YOUR API KEY HERE
MODEL_NAME = "models/embedding-001"

EMBEDDING_DIMENSION = 768  # Gemini embedding-001 produces 768-dim vectors

# Database Configuration
DB_CONFIG = {
    'host': DB_HOST,
    'user': DB_USER,
    'password': DB_PASS,
    'database': DB_NAME,
    'charset': 'utf8mb4',
    'cursorclass': pymysql.cursors.DictCursor
}

# =====================================================================
# FUNCTIONS
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

def add_vector_column(connection):
    """Add product_embedding column to Products table"""
    try:
        with connection.cursor() as cursor:
            # Check if column already exists
            cursor.execute("""
                SELECT COUNT(*) as count 
                FROM INFORMATION_SCHEMA.COLUMNS 
                WHERE TABLE_SCHEMA = %s
                AND TABLE_NAME = 'Products' 
                AND COLUMN_NAME = 'product_embedding'
            """, (DB_NAME,))
            result = cursor.fetchone()
            
            if result['count'] == 0:
                print(f"Adding product_embedding VECTOR({EMBEDDING_DIMENSION}) column...")
                cursor.execute(f"""
                    ALTER TABLE Products 
                    ADD COLUMN product_embedding VECTOR({EMBEDDING_DIMENSION}) 
                    AFTER product_description
                """)
                connection.commit()
                print(f"✅ Added product_embedding VECTOR({EMBEDDING_DIMENSION}) column")
            else:
                print("ℹ️  product_embedding column already exists")
                # Optionally, clear existing embeddings
                response = input("Clear existing embeddings? (y/n): ")
                if response.lower() == 'y':
                    cursor.execute("UPDATE Products SET product_embedding = NULL")
                    connection.commit()
                    print("✅ Cleared existing embeddings")
    except Exception as e:
        print(f"❌ Error adding vector column: {e}")
        raise

def fetch_products(connection):
    """Fetch all products with descriptions"""
    try:
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT 
                    p.product_id,
                    p.product_name,
                    p.product_description,
                    c.category_name,
                    p.price
                FROM Products p
                JOIN Categories c ON p.category_id = c.category_id
                WHERE p.product_description IS NOT NULL 
                AND p.product_description != ''
                ORDER BY p.product_id
            """)
            products = cursor.fetchall()
            print(f"✅ Fetched {len(products)} products with descriptions")
            return products
    except Exception as e:
        print(f"❌ Error fetching products: {e}")
        raise

def generate_embeddings_gemini(products):
    """Generate embeddings using Google Gemini API"""
    print(f"\n🔄 Initializing Google Gemini API...")
    
    # Validate API key
    if API_KEY == "YOUR_GEMINI_API_KEY_HERE" or not API_KEY:
        print("❌ ERROR: Please set your Gemini API key!")
        print("   Get it from: https://aistudio.google.com/app/apikey")
        sys.exit(1)
    
    genai.configure(api_key=API_KEY)
    
    print(f"🔄 Generating embeddings using {MODEL_NAME}...")
    embeddings_data = []
    failed_products = []
    
    for i, product in enumerate(products, 1):
        # Combine product information for richer embedding
        text_to_embed = (
            f"Product: {product['product_name']}. "
            f"Description: {product['product_description']} "
            f"Category: {product['category_name']}. "
            f"Price: ${product['price']}"
        )
        
        try:
            # Generate embedding using Gemini
            result = genai.embed_content(
                model=MODEL_NAME,
                content=text_to_embed,
                task_type="retrieval_document"
            )
            
            embedding = result['embedding']
            
            embeddings_data.append({
                'product_id': product['product_id'],
                'product_name': product['product_name'],
                'embedding': embedding
            })
            
            if i % 10 == 0:
                print(f"   Progress: {i}/{len(products)} products embedded")
            
            # Rate limiting: Gemini free tier = 60 requests/minute
            # Sleep for 1 second every request to be safe (60 req/min = 1 req/sec)
            time.sleep(1.1)
                
        except Exception as e:
            print(f"⚠️  Error embedding product {product['product_id']}: {e}")
            failed_products.append(product['product_id'])
            time.sleep(2)  # Extra delay after error
    
    print(f"\n✅ Generated embeddings for {len(embeddings_data)} products")
    if failed_products:
        print(f"⚠️  Failed products: {failed_products}")
    
    return embeddings_data

def vector_to_string(vector):
    """Convert vector list to MariaDB VECTOR format string"""
    vector_str = '[' + ','.join([f"{v:.8f}" for v in vector]) + ']'
    return vector_str

def load_embeddings_to_db(connection, embeddings_data):
    """Load embeddings into MariaDB"""
    print("\n🔄 Loading embeddings into database...")
    
    try:
        with connection.cursor() as cursor:
            update_count = 0
            errors = []
            
            for data in embeddings_data:
                product_id = data['product_id']
                embedding_vector = vector_to_string(data['embedding'])
                
                try:
                    # Update product with embedding
                    sql = """
                        UPDATE Products 
                        SET product_embedding = VEC_FromText(%s)
                        WHERE product_id = %s
                    """
                    cursor.execute(sql, (embedding_vector, product_id))
                    update_count += 1
                    
                    if update_count % 10 == 0:
                        connection.commit()
                        print(f"   Progress: {update_count}/{len(embeddings_data)} products updated")
                        
                except Exception as e:
                    print(f"⚠️  Error updating product {product_id}: {e}")
                    errors.append(product_id)
            
            # Final commit
            connection.commit()
            print(f"\n✅ Successfully loaded embeddings for {update_count} products!")
            
            if errors:
                print(f"⚠️  Errors occurred for products: {errors}")
            
    except Exception as e:
        connection.rollback()
        print(f"❌ Error loading embeddings: {e}")
        raise

def verify_embeddings(connection):
    """Verify that embeddings were loaded correctly"""
    print("\n" + "="*70)
    print("VERIFICATION RESULTS")
    print("="*70)
    
    try:
        with connection.cursor() as cursor:
            # Count products with embeddings
            cursor.execute("""
                SELECT COUNT(*) as count 
                FROM Products 
                WHERE product_embedding IS NOT NULL
            """)
            result = cursor.fetchone()
            print(f"✅ Products with embeddings: {result['count']}")
            
            # Count total products with descriptions
            cursor.execute("""
                SELECT COUNT(*) as count 
                FROM Products 
                WHERE product_description IS NOT NULL
            """)
            result = cursor.fetchone()
            print(f"📊 Total products with descriptions: {result['count']}")
            
            # Show sample embeddings
            cursor.execute("""
                SELECT 
                    product_id,
                    product_name,
                    VEC_Dimensions(product_embedding) as dimensions
                FROM Products 
                WHERE product_embedding IS NOT NULL 
                LIMIT 5
            """)
            samples = cursor.fetchall()
            
            if samples:
                print(f"\n📝 Sample Products:")
                for sample in samples:
                    print(f"   • ID {sample['product_id']}: {sample['product_name']} (Dims: {sample['dimensions']})")
            
            # Test a similarity query
            print("\n🔍 Testing similarity search for Product ID 1...")
            cursor.execute("""
                SELECT 
                    p2.product_id,
                    p2.product_name,
                    ROUND((1 - VEC_DISTANCE_COSINE(
                        (SELECT product_embedding FROM Products WHERE product_id = 1),
                        p2.product_embedding
                    )) * 100, 2) as similarity
                FROM Products p2
                WHERE p2.product_id != 1
                  AND p2.product_embedding IS NOT NULL
                ORDER BY similarity DESC
                LIMIT 3
            """)
            similar = cursor.fetchall()
            
            if similar:
                print("   Most similar products:")
                for s in similar:
                    print(f"   • {s['product_name']} (Similarity: {s['similarity']}%)")
            
    except Exception as e:
        print(f"❌ Error verifying embeddings: {e}")

def main():
    """Main execution function"""
    print("=" * 70)
    print("       AetherMart Product Embedding Generator")
    print("              (Google Gemini API)")
    print("=" * 70)
    print()
    
    connection = None
    
    try:
        # Connect to database
        connection = connect_db()
        
        # Add vector column if not exists
        add_vector_column(connection)
        
        # Fetch products
        products = fetch_products(connection)
        
        if not products:
            print("⚠️  No products with descriptions found.")
            print("   Please run the product description UPDATE statements first!")
            return
        
        print(f"\n⏱️  Estimated time: ~{len(products)} seconds (rate limited)")
        response = input("\nProceed with embedding generation? (y/n): ")
        
        if response.lower() != 'y':
            print("❌ Cancelled by user")
            return
        
        # Generate embeddings
        embeddings_data = generate_embeddings_gemini(products)
        
        if not embeddings_data:
            print("❌ No embeddings generated. Please check API key and network.")
            return
        
        # Load embeddings to database
        load_embeddings_to_db(connection, embeddings_data)
        
        # Verify
        verify_embeddings(connection)
        
        print("\n" + "=" * 70)
        print("✅ EMBEDDING GENERATION COMPLETE!")
        print("=" * 70)
        print("\nNext steps:")
        print("1. Run similarity search queries: mysql -u alex -p < product_similarity_search.sql")
        print("2. Try semantic search: python3 semantic_search.py")
        
    except KeyboardInterrupt:
        print("\n\n⚠️  Interrupted by user")
        
    except Exception as e:
        print(f"\n❌ Fatal error: {e}")
        import traceback
        traceback.print_exc()
        
    finally:
        if connection:
            connection.close()
            print("\n🔒 Database connection closed")

if __name__ == "__main__":
    main()