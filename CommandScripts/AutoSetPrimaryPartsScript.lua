--[[
    AutoSetPrimaryPartsScript.lua
    This script traverses Workspace.Items and ServerStorage.Items recursively.
    For each Model found without a PrimaryPart, it attempts to set one by:
    1. Looking for an existing part with a preferred name (e.g., "Handle", "Root").
    2. If not found, looking for the largest part by volume.
    3. If still not found (and the model contains parts), creating a new, small, 
       invisible part at the model's center named "AutoPrimaryPart".
    Run this script from the Roblox Studio command bar or by saving it and running it.
]]

local function processModel(model)
    if not model:IsA("Model") then
        return -- Should not happen if called correctly, but good check
    end

    if model.PrimaryPart then
        -- print("Model '" .. model:GetFullName() .. "' already has a PrimaryPart: '" .. model.PrimaryPart.Name .. "'")
        return
    end

    -- print("Processing model for PrimaryPart: " .. model:GetFullName())

    local preferredPart = nil
    local largestPart = nil
    local largestVolume = 0
    local allPartsInModel = {}

    local preferredNames = {
        humanoidrootpart = true, torso = true, handle = true, 
        body = true, rootpart = true, middle = true, root = true 
    }

    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            table.insert(allPartsInModel, descendant)
            
            if not preferredPart and preferredNames[descendant.Name:lower()] then
                preferredPart = descendant
                -- print("Found preferred part candidate: " .. descendant:GetFullName())
            end
            
            local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
            if volume > largestVolume then
                largestVolume = volume
                largestPart = descendant
            end
        end
    end

    if #allPartsInModel == 0 then
        print("Model '" .. model:GetFullName() .. "' has no BaseParts. Cannot set or create PrimaryPart.")
        return
    end

    local partToSetAsPrimary = preferredPart or largestPart

    if partToSetAsPrimary then
        model.PrimaryPart = partToSetAsPrimary
        print("Set PrimaryPart for '" .. model:GetFullName() .. "' to existing part: '" .. partToSetAsPrimary:GetFullName() .. "'")
    else
        -- This case means parts exist, but no preferred name found, and all parts have zero volume (or were not BaseParts, caught by earlier check).
        print("No suitable existing part found for '" .. model:GetFullName() .. "' (no preferred name and no part with volume > 0). Creating new PrimaryPart.")
        
        local modelCFrame, modelSize = model:GetBoundingBox() -- Safe due to #allPartsInModel > 0
        
        local newPrimaryPart = Instance.new("Part")
        newPrimaryPart.Name = "AutoPrimaryPart"
        newPrimaryPart.Size = Vector3.new(0.5, 0.5, 0.5) -- Small and unobtrusive
        newPrimaryPart.CFrame = modelCFrame
        newPrimaryPart.Transparency = 1
        newPrimaryPart.CanCollide = false
        newPrimaryPart.Anchored = true -- Important for a PrimaryPart not physically connected
        newPrimaryPart.Parent = model
        
        model.PrimaryPart = newPrimaryPart
        print("Created and set new PrimaryPart 'AutoPrimaryPart' for model: " .. model:GetFullName())
    end
end

local function traverseAndProcess(container, containerName)
    if not container then
        print(containerName .. " not found. Skipping.")
        return
    end
    
    print("--- Processing contents of " .. containerName .. " ---")

    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Model") then
            processModel(child) -- Process the model itself
        end
        
        -- Recurse into Folders or Models that might contain more models
        if child:IsA("Folder") or child:IsA("Model") then
            traverseAndProcess(child, child:GetFullName()) -- Pass child's full name for clearer logs in recursion
        end
    end
end

local workspaceItems = game.Workspace:FindFirstChild("Items")
local serverStorageItems = game:GetService("ServerStorage"):FindFirstChild("Items")

print("--- Starting PrimaryPart assignment script ---")

traverseAndProcess(workspaceItems, "Workspace.Items")
traverseAndProcess(serverStorageItems, "ServerStorage.Items")

print("--- PrimaryPart assignment script finished ---") 