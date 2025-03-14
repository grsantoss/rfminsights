# Guia de Instalação do RFM Insights

Este guia fornece instruções simplificadas para instalar e configurar o RFM Insights utilizando Docker.

## Pré-requisitos

- Servidor Linux (Ubuntu 20.04 LTS ou superior recomendado) ou Windows com Docker
- Docker e Docker Compose instalados
- Domínios configurados (opcional para produção)

## 1. Preparação do Ambiente

### 1.1 Instalar Docker e Docker Compose

#### Linux
```bash
# Instalar dependências
sudo apt update && sudo apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release

# Configurar repositório do Docker
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Instalar Docker Compose v2
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-linux-$(uname -m)" -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
sudo ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
```

#### Windows
Baixe e instale o Docker Desktop para Windows em https://www.docker.com/products/docker-desktop

## 2. Instalação do RFM Insights

### 2.1 Criar Estrutura de Diretórios

```bash
# Criar diretório de instalação
mkdir -p ~/rfminsights
cd ~/rfminsights

# Criar estrutura de diretórios
mkdir -p app nginx/{conf.d,ssl,logs} data backups
```

### 2.2 Configurar Arquivo .env

Crie o arquivo `.env` na pasta raiz do projeto:

```bash
cat > .env << 'EOL'
# RFM Insights - Environment Variables

# Database Configuration
DATABASE_URL=postgresql://rfminsights:rfminsights_password@postgres/rfminsights

# JWT Configuration
JWT_SECRET_KEY=c8b74a279c95a740853a6c5b95eb985c12345f789abcdef0123456789abcdef0
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
EOL
```

### 2.3 Configurar Docker Compose

Crie o arquivo `docker-compose.yml` na pasta raiz:

```bash
cat > docker-compose.yml << 'EOL'
version: '3.8'

services:
  # Serviço da API
  api:
    build:
      context: .
      dockerfile: Dockerfile.optimized
    container_name: rfminsights-api
    restart: on-failure:3
    volumes:
      - ./:/app
      - ./data:/app/data
    env_file:
      - ./.env
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
      - ./frontend:/usr/share/nginx/html
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

## 3. Configuração de SSL (Opcional para Desenvolvimento)

### 3.1 Gerar Certificados Autoassinados (Desenvolvimento)

```bash
# Criar diretório para certificados
mkdir -p ~/rfminsights/nginx/ssl
cd ~/rfminsights/nginx/ssl

# Gerar certificados para frontend
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout frontend.key -out frontend.crt \
  -subj "/CN=app.rfminsights.com.br"

# Gerar certificados para API
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout api.key -out api.crt \
  -subj "/CN=api.rfminsights.com.br"

# Ajustar permissões
chmod 644 *.crt
chmod 600 *.key
```

### 3.2 Configurar Nginx

Crie os arquivos de configuração do Nginx:

```bash
# Configuração para o frontend
cat > ~/rfminsights/nginx/conf.d/frontend.conf << 'EOL'
server {
    listen 80;
    server_name app.rfminsights.com.br localhost;

    # Redirecionar HTTP para HTTPS em produção
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name app.rfminsights.com.br localhost;

    # Certificados SSL
    ssl_certificate /etc/nginx/ssl/frontend.crt;
    ssl_certificate_key /etc/nginx/ssl/frontend.key;

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

# Configuração para a API
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

## 4. Implantação

### 4.1 Iniciar os Serviços

```bash
cd ~/rfminsights
docker-compose up -d
```

### 4.2 Verificar Status dos Contêineres

```bash
docker-compose ps
```

### 4.3 Inicializar o Banco de Dados

```bash
# Executar migrações do banco de dados
docker-compose exec api python -m backend.migrations --init

# Criar usuário administrador inicial
docker-compose exec api python -m backend.migrations --seed
```

## 5. Verificação e Acesso

### 5.1 Verificar Logs

```bash
# Verificar logs da API
docker-compose logs api

# Verificar logs do frontend
docker-compose logs frontend
```

### 5.2 Acessar a Aplicação

- Frontend: https://app.rfminsights.com.br ou http://localhost (desenvolvimento)
- API: https://api.rfminsights.com.br ou http://localhost:8000 (desenvolvimento)
- Documentação da API: https://api.rfminsights.com.br/docs

Credenciais de acesso padrão:
- Email: admin@rfminsights.com
- Senha: admin123 (altere após o primeiro acesso)

## 6. Backup e Restauração

### 6.1 Backup Manual do Banco de Dados

```bash
# Criar diretório para backups
mkdir -p ~/rfminsights/backups

# Realizar backup
docker-compose exec postgres pg_dump -U rfminsights rfminsights > ~/rfminsights/backups/rfminsights_$(date +"%Y%m%d").sql
```

### 6.2 Restaurar Backup

```bash
# Restaurar backup (substitua ARQUIVO_BACKUP pelo nome do arquivo)
cat ~/rfminsights/backups/ARQUIVO_BACKUP.sql | docker-compose exec -T postgres psql -U rfminsights rfminsights
```

## 7. Atualização da Aplicação

```bash
cd ~/rfminsights
docker-compose down
git pull  # Se estiver usando repositório Git
docker-compose build
docker-compose up -d
```

## 8. Solução de Problemas Comuns

### 8.1 Erro de Conexão com o Banco de Dados

```bash
# Verificar status do PostgreSQL
docker-compose ps postgres
docker-compose logs postgres

# Reiniciar o PostgreSQL
docker-compose restart postgres
```

### 8.2 Erro 502 Bad Gateway

```bash
# Verificar se a API está em execução
docker-compose ps api
docker-compose logs api

# Reiniciar a API
docker-compose restart api
```

### 8.3 Problemas com Dependências Python

Verifique se todas as dependências estão instaladas, especialmente o pacote `reportlab` que é essencial para a geração de relatórios.

```bash
# Verificar dependências instaladas
docker-compose exec api pip list

# Instalar dependências manualmente se necessário
docker-compose exec api pip install reportlab
```

## 9. Conclusão

Parabéns! Você concluiu a instalação do RFM Insights. Para mais informações sobre a API e suas funcionalidades, consulte a documentação em https://api.rfminsights.com.br/docs.