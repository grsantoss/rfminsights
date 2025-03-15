#!/bin/bash

# RFM Insights - Script de Configuração SSL para Linux
# Este script configura certificados SSL para o RFM Insights

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

# Definir diretório de instalação
INSTALL_DIR="$HOME/rfminsights"
SSL_DIR="$INSTALL_DIR/nginx/ssl"

# Garantir que o diretório SSL existe
log "Verificando diretório SSL: $SSL_DIR"
mkdir -p "$SSL_DIR"
check_status "Diretório SSL verificado"

# Menu principal
echo ""
echo "===================================================="
echo "          CONFIGURAÇÃO SSL RFM INSIGHTS           "
echo "===================================================="
echo ""
echo "Opções disponíveis:"
echo "1. Gerar certificados autoassinados (desenvolvimento)"
echo "2. Configurar Let's Encrypt (produção)"
echo "3. Verificar certificados existentes"
echo "4. Sair"
echo ""

read -p "Escolha uma opção (1-4): " option

case $option in
    1)
        # Gerar certificados autoassinados
        log "Gerando certificados autoassinados..."
        
        # Verificar se o OpenSSL está instalado
        if ! command -v openssl &> /dev/null; then
            error "OpenSSL não encontrado. Instalando..."
            apt-get update && apt-get install -y openssl
            check_status "OpenSSL instalado"
        fi
        
        # Gerar certificado para o frontend
        log "Gerando certificado para o frontend (app.rfminsights.com.br)..."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$SSL_DIR/server.key" \
            -out "$SSL_DIR/server.crt" \
            -subj "/C=BR/ST=Sao Paulo/L=Sao Paulo/O=RFM Insights/OU=IT/CN=app.rfminsights.com.br"
        check_status "Certificado para o frontend gerado"
        
        # Ajustar permissões
        chmod 644 "$SSL_DIR/server.crt"
        chmod 600 "$SSL_DIR/server.key"
        check_status "Permissões ajustadas"
        
        success "Certificados autoassinados gerados com sucesso!"
        ;;
        
    2)
        # Configurar Let's Encrypt
        log "Configurando Let's Encrypt..."
        
        # Verificar se o certbot está instalado
        if ! command -v certbot &> /dev/null; then
            log "Certbot não encontrado. Instalando..."
            apt-get update
            apt-get install -y certbot python3-certbot-nginx
            check_status "Certbot instalado"
        fi
        
        # Solicitar domínios
        read -p "Digite o domínio para o frontend (ex: app.rfminsights.com.br): " frontend_domain
        read -p "Digite o domínio para a API (ex: api.rfminsights.com.br): " api_domain
        
        # Obter certificados
        log "Obtendo certificados para $frontend_domain e $api_domain..."
        certbot certonly --standalone -d "$frontend_domain" -d "$api_domain" --agree-tos --email admin@rfminsights.com.br --non-interactive
        check_status "Certificados obtidos"
        
        # Copiar certificados para o diretório SSL
        log "Copiando certificados para $SSL_DIR..."
        cp "/etc/letsencrypt/live/$frontend_domain/fullchain.pem" "$SSL_DIR/server.crt"
        cp "/etc/letsencrypt/live/$frontend_domain/privkey.pem" "$SSL_DIR/server.key"
        check_status "Certificados copiados"
        
        # Configurar renovação automática
        log "Configurando renovação automática..."
        echo "0 0 * * * certbot renew --quiet && cp /etc/letsencrypt/live/$frontend_domain/fullchain.pem $SSL_DIR/server.crt && cp /etc/letsencrypt/live/$frontend_domain/privkey.pem $SSL_DIR/server.key" | crontab -
        check_status "Renovação automática configurada"
        
        success "Certificados Let's Encrypt configurados com sucesso!"
        ;;
        
    3)
        # Verificar certificados existentes
        log "Verificando certificados existentes..."
        
        if [ -f "$SSL_DIR/server.crt" ] && [ -f "$SSL_DIR/server.key" ]; then
            log "Certificados encontrados:"
            openssl x509 -in "$SSL_DIR/server.crt" -text -noout | grep -E 'Subject:|Issuer:|Not Before:|Not After :'
            success "Certificados verificados com sucesso!"
        else
            error "Certificados não encontrados em $SSL_DIR"
        fi
        ;;
        
    4)
        log "Saindo..."
        exit 0
        ;;
        
    *)
        error "Opção inválida!"
        exit 1
        ;;
esac

echo ""
log "Configuração SSL concluída!"