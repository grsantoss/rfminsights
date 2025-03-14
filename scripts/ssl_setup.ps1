# ssl_setup.ps1 - Script para configuração de certificados SSL para o RFM Insights no Windows
# Este script pode ser executado em ambientes de desenvolvimento ou produção

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
    
    # Opcionalmente, você pode decidir se deseja encerrar o script ou continuar
    # Exit 1
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

# Função para verificar se um certificado é válido
function Verify-Certificate {
    param (
        [string]$CertPath,
        [string]$KeyPath
    )
    
    if (-not (Test-Path -Path $CertPath) -or -not (Test-Path -Path $KeyPath)) {
        Write-Log "Certificado ou chave não encontrados: $CertPath, $KeyPath" -Level "Error"
        return $false
    }
    
    try {
        # Verificar se o arquivo de certificado é válido
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
        $cert.Import($CertPath)
        
        Write-Log "Certificado válido: $CertPath" -Level "Success"
        Write-Log "  Emitido para: $($cert.Subject)" -Level "Info"
        Write-Log "  Emitido por: $($cert.Issuer)" -Level "Info"
        Write-Log "  Válido de: $($cert.NotBefore) até $($cert.NotAfter)" -Level "Info"
        
        return $true
    } catch {
        Handle-Error -ErrorRecord $_ -CustomMessage "Falha ao verificar certificado"
        return $false
    }
}

# Definir diretório de instalação
$InstallDir = "$env:USERPROFILE\rfminsights"
Write-Log "Usando diretório de instalação: $InstallDir" -Level "Info"

# Garantir que o diretório SSL existe
$SSLDir = "$InstallDir\nginx\ssl"
Ensure-Directory -DirectoryPath $SSLDir

# Função para gerar certificados autoassinados
function Generate-SelfSignedCerts {
    Write-Log "Gerando certificados SSL autoassinados..." -Level "Info"
    
    try {
        # Gerar certificado para o frontend
        $frontendCertPath = "$SSLDir\frontend.crt"
        $frontendKeyPath = "$SSLDir\frontend.key"
        $frontendPfxPath = "$SSLDir\frontend.pfx"
        
        if (-not (Test-Path -Path $frontendCertPath)) {
            Write-Log "Gerando certificado para o frontend..." -Level "Info"
            $frontendCert = New-SelfSignedCertificate -DnsName "app.rfminsights.com.br" -CertStoreLocation "cert:\LocalMachine\My" -NotAfter (Get-Date).AddYears(1)
            $certPassword = ConvertTo-SecureString -String "RFMInsights2023!" -Force -AsPlainText
            
            # Exportar para PFX
            Export-PfxCertificate -Cert "cert:\LocalMachine\My\$($frontendCert.Thumbprint)" -FilePath $frontendPfxPath -Password $certPassword | Out-Null
            
            # Exportar para CRT/KEY (requer OpenSSL)
            if (Get-Command openssl -ErrorAction SilentlyContinue) {
                # Exportar certificado
                & openssl pkcs12 -in $frontendPfxPath -clcerts -nokeys -out $frontendCertPath -passin pass:"RFMInsights2023!"
                # Exportar chave privada
                & openssl pkcs12 -in $frontendPfxPath -nocerts -out $frontendKeyPath -passin pass:"RFMInsights2023!" -passout pass:"temp"
                # Remover senha da chave privada
                & openssl rsa -in $frontendKeyPath -out $frontendKeyPath -passin pass:"temp"
            } else {
                Write-Log "OpenSSL não encontrado. Apenas o arquivo PFX foi gerado." -Level "Warning"
                Write-Log "Para usar com Nginx, instale OpenSSL e converta o PFX para os formatos CRT e KEY." -Level "Warning"
            }
            
            Write-Log "Certificado frontend gerado com sucesso" -Level "Success"
        } else {
            Write-Log "Certificado frontend já existe: $frontendCertPath" -Level "Info"
        }
        
        # Gerar certificado para a API
        $apiCertPath = "$SSLDir\api.crt"
        $apiKeyPath = "$SSLDir\api.key"
        $apiPfxPath = "$SSLDir\api.pfx"
        
        if (-not (Test-Path -Path $apiCertPath)) {
            Write-Log "Gerando certificado para a API..." -Level "Info"
            $apiCert = New-SelfSignedCertificate -DnsName "api.rfminsights.com.br" -CertStoreLocation "cert:\LocalMachine\My" -NotAfter (Get-Date).AddYears(1)
            $certPassword = ConvertTo-SecureString -String "RFMInsights2023!" -Force -AsPlainText
            
            # Exportar para PFX
            Export-PfxCertificate -Cert "cert:\LocalMachine\My\$($apiCert.Thumbprint)" -FilePath $apiPfxPath -Password $certPassword | Out-Null
            
            # Exportar para CRT/KEY (requer OpenSSL)
            if (Get-Command openssl -ErrorAction SilentlyContinue) {
                # Exportar certificado
                & openssl pkcs12 -in $apiPfxPath -clcerts -nokeys -out $apiCertPath -passin pass:"RFMInsights2023!"
                # Exportar chave privada
                & openssl pkcs12 -in $apiPfxPath -nocerts -out $apiKeyPath -passin pass:"RFMInsights2023!" -passout pass:"temp"
                # Remover senha da chave privada
                & openssl rsa -in $apiKeyPath -out $apiKeyPath -passin pass:"temp"
            }
            
            Write-Log "Certificado API gerado com sucesso" -Level "Success"
        } else {
            Write-Log "Certificado API já existe: $apiCertPath" -Level "Info"
        }
        
        # Verificar certificados
        Verify-Certificate -CertPath $frontendCertPath -KeyPath $frontendKeyPath
        Verify-Certificate -CertPath $apiCertPath -KeyPath $apiKeyPath
        
    } catch {
        Handle-Error -ErrorRecord $_ -CustomMessage "Falha ao gerar certificados SSL"
    }
}

# Função para importar certificados existentes
function Import-ExistingCerts {
    param (
        [string]$FrontendCertPath,
        [string]$FrontendKeyPath,
        [string]$ApiCertPath,
        [string]$ApiKeyPath
    )
    
    Write-Log "Importando certificados existentes..." -Level "Info"
    
    try {
        # Copiar certificados para o diretório SSL
        Copy-Item -Path $FrontendCertPath -Destination "$SSLDir\frontend.crt" -Force
        Copy-Item -Path $FrontendKeyPath -Destination "$SSLDir\frontend.key" -Force
        Copy-Item -Path $ApiCertPath -Destination "$SSLDir\api.crt" -Force
        Copy-Item -Path $ApiKeyPath -Destination "$SSLDir\api.key" -Force
        
        Write-Log "Certificados importados com sucesso" -Level "Success"
        
        # Verificar certificados
        Verify-Certificate -CertPath "$SSLDir\frontend.crt" -KeyPath "$SSLDir\frontend.key"
        Verify-Certificate -CertPath "$SSLDir\api.crt" -KeyPath "$SSLDir\api.key"
        
    } catch {
        Handle-Error -ErrorRecord $_ -CustomMessage "Falha ao importar certificados"
    }
}

# Menu principal
Write-Host "==================================================" -ForegroundColor $InfoColor
Write-Host "      Configuração de Certificados SSL          " -ForegroundColor $InfoColor
Write-Host "==================================================" -ForegroundColor $InfoColor
Write-Host "1. Gerar certificados autoassinados (desenvolvimento)" -ForegroundColor $InfoColor
Write-Host "2. Importar certificados existentes" -ForegroundColor $InfoColor
Write-Host "3. Verificar certificados existentes" -ForegroundColor $InfoColor
Write-Host "4. Sair" -ForegroundColor $InfoColor
Write-Host "==================================================" -ForegroundColor $InfoColor

$option = Read-Host "Escolha uma opção (1-4)"

switch ($option) {
    "1" {
        Generate-SelfSignedCerts
    }
    "2" {
        $frontendCertPath = Read-Host "Caminho para o certificado frontend (CRT)"
        $frontendKeyPath = Read-Host "Caminho para a chave privada frontend (KEY)"
        $apiCertPath = Read-Host "Caminho para o certificado API (CRT)"
        $apiKeyPath = Read-Host "Caminho para a chave privada API (KEY)"
        
        Import-ExistingCerts -FrontendCertPath $frontendCertPath -FrontendKeyPath $frontendKeyPath -ApiCertPath $apiCertPath -ApiKeyPath $apiKeyPath
    }
    "3" {
        $frontendCertPath = "$SSLDir\frontend.crt"
        $frontendKeyPath = "$SSLDir\frontend.key"
        $apiCertPath = "$SSLDir\api.crt"
        $apiKeyPath = "$SSLDir\api.key"
        
        if ((Test-Path -Path $frontendCertPath) -and (Test-Path -Path $frontendKeyPath) -and 
            (Test-Path -Path $apiCertPath) -and (Test-Path -Path $apiKeyPath)) {
            Write-Log "Verificando certificados existentes..." -Level "Info"
            Verify-Certificate -CertPath $frontendCertPath -KeyPath $frontendKeyPath
            Verify-Certificate -CertPath $apiCertPath -KeyPath $apiKeyPath
        } else {
            Write-Log "Certificados não encontrados em $SSLDir" -Level "Error"
        }
    }
    "4" {
        Write-Log "Saindo..." -Level "Info"
        exit 0
    }
    default {
        Write-Log "Opção inválida" -Level "Error"
        exit 1
    }
}

Write-Log "Configuração de certificados SSL concluída com sucesso!" -Level "Success"
exit 0