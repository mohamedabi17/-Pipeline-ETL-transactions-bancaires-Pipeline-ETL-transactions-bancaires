# Main Execution Script - Banking Transactions ETL Pipeline
# Run this script to execute the complete pipeline

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Banking Transactions ETL Pipeline" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$ErrorActionPreference = "Stop"

# Paths
$projectRoot = $PSScriptRoot
$dataRaw = "$projectRoot\data\raw"
$dataProcessed = "$projectRoot\data\processed"
$logs = "$projectRoot\logs"

# Create directories if they don't exist
@($dataRaw, $dataProcessed, $logs) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
        Write-Host "✓ Created directory: $_" -ForegroundColor Green
    }
}

# Check Python installation
Write-Host "Checking Python installation..." -ForegroundColor Yellow
try {
    $pythonVersion = python --version 2>&1
    Write-Host "✓ $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Python not found! Please install Python 3.9+" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Menu
Write-Host "Select operation:" -ForegroundColor Cyan
Write-Host "1. Generate sample transaction data" -ForegroundColor White
Write-Host "2. Run ETL pipeline (local)" -ForegroundColor White
Write-Host "3. Run ETL pipeline with MinIO" -ForegroundColor White
Write-Host "4. Monitor performance" -ForegroundColor White
Write-Host "5. Full pipeline (Generate + ETL + Load to DB)" -ForegroundColor White
Write-Host "6. Exit" -ForegroundColor White
Write-Host ""

$choice = Read-Host "Enter choice (1-6)"

switch ($choice) {
    "1" {
        Write-Host ""
        Write-Host "=== Generating Transaction Data ===" -ForegroundColor Cyan
        
        $count = Read-Host "Number of transactions per day (default: 100000)"
        if (-not $count) { $count = "100000" }
        
        $days = Read-Host "Number of days (default: 1)"
        if (-not $days) { $days = "1" }
        
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $logFile = "$logs\data_generation_$timestamp.log"
        
        Write-Host "Generating data..." -ForegroundColor Yellow
        python scripts\data_generator.py --count $count --days $days --output "$dataRaw" 2>&1 | Tee-Object -FilePath $logFile
        
        Write-Host ""
        Write-Host "✓ Data generation completed!" -ForegroundColor Green
        Write-Host "Log saved to: $logFile" -ForegroundColor Gray
    }
    
    "2" {
        Write-Host ""
        Write-Host "=== Running ETL Pipeline (Local) ===" -ForegroundColor Cyan
        
        # Find latest CSV file
        $latestFile = Get-ChildItem -Path "$dataRaw\transactions_*.csv" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        if (-not $latestFile) {
            Write-Host "✗ No transaction files found in $dataRaw" -ForegroundColor Red
            Write-Host "Run option 1 to generate data first" -ForegroundColor Yellow
            exit 1
        }
        
        Write-Host "Input file: $($latestFile.Name)" -ForegroundColor Gray
        
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $logFile = "$logs\etl_pipeline_$timestamp.log"
        
        Write-Host "Running ETL pipeline..." -ForegroundColor Yellow
        python scripts\etl_pipeline.py --input "$dataRaw\transactions_*.csv" --output "$dataProcessed" 2>&1 | Tee-Object -FilePath $logFile
        
        Write-Host ""
        Write-Host "✓ ETL pipeline completed!" -ForegroundColor Green
        Write-Host "Output: $dataProcessed" -ForegroundColor Gray
        Write-Host "Log saved to: $logFile" -ForegroundColor Gray
    }
    
    "3" {
        Write-Host ""
        Write-Host "=== Running ETL Pipeline with MinIO ===" -ForegroundColor Cyan
        
        Write-Host "Step 1: Uploading data to MinIO..." -ForegroundColor Yellow
        python scripts\minio_manager.py upload --bucket transactions-raw --local "$dataRaw"
        
        Write-Host ""
        Write-Host "Step 2: Running ETL pipeline..." -ForegroundColor Yellow
        # Note: This would require MinIO connector in Spark
        Write-Host "⚠ MinIO integration requires additional Spark configuration" -ForegroundColor Yellow
        Write-Host "For now, processing local files..." -ForegroundColor Yellow
        
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $logFile = "$logs\etl_minio_$timestamp.log"
        
        python scripts\etl_pipeline.py --input "$dataRaw\transactions_*.csv" --output "$dataProcessed" 2>&1 | Tee-Object -FilePath $logFile
        
        Write-Host ""
        Write-Host "Step 3: Uploading processed data to MinIO..." -ForegroundColor Yellow
        python scripts\minio_manager.py upload --bucket transactions-processed --local "$dataProcessed"
        
        Write-Host ""
        Write-Host "✓ ETL pipeline with MinIO completed!" -ForegroundColor Green
    }
    
    "4" {
        Write-Host ""
        Write-Host "=== Performance Monitoring ===" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Starting monitoring dashboard..." -ForegroundColor Yellow
        Write-Host "Press Ctrl+C to stop" -ForegroundColor Gray
        Write-Host ""
        
        python monitoring\performance_monitor.py --watch
    }
    
    "5" {
        Write-Host ""
        Write-Host "=== Full Pipeline Execution ===" -ForegroundColor Cyan
        
        $count = Read-Host "Number of transactions per day (default: 100000)"
        if (-not $count) { $count = "100000" }
        
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $masterLog = "$logs\full_pipeline_$timestamp.log"
        
        Write-Host ""
        Write-Host "[1/3] Generating transaction data..." -ForegroundColor Yellow
        python scripts\data_generator.py --count $count --days 1 --output "$dataRaw" 2>&1 | Tee-Object -FilePath $masterLog -Append
        
        Write-Host ""
        Write-Host "[2/3] Running ETL pipeline..." -ForegroundColor Yellow
        python scripts\etl_pipeline.py --input "$dataRaw\transactions_*.csv" --output "$dataProcessed" 2>&1 | Tee-Object -FilePath $masterLog -Append
        
        Write-Host ""
        Write-Host "[3/3] Loading to PostgreSQL..." -ForegroundColor Yellow
        python scripts\etl_pipeline.py --input "$dataRaw\transactions_*.csv" --output "$dataProcessed" --load-db 2>&1 | Tee-Object -FilePath $masterLog -Append
        
        Write-Host ""
        Write-Host "✓✓✓ Full pipeline completed successfully! ✓✓✓" -ForegroundColor Green
        Write-Host "Master log: $masterLog" -ForegroundColor Gray
        
        Write-Host ""
        $monitor = Read-Host "View performance dashboard? (y/n)"
        if ($monitor -eq 'y' -or $monitor -eq 'Y') {
            python monitoring\performance_monitor.py
        }
    }
    
    "6" {
        Write-Host ""
        Write-Host "Goodbye!" -ForegroundColor Cyan
        exit 0
    }
    
    default {
        Write-Host ""
        Write-Host "✗ Invalid choice" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Operation completed" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
