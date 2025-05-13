@echo off
REM Rename shared core module files
ren "src\shared\core\Constants.lua" "Constants.luau"
ren "src\shared\core\GameManager.lua" "GameManager.luau"
ren "src\shared\core\LazyLoadModules.lua" "LazyLoadModules.luau"

REM Rename economy module files
ren "src\shared\core\economy\CurrencyManager.lua" "CurrencyManager.luau"
ren "src\shared\core\economy\init.lua" "init.luau"

REM Rename UI module files
ren "src\shared\core\ui\CurrencyUI.lua" "CurrencyUI.luau"
ren "src\shared\core\ui\init.lua" "init.luau"
ren "src\shared\core\ui\PlacedItemDialog.lua" "PlacedItemDialog.luau"
ren "src\shared\core\ui\InventoryUI.lua" "InventoryUI.luau"
ren "src\shared\core\ui\PurchaseDialog.lua" "PurchaseDialog.luau"

REM Rename interaction module files
ren "src\shared\core\interaction\InteractionManager.lua" "InteractionManager.luau"
ren "src\shared\core\interaction\init.lua" "init.luau"

REM Rename inventory module files
ren "src\shared\core\inventory\ItemManager.lua" "ItemManager.luau"
ren "src\shared\core\inventory\init.lua" "init.luau"
ren "src\shared\core\inventory\InventoryManager.lua" "InventoryManager.luau"

REM Rename placement module files
ren "src\shared\core\placement\init.lua" "init.luau"
ren "src\shared\core\placement\PlacementManager.lua" "PlacementManager.luau"

REM Rename shared init file
ren "src\shared\init.lua" "init.luau"

REM Rename client files
ren "src\client\init.client.lua" "init.client.luau"
ren "src\client\client.lua" "client.luau"
ren "src\client\interaction\InteractionSystem.lua" "InteractionSystem.client.luau"

REM Rename server files
ren "src\server\init.server.lua" "init.server.luau"
ren "src\server\Neon\NeonGlowManager.server.luau" "NeonGlowManager.server.luau"

REM Rename StarterGui files
ren "src\StarterGui\init.client.lua" "init.client.luau" 