# RFM Insights - Módulo de Configuração SSL
# Este módulo configura os certificados SSL para o RFM Insights

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
Write-Host "          CONFIGURAÇÃO SSL                      " -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

# Iniciar log do módulo
Write-Log "Iniciando configuração SSL" -Level "Info"

# Verificar se o diretório SSL existe
$sslDir = Join-Path -Path $ProjectRoot -ChildPath "nginx\ssl"
if (-not (Test-Path $sslDir)) {
    Write-Log "Criando diretório SSL..." -Level "Info"
    try {
        New-Item -Path $sslDir -ItemType Directory -Force | Out-Null
        Write-Log "Diretório SSL criado" -Level "Success"
    } catch {
        Write-Log "Erro ao criar diretório SSL: $_" -Level "Error"
        exit 1
    }
} else {
    Write-Log "Diretório SSL encontrado" -Level "Success"
}

# Verificar se os certificados já existem
$certFile = Join-Path -Path $sslDir -ChildPath "server.crt"
$keyFile = Join-Path -Path $sslDir -ChildPath "server.key"

if ((Test-Path $certFile) -and (Test-Path $keyFile)) {
    Write-Log "Certificados SSL já existem" -Level "Info"
    $regenerateCerts = Read-Host "Deseja regenerar os certificados SSL? (S/N)"
    if ($regenerateCerts -ne "S" -and $regenerateCerts -ne "s") {
        Write-Log "Mantendo certificados SSL existentes" -Level "Info"
        exit 0
    }
}

# Perguntar ao usuário se deseja usar certificados autoassinados ou Let's Encrypt
Write-Host ""
Write-Host "Opções de Certificado SSL:" -ForegroundColor Cyan
Write-Host "1. Certificado Autoassinado (para desenvolvimento)" -ForegroundColor White
Write-Host "2. Let's Encrypt (para produção - requer domínio público)" -ForegroundColor White
Write-Host ""

$sslOption = Read-Host "Escolha uma opção (1-2)"

switch ($sslOption) {
    "1" {
        Write-Log "Gerando certificado autoassinado..." -Level "Info"
        
        # Verificar se o OpenSSL está instalado
        try {
            $opensslVersion = openssl version 2>&1
            Write-Log "OpenSSL encontrado: $opensslVersion" -Level "Success"
        } catch {
            Write-Log "OpenSSL não encontrado" -Level "Warning"
            Write-Log "Tentando usar o OpenSSL do Docker..." -Level "Info"
            
            try {
                # Usar o OpenSSL dentro de um contêiner Docker
                $opensslCommand = @"
docker run --rm -v "${sslDir}:/ssl" alpine /bin/sh -c "apk add --no-cache openssl && \
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /ssl/server.key -out /ssl/server.crt \
  -subj '/CN=localhost/O=RFM Insights/C=BR' && \
  chmod 644 /ssl/server.crt && \
  chmod 600 /ssl/server.key"
"@
                
                Invoke-Expression $opensslCommand
                
                if (Test-Path $certFile -and Test-Path $keyFile) {
                    Write-Log "Certificados SSL gerados com sucesso usando Docker" -Level "Success"
                } else {
                    Write-Log "Falha ao gerar certificados SSL usando Docker" -Level "Error"
                    exit 1
                }
            } catch {
                Write-Log "Erro ao gerar certificados SSL: $_" -Level "Error"
                Write-Log "Por favor, instale o OpenSSL e execute este módulo novamente" -Level "Info"
                exit 1
            }
        }
        
        # Se o OpenSSL estiver instalado, usar diretamente
        if ($opensslVersion) {
            try {
                # Gerar chave privada e certificado
                $opensslCommand = "openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout `"$keyFile`" -out `"$certFile`" -subj '/CN=localhost/O=RFM Insights/C=BR'"
                Invoke-Expression $opensslCommand
                
                # Verificar se os arquivos foram criados
                if (Test-Path $certFile -and Test-Path $keyFile) {
                    Write-Log "Certificados SSL gerados com sucesso" -Level "Success"
                } else {
                    Write-Log "Falha ao gerar certificados SSL" -Level "Error"
                    exit 1
                }
            } catch {
                Write-Log "Erro ao gerar certificados SSL: $_" -Level "Error"
                exit 1
            }
        }
    }
    "2" {
        Write-Log "Configuração do Let's Encrypt selecionada" -Level "Info"
        
        # Solicitar informações do domínio
        $domain = Read-Host "Digite o nome de domínio para o certificado (ex: rfminsights.com.br)"
        $email = Read-Host "Digite o endereço de e-mail para notificações do Let's Encrypt"
        
        Write-Log "Configurando Let's Encrypt para o domínio $domain" -Level "Info"
        
        # Verificar se o Certbot está instalado
        try {
            $certbotVersion = docker run --rm certbot/certbot --version 2>&1
            Write-Log "Certbot disponível via Docker: $certbotVersion" -Level "Success"
            
            # Criar diretório para armazenar dados do Certbot
            $certbotDataDir = Join-Path -Path $ProjectRoot -ChildPath "certbot"
            if (-not (Test-Path $certbotDataDir)) {
                New-Item -Path $certbotDataDir -ItemType Directory -Force | Out-Null
                New-Item -Path "$certbotDataDir\conf" -ItemType Directory -Force | Out-Null
                New-Item -Path "$certbotDataDir\www" -ItemType Directory -Force | Out-Null
            }
            
            # Informar ao usuário sobre os próximos passos
            Write-Log "Para obter um certificado Let's Encrypt válido:" -Level "Info"
            Write-Log "1. Certifique-se de que seu domínio $domain aponta para este servidor" -Level "Info"
            Write-Log "2. Certifique-se de que a porta 80 está aberta e acessível pela internet" -Level "Info"
            Write-Log "3. Execute o seguinte comando quando estiver pronto:" -Level "Info"
            
            $certbotCommand = @"
docker run -it --rm \
  -v "${certbotDataDir}/conf:/etc/letsencrypt" \
  -v "${certbotDataDir}/www:/var/www/certbot" \
  certbot/certbot certonly --webroot \
  --webroot-path=/var/www/certbot \
  --email $email --agree-tos --no-eff-email \
  -d $domain
"@
            
            Write-Host $certbotCommand -ForegroundColor Yellow
            Write-Log "4. Após obter o certificado, copie-o para o diretório nginx/ssl" -Level "Info"
            
            $continue = Read-Host "Deseja tentar obter o certificado agora? (S/N)"
            if ($continue -eq "S" -or $continue -eq "s") {
                try {
                    Invoke-Expression $certbotCommand
                    
                    # Verificar se o certificado foi obtido com sucesso
                    $certPath = "$certbotDataDir\conf\live\$domain\fullchain.pem"
                    $privKeyPath = "$certbotDataDir\conf\live\$domain\privkey.pem"
                    
                    if (Test-Path $certPath -and Test-Path $privKeyPath) {
                        # Copiar certificados para o diretório nginx/ssl
                        Copy-Item -Path $certPath -Destination $certFile -Force
                        Copy-Item -Path $privKeyPath -Destination $keyFile -Force
                        
                        Write-Log "Certificados Let's Encrypt obtidos e copiados com sucesso" -Level "Success"
                    } else {
                        Write-Log "Não foi possível encontrar os certificados Let's Encrypt" -Level "Warning"
                        Write-Log "Gerando certificado autoassinado temporário..." -Level "Info"
                        
                        # Gerar certificado autoassinado como fallback
                        $opensslCommand = "openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout `"$keyFile`" -out `"$certFile`" -subj '/CN=$domain/O=RFM Insights/C=BR'"
                        Invoke-Expression $opensslCommand
                        
                        Write-Log "Certificado autoassinado temporário gerado" -Level "Success"
                    }
                } catch {
                    Write-Log "Erro ao obter certificado Let's Encrypt: $_" -Level "Error"
                    Write-Log "Gerando certificado autoassinado temporário..." -Level "Info"
                    
                    # Gerar certificado autoassinado como fallback
                    $opensslCommand = "openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout `"$keyFile`" -out `"$certFile`" -subj '/CN=$domain/O=RFM Insights/C=BR'"
                    Invoke-Expression $opensslCommand
                    
                    Write-Log "Certificado autoassinado temporário gerado" -Level "Success"
                }
            } else {
                Write-Log "Gerando certificado autoassinado temporário..." -Level "Info"
                
                # Gerar certificado autoassinado como fallback
                $opensslCommand = "openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout `"$keyFile`" -out `"$certFile`" -subj '/CN=$domain/O=RFM Insights/C=BR'"
                Invoke-Expression $opensslCommand
                
                Write-Log "Certificado autoassinado temporário gerado" -Level "Success"
            }
        }
    }
}

# Verificar se os certificados foram gerados corretamente
if (Test-Path $certFile -and Test-Path $keyFile) {
    Write-Log "Certificados SSL configurados com sucesso" -Level "Success"
    
    # Perguntar se deseja reiniciar o Nginx para aplicar as configurações
    $restartNginx = Read-Host "Deseja reiniciar o Nginx para aplicar as configurações SSL? (S/N)"
    
    if ($restartNginx -eq "S" -or $restartNginx -eq "s") {
        Write-Log "Reiniciando contêiner do Nginx..." -Level "Info"
        try {
            docker-compose -f "$ProjectRoot\docker-compose.yml" restart nginx
            Write-Log "Contêiner do Nginx reiniciado com sucesso" -Level "Success"
        } catch {
            Write-Log "Erro ao reiniciar contêiner do Nginx: $_" -Level "Error"
            exit 1
        }
    } else {
        Write-Log "Contêiner do Nginx não foi reiniciado" -Level "Info"
        Write-Log "As configurações SSL serão aplicadas na próxima reinicialização" -Level "Warning"
    }
} else {
    Write-Log "Falha ao configurar certificados SSL" -Level "Error"
    exit 1
}

# Configuração SSL concluída com sucesso
Write-Log "Configuração SSL concluída com sucesso" -Level "Success"
exit 0