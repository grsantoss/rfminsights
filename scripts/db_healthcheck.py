#!/usr/bin/env python
# RFM Insights - Database Health Check Script
# This script verifies if PostgreSQL is ready before running migrations

import os
import sys
import time
import argparse
from sqlalchemy import create_engine, text
from sqlalchemy.exc import OperationalError, SQLAlchemyError

# Add the project root to the path so we can import modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Try to import from config, if it fails, use environment variable directly
try:
    from config import config
    DATABASE_URL = config.DATABASE_URL
except ImportError:
    # Fallback to environment variable
    DATABASE_URL = os.getenv('DATABASE_URL')
    if not DATABASE_URL:
        print("[ERROR] DATABASE_URL environment variable not set")
        sys.exit(1)

def check_database_connection(max_retries=30, retry_interval=2):
    """
    Check if the database is ready for connections.
    
    Args:
        max_retries (int): Maximum number of connection attempts
        retry_interval (int): Seconds to wait between retries
        
    Returns:
        bool: True if connection successful, False otherwise
    """
    print(f"[INFO] Checking database connection at {DATABASE_URL.split('@')[1] if '@' in DATABASE_URL else DATABASE_URL}")
    print(f"[INFO] Will retry up to {max_retries} times with {retry_interval} second intervals")
    
    engine = create_engine(DATABASE_URL)
    
    for attempt in range(1, max_retries + 1):
        try:
            # Try to connect and execute a simple query
            with engine.connect() as connection:
                result = connection.execute(text("SELECT 1")).fetchone()
                if result and result[0] == 1:
                    print(f"[SUCCESS] Database connection established on attempt {attempt}")
                    return True
        except OperationalError as e:
            print(f"[RETRY] Attempt {attempt}/{max_retries}: Database not ready yet. Error: {str(e).split('\n')[0]}")
        except SQLAlchemyError as e:
            print(f"[ERROR] Database error: {str(e)}")
            # If it's not a connection error, break the loop
            if "connection" not in str(e).lower():
                break
        
        # Wait before retrying
        if attempt < max_retries:
            print(f"[INFO] Waiting {retry_interval} seconds before next attempt...")
            time.sleep(retry_interval)
    
    print("[FAILED] Could not connect to the database after multiple attempts")
    return False

def main():
    parser = argparse.ArgumentParser(description="RFM Insights Database Health Check")
    parser.add_argument('--max-retries', type=int, default=30, help='Maximum number of connection attempts')
    parser.add_argument('--retry-interval', type=int, default=2, help='Seconds to wait between retries')
    parser.add_argument('--exit-on-failure', action='store_true', help='Exit with error code if connection fails')
    
    args = parser.parse_args()
    
    success = check_database_connection(
        max_retries=args.max_retries,
        retry_interval=args.retry_interval
    )
    
    if not success and args.exit_on_failure:
        sys.exit(1)
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()