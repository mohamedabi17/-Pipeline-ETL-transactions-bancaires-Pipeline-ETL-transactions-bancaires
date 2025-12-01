# Setup Apache Spark for Windows
# Alternative to AWS Glue for ETL processing

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Apache Spark Setup - AWS Glue Alternative" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Variables
$sparkVersion = "3.5.0"
$hadoopVersion = "3"
$sparkDir = "$env:USERPROFILE\spark"
$sparkHome = "$sparkDir\spark-$sparkVersion-bin-hadoop$hadoopVersion"
$sparkUrl = "https://archive.apache.org/dist/spark/spark-$sparkVersion/spark-$sparkVersion-bin-hadoop$hadoopVersion.tgz"
$sparkArchive = "$sparkDir\spark-$sparkVersion.tgz"

# Check Java installation
Write-Host "Checking Java installation..." -ForegroundColor Yellow
try {
    $javaVersion = java -version 2>&1 | Select-Object -First 1
    Write-Host "✓ Java is installed: $javaVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Java is not installed!" -ForegroundColor Red
    Write-Host "Please install Java 11 or later from:" -ForegroundColor Yellow
    Write-Host "https://adoptium.net/" -ForegroundColor Cyan
    exit 1
}

Write-Host ""

# Create Spark directory
Write-Host "Creating Spark directory..." -ForegroundColor Yellow
if (-not (Test-Path $sparkDir)) {
    New-Item -ItemType Directory -Path $sparkDir -Force | Out-Null
}

# Download Spark
if (-not (Test-Path $sparkHome)) {
    Write-Host "Downloading Apache Spark $sparkVersion..." -ForegroundColor Yellow
    Write-Host "This may take several minutes..." -ForegroundColor Gray
    
    try {
        # Download using wget or curl if available, otherwise use Invoke-WebRequest
        if (Get-Command wget -ErrorAction SilentlyContinue) {
            wget $sparkUrl -O $sparkArchive
        } else {
            Invoke-WebRequest -Uri $sparkUrl -OutFile $sparkArchive
        }
        Write-Host "✓ Spark downloaded successfully" -ForegroundColor Green
        
        # Extract archive
        Write-Host "Extracting Spark archive..." -ForegroundColor Yellow
        Write-Host "Note: You may need 7-Zip or another tool to extract .tgz files" -ForegroundColor Gray
        Write-Host "Download 7-Zip from: https://www.7-zip.org/" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "After extraction, move the folder to: $sparkHome" -ForegroundColor Yellow
        
    } catch {
        Write-Host "✗ Failed to download Spark: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Manual download option:" -ForegroundColor Yellow
        Write-Host "1. Download from: $sparkUrl" -ForegroundColor Cyan
        Write-Host "2. Extract to: $sparkDir" -ForegroundColor Cyan
        Write-Host "3. Rename folder to: spark-$sparkVersion-bin-hadoop$hadoopVersion" -ForegroundColor Cyan
    }
} else {
    Write-Host "✓ Spark already installed at: $sparkHome" -ForegroundColor Green
}

# Set environment variables
Write-Host ""
Write-Host "Setting environment variables..." -ForegroundColor Yellow

$env:SPARK_HOME = $sparkHome
$env:HADOOP_HOME = $sparkHome
$env:PYSPARK_PYTHON = "python"

# Create environment setup script
$envScript = @"
# Apache Spark Environment Variables
# Add these to your PowerShell profile or run before using Spark

`$env:SPARK_HOME = "$sparkHome"
`$env:HADOOP_HOME = "$sparkHome"
`$env:PYSPARK_PYTHON = "python"
`$env:PYSPARK_DRIVER_PYTHON = "python"
`$env:PATH = "`$env:PATH;$sparkHome\bin"

Write-Host "Spark environment variables set!" -ForegroundColor Green
Write-Host "SPARK_HOME: `$env:SPARK_HOME" -ForegroundColor Cyan
"@

$envScriptPath = "$sparkDir\setup-spark-env.ps1"
$envScript | Out-File -FilePath $envScriptPath -Encoding UTF8
Write-Host "✓ Environment setup script created: $envScriptPath" -ForegroundColor Green

# Create PySpark test script
$testScript = @"
from pyspark.sql import SparkSession
import sys

def test_spark():
    try:
        print('Initializing Spark...')
        spark = SparkSession.builder \
            .appName('SparkTest') \
            .master('local[*]') \
            .config('spark.driver.memory', '2g') \
            .getOrCreate()
        
        print('✓ Spark initialized successfully!')
        print(f'Spark version: {spark.version}')
        
        # Create test DataFrame
        data = [('Alice', 25), ('Bob', 30), ('Charlie', 35)]
        df = spark.createDataFrame(data, ['name', 'age'])
        
        print('\\nTest DataFrame:')
        df.show()
        
        spark.stop()
        print('\\n✓ Spark test completed successfully!')
        return True
        
    except Exception as e:
        print(f'✗ Spark test failed: {e}')
        return False

if __name__ == '__main__':
    success = test_spark()
    sys.exit(0 if success else 1)
"@

$testScriptPath = "$PSScriptRoot\..\scripts\test_spark.py"
$testScript | Out-File -FilePath $testScriptPath -Encoding UTF8
Write-Host "✓ Spark test script created: $testScriptPath" -ForegroundColor Green

# Create Spark configuration file
$sparkConfDir = "$sparkHome\conf"
if (Test-Path $sparkHome) {
    if (-not (Test-Path $sparkConfDir)) {
        New-Item -ItemType Directory -Path $sparkConfDir -Force | Out-Null
    }
    
    $sparkDefaults = @"
# Spark Configuration for Banking Transactions ETL
spark.master                     local[*]
spark.driver.memory              4g
spark.executor.memory            4g
spark.sql.shuffle.partitions     200
spark.default.parallelism        8
spark.serializer                 org.apache.spark.serializer.KryoSerializer
spark.sql.adaptive.enabled       true
spark.sql.adaptive.coalescePartitions.enabled true
spark.sql.parquet.compression.codec snappy
spark.sql.parquet.filterPushdown true
spark.ui.showConsoleProgress     true
spark.sql.sources.partitionOverwriteMode dynamic
"@
    
    $sparkDefaultsPath = "$sparkConfDir\spark-defaults.conf"
    if (Test-Path $sparkHome) {
        $sparkDefaults | Out-File -FilePath $sparkDefaultsPath -Encoding UTF8
        Write-Host "✓ Spark configuration created: $sparkDefaultsPath" -ForegroundColor Green
    }
}

# Create README
$readme = @"
# Apache Spark Setup

## Environment Setup

Before using Spark, run:
```powershell
. $envScriptPath
```

Or add to your PowerShell profile:
```powershell
notepad `$PROFILE
```

## Testing Spark

Install PySpark:
```powershell
pip install pyspark==3.5.0
```

Test installation:
```powershell
python $testScriptPath
```

## Using PySpark

Start PySpark shell:
```powershell
pyspark
```

## Spark Submit

Submit a Spark job:
```powershell
spark-submit --master local[*] your_script.py
```

## Configuration

Spark configuration file:
$sparkConfDir\spark-defaults.conf

## Troubleshooting

If you encounter winutils errors, download winutils.exe from:
https://github.com/steveloughran/winutils

Place it in: `$env:HADOOP_HOME\bin\winutils.exe`

"@

$readmePath = "$sparkDir\README.txt"
$readme | Out-File -FilePath $readmePath -Encoding UTF8

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Spark Setup Instructions" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. If not extracted, extract Spark archive to:" -ForegroundColor White
Write-Host "   $sparkDir" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Set environment variables:" -ForegroundColor White
Write-Host "   . $envScriptPath" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Install PySpark:" -ForegroundColor White
Write-Host "   pip install pyspark==3.5.0" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Test Spark:" -ForegroundColor White
Write-Host "   python $testScriptPath" -ForegroundColor Gray
Write-Host ""
Write-Host "Installation Directory: $sparkDir" -ForegroundColor Cyan
Write-Host ""
