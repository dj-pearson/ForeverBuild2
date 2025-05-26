-- test_placed_items_debug.luau
-- Debug test to check if placed items are loading properly

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

print("=== CHECKING PLACED ITEMS DEBUG ===")

-- Check if World_Items folder structure exists
local worldItems = Workspace:FindFirstChild("World_Items")
if worldItems then
    print("✅ World_Items folder found")
    
    local placedFolder = worldItems:FindFirstChild("Placed")
    if placedFolder then
        print("✅ Placed folder found")
        
        local itemCount = #placedFolder:GetChildren()
        print("📦 Items in Placed folder:", itemCount)
        
        if itemCount > 0 then
            print("Found placed items:")
            for i, item in ipairs(placedFolder:GetChildren()) do
                local instanceId = item:GetAttribute("instanceId")
                local itemId = item:GetAttribute("itemId")
                local owner = item:GetAttribute("owner")
                print(string.format("  %d. %s", i, item.Name))
                print(string.format("     - InstanceID: %s", tostring(instanceId)))
                print(string.format("     - ItemID: %s", tostring(itemId)))
                print(string.format("     - Owner: %s", tostring(owner)))
                
                if item:IsA("Model") and item.PrimaryPart then
                    print(string.format("     - Position: %s", tostring(item.PrimaryPart.Position)))
                elseif item:IsA("Part") then
                    print(string.format("     - Position: %s", tostring(item.Position)))
                end
                print()
            end
        else
            print("❌ No items found in Placed folder")
        end
    else
        print("❌ Placed folder not found - creating it...")
        local newPlacedFolder = Instance.new("Folder")
        newPlacedFolder.Name = "Placed"
        newPlacedFolder.Parent = worldItems
        print("✅ Created Placed folder")
    end
else
    print("❌ World_Items folder not found - creating it...")
    local newWorldItems = Instance.new("Folder")
    newWorldItems.Name = "World_Items"
    newWorldItems.Parent = Workspace
    
    local newPlacedFolder = Instance.new("Folder")
    newPlacedFolder.Name = "Placed"
    newPlacedFolder.Parent = newWorldItems
    
    print("✅ Created World_Items and Placed folders")
end

-- Check if DataService exists and can load data
print("\n=== CHECKING DATA SERVICE ===")
local shared = ReplicatedStorage:FindFirstChild("shared")
if shared then
    local SharedModule = require(shared)
    if SharedModule and SharedModule.DataService then
        print("✅ DataService found")
        
        -- Try to load world data
        local worldData = SharedModule.DataService:GetData("WorldPlacedItems")
        if worldData and type(worldData) == "table" then
            print("📦 Stored world data contains", #worldData, "items")
            
            if #worldData > 0 then
                print("Stored items:")
                for i, itemData in ipairs(worldData) do
                    print(string.format("  %d. ItemID: %s, InstanceID: %s, Owner: %s", 
                        i, 
                        tostring(itemData.itemId), 
                        tostring(itemData.instanceId), 
                        tostring(itemData.owner)))
                    
                    if itemData.position then
                        if type(itemData.position) == "table" then
                            print(string.format("     - Position: {X=%s, Y=%s, Z=%s}", 
                                tostring(itemData.position.X), 
                                tostring(itemData.position.Y), 
                                tostring(itemData.position.Z)))
                        else
                            print("     - Position:", tostring(itemData.position))
                        end
                    end
                end
            end
        else
            print("❌ No stored world data found or data is invalid")
        end
    else
        print("❌ DataService not found in SharedModule")
    end
else
    print("❌ SharedModule not found")
end

-- Check if PlacementManager is properly initialized
print("\n=== CHECKING PLACEMENT MANAGER ===")
if shared then
    local SharedModule = require(shared)
    if SharedModule and SharedModule.PlacementManager then
        print("✅ PlacementManager found")
        
        -- Check if server-side LoadWorldData method exists
        if SharedModule.PlacementManager.LoadWorldData then
            print("✅ LoadWorldData method exists")
        else
            print("❌ LoadWorldData method not found")
        end
        
        -- Check if placedItemsByPlayer table exists and has data
        if SharedModule.PlacementManager.placedItemsByPlayer then
            local totalTrackedItems = 0
            for playerId, items in pairs(SharedModule.PlacementManager.placedItemsByPlayer) do
                totalTrackedItems = totalTrackedItems + #items
                print(string.format("Player %s has %d tracked items", playerId, #items))
            end
            print("Total tracked items:", totalTrackedItems)
        else
            print("❌ placedItemsByPlayer table not found")
        end
    else
        print("❌ PlacementManager not found in SharedModule")
    end
end

print("\n=== DEBUG COMPLETE ===")
print("If no placed items are showing:")
print("1. Check if the server is calling LoadWorldData() during initialization")
print("2. Check if DataService is properly storing/loading data")
print("3. Check if item templates exist for the stored items") 