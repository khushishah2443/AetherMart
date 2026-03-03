import csv
import random
from faker import Faker
from datetime import datetime, timedelta

# Initialize Faker
fake = Faker()

# --- Configuration ---
NUM_CUSTOMERS = 100
NUM_PRODUCTS = 50
NUM_CATEGORIES = 10
NUM_SUPPLIERS = 25
NUM_ORDERS = 200
NUM_REVIEWS = 75

# --- Data Generation Functions ---

def create_customers_csv(filename="customers.csv"):
    """Generates the customers CSV file with some missing emails."""
    with open(filename, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['customer_id', 'first_name', 'last_name', 'email', 'registration_date', 'city', 'state', 'zipcode'])
        for i in range(1, NUM_CUSTOMERS + 1):
            # Introduce some missing emails
            email = fake.email() if random.random() > 0.1 else ''
            writer.writerow([
                i,
                fake.first_name(),
                fake.last_name(),
                email,
                fake.date_between(start_date='-2y', end_date='today'),
                fake.city(),
                fake.state_abbr(),
                fake.zipcode()
            ])
    print(f"{filename} created successfully.")

def create_categories_csv(filename="categories.csv"):
    """Generates the categories CSV file."""
    with open(filename, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['category_id', 'category_name'])
        categories = ['Electronics', 'Apparel', 'Home Goods', 'Furniture', 'Sports', 'Books', 'Toys', 'Groceries', 'Health', 'Automotive']
        for i, name in enumerate(categories, 1):
            writer.writerow([i, name])
    print(f"{filename} created successfully.")

def create_suppliers_csv(filename="suppliers.csv"):
    """Generates the suppliers CSV file with duplicate entries."""
    with open(filename, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['supplier_id', 'supplier_name', 'contact_email'])
        suppliers = []
        for i in range(1, NUM_SUPPLIERS + 1):
            supplier_name = fake.company()
            supplier = [i, supplier_name, f"contact@{supplier_name.lower().replace(' ', '')}.com"]
            suppliers.append(supplier)
            writer.writerow(supplier)

        # Introduce duplicates
        for _ in range(3):
            writer.writerow(random.choice(suppliers))
    print(f"{filename} created successfully.")


def create_products_csv(filename="products.csv"):
    """Generates the products CSV file."""
    with open(filename, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['product_id', 'product_name', 'category_id', 'price', 'supplier_id'])
        for i in range(1, NUM_PRODUCTS + 1):
            writer.writerow([
                100 + i,
                f"Product {fake.word().capitalize()}",
                random.randint(1, NUM_CATEGORIES),
                round(random.uniform(10.0, 2000.0), 2),
                random.randint(1, NUM_SUPPLIERS)
            ])
    print(f"{filename} created successfully.")

def create_orders_csv(filename="orders.csv"):
    """Generates the orders CSV file with varied date formats."""
    with open(filename, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['order_id', 'customer_id', 'order_date', 'total_amount'])
        date_formats = ['%Y-%m-%d', '%m-%d-%Y', '%m/%d/%Y', '%B %d, %Y']
        for i in range(1, NUM_ORDERS + 1):
            order_date = fake.date_between(start_date='-1y', end_date='today')
            # Introduce different date formats
            date_format = random.choice(date_formats)
            writer.writerow([
                1000 + i,
                random.randint(1, NUM_CUSTOMERS),
                order_date.strftime(date_format),
                round(random.uniform(20.0, 5000.0), 2)
            ])
    print(f"{filename} created successfully.")


def create_order_items_csv(filename="order_items.csv"):
    """Generates the order_items CSV file."""
    with open(filename, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['order_item_id', 'order_id', 'product_id', 'quantity', 'price_per_unit'])
        for i in range(1, NUM_ORDERS + 50): # More items than orders
            product_id = 100 + random.randint(1, NUM_PRODUCTS)
            price = round(random.uniform(10.0, 2000.0), 2)
            quantity = random.randint(1, 5)
            writer.writerow([
                2000 + i,
                1000 + random.randint(1, NUM_ORDERS),
                product_id,
                quantity,
                price
            ])
    print(f"{filename} created successfully.")

def create_reviews_csv(filename="reviews.csv"):
    """Generates the reviews CSV file with missing and invalid ratings."""
    with open(filename, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['review_id', 'product_id', 'customer_id', 'rating', 'review_text', 'review_date'])
        for i in range(1, NUM_REVIEWS + 1):
            rating = random.choice([1, 2, 3, 4, 5, 'NULL', '', 'invalid'])
            writer.writerow([
                3000 + i,
                100 + random.randint(1, NUM_PRODUCTS),
                random.randint(1, NUM_CUSTOMERS),
                rating,
                fake.sentence(),
                fake.date_between(start_date='-1y', end_date='today')
            ])
    print(f"{filename} created successfully.")


if __name__ == '__main__':
    create_customers_csv()
    create_categories_csv()
    create_suppliers_csv()
    create_products_csv()
    create_orders_csv()
    create_order_items_csv()
    create_reviews_csv()
    print("\nAll CSV files have been generated.")