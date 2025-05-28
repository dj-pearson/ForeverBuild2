local SharedModule = {}

local core = script.Parent:FindFirstChild("core")
if not core then error("[SharedModule] Missing 'core' folder under shared") end

local function tryRequire(moduleScript, name)
    print("[SharedModule] Attempting to require " .. name)
    local ok, result = pcall(require, moduleScript)
    if ok then
        print("[SharedModule] Successfully required " .. name)
        return result
    else
        warn("[SharedModule] Failed to require " .. name .. ": " .. tostring(result))
        return nil
    end
end

-- Managers
SharedModule.GameManager = core:FindFirstChild("GameManager") and tryRequire(core.GameManager, "GameManager") or nil
SharedModule.InventoryManager = core:FindFirstChild("inventory") and core.inventory:FindFirstChild("InventoryManager") and tryRequire(core.inventory.InventoryManager, "InventoryManager") or nil
SharedModule.CurrencyManager = core:FindFirstChild("economy") and core.economy:FindFirstChild("CurrencyManager") and tryRequire(core.economy.CurrencyManager, "CurrencyManager") or nil
SharedModule.PlacementManager = core:FindFirstChild("placement") and core.placement:FindFirstChild("PlacementManager") and tryRequire(core.placement.PlacementManager, "PlacementManager") or nil
SharedModule.InteractionManager = core:FindFirstChild("interaction") and core.interaction:FindFirstChild("InteractionManager") and tryRequire(core.interaction.InteractionManager, "InteractionManager") or nil
SharedModule.ItemManager = core:FindFirstChild("inventory") and core.inventory:FindFirstChild("ItemManager") and tryRequire(core.inventory.ItemManager, "ItemManager") or nil

-- UI Modules
SharedModule.PurchaseDialog = core:FindFirstChild("ui") and core.ui:FindFirstChild("PurchaseDialog") and tryRequire(core.ui.PurchaseDialog, "PurchaseDialog") or nil
SharedModule.InventoryUI = core:FindFirstChild("ui") and core.ui:FindFirstChild("InventoryUI") and tryRequire(core.ui.InventoryUI, "InventoryUI") or nil
SharedModule.PlacedItemDialog = core:FindFirstChild("ui") and core.ui:FindFirstChild("PlacedItemDialog") and tryRequire(core.ui.PlacedItemDialog, "PlacedItemDialog") or nil
SharedModule.CurrencyUI = core:FindFirstChild("ui") and core.ui:FindFirstChild("CurrencyUI") and tryRequire(core.ui.CurrencyUI, "CurrencyUI") or nil

-- Other core modules
SharedModule.Constants = core:FindFirstChild("Constants") and tryRequire(core.Constants, "Constants") or nil
SharedModule.LazyLoadModules = core:FindFirstChild("LazyLoadModules") and tryRequire(core.LazyLoadModules, "LazyLoadModules") or {
    register = function() end,
    require = function() return {} end
}

function SharedModule.Init()
    print("[SharedModule] Init called.")
end

return SharedModule 