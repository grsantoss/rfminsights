# RFM Insights - Database Module

from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# Use relative import for better consistency
from ..config import config

# Create database engine
engine = create_engine(
    config.DATABASE_URL,
    pool_pre_ping=True,  # Check connection before using it
    pool_recycle=3600,   # Recycle connections after 1 hour
    echo=False           # Set to True for SQL query logging
)

# Create session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Create base class for models
Base = declarative_base()

# Dependency to get DB session
def get_db():
    """Dependency for FastAPI to inject database sessions"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()