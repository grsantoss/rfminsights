#!/bin/bash

# RFM Insights - Environment Setup Script
# This script automates the setup of the RFM Insights environment

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

# Detectar sistema operacional
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
        OS="windows"
    else
        OS="unknown"
    fi
    log "Sistema operacional detectado: $OS"
}

# Verificar dependências
check_dependencies() {
    log "Verificando dependências..."
    
    # Verificar Docker
    if command -v docker &> /dev/null; then
        success "Docker encontrado"
    else
        error "Docker não encontrado. Por favor, instale o Docker antes de continuar."
        exit 1
    fi
    
    # Verificar Docker Compose
    if command -v docker-compose &> /dev/null || command -v docker &> /dev/null && docker compose version &> /dev/null; then
        success "Docker Compose encontrado"
    else
        error "Docker Compose não encontrado. Por favor, instale o Docker Compose antes de continuar."
        exit 1
    fi
}

# Configurar diretórios
setup_directories() {
    log "Configurando diretórios..."
    
    # Criar diretórios necessários
    mkdir -p "$PROJECT_ROOT/nginx/ssl"
    mkdir -p "$PROJECT_ROOT/nginx/logs"
    mkdir -p "$PROJECT_ROOT/data"
    mkdir -p "$PROJECT_ROOT/backups"
    
    check_status "Diretórios configurados"
}

# Gerar certificados SSL autoassinados
generate_ssl_certs() {
    log "Gerando certificados SSL autoassinados..."
    
    SSL_DIR="$PROJECT_ROOT/nginx/ssl"
    
    # Verificar se os certificados já existem
    if [ -f "$SSL_DIR/server.crt" ] && [ -f "$SSL_DIR/server.key" ]; then
        warning "Certificados SSL já existem. Pulando geração."
        return 0
    fi
    
    # Verificar se o OpenSSL está instalado
    if ! command -v openssl &> /dev/null; then
        error "OpenSSL não encontrado. Por favor, instale o OpenSSL antes de continuar."
        exit 1
    fi
    
    # Gerar certificado autoassinado
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SSL_DIR/server.key" \
        -out "$SSL_DIR/server.crt" \
        -subj "/C=BR/ST=Sao Paulo/L=Sao Paulo/O=RFM Insights/OU=IT/CN=app.rfminsights.com.br" \
        -addext "subjectAltName=DNS:app.rfminsights.com.br,DNS:api.rfminsights.com.br"
    
    check_status "Certificados SSL gerados"
    
    # Ajustar permissões
    chmod 644 "$SSL_DIR/server.crt"
    chmod 600 "$SSL_DIR/server.key"
    
    check_status "Permissões de certificados ajustadas"
}

# Verificar e configurar arquivo .env
setup_env_file() {
    log "Configurando arquivo .env..."
    
    ENV_FILE="$PROJECT_ROOT/.env"
    ENV_EXAMPLE="$PROJECT_ROOT/.env.example"
    
    # Verificar se o arquivo .env já existe
    if [ ! -f "$ENV_FILE" ]; then
        # Verificar se o arquivo .env.example existe
        if [ -f "$ENV_EXAMPLE" ]; then
            cp "$ENV_EXAMPLE" "$ENV_FILE"
            success "Arquivo .env criado a partir do exemplo"
        else
            error "Arquivo .env.example não encontrado"
            exit 1
        fi
    else
        warning "Arquivo .env já existe. Verificando configurações..."
    fi
    
    # Gerar uma chave JWT segura se não existir ou for a padrão
    JWT_SECRET=$(grep JWT_SECRET_KEY "$ENV_FILE" | cut -d '=' -f2)
    if [ -z "$JWT_SECRET" ] || [ "$JWT_SECRET" == "your-secret-key-should-be-very-long-and-secure" ]; then
        NEW_JWT_SECRET=$(openssl rand -hex 32)
        sed -i.bak "s/JWT_SECRET_KEY=.*/JWT_SECRET_KEY=$NEW_JWT_SECRET/" "$ENV_FILE"
        success "Chave JWT gerada"
    fi
    
    check_status "Arquivo .env configurado"
}

# Verificar configuração do Nginx
setup_nginx_config() {
    log "Verificando configuração do Nginx..."
    
    NGINX_DIR="$PROJECT_ROOT/nginx"
    FRONTEND_CONF="$NGINX_DIR/frontend.conf"
    
    # Verificar se o arquivo frontend.conf existe
    if [ ! -f "$FRONTEND_CONF" ]; then
        error "Arquivo frontend.conf não encontrado. Verifique a instalação."
        exit 1
    fi
    
    success "Configuração do Nginx verificada"
}

# Função principal
main() {
    # Banner
    echo ""
    echo "===================================================="
    echo "          RFM INSIGHTS - CONFIGURAÇÃO DE AMBIENTE  "
    echo "===================================================="
    echo ""
    
    # Obter diretório do projeto
    PROJECT_ROOT=$(pwd)
    log "Diretório do projeto: $PROJECT_ROOT"
    
    # Executar etapas de configuração
    detect_os
    check_dependencies
    setup_directories
    generate_ssl_certs
    setup_env_file
    setup_nginx_config
    
    success "Configuração de ambiente concluída com sucesso!"
    echo ""
    log "Agora você pode iniciar o RFM Insights com: docker-compose up -d"
    echo ""
}

# Executar função principal
main