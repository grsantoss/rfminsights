# Configurações de Segurança para Nginx

Este documento contém as configurações de segurança recomendadas para o servidor Nginx do RFM Insights.

## Headers de Segurança

Adicione as seguintes configurações ao bloco `server` nos arquivos de configuração do Nginx:

```nginx
# Configurações de segurança básicas
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;

# Strict Transport Security (HSTS)
# Força o uso de HTTPS por 6 meses (15768000 segundos)
add_header Strict-Transport-Security "max-age=15768000; includeSubDomains" always;

# Content Security Policy (CSP)
# Ajuste conforme necessário para permitir recursos específicos
add_header Content-Security-Policy "default-src 'self'; script-src 'self' https://cdn.jsdelivr.net; style-src 'self' https://cdn.jsdelivr.net; img-src 'self' data:; font-src 'self'; connect-src 'self' https://api.rfminsights.com.br; frame-ancestors 'none';" always;

# Desabilitar exibição da versão do Nginx
server_tokens off;
```

## Configurações SSL/TLS

Adicione ou atualize as seguintes configurações no bloco `http` do arquivo `nginx.conf`:

```nginx
# SSL/TLS settings
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;
```

## Limitação de Taxa (Rate Limiting)

Adicione as seguintes configurações ao bloco `http` para limitar requisições:

```nginx
# Definir zonas de limitação
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=auth_limit:10m rate=5r/m;

# Aplicar limitação no bloco server para endpoints de autenticação
location ~ ^/api/auth/ {
    limit_req zone=auth_limit burst=10 nodelay;
    proxy_pass http://api:8000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}

# Aplicar limitação geral para a API
location /api/ {
    limit_req zone=api_limit burst=20;
    proxy_pass http://api:8000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

## Proteção contra Ataques Comuns

Adicione as seguintes configurações para proteção contra ataques comuns:

```nginx
# Tamanho máximo do corpo da requisição
client_max_body_size 10M;

# Timeout settings
client_body_timeout 10s;
client_header_timeout 10s;
keepalive_timeout 65s;
send_timeout 10s;

# Buffer settings
client_body_buffer_size 128k;
client_header_buffer_size 1k;
large_client_header_buffers 4 4k;
```

## Implementação

Para implementar estas configurações:

1. Edite o arquivo `nginx.conf` principal para adicionar as configurações globais
2. Atualize os arquivos de configuração específicos dos sites em `conf.d/`
3. Teste a configuração com `nginx -t`
4. Reinicie o Nginx com `nginx -s reload`

Estas configurações aumentarão significativamente a segurança da sua instalação do RFM Insights.