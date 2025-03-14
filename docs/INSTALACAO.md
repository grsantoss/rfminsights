# Guia de Instalação do RFM Insights

Este guia fornece instruções detalhadas para instalar e configurar o RFM Insights utilizando Docker.

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

## 2. Obtenção do Código

### 2.1 Clonar o Repositório (Recomendado)

```bash
# Clonar o repositório do GitHub
git clone https://github.com/seu-usuario/rfminsights.git
cd rfminsights
```

### 2.2 Download Manual (Alternativa)

Se você recebeu os arquivos diretamente:

```bash
# Criar diretório de instalação
mkdir -p ~/rfminsights
cd ~/rfminsights

# Extrair os arquivos recebidos para este diretório
# Exemplo: unzip rfminsights.zip -d ~/rfminsights
```

## 3. Instalação do RFM Insights

### 3.1 Criar Estrutura de Diretórios

```bash
# Criar estrutura de diretórios (se não existir)
mkdir -p app nginx/{conf.d,ssl,logs} data backups
```

### 3.2 Configurar Arquivo .env

O arquivo `.env` contém todas as variáveis de ambiente necessárias para a aplicação. Siga as instruções abaixo para configurá-lo corretamente:

#### Linux

```bash
# Verificar se .env.example existe e copiá-lo para .env
if [ -f ".env.example" ]; then
    cp .env.example .env
    echo "✅ Arquivo .env criado com sucesso a partir do .env.example"
    echo "⚠️ IMPORTANTE: Edite o arquivo .env e configure todas as variáveis necessárias antes de prosseguir"
else
    echo "⚠️ Arquivo .env.example não encontrado. Criando .env com configurações padrão..."
    # Criar arquivo .env manualmente se .env.example não existir
    cat > .env << 'EOL'
# RFM Insights - Environment Variables

# Database Configuration
DATABASE_URL=postgresql://rfminsights:rfminsights_password@postgres/rfminsights

# JWT Configuration
# ATENÇÃO: Substitua esta chave por uma chave segura em produção
JWT_SECRET_KEY=c8b74a279c95a740853a6c5b95eb985c12345f789abcdef0123456789abcdef0
JWT_EXPIRATION_MINUTES=60

# Amazon SES Configuration for Email
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
EMAIL_SENDER=noreply@rfminsights.com.br

# OpenAI Configuration
# OBRIGATÓRIO: Adicione sua chave de API da OpenAI
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
    echo "✅ Arquivo .env criado com configurações padrão"
    echo "⚠️ IMPORTANTE: Edite o arquivo .env e configure todas as variáveis necessárias antes de prosseguir"
fi

# Verificar se as variáveis obrigatórias estão configuradas
echo "ℹ️ Verificando configurações do arquivo .env..."
if grep -q "SUBSTITUA_POR" .env || grep -q "JWT_SECRET_KEY=$" .env || grep -q "OPENAI_API_KEY=$" .env; then
    echo "⚠️ ATENÇÃO: Algumas variáveis importantes no arquivo .env precisam ser configuradas:"
    echo "   - JWT_SECRET_KEY: Chave de segurança para autenticação"
    echo "   - OPENAI_API_KEY: Chave da API OpenAI para recursos de IA"
    echo "   Edite o arquivo .env antes de continuar."
fi
```

#### Windows (PowerShell)

```powershell
# Verificar se .env.example existe e copiá-lo para .env
if (Test-Path ".env.example") {
    Copy-Item ".env.example" ".env"
    Write-Host "✅ Arquivo .env criado com sucesso a partir do .env.example" -ForegroundColor Green
    Write-Host "⚠️ IMPORTANTE: Edite o arquivo .env e configure todas as variáveis necessárias antes de prosseguir" -ForegroundColor Yellow
} else {
    Write-Host "⚠️ Arquivo .env.example não encontrado. Criando .env com configurações padrão..." -ForegroundColor Yellow
    # Criar arquivo .env manualmente se .env.example não existir
    @"
# RFM Insights - Environment Variables

# Database Configuration
DATABASE_URL=postgresql://rfminsights:rfminsights_password@postgres/rfminsights

# JWT Configuration
# ATENÇÃO: Substitua esta chave por uma chave segura em produção
JWT_SECRET_KEY=c8b74a279c95a740853a6c5b95eb985c12345f789abcdef0123456789abcdef0
JWT_EXPIRATION_MINUTES=60

# Amazon SES Configuration for Email
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
EMAIL_SENDER=noreply@rfminsights.com.br

# OpenAI Configuration
# OBRIGATÓRIO: Adicione sua chave de API da OpenAI
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
"@ | Out-File -FilePath ".env" -Encoding utf8
    Write-Host "✅ Arquivo .env criado com configurações padrão" -ForegroundColor Green
    Write-Host "⚠️ IMPORTANTE: Edite o arquivo .env e configure todas as variáveis necessárias antes de prosseguir" -ForegroundColor Yellow
}

# Verificar se as variáveis obrigatórias estão configuradas
Write-Host "ℹ️ Verificando configurações do arquivo .env..." -ForegroundColor Cyan
$envContent = Get-Content ".env" -Raw
if ($envContent -match "SUBSTITUA_POR" -or $envContent -match "JWT_SECRET_KEY=$" -or $envContent -match "OPENAI_API_KEY=$") {
    Write-Host "⚠️ ATENÇÃO: Algumas variáveis importantes no arquivo .env precisam ser configuradas:" -ForegroundColor Yellow
    Write-Host "   - JWT_SECRET_KEY: Chave de segurança para autenticação" -ForegroundColor Yellow
    Write-Host "   - OPENAI_API_KEY: Chave da API OpenAI para recursos de IA" -ForegroundColor Yellow
    Write-Host "   Edite o arquivo .env antes de continuar." -ForegroundColor Yellow
}
```

> **Nota**: É fundamental configurar corretamente todas as variáveis de ambiente antes de prosseguir com a instalação, especialmente as chaves de segurança e API.

### 3.3 Configurar Docker Compose

Verifique se o arquivo `docker-compose.yml` já existe. Se não existir, crie-o:

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
    restart: unless-stopped
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
    restart: unless-stopped
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
    restart: unless-stopped
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
    restart: unless-stopped
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

## 4. Configuração de SSL (Opcional para Desenvolvimento)

### 4.1 Gerar Certificados Autoassinados (Desenvolvimento)

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

### 4.2 Configurar Nginx

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

## 5. Implantação

### 5.1 Verificar e Instalar Dependências

#### 5.1.1 Verificar Dependências no requirements.txt

Verifique se o pacote `reportlab` está incluído no arquivo `requirements.txt`. Se não estiver, adicione-o:

```bash
# Verificar se reportlab está no requirements.txt
if ! grep -q "reportlab==" requirements.txt; then
    echo "reportlab==3.6.12" >> requirements.txt
    echo "✅ Adicionado reportlab ao requirements.txt"
fi

# Verificar outras dependências críticas
CRITICAL_DEPS=("fastapi" "uvicorn" "sqlalchemy" "openai" "pandas")
for dep in "${CRITICAL_DEPS[@]}"; do
    if ! grep -q "$dep==" requirements.txt; then
        echo "⚠️ Dependência crítica não encontrada: $dep"
        echo "Por favor, verifique o arquivo requirements.txt manualmente"
    fi
done
```

#### 5.1.2 Garantir Instalação Correta no Dockerfile

Verifique se o Dockerfile está configurado corretamente para instalar todas as dependências:

```bash
# Verificar se o Dockerfile contém o comando de instalação de dependências
if ! grep -q "pip install --no-cache-dir -r requirements.txt" Dockerfile*; then
    echo "⚠️ AVISO: Não foi encontrado o comando de instalação de dependências no Dockerfile"
    echo "Verifique manualmente os arquivos Dockerfile e Dockerfile.optimized"
fi
```

#### 5.1.3 Instalação Manual de Dependências (Caso Necessário)

Se a instalação automática falhar durante a construção do container, você pode instalar manualmente as dependências:

```bash
# Instalação manual dentro do container da API
docker-compose exec api pip install --no-cache-dir reportlab==3.6.12

# Verificar se a instalação foi bem-sucedida
docker-compose exec api python -c "import reportlab; print(f'Reportlab instalado: versão {reportlab.__version__}')"
```

#### 5.1.4 Verificação de Dependências Após Instalação

```bash
# Verificar dependências instaladas no container
docker-compose exec api pip list | grep -E "reportlab|fastapi|uvicorn|sqlalchemy|openai|pandas"

# Verificar se o módulo reportlab pode ser importado corretamente
docker-compose exec api python -c "import reportlab; print('✅ Reportlab importado com sucesso!')"
```


### 5.2 Forçar Reconstrução dos Containers

```bash
cd ~/rfminsights

# Forçar reconstrução dos containers para garantir que todas as dependências sejam instaladas corretamente
# Isso evita problemas com versões antigas em cache e garante que todas as alterações sejam aplicadas
docker-compose build --no-cache

# Verificar se a reconstrução foi bem-sucedida
if [ $? -eq 0 ]; then
    echo "✅ Reconstrução dos containers concluída com sucesso"
else
    echo "⚠️ Erro na reconstrução dos containers. Verifique os logs para mais detalhes."
    echo "Você pode tentar resolver problemas de dependências manualmente (veja seção 8 - Troubleshooting)"
fi
```

#### Windows (PowerShell)

```powershell
cd C:\caminho\para\rfminsights

# Forçar reconstrução dos containers para garantir que todas as dependências sejam instaladas corretamente
docker-compose build --no-cache

# Verificar se a reconstrução foi bem-sucedida
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Reconstrução dos containers concluída com sucesso" -ForegroundColor Green
} else {
    Write-Host "⚠️ Erro na reconstrução dos containers. Verifique os logs para mais detalhes." -ForegroundColor Red
    Write-Host "Você pode tentar resolver problemas de dependências manualmente (veja seção 8 - Troubleshooting)" -ForegroundColor Yellow
}
```

### 5.3 Iniciar os Serviços

```bash
# Iniciar todos os serviços
docker-compose up -d

# Aguardar inicialização completa dos serviços
echo "Aguardando inicialização dos serviços (10 segundos)..."
sleep 10

# Verificar se o serviço da API está em execução e se as dependências foram carregadas corretamente
docker-compose exec api python -c "import sys; import reportlab; print(f'Python {sys.version}'); print(f'Reportlab {reportlab.__version__} instalado com sucesso!')" || {
    echo "⚠️ Erro ao verificar dependências. Verifique a seção de Troubleshooting."
}
```

### 5.4 Verificar Status dos Contêineres

```bash
docker-compose ps
```

### 5.5 Testar Comunicação Entre Containers

```bash
# Verificar se a API está respondendo antes de iniciar o Nginx
echo "Verificando se a API está em execução antes de prosseguir..."
API_HEALTH_CHECK=$(docker-compose exec api curl -f http://localhost:8000/health 2>/dev/null || echo "Falha")
if [[ "$API_HEALTH_CHECK" == *"healthy"* ]]; then
    echo "✅ API está em execução e respondendo corretamente"
else
    echo "⚠️ API não está respondendo corretamente. Verificando logs..."
    docker-compose logs api --tail=50
    echo "⚠️ Aguardando 30 segundos para nova tentativa..."
    sleep 30
    API_HEALTH_CHECK=$(docker-compose exec api curl -f http://localhost:8000/health 2>/dev/null || echo "Falha")
    if [[ "$API_HEALTH_CHECK" == *"healthy"* ]]; then
        echo "✅ API está em execução e respondendo corretamente após aguardar"
    else
        echo "❌ API continua não respondendo. Verifique a configuração e os logs."
    fi
fi

# Testar comunicação entre nginx-proxy e api
echo "Testando comunicação interna entre nginx-proxy e api..."
NGINX_API_CHECK=$(docker-compose exec nginx-proxy curl -I http://api:8000 2>/dev/null || echo "Falha")
if [[ "$NGINX_API_CHECK" == *"200 OK"* ]] || [[ "$NGINX_API_CHECK" == *"401 Unauthorized"* ]]; then
    echo "✅ Comunicação entre nginx-proxy e api está funcionando corretamente"
else
    echo "❌ Falha na comunicação entre nginx-proxy e api. Resposta:"
    echo "$NGINX_API_CHECK"
    echo "Verificando configuração de rede..."
    docker network inspect rfminsights-network
fi

# Verificar se a API está respondendo através do endpoint de saúde
echo "Verificando endpoint de saúde da API..."
docker-compose exec nginx-proxy curl -I http://api:8000/health

# Verificar se o frontend está respondendo
echo "Verificando se o frontend está respondendo..."
docker-compose exec nginx-proxy curl -I http://frontend
```

### 5.6 Inicializar o Banco de Dados

#### 5.6.1 Verificar Prontidão do PostgreSQL

Antes de executar as migrações, é importante verificar se o PostgreSQL está completamente inicializado e pronto para aceitar conexões. O RFM Insights inclui um script de verificação de saúde do banco de dados que realiza esta verificação automaticamente durante a inicialização:

```bash
# Verificar se o PostgreSQL está pronto antes de executar migrações
docker-compose exec api python /app/scripts/db_healthcheck.py --max-retries 30 --retry-interval 2

# Se o comando acima falhar, você pode verificar manualmente
docker-compose exec postgres pg_isready -U rfminsights
```

> **Nota**: O script `db_healthcheck.py` tenta conectar-se ao banco de dados várias vezes com um intervalo configurável entre as tentativas. Isso é especialmente útil em ambientes onde o PostgreSQL pode levar mais tempo para inicializar completamente.

#### 5.6.2 Executar Migrações

Após confirmar que o PostgreSQL está pronto, você pode executar as migrações do banco de dados:

```bash
# Executar migrações do banco de dados
docker-compose exec api python -m backend.migrations --init

# Criar usuário administrador inicial
docker-compose exec api python -m backend.migrations --seed
```

## 6. Verificação e Acesso

### 6.1 Verificar Logs

```bash
# Verificar logs da API
docker-compose logs api

# Verificar logs do frontend
docker-compose logs frontend

# Verificar logs do nginx
docker-compose logs nginx-proxy
```

### 6.2 Acessar a Aplicação

- Frontend: https://app.rfminsights.com.br ou http://localhost (desenvolvimento)
- API: https://api.rfminsights.com.br ou http://localhost:8000 (desenvolvimento)
- Documentação da API: https://api.rfminsights.com.br/docs

Credenciais de acesso padrão:
- Email: admin@rfminsights.com
- Senha: admin123 (altere após o primeiro acesso)

## 7. Backup e Restauração

### 7.1 Backup Manual do Banco de Dados

```bash
# Criar diretório para backups
mkdir -p ~/rfminsights/backups

# Realizar backup
docker-compose exec postgres pg_dump -U rfminsights rfminsights > ~/rfminsights/backups/rfminsights_$(date +%Y%m%d_%H%M%S).sql
```

### 7.2 Restauração de Backup

```bash
# Restaurar backup (substitua ARQUIVO_BACKUP pelo nome do arquivo de backup)
docker-compose exec -T postgres psql -U rfminsights rfminsights < ~/rfminsights/backups/ARQUIVO_BACKUP
```

## 8. Troubleshooting

### 8.1 Problemas com Containers

#### 8.1.1 Containers em Loop de Reinicialização

Se um container estiver reiniciando repetidamente (em loop), você pode desativar a política de reinicialização automática para diagnosticar o problema:

```bash
# Verificar o status dos containers para identificar qual está em loop de reinicialização
docker-compose ps

# Desativar a reinicialização automática do container problemático
# Substitua NOME_DO_CONTAINER pelo nome do container (ex: rfminsights-api)
docker update --restart=no NOME_DO_CONTAINER

# Parar o container
docker stop NOME_DO_CONTAINER

# Verificar os logs para identificar o problema
docker logs NOME_DO_CONTAINER
```

#### Windows (PowerShell)

```powershell
# Verificar o status dos containers para identificar qual está em loop de reinicialização
docker-compose ps

# Desativar a reinicialização automática do container problemático
# Substitua NOME_DO_CONTAINER pelo nome do container (ex: rfminsights-api)
docker update --restart=no NOME_DO_CONTAINER

# Parar o container
docker stop NOME_DO_CONTAINER

# Verificar os logs para identificar o problema
docker logs NOME_DO_CONTAINER
```

Após identificar e corrigir o problema, você pode restaurar a política de reinicialização e iniciar o container novamente:

```bash
# Restaurar a política de reinicialização
docker update --restart=unless-stopped NOME_DO_CONTAINER

# Iniciar o container novamente
docker start NOME_DO_CONTAINER
```

### 8.2 Problemas com o Banco de Dados

#### 8.2.1 Falha na Conexão com o Banco de Dados

Se você encontrar problemas de conexão com o banco de dados durante a inicialização ou execução da aplicação, utilize o script de verificação de saúde do banco de dados para diagnosticar o problema:

```bash
# Executar verificação de saúde do banco de dados com mais tentativas
docker-compose exec api python /app/scripts/db_healthcheck.py --max-retries 60 --retry-interval 5 --exit-on-failure

# Verificar logs do PostgreSQL
docker-compose logs postgres

# Verificar se o PostgreSQL está aceitando conexões
docker-compose exec postgres pg_isready -U rfminsights
```

Problemas comuns e soluções:

1. **PostgreSQL ainda está inicializando**: Aguarde alguns minutos e tente novamente.
2. **Credenciais incorretas**: Verifique as variáveis de ambiente no arquivo `.env`.
3. **Problemas de rede**: Verifique se os containers estão na mesma rede Docker.
4. **Problemas de permissão**: Verifique as permissões do diretório de dados do PostgreSQL.

```bash
# Verificar permissões do diretório de dados
docker-compose exec postgres ls -la /var/lib/postgresql/data
```

#### 8.2.2 Erro na Instalação do ReportLab

Se você encontrar erros relacionados ao ReportLab durante a construção do container ou inicialização da aplicação:

```bash
# Verificar se o ReportLab está instalado corretamente
docker-compose exec api pip show reportlab

# Se não estiver instalado ou apresentar erros, instale manualmente
docker-compose exec api pip uninstall -y reportlab
docker-compose exec api pip install --no-cache-dir reportlab==3.6.12

# Instalar dependências do sistema que podem ser necessárias para o ReportLab
docker-compose exec api apt-get update && apt-get install -y --no-install-recommends libjpeg-dev zlib1g-dev

# Reinstalar o ReportLab após instalar as dependências do sistema
docker-compose exec api pip install --no-cache-dir reportlab==3.6.12
```

#### 8.1.2 Verificação Completa de Dependências

```bash
# Verificar todas as dependências críticas
docker-compose exec api python -c "\
import sys; \
print(f'Python {sys.version}'); \
try: \
    import reportlab; print(f'✅ ReportLab {reportlab.__version__}'); \
except ImportError: \
    print('❌ ReportLab não instalado'); \
try: \
    import fastapi; print(f'✅ FastAPI {fastapi.__version__}'); \
except ImportError: \
    print('❌ FastAPI não instalado'); \
try: \
    import sqlalchemy; print(f'✅ SQLAlchemy {sqlalchemy.__version__}'); \
except ImportError: \
    print('❌ SQLAlchemy não instalado'); \
try: \
    import pandas; print(f'✅ Pandas {pandas.__version__}'); \
except ImportError: \
    print('❌ Pandas não instalado'); \
try: \
    import openai; print(f'✅ OpenAI {openai.__version__}'); \
except ImportError: \
    print('❌ OpenAI não instalado'); \
"
```

#### 8.1.3 Reconstrução do Container com Flags Adicionais

Se os problemas persistirem, tente reconstruir o container com flags adicionais:

```bash
# Parar e remover containers existentes
docker-compose down

# Reconstruir com flags adicionais para depuração
docker-compose build --no-cache --progress=plain api

# Iniciar novamente
docker-compose up -d
```

### 8.2 Problemas de Conexão entre Containers

#### 8.2.1 Verificação de Comunicação entre Containers

A comunicação adequada entre os containers é essencial para o funcionamento correto do sistema. Utilize os comandos abaixo para diagnosticar problemas de comunicação:

```bash
# Verificar se todos os containers estão em execução
docker-compose ps

# Verificar logs para identificar problemas
docker-compose logs api | tail -n 50

# Verificar rede Docker
docker network inspect rfminsights-network

# Testar comunicação entre nginx-proxy e api
echo "Testando comunicação interna entre nginx-proxy e api..."
docker-compose exec nginx-proxy curl -I http://api:8000/health

# Testar comunicação entre api e banco de dados
docker-compose exec api python -c "import os; from sqlalchemy import create_engine; engine = create_engine(os.getenv('DATABASE_URL')); conn = engine.connect(); print('✅ Conexão com o banco de dados bem-sucedida'); conn.close()" || echo "❌ Falha na conexão com o banco de dados"
```

#### 8.2.2 Resolução de Problemas de Comunicação

Se encontrar problemas de comunicação entre containers, tente as seguintes soluções:

1. **Reiniciar os containers com problemas**:
   ```bash
   docker-compose restart api nginx-proxy
   ```

2. **Verificar se os serviços estão prontos antes de tentar acessá-los**:
   ```bash
   # Verificar se a API está respondendo
   until docker-compose exec api curl -f http://localhost:8000/health 2>/dev/null; do
     echo "Aguardando API inicializar..."
     sleep 5
   done
   echo "✅ API está pronta!"
   ```

3. **Verificar configurações de rede**:
   ```bash
   # Listar todas as redes Docker
   docker network ls
   
   # Inspecionar a rede do RFM Insights
   docker network inspect rfminsights-network
   ```

4. **Verificar resolução de nomes**:
   ```bash
   # Testar resolução de nomes dentro do container nginx-proxy
   docker-compose exec nginx-proxy ping -c 3 api
   docker-compose exec nginx-proxy ping -c 3 postgres
   ```

5. **Verificar portas expostas**:
   ```bash
   # Listar todas as portas em uso
   docker-compose ps
   ```

### 8.3 Problemas de Permissão

```bash
# Corrigir permissões de arquivos
docker-compose exec api chmod -R 755 /app

# Verificar proprietário dos arquivos
docker-compose exec api ls -la /app
```

### 8.4 Diagnóstico Pós-Instalação

Após a instalação, é importante verificar se todos os serviços estão funcionando corretamente. Utilize os comandos abaixo para diagnosticar o estado atual do sistema:

#### 8.4.1 Verificar Status dos Containers

```bash
# Verificar o status de todos os containers
docker-compose ps
```

Este comando mostrará o status de todos os containers, incluindo se estão em execução, parados ou com problemas. Todos os serviços devem estar com o status "Up".

#### 8.4.2 Verificar Logs da API

```bash
# Verificar logs do serviço da API
docker-compose logs api
```

Analise os logs para identificar possíveis erros ou avisos. Procure por mensagens de erro como "Error", "Exception" ou "Failed".

#### 8.4.3 Verificar Logs do Nginx Proxy

```bash
# Verificar logs do serviço nginx-proxy
docker-compose logs nginx-proxy
```

Verifique se há erros de conexão ou problemas de configuração no proxy reverso.

#### 8.4.4 Verificar Pacotes Python Instalados

```bash
# Listar todos os pacotes Python instalados no container da API
docker-compose exec api pip list
```

Confirme se todos os pacotes necessários estão instalados e com as versões corretas.

#### 8.4.5 Reinicialização de Serviços

Se algum serviço não estiver funcionando corretamente, você pode forçar uma reinicialização:

```bash
# Reiniciar um serviço específico (substitua SERVIÇO pelo nome do serviço)
docker-compose restart SERVIÇO

# Exemplos:
docker-compose restart api
docker-compose restart nginx-proxy
docker-compose restart postgres
```

Para casos mais graves, você pode reiniciar todo o ambiente:

```bash
# Parar todos os containers
docker-compose down

# Iniciar todos os containers novamente
docker-compose up -d
```

#### 8.4.6 Verificação Completa do Sistema

Para uma verificação completa do sistema, execute a seguinte sequência de comandos:

```bash
# 1. Verificar status de todos os containers
docker-compose ps

# 2. Verificar logs recentes da API
docker-compose logs --tail=50 api

# 3. Verificar logs recentes do nginx-proxy
docker-compose logs --tail=50 nginx-proxy

# 4. Verificar dependências críticas
docker-compose exec api pip list | grep -E "reportlab|fastapi|uvicorn|sqlalchemy|openai|pandas"

# 5. Verificar conexão com o banco de dados
docker-compose exec api python -c "import os; from sqlalchemy import create_engine; engine = create_engine(os.getenv('DATABASE_URL')); conn = engine.connect(); print('✅ Conexão com o banco de dados bem-sucedida'); conn.close()" || echo "❌ Falha na conexão com o banco de dados"

# 6. Verificar endpoint de saúde da API
docker-compose exec api curl -f http://localhost:8000/health || echo "❌ API não está respondendo corretamente"
```

#### 8.4.7 Diagnóstico para Windows (PowerShell)

```powershell
# 1. Verificar status de todos os containers
docker-compose ps

# 2. Verificar logs recentes da API
docker-compose logs --tail=50 api

# 3. Verificar logs recentes do nginx-proxy
docker-compose logs --tail=50 nginx-proxy

# 4. Verificar dependências críticas
docker-compose exec api pip list

# 5. Verificar endpoint de saúde da API
docker-compose exec api curl -f http://localhost:8000/health
```