local SharedModule = {}

local function safeRequire(moduleScript, name)
    local ok, result = pcall(require, moduleScript)
    if not ok then
        warn("[SharedModule] Failed to require " .. name .. ": " .. tostring(result))
        -- Return a minimal stub to prevent nil errors
        return setmetatable({
            Initialize = function() end,
            Update = function() end,
            Show = function() end,
        }, { __tostring = function() return "[Stub for " .. name .. "]" end })
    end
    return result
end

local core = script:FindFirstChild("core")
if not core then error("[SharedModule] Missing 'core' folder under SharedModule") end

-- Managers
SharedModule.GameManager = core:FindFirstChild("GameManager") and safeRequire(core.GameManager, "GameManager") or {}
SharedModule.InventoryManager = core:FindFirstChild("inventory") and core.inventory:FindFirstChild("InventoryManager") and safeRequire(core.inventory.InventoryManager, "InventoryManager") or {}
SharedModule.CurrencyManager = core:FindFirstChild("economy") and core.economy:FindFirstChild("CurrencyManager") and safeRequire(core.economy.CurrencyManager, "CurrencyManager") or {}
SharedModule.PlacementManager = core:FindFirstChild("placement") and core.placement:FindFirstChild("PlacementManager") and safeRequire(core.placement.PlacementManager, "PlacementManager") or {}
SharedModule.InteractionManager = core:FindFirstChild("interaction") and core.interaction:FindFirstChild("InteractionManager") and safeRequire(core.interaction.InteractionManager, "InteractionManager") or {}
SharedModule.ItemManager = core:FindFirstChild("inventory") and core.inventory:FindFirstChild("ItemManager") and safeRequire(core.inventory.ItemManager, "ItemManager") or {}

-- UI Modules
SharedModule.PurchaseDialog = core:FindFirstChild("ui") and core.ui:FindFirstChild("PurchaseDialog") and safeRequire(core.ui.PurchaseDialog, "PurchaseDialog") or {}
SharedModule.InventoryUI = core:FindFirstChild("ui") and core.ui:FindFirstChild("InventoryUI") and safeRequire(core.ui.InventoryUI, "InventoryUI") or {}
SharedModule.PlacedItemDialog = core:FindFirstChild("ui") and core.ui:FindFirstChild("PlacedItemDialog") and safeRequire(core.ui.PlacedItemDialog, "PlacedItemDialog") or {}
SharedModule.CurrencyUI = core:FindFirstChild("ui") and core.ui:FindFirstChild("CurrencyUI") and safeRequire(core.ui.CurrencyUI, "CurrencyUI") or {}

-- Other core modules
SharedModule.Constants = core:FindFirstChild("Constants") and safeRequire(core.Constants, "Constants") or {}
SharedModule.LazyLoadModules = core:FindFirstChild("LazyLoadModules") and safeRequire(core.LazyLoadModules, "LazyLoadModules") or {
    register = function() end,
    require = function() return {} end
}

function SharedModule.Init()
    print("[SharedModule] Init called.")
end

return SharedModule 