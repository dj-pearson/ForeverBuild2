local Core = {}

local function safeRequire(modulePath, moduleName)
	local success, result = pcall(function()
		return require(modulePath)
	end)
	if success then
		if result == nil then
			warn("Warning: Module loaded successfully but returned nil: ", moduleName, " at path ", tostring(modulePath))
		end
		return result
	else
		warn("Error loading module: ", moduleName, " at path ", tostring(modulePath), "\nError: ", tostring(result))
		return nil
	end
end

-- Interaction
Core.InteractionManager = safeRequire(script.interaction.InteractionManager, "InteractionManager") -- Restored this line

-- Inventory
Core.InventoryManager = safeRequire(script.inventory.InventoryManager, "InventoryManager")
Core.ItemManager = safeRequire(script.inventory.ItemManager, "ItemManager")

-- Placement
Core.PlacementManager = safeRequire(script.placement.PlacementManager, "PlacementManager")

-- Economy
Core.CurrencyManager = safeRequire(script.economy.CurrencyManager, "CurrencyManager")

-- GameManager
Core.GameManager = safeRequire(script.GameManager, "GameManager") -- Added GameManager

-- UI
Core.PurchaseDialog = safeRequire(script.ui.PurchaseDialog, "PurchaseDialog")
Core.InventoryUI = safeRequire(script.ui.InventoryUI, "InventoryUI")
Core.CurrencyUI = safeRequire(script.ui.CurrencyUI, "CurrencyUI")
Core.PlacedItemDialog = safeRequire(script.ui.PlacedItemDialog, "PlacedItemDialog")
Core.LazyLoadModules = safeRequire(script.LazyLoadModules, "LazyLoadModules")


return Core