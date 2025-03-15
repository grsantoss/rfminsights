# RFM Insights - Módulo de Configuração Final
# Este módulo finaliza a configuração do RFM Insights e verifica se tudo está funcionando corretamente

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
Write-Host "          CONFIGURAÇÃO FINAL                    " -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

# Iniciar log do módulo
Write-Log "Iniciando configuração final" -Level "Info"

# Verificar se todos os contêineres estão em execução
Write-Log "Verificando status dos contêineres..." -Level "Info"
try {
    $dockerComposeFile = Join-Path -Path $ProjectRoot -ChildPath "docker-compose.yml"
    if (Test-Path $dockerComposeFile) {
        $containerStatus = docker-compose -f $dockerComposeFile ps 2>&1
        Write-Log "Status dos contêineres:" -Level "Info"
        $containerStatus | ForEach-Object { Write-Log "  $_" -Level "Info" }
        
        # Verificar se há contêineres parados
        $stoppedContainers = docker-compose -f $dockerComposeFile ps --services --filter "status=stopped" 2>&1
        if ($stoppedContainers) {
            Write-Log "Contêineres parados encontrados:" -Level "Warning"
            $stoppedContainers | ForEach-Object { Write-Log "  - $_" -Level "Warning" }
            
            $startContainers = Read-Host "Deseja iniciar os contêineres parados? (S/N)"
            if ($startContainers -eq "S" -or $startContainers -eq "s") {
                Write-Log "Iniciando contêineres parados..." -Level "Info"
                docker-compose -f $dockerComposeFile start $stoppedContainers 2>&1
                Write-Log "Contêineres iniciados com sucesso" -Level "Success"
            } else {
                Write-Log "Mantendo contêineres parados" -Level "Info"
            }
        } else {
            Write-Log "Todos os contêineres estão em execução" -Level "Success"
        }
    } else {
        Write-Log "Arquivo docker-compose.yml não encontrado" -Level "Error"
        exit 1
    }
} catch {
    Write-Log "Erro ao verificar status dos contêineres: $_" -Level "Error"
    exit 1
}

# Verificar se a API está respondendo
Write-Log "Verificando se a API está respondendo..." -Level "Info"
try {
    $apiHealthCheck = docker exec rfminsights-api curl -s http://localhost:8000/health 2>&1
    if ($apiHealthCheck -match "healthy") {
        Write-Log "API está respondendo corretamente" -Level "Success"
    } else {
        Write-Log "API não está respondendo corretamente" -Level "Warning"
        Write-Log "Resposta da API: $apiHealthCheck" -Level "Info"
        
        $restartApi = Read-Host "Deseja reiniciar o contêiner da API? (S/N)"
        if ($restartApi -eq "S" -or $restartApi -eq "s") {
            Write-Log "Reiniciando contêiner da API..." -Level "Info"
            docker restart rfminsights-api 2>&1
            Write-Log "Contêiner da API reiniciado" -Level "Success"
            
            # Aguardar a API iniciar
            Write-Log "Aguardando a API iniciar..." -Level "Info"
            Start-Sleep -Seconds 10
            
            # Verificar novamente
            $apiHealthCheck = docker exec rfminsights-api curl -s http://localhost:8000/health 2>&1
            if ($apiHealthCheck -match "healthy") {
                Write-Log "API está respondendo corretamente após reinício" -Level "Success"
            } else {
                Write-Log "API ainda não está respondendo corretamente após reinício" -Level "Warning"
                Write-Log "Resposta da API: $apiHealthCheck" -Level "Info"
            }
        }
    }
} catch {
    Write-Log "Erro ao verificar a API: $_" -Level "Warning"
}

# Verificar se o frontend está respondendo
Write-Log "Verificando se o frontend está respondendo..." -Level "Info"
try {
    $frontendHealthCheck = docker exec rfminsights-frontend wget -qO- http://localhost/health.html 2>&1
    if ($frontendHealthCheck -match "OK") {
        Write-Log "Frontend está respondendo corretamente" -Level "Success"
    } else {
        Write-Log "Frontend não está respondendo corretamente" -Level "Warning"
        Write-Log "Resposta do frontend: $frontendHealthCheck" -Level "Info"
        
        $restartFrontend = Read-Host "Deseja reiniciar o contêiner do frontend? (S/N)"
        if ($restartFrontend -eq "S" -or $restartFrontend -eq "s") {
            Write-Log "Reiniciando contêiner do frontend..." -Level "Info"
            docker restart rfminsights-frontend 2>&1
            Write-Log "Contêiner do frontend reiniciado" -Level "Success"
            
            # Aguardar o frontend iniciar
            Write-Log "Aguardando o frontend iniciar..." -Level "Info"
            Start-Sleep -Seconds 5
            
            # Verificar novamente
            $frontendHealthCheck = docker exec rfminsights-frontend wget -qO- http://localhost/health.html 2>&1
            if ($frontendHealthCheck -match "OK") {
                Write-Log "Frontend está respondendo corretamente após reinício" -Level "Success"
            } else {
                Write-Log "Frontend ainda não está respondendo corretamente após reinício" -Level "Warning"
                Write-Log "Resposta do frontend: $frontendHealthCheck" -Level "Info"
            }
        }
    }
} catch {
    Write-Log "Erro ao verificar o frontend: $_" -Level "Warning"
}

# Verificar se o Nginx está respondendo
Write-Log "Verificando se o Nginx está respondendo..." -Level "Info"
try {
    $nginxHealthCheck = docker exec rfminsights-nginx-proxy wget -qO- http://localhost/health 2>&1
    if ($nginxHealthCheck -match "OK") {
        Write-Log "Nginx está respondendo corretamente" -Level "Success"
    } else {
        Write-Log "Nginx não está respondendo corretamente" -Level "Warning"
        Write-Log "Resposta do Nginx: $nginxHealthCheck" -Level "Info"
        
        $restartNginx = Read-Host "Deseja reiniciar o contêiner do Nginx? (S/N)"
        if ($restartNginx -eq "S" -or $restartNginx -eq "s") {
            Write-Log "Reiniciando contêiner do Nginx..." -Level "Info"
            docker restart rfminsights-nginx-proxy 2>&1
            Write-Log "Contêiner do Nginx reiniciado" -Level "Success"
            
            # Aguardar o Nginx iniciar
            Write-Log "Aguardando o Nginx iniciar..." -Level "Info"
            Start-Sleep -Seconds 5
            
            # Verificar novamente
            $nginxHealthCheck = docker exec rfminsights-nginx-proxy wget -qO- http://localhost/health 2>&1
            if ($nginxHealthCheck -match "OK") {
                Write-Log "Nginx está respondendo corretamente após reinício" -Level "Success"
            } else {
                Write-Log "Nginx ainda não está respondendo corretamente após reinício" -Level "Warning"
                Write-Log "Resposta do Nginx: $nginxHealthCheck" -Level "Info"
            }
        }
    }
} catch {
    Write-Log "Erro ao verificar o Nginx: $_" -Level "Warning"
}

# Exibir informações de acesso
Write-Host ""
Write-Host "===================================================" -ForegroundColor Green
Write-Host "          INSTALAÇÃO CONCLUÍDA                  " -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Informações de Acesso:" -ForegroundColor Cyan
Write-Host "  - Frontend: http://localhost" -ForegroundColor White
Write-Host "  - API: http://localhost/api" -ForegroundColor White
Write-Host "  - Portainer: https://localhost:9443" -ForegroundColor White
Write-Host ""
Write-Host "Para acessar via HTTPS:" -ForegroundColor Cyan
Write-Host "  - Frontend: https://localhost" -ForegroundColor White
Write-Host "  - API: https://localhost/api" -ForegroundColor White
Write-Host ""
Write-Host "Credenciais padrão:" -ForegroundColor Cyan
Write-Host "  - Usuário: admin@rfminsights.com.br" -ForegroundColor White
Write-Host "  - Senha: RFMInsights@2023" -ForegroundColor White
Write-Host ""
Write-Host "IMPORTANTE: Altere a senha padrão após o primeiro acesso!" -ForegroundColor Yellow
Write-Host ""

# Configuração final concluída com sucesso
Write-Log "Configuração final concluída com sucesso" -Level "Success"
exit 0