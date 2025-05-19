# Cleanup script for ForeverBuild2
# This will remove duplicate files and keep only the .luau versions

# Files to remove
$filesToRemove = @(
    # Client folder
    "src\client\init.client.lua",
    
    # Currency folder
    "src\client\Currency\CurrencyUI.lua",
    "src\client\Currency\CurrencyUI_fixed.lua",
    
    # Shared core folder
    "src\shared\core\GameManager.lua",
    
    # Economy folder
    "src\shared\core\economy\CurrencyManager.lua",
    "src\shared\core\economy\CurrencyManager_client.lua",
    
    # UI folder
    "src\shared\core\ui\CurrencyUI_fixed.lua",
    
    # StarterGui folder
    "src\StarterGui\init.client.lua",
    
    # Server folder
    "src\server\init.server.lua",
    
    # Duplicate module files with overlapping functionality
    "src\server\ItemPurchaseHandler.lua",
    "src\server\AdminCurrencyManager.lua"
)

# Create backup folder for important files
$backupFolder = Join-Path $PSScriptRoot "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -Path $backupFolder -ItemType Directory -Force | Out-Null
Write-Host "Created backup folder: $backupFolder"

# Backup important files before removal
$filesToBackup = @(
    "src\server\ItemPurchaseHandler.lua",
    "src\server\AdminCurrencyManager.lua"
)

foreach ($file in $filesToBackup) {
    $fullPath = Join-Path $PSScriptRoot $file
    if (Test-Path $fullPath) {
        $fileName = Split-Path $file -Leaf
        $backupPath = Join-Path $backupFolder "$fileName.bak"
        Write-Host "Backing up: $file to $backupPath"
        Copy-Item -Path $fullPath -Destination $backupPath -Force
    }
}

# Remove each file if it exists
foreach ($file in $filesToRemove) {
    $fullPath = Join-Path $PSScriptRoot $file
    if (Test-Path $fullPath) {
        Write-Host "Removing: $file"
        Remove-Item -Path $fullPath -Force
    } else {
        Write-Host "File not found: $file"
    }
}

Write-Host "`nCleanup complete. The codebase now uses .luau files consistently."
