# RFM Insights

RFM Insights é uma aplicação SaaS para análise RFM (Recência, Frequência, Monetização) que ajuda empresas a segmentar clientes e otimizar estratégias de marketing.

## Visão Geral

O RFM Insights permite que empresas:

- Importem dados de clientes de diversas fontes
- Realizem análises RFM automatizadas
- Visualizem segmentos de clientes em dashboards interativos
- Obtenham insights de marketing baseados em IA
- Integrem com plataformas de marketing existentes

## Estrutura do Projeto

O projeto está organizado nas seguintes pastas:

### `/backend`

Contém todos os arquivos relacionados ao backend da aplicação:

- Autenticação e autorização
- Conexão com banco de dados
- Análise RFM e algoritmos
- APIs e endpoints
- Modelos de dados

### `/frontend`

Contém todos os arquivos relacionados à interface do usuário:

- Páginas HTML
- Scripts JavaScript
- Estilos CSS
- Componentes de UI

### `/config`

Contém arquivos de configuração do projeto.

### `/docs`

Contém documentação técnica detalhada:

- [Configuração SSL](docs/SSL_SETUP.md)
- [Segurança do Nginx](docs/nginx_security.md)

### `/scripts`

Contém scripts de instalação e manutenção:

- Scripts de instalação para Windows e Linux
- Scripts de backup e monitoramento
- Utilitários de manutenção

### `/migrations`

Contém scripts de migração do banco de dados gerenciados pelo Alembic.

## Instalação

Para instruções detalhadas de instalação, consulte o [Guia de Instalação](INSTALL.md).

### Requisitos

- Docker e Docker Compose
- Git
- OpenSSL (para certificados SSL)

### Instalação Rápida

#### Linux/macOS

```bash
chmod +x ./scripts/install.sh
sudo ./scripts/install.sh
```

#### Windows (PowerShell)

```powershell
.\install.ps1
```

## Uso

Após a instalação, acesse:

- Interface web: https://app.rfminsights.com.br
- API: https://api.rfminsights.com.br

## Documentação

Para documentação detalhada sobre:

- Migrações de banco de dados: [migrations/README.md](migrations/README.md)
- Scripts de instalação: [scripts/README.md](scripts/README.md)
- Configuração SSL: [docs/SSL_SETUP.md](docs/SSL_SETUP.md)
- Segurança do Nginx: [docs/nginx_security.md](docs/nginx_security.md)

## Licença

Copyright © 2023 RFM Insights. Todos os direitos reservados.