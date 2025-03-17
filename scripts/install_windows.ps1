# RFM Insights - Universal Installation Script for Windows
# This script handles the complete installation process for RFM Insights on Windows

# Script configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Set project root directory and log file
$ProjectRoot = $PSScriptRoot
$LogFile = Join-Path -Path $ProjectRoot -ChildPath "install.log"

# Create log file
New-Item -Path $LogFile -ItemType File -Force | Out-Null

# Logging functions
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
    
    # Also append to log file
    "[$timestamp] [$Level] $Message" | Out-File -FilePath $LogFile -Append
}

# Error handling function
function Handle-Error {
    param (
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        
        [Parameter(Mandatory=$true)]
        [string]$CustomMessage
    )
    
    Write-Log "$CustomMessage: $($ErrorRecord.Exception.Message)" -Level "Error"
    Write-Log "Installation failed. Please check the log file at $LogFile for details." -Level "Error"
    exit 1
}

# Banner
Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "          RFM INSIGHTS - INSTALLATION           " -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "Starting RFM Insights installation on Windows" -Level "Info"
Write-Log "Project directory: $ProjectRoot" -Level "Info"

# Step 1: Check for Administrator privileges
Write-Log "Checking for Administrator privileges..." -Level "Info"
try {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Log "This script requires Administrator privileges. Please run PowerShell as Administrator." -Level "Error"
        exit 1
    }
    
    Write-Log "Administrator privileges confirmed" -Level "Success"
} catch {
    Handle-Error -ErrorRecord $_ -CustomMessage "Failed to check Administrator privileges"
}

# Step 2: Check for Docker Desktop
Write-Log "Checking for Docker Desktop..." -Level "Info"
try {
    $dockerPath = (Get-Command docker -ErrorAction SilentlyContinue).Source
    
    if (-not $dockerPath) {
        Write-Log "Docker Desktop not found. Please install Docker Desktop for Windows." -Level "Error"
        Write-Log "Download from: https://www.docker.com/products/docker-desktop" -Level "Info"
        exit 1
    }
    
    # Check Docker version
    $dockerVersion = docker version --format '{{.Server.Version}}' 2>$null
    if (-not $dockerVersion) {
        Write-Log "Docker is installed but not running. Please start Docker Desktop." -Level "Error"
        exit 1
    }
    
    Write-Log "Docker Desktop found (version $dockerVersion)" -Level "Success"
    
    # Check Docker Compose
    $composeVersion = docker compose version --short 2>$null
    if (-not $composeVersion) {
        Write-Log "Docker Compose not found. It should be included with Docker Desktop." -Level "Error"
        exit 1
    }
    
    Write-Log "Docker Compose found (version $composeVersion)" -Level "Success"
} catch {
    Handle-Error -ErrorRecord $_ -CustomMessage "Failed to check Docker installation"
}

# Step 3: Create necessary directories
Write-Log "Creating necessary directories..." -Level "Info"
try {
    $directories = @(
        "$ProjectRoot\nginx\ssl",
        "$ProjectRoot\nginx\logs",
        "$ProjectRoot\data",
        "$ProjectRoot\backups"
    )
    
    foreach ($dir in $directories) {
        if (-not (Test-Path -Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
            Write-Log "Created directory: $dir" -Level "Info"
        }
    }
    
    Write-Log "Directory structure created successfully" -Level "Success"
} catch {
    Handle-Error -ErrorRecord $_ -CustomMessage "Failed to create directories"
}

# Step 4: Generate SSL certificates
Write-Log "Setting up SSL certificates..." -Level "Info"
try {
    $sslDir = "$ProjectRoot\nginx\ssl"
    $apiCert = "$sslDir\api.crt"
    $apiKey = "$sslDir\api.key"
    $frontendCert = "$sslDir\frontend.crt"
    $frontendKey = "$sslDir\frontend.key"
    
    $needCerts = (-not (Test-Path $apiCert)) -or (-not (Test-Path $apiKey)) -or 
                 (-not (Test-Path $frontendCert)) -or (-not (Test-Path $frontendKey))
    
    if ($needCerts) {
        Write-Log "SSL certificates missing. Generating self-signed certificates..." -Level "Info"
        
        # Check for OpenSSL
        $openSSL = Get-Command openssl -ErrorAction SilentlyContinue
        if (-not $openSSL) {
            Write-Log "OpenSSL not found. Installing OpenSSL using Chocolatey..." -Level "Warning"
            
            # Check for Chocolatey
            $choco = Get-Command choco -ErrorAction SilentlyContinue
            if (-not $choco) {
                Write-Log "Chocolatey not found. Installing Chocolatey..." -Level "Info"
                Set-ExecutionPolicy Bypass -Scope Process -Force
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
                
                # Refresh environment variables
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            }
            
            # Install OpenSSL
            choco install openssl -y
            
            # Refresh environment variables
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            
            # Check OpenSSL again
            $openSSL = Get-Command openssl -ErrorAction SilentlyContinue
            if (-not $openSSL) {
                Write-Log "Failed to install OpenSSL. Please install it manually." -Level "Error"
                exit 1
            }
        }
        
        # Generate API certificate
        Write-Log "Generating API certificate..." -Level "Info"
        & openssl req -x509 -nodes -days 365 -newkey rsa:2048 `
            -keyout $apiKey `
            -out $apiCert `
            -subj "/CN=api.rfminsights.com.br/O=RFM Insights/C=BR" `
            -addext "subjectAltName=DNS:api.rfminsights.com.br,DNS:localhost"
        
        # Generate Frontend certificate
        Write-Log "Generating Frontend certificate..." -Level "Info"
        & openssl req -x509 -nodes -days 365 -newkey rsa:2048 `
            -keyout $frontendKey `
            -out $frontendCert `
            -subj "/CN=app.rfminsights.com.br/O=RFM Insights/C=BR" `
            -addext "subjectAltName=DNS:app.rfminsights.com.br,DNS:localhost"
        
        Write-Log "SSL certificates generated successfully" -Level "Success"
    } else {
        Write-Log "SSL certificates already exist" -Level "Success"
    }
} catch {
    Handle-Error -ErrorRecord $_ -CustomMessage "Failed to generate SSL certificates"
}

# Step 5: Setup environment file
Write-Log "Setting up environment file..." -Level "Info"
try {
    $envFile = "$ProjectRoot\.env"
    $envExampleFile = "$ProjectRoot\.env.example"
    
    if (-not (Test-Path $envFile)) {
        if (Test-Path $envExampleFile) {
            Write-Log "Creating .env file from example..." -Level "Info"
            Copy-Item -Path $envExampleFile -Destination $envFile
            
            # Update database connection for Docker
            Write-Log "Updating database connection string..." -Level "Info"
            (Get-Content $envFile) -replace 'DATABASE_URL=.*', 'DATABASE_URL=postgresql://rfminsights:rfminsights_password@rfminsights-postgres/rfminsights' | Set-Content $envFile
            
            Write-Log "Environment file created and configured" -Level "Success"
        } else {
            Write-Log ".env.example file not found. Cannot create environment file." -Level "Error"
            exit 1
        }
    } else {
        Write-Log "Checking database connection string in .env..." -Level "Info"
        $envContent = Get-Content $envFile -Raw
        
        if ($envContent -match 'DATABASE_URL=postgresql://rfminsights:rfminsights_password@rfminsights-postgres/rfminsights') {
            Write-Log "Database connection string is correctly configured" -Level "Success"
        } else {
            Write-Log "Database connection string may be incorrect in .env file" -Level "Warning"
            Write-Log "Updating database connection string..." -Level "Info"
            (Get-Content $envFile) -replace 'DATABASE_URL=.*', 'DATABASE_URL=postgresql://rfminsights:rfminsights_password@rfminsights-postgres/rfminsights' | Set-Content $envFile
            Write-Log "Database connection string updated" -Level "Success"
        }
    }
} catch {
    Handle-Error -ErrorRecord $_ -CustomMessage "Failed to setup environment file"
}

# Step 6: Create health check file for frontend
Write-Log "Setting up health check endpoint..." -Level "Info"
try {
    $healthFile = "$ProjectRoot\frontend\health.html"
    
    if (-not (Test-Path $healthFile)) {
        Write-Log "Creating health.html for frontend..." -Level "Info"
        
        # Ensure frontend directory exists
        if (-not (Test-Path "$ProjectRoot\frontend")) {
            New-Item -Path "$ProjectRoot\frontend" -ItemType Directory -Force | Out-Null
        }
        
        "<!DOCTYPE html><html><head><title>Health Check</title></head><body>OK</body></html>" | Out-File -FilePath $healthFile -Encoding utf8
        Write-Log "Frontend health check file created" -Level "Success"
    } else {
        Write-Log "Frontend health check file already exists" -Level "Success"
    }
} catch {
    Handle-Error -ErrorRecord $_ -CustomMessage "Failed to create health check file"
}

# Step 7: Start Docker services
Write-Log "Starting Docker services..." -Level "Info"
try {
    # Stop any running containers
    Write-Log "Stopping any running containers..." -Level "Info"
    docker-compose down 2>$null
    
    # Build and start containers
    Write-Log "Building and starting containers..." -Level "Info"
    docker-compose up -d --build
    
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Failed to start Docker services. Check the Docker logs for details." -Level "Error"
        exit 1
    }
    
    Write-Log "Docker services started successfully" -Level "Success"
} catch {
    Handle-Error -ErrorRecord $_ -CustomMessage "Failed to start Docker services"
}

# Step 8: Verify services are running
Write-Log "Verifying services..." -Level "Info"
try {
    # Give services time to start
    Start-Sleep -Seconds 10
    
    # Check API service
    Write-Log "Checking API service..." -Level "Info"
    $apiRunning = docker ps | Select-String "rfminsights-api"
    if ($apiRunning) {
        Write-Log "API service is running" -Level "Success"
    } else {
        Write-Log "API service may not be running. Check with 'docker-compose logs api'" -Level "Warning"
    }
    
    # Check frontend service
    Write-Log "Checking frontend service..." -Level "Info"
    $frontendRunning = docker ps | Select-String "rfminsights-frontend"
    if ($frontendRunning) {
        Write-Log "Frontend service is running" -Level "Success"
    } else {
        Write-Log "Frontend service may not be running. Check with 'docker-compose logs frontend'" -Level "Warning"
    }
    
    # Check database service
    Write-Log "Checking database service..." -Level "Info"
    $dbRunning = docker ps | Select-String "rfminsights-postgres"
    if ($dbRunning) {
        Write-Log "Database service is running" -Level "Success"
    } else {
        Write-Log "Database service may not be running. Check with 'docker-compose logs postgres'" -Level "Warning"
    }
} catch {
    Handle-Error -ErrorRecord $_ -CustomMessage "Failed to verify services