# RFM Insights - Documentação

## Estrutura do Projeto

O projeto RFM Insights está organizado nas seguintes pastas:

### `/backend`

Contém todos os arquivos relacionados ao backend da aplicação:

- `__init__.py`: Inicialização do pacote backend
- `auth.py`: Funções de autenticação
- `auth_routes.py`: Rotas de API para autenticação
- `database.py`: Configuração da conexão com o banco de dados
- `marketplace.py`: Implementação da API do marketplace
- `migrations.py`: Scripts para migração do banco de dados
- `models.py`: Modelos de dados SQLAlchemy
- `rfm_analysis.py`: Lógica de análise RFM
- `rfm_api.py`: Endpoints da API para análise RFM

### `/config`

Contém arquivos de configuração do projeto:

- `__init__.py`: Inicialização do pacote de configuração
- `config.py`: Configurações globais da aplicação

### `/frontend`

Contém todos os arquivos relacionados à interface do usuário:

- Arquivos HTML: Páginas da aplicação
- Arquivos JavaScript: Lógica do cliente
- Arquivos CSS: Estilos da aplicação

### `/docs`

Contém a documentação do projeto.

## Arquivos na Raiz

- `main.py`: Ponto de entrada da aplicação
- `Dockerfile`: Configuração para containerização
- `requirements.txt`: Dependências Python
- `.env.example`: Exemplo de variáveis de ambiente
- `__init__.py`: Inicialização do pacote principal

## Fluxo de Dados

1. O usuário interage com a interface frontend
2. As requisições são enviadas para os endpoints da API
3. O backend processa os dados e realiza análises RFM
4. Os resultados são retornados para o frontend
5. O frontend apresenta os insights ao usuário

## Configuração do Ambiente

Para configurar o ambiente de desenvolvimento:

1. Clone o repositório
2. Copie `.env.example` para `.env` e configure as variáveis
3. Instale as dependências com `pip install -r requirements.txt`
4. Execute as migrações com `python -m backend.migrations --init`
5. Inicie o servidor com `python main.py`