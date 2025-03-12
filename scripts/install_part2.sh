#!/bin/bash

# RFM Insights - Script de Instalação (Parte 2)
# Este script deve ser executado após install.sh

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

# Definir diretório de instalação
INSTALL_DIR="/opt/rfminsights"
cd "$INSTALL_DIR" || exit 1

# Continuar a partir da criação do docker-compose.yml
log "Continuando a criação do arquivo docker-compose.yml..."
cat >> "$INSTALL_DIR/docker-compose.yml" << 'EOL'
      retries: 3
      start_period: 10s

  # Serviço do Banco de Dados PostgreSQL
  postgres:
    image: postgres:14-alpine
    container_name: rfminsights-postgres
    restart: always
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backups:/backups
    environment:
      - POSTGRES_USER=rfminsights
      - POSTGRES_PASSWORD=rfminsights_password
      - POSTGRES_DB=rfminsights
    networks:
      - rfminsights-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U rfminsights"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s

  # Serviço do Nginx para Proxy Reverso
  nginx-proxy:
    image: nginx:alpine
    container_name: rfminsights-nginx-proxy
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./nginx/ssl:/etc/nginx/ssl
      - ./nginx/logs:/var/log/nginx
    depends_on:
      - api
      - frontend
    networks:
      - rfminsights-network
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

  # Serviço do Portainer para gerenciamento de contêineres
  portainer:
    image: portainer/portainer-ce:latest
    container_name: rfminsights-portainer
    restart: always
    ports:
      - "${PORTAINER_PORT:-9443}:9443"
      - "8000:8000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    networks:
      - rfminsights-network

networks:
  rfminsights-network:
    driver: bridge

volumes:
  postgres_data:
    driver: local
  portainer_data:
    driver: local
EOL
check_status "Arquivo docker-compose.yml criado"

# 8. Configurar Nginx
log "Configurando Nginx..."

# Criar arquivo nginx.conf
cat > "$INSTALL_DIR/nginx/nginx.conf" << 'EOL'
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    tcp_nopush      on;
    tcp_nodelay     on;
    keepalive_timeout  65;
    types_hash_max_size 2048;
    server_tokens off;

    # SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Gzip settings
    gzip on;
    gzip_disable "msie6";
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # Include virtual host configs
    include /etc/nginx/conf.d/*.conf;
}
EOL
check_status "Arquivo nginx.conf criado"

# Criar configuração para o frontend
cat > "$INSTALL_DIR/nginx/conf.d/frontend.conf" << 'EOL'
server {
    listen 80;
    server_name app.rfminsights.com.br;

    # Redirecionar HTTP para HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name app.rfminsights.com.br;

    # Certificados SSL
    ssl_certificate /etc/nginx/ssl/frontend.crt;
    ssl_certificate_key /etc/nginx/ssl/frontend.key;

    # Logs
    access_log /var/log/nginx/frontend_access.log;
    error_log /var/log/nginx/frontend_error.log;

    # Configurações de segurança
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Strict Transport Security (HSTS)
    add_header Strict-Transport-Security "max-age=15768000; includeSubDomains" always;
    
    # Content Security Policy (CSP)
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' https://cdn.jsdelivr.net; style-src 'self' https://cdn.jsdelivr.net; img-src 'self' data:; font-src 'self'; connect-src 'self' https://api.rfminsights.com.br; frame-ancestors 'none';" always;

    # Configuração do proxy para o serviço frontend
    location / {
        proxy_pass http://frontend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOL
check_status "Arquivo frontend.conf criado"

# Criar configuração para a API
cat > "$INSTALL_DIR/nginx/conf.d/api.conf" << 'EOL'
server {
    listen 80;
    server_name api.rfminsights.com.br;

    # Redirecionar HTTP para HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name api.rfminsights.com.br;

    # Certificados SSL
    ssl_certificate /etc/nginx/ssl/api.crt;
    ssl_certificate_key /etc/nginx/ssl/api.key;

    # Logs
    access_log /var/log/nginx/api_access.log;
    error_log /var/log/nginx/api_error.log;

    # Configurações de segurança
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Strict Transport Security (HSTS)
    add_header Strict-Transport-Security "max-age=15768000; includeSubDomains" always;
    
    # Content Security Policy (CSP)
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' https://cdn.jsdelivr.net; style-src 'self' https://cdn.jsdelivr.net; img-src 'self' data:; font-src 'self'; connect-src 'self' https://api.rfminsights.com.br; frame-ancestors 'none';" always;

    # Configuração do proxy para o serviço API
    location / {
        proxy_pass http://api:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOL
check_status "Arquivo api.conf criado"

# Criar configuração para o frontend Nginx interno
cat > "$INSTALL_DIR/nginx/frontend.conf" << 'EOL'
server {
    listen 80;
    server_name localhost;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache de arquivos estáticos
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
}
EOL
check_status "Arquivo frontend.conf interno criado"

# 9. Gerar certificados SSL autoassinados
log "Gerando certificados SSL autoassinados..."

# Gerar certificado para o frontend
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$INSTALL_DIR/nginx/ssl/frontend.key" \
    -out "$INSTALL_DIR/nginx/ssl/frontend.crt" \
    -subj "/C=BR/ST=Estado/L=Cidade/O=RFMInsights/CN=app.rfminsights.com.br"

# Gerar certificado para a API
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$INSTALL_DIR/nginx/ssl/api.key" \
    -out "$INSTALL_DIR/nginx/ssl/api.crt" \
    -subj "/C=BR/ST=Estado/L=Cidade/O=RFMInsights/CN=api.rfminsights.com.br"

# Ajustar permissões
chmod 644 "$INSTALL_DIR/nginx/ssl/"*.crt
chmod 600 "$INSTALL_DIR/nginx/ssl/"*.key
check_status "Certificados SSL gerados"

# 10. Criar arquivo de verificação de saúde para o frontend
log "Criando arquivo de verificação de saúde para o frontend..."
cat > "$INSTALL_DIR/app/frontend/health.html" << 'EOL'
<!DOCTYPE html>
<html>
<head>
    <title>Health Check</title>
</head>
<body>
    <h1>OK</h1>
</body>
</html>
EOL
check_status "Arquivo health.html criado"

# 11. Iniciar os serviços
log "Iniciando os serviços..."
cd "$INSTALL_DIR"
docker compose up -d
check_status "Serviços iniciados"

# 12. Verificar status dos contêineres
log "Verificando status dos contêineres..."
docker compose ps

# 13. Criar script de verificação de saúde
log "Criando script de verificação de saúde..."
cat > "$INSTALL_DIR/health_check.sh" << 'EOL'
#!/bin/bash

# Definir cores para saída
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] Verificando status dos ser