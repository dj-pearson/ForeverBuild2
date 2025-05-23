-- Fix Proximity Detection Depth for Glow Items
-- This updates the existing ItemInteractionClient to detect items in deeper subfolders

print("=== FIXING PROXIMITY DETECTION FOR DEEPER SUBFOLDERS ===")

local filePath = "src/client/interaction/ItemInteractionClient.luau"

-- Read the current file
local success, content = pcall(function()
    return readfile(filePath)
end)

if not success then
    print("✗ Could not read ItemInteractionClient.luau file")
    return
end

-- Find and replace the problematic GetInteractableFromPart function
local oldPattern = [[while ancestor and ancestor.Parent ~= itemsFolder and not ancestor:IsDescendantOf(itemsFolder) do 
            ancestor = ancestor.Parent
        end]]

local newCode = [[-- Look for any Model with purchase attributes in the Items folder tree
        while ancestor and ancestor.Parent do
            if ancestor.Parent == itemsFolder then
                -- Direct child of Items folder (e.g., Basic, Level_1, etc.)
                break
            elseif ancestor:IsDescendantOf(itemsFolder) and (ancestor:GetAttribute("Purchasable") or ancestor:GetAttribute("Price") or ancestor:GetAttribute("priceIngame")) then
                -- Deeper nested item with purchase attributes (e.g., Glow items)
                break
            end
            ancestor = ancestor.Parent
        end]]

-- Replace the old code with the new code
local updatedContent = content:gsub(string.gsub(oldPattern, "([%(%)%+%-%*%?%[%]%^%$%%])", "%%%1"), newCode)

if updatedContent == content then
    print("✗ Could not find the target code to replace")
    print("Looking for pattern:", oldPattern)
    return
end

-- Write the updated content back to the file
local writeSuccess = pcall(function()
    writefile(filePath, updatedContent)
end)

if writeSuccess then
    print("✓ Successfully updated ItemInteractionClient.luau")
    print("✓ Proximity detection now works for items in deeper subfolders")
    print("")
    print("CHANGES MADE:")
    print("• Updated GetInteractableFromPart function")
    print("• Now detects items with purchase attributes at any depth in Items folder")
    print("• Glow items in Workspace > Items > Basic > Glow should now show purchase popup")
    print("")
    print("The existing purchase system will now work for your glow items!")
else
    print("✗ Failed to write updated file")
end 