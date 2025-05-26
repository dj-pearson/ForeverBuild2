-- test_fix_inventory_placement.luau
-- Quick fix for inventory item placement

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

print("=== FIXING INVENTORY PLACEMENT ===")

-- Wait for shared module
task.wait(2) -- Give system time to initialize

local shared = ReplicatedStorage:FindFirstChild("shared")
if not shared then
    warn("❌ Shared module not found")
    return
end

local SharedModule = require(shared)
if not SharedModule then
    warn("❌ SharedModule not loaded")
    return
end

print("✅ SharedModule loaded")

-- Check if InventoryUI exists
if not SharedModule.InventoryUI then
    warn("❌ InventoryUI not found in SharedModule")
    return
end

print("✅ InventoryUI found")

-- Check if PlacementManagerClientInstance exists
if not SharedModule.PlacementManagerClientInstance then
    warn("❌ PlacementManagerClientInstance not found")
    return
end

print("✅ PlacementManagerClientInstance found")

-- Set up the OnItemSelected callback directly
SharedModule.InventoryUI.OnItemSelected = function(itemName, itemData)
    print("🔄 Inventory item selected:", itemName)
    
    -- Normalize the item name
    local normalizedItemName = itemName:gsub(" ", "_")
    
    -- Try ShowItemInHand first
    if SharedModule.PlacementManagerClientInstance.ShowItemInHand then
        print("🎯 Using ShowItemInHand method")
        local success = SharedModule.PlacementManagerClientInstance:ShowItemInHand(normalizedItemName)
        if success then
            print("✅ Item shown in hand successfully")
        else
            warn("❌ ShowItemInHand failed")
        end
    -- Fallback to RecallItemFromInventory
    elseif SharedModule.PlacementManagerClientInstance.RecallItemFromInventory then
        print("🎯 Using RecallItemFromInventory method")
        local success = SharedModule.PlacementManagerClientInstance:RecallItemFromInventory(normalizedItemName)
        if success then
            print("✅ Item recalled successfully")
        else
            warn("❌ RecallItemFromInventory failed")
        end
    else
        warn("❌ No placement method available")
        print("Available methods in PlacementManagerClientInstance:")
        for k, v in pairs(SharedModule.PlacementManagerClientInstance) do
            if type(v) == "function" then
                print("  -", k)
            end
        end
    end
end

print("✅ OnItemSelected callback has been set up!")
print("🎉 Try clicking on an inventory item now - it should work!") 