local Core = {}

-- Interaction
Core.InteractionManager = require(script.interaction.InteractionManager)
Core.InteractionSystem = require(script.interaction.InteractionManager)

-- Inventory
Core.InventoryManager = require(script.inventory.InventoryManager)
Core.ItemManager = require(script.inventory.ItemManager)

-- Placement
Core.PlacementManager = require(script.placement.PlacementManager)

-- Economy
Core.CurrencyManager = require(script.economy.CurrencyManager)

-- UI
Core.PurchaseDialog = require(script.ui.PurchaseDialog)
Core.InventoryUI = require(script.ui.InventoryUI)
Core.CurrencyUI = require(script.ui.CurrencyUI)
Core.PlacedItemDialog = require(script.ui.PlacedItemDialog)

return Core 