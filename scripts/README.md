# RFM Insights - Scripts de Instalação Aprimorados

Este diretório contém scripts aprimorados para a instalação do RFM Insights, corrigindo diversos problemas encontrados no processo de instalação original.

## Problemas Corrigidos

1. **Avisos de Depreciação do apt-key**
   - Substituído o método antigo `apt-key add` pelo método moderno usando `/etc/apt/keyrings`
   - Eliminado o aviso: `Warning: apt-key is deprecated. Manage keyring files in trusted.gpg.d instead`

2. **Problemas com Arquivos .env**
   - Corrigido o erro: `cp: cannot stat '.env.example': No such file or directory`
   - Adicionada verificação da existência dos arquivos antes de copiá-los
   - Criação automática dos arquivos .env e .env.monitoring caso não existam

3. **Problemas com Certificados SSL**
   - Melhorada a geração de certificados SSL autoassinados
   - Adicionadas instruções claras para configuração de certificados Let's Encrypt
   - Corrigidas as permissões dos arquivos de certificado

4. **Hierarquia de Arquivos**
   - Reorganizada a estrutura de diretórios para garantir consistência
   - Corrigidos caminhos absolutos em todos os scripts
   - Melhorada a cópia de arquivos do projeto para o diretório de instalação

## Scripts Disponíveis

### 1. `install.sh`

Script principal que realiza a primeira parte da instalação:
- Atualiza o sistema
- Instala dependências
- Configura o Docker usando o método moderno (sem apt-key)
- Cria a estrutura de diretórios
- Copia os arquivos do projeto

### 2. `install_part2.sh`

Continuação do script de instalação:
- Cria o arquivo docker-compose.yml
- Configura o Nginx
- Gera certificados SSL autoassinados
- Inicia os serviços

### 3. `install_part3.sh`

Finalização da instalação:
- Cria scripts de verificação de saúde
- Configura backup automático
- Adiciona scripts ao crontab
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