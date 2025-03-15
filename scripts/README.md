# RFM Insights - Scripts de Instalação e Manutenção

Este diretório contém scripts para instalação e manutenção do RFM Insights.

## Scripts Disponíveis

### 1. `install.sh`

Script unificado de instalação para ambientes Linux:
- Atualiza o sistema
- Instala dependências
- Configura o Docker usando o método moderno (sem apt-key)
- Cria a estrutura de diretórios
- Configura o Nginx
- Gera certificados SSL autoassinados
- Inicia os serviços

### 2. `backup.sh`

Script para backup automático do banco de dados:
- Realiza backup do PostgreSQL
- Comprime os arquivos de backup
- Mantém um histórico de backups
- Remove backups antigos conforme configuração

### 3. `db_healthcheck.py`

Script Python para verificar a saúde do banco de dados:
- Verifica a conexão com o PostgreSQL
- Realiza tentativas de reconexão
- Fornece feedback detalhado sobre o status

### 4. `startup.sh`

Script de inicialização para o contêiner Docker:
- Verifica dependências Python
- Instala pacotes faltantes
- Executa verificação de saúde do banco de dados
- Inicia a aplicação

### 5. `ssl_setup.ps1`

Script PowerShell para configuração de SSL em ambientes Windows:
- Gera certificados autoassinados
- Configura certificados Let's Encrypt
- Verifica a validade dos certificados

### 6. `create_nginx_structure.ps1`

Script PowerShell para criar a estrutura de diretórios do Nginx em ambientes Windows:
- Cria diretórios para configurações
- Cria diretórios para certificados SSL
- Cria diretórios para logs
- Cria script de atualização
- Gera documentação

### 4. `install_unified.sh`

Script unificado que combina todas as etapas em um único arquivo para facilitar a instalação.

## Como Usar

### Instalação Completa (Recomendado)

```bash
# Dar permissão de execução ao script
chmod +x install_unified.sh

# Executar o script como root
sudo ./install_unified.sh
```

### Instalação em Etapas

Se preferir instalar em etapas:

```bash
# Etapa 1
chmod +x install.sh
sudo ./install.sh

# Etapa 2
chmod +x install_part2.sh
sudo ./install_part2.sh

# Etapa 3
chmod +x install_part3.sh
sudo ./install_part3.sh
```

## Verificação da Instalação

Após a instalação, verifique se todos os serviços estão funcionando corretamente:

```bash
sudo /opt/rfminsights/health_check.sh
```

## Solução de Problemas

### Problema: Certificados SSL

Se encontrar problemas com os certificados SSL:

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
cd /opt/rfminsights
docker compose restart nginx-proxy
```

### Problema: Arquivos .env não encontrados

Se os arquivos .env não forem encontrados durante a instalação, o script criará automaticamente versões padrão. Você deve editar esses arquivos após a instalação para configurar suas credenciais específicas:

```bash
sudo nano /opt/rfminsights/app/.env
```

### Problema: Erros no Docker

Se encontrar problemas com o Docker:

```bash
# Verificar status do Docker
sudo systemctl status docker

# Reiniciar Docker
sudo systemctl restart docker

# Verificar logs do Docker
sudo journalctl -u docker
```

## Notas Importantes

1. Os scripts foram projetados para Ubuntu 20.04 LTS ou superior.
2. Para ambiente de produção, recomenda-se substituir os certificados autoassinados por certificados válidos do Let's Encrypt.
3. Após a instalação, altere as senhas padrão nos arquivos de configuração.
4. Certifique-se de que os domínios app.rfminsights.com.br e api.rfminsights.com.br estão configurados para apontar para o seu servidor.

## Suporte

Se encontrar problemas durante a instalação, verifique os logs em `/opt/rfminsights/health_check.log` e `/opt/rfminsights/backup.log`.