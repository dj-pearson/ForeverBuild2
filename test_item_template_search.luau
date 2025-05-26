-- test_item_template_search.luau
-- Test script to verify the updated template search functionality

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

print("=== ITEM TEMPLATE SEARCH TEST ===")

-- Wait for shared module
local shared = ReplicatedStorage:WaitForChild("shared", 10)
if not shared then
    warn("❌ SharedModule not found")
    return
end

local SharedModule = require(shared)
if not SharedModule then
    warn("❌ SharedModule not loaded")
    return
end

print("✅ SharedModule loaded")

-- Test the PlacementManager template search
local placementManager = SharedModule.PlacementManagerClientInstance
if not placementManager then
    warn("❌ PlacementManagerClientInstance not found")
    return
end

print("✅ PlacementManager found")

-- Test searching for items in the new folder structure
local testItems = {"Water_Cube", "Stone_Cube", "Brick_Cube", "Grass_Cube", "Glass_Cube"}

print("\n🔍 Testing template search with new folder structure...")

for _, itemId in ipairs(testItems) do
    print(string.format("\n--- Testing item: %s ---", itemId))
    
    local template = placementManager:GetItemTemplate(itemId)
    if template then
        print(string.format("✅ Found template for %s: %s", itemId, template:GetFullName()))
        
        -- Check if it has ItemId attribute
        local attributeItemId = template:GetAttribute("ItemId") or template:GetAttribute("itemId")
        if attributeItemId then
            print(string.format("  📝 Template has ItemId attribute: %s", attributeItemId))
        else
            print(string.format("  📝 Template has no ItemId attribute (found by name)"))
        end
        
        -- Check template properties
        if template:IsA("BasePart") then
            print(string.format("  🎨 BrickColor: %s", template.BrickColor.Name))
            print(string.format("  🎨 Material: %s", template.Material.Name))
            print(string.format("  🎨 Transparency: %s", tostring(template.Transparency)))
        elseif template:IsA("Model") then
            print(string.format("  📦 Model with %d parts", #template:GetChildren()))
        end
    else
        print(string.format("❌ Template not found for %s", itemId))
    end
end

-- Test direct folder search to see what's available
print("\n📁 Checking folder structure...")

local itemsFolder = Workspace:FindFirstChild("Items")
if itemsFolder then
    print("✅ Found Workspace.Items folder")
    
    local function listItems(folder, depth)
        local indent = string.rep("  ", depth)
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("Folder") then
                print(string.format("%s📁 %s/", indent, child.Name))
                listItems(child, depth + 1)
            else
                local itemIdAttr = child:GetAttribute("ItemId") or child:GetAttribute("itemId")
                if itemIdAttr then
                    print(string.format("%s📦 %s (ItemId: %s)", indent, child.Name, itemIdAttr))
                else
                    print(string.format("%s📦 %s (No ItemId)", indent, child.Name))
                end
            end
        end
    end
    
    listItems(itemsFolder, 0)
else
    warn("❌ Workspace.Items folder not found")
end

print("\n=== TEMPLATE SEARCH TEST COMPLETE ===") 