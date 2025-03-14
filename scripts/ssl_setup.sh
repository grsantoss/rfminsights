#!/bin/bash
# ssl_setup.sh - Script para configuração de certificados SSL para o RFM Insights
# Este script pode ser executado em ambientes de desenvolvimento ou produção

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

# Função para verificar se um certificado é válido
verify_certificate() {
    local cert_file=$1
    local key_file=$2
    
    if [ ! -f "$cert_file" ] || [ ! -f "$key_file" ]; then
        log "ERROR" "Certificado ou chave não encontrados: $cert_file, $key_file"
        return 1
    fi
    
    # Verificar validade do certificado
    openssl x509 -in "$cert_file" -noout -dates 2>/dev/null
    check_status "Verificação da validade do certificado $cert_file"
    
    # Verificar se a chave privada corresponde ao certificado
    cert_modulus=$(openssl x509 -in "$cert_file" -noout -modulus 2>/dev/null | openssl md5)
    key_modulus=$(openssl rsa -in "$key_file" -noout -modulus 2>/dev/null | openssl md5)
    
    if [ "$cert_modulus" = "$key_modulus" ]; then
        log "INFO" "✅ Certificado e chave privada correspondem"
        return 0
    else
        log "ERROR" "❌ Certificado e chave privada NÃO correspondem"
        return 1
    fi
}

# Definir diretório de instalação
if [ -z "$INSTALL_DIR" ]; then
    INSTALL_DIR="$HOME/rfminsights"
    log "INFO" "Usando diretório de instalação padrão: $INSTALL_DIR"
fi

# Garantir que o diretório SSL existe
SSL_DIR="$INSTALL_DIR/nginx/ssl"
ensure_directory "$SSL_DIR"

# Função para gerar certificados autoassinados
generate_self_signed_certs() {
    log "INFO" "Gerando certificados SSL autoassinados..."
    
    # Gerar certificado para o frontend
    log "INFO" "Gerando certificado para o frontend..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SSL_DIR/frontend.key" \
        -out "$SSL_DIR/frontend.crt" \
        -subj "/C=BR/ST=Estado/L=Cidade/O=RFMInsights/CN=app.rfminsights.com.br" 2>/dev/null
    check_status "Geração do certificado frontend"
    
    # Gerar certificado para a API
    log "INFO" "Gerando certificado para a API..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SSL_DIR/api.key" \
        -out "$SSL_DIR/api.crt" \
        -subj "/C=BR/ST=Estado/L=Cidade/O=RFMInsights/CN=api.rfminsights.com.br" 2>/dev/null
    check_status "Geração do certificado API"
    
    # Ajustar permissões
    chmod 644 "$SSL_DIR"/*.crt
    chmod 600 "$SSL_DIR"/*.key
    check_status "Ajuste de permissões dos certificados"
    
    # Verificar certificados
    verify_certificate "$SSL_DIR/frontend.crt" "$SSL_DIR/frontend.key"
    verify_certificate "$SSL_DIR/api.crt" "$SSL_DIR/api.key"
}

# Função para configurar certificados Let's Encrypt
setup_letsencrypt_certs() {
    log "INFO" "Configurando certificados Let's Encrypt..."
    
    # Verificar se o Certbot está instalado
    if ! command -v certbot &> /dev/null; then
        log "INFO" "Instalando Certbot..."
        sudo apt update
        sudo apt install -y certbot python3-certbot-nginx
        check_status "Instalação do Certbot"
    fi
    
    # Obter certificados para os domínios
    log "INFO" "Obtendo certificados para os domínios..."
    sudo certbot --nginx -d app.rfminsights.com.br -d api.rfminsights.com.br
    check_status "Obtenção de certificados Let's Encrypt"
    
    # Copiar certificados para a pasta do Nginx
    log "INFO" "Copiando certificados para a pasta do Nginx..."
    sudo cp /etc/letsencrypt/live/app.rfminsights.com.br/fullchain.pem "$SSL_DIR/frontend.crt"
    sudo cp /etc/letsencrypt/live/app.rfminsights.com.br/privkey.pem "$SSL_DIR/frontend.key"
    sudo cp /etc/letsencrypt/live/api.rfminsights.com.br/fullchain.pem "$SSL_DIR/api.crt"
    sudo cp /etc/letsencrypt/live/api.rfminsights.com.br/privkey.pem "$SSL_DIR/api.key"
    check_status "Cópia dos certificados"
    
    # Ajustar permissões
    sudo chmod 644 "$SSL_DIR"/*.crt
    sudo chmod 600 "$SSL_DIR"/*.key
    check_status "Ajuste de permissões dos certificados"
    
    # Verificar certificados
    verify_certificate "$SSL_DIR/frontend.crt" "$SSL_DIR/frontend.key"
    verify_certificate "$SSL_DIR/api.crt" "$SSL_DIR/api.key"
    
    # Configurar renovação automática
    log "INFO" "Configurando renovação automática de certificados..."
    sudo bash -c "cat > /etc/cron.d/certbot-renew << EOF
0 0,12 * * * root certbot renew --quiet --post-hook 'cp /etc/letsencrypt/live/app.rfminsights.com.br/fullchain.pem $SSL_DIR/frontend.crt && cp /etc/letsencrypt/live/app.rfminsights.com.br/privkey.pem $SSL_DIR/frontend.key && cp /etc/letsencrypt/live/api.rfminsights.com.br/fullchain.pem $SSL_DIR/api.crt && cp /etc/letsencrypt/live/api.rfminsights.com.br/privkey.pem $SSL_DIR/api.key && chmod 644 $SSL_DIR/*.crt && chmod 600 $SSL_DIR/*.key && docker-compose restart nginx-proxy'
EOF"
    check_status "Configuração da renovação automática"
}

# Menu principal
echo "=================================================="
echo "      Configuração de Certificados SSL          "
echo "=================================================="
echo "1. Gerar certificados autoassinados (desenvolvimento)"
echo "2. Configurar certificados Let's Encrypt (produção)"
echo "3. Verificar certificados existentes"
echo "4. Sair"
echo "=================================================="

read -p "Escolha uma opção (1-4): " option

case $option in
    1)
        generate_self_signed_certs
        ;;
    2)
        setup_letsencrypt_certs
        ;;
    3)
        if [ -f "$SSL_DIR/frontend.crt" ] && [ -f "$SSL_DIR/frontend.key" ] && \
           [ -f "$SSL_DIR/api.crt" ] && [ -f "$SSL_DIR/api.key" ]; then
            log "INFO" "Verificando certificados existentes..."
            verify_certificate "$SSL_DIR/frontend.crt" "$SSL_DIR/frontend.key"
            verify_certificate "$SSL_DIR/api.crt" "$SSL_DIR/api.key"
            
            # Mostrar informações dos certificados
            echo "\nInformações do certificado frontend:"
            openssl x509 -in "$SSL_DIR/frontend.crt" -noout -text | grep -E 'Subject:|Issuer:|Not Before:|Not After :'
            
            echo "\nInformações do certificado API:"
            openssl x509 -in "$SSL_DIR/api.crt" -noout -text | grep -E 'Subject:|Issuer:|Not Before:|Not After :'
        else
            log "ERROR" "Certificados não encontrados em $SSL_DIR"
        fi
        ;;
    4)
        log "INFO" "Saindo..."
        exit 0
        ;;
    *)
        log "ERROR" "Opção inválida"
        exit 1
        ;;
esac

log "INFO" "Configuração de certificados SSL concluída com sucesso!"
exit 0