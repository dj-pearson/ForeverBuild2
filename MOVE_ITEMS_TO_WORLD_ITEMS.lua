-- MOVE_ITEMS_TO_WORLD_ITEMS.lua
-- This script moves or creates references to all items in the Items folder to the World_Items folder
-- Run this script in the Command Bar of Roblox Studio

print("====== MOVE ITEMS TO WORLD_ITEMS ======")
print("This script will make all items in the Items folder accessible in World_Items folder.")

-- Check if Items folder exists
local itemsFolder = workspace:FindFirstChild("Items")
if not itemsFolder then
    warn("Items folder not found in workspace!")
    return
end

-- Check if World_Items folder exists, create if needed
local worldItems = workspace:FindFirstChild("World_Items")
if not worldItems then
    print("Creating World_Items folder in workspace...")
    worldItems = Instance.new("Folder")
    worldItems.Name = "World_Items"
    worldItems.Parent = workspace
end

-- Function to process items in a folder
local function processFolder(sourceFolder, targetFolder)
    print("Processing folder: " .. sourceFolder.Name)
    
    -- Create a matching folder structure in the target
    local targetSubfolder = targetFolder:FindFirstChild(sourceFolder.Name)
    if not targetSubfolder and sourceFolder ~= itemsFolder then
        targetSubfolder = Instance.new("Folder")
        targetSubfolder.Name = sourceFolder.Name
        targetSubfolder.Parent = targetFolder
        print("Created folder: " .. targetSubfolder.Name)
    else
        targetSubfolder = targetFolder
    end
    
    -- Process all children
    for _, child in pairs(sourceFolder:GetChildren()) do
        if child:IsA("Folder") then
            -- Recursively process subfolders
            processFolder(child, targetSubfolder)
        elseif child:IsA("Model") or child:IsA("BasePart") then
            -- Process model or part
            local existingItem = targetSubfolder:FindFirstChild(child.Name)
            
            if not existingItem then
                local newItem = child:Clone()
                newItem.Parent = targetSubfolder
                
                -- Setup for interaction
                newItem:SetAttribute("Interactable", true)
                newItem:SetAttribute("InteractionType", "PICKUP") -- Default to PICKUP
                
                -- Check/set PrimaryPart for models
                if newItem:IsA("Model") and not newItem.PrimaryPart then
                    for _, part in pairs(newItem:GetChildren()) do
                        if part:IsA("BasePart") then
                            newItem.PrimaryPart = part
                            break
                        end
                    end
                end
                
                print("Added item: " .. newItem.Name)
            end
        end
    end
end

-- Start processing
print("\nStarting to process items from Items folder to World_Items...")
processFolder(itemsFolder, worldItems)

print("\nDone! All items should now be available in the World_Items folder.")
print("Next steps:")
print("1. Run the VALIDATE_FIXED_INTERACTION_MODULE_ROBLOX_UPDATED.lua script")
print("2. Play the game to test interactions")
print("3. Approach items and press E to interact with them")
