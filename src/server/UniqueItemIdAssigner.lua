-- UniqueItemIdAssigner.lua
-- Assigns and manages unique, persistent numeric IDs for items in Workspace.Items

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local uniqueIdDataStore = DataStoreService:GetDataStore("UniqueItemIds")
local LAST_ID_KEY = "LastAssignedId"

local MAX_RETRIES = 3
local PLACED_ITEMS_PARENT_FOLDER_NAME = "World_Items" -- Consistent with PlacementManager
local PLACED_ITEMS_SUBFOLDER_NAME = "Placed" -- Consistent with PlacementManager

local UniqueItemIdAssigner = {} -- Create the module table

-- Function to get the next available unique ID
local function getNextUniqueId()
    local currentId
    local success, err

    for i = 1, MAX_RETRIES do
        success, currentId = pcall(function()
            return uniqueIdDataStore:GetAsync(LAST_ID_KEY)
        end)

        if success then
            currentId = tonumber(currentId) or 0 -- Default to 0 if nil or not a number
            local nextId = currentId + 1
            
            local setSuccess, setErr = pcall(function()
                uniqueIdDataStore:SetAsync(LAST_ID_KEY, nextId)
            end)

            if setSuccess then
                print(string.format("UniqueItemIdAssigner: Successfully assigned new UniqueItemId: %d (Previous: %d)", nextId, currentId))
                return nextId
            else
                warn(string.format("UniqueItemIdAssigner: Failed to set next ID in DataStore on attempt %d: %s", i, tostring(setErr)))
            end
        else
            warn(string.format("UniqueItemIdAssigner: Failed to get LAST_ID_KEY from DataStore on attempt %d: %s", i, tostring(err)))
        end
        
        if i < MAX_RETRIES then
            task.wait(2) -- Wait before retrying
        end
    end
    
    warn("UniqueItemIdAssigner: Exhausted retries for DataStore operation. Cannot generate new UniqueItemId.")
    return nil -- Return nil if all retries fail
end

-- Function to assign UniqueItemIds to existing items in Workspace.Items
local function assignUniqueIdsToExistingItems()
    if RunService:IsClient() then return end

    print(string.format("UniqueItemIdAssigner: Starting scan of Workspace.%s/%s to assign UniqueItemIds...", PLACED_ITEMS_PARENT_FOLDER_NAME, PLACED_ITEMS_SUBFOLDER_NAME))

    local worldItemsFolder = Workspace:FindFirstChild(PLACED_ITEMS_PARENT_FOLDER_NAME)
    if not worldItemsFolder then
        warn(string.format("UniqueItemIdAssigner: Workspace.%s folder not found. Cannot scan for existing items.", PLACED_ITEMS_PARENT_FOLDER_NAME))
        return
    end

    local itemsFolder = worldItemsFolder:FindFirstChild(PLACED_ITEMS_SUBFOLDER_NAME)
    if not itemsFolder then
        warn(string.format("UniqueItemIdAssigner: Workspace.%s/%s folder not found. Cannot scan for existing items.", PLACED_ITEMS_PARENT_FOLDER_NAME, PLACED_ITEMS_SUBFOLDER_NAME))
        -- Optionally, create it if PlacementManager might not have run yet, though it should.
        -- itemsFolder = Instance.new("Folder")
        -- itemsFolder.Name = PLACED_ITEMS_SUBFOLDER_NAME
        -- itemsFolder.Parent = worldItemsFolder
        -- print(string.format("UniqueItemIdAssigner: Created Workspace.%s/%s folder.", PLACED_ITEMS_PARENT_FOLDER_NAME, PLACED_ITEMS_SUBFOLDER_NAME))
        return
    end

    local itemsProcessed = 0
    local idsAssigned = 0

    for _, itemInstance in ipairs(itemsFolder:GetChildren()) do
        itemsProcessed = itemsProcessed + 1
        if itemInstance:IsA("Model") or itemInstance:IsA("BasePart") then -- Process models or baseparts
            local existingUniqueId = itemInstance:GetAttribute("UniqueItemId")

            if existingUniqueId == nil then
                local newId = getNextUniqueId()
                if newId then
                    itemInstance:SetAttribute("UniqueItemId", newId)
                    print(string.format("UniqueItemIdAssigner: Assigned new UniqueItemId %d to item '%s' in %s/%s", newId, itemInstance.Name, PLACED_ITEMS_PARENT_FOLDER_NAME, PLACED_ITEMS_SUBFOLDER_NAME))
                    idsAssigned = idsAssigned + 1
                else
                    warn(string.format("UniqueItemIdAssigner: Could not assign UniqueItemId to item '%s' in %s/%s due to DataStore issues.", itemInstance.Name, PLACED_ITEMS_PARENT_FOLDER_NAME, PLACED_ITEMS_SUBFOLDER_NAME))
                end
            else
                -- Optional: Validate existing ID if needed (e.g., ensure it's a number)
                -- print(string.format("UniqueItemIdAssigner: Item '%s' in %s/%s already has UniqueItemId: %s", itemInstance.Name, PLACED_ITEMS_PARENT_FOLDER_NAME, PLACED_ITEMS_SUBFOLDER_NAME, tostring(existingUniqueId)))
            end
        else
            -- warn(string.format("UniqueItemIdAssigner: Skipping child '%s' in %s/%s as it is not a Model or BasePart.", itemInstance.Name, PLACED_ITEMS_PARENT_FOLDER_NAME, PLACED_ITEMS_SUBFOLDER_NAME))
        end
    end

    print(string.format("UniqueItemIdAssigner: Scan of %s/%s complete. Processed %d items, assigned %d new UniqueItemIds.", PLACED_ITEMS_PARENT_FOLDER_NAME, PLACED_ITEMS_SUBFOLDER_NAME, itemsProcessed, idsAssigned))
end

-- Public function to assign a UniqueItemId to a new item
function UniqueItemIdAssigner.assignIdToNewItem(itemInstance)
    if RunService:IsClient() then return end -- Should only run on server

    if not itemInstance or not (itemInstance:IsA("Model") or itemInstance:IsA("BasePart")) then
        warn("UniqueItemIdAssigner: assignIdToNewItem called with invalid itemInstance:", itemInstance)
        return
    end

    -- Check if it already has an ID (e.g., if it was cloned from an item that had one)
    if itemInstance:GetAttribute("UniqueItemId") ~= nil then
        -- print(string.format("UniqueItemIdAssigner: Item '%s' already has a UniqueItemId (%s). Skipping assignment.", itemInstance.Name, tostring(itemInstance:GetAttribute("UniqueItemId"))))
        return
    end

    local newId = getNextUniqueId()
    if newId then
        itemInstance:SetAttribute("UniqueItemId", newId)
        print(string.format("UniqueItemIdAssigner: Assigned new UniqueItemId %d to new item '%s'", newId, itemInstance.Name))
    else
        warn(string.format("UniqueItemIdAssigner: Could not assign UniqueItemId to new item '%s' due to DataStore issues.", itemInstance.Name))
    end
end

-- Initial scan when the module is first required on the server
if RunService:IsServer() then
    -- Wait a moment for other services and folders to potentially initialize
    task.wait(5) 
    assignUniqueIdsToExistingItems()
end

return UniqueItemIdAssigner
