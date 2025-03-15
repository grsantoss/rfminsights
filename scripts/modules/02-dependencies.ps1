# RFM Insights - Módulo de Instalação de Dependências
# Este módulo instala as dependências necessárias para o RFM Insights

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
Write-Host "          INSTALAÇÃO DE DEPENDÊNCIAS            " -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

# Iniciar log do módulo
Write-Log "Iniciando instalação de dependências" -Level "Info"

# Verificar se o Python está instalado
Write-Log "Verificando instalação do Python..." -Level "Info"
try {
    $pythonVersion = python --version 2>&1
    if ($pythonVersion -match "Python (\d+\.\d+\.\d+)") {
        $version = $matches[1]
        Write-Log "Python $version encontrado" -Level "Success"
        
        # Verificar se a versão é compatível (3.8 ou superior)
        $versionParts = $version -split '\.' | ForEach-Object { [int]$_ }
        if ($versionParts[0] -lt 3 -or ($versionParts[0] -eq 3 -and $versionParts[1] -lt 8)) {
            Write-Log "A versão do Python deve ser 3.8 ou superior" -Level "Warning"
            $continue = Read-Host "Deseja continuar mesmo com uma versão incompatível do Python? (S/N)"
            if ($continue -ne "S" -and $continue -ne "s") {
                Write-Log "Instalação cancelada pelo usuário" -Level "Info"
                exit 1
            }
        }
    } else {
        Write-Log "Python não encontrado" -Level "Warning"
        $installPython = Read-Host "Deseja instalar o Python 3.10? (S/N)"
        if ($installPython -eq "S" -or $installPython -eq "s") {
            Write-Log "Baixando e instalando Python 3.10..." -Level "Info"
            $pythonUrl = "https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe"
            $pythonInstaller = "$env:TEMP\python-3.10.11-amd64.exe"
            
            try {
                Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller
                Write-Log "Executando instalador do Python..." -Level "Info"
                Start-Process -FilePath $pythonInstaller -ArgumentList "/quiet", "InstallAllUsers=1", "PrependPath=1" -Wait
                Write-Log "Python instalado com sucesso" -Level "Success"
                
                # Atualizar variáveis de ambiente sem reiniciar
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            } catch {
                Write-Log "Erro ao instalar Python: $_" -Level "Error"
                exit 1
            }
        } else {
            Write-Log "Instalação não pode continuar sem Python" -Level "Error"
            exit 1
        }
    }
} catch {
    Write-Log "Erro ao verificar instalação do Python: $_" -Level "Error"
    exit 1
}

# Verificar se o pip está instalado
Write-Log "Verificando instalação do pip..." -Level "Info"
try {
    $pipVersion = pip --version 2>&1
    if ($pipVersion -match "pip") {
        Write-Log "pip encontrado: $pipVersion" -Level "Success"
    } else {
        Write-Log "pip não encontrado, instalando..." -Level "Warning"
        try {
            python -m ensurepip --upgrade
            Write-Log "pip instalado com sucesso" -Level "Success"
        } catch {
            Write-Log "Erro ao instalar pip: $_" -Level "Error"
            exit 1
        }
    }
} catch {
    Write-Log "Erro ao verificar instalação do pip: $_" -Level "Warning"
    try {
        Write-Log "Tentando instalar pip..." -Level "Info"
        python -m ensurepip --upgrade
        Write-Log "pip instalado com sucesso" -Level "Success"
    } catch {
        Write-Log "Erro ao instalar pip: $_" -Level "Error"
        exit 1
    }
}

# Verificar se o Docker está instalado
Write-Log "Verificando instalação do Docker..." -Level "Info"
try {
    $dockerVersion = docker --version 2>&1
    if ($dockerVersion -match "Docker version") {
        Write-Log "Docker encontrado: $dockerVersion" -Level "Success"
    } else {
        Write-Log "Docker não encontrado" -Level "Warning"
        $installDocker = Read-Host "Deseja instalar o Docker Desktop? (S/N)"
        if ($installDocker -eq "S" -or $installDocker -eq "s") {
            Write-Log "Para instalar o Docker Desktop, siga estas etapas:" -Level "Info"
            Write-Log "1. Baixe o Docker Desktop em: https://www.docker.com/products/docker-desktop" -Level "Info"
            Write-Log "2. Execute o instalador e siga as instruções" -Level "Info"
            Write-Log "3. Reinicie o computador após a instalação" -Level "Info"
            Write-Log "4. Execute este script novamente após a instalação do Docker" -Level "Info"
            
            $openBrowser = Read-Host "Deseja abrir o site de download do Docker agora? (S/N)"
            if ($openBrowser -eq "S" -or $openBrowser -eq "s") {
                Start-Process "https://www.docker.com/products/docker-desktop"
            }
            
            Write-Log "Instalação interrompida. Execute novamente após instalar o Docker" -Level "Warning"
            exit 1
        } else {
            Write-Log "Instalação não pode continuar sem Docker" -Level "Error"
            exit 1
        }
    }
} catch {
    Write-Log "Erro ao verificar instalação do Docker: $_" -Level "Warning"
    Write-Log "Docker não encontrado" -Level "Warning"
    $installDocker = Read-Host "Deseja instalar o Docker Desktop? (S/N)"
    if ($installDocker -eq "S" -or $installDocker -eq "s") {
        Write-Log "Para instalar o Docker Desktop, siga estas etapas:" -Level "Info"
        Write-Log "1. Baixe o Docker Desktop em: https://www.docker.com/products/docker-desktop" -Level "Info"
        Write-Log "2. Execute o instalador e siga as instruções" -Level "Info"
        Write-Log "3. Reinicie o computador após a instalação" -Level "Info"
        Write-Log "4. Execute este script novamente após a instalação do Docker" -Level "Info"
        
        $openBrowser = Read-Host "Deseja abrir o site de download do Docker agora? (S/N)"
        if ($openBrowser -eq "S" -or $openBrowser -eq "s") {
            Start-Process "https://www.docker.com/products/docker-desktop"
        }
        
        Write-Log "Instalação interrompida. Execute novamente após instalar o Docker" -Level "Warning"
        exit 1
    } else {
        Write-Log "Instalação não pode continuar sem Docker" -Level "Error"
        exit 1
    }
}

# Verificar se o Docker Compose está instalado
Write-Log "Verificando instalação do Docker Compose..." -Level "Info"
try {
    $dockerComposeVersion = docker-compose --version 2>&1
    if ($dockerComposeVersion -match "docker-compose version") {
        Write-Log "Docker Compose encontrado: $dockerComposeVersion" -Level "Success"
    } else {
        Write-Log "Docker Compose não encontrado, mas pode estar integrado ao Docker Desktop" -Level "Warning"
        
        # Verificar se o Docker Compose V2 está disponível
        $dockerComposeV2 = docker compose version 2>&1
        if ($dockerComposeV2 -match "Docker Compose version") {
            Write-Log "Docker Compose V2 encontrado: $dockerComposeV2" -Level "Success"
        } else {
            Write-Log "Docker Compose não encontrado" -Level "Warning"
            Write-Log "O Docker Compose geralmente é instalado com o Docker Desktop" -Level "Info"
            Write-Log "Verifique se o Docker Desktop está instalado corretamente" -Level "Info"
            
            $continue = Read-Host "Deseja continuar mesmo sem Docker Compose? (S/N)"
            if ($continue -ne "S" -and $continue -ne "s") {
                Write-Log "Instalação cancelada pelo usuário" -Level "Info"
                exit 1
            }
        }
    }
} catch {
    Write-Log "Erro ao verificar instalação do Docker Compose: $_" -Level "Warning"
    
    # Verificar se o Docker Compose V2 está disponível
    try {
        $dockerComposeV2 = docker compose version 2>&1
        if ($dockerComposeV2 -match "Docker Compose version") {
            Write-Log "Docker Compose V2 encontrado: $dockerComposeV2" -Level "Success"
        } else {
            Write-Log "Docker Compose não encontrado" -Level "Warning"
            Write-Log "O Docker Compose geralmente é instalado com o Docker Desktop" -Level "Info"
            Write-Log "Verifique se o Docker Desktop está instalado corretamente" -Level "Info"
            
            $continue = Read-Host "Deseja continuar mesmo sem Docker Compose? (S/N)"
            if ($continue -ne "S" -and $continue -ne "s") {
                Write-Log "Instalação cancelada pelo usuário" -Level "Info"
                exit 1
            }
        }
    } catch {
        Write-Log "Docker Compose não encontrado" -Level "Warning"
        Write-Log "O Docker Compose geralmente é instalado com o Docker Desktop" -Level "Info"
        Write-Log "Verifique se o Docker Desktop está instalado corretamente" -Level "Info"
        
        $continue = Read-Host "Deseja continuar mesmo sem Docker Compose? (S/N)"
        if ($continue -ne "S" -and $continue -ne "s") {
            Write-Log "Instalação cancelada pelo usuário" -Level "Info"
            exit 1
        }
    }
}

# Instalar dependências Python do requirements.txt
$requirementsFile = Join-Path -Path $ProjectRoot -ChildPath "requirements.txt"
if (Test-Path $requirementsFile) {
    Write-Log "Arquivo requirements.txt encontrado" -Level "Info"
    $installPythonDeps = Read-Host "Deseja instalar as dependências Python listadas em requirements.txt? (S/N)"
    if ($installPythonDeps -eq "S" -or $installPythonDeps -eq "s") {
        Write-Log "Instalando dependências Python..." -Level "Info"
        try {
            $output = pip install -r $requirementsFile 2>&1
            Write-Log "Dependências Python instaladas com sucesso" -Level "Success"
        } catch {
            Write-Log "Erro ao instalar dependências Python: $_" -Level "Warning"
            Write-Log "As dependências serão instaladas automaticamente no contêiner Docker" -Level "Info"
            
            $continue = Read-Host "Deseja continuar mesmo com erro na instalação das dependências? (S/N)"
            if ($continue -ne "S" -and $continue -ne "s") {
                Write-Log "Instalação cancelada pelo usuário" -Level "Info"
                exit 1
            }
        }
    } else {
        Write-Log "Instalação de dependências Python ignorada pelo usuário" -Level "Info"
        Write-Log "As dependências serão instaladas automaticamente no contêiner Docker" -Level "Info"
    }
} else {
    Write-Log "Arquivo requirements.txt não encontrado" -Level "Warning"
    Write-Log "As dependências serão instaladas automaticamente no contêiner Docker" -Level "Info"
}

# Instalação de dependências concluída com sucesso
Write-Log "Instalação de dependências concluída com sucesso" -Level "Success"
exit 0