# RFM Insights - Database Models

from sqlalchemy import Boolean, Column, ForeignKey, Integer, String, Float, DateTime, Text, JSON
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import uuid
from datetime import datetime

from .database import Base

# Function to generate UUID
def generate_uuid():
    return str(uuid.uuid4())

# User model
class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=generate_uuid)
    email = Column(String, unique=True, index=True)
    password = Column(String)
    full_name = Column(String)
    company_name = Column(String)
    is_active = Column(Boolean, default=True)
    is_admin = Column(Boolean, default=False)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
    
    # Relationships
    messages = relationship("Message", back_populates="user")
    rfm_analyses = relationship("RFMAnalysis", back_populates="user")
    api_keys = relationship("APIKey", back_populates="user")

# Message model
class Message(Base):
    __tablename__ = "messages"

    id = Column(String, primary_key=True, default=generate_uuid)
    user_id = Column(String, ForeignKey("users.id"))
    message_type = Column(String)  # sms, whatsapp, email
    company_name = Column(String)
    company_website = Column(String, nullable=True)
    company_description = Column(Text, nullable=True)
    segment = Column(String)
    objective = Column(String)
    seasonality = Column(String, nullable=True)
    tone = Column(String)
    message = Column(Text)
    regeneration_attempts = Column(Integer, default=0)
    parent_id = Column(String, ForeignKey("messages.id"), nullable=True)
    sequence_number = Column(Integer, default=1)
    sequence_total = Column(Integer, default=1)
    created_at = Column(DateTime, default=func.now())
    
    # Relationships
    user = relationship("User", back_populates="messages")
    pdf = relationship("MessagePDF", back_populates="message", uselist=False)
    parent = relationship("Message", remote_side=[id], backref="regenerations")

# Message PDF model
class MessagePDF(Base):
    __tablename__ = "message_pdfs"

    id = Column(String, primary_key=True, default=generate_uuid)
    message_id = Column(String, ForeignKey("messages.id"))
    file_path = Column(String)
    created_at = Column(DateTime, default=func.now())
    
    # Relationships
    message = relationship("Message", back_populates="pdf")

# RFM Analysis model
class RFMAnalysis(Base):
    __tablename__ = "rfm_analyses"

    id = Column(String, primary_key=True, default=generate_uuid)
    user_id = Column(String, ForeignKey("users.id"))
    name = Column(String)
    description = Column(Text, nullable=True)
    segment_type = Column(String)  # ecommerce, subscription, etc.
    file_name = Column(String)
    record_count = Column(Integer)
    column_mapping = Column(JSON)  # Stores column mapping as JSON
    segment_counts = Column(JSON)  # Stores segment counts as JSON
    created_at = Column(DateTime, default=func.now())
    
    # Relationships
    user = relationship("User", back_populates="rfm_analyses")
    insights = relationship("AIInsight", back_populates="rfm_analysis")

# AI Insight model
class AIInsight(Base):
    __tablename__ = "ai_insights"

    id = Column(String, primary_key=True, default=generate_uuid)
    rfm_analysis_id = Column(String, ForeignKey("rfm_analyses.id"))
    segment = Column(String, nullable=True)  # If segment-specific
    business_type = Column(String, nullable=True)  # If business-specific
    insight_type = Column(String)  # general, segment_specific, business_specific
    content = Column(Text)
    created_at = Column(DateTime, default=func.now())
    
    # Relationships
    rfm_analysis = relationship("RFMAnalysis", back_populates="insights")

# API Key model
class APIKey(Base):
    __tablename__ = "api_keys"

    id = Column(String, primary_key=True, default=generate_uuid)
    user_id = Column(String, ForeignKey("users.id"))
    key = Column(String, unique=True, index=True)
    name = Column(String)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=func.now())
    last_used_at = Column(DateTime, nullable=True)
    
    # Relationships
    user = relationship("User", back_populates="api_keys")