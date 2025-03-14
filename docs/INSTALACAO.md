# Guia de Instalação do RFM Insights

Este guia fornece instruções detalhadas para instalar e configurar o RFM Insights utilizando Docker, Portainer para gerenciamento de contêineres e Nginx para roteamento de URLs.

## Pré-requisitos

- Servidor Linux (Ubuntu 20.04 LTS ou superior recomendado)
- Docker e Docker Compose instalados
- Domínios configurados (ap.rfminsights.com.br e api.rfminsights.com.br)
- Acesso root ou sudo ao servidor

## 1. Preparação do Ambiente

### 1.1 Atualizar o Sistema

```bash
sudo apt update && sudo apt upgrade -y
```

### 1.2 Instalar Docker e Docker Compose

```bash
# Instalar dependências
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# Adicionar chave GPG do Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Adicionar repositório do Docker
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Atualizar lista de pacotes
sudo apt update

# Instalar Docker
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Instalar Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Adicionar usuário ao grupo docker (opcional, para executar docker sem sudo)
sudo usermod -aG docker $USER
```

### 1.3 Verificar Instalação

```bash
# Verificar versão do Docker
docker --version

# Verificar versão do Docker Compose
docker-compose --version

# Testar Docker
docker run hello-world
```

## 2. Configuração do Portainer

### 2.1 Criar Volume para Persistência de Dados

```bash
sudo docker volume create portainer_data
```

### 2.2 Instalar e Iniciar Portainer

```bash
sudo docker run -d -p 8000:8000 -p 9443:9443 --name portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest
```

### 2.3 Acessar Portainer

Acesse `https://seu-servidor:9443` e crie uma senha de administrador.

## 3. Configuração do Projeto RFM Insights

### 3.1 Criar Estrutura de Diretórios

```bash
# Criar diretórios principais
mkdir -p ~/rfminsights/{app,nginx,postgres,portainer}

# Criar subdiretórios necessários para o Nginx
mkdir -p ~/rfminsights/nginx/{conf.d,ssl,logs}

# Verificar a criação dos diretórios
ls -la ~/rfminsights
ls -la ~/rfminsights/nginx

cd ~/rfminsights
```

### 3.2 Criar Arquivo Docker Compose

Crie o arquivo `docker-compose.yml` na pasta raiz:

```bash
cat > docker-compose.yml << 'EOL'
version: '3.8'

services:
  # Serviço da API
  api:
    build:
      context: ./app
      dockerfile: Dockerfile
    container_name: rfminsights-api
    restart: always
    volumes:
      - ./app:/app
      - ./app/data:/app/data
    env_file:
      - ./app/.env
    depends_on:
      - postgres
    networks:
      - rfminsights-network

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

  # Serviço do Banco de Dados PostgreSQL
  postgres:
    image: postgres:14-alpine
    container_name: rfminsights-postgres
    restart: always
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=rfminsights
      - POSTGRES_PASSWORD=rfminsights_password
      - POSTGRES_DB=rfminsights
    networks:
      - rfminsights-network

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

networks:
  rfminsights-network:
    driver: bridge

volumes:
  postgres_data:
    driver: local
EOL
```

### 3.3 Configurar Nginx para Proxy Reverso

Crie a pasta de configuração do Nginx:

```bash
mkdir -p ~/rfminsights/nginx/conf.d
mkdir -p ~/rfminsights/nginx/ssl
mkdir -p ~/rfminsights/nginx/logs
```

Crie o arquivo de configuração principal do Nginx:

```bash
cat > ~/rfminsights/nginx/nginx.conf << 'EOL'
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
```

Crie a configuração para o frontend (ap.rfminsights.com.br):

```bash
cat > ~/rfminsights/nginx/conf.d/frontend.conf << 'EOL'
server {
    listen 80;
    server_name ap.rfminsights.com.br;

    # Redirecionar HTTP para HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name ap.rfminsights.com.br;

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
```

Crie a configuração para a API (api.rfminsights.com.br):

```bash
cat > ~/rfminsights/nginx/conf.d/api.conf << 'EOL'
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
```

Crie a configuração para o frontend Nginx interno:

```bash
cat > ~/rfminsights/nginx/frontend.conf << 'EOL'
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
```

### 3.4 Configurar Arquivo .env

Crie a pasta do aplicativo e configure o arquivo .env:

```bash
# Criar diretório para a aplicação
mkdir -p ~/rfminsights/app

# Verificar se o arquivo .env.example existe no diretório atual
if [ -f ".env.example" ]; then
    # Se existir, copiar para o diretório da aplicação
    cp .env.example ~/rfminsights/app/.env
    echo "Arquivo .env.example copiado com sucesso."
else
    # Se não existir, criar o arquivo .env diretamente
    echo "Arquivo .env.example não encontrado. Criando arquivo .env diretamente."
fi
```

Edite o arquivo .env com as configurações corretas (isso substituirá qualquer conteúdo existente):

```bash
# Gerar uma chave JWT segura
JWT_KEY=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | xxd -p)

# Criar ou substituir o arquivo .env com as configurações corretas
cat > ~/rfminsights/app/.env << 'EOL'
# RFM Insights - Environment Variables

# Database Configuration
DATABASE_URL=postgresql://rfminsights:rfminsights_password@postgres/rfminsights

# JWT Configuration
JWT_SECRET_KEY=${JWT_KEY:-c8b74a279c95a740853a6c5b95eb985c12345f789abcdef0123456789abcdef0}
JWT_EXPIRATION_MINUTES=60

# Amazon SES Configuration for Email
AWS_REGION=us-east-1
# Credenciais da AWS
# ATENÇÃO: Substitua por credenciais reais ou deixe em branco se não usar email
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
EMAIL_SENDER=noreply@rfminsights.com.br

# OpenAI Configuration
# OBRIGATÓRIO: Substitua por uma chave de API válida da OpenAI
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
EOL

echo "Arquivo .env configurado com sucesso."
echo "IMPORTANTE: Edite o arquivo ~/rfminsights/app/.env e configure suas chaves de API e outras configurações específicas."
```

### 3.5 Estrutura de Arquivos do Projeto

O RFM Insights possui a seguinte estrutura de arquivos e diretórios:

```
RFMInsights/
├── backend/                # Código backend da aplicação
│   ├── __init__.py
│   ├── api_utils.py        # Utilitários para API
│   ├── auth.py             # Lógica de autenticação
│   ├── auth_routes.py      # Rotas de autenticação
│   ├── database.py         # Configuração do banco de dados
│   ├── marketplace.py      # Funcionalidades do marketplace
│   ├── middleware.py       # Middlewares da aplicação
│   ├── migrations.py       # Migrações do banco de dados
│   ├── models.py           # Modelos de dados
│   ├── monitoring.py       # Sistema de monitoramento
│   ├── rfm_analysis.py     # Lógica de análise RFM
│   ├── rfm_api.py          # Rotas da API RFM
│   └── schemas.py          # Esquemas de dados
├── config/                 # Configurações da aplicação
│   ├── __init__.py
│   ├── config.py           # Configurações gerais
│   ├── env_validator.py    # Validação de variáveis de ambiente
│   ├── logging_config.py   # Configuração de logs
│   └── monitoring_config.py # Configuração de monitoramento
├── docs/                   # Documentação
│   ├── INSTALACAO.md       # Guia de instalação
│   ├── README.md           # Documentação geral
│   └── nginx_security.md   # Configurações de segurança do Nginx
├── frontend/               # Interface de usuário
│   ├── ai_insights.js      # Funcionalidades de insights com IA
│   ├── analise.html        # Página de análise RFM
│   ├── analise.js          # Lógica da página de análise
│   ├── api-client.js       # Cliente para comunicação com a API
│   ├── app.js              # Aplicação principal
│   ├── cadastro.html       # Página de cadastro
│   ├── configuracoes.html  # Página de configurações
│   ├── dashboard.js        # Lógica do dashboard
│   ├── index.html          # Página inicial
│   ├── login.html          # Página de login
│   ├── marketplace.html    # Página do marketplace
│   └── styles.css          # Estilos da aplicação
├── migrations/             # Migrações do Alembic
│   ├── versions/           # Versões das migrações
│   └── env.py              # Ambiente de migrações
├── monitoring/             # Configurações de monitoramento
│   ├── grafana/            # Configurações do Grafana
│   │   ├── dashboards/     # Dashboards pré-configurados
│   │   └── provisioning/   # Configuração automática
│   └── prometheus/         # Configurações do Prometheus
├── scripts/                # Scripts utilitários
│   └── backup.sh           # Script de backup
├── tests/                  # Testes automatizados
│   ├── integration/        # Testes de integração
│   └── unit/               # Testes unitários
├── .env.example            # Exemplo de variáveis de ambiente
├── .env.monitoring         # Variáveis para monitoramento
├── Dockerfile              # Configuração do Docker
├── Dockerfile.optimized    # Dockerfile otimizado para produção
├── docker-compose.yml      # Configuração dos serviços
├── docker-compose.monitoring.yml # Configuração de monitoramento
├── main.py                 # Ponto de entrada da aplicação
├── alembic.ini             # Configuração do Alembic
└── requirements.txt        # Dependências Python
```

### 3.6 Copiar Arquivos do Projeto

Copie os arquivos do projeto para a pasta do aplicativo:

```bash
# Copiar todos os arquivos do projeto para a pasta do aplicativo
cp -r * ~/rfminsights/app/
```

## 4. Configuração de SSL

### 4.1 Gerar Certificados SSL Autoassinados (para desenvolvimento)

```bash
# Gerar certificado para o frontend
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ~/rfminsights/nginx/ssl/frontend.key \
    -out ~/rfminsights/nginx/ssl/frontend.crt \
    -subj "/C=BR/ST=Estado/L=Cidade/O=RFMInsights/CN=ap.rfminsights.com.br"

# Gerar certificado para a API
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ~/rfminsights/nginx/ssl/api.key \
    -out ~/rfminsights/nginx/ssl/api.crt \
    -subj "/C=BR/ST=Estado/L=Cidade/O=RFMInsights/CN=api.rfminsights.com.br"
```

### 4.2 Configurar Certificados Let's Encrypt (para produção)

Para ambiente de produção, é recomendado usar certificados válidos do Let's Encrypt:

```bash
# Instalar Certbot
sudo apt install -y certbot python3-certbot-nginx

# Obter certificados para os domínios
sudo certbot --nginx -d ap.rfminsights.com.br -d api.rfminsights.com.br

# Copiar certificados para a pasta do Nginx
sudo cp /etc/letsencrypt/live/ap.rfminsights.com.br/fullchain.pem ~/rfminsights/nginx/ssl/frontend.crt
sudo cp /etc/letsencrypt/live/ap.rfminsights.com.br/privkey.pem ~/rfminsights/nginx/ssl/frontend.key
sudo cp /etc/letsencrypt/live/api.rfminsights.com.br/fullchain.pem ~/rfminsights/nginx/ssl/api.crt
sudo cp /etc/letsencrypt/live/api.rfminsights.com.br/privkey.pem ~/rfminsights/nginx/ssl/api.key

# Ajustar permissões
sudo chmod 644 ~/rfminsights/nginx/ssl/*.crt
sudo chmod 600 ~/rfminsights/nginx/ssl/*.key
```

## 5. Implantação com Docker Compose

### 5.1 Iniciar os Serviços

```bash
cd ~/rfminsights
docker-compose up -d
```

### 5.2 Verificar Status dos Contêineres

```bash
docker-compose ps
```

### 5.3 Inicializar o Banco de Dados

```bash
# Executar migrações do banco de dados
docker-compose exec api python -m backend.migrations --init

# Criar usuário administrador inicial
docker-compose exec api python -m backend.migrations --seed
```

## 6. Verificação e Monitoramento

### 6.1 Verificar Logs dos Serviços

```bash
# Verificar logs da API
docker-compose logs api

# Verificar logs do frontend
docker-compose logs frontend

# Verificar logs do Nginx
docker-compose logs nginx-proxy
```

### 6.2 Verificar Conectividade

```bash
# Testar conectividade com a API
curl -k https://api.rfminsights.com.br/

# Testar conectividade com o frontend
curl -k https://ap.rfminsights.com.br/
```

### 6.3 Configurar Verificações de Saúde Automáticas

Crie um script para verificação automática de saúde dos serviços:

```bash
cat > ~/rfminsights/health_check.sh << 'EOL'
#!/bin/bash

# Verificar status dos contêineres
echo "Verificando status dos contêineres..."
docker ps | grep rfminsights

# Verificar API
echo "\nVerificando API..."
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -k https://api.rfminsights.com.br/)
if [ "$API_STATUS" == "200" ] || [ "$API_STATUS" == "401" ]; then
    echo "API está funcionando (status: $API_STATUS)"
else
    echo "ERRO: API não está respondendo corretamente (status: $API_STATUS)"
fi

# Verificar Frontend
echo "\nVerificando Frontend..."
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -k https://ap.rfminsights.com.br/)
if [ "$FRONTEND_STATUS" == "200" ]; then
    echo "Frontend está funcionando (status: $FRONTEND_STATUS)"
else
    echo "ERRO: Frontend não está respondendo corretamente (status: $FRONTEND_STATUS)"
fi

# Verificar Banco de Dados
echo "\nVerificando Banco de Dados..."
DB_STATUS=$(docker-compose exec -T postgres pg_isready -U rfminsights)
echo "Status do banco de dados: $DB_STATUS"
EOL

chmod +x ~/rfminsights/health_check.sh
```

Adicione o script ao crontab para execução periódica:

```bash
(crontab -l 2>/dev/null; echo "0 * * * * ~/rfminsights/health_check.sh >> ~/rfminsights/health_check.log 2>&1") | crontab -
```

## 7. Backup e Restauração

### 7.1 Configurar Backup Automático

Crie um script para backup automático do banco de dados:

```bash
cat > ~/rfminsights/backup.sh << 'EOL'
#!/bin/bash

# Configurações
BACKUP_DIR=~/rfminsights/backups
DATETIME=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/rfminsights_$DATETIME.sql"

# Criar diretório de backup se não existir
mkdir -p $BACKUP_DIR

# Realizar backup do banco de dados
echo "Realizando backup do banco de dados..."
docker-compose exec -T postgres pg_dump -U rfminsights rfminsights > $BACKUP_FILE

# Comprimir arquivo de backup
gzip $BACKUP_FILE

# Manter apenas os últimos 7 backups
echo "Removendo backups antigos..."
ls -t $BACKUP_DIR/rfminsights_*.sql.gz | tail -n +8 | xargs -r rm

echo "Backup concluído: ${BACKUP_FILE}.gz"
EOL

chmod +x ~/rfminsights/backup.sh
```

Adicione o script ao crontab para execução diária:

```bash
(crontab -l 2>/dev/null; echo "0 2 * * * ~/rfminsights/backup.sh >> ~/rfminsights/backup.log 2>&1") | crontab -
```

### 7.2 Restaurar Backup

```bash
# Restaurar backup (substitua ARQUIVO_BACKUP pelo nome do arquivo de backup)
gunzip -c ~/rfminsights/backups/ARQUIVO_BACKUP.sql.gz | docker-compose exec -T postgres psql -U rfminsights rfminsights
```

## 8. Atualização da Aplicação

### 8.1 Atualizar Código

```bash
cd ~/rfminsights/app
git pull origin main  # ou o branch que você está usando
```

### 8.2 Reconstruir e Reiniciar Contêineres

```bash
cd ~/rfminsights
docker-compose down
docker-compose build
docker-compose up -d
```

### 8.3 Verificar Atualização

```bash
# Verificar logs após atualização
docker-compose logs --tail=100 api

# Executar verificação de saúde
./health_check.sh
```

## 9. Solução de Problemas

### 9.1 Problemas Comuns e Soluções

#### Erro de Conexão com o Banco de Dados

```bash
# Verificar se o contêiner do PostgreSQL está em execução
docker-compose ps postgres

# Verificar logs do PostgreSQL
docker-compose logs postgres

# Reiniciar o PostgreSQL
docker-compose restart postgres
```

#### Erro de Permissão nos Certificados SSL

```bash
# Corrigir permissões dos certificados
sudo chmod 644 ~/rfminsights/nginx/ssl/*.crt
sudo chmod 600 ~/rfminsights/nginx/ssl/*.key

# Reiniciar o Nginx
docker-compose restart nginx-proxy
```

#### Erro 502 Bad Gateway

```bash
# Verificar se a API está em execução
docker-compose ps api

# Verificar logs da API
docker-compose logs api

# Reiniciar a API
docker-compose restart api
```

### 9.2 Comandos Úteis para Diagnóstico

```bash
# Verificar uso de recursos
docker stats

# Verificar configuração do Nginx
docker-compose exec nginx-proxy nginx -t

# Verificar conectividade entre contêineres
docker-compose exec api ping -c 3 postgres
```

## 10. Gerenciamento via Portainer

### 10.1 Acessar Portainer

Acesse o Portainer em `https://seu-servidor:9443` e faça login com as credenciais criadas anteriormente.

### 10.2 Adicionar Stack do RFM Insights

1. No menu lateral, clique em "Stacks"
2. Clique em "Add stack"
3. Dê um nome à stack (ex: "rfminsights")
4. Na seção "Build method", selecione "Upload"
5. Faça upload do arquivo docker-compose.yml
6. Clique em "Deploy the stack"

### 10.3 Gerenciar Contêineres

No Portainer, você pode:

- Visualizar logs dos contêineres
- Reiniciar, parar ou iniciar contêineres
- Acessar o terminal dos contêineres
- Monitorar o uso de recursos

## 11. Configuração do Sistema de Monitoramento

O RFM Insights inclui um sistema completo de monitoramento baseado em Prometheus e Grafana para acompanhar o desempenho e a saúde da aplicação em ambiente de produção.

### 11.1 Configurar Variáveis de Ambiente para Monitoramento

Crie o arquivo `.env.monitoring` na pasta raiz do projeto:

```bash
cat > ~/rfminsights/.env.monitoring << 'EOL'
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
```

### 11.2 Criar Estrutura de Diretórios para Monitoramento

```bash
mkdir -p ~/rfminsights/monitoring/prometheus
mkdir -p ~/rfminsights/monitoring/grafana/provisioning/{datasources,dashboards}
mkdir -p ~/rfminsights/monitoring/grafana/dashboards
```

### 11.3 Configurar Prometheus

Crie o arquivo de configuração do Prometheus:

```bash
cat > ~/rfminsights/monitoring/prometheus/prometheus.yml << 'EOL'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          # - alertmanager:9093

rule_files:
  # - "first_rules.yml"

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "rfminsights-api"
    static_configs:
      - targets: ["api:8000"]

  - job_name: "node-exporter"
    static_configs:
      - targets: ["node-exporter:9100"]

  - job_name: "cadvisor"
    static_configs:
      - targets: ["cadvisor:8080"]
EOL
```

### 11.4 Configurar Grafana

Crie a configuração de fonte de dados para o Grafana:

```bash
cat > ~/rfminsights/monitoring/grafana/provisioning/datasources/datasource.yml << 'EOL'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
EOL
```

### 11.5 Iniciar Serviços de Monitoramento

```bash
cd ~/rfminsights
docker-compose -f docker-compose.monitoring.yml up -d
```

### 11.6 Verificar Status dos Serviços de Monitoramento

```bash
docker-compose -f docker-compose.monitoring.yml ps
```

### 11.7 Configurar Nginx para Monitoramento

Para acessar os serviços de monitoramento de forma segura, configure o Nginx para atuar como proxy reverso:

```bash
cat > ~/rfminsights/nginx/conf.d/monitoring.conf << 'EOL'
server {
    listen 80;
    server_name monitoring.rfminsights.com.br;

    # Redirecionar HTTP para HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name monitoring.rfminsights.com.br;

    # Certificados SSL
    ssl_certificate /etc/nginx/ssl/monitoring.crt;
    ssl_certificate_key /etc/nginx/ssl/monitoring.key;

    # Logs
    access_log /var/log/nginx/monitoring_access.log;
    error_log /var/log/nginx/monitoring_error.log;

    # Configurações de segurança
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Strict Transport Security (HSTS)
    add_header Strict-Transport-Security "max-age=15768000; includeSubDomains" always;
    
    # Autenticação básica para proteção adicional
    auth_basic "Área Restrita de Monitoramento";
    auth_basic_user_file /etc/nginx/monitoring_users;

    # Proxy para Grafana
    location / {
        proxy_pass http://grafana:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Proxy para Prometheus (subpath /prometheus/)
    location /prometheus/ {
        proxy_pass http://prometheus:9090/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOL
```

Crie o arquivo de autenticação para o acesso ao monitoramento:

```bash
# Instalar apache2-utils para usar o comando htpasswd
sudo apt install -y apache2-utils

# Criar arquivo de usuários (substitua 'admin_monitoring' pela senha desejada)
sudo htpasswd -c ~/rfminsights/nginx/monitoring_users admin admin_monitoring

# Copiar para o volume do Nginx
docker cp ~/rfminsights/nginx/monitoring_users rfminsights-nginx-proxy:/etc/nginx/

# Reiniciar o Nginx para aplicar as alterações
docker-compose restart nginx-proxy
```

### 11.8 Acessar Interfaces de Monitoramento

- Monitoramento (Grafana): https://monitoring.rfminsights.com.br
- Prometheus: https://monitoring.rfminsights.com.br/prometheus/

Credenciais de acesso:
- Autenticação HTTP: usuário: admin, senha: admin_monitoring
- Grafana: usuário: admin, senha: rfminsights_grafana

## 12. Estrutura de Rotas e Endpoints da API

O RFM Insights possui uma estrutura de API organizada com endpoints versionados para garantir compatibilidade e facilitar a manutenção.

### 12.1 Rotas Principais da API

A API do RFM Insights está organizada nos seguintes grupos de endpoints:

#### Endpoints Versionados (Recomendados)

- **Análise RFM**: `/api/v1/rfm/`
  - `/api/v1/rfm/analyze` - Realizar análise RFM
  - `/api/v1/rfm/segments` - Listar segmentos RFM
  - `/api/v1/rfm/insights` - Gerar insights baseados em análise RFM
  - `/api/v1/rfm/export` - Exportar resultados da análise

- **Marketplace**: `/api/v1/marketplace/`
  - `/api/v1/marketplace/integrations` - Listar integrações disponíveis
  - `/api/v1/marketplace/plugins` - Gerenciar plugins

- **Autenticação**: `/api/v1/auth/`
  - `/api/v1/auth/login` - Autenticar usuário
  - `/api/v1/auth/register` - Registrar novo usuário
  - `/api/v1/auth/refresh` - Renovar token de acesso
  - `/api/v1/auth/password-reset` - Solicitar redefinição de senha

#### Endpoints Legados (Compatibilidade)

Para compatibilidade com versões anteriores, os seguintes endpoints também estão disponíveis:

- `/api/rfm/*` - Endpoints de análise RFM
- `/api/marketplace/*` - Endpoints do marketplace
- `/api/auth/*` - Endpoints de autenticação

### 12.2 Documentação da API

A documentação completa da API está disponível em:

- Swagger UI: `https://api.rfminsights.com.br/docs`
- ReDoc: `https://api.rfminsights.com.br/redoc`

A documentação inclui todos os endpoints, parâmetros, exemplos de requisições e respostas.

## 13. Conclusão

Parabéns! Você concluiu a instalação e configuração do RFM Insights utilizando Docker, Portainer e Nginx. A aplicação agora está disponível nos seguintes endereços:

- Frontend: https://ap.rfminsights.com.br
- API: https://api.rfminsights.com.br
- Documentação da API: https://api.rfminsights.com.br/docs
- Monitoramento (Grafana): https://monitoring.rfminsights.com.br

Para acessar o sistema, utilize as credenciais de administrador criadas durante a inicialização do banco de dados:

- Email: admin@rfminsights.com
- Senha: admin123 (recomendamos alterar esta senha após o primeiro acesso)

Em caso de dúvidas ou problemas, consulte a documentação ou entre em contato com o suporte técnico.