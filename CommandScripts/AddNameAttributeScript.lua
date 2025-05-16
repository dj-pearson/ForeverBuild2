--[[
    AddNameAttributeScript.lua
    This script traverses the Items folder and adds a 'name' attribute to each model
    based on its parent folder name while preserving the existing 'item' attribute
]]

-- Get the Items folder in Workspace
local itemsFolder = game.Workspace:FindFirstChild("Items")

if not itemsFolder then
    error("Could not find Items folder in Workspace")
    return
end

local totalProcessed = 0
local totalUpdated = 0

-- Function to recursively process models
local function processModels(folder, folderName)
    -- Process all children in this folder
    for _, child in ipairs(folder:GetChildren()) do
        -- If it's a Model
        if child:IsA("Model") then
            totalProcessed = totalProcessed + 1
            
            -- Check if it already has the attribute
            local currentNameAttribute = child:GetAttribute("name")
            
            -- Add the name attribute based on parent folder
            child:SetAttribute("name", folderName)
            
            if currentNameAttribute ~= folderName then
                totalUpdated = totalUpdated + 1
                print("Updated model: " .. child.Name .. " with name attribute: " .. folderName)
            end
            
        -- If it's a Folder, recursively process with its name
        elseif child:IsA("Folder") then
            processModels(child, child.Name)
        end
    end
end

print("Starting attribute update process...")
processModels(itemsFolder, "Items")
print("Attribute update completed!")
print("Total models processed: " .. totalProcessed)
print("Total models updated: " .. totalUpdated) 