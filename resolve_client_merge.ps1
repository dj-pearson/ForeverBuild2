# Resolve source control merge issues
# This script handles the init.client.luau vs inits.client.luau conflict

Write-Host "Starting source control merge resolution..." -ForegroundColor Cyan

# 1. Backup existing files in case we need to revert
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = "merge_backup_$timestamp"
New-Item -Path $backupDir -ItemType Directory -Force | Out-Null

Write-Host "Created backup directory: $backupDir" -ForegroundColor Green

# Backup init.client.luau if it exists
if (Test-Path -Path ".\src\client\init.client.luau") {
    Copy-Item -Path ".\src\client\init.client.luau" -Destination "$backupDir\init.client.luau.bak" -Force
    Write-Host "Backed up init.client.luau" -ForegroundColor Green
}

# Backup inits.client.luau if it exists
if (Test-Path -Path ".\src\client\inits.client.luau") {
    Copy-Item -Path ".\src\client\inits.client.luau" -Destination "$backupDir\inits.client.luau.bak" -Force
    Write-Host "Backed up inits.client.luau" -ForegroundColor Green
}

# 2. Apply the merged file to inits.client.luau
if (Test-Path -Path ".\src\client\inits.client.luau.merged") {
    Copy-Item -Path ".\src\client\inits.client.luau.merged" -Destination ".\src\client\inits.client.luau" -Force
    Write-Host "Applied merged changes to inits.client.luau" -ForegroundColor Green
}

# 3. Remove init.client.luau as we're standardizing on inits.client.luau
if (Test-Path -Path ".\src\client\init.client.luau") {
    Remove-Item -Path ".\src\client\init.client.luau" -Force
    Write-Host "Removed init.client.luau to standardize on inits.client.luau" -ForegroundColor Green
}

# 4. Clean up the merged file
if (Test-Path -Path ".\src\client\inits.client.luau.merged") {
    Remove-Item -Path ".\src\client\inits.client.luau.merged" -Force
    Write-Host "Cleaned up temporary merged file" -ForegroundColor Green
}

Write-Host "Merge resolution completed successfully!" -ForegroundColor Cyan
Write-Host "You should now be able to commit the changes without conflicts." -ForegroundColor Yellow
Write-Host "If you need to revert, backup files are in the $backupDir directory." -ForegroundColor Yellow
