import subprocess
import os
import time
import pymongo
import urllib.parse # Make sure this is imported

# --- Configuration ---
# MariaDB
MARIA_DB_USER = "root"  # MariaDB root user for administrative tasks
MARIA_DB_PASS = "alex_pass"  # Your MariaDB root password
MARIA_DB_NAME = "aethermart_db" # The database name

# MongoDB
MONGO_HOST = "172.31.30.142"
MONGO_PORT = 27017
MONGO_DB_NAME = "aethermart_profiles"
MONGO_ADMIN_USER = "admin"  # MongoDB user with privileges to drop databases
MONGO_ADMIN_PASS = "admin_password" # Password for the MongoDB admin user (IMPORTANT: Update this!)
MONGO_AUTH_DB = "admin" # Database for authenticating the MongoDB admin user

# --- Script Paths ---
MILESTONE1_SQL_FILE = "mile1.sql" # Your initial schema creation script
MILESTONE2_SQL_FILE = "mile2.sql" # Additional schema changes
MILESTONE4_SQL_FILE = "mile4.sql" # Further schema changes or features
SECURITY_SQL_FILE = "security.sql"     # MariaDB user/permissions script
SYNC_SQL_FILE = "sync2.sql"             # MariaDB queue tables, SPs, Triggers
GENERATOR_PY_FILE = "generator.py"     # Data generation script for MariaDB
MIGRATE_PY_FILE = "migrate.py"        # Initial migration script to MongoDB

# --- Helper Functions ---

def run_maria_sql_script(sql_file_path, db_name, user, password, create_db_if_not_exists=False):
    """Executes an SQL script against MariaDB."""
    print(f"Applying {sql_file_path} to MariaDB database '{db_name}'...")
    try:
        if create_db_if_not_exists:
            # Connect to MariaDB without specifying a DB, then create/use it
            # This ensures a clean slate for the MariaDB database
            create_db_command = [
                "mariadb",
                f"-u{user}",
                f"-p{password}",
                "-e", f"DROP DATABASE IF EXISTS {db_name}; CREATE DATABASE {db_name}; USE {db_name};"
            ]
            subprocess.run(create_db_command, check=True, capture_output=True, text=True)
            print(f"✅ Cleaned and created MariaDB database '{db_name}'.")

        command = [
            "mariadb",
            f"-u{user}",
            f"-p{password}",
            db_name,
            f"-eSOURCE {sql_file_path}"
        ]
        result = subprocess.run(command, check=True, capture_output=True, text=True)
        print(f"✅ Successfully applied {sql_file_path}.")
        if result.stdout:
            # print("--- SQL Script Output ---")
            # print(result.stdout)
            # print("-------------------------")
            pass # Suppress verbose output by default
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Error applying {sql_file_path}:")
        print(f"  Command: {' '.join(e.cmd)}")
        print(f"  Return Code: {e.returncode}")
        print(f"  STDOUT: {e.stdout}")
        print(f"  STDERR: {e.stderr}")
        return False
    except FileNotFoundError:
        print(f"❌ Error: mariadb client not found. Is MariaDB installed and in PATH?")
        return False
    except Exception as e:
        print(f"❌ An unexpected error occurred while applying {sql_file_path}: {e}")
        return False

def run_python_script(script_path):
    """Executes a Python script."""
    print(f"Running Python script: {script_path}...")
    try:
        result = subprocess.run(
            ["python3", script_path],
            check=True,
            capture_output=True,
            text=True
        )
        print(f"✅ Successfully ran {script_path}.")
        if result.stdout:
            print("--- Python Script Output ---")
            print(result.stdout)
            print("----------------------------")
        if result.stderr:
            print("--- Python Script ERRORS (if any) ---")
            print(result.stderr)
            print("-------------------------------------")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Error running {script_path}:")
        print(f"  Command: {' '.join(e.cmd)}")
        print(f"  Return Code: {e.returncode}")
        print(f"  STDOUT: {e.stdout}")
        print(f"  STDERR: {e.stderr}")
        return False
    except FileNotFoundError:
        print(f"❌ Error: python3 not found. Is Python installed and in PATH?")
        return False
    except Exception as e:
        print(f"❌ An unexpected error occurred while running {script_path}: {e}")
        return False

def drop_mongodb_database(host, port, db_name, user, password, auth_db):
    """Drops a MongoDB database."""
    print(f"Dropping MongoDB database '{db_name}' at {host}:{port}...")
    try:
        # Construct URI with authentication
        username_quoted = urllib.parse.quote_plus(user)
        password_quoted = urllib.parse.quote_plus(password)
        mongo_uri = f"mongodb://{username_quoted}:{password_quoted}@{host}:{port}/?authSource={auth_db}"

        client = pymongo.MongoClient(mongo_uri, serverSelectionTimeoutMS=5000)
        client.admin.command('ping') # Test connection
        
        # Check if the database exists before trying to drop it
        if db_name in client.list_database_names():
            client.drop_database(db_name)
            print(f"✅ Successfully dropped MongoDB database '{db_name}'.")
        else:
            print(f"⚠️ MongoDB database '{db_name}' does not exist. Skipping drop.")
        
        client.close()
        return True
    except pymongo.errors.ServerSelectionTimeoutError as e:
        print(f"❌ Error: MongoDB server not reachable at {host}:{port}. Is MongoDB running?")
        print(f"  Details: {e}")
        return False
    except pymongo.errors.OperationFailure as e:
        print(f"❌ Error dropping MongoDB database '{db_name}': Authentication or authorization failed.")
        print(f"  Please ensure MONGO_ADMIN_USER ('{user}') has 'dropDatabase' privilege on the '{db_name}' DB (or 'root' role).")
        print(f"  MongoDB Error: {e.details}")
        return False
    except Exception as e:
        print(f"❌ An unexpected error occurred while dropping MongoDB database '{db_name}': {e}")
        return False

def main():
    print("🚀 Starting AetherMart Full Project Orchestrator...")

    # --- Step 0: MongoDB Admin User Password Check ---
    if MONGO_ADMIN_PASS == "admin_password":
        print("\n" + "="*80)
        print("="*80 + "\n")
        # return # Optionally, uncomment to force user to update password
        # --- Step 3: Generate MariaDB Data (generator.py) ---
    print("\n" + "="*80 + "\nGenerating MariaDB Data (generator.py)...\n" + "="*80)
    if not os.path.exists(GENERATOR_PY_FILE):
        print(f"❌ Error: {GENERATOR_PY_FILE} not found. Aborting.")
        return
    if not run_python_script(GENERATOR_PY_FILE):
        print("❌ Orchestrator aborted due to MariaDB data generation failure.")
        return
    time.sleep(1)

    # --- Step 1: Clean and set up MariaDB Schema (milestone1.sql) ---
    print("\n" + "="*80 + "\nSetting up MariaDB Schema (milestone1.sql)...\n" + "="*80)
    if not os.path.exists(MILESTONE1_SQL_FILE):
        print(f"❌ Error: {MILESTONE1_SQL_FILE} not found. Aborting.")
        return
    if not run_maria_sql_script(MILESTONE1_SQL_FILE, MARIA_DB_NAME, MARIA_DB_USER, MARIA_DB_PASS, create_db_if_not_exists=True):
        print("❌ Orchestrator aborted due to MariaDB schema setup failure (milestone1.sql).")
        return
    time.sleep(1) # Give MariaDB a moment

    # --- Step 1.1: Apply Additional MariaDB Schema (milestone2.sql) ---
    print("\n" + "="*80 + "\nApplying MariaDB Schema updates (milestone2.sql)...\n" + "="*80)
    if not os.path.exists(MILESTONE2_SQL_FILE):
        print(f"⚠️ Warning: {MILESTONE2_SQL_FILE} not found. Skipping additional schema setup.")
    else:
        if not run_maria_sql_script(MILESTONE2_SQL_FILE, MARIA_DB_NAME, MARIA_DB_USER, MARIA_DB_PASS):
            print("❌ Orchestrator aborted due to MariaDB schema update failure (milestone2.sql).")
            return
    time.sleep(1)

    # --- Step 1.2: Apply Further MariaDB Schema (milestone4.sql) ---
    print("\n" + "="*80 + "\nApplying further MariaDB Schema updates (milestone4.sql)...\n" + "="*80)
    if not os.path.exists(MILESTONE4_SQL_FILE):
        print(f"⚠️ Warning: {MILESTONE4_SQL_FILE} not found. Skipping further schema setup.")
    else:
        if not run_maria_sql_script(MILESTONE4_SQL_FILE, MARIA_DB_NAME, MARIA_DB_USER, MARIA_DB_PASS):
            print("❌ Orchestrator aborted due to MariaDB schema update failure (milestone4.sql).")
            return
    time.sleep(1)

    # --- Step 2: Apply MariaDB Security (security.sql) ---
    print("\n" + "="*80 + "\nApplying MariaDB Security (security.sql)...\n" + "="*80)
    if not os.path.exists(SECURITY_SQL_FILE):
        print(f"⚠️ Warning: {SECURITY_SQL_FILE} not found. Skipping MariaDB security setup.")
    else:
        if not run_maria_sql_script(SECURITY_SQL_FILE, MARIA_DB_NAME, MARIA_DB_USER, MARIA_DB_PASS):
            print("❌ Orchestrator aborted due to MariaDB security setup failure.")
            return
    time.sleep(1)

    # --- Step 4: Set up MariaDB Real-time Sync (sync.sql) ---
    print("\n" + "="*80 + "\nSetting up MariaDB Real-time Sync (sync.sql)...\n" + "="*80)
    if not os.path.exists(SYNC_SQL_FILE):
        print(f"❌ Error: {SYNC_SQL_FILE} not found. Aborting.")
        return
    else:
        if not run_maria_sql_script(SYNC_SQL_FILE, MARIA_DB_NAME, MARIA_DB_USER, MARIA_DB_PASS):
            print("❌ Orchestrator aborted due to MariaDB sync setup failure.")
            return
    time.sleep(1)

    # # --- Step 5: Drop MongoDB Database for clean migration ---
    # print("\n" + "="*80 + "\nDropping MongoDB Database for clean migration...\n" + "="*80)
    # if not drop_mongodb_database(MONGO_HOST, MONGO_PORT, MONGO_DB_NAME, MONGO_ADMIN_USER, MONGO_ADMIN_PASS, MONGO_AUTH_DB):
    #     print("❌ Orchestrator aborted due to MongoDB database drop failure.")
    #     return
    # time.sleep(1)

    # --- Step 6: Run Initial MongoDB Migration (migrate2.py) ---
    print("\n" + "="*80 + "\nPerforming Initial MongoDB Migration (migrate2.py)...\n" + "="*80)
    if not os.path.exists(MIGRATE_PY_FILE):
        print(f"❌ Error: {MIGRATE_PY_FILE} not found. Aborting.")
        return
    if not run_python_script(MIGRATE_PY_FILE):
        print("❌ Orchestrator aborted due to initial MongoDB migration failure.")
        return
    time.sleep(1)

    print("\n" + "="*80)
    print("🎉 AetherMart Full Project Orchestration Complete! 🎉")
    print("All databases and initial data are set up.")
    print("Now, you should run 'python3 mongo_sync_worker.py' in a separate terminal")
    print("to start the real-time synchronization process.")
    print("="*80 + "\n")

if __name__ == "__main__":
    main()