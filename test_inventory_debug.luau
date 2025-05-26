-- test_inventory_debug.luau
-- Debug test for inventory item selection and placement issues

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

print("=== INVENTORY & PLACEMENT DEBUG TEST ===")

-- Wait for shared module
local shared = ReplicatedStorage:WaitForChild("shared", 10)
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

-- Check InventoryUI
if SharedModule.InventoryUI then
    print("✅ InventoryUI found in SharedModule")
    
    if SharedModule.InventoryUI.OnItemSelected then
        print("✅ OnItemSelected callback exists:", type(SharedModule.InventoryUI.OnItemSelected))
        if type(SharedModule.InventoryUI.OnItemSelected) == "function" then
            print("✅ OnItemSelected is a function")
        else
            warn("❌ OnItemSelected is not a function")
        end
    else
        warn("❌ OnItemSelected callback is nil")
    end
else
    warn("❌ InventoryUI not found in SharedModule")
end

-- Check PlacementManagerClientInstance
if SharedModule.PlacementManagerClientInstance then
    print("✅ PlacementManagerClientInstance exists")
    
    if SharedModule.PlacementManagerClientInstance.RecallItemFromInventory then
        print("✅ RecallItemFromInventory method exists")
    else
        warn("❌ RecallItemFromInventory method not found")
    end
    
    if SharedModule.PlacementManagerClientInstance.ShowItemInHand then
        print("✅ ShowItemInHand method exists")
    else
        warn("❌ ShowItemInHand method not found")
    end
else
    warn("❌ PlacementManagerClientInstance not found")
end

-- Check if there are placed items in the world
print("\n=== CHECKING PLACED ITEMS ===")
local worldItems = workspace:FindFirstChild("World_Items")
if worldItems then
    print("✅ World_Items folder found")
    
    local placedFolder = worldItems:FindFirstChild("Placed")
    if placedFolder then
        print("✅ Placed folder found")
        local itemCount = #placedFolder:GetChildren()
        print("📦 Items in Placed folder:", itemCount)
        
        if itemCount > 0 then
            print("Items found:")
            for i, item in ipairs(placedFolder:GetChildren()) do
                local instanceId = item:GetAttribute("instanceId")
                local itemId = item:GetAttribute("itemId")
                local owner = item:GetAttribute("owner")
                print(string.format("  %d. %s (instanceId: %s, itemId: %s, owner: %s)", 
                    i, item.Name, tostring(instanceId), tostring(itemId), tostring(owner)))
            end
        else
            print("❌ No items found in Placed folder")
        end
    else
        warn("❌ Placed folder not found")
    end
else
    warn("❌ World_Items folder not found")
end

-- Check remotes
print("\n=== CHECKING REMOTES ===")
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if remotes then
    print("✅ Remotes folder found")
    
    local placementRemotes = {"PlaceItem", "GetInventory", "ItemPlaced", "RecallItem"}
    for _, remoteName in ipairs(placementRemotes) do
        local remote = remotes:FindFirstChild(remoteName)
        if remote then
            print("✅", remoteName, "found")
        else
            warn("❌", remoteName, "not found")
        end
    end
else
    warn("❌ Remotes folder not found")
end

-- Test inventory item selection
print("\n=== TESTING INVENTORY ITEM SELECTION ===")
if SharedModule.InventoryUI and SharedModule.InventoryUI.OnItemSelected then
    print("Testing OnItemSelected callback...")
    
    local testItemData = {
        id = "Test_Cube",
        name = "Test_Cube",
        displayName = "Test Cube",
        count = 1,
        tier = "BASIC"
    }
    
    print("Calling OnItemSelected with test data...")
    local success, error = pcall(function()
        SharedModule.InventoryUI.OnItemSelected("Test_Cube", testItemData)
    end)
    
    if success then
        print("✅ OnItemSelected callback executed successfully")
    else
        warn("❌ OnItemSelected callback failed:", error)
    end
else
    warn("❌ Cannot test OnItemSelected - callback not available")
end

-- Check inventory data
print("\n=== CHECKING INVENTORY DATA ===")
if remotes and remotes:FindFirstChild("GetInventory") then
    local getInventoryFunc = remotes.GetInventory
    local success, inventorySuccess, inventoryData, currency = pcall(function()
        return getInventoryFunc:InvokeServer()
    end)
    
    if success and inventorySuccess then
        print("✅ Successfully retrieved inventory data")
        if inventoryData and type(inventoryData) == "table" then
            print("📦 Inventory contains", #inventoryData, "items")
            for i, item in ipairs(inventoryData) do
                print(string.format("  %d. %s (count: %s, tier: %s)", 
                    i, item.id or item.name or "unknown", 
                    tostring(item.count or item.quantity or 1),
                    tostring(item.tier or "unknown")))
            end
        else
            warn("❌ Inventory data is not a table:", type(inventoryData))
        end
        print("💰 Currency:", currency or 0)
    else
        warn("❌ Failed to get inventory data:", inventoryData)
    end
else
    warn("❌ GetInventory remote not found")
end

print("\n=== DEBUG TEST COMPLETE ===") 