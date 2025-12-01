# Quick Start Guide - Banking Transactions ETL

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Quick Start - Banking ETL System" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "This script will help you set up the complete ETL system" -ForegroundColor Yellow
Write-Host ""

# Step 1: Install Python dependencies
Write-Host "[Step 1/4] Installing Python dependencies..." -ForegroundColor Cyan
Write-Host ""
Write-Host "Running: pip install -r requirements.txt" -ForegroundColor Gray

$response = Read-Host "Continue? (y/n)"
if ($response -ne 'y' -and $response -ne 'Y') {
    Write-Host "Setup cancelled" -ForegroundColor Yellow
    exit 0
}

pip install -r requirements.txt

Write-Host ""
Write-Host "✓ Python dependencies installed" -ForegroundColor Green
Write-Host ""

# Step 2: Setup MinIO
Write-Host "[Step 2/4] Setting up MinIO (S3 alternative)..." -ForegroundColor Cyan
Write-Host ""
Write-Host "This will download and configure MinIO server" -ForegroundColor Gray

$response = Read-Host "Setup MinIO? (y/n)"
if ($response -eq 'y' -or $response -eq 'Y') {
    .\setup\setup_minio.ps1
} else {
    Write-Host "⊘ Skipping MinIO setup" -ForegroundColor Yellow
}

Write-Host ""

# Step 3: Setup PostgreSQL
Write-Host "[Step 3/4] Setting up PostgreSQL database..." -ForegroundColor Cyan
Write-Host ""
Write-Host "Make sure PostgreSQL is installed and running" -ForegroundColor Gray

$response = Read-Host "Setup PostgreSQL database? (y/n)"
if ($response -eq 'y' -or $response -eq 'Y') {
    .\setup\setup_postgresql.ps1
    
    Write-Host ""
    Write-Host "Creating database tables..." -ForegroundColor Yellow
    
    # Find PostgreSQL
    $pgPath = "C:\Program Files\PostgreSQL\14\bin\psql.exe"
    if (Test-Path $pgPath) {
        Write-Host "Enter PostgreSQL postgres user password when prompted:" -ForegroundColor Gray
        & $pgPath -U postgres -f "sql\create_tables.sql"
        
        Write-Host ""
        Write-Host "Creating indexes..." -ForegroundColor Yellow
        & $pgPath -U postgres -d banking_transactions -f "sql\create_indexes.sql"
        
        Write-Host ""
        Write-Host "✓ Database setup completed" -ForegroundColor Green
    } else {
        Write-Host "PostgreSQL not found at default location" -ForegroundColor Yellow
        Write-Host "Please run the SQL scripts manually:" -ForegroundColor Yellow
        Write-Host "  1. sql\create_tables.sql" -ForegroundColor Gray
        Write-Host "  2. sql\create_indexes.sql" -ForegroundColor Gray
    }
} else {
    Write-Host "⊘ Skipping PostgreSQL setup" -ForegroundColor Yellow
}

Write-Host ""

# Step 4: Setup Spark
Write-Host "[Step 4/4] Setting up Apache Spark..." -ForegroundColor Cyan
Write-Host ""
Write-Host "This will download and configure Spark for ETL processing" -ForegroundColor Gray

$response = Read-Host "Setup Spark? (y/n)"
if ($response -eq 'y' -or $response -eq 'Y') {
    .\setup\setup_spark.ps1
} else {
    Write-Host "⊘ Skipping Spark setup" -ForegroundColor Yellow
    Write-Host "Note: PySpark will still work via pip package" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Start MinIO server (if installed):" -ForegroundColor White
Write-Host "   Run the batch file created in your user directory" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Test the pipeline:" -ForegroundColor White
Write-Host "   .\run_pipeline.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Generate sample data:" -ForegroundColor White
Write-Host "   python scripts\data_generator.py --count 100000" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Run ETL pipeline:" -ForegroundColor White
Write-Host "   python scripts\etl_pipeline.py --input data\raw --output data\processed" -ForegroundColor Gray
Write-Host ""
Write-Host "5. Monitor performance:" -ForegroundColor White
Write-Host "   python monitoring\performance_monitor.py" -ForegroundColor Gray
Write-Host ""

Write-Host "For more information, see README.md" -ForegroundColor Yellow
Write-Host ""
