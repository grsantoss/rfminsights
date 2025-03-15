# RFM Insights - Módulo de Configuração do Banco de Dados
# Este módulo configura o banco de dados PostgreSQL para o RFM Insights

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
Write-Host "          CONFIGURAÇÃO DO BANCO DE DADOS         " -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

# Iniciar log do módulo
Write-Log "Iniciando configuração do banco de dados" -Level "Info"

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

# Verificar se o contêiner do PostgreSQL está em execução
Write-Log "Verificando se o contêiner do PostgreSQL está em execução..." -Level "Info"
try {
    $postgresContainer = docker ps --filter "name=rfminsights-postgres" --format "{{.Names}}" 2>&1
    if ($postgresContainer -eq "rfminsights-postgres") {
        Write-Log "Contêiner do PostgreSQL está em execução" -Level "Success"
    } else {
        Write-Log "Contêiner do PostgreSQL não está em execução" -Level "Warning"
        
        # Verificar se o contêiner existe mas está parado
        $stoppedContainer = docker ps -a --filter "name=rfminsights-postgres" --format "{{.Names}}" 2>&1
        if ($stoppedContainer -eq "rfminsights-postgres") {
            Write-Log "Contêiner do PostgreSQL existe mas está parado" -Level "Info"
            $startContainer = Read-Host "Deseja iniciar o contêiner do PostgreSQL? (S/N)"
            if ($startContainer -eq "S" -or $startContainer -eq "s") {
                Write-Log "Iniciando contêiner do PostgreSQL..." -Level "Info"
                docker start rfminsights-postgres 2>&1
                Write-Log "Contêiner do PostgreSQL iniciado" -Level "Success"
            } else {
                Write-Log "Configuração do banco de dados não pode continuar sem o PostgreSQL" -Level "Error"
                exit 1
            }
        } else {
            Write-Log "Contêiner do PostgreSQL não existe" -Level "Warning"
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
                Write-Log "Configuração do banco de dados não pode continuar sem o PostgreSQL" -Level "Error"
                exit 1
            }
        }
    }
} catch {
    Write-Log "Erro ao verificar o contêiner do PostgreSQL: $_" -Level "Error"
    exit 1
}

# Aguardar o PostgreSQL iniciar completamente
Write-Log "Aguardando o PostgreSQL iniciar completamente..." -Level "Info"
$retries = 0
$maxRetries = 30
$postgresReady = $false

while (-not $postgresReady -and $retries -lt $maxRetries) {
    Start-Sleep -Seconds 2
    $retries++
    
    try {
        $healthCheck = docker exec rfminsights-postgres pg_isready -U rfminsights 2>&1
        if ($LASTEXITCODE -eq 0) {
            $postgresReady = $true
            Write-Log "PostgreSQL está pronto após $retries tentativas" -Level "Success"
        } else {
            Write-Log "Aguardando PostgreSQL iniciar (tentativa $retries de $maxRetries)..." -Level "Info"
        }
    } catch {
        Write-Log "Erro ao verificar status do PostgreSQL (tentativa $retries de $maxRetries): $_" -Level "Warning"
    }
}

if (-not $postgresReady) {
    Write-Log "PostgreSQL não ficou pronto após várias tentativas" -Level "Error"
    Write-Log "Verifique os logs do contêiner para mais detalhes" -Level "Info"
    exit 1
}

# Verificar se o script de verificação de saúde do banco de dados existe
$dbHealthcheckScript = Join-Path -Path $ProjectRoot -ChildPath "scripts\db_healthcheck.py"
if (Test-Path $dbHealthcheckScript) {
    Write-Log "Script de verificação de saúde do banco de dados encontrado" -Level "Info"
    
    # Verificar se o Python está instalado
    try {
        $pythonVersion = python --version 2>&1
        if ($pythonVersion -match "Python") {
            Write-Log "Python encontrado: $pythonVersion" -Level "Success"
            
            # Executar o script de verificação de saúde do banco de dados
            $runHealthCheck = Read-Host "Deseja executar o script de verificação de saúde do banco de dados? (S/N)"
            if ($runHealthCheck -eq "S" -or $runHealthCheck -eq "s") {
                Write-Log "Executando script de verificação de saúde do banco de dados..." -Level "Info"
                try {
                    $output = python $dbHealthcheckScript --max-retries 10 --retry-interval 2 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Log "Verificação de saúde do banco de dados concluída com sucesso" -Level "Success"
                    } else {
                        Write-Log "Verificação de saúde do banco de dados falhou" -Level "Warning"
                        Write-Log "Saída do script: $output" -Level "Info"
                        
                        $continue = Read-Host "Deseja continuar mesmo com falha na verificação de saúde? (S/N)"
                        if ($continue -ne "S" -and $continue -ne "s") {
                            Write-Log "Configuração do banco de dados interrompida pelo usuário" -Level "Info"
                            exit 1
                        }
                    }
                } catch {
                    Write-Log "Erro ao executar script de verificação de saúde: $_" -Level "Warning"
                    
                    $continue = Read-Host "Deseja continuar mesmo com erro na verificação de saúde? (S/N)"
                    if ($continue -ne "S" -and $continue -ne "s") {
                        Write-Log "Configuração do banco de dados interrompida pelo usuário" -Level "Info"
                        exit 1
                    }
                }
            } else {
                Write-Log "Verificação de saúde do banco de dados ignorada pelo usuário" -Level "Info"
            }
        } else {
            Write-Log "Python não encontrado, pulando verificação de saúde do banco de dados" -Level "Warning"
        }
    } catch {
        Write-Log "Erro ao verificar instalação do Python: $_" -Level "Warning"
        Write-Log "Pulando verificação de saúde do banco de dados" -Level "Info"
    }
} else {
    Write-Log "Script de verificação de saúde do banco de dados não encontrado" -Level "Warning"
    Write-Log "Pulando verificação de saúde do banco de dados" -Level "Info"
}

# Configurar backup automático do banco de dados
Write-Log "Configurando backup automático do banco de dados..." -Level "Info"
$backupScript = Join-Path -Path $ProjectRoot -ChildPath "scripts\backup.sh"
if (Test-Path $backupScript) {
    Write-Log "Script de backup encontrado" -Level "Success"
    
    # Verificar se o contêiner de backup está em execução
    try {
        $backupContainer = docker ps --filter "name=rfminsights-db-backup" --format "{{.Names}}" 2>&1
        if ($backupContainer -eq "rfminsights-db-backup") {
            Write-Log "Contêiner de backup está em execução" -Level "Success"
        } else {
            Write-Log "Contêiner de backup não está em execução" -Level "Warning"
            
            # Verificar se o contêiner existe mas está parado
            $stoppedContainer = docker ps -a --filter "name=rfminsights-db-backup" --format "{{.Names}}" 2>&1
            if ($stoppedContainer -eq "rfminsights-db-backup") {
                Write-Log "Contêiner de backup existe mas está parado" -Level "Info"
                $startContainer = Read-Host "Deseja iniciar o contêiner de backup? (S/N)"
                if ($startContainer -eq "S" -or $startContainer -eq "s") {
                    Write-Log "Iniciando contêiner de backup..." -Level "Info"
                    docker start rfminsights-db-backup 2>&1
                    Write-Log "Contêiner de backup iniciado" -Level "Success"
                } else {
                    Write-Log "Backup automático não será configurado" -Level "Warning"
                }
            } else {
                Write-Log "Contêiner de backup não existe" -Level "Warning"
                Write-Log "Execute o módulo de configuração do Docker primeiro" -Level "Info"
            }
        }
    } catch {
        Write-Log "Erro ao verificar o contêiner de backup: $_" -Level "Warning"
    }
} else {
    Write-Log "Script de backup não encontrado" -Level "Warning"
    Write-Log "Backup automático não será configurado" -Level "Info"
}

# Configuração do banco de dados concluída com sucesso
Write-Log "Configuração do banco de dados concluída com sucesso" -Level "Success"
exit 0