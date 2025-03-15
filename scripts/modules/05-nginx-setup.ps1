# RFM Insights - Módulo de Configuração do Nginx
# Este módulo configura o Nginx para o RFM Insights

# Configuração do script
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Obter o diretório do script e do projeto
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulesPath = Split-Path -Parent $ScriptPath
$ProjectRoot = Split-Path -Parent $ModulesPath
$LogFile = Join-Path -Path $ProjectRoot -ChildPath "install.log"

# Função para registro de log
function Write-Log {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "Info"    { "White" }
        "Warning" { "Yellow" }
        "Error"   { "Red" }
        "Success" { "Green" }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    
    # Também adiciona ao arquivo de log
    "[$timestamp] [$Level] $Message" | Out-File -FilePath $LogFile -Append
}

# Banner do módulo
Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "          CONFIGURAÇÃO DO NGINX                 " -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

# Iniciar log do módulo
Write-Log "Iniciando configuração do Nginx" -Level "Info"

# Verificar se o Docker está em execução
Write-Log "Verificando se o Docker está em execução..." -Level "Info"
try {
    $dockerInfo = docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Docker não está em execução" -Level "Error"
        Write-Log "Por favor, inicie o Docker Desktop e execute este módulo novamente" -Level "Info"
        exit 1
    } else {
        Write-Log "Docker está em execução" -Level "Success"
    }
} catch {
    Write-Log "Erro ao verificar o status do Docker: $_" -Level "Error"
    Write-Log "Por favor, verifique se o Docker está instalado e em execução" -Level "Info"
    exit 1
}

# Verificar se o contêiner do Nginx está em execução
Write-Log "Verificando se o contêiner do Nginx está em execução..." -Level "Info"
try {
    $nginxContainer = docker ps --filter "name=rfminsights-nginx-proxy" --format "{{.Names}}" 2>&1
    if ($nginxContainer -eq "rfminsights-nginx-proxy") {
        Write-Log "Contêiner do Nginx está em execução" -Level "Success"
    } else {
        Write-Log "Contêiner do Nginx não está em execução" -Level "Warning"
        
        # Verificar se o contêiner existe mas está parado
        $stoppedContainer = docker ps -a --filter "name=rfminsights-nginx-proxy" --format "{{.Names}}" 2>&1
        if ($stoppedContainer -eq "rfminsights-nginx-proxy") {
            Write-Log "Contêiner do Nginx existe mas está parado" -Level "Info"
            $startContainer = Read-Host "Deseja iniciar o contêiner do Nginx? (S/N)"
            if ($startContainer -eq "S" -or $startContainer -eq "s") {
                Write-Log "Iniciando contêiner do Nginx..." -Level "Info"
                docker start rfminsights-nginx-proxy 2>&1
                Write-Log "Contêiner do Nginx iniciado" -Level "Success"
            } else {
                Write-Log "Configuração do Nginx não pode continuar sem o contêiner em execução" -Level "Error"
                exit 1
            }
        } else {
            Write-Log "Contêiner do Nginx não existe" -Level "Warning"
            Write-Log "Execute o módulo de configuração do Docker primeiro" -Level "Info"
            
            $startDocker = Read-Host "Deseja iniciar todos os contêineres com docker-compose? (S/N)"
            if ($startDocker -eq "S" -or $startDocker -eq "s") {
                $dockerComposeFile = Join-Path -Path $ProjectRoot -ChildPath "docker-compose.yml"
                if (Test-Path $dockerComposeFile) {
                    Write-Log "Iniciando contêineres com docker-compose..." -Level "Info"
                    docker-compose -f $dockerComposeFile up -d 2>&1
                    Write-Log "Contêineres iniciados com sucesso" -Level "Success"
                } else {
                    Write-Log "Arquivo docker-compose.yml não encontrado" -Level "Error"
                    exit 1
                }
            } else {
                Write-Log "Configuração do Nginx não pode continuar sem o contêiner em execução" -Level "Error"
                exit 1
            }
        }
    }
} catch {
    Write-Log "Erro ao verificar o contêiner do Nginx: $_" -Level "Error"
    exit 1
}

# Verificar se o diretório de configuração do Nginx existe
$nginxConfigDir = Join-Path -Path $ProjectRoot -ChildPath "nginx\conf.d"
if (-not (Test-Path $nginxConfigDir)) {
    Write-Log "Criando diretório de configuração do Nginx..." -Level "Info"
    try {
        New-Item -Path $nginxConfigDir -ItemType Directory -Force | Out-Null
        Write-Log "Diretório de configuração do Nginx criado" -Level "Success"
    } catch {
        Write-Log "Erro ao criar diretório de configuração do Nginx: $_" -Level "Error"
        exit 1
    }
} else {
    Write-Log "Diretório de configuração do Nginx encontrado" -Level "Success"
}

# Verificar se o diretório de logs do Nginx existe
$nginxLogsDir = Join-Path -Path $ProjectRoot -ChildPath "nginx\logs"
if (-not (Test-Path $nginxLogsDir)) {
    Write-Log "Criando diretório de logs do Nginx..." -Level "Info"
    try {
        New-Item -Path $nginxLogsDir -ItemType Directory -Force | Out-Null
        Write-Log "Diretório de logs do Nginx criado" -Level "Success"
    } catch {
        Write-Log "Erro ao criar diretório de logs do Nginx: $_" -Level "Error"
        exit 1
    }
} else {
    Write-Log "Diretório de logs do Nginx encontrado" -Level "Success"
}

# Criar arquivo de configuração do Nginx se não existir
$nginxConfFile = Join-Path -Path $ProjectRoot -ChildPath "nginx\nginx.conf"
if (-not (Test-Path $nginxConfFile)) {
    Write-Log "Criando arquivo de configuração do Nginx..." -Level "Info"
    try {
        $nginxConfContent = @"
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    tcp_nopush      on;
    tcp_nodelay     on;
    keepalive_timeout  65;
    types_hash_max_size 2048;
    server_tokens off;

    # SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";

    # Gzip settings
    gzip on;
    gzip_disable "msie6";
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # Include virtual host configurations
    include /etc/nginx/conf.d/*.conf;
}
"@

        $nginxConfContent | Out-File -FilePath $nginxConfFile -Encoding utf8
        Write-Log "Arquivo de configuração do Nginx criado" -Level "Success"
    } catch {
        Write-Log "Erro ao criar arquivo de configuração do Nginx: $_" -Level "Error"
        exit 1
    }
} else {
    Write-Log "Arquivo de configuração do Nginx encontrado" -Level "Success"
}

# Criar arquivo de configuração do frontend se não existir
$frontendConfFile = Join-Path -Path $ProjectRoot -ChildPath "nginx\conf.d\frontend.conf"
if (-not (Test-Path $frontendConfFile)) {
    Write-Log "Criando arquivo de configuração do frontend..." -Level "Info"
    try {
        $frontendConfContent = @"
server {
    listen 80;
    server_name localhost;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /health.html {
        access_log off;
        add_header Content-Type text/plain;
        return 200 'OK';
    }

    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
"@

        $frontendConfContent | Out-File -FilePath $frontendConfFile -Encoding utf8
        Write-Log "Arquivo de configuração do frontend criado" -Level "Success"
    } catch {
        Write-Log "Erro ao criar arquivo de configuração do frontend: $_" -Level "Error"
        exit 1
    }
} else {
    Write-Log "Arquivo de configuração do frontend encontrado" -Level "Success"
}

# Criar arquivo de configuração do proxy reverso se não existir
$proxyConfFile = Join-Path -Path $ProjectRoot -ChildPath "nginx\conf.d\default.conf"
if (-not (Test-Path $proxyConfFile)) {
    Write-Log "Criando arquivo de configuração do proxy reverso..." -Level "Info"
    try {
        $proxyConfContent = @"
server {
    listen 80 default_server;
    server_name _;

    # Redirect all HTTP requests to HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name localhost;

    # SSL certificates
    ssl_certificate /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;

    # Frontend
    location / {
        proxy_pass http://frontend:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # API
    location /api/ {
        proxy_pass http://api:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Health check endpoint
    location /health {
        access_log off;
        add_header Content-Type text/plain;
        return 200 'OK';
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
"@

        $proxyConfContent | Out-File -FilePath $proxyConfFile -Encoding utf8
        Write-Log "Arquivo de configuração do proxy reverso criado" -Level "Success"
    } catch {
        Write-Log "Erro ao criar arquivo de configuração do proxy reverso: $_" -Level "Error"
        exit 1
    }
} else {
    Write-Log "Arquivo de configuração do proxy reverso encontrado" -Level "Success"
}

# Reiniciar o contêiner do Nginx para aplicar as configurações
$restartNginx = Read-Host "Deseja reiniciar o contêiner do Nginx para aplicar as configurações? (S/N)"
if ($restartNginx -eq "S" -or $restartNginx -eq "s") {
    try {
        Write-Log "Reiniciando contêiner do Nginx..." -Level "Info"
        docker restart rfminsights-nginx-proxy 2>&1
        Write-Log "Contêiner do Nginx reiniciado com sucesso" -Level "Success"
    } catch {
        Write-Log "Erro ao reiniciar contêiner do Nginx: $_" -Level "Error"
        exit 1
    }
} else {
    Write-Log "Contêiner do Nginx não foi reiniciado" -Level "Info"
    Write-Log "As configurações serão aplicadas na próxima reinicialização" -Level "Warning"
}

# Configuração do Nginx concluída com sucesso
Write-Log "Configuração do Nginx concluída com sucesso" -Level "Success"
exit 0