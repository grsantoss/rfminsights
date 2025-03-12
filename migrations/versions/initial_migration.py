"""Initial migration with indexes and constraints

Revision ID: 001
Revises: 
Create Date: 2023-06-01

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '001'
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create tables with all constraints and indexes
    # Users table
    op.create_table('users',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('email', sa.String(), nullable=False),
        sa.Column('password', sa.String(), nullable=False),
        sa.Column('full_name', sa.String(), nullable=False),
        sa.Column('company_name', sa.String(), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('is_admin', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.text('now()')),
        sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.text('now()')),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('idx_user_email', 'users', ['email'], unique=True)
    op.create_index('idx_user_company_name', 'users', ['company_name'])
    op.create_index('idx_user_created_at', 'users', ['created_at'])
    
    # Messages table
    op.create_table('messages',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('user_id', sa.String(), nullable=False),
        sa.Column('message_type', sa.String(), nullable=False),
        sa.Column('company_name', sa.String(), nullable=False),
        sa.Column('company_website', sa.String(), nullable=True),
        sa.Column('company_description', sa.Text(), nullable=True),
        sa.Column('segment', sa.String(), nullable=False),
        sa.Column('objective', sa.String(), nullable=False),
        sa.Column('seasonality', sa.String(), nullable=True),
        sa.Column('tone', sa.String(), nullable=False),
        sa.Column('message', sa.Text(), nullable=False),
        sa.Column('regeneration_attempts', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('parent_id', sa.String(), nullable=True),
        sa.Column('sequence_number', sa.Integer(), nullable=False, server_default='1'),
        sa.Column('sequence_total', sa.Integer(), nullable=False, server_default='1'),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.text('now()')),
        sa.ForeignKeyConstraint(['parent_id'], ['messages.id'], ),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id'),
        sa.CheckConstraint("message_type IN ('sms', 'whatsapp', 'email')", name="ck_message_type_valid"),
        sa.CheckConstraint("regeneration_attempts >= 0", name="ck_regeneration_attempts_positive")
    )
    op.create_index('idx_message_user_id', 'messages', ['user_id'])
    op.create_index('idx_message_type', 'messages', ['message_type'])
    op.create_index('idx_message_segment', 'messages', ['segment'])
    op.create_index('idx_message_created_at', 'messages', ['created_at'])
    
    # Message PDFs table
    op.create_table('message_pdfs',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('message_id', sa.String(), nullable=False),
        sa.Column('file_path', sa.String(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.text('now()')),
        sa.ForeignKeyConstraint(['message_id'], ['messages.id'], ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('message_id')
    )
    op.create_index('idx_message_pdf_created_at', 'message_pdfs', ['created_at'])
    
    # RFM Analyses table
    op.create_table('rfm_analyses',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('user_id', sa.String(), nullable=False),
        sa.Column('name', sa.String(), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('segment_type', sa.String(), nullable=False),
        sa.Column('file_name', sa.String(), nullable=False),
        sa.Column('record_count', sa.Integer(), nullable=False),
        sa.Column('column_mapping', postgresql.JSON(astext_type=sa.Text()), nullable=False),
        sa.Column('segment_counts', postgresql.JSON(astext_type=sa.Text()), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.text('now()')),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'name', name='uq_user_analysis_name'),
        sa.CheckConstraint("record_count > 0", name="ck_record_count_positive")
    )
    op.create_index('idx_rfm_analysis_user_id', 'rfm_analyses', ['user_id'])
    op.create_index('idx_rfm_analysis_segment_type', 'rfm_analyses', ['segment_type'])
    op.create_index('idx_rfm_analysis_created_at', 'rfm_analyses', ['created_at'])
    
    # AI Insights table
    op.create_table('ai_insights',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('rfm_analysis_id', sa.String(), nullable=False),
        sa.Column('segment', sa.String(), nullable=True),
        sa.Column('business_type', sa.String(), nullable=True),
        sa.Column('insight_type', sa.String(), nullable=False),
        sa.Column('content', sa.Text(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.text('now()')),
        sa.ForeignKeyConstraint(['rfm_analysis_id'], ['rfm_analyses.id'], ),
        sa.PrimaryKeyConstraint('id'),
        sa.CheckConstraint("insight_type IN ('general', 'segment_specific', 'business_specific')", name="ck_insight_type_valid")
    )
    op.create_index('idx_ai_insight_rfm_analysis_id', 'ai_insights', ['rfm_analysis_id'])
    op.create_index('idx_ai_insight_insight_type', 'ai_insights', ['insight_type'])
    op.create_index('idx_ai_insight_created_at', 'ai_insights', ['created_at'])
    
    # API Keys table
    op.create_table('api_keys',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('user_id', sa.String(), nullable=False),
        sa.Column('key', sa.String(), nullable=False),
        sa.Column('name', sa.String(), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.text('now()')),
        sa.Column('last_used_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('key')
    )
    op.create_index('idx_api_key_key', 'api_keys', ['key'])
    op.create_index('idx_api_key_user_id', 'api_keys', ['user_id'])
    op.create_index('idx_api_key_created_at', 'api_keys', ['created_at'])
    op.create_index('idx_api_key_last_used_at', 'api_keys', ['last_used_at'])


def downgrade() -> None:
    # Drop tables in reverse order of creation
    op.drop_table('api_keys')
    op.drop_table('ai_insights')
    op.drop_table('rfm_analyses')
    op.drop_table('message_pdfs')
    op.drop_table('messages')
    op.drop_table('users')