# RFM Insights - Database Migrations

Este diretório contém as migrações de banco de dados para o projeto RFM Insights, gerenciadas pelo Alembic.

## Estrutura

- `env.py`: Configuração do ambiente Alembic
- `script.py.mako`: Template para novos scripts de migração
- `versions/`: Diretório contendo os scripts de migração versionados

## Comandos Comuns

### Inicializar o Banco de Dados

```bash
# Aplicar todas as migrações
alembic upgrade head
```

### Criar Nova Migração

```bash
# Gerar automaticamente uma migração baseada nas alterações nos modelos
alembic revision --autogenerate -m "descrição da migração"

# Criar uma migração vazia
alembic revision -m "descrição da migração"
```

### Atualizar o Banco de Dados

```bash
# Atualizar para a versão mais recente
alembic upgrade head

# Atualizar para uma versão específica
alembic upgrade <revision_id>

# Atualizar N versões à frente
alembic upgrade +N
```

### Reverter Migrações

```bash
# Reverter para a versão anterior
alembic downgrade -1

# Reverter para uma versão específica
alembic downgrade <revision_id>

# Reverter todas as migrações
alembic downgrade base
```

### Verificar Status

```bash
# Mostrar o histórico de migrações
alembic history

# Verificar a versão atual
alembic current
```

## Boas Práticas

1. **Sempre teste as migrações** em um ambiente de desenvolvimento antes de aplicá-las em produção
2. **Nunca edite migrações já aplicadas** em ambientes compartilhados
3. **Inclua operações de downgrade** para permitir a reversão de alterações
4. **Use mensagens descritivas** ao criar novas migrações
5. **Faça backup do banco de dados** antes de aplicar migrações em produção

## Resolução de Problemas

Se encontrar problemas ao executar migrações:

1. Verifique se o banco de dados está acessível
2. Confirme que as credenciais estão corretas no arquivo de configuração
3. Verifique se há conflitos entre migrações
4. Consulte os logs para mensagens de erro detalhadas