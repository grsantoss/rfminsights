# RFM Insights - Módulo de Verificação de Ambiente
# Este módulo verifica os requisitos do sistema para a instalação do RFM Insights

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
Write-Host "          VERIFICAÇÃO DE AMBIENTE                " -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

# Iniciar log do módulo
Write-Log "Iniciando verificação de ambiente" -Level "Info"

# Verificar se está sendo executado como administrador
Write-Log "Verificando privilégios administrativos..." -Level "Info"
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Log "Este script deve ser executado como administrador" -Level "Error"
    exit 1
} else {
    Write-Log "Executando com privilégios administrativos" -Level "Success"
}

# Verificar versão do PowerShell
Write-Log "Verificando versão do PowerShell..." -Level "Info"
$psVersion = $PSVersionTable.PSVersion
Write-Log "Versão do PowerShell: $($psVersion.Major).$($psVersion.Minor).$($psVersion.Patch)" -Level "Info"

if ($psVersion.Major -lt 5) {
    Write-Log "É necessário PowerShell 5.0 ou superior" -Level "Error"
    exit 1
} else {
    Write-Log "Versão do PowerShell compatível" -Level "Success"
}

# Verificar conectividade com a internet
Write-Log "Verificando conectividade com a internet..." -Level "Info"
try {
    $internetCheck = Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet
    if ($internetCheck) {
        Write-Log "Conectividade com a internet confirmada" -Level "Success"
    } else {
        Write-Log "Sem conectividade com a internet" -Level "Warning"
        $continue = Read-Host "Continuar mesmo sem conectividade com a internet? (S/N)"
        if ($continue -ne "S" -and $continue -ne "s") {
            Write-Log "Instalação cancelada pelo usuário" -Level "Info"
            exit 1
        }
    }
} catch {
    Write-Log "Erro ao verificar conectividade com a internet: $_" -Level "Warning"
    $continue = Read-Host "Continuar mesmo com erro na verificação de conectividade? (S/N)"
    if ($continue -ne "S" -and $continue -ne "s") {
        Write-Log "Instalação cancelada pelo usuário" -Level "Info"
        exit 1
    }
}

# Verificar espaço em disco
Write-Log "Verificando espaço em disco..." -Level "Info"
$drive = (Get-Item $ProjectRoot).PSDrive
$freeSpaceGB = [math]::Round($drive.Free / 1GB, 2)
$totalSpaceGB = [math]::Round(($drive.Free + $drive.Used) / 1GB, 2)
$usedPercentage = [math]::Round(($drive.Used / ($drive.Free + $drive.Used)) * 100, 2)

Write-Log "Espaço livre: $freeSpaceGB GB de $totalSpaceGB GB ($usedPercentage% usado)" -Level "Info"

if ($freeSpaceGB -lt 5) {
    Write-Log "Espaço em disco insuficiente. Recomendado pelo menos 5 GB livre" -Level "Warning"
    $continue = Read-Host "Continuar mesmo com pouco espaço em disco? (S/N)"
    if ($continue -ne "S" -and $continue -ne "s") {
        Write-Log "Instalação cancelada pelo usuário" -Level "Info"
        exit 1
    }
} else {
    Write-Log "Espaço em disco suficiente" -Level "Success"
}

# Verificar se o arquivo .env existe
Write-Log "Verificando arquivo de configuração .env..." -Level "Info"
$envFile = Join-Path -Path $ProjectRoot -ChildPath ".env"
$envExampleFile = Join-Path -Path $ProjectRoot -ChildPath ".env.example"

if (Test-Path $envFile) {
    Write-Log "Arquivo .env encontrado" -Level "Success"
} else {
    Write-Log "Arquivo .env não encontrado" -Level "Warning"
    
    if (Test-Path $envExampleFile) {
        $createEnv = Read-Host "Deseja criar o arquivo .env a partir do .env.example? (S/N)"
        if ($createEnv -eq "S" -or $createEnv -eq "s") {
            try {
                Copy-Item -Path $envExampleFile -Destination $envFile
                Write-Log "Arquivo .env criado a partir do .env.example" -Level "Success"
                Write-Log "IMPORTANTE: Edite o arquivo .env com suas configurações antes de continuar" -Level "Warning"
                
                $editNow = Read-Host "Deseja abrir o arquivo .env para edição agora? (S/N)"
                if ($editNow -eq "S" -or $editNow -eq "s") {
                    Start-Process notepad.exe -ArgumentList $envFile
                    Write-Log "Arquivo .env aberto para edição" -Level "Info"
                    
                    $continue = Read-Host "Pressione ENTER quando terminar de editar o arquivo .env"
                }
            } catch {
                Write-Log "Erro ao criar arquivo .env: $_" -Level "Error"
                exit 1
            }
        } else {
            Write-Log "Instalação não pode continuar sem o arquivo .env" -Level "Error"
            exit 1
        }
    } else {
        Write-Log "Arquivo .env.example não encontrado. Não é possível criar o arquivo .env" -Level "Error"
        exit 1
    }
}

# Verificar diretórios necessários
Write-Log "Verificando diretórios necessários..." -Level "Info"
$requiredDirs = @(
    (Join-Path -Path $ProjectRoot -ChildPath "data"),
    (Join-Path -Path $ProjectRoot -ChildPath "logs"),
    (Join-Path -Path $ProjectRoot -ChildPath "backups"),
    (Join-Path -Path $ProjectRoot -ChildPath "nginx\conf.d"),
    (Join-Path -Path $ProjectRoot -ChildPath "nginx\ssl"),
    (Join-Path -Path $ProjectRoot -ChildPath "nginx\logs")
)

foreach ($dir in $requiredDirs) {
    if (-not (Test-Path $dir)) {
        Write-Log "Criando diretório: $dir" -Level "Info"
        try {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
            Write-Log "Diretório criado: $dir" -Level "Success"
        } catch {
            Write-Log "Erro ao criar diretório $dir: $_" -Level "Error"
            exit 1
        }
    } else {
        Write-Log "Diretório existente: $dir" -Level "Info"
    }
}

# Verificação concluída com sucesso
Write-Log "Verificação de ambiente concluída com sucesso" -Level "Success"
exit 0