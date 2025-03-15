# RFM Insights - Script de Instalação Modular
# Este script coordena a instalação do RFM Insights em etapas separadas

# Configuração do script
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Variáveis globais
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptPath
$ModulesPath = Join-Path -Path $ScriptPath -ChildPath "modules"
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

# Função para verificar se um módulo existe
function Test-Module {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ModuleName
    )
    
    $modulePath = Join-Path -Path $ModulesPath -ChildPath "$ModuleName.ps1"
    return Test-Path $modulePath
}

# Função para executar um módulo
function Invoke-Module {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ModuleName
    )
    
    $modulePath = Join-Path -Path $ModulesPath -ChildPath "$ModuleName.ps1"
    
    if (Test-Path $modulePath) {
        Write-Log "Executando módulo: $ModuleName" -Level "Info"
        try {
            & $modulePath
            if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) {
                Write-Log "Módulo $ModuleName concluído com sucesso" -Level "Success"
                return $true
            } else {
                Write-Log "Módulo $ModuleName falhou com código de saída $LASTEXITCODE" -Level "Error"
                return $false
            }
        } catch {
            Write-Log "Erro ao executar o módulo $ModuleName: $_" -Level "Error"
            return $false
        }
    } else {
        Write-Log "Módulo $ModuleName não encontrado" -Level "Error"
        return $false
    }
}

# Banner
Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "          RFM INSIGHTS INSTALAÇÃO MODULAR         " -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

# Iniciar log de instalação
Write-Log "Iniciando instalação modular do RFM Insights" -Level "Info"
Write-Log "Diretório do projeto: $ProjectRoot" -Level "Info"

# Verificar se o diretório de módulos existe
if (-not (Test-Path $ModulesPath)) {
    Write-Log "Criando diretório de módulos..." -Level "Info"
    New-Item -Path $ModulesPath -ItemType Directory -Force | Out-Null
}

# Lista de módulos disponíveis
$availableModules = @(
    "01-environment-check",
    "02-dependencies",
    "03-docker-setup",
    "04-database-setup",
    "05-nginx-setup",
    "06-ssl-setup",
    "07-final-setup"
)

# Verificar quais módulos estão disponíveis
$missingModules = @()
foreach ($module in $availableModules) {
    if (-not (Test-Module $module)) {
        $missingModules += $module
    }
}

if ($missingModules.Count -gt 0) {
    Write-Log "Os seguintes módulos estão faltando:" -Level "Warning"
    foreach ($module in $missingModules) {
        Write-Log "  - $module" -Level "Warning"
    }
    
    $continue = Read-Host "Alguns módulos estão faltando. Deseja continuar com os módulos disponíveis? (S/N)"
    if ($continue -ne "S" -and $continue -ne "s") {
        Write-Log "Instalação cancelada pelo usuário" -Level "Info"
        exit 1
    }
}

# Menu de instalação
Write-Host ""
Write-Host "Opções de Instalação:" -ForegroundColor Cyan
Write-Host "1. Instalação Completa (Todos os módulos)" -ForegroundColor White
Write-Host "2. Instalação Personalizada (Selecionar módulos)" -ForegroundColor White
Write-Host "3. Sair" -ForegroundColor White
Write-Host ""

$option = Read-Host "Escolha uma opção (1-3)"

switch ($option) {
    "1" {
        Write-Log "Iniciando instalação completa..." -Level "Info"
        
        $allSuccess = $true
        foreach ($module in $availableModules) {
            if (Test-Module $module) {
                $success = Invoke-Module $module
                if (-not $success) {
                    $allSuccess = $false
                    $continue = Read-Host "O módulo $module falhou. Deseja continuar com os próximos módulos? (S/N)"
                    if ($continue -ne "S" -and $continue -ne "s") {
                        Write-Log "Instalação interrompida pelo usuário após falha no módulo $module" -Level "Info"
                        exit 1
                    }
                }
            } else {
                Write-Log "Pulando módulo ausente: $module" -Level "Warning"
            }
        }
        
        if ($allSuccess) {
            Write-Log "Instalação completa concluída com sucesso!" -Level "Success"
        } else {
            Write-Log "Instalação completa concluída com avisos ou erros. Verifique o log para mais detalhes." -Level "Warning"
        }
    }
    "2" {
        Write-Log "Iniciando instalação personalizada..." -Level "Info"
        
        Write-Host ""
        Write-Host "Módulos Disponíveis:" -ForegroundColor Cyan
        
        $i = 1
        foreach ($module in $availableModules) {
            $status = if (Test-Module $module) { "[Disponível]" } else { "[Indisponível]" }
            Write-Host "$i. $module $status" -ForegroundColor $(if (Test-Module $module) { "White" } else { "Gray" })
            $i++
        }
        
        Write-Host ""
        $selectedModules = Read-Host "Digite os números dos módulos que deseja instalar (separados por vírgula, ex: 1,3,5)"
        
        $selectedIndices = $selectedModules -split ',' | ForEach-Object { $_.Trim() }
        
        foreach ($index in $selectedIndices) {
            $moduleIndex = [int]$index - 1
            if ($moduleIndex -ge 0 -and $moduleIndex -lt $availableModules.Count) {
                $module = $availableModules[$moduleIndex]
                if (Test-Module $module) {
                    $success = Invoke-Module $module
                    if (-not $success) {
                        $continue = Read-Host "O módulo $module falhou. Deseja continuar com os próximos módulos? (S/N)"
                        if ($continue -ne "S" -and $continue -ne "s") {
                            Write-Log "Instalação interrompida pelo usuário após falha no módulo $module" -Level "Info"
                            exit 1
                        }
                    }
                } else {
                    Write-Log "Módulo indisponível: $module" -Level "Warning"
                }
            } else {
                Write-Log "Índice de módulo inválido: $index" -Level "Warning"
            }
        }
        
        Write-Log "Instalação personalizada concluída" -Level "Success"
    }
    "3" {
        Write-Log "Instalação cancelada pelo usuário" -Level "Info"
        exit 0
    }
    default {
        Write-Log "Opção inválida" -Level "Error"
        exit 1
    }
}

Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "          INSTALAÇÃO CONCLUÍDA                   " -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Log de instalação disponível em: $LogFile" -ForegroundColor White
Write-Host ""