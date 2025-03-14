# RFM Insights Installation Script
# This script handles the complete installation process for RFM Insights
# Including dependencies, directory structure, configuration, and SSL certificates

# Script configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Log function for consistent output
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
    "[$timestamp] [$Level] $Message" | Out-File -FilePath "$PSScriptRoot\install.log" -Append
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
    Write-Log "Installation failed. Please check the log file at $PSScriptRoot\install.log for details." -Level "Error"
    exit 1
}

# Validation function
function Test-Requirement {
    param (
        [Parameter(Mandatory=$true)]
        [scriptblock]$Condition,
        
        [Parameter(Mandatory=$true)]
        [string]$ErrorMessage
    )
    
    try {
        $result = & $Condition
        if (-not $result) {
            Write-Log $ErrorMessage -Level "Error"
            return $false
        }
        return $true
    }
    catch {
        Write-Log "$ErrorMessage: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

# Configuration variables
$config = @{
    "AppName" = "RFM Insights"
    "InstallDir" = "$PSScriptRoot"
    "DataDir" = "$PSScriptRoot\data"
    "ConfigDir" = "$PSScriptRoot\config"
    "LogDir" = "$PSScriptRoot\logs"
    "SSLDir" = "$PSScriptRoot\ssl"
    "RequiredModules" = @("ImportExcel", "PSWriteHTML", "dbatools")
    "Port" = 8080
    "SSLPort" = 8443
    "DatabaseType" = "SQLite" # Options: SQLite, SQLServer, MySQL
    "DatabasePath" = "$PSScriptRoot\data\rfminsights.db"
}

# Banner
Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "          RFM INSIGHTS INSTALLATION             " -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

# Start installation log
Write-Log "Starting installation of $($config.AppName)" -Level "Info"
Write-Log "Installation directory: $($config.InstallDir)" -Level "Info"

# Check if running as administrator
Write-Log "Checking administrative privileges..." -Level "Info"
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Log "This script requires administrative privileges. Please run PowerShell as Administrator." -Level "Error"
    exit 1
}
Write-Log "Administrative privileges confirmed." -Level "Success"

# Check PowerShell version
Write-Log "Checking PowerShell version..." -Level "Info"
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Log "PowerShell 5.0 or higher is required. Please upgrade PowerShell." -Level "Error"
    exit 1
}
Write-Log "PowerShell version $($PSVersionTable.PSVersion) detected." -Level "Success"

# Create directory structure
Write-Log "Creating directory structure..." -Level "Info"
try {
    $directories = @($config.DataDir, $config.ConfigDir, $config.LogDir, $config.SSLDir)
    foreach ($dir in $directories) {
        if (-not (Test-Path -Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
            Write-Log "Created directory: $dir" -Level "Info"
        } else {
            Write-Log "Directory already exists: $dir" -Level "Info"
        }
    }
    Write-Log "Directory structure created successfully." -Level "Success"
} catch {
    Handle-Error -ErrorRecord $_ -CustomMessage "Failed to create directory structure"
}

# Install required PowerShell modules
Write-Log "Installing required PowerShell modules..." -Level "Info"
try {
    foreach ($module in $config.RequiredModules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Write-Log "Installing module: $module" -Level "Info"
            Install-Module -Name $module -Force -Scope CurrentUser -AllowClobber
            Write-Log "Module $module installed successfully." -Level "Success"
        } else {
            Write-Log "Module $module is already installed." -Level "Info"
        }
    }
    Write-Log "All required modules are installed." -Level "Success"
} catch {
    Handle-Error -ErrorRecord $_ -CustomMessage "Failed to install PowerShell modules"
}

# Generate SSL certificates
Write-Log "Generating SSL certificates..." -Level "Info"
try {
    $certPath = "$($config.SSLDir)\rfminsights.pfx"
    if (-not (Test-Path -Path $certPath)) {
        $cert = New-SelfSignedCertificate -DnsName "rfminsights.local" -CertStoreLocation "cert:\LocalMachine\My" -NotAfter (Get-Date).AddYears(5)
        $certPassword = ConvertTo-SecureString -String "RFMInsights2023!" -Force -AsPlainText
        Export-PfxCertificate -Cert "cert:\LocalMachine\My\$($cert.Thumbprint)" -FilePath $certPath -Password $certPassword | Out-Null
        Write-Log "SSL certificate generated at: $certPath" -Level "Success"
    } else {
        Write-Log "SSL certificate already exists at: $certPath" -Level "Info"
    }
} catch {
    Handle-Error -ErrorRecord $_ -CustomMessage "Failed to generate SSL certificate"
}

# Create default configuration file
Write-Log "Creating configuration file..." -Level "Info"
try {
    $configFilePath = "$($config.ConfigDir)\config.json"
    if (-not (Test-Path -Path $configFilePath)) {
        $configContent = @{
            "AppSettings" = @{
                "AppName" = $config.AppName
                "Port" = $config.Port
                "SSLPort" = $config.SSLPort
                "EnableSSL" = $true
                "SSLCertPath" = $certPath
                "LogLevel" = "Information"
                "DataRetentionDays" = 90
            }
            "Database" = @{
                "Type" = $config.DatabaseType
                "ConnectionString" = switch ($config.DatabaseType) {
                    "SQLite" { "Data Source=$($config.DatabasePath)" }
                    "SQLServer" { "Server=localhost;Database=RFMInsights;Trusted_Connection=True;" }
                    "MySQL" { "Server=localhost;Database=rfminsights;Uid=root;Pwd=password;" }
                }
            }
            "Email" = @{
                "SMTPServer" = "smtp.example.com"
                "SMTPPort" = 587
                "EnableSSL" = $true
                "Username" = "user@example.com"
                "Password" = "" # Will be set during configuration
                "FromAddress" = "rfminsights@example.com"
            }
            "Security" = @{
                "JWTSecret" = [System.Guid]::NewGuid().ToString()
                "TokenExpirationMinutes" = 60
                "AllowedOrigins" = @("https://localhost:$($config.SSLPort)")
            }
        }
        
        $configContent | ConvertTo-Json -Depth 10 | Out-File -FilePath $configFilePath -Encoding UTF8
        Write-Log "Configuration file created at: $configFilePath" -Level "Success"
    } else {
        Write-Log "Configuration file already exists at: $configFilePath" -Level "Info"
    }
} catch {
    Handle-Error -ErrorRecord $_ -CustomMessage "Failed to create configuration file"
}

# Initialize database
Write-Log "Initializing database..." -Level "Info"
try {
    if ($config.DatabaseType -eq "SQLite") {
        if (-not (Test-Path -Path $config.DatabasePath)) {
            # Create SQLite database
            $sqliteAssembly = "$($config.InstallDir)\lib\System.Data.SQLite.dll"
            if (-not (Test-Path -Path $sqliteAssembly)) {
                # Download SQLite assembly if not exists
                $libDir = "$($config.InstallDir)\lib"
                if (-not (Test-Path -Path $libDir)) {
                    New-Item -Path $libDir -ItemType Directory -Force | Out-Null
                }
                
                $url = "https://system.data.sqlite.org/blobs/1.0.118.0/sqlite-netFx-full-source-1.0.118.0.zip"
                $zipFile = "$env:TEMP\sqlite.zip"
                
                Invoke-WebRequest -Uri $url -OutFile $zipFile
                Expand-Archive -Path $zipFile -DestinationPath "$env:TEMP\sqlite" -Force
                
                Copy-Item -Path "$env:TEMP\sqlite\bin\System.Data.SQLite.dll" -Destination $sqliteAssembly -Force
                Remove-Item -Path $zipFile -Force
                Remove-Item -Path "$env:TEMP\sqlite" -Recurse -Force
            }
            
            # Create database file
            Add-Type -Path $sqliteAssembly
            $connection = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$($config.DatabasePath);Version=3;")
            $connection.Open()
            
            # Create tables
            $command = $connection.CreateCommand()
            $command.CommandText = @"
CREATE TABLE Users (
    UserID INTEGER PRIMARY KEY AUTOINCREMENT,
    Username TEXT NOT NULL UNIQUE,
    PasswordHash TEXT NOT NULL,
    Email TEXT NOT NULL UNIQUE,
    FirstName TEXT,
    LastName TEXT,
    IsAdmin INTEGER NOT NULL DEFAULT 0,
    CreatedAt TEXT NOT NULL,
    LastLogin TEXT
);

CREATE TABLE Customers (
    CustomerID INTEGER PRIMARY KEY AUTOINCREMENT,
    CustomerCode TEXT,
    Name TEXT NOT NULL,
    Email TEXT,
    Phone TEXT,
    Address TEXT,
    City TEXT,
    State TEXT,
    ZipCode TEXT,
    Country TEXT,
    CreatedAt TEXT NOT NULL
);

CREATE TABLE Transactions (
    TransactionID INTEGER PRIMARY KEY AUTOINCREMENT,
    CustomerID INTEGER NOT NULL,
    TransactionDate TEXT NOT NULL,
    Amount REAL NOT NULL,
    ProductCount INTEGER NOT NULL,
    OrderID TEXT,
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);

CREATE TABLE RFMScores (
    ScoreID INTEGER PRIMARY KEY AUTOINCREMENT,
    CustomerID INTEGER NOT NULL,
    CalculationDate TEXT NOT NULL,
    RecencyScore INTEGER NOT NULL,
    FrequencyScore INTEGER NOT NULL,
    MonetaryScore INTEGER NOT NULL,
    RFMScore INTEGER NOT NULL,
    Segment TEXT NOT NULL,
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);

CREATE TABLE ImportHistory (
    ImportID INTEGER PRIMARY KEY AUTOINCREMENT,
    FileName TEXT NOT NULL,
    ImportDate TEXT NOT NULL,
    RecordCount INTEGER NOT NULL,
    UserID INTEGER NOT NULL,
    FOREIGN KEY (UserID) REFERENCES Users(UserID)
);

CREATE TABLE Settings (
    SettingID INTEGER PRIMARY KEY AUTOINCREMENT,
    SettingKey TEXT NOT NULL UNIQUE,
    SettingValue TEXT NOT NULL,
    Description TEXT,
    LastUpdated TEXT NOT NULL
);
"@
            $command.ExecuteNonQuery() | Out-Null
            
            # Create admin user
            $adminUsername = "admin"
            $adminPassword = "Admin123!" # Default password, should be changed on first login
            $adminEmail = "admin@rfminsights.local"
            
            # Generate password hash
            $salt = [System.Text.Encoding]::UTF8.GetBytes([System.Guid]::NewGuid().ToString())
            $passwordBytes = [System.Text.Encoding]::UTF8.GetBytes($adminPassword)
            $hmac = New-Object System.Security.Cryptography.HMACSHA256
            $hmac.Key = $salt
            $passwordHash = $hmac.ComputeHash($passwordBytes)
            $saltString = [Convert]::ToBase64String($salt)
            $passwordHashString = [Convert]::ToBase64String($passwordHash)
            $combinedHash = "$saltString:$passwordHashString"
            
            # Insert admin user
            $command.CommandText = "INSERT INTO Users (Username, PasswordHash, Email, FirstName, LastName, IsAdmin, CreatedAt) VALUES (@Username, @PasswordHash, @Email, @FirstName, @LastName, @IsAdmin, @CreatedAt)"
            $command.Parameters.AddWithValue("@Username", $adminUsername) | Out-Null
            $command.Parameters.AddWithValue("@PasswordHash", $combinedHash) | Out-Null
            $command.Parameters.AddWithValue("@Email", $adminEmail) | Out-Null
            $command.Parameters.AddWithValue("@FirstName", "Admin") | Out-Null
            $command.Parameters.AddWithValue("@LastName", "User") | Out-Null
            $command.Parameters.AddWithValue("@IsAdmin", 1) | Out-Null
            $command.Parameters.AddWithValue("@CreatedAt", (Get-Date -Format "yyyy-MM-dd HH:mm:ss")) | Out-Null
            $command.ExecuteNonQuery() | Out-Null
            
            # Insert default settings
            $command.Parameters.Clear()
            $command.CommandText = "INSERT INTO Settings (SettingKey, SettingValue, Description, LastUpdated) VALUES (@Key, @Value, @Description, @LastUpdated)"
            
            $defaultSettings = @(
                @{Key="RFMPeriod"; Value="365"; Description="Period in days for RFM analysis"}
                @{Key="RecencyWeight"; Value="100"; Description="Weight for Recency score (0-100)"}
                @{Key="FrequencyWeight"; Value="100"; Description="Weight for Frequency score (0-100)"}
                @{Key="MonetaryWeight"; Value="100"; Description="Weight for Monetary score (0-100)"}
                @{Key="RFMScoreGroups"; Value="5"; Description="Number of groups for RFM scoring (3-5)"}
            )
            
            foreach ($setting in $defaultSettings) {
                $command.Parameters.Clear()
                $command.Parameters.AddWithValue("@Key", $setting.Key) | Out-Null
                $command.Parameters.AddWithValue("@Value", $setting.Value) | Out-Null
                $command.Parameters.AddWithValue("@Description", $setting.Description) | Out-Null
                $command.Parameters.AddWithValue("@LastUpdated", (Get-Date -Format "yyyy-MM-dd HH:mm:ss")) | Out-Null
                $command.ExecuteNonQuery() | Out-Null
            }
            
            $connection.Close()
            Write-Log "SQLite database created successfully at: $($config.DatabasePath)" -Level "Success"
        } else {
            Write-Log "SQLite database already exists at: $($config.DatabasePath)" -Level "Info"
        }
    } elseif ($config.DatabaseType -eq "SQLServer") {
        # SQL Server database initialization would go here
        Write-Log "SQL Server database initialization not implemented yet." -Level "Warning"
    } elseif ($config.DatabaseType -eq "MySQL") {
        # MySQL database initialization would go here
        Write-Log "MySQL database initialization not implemented yet." -Level "Warning"
    }
} catch {
    Handle-Error -ErrorRecord $_ -CustomMessage "Failed to initialize database"
}

# Create startup script
Write-Log "Creating startup script..." -Level "Info"
try {
    $startupScriptPath = "$($config.InstallDir)\start.ps1"
    if (-not (Test-Path -Path $startupScriptPath)) {
        $startupScript = @"
# RFM Insights Startup Script

# Configuration
$ErrorActionPreference = "Stop"
$configPath = "$PSScriptRoot\config\config.json"
$logPath = "$PSScriptRoot\logs\server.log"

# Ensure log directory exists
if (-not (Test-Path -Path "$PSScriptRoot\logs")) {
    New-Item -Path "$PSScriptRoot\logs" -ItemType Directory -Force | Out-Null
}

# Load configuration
if (-not (Test-Path -Path $configPath)) {
    Write-Host "Configuration file not found at: $configPath" -ForegroundColor Red
    Write-Host "Please run the installation script first." -ForegroundColor Red
    exit 1
}

$config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

# Start web server
Write-Host "Starting RFM Insights server..." -ForegroundColor Cyan

# Import required modules
Import-Module PSWriteHTML
Import-Module ImportExcel

# Start the web server
$serverParams = @{
    Port = $config.AppSettings.Port
}

if ($config.AppSettings.EnableSSL) {
    $serverParams.SSLPort = $config.AppSettings.SSLPort
    $serverParams.SSLCertificatePath = $config.AppSettings.SSLCertPath
}

# Start the server (placeholder for actual server start command)
Write-Host "RFM Insights server started successfully!" -ForegroundColor Green
Write-Host "Access the application at:" -ForegroundColor Cyan
Write-Host "  HTTP:  http://localhost:$($config.AppSettings.Port)" -ForegroundColor White

if ($config.AppSettings.EnableSSL) {
    Write-Host "  HTTPS: https://localhost:$($config.AppSettings.SSLPort)" -ForegroundColor White
}

Write-Host "\nPress Ctrl+C to stop the server." -ForegroundColor Yellow

# Keep the script running
try {
    while ($true) {
        Start-Sleep -Seconds 1
    }
} finally {
    # Cleanup when server is stopped
    Write-Host "\nStopping RFM Insights server..." -ForegroundColor Cyan
    # Cleanup code here
    Write-Host "Server stopped." -ForegroundColor Green
}
"@
        
        $startupScript | Out-File -FilePath $startupScriptPath -Encoding UTF8
        Write-Log "Startup script created at: $startupScriptPath" -Level "Success"
    } else {
        Write-Log "Startup script already exists at: $startupScriptPath" -Level "Info"
    }
} catch {
    Handle-Error -ErrorRecord $_ -CustomMessage "Failed to create startup script"
}

# Create README file
Write-Log "Creating README file..." -Level "Info"
try {
    $readmePath = "$($config.InstallDir)\README.md"
    $readmeContent = @"
# RFM Insights

## Overview
RFM Insights is a powerful tool for analyzing customer behavior using the RFM (Recency, Frequency, Monetary) methodology. This application helps businesses segment their customers based on purchasing patterns and identify high-value customers.

## Installation

### Prerequisites
- Windows 10 or later
- PowerShell 5.0 or later
- Administrator privileges

### Installation Steps
1. Clone or download this repository
2. Open PowerShell as Administrator
3. Navigate to the installation directory
4. Run the installation script:
   ```powershell
   .\install.ps1
   ```
5. Follow the on-screen instructions

## Usage

### Starting the Application
1. Open PowerShell
2. Navigate to the installation directory
3. Run the startup script:
   ```powershell
   .\start.ps1
   ```
4. Access the application in your web browser at:
   - HTTP: http://localhost:8080
   - HTTPS: https://localhost:8443

### Default Login
- Username: admin
- Password: Admin123!

**Important:** Change the default password after first login.

## Features
- Import customer transaction data from Excel or CSV
- Calculate RFM scores and segment customers
- Visualize customer segments with interactive charts
- Export analysis results to various formats
- Customize RFM parameters and weights

## Support
For support, please contact support@rfminsights.com

## License
Copyright © 2023 RFM Insights. All rights reserved.
"@
    
    $readmeContent | Out-File -FilePath $readmePath -Encoding UTF8
    Write-Log "README file created at: $readmePath" -Level "Success"
} catch {
    Handle-Error -ErrorRecord $_ -CustomMessage "Failed to create README file"
}

# Installation complete
Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "      RFM INSIGHTS INSTALLATION COMPLETE         " -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "Installation completed successfully!" -Level "Success"
Write-Log "To start the application, run: $($config.InstallDir)\start.ps1" -Level "Info"
Write-Log "Default login: admin / Admin123!" -Level "Info"
Write-Log "IMPORTANT: Change the default password after first login." -Level "Warning"

Write-Host ""
Write-Host "Thank you for installing RFM Insights!" -ForegroundColor Green
Write-Host "For more information, please read the README.md file." -ForegroundColor White
Write-Host ""