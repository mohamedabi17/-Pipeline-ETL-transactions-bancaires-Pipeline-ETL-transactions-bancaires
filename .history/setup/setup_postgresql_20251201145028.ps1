# Setup PostgreSQL Database for Banking Transactions
# Alternative to Amazon Redshift

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PostgreSQL Setup - Redshift Alternative" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if PostgreSQL is installed
$pgVersion = "14"
$pgPath = "C:\Program Files\PostgreSQL\$pgVersion\bin\psql.exe"

if (-not (Test-Path $pgPath)) {
    Write-Host "PostgreSQL is not installed at the expected path." -ForegroundColor Yellow
    Write-Host "Please install PostgreSQL 14 or later from:" -ForegroundColor Yellow
    Write-Host "https://www.postgresql.org/download/windows/" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "After installation, run this script again." -ForegroundColor Yellow
    
    # Try to find PostgreSQL in common locations
    $commonPaths = @(
        "C:\Program Files\PostgreSQL\15\bin\psql.exe",
        "C:\Program Files\PostgreSQL\16\bin\psql.exe",
        "C:\PostgreSQL\bin\psql.exe"
    )
    
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            $pgPath = $path
            Write-Host "Found PostgreSQL at: $path" -ForegroundColor Green
            break
        }
    }
    
    if (-not (Test-Path $pgPath)) {
        exit 1
    }
}

Write-Host "✓ PostgreSQL found at: $pgPath" -ForegroundColor Green
Write-Host ""

# Database configuration
$dbName = "banking_transactions"
$dbUser = "postgres"
$dbPassword = "postgres"  # Change this in production!
$dbHost = "localhost"
$dbPort = "5432"

# Create database creation script
$createDbScript = @"
-- Create Database
DROP DATABASE IF EXISTS $dbName;
CREATE DATABASE $dbName
    WITH 
    ENCODING = 'UTF8'
    LC_COLLATE = 'English_United States.1252'
    LC_CTYPE = 'English_United States.1252'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1;

\c $dbName

-- Enable extensions for performance
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS btree_gin;

COMMENT ON DATABASE $dbName IS 'Banking Transactions Data Warehouse';
"@

$scriptPath = "$PSScriptRoot\..\sql\create_database.sql"
$createDbScript | Out-File -FilePath $scriptPath -Encoding UTF8
Write-Host "✓ Database creation script generated: $scriptPath" -ForegroundColor Green

Write-Host ""
Write-Host "To create the database, run:" -ForegroundColor Yellow
Write-Host ""
Write-Host "psql -U postgres -f `"$scriptPath`"" -ForegroundColor Cyan
Write-Host ""
Write-Host "You will be prompted for the postgres user password." -ForegroundColor Gray
Write-Host ""

# Create connection test script
$testScript = @"
import psycopg2
import sys

def test_connection():
    try:
        conn = psycopg2.connect(
            host='$dbHost',
            port='$dbPort',
            database='$dbName',
            user='$dbUser',
            password='$dbPassword'
        )
        cursor = conn.cursor()
        cursor.execute('SELECT version();')
        version = cursor.fetchone()
        print('✓ Connected successfully!')
        print(f'PostgreSQL version: {version[0]}')
        cursor.close()
        conn.close()
        return True
    except Exception as e:
        print(f'✗ Connection failed: {e}')
        return False

if __name__ == '__main__':
    success = test_connection()
    sys.exit(0 if success else 1)
"@

$testScriptPath = "$PSScriptRoot\..\scripts\test_db_connection.py"
$testScript | Out-File -FilePath $testScriptPath -Encoding UTF8
Write-Host "✓ Connection test script created: $testScriptPath" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  PostgreSQL Setup Instructions" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "1. Ensure PostgreSQL service is running" -ForegroundColor Yellow
Write-Host "2. Create the database using the generated script" -ForegroundColor Yellow
Write-Host "3. Run the table creation scripts in sql/ directory" -ForegroundColor Yellow
Write-Host "4. Test connection using: python $testScriptPath" -ForegroundColor Yellow
Write-Host ""
Write-Host "Database Details:" -ForegroundColor Cyan
Write-Host "  Host: $dbHost" -ForegroundColor White
Write-Host "  Port: $dbPort" -ForegroundColor White
Write-Host "  Database: $dbName" -ForegroundColor White
Write-Host "  User: $dbUser" -ForegroundColor White
Write-Host ""
