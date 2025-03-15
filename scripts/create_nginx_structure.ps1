# create_nginx_structure.ps1 - Script para criar a estrutura de diretórios do Nginx

# Definir cores para saída
$ErrorColor = "Red"
$SuccessColor = "Green"
$WarningColor = "Yellow"
$InfoColor = "Cyan"

# Função para exibir mensagens de log
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    switch ($Level) {
        "Info" { Write-Host "$timestamp [INFO] $Message" -ForegroundColor $InfoColor }
        "Success" { Write-Host "$timestamp [SUCCESS] $Message" -ForegroundColor $SuccessColor }
        "Warning" { Write-Host "$timestamp [WARNING] $Message" -ForegroundColor $WarningColor }
        "Error" { Write-Host "$timestamp [ERROR] $Message" -ForegroundColor $ErrorColor }
        default { Write-Host "$timestamp [INFO] $Message" -ForegroundColor $InfoColor }
    }
}

# Função para tratar erros
function Handle-Error {
    param (
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [string]$CustomMessage = ""
    )
    
    if ($CustomMessage) {
        Write-Log "$CustomMessage: $($ErrorRecord.Exception.Message)" -Level "Error"
    } else {
        Write-Log "$($ErrorRecord.Exception.Message)" -Level "Error"
    }
}

# Função para verificar se um diretório existe, se não, criá-lo
function Ensure-Directory {
    param (
        [string]$DirectoryPath
    )
    
    if (-not (Test-Path -Path $DirectoryPath -PathType Container)) {
        Write-Log "Criando diretório: $DirectoryPath" -Level "Info"
        try {
            New-Item -Path $DirectoryPath -ItemType Directory -Force | Out-Null
            Write-Log "Diretório criado com sucesso: $DirectoryPath" -Level "Success"
        } catch {
            Handle-Error -ErrorRecord $_ -CustomMessage "Falha ao criar diretório"
            return $false
        }
    } else {
        Write-Log "Diretório já existe: $DirectoryPath" -Level "Info"
    }
    
    return $true
}

# Definir diretório de instalação
$InstallDir = "$env:USERPROFILE\rfminsights"
Write-Log "Usando diretório de instalação: $InstallDir" -Level "Info"

# Criar estrutura de diretórios para o Nginx
Write-Log "Criando estrutura de diretórios para o Nginx..." -Level "Info"

# Diretório principal do Nginx
$NginxDir = "$InstallDir\nginx"
Ensure-Directory -DirectoryPath $NginxDir

# Diretório para arquivos de configuração
$ConfDir = "$NginxDir\conf.d"
Ensure-Directory -DirectoryPath $ConfDir

# Diretório para certificados SSL
$SSLDir = "$NginxDir\ssl"
Ensure-Directory -DirectoryPath $SSLDir

# Diretório para logs
$LogsDir = "$NginxDir\logs"
Ensure-Directory -DirectoryPath $LogsDir

Write-Log "Estrutura de diretórios para o Nginx criada com sucesso!" -Level "Success"