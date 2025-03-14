#!/bin/bash
# create_nginx_structure.sh - Script para criar a estrutura de diretórios do Nginx

# Definir cores para saída
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Função para exibir mensagens de log
log() {
    local level=$1
    local message=$2
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    case $level in
        "INFO")
            echo -e "${timestamp} [${GREEN}INFO${NC}] $message"
            ;;
        "WARN")
            echo -e "${timestamp} [${YELLOW}WARN${NC}] $message"
            ;;
        "ERROR")
            echo -e "${timestamp} [${RED}ERROR${NC}] $message"
            ;;
        *)
            echo -e "${timestamp} [INFO] $message"
            ;;
    esac
}

# Função para verificar status de comandos
check_status() {
    if [ $? -eq 0 ]; then
        log "INFO" "✅ $1"
    else
        log "ERROR" "❌ $1"
        exit 1
    fi
}

# Função para verificar se um diretório existe, se não, criá-lo
ensure_directory() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        log "INFO" "Criando diretório: $dir"
        mkdir -p "$dir"
        check_status "Criação do diretório $dir"
    else
        log "INFO" "Diretório já existe: $dir"
    fi
}

# Definir diretório de instalação
if [ -z "$INSTALL_DIR" ]; then
    INSTALL_DIR="$HOME/rfminsights"
    log "INFO" "Usando diretório de instalação padrão: $INSTALL_DIR"
fi

# Criar estrutura de diretórios para o Nginx
log "INFO" "Criando estrutura de diretórios para o Nginx..."

# Diretório principal do Nginx
NGINX_DIR="$INSTALL_DIR/nginx"
ensure_directory "$NGINX_DIR"

# Diretório para arquivos de configuração
CONF_DIR="$NGINX_DIR/conf.d"
ensure_directory "$CONF_DIR"

# Diretório para certificados SSL
SSL_DIR="$NGINX_DIR/ssl"
ensure_directory "$SSL_DIR"

# Diretório para logs
LOGS_DIR="$NGINX_DIR/logs"
ensure_directory "$LOGS_DIR"

log "INFO" "Estrutura de diretórios para o Nginx criada com sucesso!"