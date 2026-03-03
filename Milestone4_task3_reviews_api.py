#!/usr/bin/env python3
"""
AetherMart Review Embedding Generator
Generates embeddings for all reviews and loads them into MariaDB.
"""

import pymysql
import google.generativeai as genai
import time
import sys
import os

# =====================================================================
# CONFIGURATION - EDIT THESE VALUES
# =====================================================================
DB_USER = "alex"
DB_PASS = "alex_pass"
DB_HOST = "localhost"
DB_NAME = "aethermart_db"

# --- IMPORTANT ---
API_KEY = os.environ.get('GEMINI_API_KEY')
if not API_KEY:
    API_KEY = "AIzaSyCxZvgc-V6iUN66NYlGx7nNfnEPKsduodM" # <-- PASTE YOUR KEY

MODEL_NAME = "models/embedding-001"
EMBEDDING_DIMENSION = 768  # Gemini embedding-001

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

def connect_db():
    """Establish database connection"""
    try:
        connection = pymysql.connect(**DB_CONFIG)
        print("✅ Connected to MariaDB successfully!")
        return connection
    except Exception as e:
        print(f"❌ Error connecting to database: {e}")
        raise

def prepare_reviews_table(connection):
    """Adds vector column and index to Reviews table"""
    try:
        with connection.cursor() as cursor:
            # 1. Add the new column if it doesn't exist
            cursor.execute("""
                SELECT COUNT(*) as count 
                FROM INFORMATION_SCHEMA.COLUMNS 
                WHERE TABLE_SCHEMA = %s
                AND TABLE_NAME = 'Reviews' 
                AND COLUMN_NAME = 'review_embedding'
            """, (DB_NAME,))
            result = cursor.fetchone()
            
            if result['count'] == 0:
                print(f"Adding review_embedding VECTOR({EMBEDDING_DIMENSION}) column...")
                # We learned our lesson: Add NOT NULL from the start!
                cursor.execute(f"""
                    ALTER TABLE Reviews 
                    ADD COLUMN review_embedding VECTOR({EMBEDDING_DIMENSION}) NOT NULL
                """)
                connection.commit()
                print(f"✅ Added review_embedding column")
            else:
                print("ℹ️  review_embedding column already exists")
                cursor.execute("UPDATE Reviews SET review_embedding = NULL")
                connection.commit()
                print("✅ Cleared existing embeddings for a fresh start.")

            # 2. Create the vector index if it doesn't exist
            cursor.execute("""
                SELECT COUNT(*) as count
                FROM INFORMATION_SCHEMA.STATISTICS
                WHERE TABLE_SCHEMA = %s
                AND TABLE_NAME = 'Reviews'
                AND INDEX_NAME = 'idx_review_embedding'
            """, (DB_NAME,))
            result = cursor.fetchone()

            if result['count'] == 0:
                print("Creating vector index 'idx_review_embedding'...")
                # This will work because the column is NOT NULL
                cursor.execute("""
                    CREATE VECTOR INDEX idx_review_embedding
                    ON Reviews (review_embedding)
                """)
                connection.commit()
                print("✅ Vector index created successfully.")
            else:
                print("ℹ️  Vector index 'idx_review_embedding' already exists.")

    except Exception as e:
        print(f"❌ Error preparing Reviews table: {e}")
        raise

def fetch_reviews(connection):
    """Fetch all reviews with text"""
    try:
        with connection.cursor() as cursor:
            # We'll vectorize ALL reviews, even ones with just text,
            # but we'll focus on those with text.
            cursor.execute("""
                SELECT review_id, rating, review_text
                FROM Reviews
                WHERE review_text IS NOT NULL AND review_text != ''
                AND review_embedding IS NULL
            """)
            reviews = cursor.fetchall()
            print(f"✅ Fetched {len(reviews)} reviews to be vectorized.")
            return reviews
    except Exception as e:
        print(f"❌ Error fetching reviews: {e}")
        raise

def generate_embeddings_gemini(reviews):
    """Generate embeddings using Google Gemini API"""
    print(f"\n🔄 Initializing Google Gemini API...")
    
    genai.configure(api_key=API_KEY)
    
    print(f"🔄 Generating embeddings using {MODEL_NAME}...")
    embeddings_data = []
    failed_reviews = []
    
    for i, review in enumerate(reviews, 1):
        # --- FEATURE ENGINEERING ---
        # We combine rating and text for better semantic context.
        text_to_embed = (
            f"Review Text: {review['review_text']} "
            f"Rating: {review['rating']}/5"
        )
        
        try:
            # Generate embedding using Gemini
            result = genai.embed_content(
                model=MODEL_NAME,
                content=text_to_embed,
                task_type="retrieval_document" # Store this vector
            )
            
            embedding = result['embedding']
            
            embeddings_data.append({
                'review_id': review['review_id'],
                'embedding': embedding
            })
            
            if i % 10 == 0 or i == len(reviews):
                print(f"   Progress: {i}/{len(reviews)} reviews embedded")
            
            # Rate limiting: 60 requests/minute
            time.sleep(1.1)
                
        except Exception as e:
            print(f"⚠️  Error embedding review {review['review_id']}: {e}")
            failed_reviews.append(review['review_id'])
            time.sleep(2)
    
    print(f"\n✅ Generated embeddings for {len(embeddings_data)} reviews")
    if failed_reviews:
        print(f"⚠️  Failed reviews: {failed_reviews}")
    
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
                review_id = data['review_id']
                embedding_vector = vector_to_string(data['embedding'])
                
                try:
                    # Update review with embedding
                    sql = """
                        UPDATE Reviews 
                        SET review_embedding = VEC_FromText(%s)
                        WHERE review_id = %s
                    """
                    cursor.execute(sql, (embedding_vector, review_id))
                    update_count += 1
                    
                    if update_count % 10 == 0 or update_count == len(embeddings_data):
                        connection.commit()
                        print(f"   Progress: {update_count}/{len(embeddings_data)} reviews updated")
                        
                except Exception as e:
                    print(f"⚠️  Error updating review {review_id}: {e}")
                    errors.append(review_id)
            
            # Final commit
            connection.commit()
            print(f"\n✅ Successfully loaded embeddings for {update_count} reviews!")
            
    except Exception as e:
        connection.rollback()
        print(f"❌ Error loading embeddings: {e}")
        raise

def main():
    """Main execution function"""
    print("=" * 70)
    print("       AetherMart REVIEW Embedding Generator")
    print("=" * 70)
    
    connection = None
    
    try:
        connection = connect_db()
        prepare_reviews_table(connection)
        reviews = fetch_reviews(connection)
        
        if not reviews:
            print("⚠️  No reviews found to vectorize (or they are all done).")
            return
        
        response = input(f"\nFound {len(reviews)} reviews. Proceed? (y/n): ")
        if response.lower() != 'y':
            print("❌ Cancelled by user")
            return
        
        embeddings_data = generate_embeddings_gemini(reviews)
        
        if not embeddings_data:
            print("❌ No embeddings generated. Check API key and network.")
            return
        
        load_embeddings_to_db(connection, embeddings_data)
        
        print("\n" + "=" * 70)
        print("✅ REVIEW EMBEDDING GENERATION COMPLETE!")
        print("=" * 70)
        
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
