# Pipeline Execution Logs

This directory contains logs from ETL pipeline executions.

## Log Files

- `data_generation_YYYYMMDD_HHMMSS.log` - Data generation logs
- `etl_pipeline_YYYYMMDD_HHMMSS.log` - ETL pipeline execution logs
- `full_pipeline_YYYYMMDD_HHMMSS.log` - Complete pipeline logs
- `metrics.json` - Performance metrics snapshots

## Log Rotation

Logs are automatically created with timestamps.
Consider cleaning old logs periodically to save disk space.

```powershell
# Remove logs older than 30 days
Get-ChildItem -Path logs\ -Filter *.log | 
    Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-30)} | 
    Remove-Item
```
