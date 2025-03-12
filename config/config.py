# RFM Insights Configuration File

import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Database Configuration
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://user:password@localhost/rfminsights")

# JWT Configuration
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "your-secret-key-should-be-very-long-and-secure")
JWT_ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# Amazon SES Configuration for Email
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID", "")
AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY", "")
EMAIL_SENDER = os.getenv("EMAIL_SENDER", "noreply@rfminsights.com")

# OpenAI Configuration
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")

# Message Generation Configuration
MESSAGE_LIMITS = {
    "sms": 160,
    "whatsapp": 500,
    "email": 800
}

MAX_REGENERATION_ATTEMPTS = 3
MAX_MESSAGES_PER_GENERATION = 5
MESSAGE_HISTORY_DAYS = 7

# Message Generation Prompts
PROMPT_TEMPLATES = {
    "sms": "Gere uma mensagem SMS promocional em português do Brasil, limitada a {limit} caracteres, para {segment} com objetivo de {objective}. Tom: {tone}. Empresa: {company}.",
    "whatsapp": "Crie uma mensagem WhatsApp promocional em português do Brasil, limitada a {limit} caracteres, incluindo emojis adequados, para {segment} com objetivo de {objective}. Tom: {tone}. Empresa: {company}.",
    "email": "Elabore um email promocional em português do Brasil, limitado a {limit} caracteres, com estrutura clara (saudação, corpo e chamada para ação), para {segment} com objetivo de {objective}. Tom: {tone}. Empresa: {company}."
}

# AI Insights Configuration
AI_INSIGHTS_MAX_LENGTH = 1500
AI_INSIGHTS_TEMPERATURE = 0.7

# AI Insights Prompts
AI_INSIGHTS_PROMPTS = {
    "general": "Analise os dados da matriz RFM apresentada e gere insights estratégicos de marketing em português do Brasil. Forneça recomendações específicas e acionáveis para melhorar o engajamento e aumentar o valor do cliente. Foque em estratégias personalizadas para cada segmento RFM identificado.",
    "segment_specific": "Com base na análise RFM, gere insights estratégicos em português do Brasil para o segmento '{segment}'. Forneça 3-5 recomendações específicas e acionáveis que possam ser implementadas para melhorar o engajamento, retenção e valor deste segmento de clientes.",
    "business_specific": "Considerando o tipo de negócio '{business_type}' e os dados da análise RFM, gere insights estratégicos de marketing em português do Brasil. Forneça recomendações específicas para este setor, focando em como melhorar a retenção de clientes, aumentar o valor médio de compra e reativar clientes dormentes."
}

# Password Reset Configuration
PASSWORD_RESET_TOKEN_EXPIRE_HOURS = 24
FRONTEND_URL = os.getenv("FRONTEND_URL", "http://localhost:3000")