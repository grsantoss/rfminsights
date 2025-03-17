# RFM Insights - Guia de Instalação

Este guia fornece instruções detalhadas para instalar o RFM Insights, abordando problemas comuns de instalação e configuração.

## Instalação Rápida

Para uma instalação rápida e simplificada, utilize os scripts de instalação automática:

### Windows

```powershell
# Execute no PowerShell como administrador
.\install.ps1
```

### macOS

```bash
# Execute no Terminal
chmod +x ./install.sh
./install.sh
```

### Linux

```bash
# Execute no Terminal com privilégios de superusuário
chmod +x ./install.sh
./install.sh
```

O script de instalação automática irá:
1. Verificar os pré-requisitos do sistema
2. Instalar dependências necessárias (se faltantes)
3. Configurar o ambiente Docker
4. Configurar o banco de dados PostgreSQL
5. Configurar o Nginx e certificados SSL
6. Iniciar todos os serviços
7. Verificar a instalação

## Verificação da Instalação

Após a instalação, você pode verificar se tudo está funcionando corretamente usando o script de verificação de saúde:

```bash
./scripts/health_check.sh
```

Este script irá verificar:
- Status dos containers Docker
- Saúde da API
- Disponibilidade dos serviços

## Pré-requisitos

- Docker e Docker Compose instalados
- Git (para clonar o repositório)
- Acesso à internet para baixar imagens Docker
- OpenSSL (para geração de certificados SSL)

## Instalação do Docker

O RFM Insights utiliza Docker para facilitar a instalação e execução. Siga as instruções abaixo para instalar o Docker em seu sistema operacional.

### Windows

1. Baixe o Docker Desktop para Windows no [site oficial](https://www.docker.com/products/docker-desktop)
2. Execute o instalador e siga as instruções na tela
3. Certifique-se de que a virtualização esteja habilitada no BIOS/UEFI do seu sistema
4. Após a instalação, inicie o Docker Desktop
5. Verifique a instalação abrindo um terminal PowerShell e executando:
   ```powershell
   docker --version
   docker-compose --version
   ```

### macOS

1. Baixe o Docker Desktop para Mac no [site oficial](https://www.docker.com/products/docker-desktop)
2. Arraste o aplicativo Docker para a pasta Aplicativos
3. Inicie o Docker a partir da pasta Aplicativos
4. Verifique a instalação abrindo um terminal e executando:
   ```bash
   docker --version
   docker-compose --version
   ```

### Linux (Ubuntu/Debian)

1. Atualize os pacotes do sistema:
   ```bash
   sudo apt update
   sudo apt upgrade -y
   ```

2. Instale os pacotes necessários:
   ```bash
   sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
   ```

3. Adicione a chave GPG oficial do Docker:
   ```bash
   curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
   ```

4. Adicione o repositório do Docker:
   ```bash
   sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
   ```

5. Atualize os pacotes novamente e instale o Docker:
   ```bash
   sudo apt update
   sudo apt install -y docker-ce docker-ce-cli containerd.io
   ```

6. Adicione seu usuário ao grupo docker para executar comandos sem sudo:
   ```bash
   sudo usermod -aG docker $USER
   ```
   (Faça logout e login novamente para aplicar as alterações)

7. Instale o Docker Compose:
   ```bash
   sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   ```

8. Verifique a instalação:
   ```bash
   docker --version
   docker-compose --version
   ```

### Verificação da Instalação do Docker

Para verificar se o Docker está funcionando corretamente, execute:

```bash
docker run hello-world
```

Você deve ver uma mensagem de confirmação indicando que o Docker está instalado e funcionando corretamente.

## Instalação Passo a Passo (Manual)

Se preferir realizar a instalação manualmente, siga estas etapas:

### 1. Clonar o Repositório

```bash
# Clone o repositório oficial do RFM Insights
git clone https://github.com/rfminsights/rfminsights.git

# Navegue para o diretório do projeto
cd rfminsights
```

### 2. Instalação Usando Módulos Individuais

O RFM Insights possui scripts modulares que permitem uma instalação passo a passo, oferecendo maior controle sobre o processo de instalação. Cada módulo é responsável por uma parte específica da configuração.

#### No Linux/macOS:

Primeiro, torne todos os scripts executáveis:

```bash
# Tornar todos os scripts executáveis
chmod +x ./scripts/modules/*.sh
```

Em seguida, execute cada módulo na sequência correta:

```bash
# 1. Verificação do ambiente
./scripts/modules/01-environment-check.sh

# 2. Instalação de dependências
./scripts/modules/02-dependencies.sh

# 3. Configuração do Docker
./scripts/modules/03-docker-setup.sh

# 4. Configuração do banco de dados
./scripts/modules/04-database-setup.sh

# 5. Configuração de certificados SSL
./scripts/modules/05-ssl-setup.sh

# 6. Finalização da instalação
./scripts/modules/06-final-setup.sh
```

#### No Windows (PowerShell):

Execute cada módulo na sequência correta:

```powershell
# 1. Verificação do ambiente
.\scripts\modules\01-environment-check.ps1

# 2. Instalação de dependências
.\scripts\modules\02-dependencies.ps1

# 3. Configuração do Docker
.\scripts\modules\03-docker-setup.ps1

# 4. Configuração do banco de dados
.\scripts\modules\04-database-setup.ps1

# 5. Configuração do Nginx
.\scripts\modules\05-nginx-setup.ps1

# 6. Configuração de certificados SSL
.\scripts\modules\06-ssl-setup.ps1

# 7. Finalização da instalação
.\scripts\modules\07-final-setup.ps1
```

### 3. Descrição dos Módulos de Instalação

Cada módulo de instalação tem uma função específica:

1. **Verificação do Ambiente**: Verifica os pré-requisitos do sistema e prepara o ambiente para instalação.
2. **Instalação de Dependências**: Instala todas as dependências necessárias, incluindo Docker e Docker Compose.
3. **Configuração do Docker**: Configura os containers Docker necessários para a aplicação.
4. **Configuração do Banco de Dados**: Configura o banco de dados PostgreSQL e executa migrações iniciais.
5. **Configuração do Nginx/SSL**: Configura o servidor web Nginx e gera certificados SSL autoassinados.
6. **Finalização da Instalação**: Verifica se todos os componentes estão funcionando corretamente e inicia os serviços.

### 4. Configuração Alternativa (Script de Ambiente)

Alternativamente, você pode usar o script de configuração de ambiente que automatiza parte do processo:

#### No Linux/macOS:

```bash
chmod +x ./scripts/setup_environment.sh
./scripts/setup_environment.sh
```

#### No Windows (PowerShell):

```powershell
.\scripts\install_modular.ps1
```

### 6. Configurar API Keys (Opcional)

Para utilizar os recursos de IA, você precisa configurar uma chave de API do OpenAI:

1. Obtenha uma chave de API em https://platform.openai.com/api-keys
2. Edite o arquivo `.env` e adicione sua chave:

```
OPENAI_API_KEY=sua-chave-api-aqui
```

**Nota:** A aplicação funcionará sem a chave da OpenAI, mas os recursos de IA não estarão disponíveis.

### 7. Iniciar a Aplicação

Se você seguiu a instalação manual e ainda não iniciou os containers:

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

### Containers Docker não Iniciam

Se os containers não iniciarem corretamente:

1. Verifique se o Docker está em execução
2. Verifique os logs dos containers:
   ```bash
   docker-compose logs
   ```
3. Tente reiniciar os containers:
   ```bash
   docker-compose down
   docker-compose up -d
   ```

### Configuração do Nginx

Se o frontend não carregar corretamente, verifique se o arquivo `nginx/frontend.conf` existe e está configurado corretamente.

## Acessando a Aplicação

Após a instalação, acesse:

- Frontend: https://localhost ou https://app.rfminsights.com.br (se configurado no hosts)
- API: https://localhost:8000 ou https://api.rfminsights.com.br (se configurado no hosts)

## Suporte

Para obter ajuda adicional, entre em contato com nossa equipe de suporte.