# RFM Insights - Universal Installation Script for Windows
# This script handles the complete installation process for RFM Insights

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

# Function to check if a module exists
function Test-Module {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ModuleName
    )
    
    $modulePath = Join-Path -Path $ModulesPath -ChildPath "$ModuleName.ps1"
    return Test-Path $modulePath
}

# Function to execute a module
function Invoke-Module {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ModuleName
    )
    
    $modulePath = Join-Path -Path $ModulesPath -ChildPath "$ModuleName.ps1"
    
    if (Test-Path $modulePath) {
        Write-Log "Executing module: $ModuleName" -Level "Info"
        try {
            & $modulePath
            if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) {
                Write-Log "Module $ModuleName completed successfully" -Level "Success"
                return $true
            } else {
                Write-Log "Module $ModuleName failed with exit code $LASTEXITCODE" -Level "Error"
                return $false
            }
        } catch {
            Write-Log "Error executing module $ModuleName: $_" -Level "Error"
            return $false
        }
    } else {
        Write-Log "Module $ModuleName not found" -Level "Error"
        return $false
    }
}

# Banner
Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "          RFM INSIGHTS - INSTALLATION           " -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "Starting RFM Insights installation on Windows" -Level "Info"
Write-Log "Project directory: $ProjectRoot" -Level "Info"

# Set modules directory
$ModulesPath = Join-Path -Path $ProjectRoot -ChildPath "scripts\modules"

# Check if modules directory exists
if (-not (Test-Path $ModulesPath)) {
    Write-Log "Modules directory not found. Creating directory..." -Level "Info"
    New-Item -Path $ModulesPath -ItemType Directory -Force | Out-Null
    Write-Log "Modules directory created" -Level "Success"
}

# List of modules to execute in order
$modules = @(
    "01-environment-check",
    "02-dependencies",
    "03-docker-setup",
    "04-database-setup",
    "05-nginx-setup",
    "06-ssl-setup",
    "07-final-setup"
)

# Execute each module in sequence
foreach ($module in $modules) {
    Write-Log "Starting module: $module" -Level "Info"
    
    if (Test-Module $module) {
        $success = Invoke-Module $module
        
        if (-not $success) {
            Write-Log "Module $module failed. Installation cannot continue." -Level "Error"
            exit 1
        }
    } else {
        Write-Log "Module $module not found. Skipping..." -Level "Warning"
        $continue = Read-Host "Continue without this module? (Y/N)"
        
        if ($continue -ne "Y" -and $continue -ne "y") {
            Write-Log "Installation aborted by user" -Level "Info"
            exit 0
        }
    }
}

# Installation complete
Write-Log "RFM Insights installation completed successfully" -Level "Success"
Write-Log "You can now access the application at:" -Level "Info"
Write-Log "  - Frontend: https://localhost" -Level "Info"
Write-Log "  - API: https://localhost:8000" -Level "Info"
Write-Log "For more details, check the log file at: $LogFile" -Level "Info"

Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "          INSTALLATION COMPLETE                " -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""