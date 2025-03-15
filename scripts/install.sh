#!/bin/bash

# RFM Insights - Script de Instalação Unificado
# Este script corrige problemas conhecidos na instalação do RFM Insights

# Definir cores para saída
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para exibir mensagens
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCESSO]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

# Função para verificar se o comando foi executado com sucesso
check_status() {
    if [ $? -eq 0 ]; then
        success "$1"
    else
        error "$1"
        exit 1
    fi
}

# Verificar se está sendo executado como root
if [ "$(id -u)" != "0" ]; then
    error "Este script deve ser executado como root (sudo)."
    exit 1
fi

# Criar diretório de instalação
INSTALL_DIR="/opt/rfminsights"
log "Criando diretório de instalação em $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit 1

# 1. Atualizar o sistema
log "Atualizando o sistema..."
apt update && apt upgrade -y
check_status "Sistema atualizado"

# 2. Instalar dependências
log "Instalando dependências..."
apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release
check_status "Dependências instaladas"

# 3. Instalar Docker usando o método recomendado (sem apt-key)
log "Instalando Docker..."

# Remover instalações antigas do Docker, se existirem
apt remove -y docker docker-engine docker.io containerd runc || true

# Configurar repositório do Docker usando o método moderno (sem apt-key)
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Atualizar lista de pacotes
apt update

# Instalar Docker
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
check_status "Docker instalado"

# 4. Instalar Docker Compose v2
log "Instalando Docker Compose..."
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-linux-$(uname -m)" -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
check_status "Docker Compose instalado"

# Verificar instalação
log "Verificando instalação do Docker..."
docker --version
docker compose version

# 5. Criar estrutura de diretórios
log "Criando estrutura de diretórios..."
mkdir -p "$INSTALL_DIR/app"
mkdir -p "$INSTALL_DIR/nginx/conf.d"
mkdir -p "$INSTALL_DIR/nginx/ssl"
mkdir -p "$INSTALL_DIR/nginx/logs"
mkdir -p "$INSTALL_DIR/backups"
mkdir -p "$INSTALL_DIR/data"
check_status "Estrutura de diretórios criada"

# 6. Copiar arquivos do projeto
log "Copiando arquivos do projeto..."

# Verificar se estamos no diretório do projeto ou se precisamos clonar do repositório
if [ -f "./docker-compose.yml" ] && [ -f "./Dockerfile.optimized" ]; then
    # Estamos no diretório do projeto, copiar arquivos locais
    cp -r ./* "$INSTALL_DIR/app/"
    # Copiar arquivos ocultos também
    cp -r ./.env* "$INSTALL_DIR/app/" 2>/dev/null || warning "Arquivos .env* não encontrados."
    
    # Se .env.example não existir, criar .env manualmente
    if [ ! -f "$INSTALL_DIR/app/.env" ]; then
        log "Criando arquivo .env manualmente..."
        cat > "$INSTALL_DIR/app/.env" << 'EOL'
# RFM Insights - Environment Variables

# Database Configuration
DATABASE_URL=postgresql://rfminsights:rfminsights_password@postgres/rfminsights

# JWT Configuration
JWT_SECRET_KEY=$(openssl rand -hex 32)
JWT_EXPIRATION_MINUTES=60

# Amazon SES Configuration for Email
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
EMAIL_SENDER=noreply@rfminsights.com.br

# OpenAI Configuration
OPENAI_API_KEY=
OPENAI_MODEL=gpt-4o-mini

# Frontend URL
FRONTEND_URL=https://app.rfminsights.com.br

# Server Configuration
PORT=8000
ENVIRONMENT=production

# Logging Configuration
LOG_LEVEL=info

# Nginx Configuration
NGINX_HOST=app.rfminsights.com.br
API_HOST=api.rfminsights.com.br

# Portainer Configuration
PORTAINER_PORT=9443
PORTAINER_ADMIN_PASSWORD=rfminsights@2024
EOL
        success "Arquivo .env criado manualmente"
    fi
    
    # Se .env.monitoring não existir, criar manualmente
    if [ ! -f "$INSTALL_DIR/app/.env.monitoring" ]; then
        log "Criando arquivo .env.monitoring manualmente..."
        cat > "$INSTALL_DIR/app/.env.monitoring" << 'EOL'
# RFM Insights - Monitoring Environment Variables

# Sentry Configuration
SENTRY_DSN=https://your-sentry-dsn@sentry.io/project-id
SENTRY_TRACES_SAMPLE_RATE=0.2
SENTRY_PROFILES_SAMPLE_RATE=0.1
SENTRY_ENABLE_TRACING=True

# Prometheus Configuration
PROMETHEUS_ENABLE=True
PROMETHEUS_METRICS_PORT=9090

# Grafana Configuration
GRAFANA_URL=http://grafana:3000

# Alert Configuration
ALERT_EMAIL_RECIPIENTS=admin@example.com,alerts@example.com
ALERT_SLACK_WEBHOOK=https://hooks.slack.com/services/your-slack-webhook-url
ALERT_CRITICAL_THRESHOLD=3

# Performance Thresholds
THRESHOLD_API_RESPONSE_TIME=1.0
THRESHOLD_DATABASE_QUERY_TIME=0.5
THRESHOLD_MEMORY_USAGE=85.0
THRESHOLD_CPU_USAGE=80.0
EOL
        success "Arquivo .env.monitoring criado manualmente"
    fi
else
    # Não estamos no diretório do projeto, precisamos clonar do repositório
    warning "Arquivos do projeto não encontrados no diretório atual."
    read -p "Deseja clonar o repositório do RFM Insights? (s/n): " clone_repo
    
    if [ "$clone_repo" = "s" ] || [ "$clone_repo" = "S" ]; then
        apt install -y git
        git clone https://github.com/seu-usu/rfminsights.git temp_repo
        cp -r temp_repo/* "$INSTALL_DIR/app/"
        cp -r temp_repo/.env* "$INSTALL_DIR/app/" 2>/dev/null || warning "Arquivos .env* não encontrados no repositório."
        rm -rf temp_repo
        
        # Criar .env manualmente se não existir
        if [ ! -f "$INSTALL_DIR/app/.env" ]; then
            log "Criando arquivo .env manualmente..."
            cat > "$INSTALL_DIR/app/.env" << 'EOL'
# RFM Insights - Environment Variables

# Database Configuration
DATABASE_URL=postgresql://rfminsights:rfminsights_password@postgres/rfminsights

# JWT Configuration
JWT_SECRET_KEY=$(openssl rand -hex 32)
JWT_EXPIRATION_MINUTES=60

# Amazon SES Configuration for Email
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
EMAIL_SENDER=noreply@rfminsights.com.br

# OpenAI Configuration
OPENAI_API_KEY=
OPENAI_MODEL=gpt-4o-mini

# Frontend URL
FRONTEND_URL=https://app.rfminsights.com.br

# Server Configuration
PORT=8000
ENVIRONMENT=production

# Logging Configuration
LOG_LEVEL=info

# Nginx Configuration
NGINX_HOST=app.rfminsights.com.br
API_HOST=api.rfminsights.com.br

# Portainer Configuration
PORTAINER_PORT=9443
PORTAINER_ADMIN_PASSWORD=rfminsights@2024
EOL
            success "Arquivo .env criado manualmente"
        fi
        
        # Criar .env.monitoring manualmente se não existir
        if [ ! -f "$INSTALL_DIR/app/.env.monitoring" ]; then
            log "Criando arquivo .env.monitoring manualmente..."
            cat > "$INSTALL_DIR/app/.env.monitoring" << 'EOL'
# RFM Insights - Monitoring Environment Variables

# Sentry Configuration
SENTRY_DSN=https://your-sentry-dsn@sentry.io/project-id
SENTRY_TRACES_SAMPLE_RATE=0.2
SENTRY_PROFILES_SAMPLE_RATE=0.1
SENTRY_ENABLE_TRACING=True

# Prometheus Configuration
PROMETHEUS_ENABLE=True
PROMETHEUS_METRICS_PORT=9090

# Grafana Configuration
GRAFANA_URL=http://grafana:3000

# Alert Configuration
ALERT_EMAIL_RECIPIENTS=admin@example.com,alerts@example.com
ALERT_SLACK_WEBHOOK=https://hooks.slack.com/services/your-slack-webhook-url
ALERT_CRITICAL_THRESHOLD=3

# Performance Thresholds
THRESHOLD_API_RESPONSE_TIME=1.0
THRESHOLD_DATABASE_QUERY_TIME=0.5
THRESHOLD_MEMORY_USAGE=85.0
THRESHOLD_CPU_USAGE=80.0
EOL
            success "Arquivo .env.monitoring criado manualmente"
        fi
    else
        error "Instalação cancelada. Arquivos do projeto são necessários."
        exit 1
    fi
fi

check_status "Arquivos do projeto copiados"

# 7. Criar arquivo docker-compose.yml
log "Criando arquivo docker-compose.yml..."
cat > "$INSTALL_DIR/docker-compose.yml" << 'EOL'
version: '3.8'

services:
  # Serviço da API
  api:
    build:
      context: ./app
      dockerfile: Dockerfile.optimized
    container_name: rfminsights-api
    restart: always
    volumes:
      - ./app:/app
      - ./data:/app/data
    env_file:
      - ./app/.env
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - rfminsights-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  # Serviço do Frontend (Nginx para servir arquivos estáticos)
  frontend:
    image: nginx:alpine
    container_name: rfminsights-frontend
    restart: always
    volumes:
      - ./app/frontend:/usr/share/nginx/html
      - ./nginx/frontend.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - api
    networks:
      - rfminsights-network
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:80/health.html"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

  # Serviço do Banco de Dados PostgreSQL
  postgres:
    image: postgres:14-alpine