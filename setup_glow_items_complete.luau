-- Complete Setup Script for Glow Items Purchase UI
-- Run this script in the Command Bar in Roblox Studio to set up glow items for purchase

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game.Workspace

print("=== STARTING COMPREHENSIVE GLOW ITEMS SETUP ===")

-- Function to recursively find and setup items
local function setupItemsRecursive(parent, path)
    local count = 0
    
    for _, item in ipairs(parent:GetChildren()) do
        if item:IsA("Model") or item:IsA("Part") then
            -- Check if this is a glow item (contains "Glow" in the path or name)
            local isGlowItem = string.find(string.lower(path or ""), "glow") or string.find(string.lower(item.Name), "glow")
            
            if isGlowItem then
                print("Setting up glow item:", item.Name, "at path:", path)
                
                -- === PURCHASE SYSTEM ATTRIBUTES ===
                -- For ItemInteractionManager purchase system
                item:SetAttribute("Price", 75)  -- 75 Coins for glow items
                item:SetAttribute("CurrencyType", "Coins")
                item:SetAttribute("Description", "A glowing " .. item.Name:gsub("_", " "):lower() .. " that illuminates your world.")
                item:SetAttribute("Purchasable", true)
                
                -- === INTERACTION SYSTEM ATTRIBUTES ===  
                -- For InteractionSystemModule click detection
                item:SetAttribute("Interactable", true)
                item:SetAttribute("ItemID", item.Name)  -- Use item name as ID
                
                -- === ADDITIONAL CATALOG ATTRIBUTES ===
                -- For better catalog integration
                item:SetAttribute("Tier", "Glow")
                item:SetAttribute("Category", "Basic")
                item:SetAttribute("Type", "catalog")
                
                -- === ALTERNATIVE PRICE FORMATS ===
                -- Some systems might look for different price attribute names
                item:SetAttribute("priceIngame", 75)
                item:SetAttribute("priceRobux", 5)
                
                -- === MAKE SURE ITEM IS PROPERLY CONFIGURED ===
                -- Ensure it has a primary part for proper interaction detection
                if item:IsA("Model") and not item.PrimaryPart then
                    local firstPart = item:FindFirstChildOfClass("Part")
                    if firstPart then
                        item.PrimaryPart = firstPart
                        print("  Set PrimaryPart for", item.Name)
                    end
                end
                
                count = count + 1
                print("  ✓ Setup complete for:", item.Name)
            end
        elseif item:IsA("Folder") then
            -- Recursively search folders
            local newPath = path and (path .. "/" .. item.Name) or item.Name
            count = count + setupItemsRecursive(item, newPath)
        end
    end
    
    return count
end

-- Setup items in multiple locations
local totalCount = 0

-- 1. Setup items in Workspace.Items
local workspaceItems = Workspace:FindFirstChild("Items")
if workspaceItems then
    print("\n--- Setting up items in Workspace.Items ---")
    totalCount = totalCount + setupItemsRecursive(workspaceItems, "Workspace.Items")
else
    print("Workspace.Items folder not found")
end

-- 2. Setup items in ServerStorage.Items
local serverStorageItems = ServerStorage:FindFirstChild("Items")
if serverStorageItems then
    print("\n--- Setting up items in ServerStorage.Items ---")
    totalCount = totalCount + setupItemsRecursive(serverStorageItems, "ServerStorage.Items")
else
    print("ServerStorage.Items folder not found")
end

-- 3. Setup items in ReplicatedStorage.Items (if it exists)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local replicatedStorageItems = ReplicatedStorage:FindFirstChild("Items")
if replicatedStorageItems then
    print("\n--- Setting up items in ReplicatedStorage.Items ---")
    totalCount = totalCount + setupItemsRecursive(replicatedStorageItems, "ReplicatedStorage.Items")
else
    print("ReplicatedStorage.Items folder not found")
end

print("\n=== SETUP COMPLETE ===")
print("Total glow items configured:", totalCount)
print("\nGlow items should now:")
print("- Be discoverable by the purchase system")
print("- Show purchase UI when clicked")
print("- Have proper price attributes (75 Coins, 5 Robux)")
print("- Be marked as Interactable for click detection")

if totalCount > 0 then
    print("\n✓ SUCCESS: Glow items are now ready for purchase!")
    print("Test by clicking on a glow item in-game.")
else
    print("\n⚠ WARNING: No glow items found!")
    print("Check that:")
    print("1. Items exist in Workspace.Items, ServerStorage.Items, or ReplicatedStorage.Items")
    print("2. Folder structure includes 'Glow' in the path or item names")
end 