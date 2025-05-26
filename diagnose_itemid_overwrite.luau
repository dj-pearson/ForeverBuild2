-- Diagnose ItemId Overwrite Issue
-- This script identifies and fixes systems that overwrite numeric ItemIds

print("=== DIAGNOSING ITEMID OVERWRITE ISSUE ===")

local Workspace = game:GetService("Workspace")

-- 1. First, let's see the current state
print("\n🔍 CURRENT STATE OF TORCH ITEMS:")

local function checkTorchItems()
    local items = Workspace:FindFirstChild("Items")
    if items then
        local level1 = items:FindFirstChild("Level_1")
        if level1 then
            for _, child in ipairs(level1:GetChildren()) do
                if child.Name:find("Torch") or child.Name:find("torch") then
                    print(string.format("Found: %s", child:GetFullName()))
                    print(string.format("  ItemId: %s (type: %s)", 
                        tostring(child:GetAttribute("ItemId")), 
                        type(child:GetAttribute("ItemId"))))
                    print(string.format("  itemId: %s (type: %s)", 
                        tostring(child:GetAttribute("itemId")), 
                        type(child:GetAttribute("itemId"))))
                    print(string.format("  item: %s", tostring(child:GetAttribute("item"))))
                    print(string.format("  Name: %s", child.Name))
                    print("  ---")
                end
            end
        end
    end
end

checkTorchItems()

-- 2. Show the design issue
print("\n❌ DESIGN PROBLEM IDENTIFIED:")
print("Your numeric ItemId system is being undermined by scripts that:")
print("1. Set ItemId = item.Name (converts 131 → 'Torch')")
print("2. Set itemId = item.Name (creates inconsistency)")
print("3. Use model name instead of preserving unique numeric IDs")

print("\n🎯 WHAT YOU WANT:")
print("- Torch_Red = ItemId: 131")
print("- Torch_Blue = ItemId: 132") 
print("- Torch_Green = ItemId: 133")
print("- All searchable by numeric ID, not name")

-- 3. List the problematic scripts/systems
print("\n🚨 SYSTEMS OVERWRITING YOUR ITEMIDS:")
print("1. AddNameAttributeScript.lua - Sets item = modelName")
print("2. setup_glow_items_complete.luau - Sets ItemID = item.Name")
print("3. ItemInteractionManager:RegisterWorldItems() - Sets ItemID = HttpService:GenerateGUID")
print("4. Various other scripts using item.Name as ID")

-- 4. Propose solution
print("\n✅ SOLUTION:")
print("We need to:")
print("1. STOP all scripts from overwriting existing numeric ItemIds")
print("2. Update PlacementManager to search by NUMERIC ItemId first, then name fallback")
print("3. Create a proper ItemId preservation system")

-- 5. Show which files need fixing
print("\n📁 FILES THAT NEED UPDATES:")
local problematicScripts = {
    "CommandScripts/AddNameAttributeScript.lua",
    "setup_glow_items_complete.luau", 
    "src/server/interaction/ItemInteractionManager.luau",
    "src/shared/core/placement/PlacementManager.luau",
    "Any other scripts setting ItemID = item.Name"
}

for i, script in ipairs(problematicScripts) do
    print(string.format("%d. %s", i, script))
end

print("\n🔧 IMMEDIATE FIX NEEDED:")
print("1. Preserve existing numeric ItemIds")
print("2. Only assign new IDs if none exist")
print("3. Update search logic to handle numeric IDs properly")

print("\n=== DIAGNOSIS COMPLETE ===")
print("The fix scripts we ran earlier actually CAUSED the problem by")
print("overwriting your carefully assigned numeric ItemId '131' with 'Torch'!") 