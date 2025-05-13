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
    "src\server\init.server.lua"
)

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
