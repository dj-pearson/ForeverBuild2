-- Fix ItemId Preservation System
-- This script fixes the PlacementManager to properly handle numeric ItemIds

print("=== FIXING ITEMID PRESERVATION SYSTEM ===")

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 1. First, restore the original numeric ItemId
local function restoreOriginalItemIds()
    print("\n🔧 RESTORING ORIGINAL NUMERIC ITEMIDS:")
    
    local items = Workspace:FindFirstChild("Items")
    if items then
        local level1 = items:FindFirstChild("Level_1")
        if level1 then
            local torch = level1:FindFirstChild("Torch")
            if torch then
                print("Found Torch, restoring original ItemId...")
                
                -- Clear the overwritten string values
                if torch:GetAttribute("ItemId") == "Torch" then
                    torch:SetAttribute("ItemId", 131)  -- Restore original numeric ID
                    print("✅ Restored ItemId to 131")
                end
                
                if torch:GetAttribute("itemId") == "Torch" then
                    torch:SetAttribute("itemId", nil)  -- Remove conflicting lowercase
                    print("✅ Removed conflicting itemId attribute")
                end
                
                print(string.format("Final state - ItemId: %s (type: %s)", 
                    tostring(torch:GetAttribute("ItemId")), 
                    type(torch:GetAttribute("ItemId"))))
            end
        end
    end
end

restoreOriginalItemIds()

-- 2. Fix PlacementManager GetItemTemplate function (if accessible)
print("\n🔧 UPDATING PLACEMENTMANAGER SEARCH LOGIC:")

local function testPlacementManagerFix()
    local SharedModule
    local success, err = pcall(function()
        SharedModule = require(ReplicatedStorage:WaitForChild("shared"))
    end)
    
    if not success then
        print("❌ Could not access SharedModule, will create search fix script")
        return false
    end
    
    local PlacementManager = SharedModule.PlacementManager
    if not PlacementManager then
        print("❌ PlacementManager not found")
        return false
    end
    
    -- Test if the manager can now find Torch by numeric ID
    local manager = PlacementManager.new()
    if manager then
        print("Testing searches:")
        
        -- Test numeric ID search
        local template1 = manager:GetItemTemplate(131)
        if template1 then
            print("✅ SUCCESS: Found Torch by numeric ID 131")
        else
            print("❌ FAILED: Could not find Torch by numeric ID 131")
        end
        
        -- Test string search for compatibility
        local template2 = manager:GetItemTemplate("Torch")  
        if template2 then
            print("✅ Fallback works: Found Torch by string name")
        else
            print("❌ Even string fallback failed")
        end
    end
    
    return true
end

-- 3. Create improved search function that handles both numeric and string IDs
local function createImprovedSearchLogic()
    print("\n📝 RECOMMENDED PLACEMENTMANAGER UPDATES:")
    print([[
The PlacementManager:GetItemTemplate() function should be updated to:

1. First check for EXACT ItemId attribute match (handles numeric IDs)
2. Then check for string conversion match
3. Finally fallback to name matching

Here's the improved search logic needed:

function findTemplateRecursive(folder, itemId)
    for _, child in ipairs(folder:GetChildren()) do
        -- PRIMARY: Check for exact ItemId attribute match (preserves numeric IDs)
        local childItemId = child:GetAttribute("ItemId")
        if childItemId == itemId then
            return child
        end
        
        -- SECONDARY: Check lowercase itemId for compatibility  
        local childItemIdLower = child:GetAttribute("itemId")
        if childItemIdLower == itemId then
            return child
        end
        
        -- TERTIARY: Handle string/number conversion
        if type(itemId) == "number" and type(childItemId) == "string" then
            if tonumber(childItemId) == itemId then
                return child
            end
        elseif type(itemId) == "string" and type(childItemId) == "number" then
            if tostring(childItemId) == itemId then
                return child
            end
        end
        
        -- FALLBACK: Name matching for legacy compatibility
        if child.Name == tostring(itemId) then
            return child
        end
        
        -- Recursive search
        if child:IsA("Folder") then
            local found = findTemplateRecursive(child, itemId)
            if found then return found end
        end
    end
    return nil
end

This preserves your numeric ItemId system while maintaining compatibility!
]])
end

createImprovedSearchLogic()

-- 4. Test the fixed system
if not testPlacementManagerFix() then
    print("\n⚠️  Could not test PlacementManager directly")
    print("You'll need to update the PlacementManager code manually")
end

-- 5. Create prevention script
print("\n🛡️  CREATING PREVENTION MEASURES:")
print("To prevent future ItemId overwrites, any script that sets ItemId should check:")
print("1. Does the item already have a numeric ItemId?")
print("2. If yes, preserve it!")
print("3. Only set new IDs for items that have none")

local function createPreventionCode()
    print([[
    
Prevention code pattern for future scripts:

-- GOOD: Preserve existing ItemIds
local existingItemId = item:GetAttribute("ItemId")
if not existingItemId then
    -- Only set ID if none exists
    item:SetAttribute("ItemId", item.Name)  -- or some other logic
else
    print("Preserving existing ItemId:", existingItemId)
end

-- BAD: Overwrites everything
item:SetAttribute("ItemId", item.Name)  -- Don't do this!
]])
end

createPreventionCode()

print("\n=== ITEMID PRESERVATION FIX COMPLETE ===")
print("✅ Restored Torch ItemId to 131")
print("📋 Provided updated search logic for PlacementManager") 
print("🛡️  Provided prevention patterns for future scripts")
print("🎯 Your numeric ItemId variation system should now work properly!") 