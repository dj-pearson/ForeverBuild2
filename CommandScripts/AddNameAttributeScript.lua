--[[
    AddNameAttributeScript.lua
    This script traverses both Workspace.Items and ServerStorage.Items and assigns attributes:
    - name: Parent folder name
    - item: Model name or default
    - assetId: From Constants.ITEMS if matching, otherwise default
    - tier: From Constants.ITEMS if matching, otherwise 'BASIC'
    - priceIngame: From Constants.ITEMS if matching, otherwise 0
    - priceRobux: From Constants.ITEMS if matching, otherwise 0
    - description: From Constants.ITEMS if matching, otherwise 'No description available.'
]]

local Constants = require(game:GetService("ReplicatedStorage").shared.core.Constants)

local function processFolder(folder, folderName)
    local totalProcessed = 0
    local totalUpdated = 0

    local function processModels(folder, folderName)
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("Model") then
                totalProcessed = totalProcessed + 1
                local modelName = child.Name
                local itemData = Constants.ITEMS[modelName] or Constants.ITEMS["Unknown_Item"]

                -- Assign attributes
                child:SetAttribute("name", folderName)
                child:SetAttribute("item", modelName)
                child:SetAttribute("assetId", itemData.icon or "rbxassetid://3284930147") -- Default generic ID
                child:SetAttribute("tier", itemData.tier or "BASIC")
                child:SetAttribute("priceIngame", itemData.price.INGAME or 0)
                child:SetAttribute("priceRobux", itemData.price.ROBUX or 0)
                child:SetAttribute("description", itemData.description or "No description available.")

                totalUpdated = totalUpdated + 1
                print("Updated model: " .. modelName .. " in folder: " .. folderName)
            elseif child:IsA("Folder") then
                processModels(child, child.Name)
            end
        end
    end

    processModels(folder, folderName)
    return totalProcessed, totalUpdated
end

local workspaceItems = game.Workspace:FindFirstChild("Items")
local serverStorageItems = game:GetService("ServerStorage"):FindFirstChild("Items")

if not workspaceItems and not serverStorageItems then
    error("Could not find Items folder in Workspace or ServerStorage")
    return
end

local totalProcessed = 0
local totalUpdated = 0

if workspaceItems then
    local processed, updated = processFolder(workspaceItems, "Workspace.Items")
    totalProcessed = totalProcessed + processed
    totalUpdated = totalUpdated + updated
end

if serverStorageItems then
    local processed, updated = processFolder(serverStorageItems, "ServerStorage.Items")
    totalProcessed = totalProcessed + processed
    totalUpdated = totalUpdated + updated
end

print("Attribute update completed!")
print("Total models processed: " .. totalProcessed)
print("Total models updated: " .. totalUpdated) 