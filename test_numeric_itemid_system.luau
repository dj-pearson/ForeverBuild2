-- Test Numeric ItemId System
-- This script validates that the PlacementManager properly handles numeric ItemIds

print("=== TESTING NUMERIC ITEMID SYSTEM ===")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- Only run on client for now
if not RunService:IsClient() then
    print("❌ This test script is for client-side only")
    return
end

print("✅ Running numeric ItemId system test...")

-- 1. Verify the Torch has correct numeric ItemId
print("\n🔍 STEP 1: Verifying Torch ItemId State")

local function checkTorchState()
    local items = Workspace:FindFirstChild("Items")
    if items then
        local level1 = items:FindFirstChild("Level_1")
        if level1 then
            local torch = level1:FindFirstChild("Torch")
            if torch then
                local itemId = torch:GetAttribute("ItemId")
                local itemIdLower = torch:GetAttribute("itemId")
                
                print(string.format("Torch found at: %s", torch:GetFullName()))
                print(string.format("  ItemId: %s (type: %s)", tostring(itemId), type(itemId)))
                print(string.format("  itemId: %s (type: %s)", tostring(itemIdLower), type(itemIdLower)))
                print(string.format("  Name: %s", torch.Name))
                
                if type(itemId) == "number" and itemId == 131 then
                    print("✅ SUCCESS: Torch has correct numeric ItemId (131)")
                    return true
                else
                    print("❌ FAILED: Torch does not have correct numeric ItemId")
                    return false
                end
            else
                print("❌ FAILED: Torch not found in Level_1")
                return false
            end
        else
            print("❌ FAILED: Level_1 folder not found")
            return false
        end
    else
        print("❌ FAILED: Items folder not found")
        return false
    end
end

local torchStateOK = checkTorchState()

-- 2. Test PlacementManager search capabilities
print("\n🔍 STEP 2: Testing PlacementManager Search")

local function testPlacementManagerSearch()
    local SharedModule
    local success, err = pcall(function()
        SharedModule = require(ReplicatedStorage:WaitForChild("shared"))
    end)
    
    if not success then
        print("❌ Could not access SharedModule:", err)
        return false
    end
    
    local PlacementManager = SharedModule.PlacementManager
    if not PlacementManager then
        print("❌ PlacementManager not found in SharedModule")
        return false
    end
    
    local manager = PlacementManager.new()
    if not manager then
        print("❌ Failed to create PlacementManager instance")
        return false
    end
    
    print("✅ PlacementManager instance created successfully")
    
    -- Test searches
    local tests = {
        {id = 131, description = "numeric ID 131"},
        {id = "131", description = "string ID '131'"},
        {id = "Torch", description = "string ID 'Torch'"},
    }
    
    local results = {}
    
    for _, test in ipairs(tests) do
        print(string.format("\n--- Testing search for %s ---", test.description))
        local template = manager:GetItemTemplate(test.id)
        
        if template then
            print(string.format("✅ SUCCESS: Found template using %s", test.description))
            print(string.format("  Template: %s", template:GetFullName()))
            print(string.format("  Template ItemId: %s", tostring(template:GetAttribute("ItemId"))))
            results[test.description] = true
        else
            print(string.format("❌ FAILED: Could not find template using %s", test.description))
            results[test.description] = false
        end
    end
    
    return results
end

local searchResults = testPlacementManagerSearch()

-- 3. Test item variation concept
print("\n🔍 STEP 3: Testing Item Variation Concept")

local function testItemVariations()
    print("Testing the concept of multiple torch variations...")
    
    -- Simulate what your system should support:
    local variations = {
        {name = "Torch_Red", itemId = 131, color = "Bright red"},
        {name = "Torch_Blue", itemId = 132, color = "Bright blue"}, 
        {name = "Torch_Green", itemId = 133, color = "Bright green"}
    }
    
    print("🎯 Your numeric ItemId system should support:")
    for _, variation in ipairs(variations) do
        print(string.format("  %s = ItemId: %d (%s)", variation.name, variation.itemId, variation.color))
    end
    
    print("\n📋 Benefits of numeric ItemIds:")
    print("  • Each variation has unique numeric ID")
    print("  • Can have same base name with different colors/properties")
    print("  • IDs don't conflict with display names")
    print("  • System can handle thousands of variations")
    print("  • Backward compatible with string fallbacks")
end

testItemVariations()

-- 4. Summary and recommendations
print("\n📊 FINAL RESULTS:")

print(string.format("Torch State: %s", torchStateOK and "✅ PASS" or "❌ FAIL"))

if searchResults then
    for description, result in pairs(searchResults) do
        print(string.format("Search %s: %s", description, result and "✅ PASS" or "❌ FAIL"))
    end
else
    print("PlacementManager Search: ❌ FAIL (Could not test)")
end

-- 5. Next steps
print("\n🚀 NEXT STEPS:")
if torchStateOK and searchResults and searchResults["numeric ID 131"] then
    print("✅ EXCELLENT! Your numeric ItemId system is working!")
    print("You can now:")
    print("  1. Create multiple torch variations with unique numeric IDs")
    print("  2. Use PlacementManager with numeric IDs: manager:GetItemTemplate(131)")
    print("  3. Maintain compatibility with string fallbacks")
    print("  4. Prevent future scripts from overwriting your numeric IDs")
else
    print("⚠️  Some issues remain:")
    if not torchStateOK then
        print("  • Run fix_itemid_preservation.luau to restore Torch ItemId to 131")
    end
    if not searchResults or not searchResults["numeric ID 131"] then
        print("  • PlacementManager search needs updating (code already provided)")
    end
end

print("\n=== NUMERIC ITEMID SYSTEM TEST COMPLETE ===") 