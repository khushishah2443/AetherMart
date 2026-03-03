#!/usr/bin/env python3
"""
AetherMart Semantic Search Engine (v5 - Refined Evidence)
Uses Google Gemini API to embed a search query and finds
similar PRODUCTS, REVIEWS, or CUSTOMERS in the MariaDB database.

v5 Update: Refines Customer Search evidence per user request.
 - Removes text of reviews.
 - Shows last 5 products purchased.
 - Shows the customer's average rating.
"""

import pymysql
import google.generativeai as genai
import sys
import os

# =====================================================================
# CONFIGURATION - EDIT THESE VALUES
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

def get_search_vector(search_query, task_type):
    """Converts the user's text query into a vector."""
    print(f"🔄 Vectorizing search query: '{search_query}'...")
    try:
        genai.configure(api_key=API_KEY)
        result = genai.embed_content(
            model=MODEL_NAME,
            content=search_query,
            task_type=task_type 
        )
        return result['embedding']
    except Exception as e:
        print(f"❌ Error calling Google API: {e}")
        print("   (Did you set your API key? Is billing enabled?)")
        return None # Return None on failure

def vector_to_string(vector):
    """Converts vector list to MariaDB VECTOR format string"""
    return '[' + ','.join([f"{v:.8f}" for v in vector]) + ']'

def find_similar_products(connection, query_vector_str):
    """Searches the database for similar products."""
    print("🔍 Searching database for similar PRODUCTS...")
    try:
        with connection.cursor() as cursor:
            sql = """
                SELECT 
                    product_id,
                    product_name,
                    product_description,
                    VEC_DISTANCE_COSINE(
                        product_embedding, 
                        VEC_FromText(%s)
                    ) AS distance
                FROM Products
                WHERE product_embedding IS NOT NULL
                ORDER BY distance ASC
                LIMIT 5;
            """
            cursor.execute(sql, (query_vector_str,))
            return cursor.fetchall()
    except Exception as e:
        print(f"❌ Error searching database: {e}")
        return []

def find_similar_reviews(connection, query_vector_str, rating_filters):
    """
    Searches the database for similar reviews using
    HYBRID SEARCH (Vector + SQL Filter).
    """
    print("🔍 Searching database for similar REVIEWS...")
    try:
        with connection.cursor() as cursor:
            
            # Start with the base semantic query
            sql = """
                SELECT 
                    review_id,
                    review_text,
                    rating,
                    VEC_DISTANCE_COSINE(
                        review_embedding, 
                        VEC_FromText(%s)
                    ) AS distance
                FROM Reviews
                WHERE review_embedding IS NOT NULL
            """
            
            # --- NEW HYBRID LOGIC ---
            # Dynamically add the rating filter if one exists
            params = [query_vector_str]
            if rating_filters:
                # Create placeholders for each rating in the list
                filter_str = ', '.join(['%s'] * len(rating_filters))
                sql += f" AND rating IN ({filter_str})"
                params.extend(rating_filters) # Add the ratings to the parameter list
            # --- END NEW LOGIC ---

            sql += " ORDER BY distance ASC LIMIT 5;"
            
            cursor.execute(sql, tuple(params))
            return cursor.fetchall()
            
    except Exception as e:
        print(f"❌ Error searching database: {e}")
        return []

def find_similar_customers(connection, query_vector_str):
    """Searches the database for 'lookalike' customers."""
    print("🔍 Searching database for 'lookalike' CUSTOMERS...")
    try:
        with connection.cursor() as cursor:
            sql = """
                SELECT 
                    c.customer_id,
                    c.first_name,
                    c.last_name,
                    c.city,
                    c.state,
                    (SELECT GROUP_CONCAT(DISTINCT cat.category_name SEPARATOR ', ')
                     FROM Orders o
                     JOIN Order_Items oi ON o.order_id = oi.order_id
                     JOIN Products p ON oi.product_id = p.product_id
                     JOIN Categories cat ON p.category_id = cat.category_id
                     WHERE o.customer_id = c.customer_id) AS purchase_categories,
                    VEC_DISTANCE_COSINE(
                        c.customer_embedding, 
                        VEC_FromText(%s)
                    ) AS distance
                FROM Customers c
                WHERE c.customer_embedding IS NOT NULL
                ORDER BY distance ASC
                LIMIT 5;
            """
            cursor.execute(sql, (query_vector_str,))
            return cursor.fetchall()
    except Exception as e:
        print(f"❌ Error searching database: {e}")
        print("   (Did you run 'create_customer_index.sql' first?)")
        return []

def main():
    """Main execution loop"""
    print("=" * 70)
    print("     **   AetherMart Semantic Search Engine   **     ")
    print("=" * 70)
    
    connection = None
    
    while True:
        print("\n--- Main Menu ---")
        print("[1] Search Products")
        print("[2] Search Reviews")
        print("[3] Search Customers")
        print("[4] Exit")
        choice = input("Enter your choice (1-4): ")

        # --- PRODUCT SEARCH ---
        if choice == '1':
            search_query = input("\n🔍 Enter PRODUCT search (e.g. 'durable work gloves'): ")
            if not search_query: continue
            
            query_vector = get_search_vector(search_query, "retrieval_query")
            if not query_vector: continue
            query_vector_str = vector_to_string(query_vector)
            
            try:
                connection = pymysql.connect(**DB_CONFIG)
                results = find_similar_products(connection, query_vector_str)
                
                print("\n" + "=" * 70)
                print("✨ Here are the most similar products:")
                print("=" * 70)
                
                if not results:
                    print("No similar products found.")
                else:
                    for item in results:
                        similarity = (1 - item['distance']) * 100
                        print(f"\n✅ {item['product_name']} (ID: {item['product_id']})")
                        print(f"   Similarity: {similarity:.2f}%")
                        print(f"   Description: {item['product_description']}")
                        
            except Exception as e:
                print(f"\n❌ Fatal error: {e}")
            finally:
                if connection: connection.close()

        # --- REVIEW SEARCH (HYBRID) ---
        elif choice == '2':
            search_query = input("\n🔍 Enter REVIEW search (e.g. 'good battery life'): ")
            if not search_query: continue
            
            # --- NEW HYBRID LOGIC ---
            query_lower = search_query.lower()
            rating_filters = []
            
            if 'good' in query_lower or 'average' in query_lower or 'decent' in query_lower:
                rating_filters = [3]
                print("   (Hybrid Search: Detected 'good', filtering for 3-star ratings)")
            elif 'great' in query_lower or 'excellent' in query_lower or 'awesome' in query_lower or 'best' in query_lower:
                rating_filters = [4, 5]
                print("   (Hybrid Search: Detected 'great', filtering for 4 & 5-star ratings)")
            elif 'poor' in query_lower or 'bad' in query_lower or 'terrible' in query_lower or 'worst' in query_lower:
                rating_filters = [1, 2]
                print("   (Hybrid Search: Detected 'bad', filtering for 1 & 2-star ratings)")
            # --- END NEW LOGIC ---

            query_vector = get_search_vector(search_query, "retrieval_query")
            if not query_vector: continue
            query_vector_str = vector_to_string(query_vector)
            
            try:
                connection = pymysql.connect(**DB_CONFIG)
                # Pass the new rating_filters to the function
                results = find_similar_reviews(connection, query_vector_str, rating_filters)

                print("\n" + "=" * 70)
                print("✨ Here are the most similar reviews:")
                print("=" * 70)
                
                if not results:
                    print("No similar reviews found.")
                else:
                    for item in results:
                        similarity = (1 - item['distance']) * 100
                        print(f"\n✅ Review (ID: {item['review_id']}) | Rating: {item['rating']}/5")
                        print(f"   Similarity: {similarity:.2f}%")
                        print(f"   Review Text: {item['review_text']}")
            
            except Exception as e:
                print(f"\n❌ Fatal error: {e}")
            finally:
                if connection: connection.close()

        # --- CUSTOMER SEARCH ---
        elif choice == '3':
            print("\nThis search finds customers.")
            print("You can search by: ")
            print("  - A customer ID (e.g. 'customer 15')")
            print("  - A purchase profile (e.g. 'buys electronics and books')")
            search_query = input("\n🔍 Enter CUSTOMER search: ")
            if not search_query: continue
            
            query_vector = get_search_vector(search_query, "retrieval_query")
            if not query_vector: continue
            query_vector_str = vector_to_string(query_vector)

            try:
                connection = pymysql.connect(**DB_CONFIG)
                results = find_similar_customers(connection, query_vector_str)
                
                print("\n" + "=" * 70)
                print("✨ Here are the 'lookalike' customers:")
                print("=" * 70)

                if not results:
                    print("No similar customers found.")
                else:
                    for item in results:
                        similarity = (1 - item['distance']) * 100
                        print(f"\n✅ {item['first_name']} {item['last_name']} (ID: {item['customer_id']})")
                        print(f"   Similarity: {similarity:.2f}%")
                        print(f"   Location:   {item['city']}, {item['state']}")
                        print(f"   Profile:    Buys {item['purchase_categories'] or 'N/A'}")
                        
                        # --- "Evidence" Queries (MODIFIED per user request) ---
                        with connection.cursor() as evidence_cursor:
                            
                            # --- 1. Get LAST 5 Products Bought ---
                            sql_products = """
                                SELECT p.product_name
                                FROM Orders o
                                JOIN Order_Items oi ON o.order_id = oi.order_id
                                JOIN Products p ON oi.product_id = p.product_id
                                WHERE o.customer_id = %s
                                ORDER BY o.order_date DESC
                                LIMIT 5;
                            """
                            evidence_cursor.execute(sql_products, (item['customer_id'],))
                            products_bought = evidence_cursor.fetchall()
                            if products_bought:
                                product_names = [p['product_name'] for p in products_bought]
                                print(f"   Last 5:     {', '.join(product_names)}")

                            # --- 2. Get Average Rating ---
                            sql_avg_rating = """
                                SELECT AVG(rating) as avg_rating
                                FROM Reviews
                                WHERE customer_id = %s
                                AND rating IS NOT NULL AND rating > 0;
                            """
                            evidence_cursor.execute(sql_avg_rating, (item['customer_id'],))
                            rating_result = evidence_cursor.fetchone()
                            if rating_result and rating_result['avg_rating']:
                                print(f"   Avg Rating: {rating_result['avg_rating']:.2f} / 5.00")
                            else:
                                print(f"   Avg Rating: N/A (No reviews written)")

            except Exception as e:
                print(f"\n❌ Fatal error: {e}")
            finally:
                if connection: connection.close()

        # --- EXIT ---
        elif choice == '4':
            print("\nExiting. Good work, buddy! AetherMart.")
            break
        
        else:
            print("\n❌ Invalid choice. Please enter 1, 2, 3, or 4.")
            
    if connection and connection.open:
        connection.close()
        print("\n🔒 Database connection closed.")

if __name__ == "__main__":
    main()

