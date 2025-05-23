-- PreviewManager.luau
-- Handles preview items, hand items, and visual feedback during placement

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local PreviewManager = {}
PreviewManager.__index = PreviewManager

function PreviewManager.new(itemTemplateManager)
    local self = setmetatable({}, PreviewManager)
    
    self.itemTemplateManager = itemTemplateManager
    
    -- Preview state
    self.previewItem = nil
    self.handItem = nil
    self.handItemId = nil
    
    -- Movement connections for cleanup
    self.movementConnections = {}
    self.inputConnections = {}
    
    return self
end

-- Create a preview item for placement
function PreviewManager:CreatePreviewItem(itemId)
    if RunService:IsServer() then return nil end
    
    print("PreviewManager: Creating preview item for:", itemId)
    
    -- Normalize the item ID
    local normalizedItemId = itemId:gsub(" ", "_")
    
    -- Get the template
    local template = self.itemTemplateManager:GetItemTemplate(normalizedItemId)
    if not template then
        warn("PreviewManager: Failed to find template for", normalizedItemId)
        return nil
    end
    
    -- Clone the template for preview
    local previewItem = self.itemTemplateManager:CloneTemplate(template, "Preview_" .. normalizedItemId)
    if not previewItem then
        warn("PreviewManager: Failed to clone template for", normalizedItemId)
        return nil
    end
    
    -- Make preview translucent and disable collision
    self:_ApplyPreviewProperties(previewItem)
    
    -- Add preview to workspace
    previewItem.Parent = Workspace
    
    return previewItem
end

-- Apply visual properties to make item look like a preview
function PreviewManager:_ApplyPreviewProperties(item)
    if item:IsA("Model") then
        for _, part in ipairs(item:GetDescendants()) do
            if part:IsA("BasePart") then
                -- Store original properties
                part:SetAttribute("preview_original_transparency", part.Transparency)
                part:SetAttribute("preview_original_cancollide", part.CanCollide)
                part:SetAttribute("preview_original_anchored", part.Anchored)
                
                -- Apply preview effects
                part.Transparency = math.min(0.8, part.Transparency + 0.5)
                part.CanCollide = false
                part.Anchored = true
                part:SetAttribute("is_preview", true)
            end
        end
    elseif item:IsA("BasePart") then
        -- Store original properties
        item:SetAttribute("preview_original_transparency", item.Transparency)
        item:SetAttribute("preview_original_cancollide", item.CanCollide)
        item:SetAttribute("preview_original_anchored", item.Anchored)
        
        -- Apply preview effects
        item.Transparency = math.min(0.8, item.Transparency + 0.5)
        item.CanCollide = false
        item.Anchored = true
        item:SetAttribute("is_preview", true)
    end
    
    -- Create a highlight effect for better visibility
    local highlight = Instance.new("Highlight")
    highlight.Name = "PreviewHighlight"
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.FillColor = Color3.fromRGB(0, 255, 0) -- Green fill
    highlight.OutlineColor = Color3.fromRGB(0, 255, 0) -- Green outline
    highlight.Parent = item
end

-- Show an item in the player's hand for inspection
function PreviewManager:ShowItemInHand(itemId, onPlaceCallback, onCancelCallback)
    if RunService:IsServer() then return false end
    
    print("PreviewManager: Showing item in hand:", itemId)
    
    -- Clear any existing item in hand
    self:ClearItemInHand()
    
    -- Get the item template
    local normalizedItemId = itemId:gsub(" ", "_")
    local template = self.itemTemplateManager:GetItemTemplate(normalizedItemId)
    if not template then
        warn("PreviewManager: Failed to find template for", normalizedItemId)
        return false
    end
    
    -- Clone the template for display
    local displayItem = self.itemTemplateManager:CloneTemplate(template, "HandItem_" .. normalizedItemId)
    if not displayItem then
        warn("PreviewManager: Failed to clone template for hand item", normalizedItemId)
        return false
    end
    
    -- Apply hand item properties
    self:_ApplyHandItemProperties(displayItem)
    
    -- Add to workspace
    displayItem.Parent = Workspace
    
    -- Store references
    self.handItem = displayItem
    self.handItemId = normalizedItemId
    
    -- Setup positioning and input handling
    self:_SetupHandItemBehavior(onPlaceCallback, onCancelCallback)
    
    return true
end

-- Apply visual properties for hand items
function PreviewManager:_ApplyHandItemProperties(item)
    if item:IsA("Model") then
        for _, part in ipairs(item:GetDescendants()) do
            if part:IsA("BasePart") then
                -- Store original properties
                part:SetAttribute("hand_original_transparency", part.Transparency)
                part:SetAttribute("hand_original_cancollide", part.CanCollide)
                part:SetAttribute("hand_original_anchored", part.Anchored)
                
                -- Apply hand item effects
                part.Transparency = math.max(0, part.Transparency - 0.2) -- Make slightly more visible
                part.CanCollide = false
                part.Anchored = true
                part:SetAttribute("is_hand_item", true)
            end
        end
    elseif item:IsA("BasePart") then
        -- Store original properties
        item:SetAttribute("hand_original_transparency", item.Transparency)
        item:SetAttribute("hand_original_cancollide", item.CanCollide)
        item:SetAttribute("hand_original_anchored", item.Anchored)
        
        -- Apply hand item effects
        item.Transparency = math.max(0, item.Transparency - 0.2)
        item.CanCollide = false
        item.Anchored = true
        item:SetAttribute("is_hand_item", true)
    end
    
    -- Add a highlight effect for better visibility
    local highlight = Instance.new("Highlight")
    highlight.Name = "HandItemHighlight"
    highlight.FillTransparency = 0.3
    highlight.OutlineTransparency = 0
    highlight.FillColor = Color3.fromRGB(255, 215, 0) -- Gold fill
    highlight.OutlineColor = Color3.fromRGB(255, 215, 0) -- Gold outline
    highlight.Parent = item
end

-- Setup behavior for hand item (positioning and input)
function PreviewManager:_SetupHandItemBehavior(onPlaceCallback, onCancelCallback)
    local player = Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    
    -- Connect movement to update hand item position
    local movementConnection = RunService.RenderStepped:Connect(function()
        if not self.handItem then
            return
        end
        
        -- Position in front of the player
        local offset = humanoidRootPart.CFrame.LookVector * 3
        local position = humanoidRootPart.Position + offset
        position = Vector3.new(position.X, position.Y + 1, position.Z) -- Adjust height
        
        -- Rotate the item slowly
        local rotationAngle = tick() % (2 * math.pi) -- Slow continuous rotation
        local rotationCFrame = CFrame.Angles(0, rotationAngle, 0)
        
        if self.handItem:IsA("Model") and self.handItem.PrimaryPart then
            self.handItem:SetPrimaryPartCFrame(CFrame.new(position) * rotationCFrame)
        else
            self.handItem.CFrame = CFrame.new(position) * rotationCFrame
        end
    end)
    
    -- Setup input handler for interaction
    local inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            -- Left click to place
            if onPlaceCallback and self.handItemId then
                onPlaceCallback(self.handItemId)
            end
            
            -- Clear the hand item
            self:ClearItemInHand()
            
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Escape then
            -- Right click or Escape to cancel
            if onCancelCallback then
                onCancelCallback()
            end
            
            self:ClearItemInHand()
        end
    end)
    
    -- Store connections for cleanup
    table.insert(self.movementConnections, movementConnection)
    table.insert(self.inputConnections, inputConnection)
end

-- Clear any displayed item from hand
function PreviewManager:ClearItemInHand()
    if RunService:IsServer() then return end
    
    if self.handItem then
        print("PreviewManager: Clearing item from hand:", self.handItem.Name)
        
        -- Restore original properties before destroying
        self:_RestoreHandItemProperties(self.handItem)
        
        self.handItem:Destroy()
        self.handItem = nil
        self.handItemId = nil
    end
    
    -- Clean up connections
    for _, connection in ipairs(self.movementConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    for _, connection in ipairs(self.inputConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    
    self.movementConnections = {}
    self.inputConnections = {}
end

-- Clear preview item
function PreviewManager:ClearPreviewItem()
    if RunService:IsServer() then return end
    
    if self.previewItem then
        print("PreviewManager: Clearing preview item:", self.previewItem.Name)
        
        -- Restore original properties before destroying
        self:_RestorePreviewProperties(self.previewItem)
        
        self.previewItem:Destroy()
        self.previewItem = nil
    end
end

-- Clear all preview items
function PreviewManager:ClearAll()
    self:ClearItemInHand()
    self:ClearPreviewItem()
end

-- Update preview item position during placement
function PreviewManager:UpdatePreviewPosition(position, orientation)
    if not self.previewItem then
        return
    end
    
    if self.previewItem:IsA("Model") and self.previewItem.PrimaryPart then
        self.previewItem:SetPrimaryPartCFrame(CFrame.new(position) * orientation)
    elseif self.previewItem:IsA("BasePart") then
        self.previewItem.CFrame = CFrame.new(position) * orientation
    end
end

-- Set preview item
function PreviewManager:SetPreviewItem(item)
    self:ClearPreviewItem()
    self.previewItem = item
end

-- Get current preview item
function PreviewManager:GetPreviewItem()
    return self.previewItem
end

-- Get current hand item info
function PreviewManager:GetHandItemInfo()
    return self.handItem, self.handItemId
end

-- Restore preview properties
function PreviewManager:_RestorePreviewProperties(item)
    if item:IsA("Model") then
        for _, part in ipairs(item:GetDescendants()) do
            if part:IsA("BasePart") then
                -- Restore original properties
                if part:GetAttribute("preview_original_transparency") ~= nil then
                    part.Transparency = part:GetAttribute("preview_original_transparency")
                end
                if part:GetAttribute("preview_original_cancollide") ~= nil then
                    part.CanCollide = part:GetAttribute("preview_original_cancollide")
                end
                if part:GetAttribute("preview_original_anchored") ~= nil then
                    part.Anchored = part:GetAttribute("preview_original_anchored")
                end
                part:SetAttribute("is_preview", nil)
            end
        end
    elseif item:IsA("BasePart") then
        -- Restore original properties
        if item:GetAttribute("preview_original_transparency") ~= nil then
            item.Transparency = item:GetAttribute("preview_original_transparency")
        end
        if item:GetAttribute("preview_original_cancollide") ~= nil then
            item.CanCollide = item:GetAttribute("preview_original_cancollide")
        end
        if item:GetAttribute("preview_original_anchored") ~= nil then
            item.Anchored = item:GetAttribute("preview_original_anchored")
        end
        item:SetAttribute("is_preview", nil)
    end
    
    -- Remove preview highlight
    local highlight = item:FindFirstChild("PreviewHighlight")
    if highlight then
        highlight:Destroy()
    end
end

-- Restore hand item properties
function PreviewManager:_RestoreHandItemProperties(item)
    if item:IsA("Model") then
        for _, part in ipairs(item:GetDescendants()) do
            if part:IsA("BasePart") then
                -- Restore original properties
                if part:GetAttribute("hand_original_transparency") ~= nil then
                    part.Transparency = part:GetAttribute("hand_original_transparency")
                end
                if part:GetAttribute("hand_original_cancollide") ~= nil then
                    part.CanCollide = part:GetAttribute("hand_original_cancollide")
                end
                if part:GetAttribute("hand_original_anchored") ~= nil then
                    part.Anchored = part:GetAttribute("hand_original_anchored")
                end
                part:SetAttribute("is_hand_item", nil)
            end
        end
    elseif item:IsA("BasePart") then
        -- Restore original properties
        if item:GetAttribute("hand_original_transparency") ~= nil then
            item.Transparency = item:GetAttribute("hand_original_transparency")
        end
        if item:GetAttribute("hand_original_cancollide") ~= nil then
            item.CanCollide = item:GetAttribute("hand_original_cancollide")
        end
        if item:GetAttribute("hand_original_anchored") ~= nil then
            item.Anchored = item:GetAttribute("hand_original_anchored")
        end
        item:SetAttribute("is_hand_item", nil)
    end
    
    -- Remove hand item highlight
    local highlight = item:FindFirstChild("HandItemHighlight")
    if highlight then
        highlight:Destroy()
    end
end

return PreviewManager 