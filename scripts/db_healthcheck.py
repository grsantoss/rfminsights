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
            print(f"[RETRY] Attempt {attempt}/{max_retries}: Database not ready yet. Error: {str(e).splitlines()[0]}")
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
    parser = argparse.ArgumentParser(description="Check if PostgreSQL database is ready")
    parser.add_argument("--max-retries", type=int, default=30, help="Maximum number of connection attempts")
    parser.add_argument("--retry-interval", type=int, default=2, help="Seconds to wait between retries")
    args = parser.parse_args()
    
    if check_database_connection(args.max_retries, args.retry_interval):
        sys.exit(0)  # Success
    else:
        # Check if the database host is reachable at all
        try:
            # Extract host from DATABASE_URL
            if '@' in DATABASE_URL:
                host = DATABASE_URL.split('@')[1].split('/')[0]
                if ':' in host:
                    host = host.split(':')[0]
            else:
                host = 'localhost'
                
            # Try a simple socket connection to determine if host is reachable
            import socket
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(2)
            s.connect((host, 5432))
            s.close()
            
            # Host is reachable but database connection failed
            print(f"[WARNING] Host {host} is reachable but database connection failed")
            sys.exit(1)  # Soft failure - host is up but DB connection failed
        except Exception as e:
            # Host is not reachable at all
            print(f"[ERROR] Host is not reachable: {str(e)}")
            sys.exit(2)  # Hard failure - host is down

if __name__ == "__main__":
    main()