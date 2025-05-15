-- SETUP_ALL_ITEMS_AS_INTERACTABLE.lua
-- This script makes all items in the Workspace > Items folder interactable
-- Run this script in the Command Bar of Roblox Studio

print("====== SETUP ALL ITEMS AS INTERACTABLE ======")
print("This script will make all items in the Workspace > Items folder interactable.")

-- Define interaction types
local INTERACTION_TYPES = {
    "PICKUP",
    "USE",
    "CUSTOMIZE"
}

-- Default interaction type to use
local DEFAULT_INTERACTION_TYPE = "PICKUP"

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

-- Function to make an object interactable
local function makeObjectInteractable(object)
    -- Set the Interactable attribute
    object:SetAttribute("Interactable", true)
    
    -- Set interaction type if not already set
    if not object:GetAttribute("InteractionType") then
        object:SetAttribute("InteractionType", DEFAULT_INTERACTION_TYPE)
    end
    
    -- Check if it has a PrimaryPart for models
    if object:IsA("Model") and not object.PrimaryPart then
        print("  - Warning: " .. object.Name .. " is a Model but has no PrimaryPart.")
        
        -- Try to set a PrimaryPart if there are parts
        local firstPart = nil
        for _, child in pairs(object:GetChildren()) do
            if child:IsA("BasePart") then
                firstPart = child
                break
            end
        end
        
        if firstPart then
            object.PrimaryPart = firstPart
            print("    Set " .. firstPart.Name .. " as PrimaryPart.")
        end
    end
    
    -- Create a reference or move to World_Items
    local option = 2 -- Default option: Create references (change to 1 to move objects)
    
    if option == 1 then
        -- Option 1: Move actual object to World_Items
        object.Parent = worldItems
        print("  - Moved to World_Items folder")
    else
        -- Option 2: Create a reference in World_Items if not already there
        local reference = worldItems:FindFirstChild(object.Name)
        if not reference then
            -- Check if this is an item collection folder
            if #object:GetChildren() > 0 and not object:IsA("Model") then
                -- Create a folder with the same name
                local folder = Instance.new("Folder")
                folder.Name = object.Name
                folder.Parent = worldItems
                print("  - Created folder " .. object.Name .. " in World_Items")
                return folder
            else
                -- Create a reference to the individual item
                reference = object:Clone()
                reference.Parent = worldItems
                print("  - Created reference in World_Items folder")
            end
        end
        return reference
    end
    
    return object
end

-- Function to recursively process all items
local function processItems(folder, parentInWorldItems)
    print("Processing folder: " .. folder.Name)
    local itemCount = 0
    
    -- First, handle folders
    for _, child in pairs(folder:GetChildren()) do
        if #child:GetChildren() > 0 and not child:IsA("Model") then
            -- This is likely a folder, create a matching folder in World_Items
            local newFolder = parentInWorldItems:FindFirstChild(child.Name)
            if not newFolder then
                newFolder = Instance.new("Folder")
                newFolder.Name = child.Name
                newFolder.Parent = parentInWorldItems
                print("- Created folder: " .. newFolder.Name .. " in " .. parentInWorldItems.Name)
            end
            
            -- Process children of this folder
            local subItemCount = processItems(child, newFolder)
            itemCount = itemCount + subItemCount
        end
    end
    
    -- Then process individual items (models or parts)
    for _, child in pairs(folder:GetChildren()) do
        if child:IsA("Model") or child:IsA("BasePart") then
            makeObjectInteractable(child)
            itemCount = itemCount + 1
            print("- Made interactable: " .. child.Name)
        end
    end
    
    return itemCount
end

-- Start processing
print("\nStarting to process all items...")
local totalItems = processItems(itemsFolder, worldItems)
print("\nCompleted processing " .. totalItems .. " items.")
print("All items in the Items folder should now be interactable or referenced in World_Items folder.")
print("\nTo test interaction:")
print("1. Play the game")
print("2. Approach an item")
print("3. Look for highlight effect and interaction prompt")
print("4. Press E to interact with the item")
