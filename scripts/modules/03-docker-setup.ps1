# RFM Insights - Módulo de Configuração do Docker
# Este módulo configura o Docker e os contêineres necessários para o RFM Insights

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
Write-Host "          CONFIGURAÇÃO DO DOCKER                " -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

# Iniciar log do módulo
Write-Log "Iniciando configuração do Docker" -Level "Info"

# Verificar se o Docker está em execução
Write-Log "Verificando se o Docker está em execução..." -Level "Info"
try {
    $dockerInfo = docker info 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Docker está em execução" -Level "Success"
    } else {
        Write-Log "Docker não está em execução" -Level "Warning"
        Write-Log "Tentando iniciar o Docker..." -Level "Info"
        
        # Verificar se o serviço Docker existe
        $dockerService = Get-Service -Name "Docker*" -ErrorAction SilentlyContinue
        if ($dockerService) {
            try {
                Start-Service -Name $dockerService.Name
                Write-Log "Serviço Docker iniciado" -Level "Success"
                
                # Aguardar o Docker iniciar completamente
                Write-Log "Aguardando o Docker iniciar completamente..." -Level "Info"
                $retries = 0
                $maxRetries = 30
                $dockerStarted = $false
                
                while (-not $dockerStarted -and $retries -lt $maxRetries) {
                    Start-Sleep -Seconds 2
                    $retries++
                    
                    try {
                        $dockerInfo = docker info 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            $dockerStarted = $true
                            Write-Log "Docker iniciado com sucesso após $retries tentativas" -Level "Success"
                        }
                    } catch {
                        # Continuar tentando
                    }
                }
                
                if (-not $dockerStarted) {
                    Write-Log "Não foi possível iniciar o Docker após várias tentativas" -Level "Error"
                    Write-Log "Por favor, inicie o Docker Desktop manualmente e execute este script novamente" -Level "Info"
                    exit 1
                }
            } catch {
                Write-Log "Erro ao iniciar o serviço Docker: $_" -Level "Error"
                Write-Log "Por favor, inicie o Docker Desktop manualmente e execute este script novamente" -Level "Info"
                exit 1
            }
        } else {
            Write-Log "Serviço Docker não encontrado" -Level "Error"
            Write-Log "Por favor, inicie o Docker Desktop manualmente e execute este script novamente" -Level "Info"
            exit 1
        }
    }
} catch {
    Write-Log "Erro ao verificar o status do Docker: $_" -Level "Error"
    Write-Log "Por favor, verifique se o Docker está instalado e em execução" -Level "Info"
    exit 1
}

# Verificar se o docker-compose.yml existe
$dockerComposeFile = Join-Path -Path $ProjectRoot -ChildPath "docker-compose.yml"
if (-not (Test-Path $dockerComposeFile)) {
    Write-Log "Arquivo docker-compose.yml não encontrado" -Level "Error"
    exit 1
} else {
    Write-Log "Arquivo docker-compose.yml encontrado" -Level "Success"
}

# Verificar se há contêineres em execução do projeto
Write-Log "Verificando contêineres existentes..." -Level "Info"
try {
    $existingContainers = docker ps -a --filter "name=rfminsights" --format "{{.Names}}" 2>&1
    if ($existingContainers) {
        Write-Log "Contêineres existentes encontrados:" -Level "Warning"
        $existingContainers | ForEach-Object { Write-Log "  - $_" -Level "Info" }
        
        $stopContainers = Read-Host "Deseja parar e remover os contêineres existentes? (S/N)"
        if ($stopContainers -eq "S" -or $stopContainers -eq "s") {
            Write-Log "Parando e removendo contêineres existentes..." -Level "Info"
            docker-compose -f $dockerComposeFile down 2>&1
            Write-Log "Contêineres removidos com sucesso" -Level "Success"
        } else {
            Write-Log "Mantendo contêineres existentes" -Level "Info"
            Write-Log "A instalação continuará, mas pode haver conflitos" -Level "Warning"
        }
    } else {
        Write-Log "Nenhum contêiner existente encontrado" -Level "Info"
    }
} catch {
    Write-Log "Erro ao verificar contêineres existentes: $_" -Level "Warning"
    Write-Log "Continuando com a instalação" -Level "Info"
}

# Construir e iniciar os contêineres
Write-Log "Construindo e iniciando contêineres..." -Level "Info"
try {
    # Verificar se o usuário quer construir as imagens
    $buildImages = Read-Host "Deseja construir as imagens Docker? (S/N)"
    if ($buildImages -eq "S" -or $buildImages -eq "s") {
        Write-Log "Construindo imagens Docker..." -Level "Info"
        docker-compose -f $dockerComposeFile build 2>&1
        Write-Log "Imagens Docker construídas com sucesso" -Level "Success"
    } else {
        Write-Log "Pulando construção de imagens Docker" -Level "Info"
    }
    
    # Iniciar os contêineres
    $startContainers = Read-Host "Deseja iniciar os contêineres agora? (S/N)"
    if ($startContainers -eq "S" -or $startContainers -eq "s") {
        Write-Log "Iniciando contêineres..." -Level "Info"
        docker-compose -f $dockerComposeFile up -d 2>&1
        Write-Log "Contêineres iniciados com sucesso" -Level "Success"
        
        # Verificar status dos contêineres
        Write-Log "Verificando status dos contêineres..." -Level "Info"
        Start-Sleep -Seconds 5  # Aguardar um pouco para os contêineres iniciarem
        $containerStatus = docker-compose -f $dockerComposeFile ps 2>&1
        Write-Log "Status dos contêineres:" -Level "Info"
        $containerStatus | ForEach-Object { Write-Log "  $_" -Level "Info" }
    } else {
        Write-Log "Pulando inicialização dos contêineres" -Level "Info"
        Write-Log "Você pode iniciar os contêineres posteriormente com o comando:" -Level "Info"
        Write-Log "  docker-compose -f $dockerComposeFile up -d" -Level "Info"
    }
} catch {
    Write-Log "Erro ao construir/iniciar contêineres: $_" -Level "Error"
    Write-Log "Verifique o log do Docker para mais detalhes" -Level "Info"
    exit 1
}

# Configuração do Docker concluída com sucesso
Write-Log "Configuração do Docker concluída com sucesso" -Level "Success"
exit 0