# RFM Insights - SSL Certificate Generation Script
# This script generates self-signed SSL certificates for development and testing

# Import common functions
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$CommonFunctions = Join-Path -Path $ScriptDir -ChildPath "common_functions.ps1"
if (Test-Path $CommonFunctions) {
    . $CommonFunctions
} else {
    function Write-Log {
        param (
            [string]$Message,
            [string]$Level = "Info"
        )
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $colorMap = @{
            "Info" = "White"
            "Success" = "Green"
            "Warning" = "Yellow"
            "Error" = "Red"
        }
        
        $color = $colorMap[$Level]
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    }
}

# Set the project root directory
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$SSLDir = Join-Path -Path $ProjectRoot -ChildPath "nginx\ssl"

# Create SSL directory if it doesn't exist
if (-not (Test-Path $SSLDir)) {
    Write-Log "Creating SSL directory..." -Level "Info"
    New-Item -Path $SSLDir -ItemType Directory -Force | Out-Null
    Write-Log "SSL directory created at $SSLDir" -Level "Success"
}

# Check if OpenSSL is installed
$openSSLInstalled = $null
try {
    $openSSLInstalled = Get-Command openssl -ErrorAction SilentlyContinue
} catch {
    # Command not found
}

if (-not $openSSLInstalled) {
    Write-Log "OpenSSL is not installed or not in PATH. Please install OpenSSL to generate certificates." -Level "Error"
    Write-Log "You can download OpenSSL from https://slproweb.com/products/Win32OpenSSL.html" -Level "Info"
    exit 1
}

Write-Log "OpenSSL is installed. Proceeding with certificate generation." -Level "Success"

# Function to generate a self-signed certificate
function Generate-SelfSignedCertificate {
    param (
        [string]$CertName,
        [string]$Domain,
        [string]$OutputDir
    )
    
    $keyFile = Join-Path -Path $OutputDir -ChildPath "$CertName.key"
    $crtFile = Join-Path -Path $OutputDir -ChildPath "$CertName.crt"
    
    # Check if certificate already exists
    if ((Test-Path $keyFile) -and (Test-Path $crtFile)) {
        Write-Log "Certificate files for $CertName already exist." -Level "Warning"
        $overwrite = Read-Host "Do you want to overwrite them? (Y/N)"
        if ($overwrite -ne "Y" -and $overwrite -ne "y") {
            Write-Log "Skipping certificate generation for $CertName." -Level "Info"
            return
        }
    }
    
    Write-Log "Generating self-signed certificate for $Domain..." -Level "Info"
    
    # Generate private key and certificate
    $opensslCmd = "openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout `"$keyFile`" -out `"$crtFile`" -subj "/CN=$Domain/O=RFM Insights/C=BR" -addext `"subjectAltName=DNS:$Domain,DNS:localhost`""
    
    try {
        Invoke-Expression $opensslCmd | Out-Null
        
        if ((Test-Path $keyFile) -and (Test-Path $crtFile)) {
            Write-Log "Certificate for $Domain generated successfully." -Level "Success"
            Write-Log "Key file: $keyFile" -Level "Info"
            Write-Log "Certificate file: $crtFile" -Level "Info"
            
            # Set appropriate permissions
            try {
                # Make key file readable only by owner
                $acl = Get-Acl $keyFile
                $acl.SetAccessRuleProtection($true, $false)
                $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("$env:USERNAME","FullControl","Allow")
                $acl.AddAccessRule($rule)
                Set-Acl $keyFile $acl
                
                Write-Log "Permissions set for $keyFile" -Level "Success"
            } catch {
                Write-Log "Failed to set permissions on key file: $_" -Level "Warning"
            }
        } else {
            Write-Log "Failed to generate certificate files for $Domain." -Level "Error"
        }
    } catch {
        Write-Log "Error generating certificate: $_" -Level "Error"
    }
}

# Generate certificates for API and Frontend
Generate-SelfSignedCertificate -CertName "api" -Domain "api.rfminsights.com.br" -OutputDir $SSLDir
Generate-SelfSignedCertificate -CertName "frontend" -Domain "app.rfminsights.com.br" -OutputDir $SSLDir

# Inform user about next steps
Write-Log "SSL certificates have been generated." -Level "Success"
Write-Log "To use these certificates in a production environment, you should replace them with properly signed certificates from a trusted CA." -Level "Info"

# Ask if user wants to restart Nginx to apply changes
$restartNginx = Read-Host "Do you want to restart the Nginx container to apply the new certificates? (Y/N)"
if ($restartNginx -eq "Y" -or $restartNginx -eq "y") {
    Write-Log "Restarting Nginx container..." -Level "Info"
    try {
        docker-compose -f "$ProjectRoot\docker-compose.yml" restart nginx-proxy
        Write-Log "Nginx container restarted successfully." -Level "Success"
    } catch {
        Write-Log "Failed to restart Nginx container: $_" -Level "Error"
        Write-Log "Please restart the container manually using: docker-compose restart nginx-proxy" -Level "Info"
    }
} else {
    Write-Log "Remember to restart the Nginx container to apply the new certificates." -Level "Info"
    Write-Log "You can do this by running: docker-compose restart nginx-proxy" -Level "Info"
}

Write-Log "SSL certificate setup completed." -Level "Success"