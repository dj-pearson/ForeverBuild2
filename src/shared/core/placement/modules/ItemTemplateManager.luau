-- ItemTemplateManager.luau
-- Handles finding and managing item templates for placement

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local ItemTemplateManager = {}
ItemTemplateManager.__index = ItemTemplateManager

function ItemTemplateManager.new()
    local self = setmetatable({}, ItemTemplateManager)
    return self
end

-- Get item template from various possible locations
function ItemTemplateManager:GetItemTemplate(itemId)
    local normalizedItemId = itemId:gsub(" ", "_")
    
    -- Client-side: Check ReplicatedStorage.ItemTemplates first
    if RunService:IsClient() then
        local itemTemplates = ReplicatedStorage:FindFirstChild("ItemTemplates")
        if itemTemplates then
            local template = itemTemplates:FindFirstChild(normalizedItemId)
            if template then
                print("ItemTemplateManager (Client): Found template in ReplicatedStorage.ItemTemplates:", normalizedItemId)
                return template
            end
        end
    end
    
    -- Server-side: Check ServerStorage.Items (with recursive search)
    if RunService:IsServer() then
        local items = ServerStorage:FindFirstChild("Items")
        if items then
            local template = self:_FindTemplateRecursive(items, normalizedItemId)
            if template then
                print("ItemTemplateManager: Found template in ServerStorage.Items (recursive):", normalizedItemId)
                return template
            end
        end
    end
    
    -- Fallback: Check Workspace.Items
    local workspaceItems = game.Workspace:FindFirstChild("Items")
    if workspaceItems then
        local template = self:_FindTemplateRecursive(workspaceItems, normalizedItemId)
        if template then
            print("ItemTemplateManager: Found template in Workspace.Items (recursive):", normalizedItemId)
            return template
        end
    end
    
    -- Additional fallback: Check ReplicatedStorage.Items
    local replicatedItems = ReplicatedStorage:FindFirstChild("Items")
    if replicatedItems then
        local template = self:_FindTemplateRecursive(replicatedItems, normalizedItemId)
        if template then
            print("ItemTemplateManager: Found template in ReplicatedStorage.Items (recursive):", normalizedItemId)
            return template
        end
    end
    
    warn("ItemTemplateManager: Template not found for item:", normalizedItemId)
    return nil
end

-- Recursively search for template in a folder
function ItemTemplateManager:_FindTemplateRecursive(parent, itemId)
    -- First try direct child
    local direct = parent:FindFirstChild(itemId)
    if direct then
        return direct
    end
    
    -- Then search in subfolders
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("Folder") then
            local found = self:_FindTemplateRecursive(child, itemId)
            if found then
                return found
            end
        end
    end
    
    return nil
end

-- Validate that a template is suitable for placement
function ItemTemplateManager:ValidateTemplate(template)
    if not template then
        return false, "Template is nil"
    end
    
    if not (template:IsA("Model") or template:IsA("BasePart")) then
        return false, "Template must be a Model or BasePart"
    end
    
    -- For Models, ensure they have a PrimaryPart or at least one Part
    if template:IsA("Model") then
        if not template.PrimaryPart then
            local parts = {}
            for _, child in ipairs(template:GetDescendants()) do
                if child:IsA("BasePart") then
                    table.insert(parts, child)
                end
            end
            
            if #parts == 0 then
                return false, "Model template has no parts"
            end
            
            -- Auto-set PrimaryPart if not set
            template.PrimaryPart = parts[1]
            print("ItemTemplateManager: Auto-set PrimaryPart for template:", template.Name)
        end
    end
    
    return true, "Valid template"
end

-- Clone a template for use
function ItemTemplateManager:CloneTemplate(template, newName)
    local isValid, reason = self:ValidateTemplate(template)
    if not isValid then
        warn("ItemTemplateManager: Cannot clone invalid template:", reason)
        return nil
    end
    
    local clone = template:Clone()
    if newName then
        clone.Name = newName
    end
    
    return clone
end

-- Get template size for placement calculations
function ItemTemplateManager:GetTemplateSize(template)
    local isValid, reason = self:ValidateTemplate(template)
    if not isValid then
        warn("ItemTemplateManager: Cannot get size of invalid template:", reason)
        return Vector3.new(4, 4, 4) -- Default size
    end
    
    if template:IsA("Model") then
        local cf, size = template:GetBoundingBox()
        return size
    elseif template:IsA("BasePart") then
        return template.Size
    end
    
    return Vector3.new(4, 4, 4) -- Default fallback
end

return ItemTemplateManager 