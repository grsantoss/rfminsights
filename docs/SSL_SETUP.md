# Configuração de Certificados SSL para o RFM Insights

Este guia fornece instruções detalhadas para configurar certificados SSL no RFM Insights, tanto para ambientes de desenvolvimento quanto de produção.

## 1. Estrutura de Diretórios

Antes de configurar os certificados SSL, é necessário garantir que a estrutura de diretórios esteja corretamente configurada:

### No Windows

```powershell
# Execute o script para criar a estrutura de diretórios
.\scripts\create_nginx_structure.ps1
```

Este script criará a seguinte estrutura:

```
%USERPROFILE%\rfminsights\nginx\ssl\  # Diretório para certificados SSL
%USERPROFILE%\rfminsights\nginx\conf.d\  # Configurações do Nginx
%USERPROFILE%\rfminsights\nginx\logs\  # Logs do Nginx
```

### No Linux

```bash
# Criar estrutura de diretórios
mkdir -p ~/rfminsights/nginx/{conf.d,ssl,logs}
```

## 2. Configuração de Certificados SSL

### 2.1 Ambiente de Desenvolvimento (Certificados Autoassinados)

#### No Windows

```powershell
# Execute o script de configuração SSL
.\scripts\ssl_setup.ps1
```

Escolha a opção 1 para gerar certificados autoassinados. O script irá:
1. Criar certificados para o frontend (app.rfminsights.com.br)
2. Criar certificados para a API (api.rfminsights.com.br)
3. Verificar a validade dos certificados

#### No Linux

```bash
# Execute o script de configuração SSL
bash ./scripts/ssl_setup.sh
```

Escolha a opção 1 para gerar certificados autoassinados.

### 2.2 Ambiente de Produção (Let's Encrypt)

#### No Linux

```bash
# Execute o script de configuração SSL
bash ./scripts/ssl_setup.sh
```

Escolha a opção 2 para configurar certificados Let's Encrypt. O script irá:
1. Instalar o Certbot
2. Obter certificados para seus domínios
3. Configurar a renovação automática

## 3. Verificação de Certificados

Para verificar se os certificados foram corretamente instalados:

### No Windows

```powershell
# Execute o script de configuração SSL
.\scripts\ssl_setup.ps1
```

Escolha a opção 3 para verificar os certificados existentes.

### No Linux

```bash
# Execute o script de configuração SSL
bash ./scripts/ssl_setup.sh
```

Escolha a opção 3 para verificar os certificados existentes.

## 4. Solução de Problemas

### 4.1 Permissões de Certificados

Se encontrar problemas de permissão com os certificados no Linux:

```bash
# Ajustar permissões
sudo chmod 644 ~/rfminsights/nginx/ssl/*.crt
sudo chmod 600 ~/rfminsights/nginx/ssl/*.key

# Reiniciar o Nginx
docker-compose restart nginx-proxy
```

### 4.2 Certificados Não Encontrados

Se o Nginx não conseguir encontrar os certificados:

1. Verifique se os certificados existem no diretório correto:
   - Windows: `%USERPROFILE%\rfminsights\nginx\ssl\`
   - Linux: `~/rfminsights/nginx/ssl/`

2. Verifique se os nomes dos arquivos estão corretos:
   - Frontend: `frontend.crt` e `frontend.key`
   - API: `api.crt` e `api.key`

3. Regenere os certificados usando os scripts fornecidos.

### 4.3 OpenSSL não encontrado (Windows)

Se receber um aviso de que o OpenSSL não foi encontrado no Windows:

1. Instale o OpenSSL para Windows: https://slproweb.com/products/Win32OpenSSL.html
2. Adicione o diretório bin do OpenSSL ao PATH do sistema
3. Execute novamente o script de configuração SSL

## 5. Configuração no Docker Compose

Certifique-se de que o arquivo `docker-compose.yml` inclua o mapeamento correto para os certificados SSL:

```yaml
nginx-proxy:
  volumes:
    - ./nginx/ssl:/etc/nginx/ssl
```

E que os arquivos de configuração do Nginx referenciem os certificados corretamente:

```nginx
# Para o frontend
ssl_certificate /etc/nginx/ssl/frontend.crt;
ssl_certificate_key /etc/nginx/ssl/frontend.key;

# Para a API
ssl_certificate /etc/nginx/ssl/api.crt;
ssl_certificate_key /etc/nginx/ssl/api.key;
```