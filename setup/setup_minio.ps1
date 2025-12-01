# Setup MinIO Server (Alternative to AWS S3)
# This script installs and configures MinIO on Windows without Docker

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MinIO Setup - S3 Alternative" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Variables
$minioVersion = "RELEASE.2024-01-01T16-36-33Z"
$minioDir = "$env:USERPROFILE\minio"
$minioDataDir = "$minioDir\data"
$minioExe = "$minioDir\minio.exe"
$minioUrl = "https://dl.min.io/server/minio/release/windows-amd64/minio.exe"

# Create directories
Write-Host "Creating MinIO directories..." -ForegroundColor Yellow
if (-not (Test-Path $minioDir)) {
    New-Item -ItemType Directory -Path $minioDir -Force | Out-Null
}
if (-not (Test-Path $minioDataDir)) {
    New-Item -ItemType Directory -Path $minioDataDir -Force | Out-Null
}

# Download MinIO
Write-Host "Downloading MinIO Server..." -ForegroundColor Yellow
if (-not (Test-Path $minioExe)) {
    try {
        Invoke-WebRequest -Uri $minioUrl -OutFile $minioExe
        Write-Host "✓ MinIO downloaded successfully" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to download MinIO: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "✓ MinIO already downloaded" -ForegroundColor Green
}

# Set environment variables
Write-Host "Setting environment variables..." -ForegroundColor Yellow
$env:MINIO_ROOT_USER = "minioadmin"
$env:MINIO_ROOT_PASSWORD = "minioadmin"

# Create startup script
$startupScript = @"
@echo off
echo Starting MinIO Server...
set MINIO_ROOT_USER=minioadmin
set MINIO_ROOT_PASSWORD=minioadmin
"$minioExe" server "$minioDataDir" --console-address ":9001"
"@

$startupScriptPath = "$minioDir\start-minio.bat"
$startupScript | Out-File -FilePath $startupScriptPath -Encoding ASCII

Write-Host "✓ Startup script created: $startupScriptPath" -ForegroundColor Green

# Install MinIO Client (mc)
Write-Host "Downloading MinIO Client (mc)..." -ForegroundColor Yellow
$mcExe = "$minioDir\mc.exe"
$mcUrl = "https://dl.min.io/client/mc/release/windows-amd64/mc.exe"

if (-not (Test-Path $mcExe)) {
    try {
        Invoke-WebRequest -Uri $mcUrl -OutFile $mcExe
        Write-Host "✓ MinIO Client downloaded successfully" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to download MinIO Client: $_" -ForegroundColor Red
    }
} else {
    Write-Host "✓ MinIO Client already downloaded" -ForegroundColor Green
}

# Create configuration script for buckets
$configScript = @"
@echo off
echo Configuring MinIO buckets...
"$mcExe" alias set local http://localhost:9000 minioadmin minioadmin
"$mcExe" mb local/transactions-raw --ignore-existing
"$mcExe" mb local/transactions-staging --ignore-existing
"$mcExe" mb local/transactions-processed --ignore-existing
echo Buckets created successfully!
"$mcExe" ls local
pause
"@

$configScriptPath = "$minioDir\configure-buckets.bat"
$configScript | Out-File -FilePath $configScriptPath -Encoding ASCII

Write-Host "✓ Configuration script created: $configScriptPath" -ForegroundColor Green

# Create README for MinIO
$readme = @"
# MinIO Server Setup

## Starting MinIO

Run the following command:
```
$startupScriptPath
```

Or manually:
```powershell
cd $minioDir
.\minio.exe server .\data --console-address ":9001"
```

## Access Points

- **API Endpoint**: http://localhost:9000
- **Console UI**: http://localhost:9001
- **Username**: minioadmin
- **Password**: minioadmin

## Configure Buckets

After starting MinIO, run:
```
$configScriptPath
```

This will create the following buckets:
- transactions-raw
- transactions-staging
- transactions-processed

## MinIO Client Commands

Set alias:
```
mc alias set local http://localhost:9000 minioadmin minioadmin
```

List buckets:
```
mc ls local
```

Upload file:
```
mc cp myfile.csv local/transactions-raw/
```

Download file:
```
mc cp local/transactions-raw/myfile.csv ./
```

## Stopping MinIO

Press Ctrl+C in the terminal where MinIO is running.

"@

$readmePath = "$minioDir\README.txt"
$readme | Out-File -FilePath $readmePath -Encoding UTF8

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  MinIO Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Installation Directory: $minioDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Start MinIO Server:" -ForegroundColor White
Write-Host "   $startupScriptPath" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Open MinIO Console:" -ForegroundColor White
Write-Host "   http://localhost:9001" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Configure Buckets:" -ForegroundColor White
Write-Host "   $configScriptPath" -ForegroundColor Gray
Write-Host ""
Write-Host "Credentials:" -ForegroundColor Yellow
Write-Host "  Username: minioadmin" -ForegroundColor White
Write-Host "  Password: minioadmin" -ForegroundColor White
Write-Host ""
