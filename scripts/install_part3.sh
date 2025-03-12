#!/bin/bash

# RFM Insights - Script de Instalação (Parte 3)
# Este script deve ser executado após install_part2.sh

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

# Verificar se está sendo executado como root
if [ "$(id -u)" != "0" ]; then
    error "Este script deve ser executado como root (sudo)."
    exit 1
fi

# Definir diretório de instalação
INSTALL_DIR="/opt/rfminsights"
cd "$INSTALL_DIR" || exit 1

# Continuar a criação do script de verificação de saúde
log "Continuando a criação do script de verificação de saúde..."
cat >> "$INSTALL_DIR/health_check.sh" << 'EOL'
viços...${NC}"

# Verificar status dos contêineres
echo "Verificando status dos contêineres..."
docker ps | grep rfminsights

# Verificar API
echo -e "\nVerificando API..."
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -k https://api.rfminsights.com.br/ 2>/dev/null || echo "Falha")
if [ "$API_STATUS" == "200" ] || [ "$API_STATUS" == "401" ]; then
    echo -e "${GREEN}API está funcionando (status: $API_STATUS)${NC}"
else
    echo -e "${RED}ERRO: API não está respondendo corretamente (status: $API_STATUS)${NC}"
fi

# Verificar Frontend
echo -e "\nVerificando Frontend..."
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -k https://app.rfminsights.com.br/ 2>/dev/null || echo "Falha")
if [ "$FRONTEND_STATUS" == "200" ]; then
    echo -e "${GREEN}Frontend está funcionando (status: $FRONTEND_STATUS)${NC}"
else
    echo -e "${RED}ERRO: Frontend não está respondendo corretamente (status: $FRONTEND_STATUS)${NC}"
fi

# Verificar Banco de Dados
echo -e "\nVerificando Banco de Dados..."
DB_STATUS=$(docker exec rfminsights-postgres pg_isready -U rfminsights 2>/dev/null || echo "Falha")
echo -e "Status do banco de dados: $DB_STATUS"

# Verificar uso de recursos
echo -e "\nVerificando uso de recursos..."
docker stats --no-stream rfminsights-api rfminsights-frontend rfminsights-postgres rfminsights-nginx-proxy
EOL
chmod +x "$INSTALL_DIR/health_check.sh"
log "Script de verificação de saúde criado"

# Criar script de backup
log "Criando script de backup..."
cat > "$INSTALL_DIR/backup.sh" << 'EOL'
#!/bin/bash

# Definir cores para saída
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
BACKUP_DIR="/opt/rfminsights/backups"
DATETIME=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/rfminsights_$DATETIME.sql"

# Criar diretório de backup se não existir
mkdir -p $BACKUP_DIR

# Realizar backup do banco de dados
echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] Realizando backup do banco de dados...${NC}"
docker exec rfminsights-postgres pg_dump -U rfminsights rfminsights > $BACKUP_FILE

# Comprimir arquivo de backup
gzip $BACKUP_FILE

# Manter apenas os últimos 7 backups
echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] Removendo backups antigos...${NC}"
ls -t $BACKUP_DIR/rfminsights_*.sql.gz | tail -n +8 | xargs -r rm

echo -e "${GREEN}[SUCESSO] Backup concluído: ${BACKUP_FILE}.gz${NC}"
EOL
chmod +x "$INSTALL_DIR/backup.sh"
log "Script de backup criado"

# Adicionar scripts ao crontab
log "Configurando execução automática dos scripts..."
(crontab -l 2>/dev/null | grep -v "rfminsights"; echo "0 * * * * /opt/rfminsights/health_check.sh >> /opt/rfminsights/health_check.log 2>&1") | crontab -
(crontab -l 2>/dev/null | grep -v "backup.sh"; echo "0 2 * * * /opt/rfminsights/backup.sh >> /opt/rfminsights/backup.log 2>&1") | crontab -
log "Scripts adicionados ao crontab"

# Criar script de atualização
log "Criando script de atualização..."
cat > "$INSTALL_DIR/update.sh" << 'EOL'
#!/bin/bash

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

# Verificar se está sendo executado como root
if [ "$(id -u)" != "0" ]; then
    error "Este script deve ser executado como root (sudo)."
    exit 1
fi

# Definir diretório de instalação
INSTALL_DIR="/opt/rfminsights"
cd "$INSTALL_DIR" || exit 1

# Realizar backup antes da atualização
log "Realizando backup antes da atualização..."
./backup.sh

# Atualizar código do repositório
log "Atualizando código do repositório..."
cd "$INSTALL_DIR/app"
git pull origin main || warning "Não foi possível atualizar o código do repositório. Continuando com a atualização dos contêineres."

# Reconstruir e reiniciar contêineres
log "Reconstruindo e reiniciando contêineres..."
cd "$INSTALL_DIR"
docker compose down
docker compose build
docker compose up -d
success "Contêineres atualizados e reiniciados"

# Verificar status após atualização
log "Verificando status após atualização..."
sleep 10
./health_check.sh

success "Atualização concluída com sucesso!"
EOL
chmod +x "$INSTALL_DIR/update.sh"
log "Script de atualização criado"

# Criar arquivo README com instruções
log "Criando arquivo README com instruções..."
cat > "$INSTALL_DIR/README.md" << 'EOL'
# RFM Insights - Instruções de Instalação e Manutenção

## Visão Geral

O RFM Insights é uma aplicação para análise de clientes utilizando a metodologia RFM (Recência, Frequência e Valor Monetário). Esta instalação inclui:

- API backend (Python/FastAPI)
- Frontend (HTML/JavaScript)
- Banco de dados PostgreSQL
- Proxy reverso Nginx
- Portainer para gerenciamento de contêineres

## Estrutura de Diretórios

```
/opt/rfminsights/
├── app/                  # Código-fonte da aplicação
├── backups/              # Backups do banco de dados
├── data/                 # Dados persistentes
├── nginx/                # Configurações do Nginx
│   ├── conf.d/           # Configurações de sites
│   ├── ssl/              # Certificados SSL
│   └── logs/             # Logs do Nginx
├── backup.sh             # Script de backup
├── health_check.sh       # Script de verificação de saúde
├── update.sh             # Script de atualização
└── docker-compose.yml    # Configuração dos contêineres
```

## Scripts Disponíveis

### Verificação de Saúde

O script `health_check.sh` verifica o status dos serviços e é executado automaticamente a cada hora.

```bash
sudo /opt/rfminsights/health_check.sh
```

### Backup do Banco de Dados

O script `backup.sh` realiza backup do banco de dados e é executado automaticamente às 2h da manhã.

```bash
sudo /opt/rfminsights/backup.sh
```

### Atualização da Aplicação

O script `update.sh` atualiza a aplicação para a versão mais recente.

```bash
sudo /opt/rfminsights/update.sh
```

## Acesso aos Serviços

- **Frontend:** https://app.rfminsights.com.br
- **API:** https://api.rfminsights.com.br
- **Portainer:** https://seu-servidor:9443

## Solução de Problemas

### Verificar Logs

```bash
# Logs da API
docker logs rfminsights-api

# Logs do Frontend
docker logs rfminsights-frontend

# Logs do Nginx
docker logs rfminsights-nginx-proxy

# Logs do PostgreSQL
docker logs rfminsights-postgres
```

### Reiniciar Serviços

```bash
# Reiniciar todos os serviços
cd /opt/rfminsights
docker compose restart

# Reiniciar um serviço específico
docker compose restart api
```

### Problemas com Certificados SSL

Se houver problemas com os certificados SSL, você pode regenerá-los:

```bash
# Regenerar certificados autoassinados
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /opt/rfminsights/nginx/ssl/frontend.key \
    -out /opt/rfminsights/nginx/ssl/frontend.crt \
    -subj "/C=BR/ST=Estado/L=Cidade/O=RFMInsights/CN=app.rfminsights.com.br"

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /opt/rfminsights/nginx/ssl/api.key \
    -out /opt/rfminsights/nginx/ssl/api.crt \
    -subj "/C=BR/ST=Estado/L=Cidade/O=RFMInsights/CN=api.rfminsights.com.br"

# Ajustar permissões
sudo chmod 644 /opt/rfminsights/nginx/ssl/*.crt
sudo chmod 600 /opt/rfminsights/nginx/ssl/*.key

# Reiniciar Nginx
docker compose restart nginx-proxy
```

Para certificados Let's Encrypt em produção:

```bash
# Instalar Certbot
sudo apt install -y certbot python3-certbot-nginx

# Obter certificados
sudo certbot --nginx -d app.rfminsights.com.br -d api.rfminsights.com.br

# Copiar certificados
sudo cp /etc/letsencrypt/live/app.rfminsights.com.br/fullchain.pem /opt/rfminsights/nginx/ssl/frontend.crt
sudo cp /etc/letsencrypt/live/app.rfminsights.com.br/privkey.pem /opt/rfminsights/nginx/ssl/frontend.key
sudo cp /etc/letsencrypt/live/api.rfminsights.com.br/fullchain.pem /opt/rfminsights/nginx/ssl/api.crt
sudo cp /etc/letsencrypt/live/api.rfminsights.com.br/privkey.pem /opt/rfminsights/nginx/ssl/api.key

# Ajustar permissões
sudo chmod 644 /opt/rfminsights/nginx/ssl/*.crt
sudo chmod 600 /opt/rfminsights/nginx/ssl/*.key

# Reiniciar Nginx
docker compose restart nginx-proxy
```
EOL
log "Arquivo README criado"

# Criar script de instalação unificado
log "Criando script de instalação unificado..."
cat > "$INSTALL_DIR/install_unified.sh" << 'EOL'
#!/bin/bash