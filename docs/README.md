# RFM Insights - Documentação Técnica

Este diretório contém a documentação técnica detalhada do projeto RFM Insights. Para uma visão geral do projeto, consulte o [README.md](../README.md) na raiz do projeto.

## Documentação Disponível

- [Configuração SSL](SSL_SETUP.md): Instruções detalhadas para configurar certificados SSL no RFM Insights
- [Segurança do Nginx](nginx_security.md): Configurações recomendadas de segurança para o servidor Nginx

## Fluxo de Dados

1. O usuário interage com a interface frontend
2. As requisições são enviadas para os endpoints da API
3. O backend processa os dados e realiza análises RFM
4. Os resultados são retornados para o frontend
5. O frontend apresenta os insights ao usuário

## Arquitetura do Sistema

### Backend (FastAPI)

O backend é construído com FastAPI e oferece os seguintes endpoints principais:

- `/api/auth/*`: Endpoints de autenticação e gerenciamento de usuários
- `/api/rfm/*`: Endpoints para análise RFM e geração de insights
- `/api/marketplace/*`: Endpoints para integração com o marketplace

### Frontend

O frontend é construído com HTML, CSS e JavaScript puro, organizados em componentes reutilizáveis:

- Componentes de UI compartilhados (header, sidebar)
- Módulos específicos de funcionalidade (análise, dashboard, marketplace)
- Utilitários de cliente API e gerenciamento de estado

### Banco de Dados

O sistema utiliza PostgreSQL como banco de dados principal, com migrações gerenciadas pelo Alembic.

## Configuração do Ambiente de Desenvolvimento

Para configurar um ambiente de desenvolvimento local:

1. Clone o repositório
2. Copie `.env.example` para `.env` e configure as variáveis
3. Instale as dependências com `pip install -r requirements.txt`
4. Execute as migrações com `python -m backend.migrations --init`
5. Inicie o servidor com `python main.py`

## Contribuição

Ao contribuir com o projeto, siga estas diretrizes:

1. Mantenha a estrutura de diretórios existente
2. Documente novas funcionalidades
3. Adicione testes para novas funcionalidades
4. Siga as convenções de código existentes