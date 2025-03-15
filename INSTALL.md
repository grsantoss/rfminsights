# RFM Insights - Guia de Instalação

Este guia fornece instruções detalhadas para instalar o RFM Insights, abordando problemas comuns de instalação e configuração.

## Pré-requisitos

- Docker e Docker Compose instalados
- Git (para clonar o repositório)
- Acesso à internet para baixar imagens Docker
- OpenSSL (para geração de certificados SSL)

## Instalação Passo a Passo

### 1. Clonar o Repositório

```bash
git clone https://github.com/seu-usuario/rfminsights.git
cd rfminsights
```

### 2. Configurar o Ambiente

Execute o script de configuração de ambiente que irá:
- Verificar dependências
- Criar diretórios necessários
- Gerar certificados SSL autoassinados
- Configurar o arquivo .env

#### No Linux/macOS:

```bash
chmod +x ./scripts/setup_environment.sh
./scripts/setup_environment.sh
```

#### No Windows (PowerShell):

```powershell
.\install.ps1
```

### 3. Configurar Certificados SSL

Os certificados SSL são gerados automaticamente pelo script de configuração, mas você pode personalizá-los:

#### No Linux/macOS:

```bash
chmod +x ./scripts/ssl_setup.sh
./scripts/ssl_setup.sh
```

#### No Windows (PowerShell):

```powershell
.\scripts\ssl_setup.ps1
```

### 4. Configurar API Keys (Opcional)

Para utilizar os recursos de IA, você precisa configurar uma chave de API do OpenAI:

1. Obtenha uma chave de API em https://platform.openai.com/api-keys
2. Edite o arquivo `.env` e adicione sua chave:

```
OPENAI_API_KEY=sua-chave-api-aqui
```

**Nota:** A aplicação funcionará sem a chave da OpenAI, mas os recursos de IA não estarão disponíveis.

### 5. Iniciar a Aplicação

```bash
docker-compose up -d
```

## Solução de Problemas Comuns

### Problema de Conexão com o Banco de Dados

Se estiver executando componentes fora do Docker, a conexão com o banco de dados pode falhar. O sistema agora detecta automaticamente se está rodando dentro ou fora do Docker e ajusta a string de conexão.

Para forçar uma conexão local, edite o arquivo `.env`:

```
DATABASE_URL=postgresql://rfminsights:rfminsights_password@localhost/rfminsights
```

### Certificados SSL

Se os certificados SSL não forem gerados automaticamente:

```bash
# Gerar certificados manualmente
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ./nginx/ssl/server.key \
    -out ./nginx/ssl/server.crt \
    -subj "/C=BR/ST=Sao Paulo/L=Sao Paulo/O=RFM Insights/OU=IT/CN=app.rfminsights.com.br"
```

### Configuração do Nginx

Se o frontend não carregar corretamente, verifique se o arquivo `nginx/frontend.conf` existe e está configurado corretamente.

## Verificação da Instalação

Após a instalação, acesse:

- Frontend: http://localhost ou https://app.rfminsights.com.br (se configurado no hosts)
- API: http://localhost:8000 ou https://api.rfminsights.com.br (se configurado no hosts)

## Suporte

Para obter ajuda adicional, entre em contato com nossa equipe de suporte.