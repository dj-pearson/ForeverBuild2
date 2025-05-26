-- MovementManager.luau
-- Handles item movement, rotation, and recall operations

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local MovementManager = {}
MovementManager.__index = MovementManager

function MovementManager.new(validator, remoteEventManager)
    local self = setmetatable({}, MovementManager)
    
    self.validator = validator
    self.remoteEventManager = remoteEventManager
    
    -- Movement state
    self.isMovingItem = false
    self.itemBeingMoved = nil
    self.movementConnections = {}
    
    -- Rotation state 
    self.isRotatingItem = false
    self.itemBeingRotated = nil
    self.currentRotationAngles = {X = 0, Y = 0, Z = 0}
    
    return self
end

-- Start moving an existing item
function MovementManager:StartMovingItem(item, player)
    if RunService:IsServer() then 
        warn("MovementManager: StartMovingItem should only be called on client")
        return false 
    end
    
    if self.isMovingItem then
        warn("MovementManager: Already moving an item")
        return false
    end
    
    -- Validate ownership
    local canMove, message = self.validator:CanMoveItem(player, item, item.Position)
    if not canMove then
        warn("MovementManager: Cannot move item:", message)
        return false
    end
    
    print("MovementManager: Starting item movement for:", item.Name)
    
    self.isMovingItem = true
    self.itemBeingMoved = item
    
    -- Make item transparent while moving
    self:_ApplyMovementVisuals(item)
    
    -- Setup movement controls
    self:_SetupMovementControls(player)
    
    return true
end

-- Apply visual effects while moving
function MovementManager:_ApplyMovementVisuals(item)
    -- Store original properties for all parts
    if item:IsA("Model") then
        for _, part in ipairs(item:GetDescendants()) do
            if part:IsA("BasePart") then
                -- Store all visual properties
                part:SetAttribute("original_transparency", part.Transparency)
                part:SetAttribute("original_color", part.BrickColor.Name)
                part:SetAttribute("original_material", part.Material.Name)
                part:SetAttribute("original_size", tostring(part.Size))
                part:SetAttribute("original_cancollide", part.CanCollide)
                
                -- Apply movement transparency
                part.Transparency = math.min(0.9, part.Transparency + 0.3)
            end
        end
    elseif item:IsA("BasePart") then
        -- Store all visual properties
        item:SetAttribute("original_transparency", item.Transparency)
        item:SetAttribute("original_color", item.BrickColor.Name)
        item:SetAttribute("original_material", item.Material.Name)
        item:SetAttribute("original_size", tostring(item.Size))
        item:SetAttribute("original_cancollide", item.CanCollide)
        
        -- Apply movement transparency
        item.Transparency = math.min(0.9, item.Transparency + 0.3)
    end
    
    -- Add movement highlight
    local highlight = Instance.new("Highlight")
    highlight.Name = "MovementHighlight"
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.FillColor = Color3.fromRGB(255, 255, 0) -- Yellow
    highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
    highlight.Parent = item
end

-- Setup movement input controls
function MovementManager:_SetupMovementControls(player)
    local mouse = player:GetMouse()
    
    -- Mouse movement to position item
    local moveConnection = mouse.Move:Connect(function()
        if not self.isMovingItem or not self.itemBeingMoved then return end
        
        self:_UpdateItemPosition()
    end)
    
    -- Input handling for placement/cancel
    local inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or not self.isMovingItem then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            -- Left click to place
            self:_ConfirmItemMovement(player)
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Escape then
            -- Right click or Escape to cancel
            self:_CancelItemMovement()
        end
    end)
    
    table.insert(self.movementConnections, moveConnection)
    table.insert(self.movementConnections, inputConnection)
end

-- Update item position during movement
function MovementManager:_UpdateItemPosition()
    if not self.itemBeingMoved then return end
    
    local camera = game.Workspace.CurrentCamera
    local mouse = Players.LocalPlayer:GetMouse()
    
    -- Raycast to find new position
    local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude -- Changed from Blacklist to Exclude
    raycastParams.FilterDescendantsInstances = {self.itemBeingMoved}
    
    local result = game.Workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
    
    if result then
        local targetPosition = result.Position + result.Normal * 2
        
        -- Update item position
        if self.itemBeingMoved:IsA("Model") and self.itemBeingMoved.PrimaryPart then
            self.itemBeingMoved:SetPrimaryPartCFrame(CFrame.new(targetPosition))
        elseif self.itemBeingMoved:IsA("BasePart") then
            self.itemBeingMoved.CFrame = CFrame.new(targetPosition)
        end
    end
end

-- Confirm item movement
function MovementManager:_ConfirmItemMovement(player)
    if not self.itemBeingMoved then return end
    
    local newPosition
    if self.itemBeingMoved:IsA("Model") and self.itemBeingMoved.PrimaryPart then
        newPosition = self.itemBeingMoved.PrimaryPart.Position
    elseif self.itemBeingMoved:IsA("BasePart") then
        newPosition = self.itemBeingMoved.Position
    else
        warn("MovementManager: Unable to get item position")
        self:_CancelItemMovement()
        return
    end
    
    -- Validate new position
    local itemSize = self:_GetItemSize(self.itemBeingMoved)
    local canPlace, message = self.validator:CanPlaceAt(newPosition, itemSize, self.itemBeingMoved)
    
    if not canPlace then
        warn("MovementManager: Cannot place at new position:", message)
        self:_CancelItemMovement()
        return
    end
    
    -- Send move request to server
    local instanceId = self.itemBeingMoved:GetAttribute("instanceId") or self.itemBeingMoved.Name
    if self.remoteEventManager then
        self.remoteEventManager:FireServer("MoveItem", instanceId, newPosition)
    end
    
    print("MovementManager: Confirmed item movement to:", tostring(newPosition))
    self:_EndItemMovement()
end

-- Cancel item movement
function MovementManager:_CancelItemMovement()
    print("MovementManager: Cancelled item movement")
    -- Item should snap back to original position
    -- This would require storing the original position
    self:_EndItemMovement()
end

-- End item movement and cleanup
function MovementManager:_EndItemMovement()
    if self.itemBeingMoved then
        self:_RemoveMovementVisuals(self.itemBeingMoved)
    end
    
    self.isMovingItem = false
    self.itemBeingMoved = nil
    
    -- Disconnect movement connections
    for _, connection in ipairs(self.movementConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    self.movementConnections = {}
end

-- Remove movement visual effects
function MovementManager:_RemoveMovementVisuals(item)
    -- Remove highlight
    local highlight = item:FindFirstChild("MovementHighlight")
    if highlight then
        highlight:Destroy()
    end
    
    -- Restore all original properties
    if item:IsA("Model") then
        for _, part in ipairs(item:GetDescendants()) do
            if part:IsA("BasePart") then
                -- Restore transparency
                if part:GetAttribute("original_transparency") ~= nil then
                    part.Transparency = part:GetAttribute("original_transparency")
                    part:SetAttribute("original_transparency", nil)
                end
                
                -- Restore color
                if part:GetAttribute("original_color") then
                    part.BrickColor = BrickColor.new(part:GetAttribute("original_color"))
                    part:SetAttribute("original_color", nil)
                end
                
                -- Restore material
                if part:GetAttribute("original_material") then
                    part.Material = Enum.Material[part:GetAttribute("original_material")]
                    part:SetAttribute("original_material", nil)
                end
                
                -- Restore size
                if part:GetAttribute("original_size") then
                    local sizeStr = part:GetAttribute("original_size")
                    local coords = sizeStr:split(", ")
                    if #coords == 3 then
                        part.Size = Vector3.new(
                            tonumber(coords[1]) or part.Size.X,
                            tonumber(coords[2]) or part.Size.Y,
                            tonumber(coords[3]) or part.Size.Z
                        )
                    end
                    part:SetAttribute("original_size", nil)
                end
                
                -- Restore collision
                if part:GetAttribute("original_cancollide") ~= nil then
                    part.CanCollide = part:GetAttribute("original_cancollide")
                    part:SetAttribute("original_cancollide", nil)
                end
            end
        end
    elseif item:IsA("BasePart") then
        -- Restore transparency
        if item:GetAttribute("original_transparency") ~= nil then
            item.Transparency = item:GetAttribute("original_transparency")
            item:SetAttribute("original_transparency", nil)
        end
        
        -- Restore color
        if item:GetAttribute("original_color") then
            item.BrickColor = BrickColor.new(item:GetAttribute("original_color"))
            item:SetAttribute("original_color", nil)
        end
        
        -- Restore material
        if item:GetAttribute("original_material") then
            item.Material = Enum.Material[item:GetAttribute("original_material")]
            item:SetAttribute("original_material", nil)
        end
        
        -- Restore size
        if item:GetAttribute("original_size") then
            local sizeStr = item:GetAttribute("original_size")
            local coords = sizeStr:split(", ")
            if #coords == 3 then
                item.Size = Vector3.new(
                    tonumber(coords[1]) or item.Size.X,
                    tonumber(coords[2]) or item.Size.Y,
                    tonumber(coords[3]) or item.Size.Z
                )
            end
            item:SetAttribute("original_size", nil)
        end
        
        -- Restore collision
        if item:GetAttribute("original_cancollide") ~= nil then
            item.CanCollide = item:GetAttribute("original_cancollide")
            item:SetAttribute("original_cancollide", nil)
        end
    end
end

-- Rotate an item
function MovementManager:RotateItem(item, player, rotationAxis, angleDegrees)
    if not item or not player then
        warn("MovementManager: Invalid parameters for rotation")
        return false
    end
    
    -- Validate that item can be rotated
    local canRotate, message = self.validator:CanRotateItem(player, item)
    if not canRotate then
        warn("MovementManager: Cannot rotate item:", message)
        return false
    end
    
    print("MovementManager: Rotating item:", item.Name, "on axis:", rotationAxis, "by", angleDegrees, "degrees")
    
    -- Apply rotation
    local rotationCFrame = CFrame.identity
    if rotationAxis == "X" then
        rotationCFrame = CFrame.Angles(math.rad(angleDegrees), 0, 0)
    elseif rotationAxis == "Y" then
        rotationCFrame = CFrame.Angles(0, math.rad(angleDegrees), 0)
    elseif rotationAxis == "Z" then
        rotationCFrame = CFrame.Angles(0, 0, math.rad(angleDegrees))
    end
    
    -- Apply rotation to item
    if item:IsA("Model") and item.PrimaryPart then
        local currentCFrame = item:GetPrimaryPartCFrame()
        item:SetPrimaryPartCFrame(currentCFrame * rotationCFrame)
    elseif item:IsA("BasePart") then
        item.CFrame = item.CFrame * rotationCFrame
    end
    
    -- Send rotation update to server if on client
    if RunService:IsClient() and self.remoteEventManager then
        local instanceId = item:GetAttribute("instanceId") or item.Name
        local currentAngles = self:_GetItemRotationAngles(item)
        self.remoteEventManager:FireServer("RotateItem", instanceId, currentAngles)
    end
    
    return true
end

-- Get current rotation angles of an item
function MovementManager:_GetItemRotationAngles(item)
    local cframe
    if item:IsA("Model") and item.PrimaryPart then
        cframe = item:GetPrimaryPartCFrame()
    elseif item:IsA("BasePart") then
        cframe = item.CFrame
    else
        return {X = 0, Y = 0, Z = 0}
    end
    
    local rx, ry, rz = cframe:ToEulerAnglesXYZ()
    return {
        X = math.deg(rx),
        Y = math.deg(ry), 
        Z = math.deg(rz)
    }
end

-- Recall an item to inventory
function MovementManager:RecallItem(item, player)
    if not item or not player then
        warn("MovementManager: Invalid parameters for recall")
        return false
    end
    
    -- Validate that item can be recalled
    local canRecall, message = self.validator:CanRecallItem(player, item)
    if not canRecall then
        warn("MovementManager: Cannot recall item:", message)
        return false
    end
    
    print("MovementManager: Recalling item:", item.Name)
    
    -- Send recall request to server
    if RunService:IsClient() and self.remoteEventManager then
        local instanceId = item:GetAttribute("instanceId") or item.Name
        self.remoteEventManager:FireServer("RecallItem", instanceId)
    elseif RunService:IsServer() then
        -- Handle server-side recall
        self:_HandleServerRecall(item, player)
    end
    
    return true
end

-- Handle server-side item recall
function MovementManager:_HandleServerRecall(item, player)
    if RunService:IsClient() then
        warn("MovementManager: _HandleServerRecall should only be called on server")
        return false
    end
    
    -- Add item back to player's inventory
    -- This would integrate with the inventory system
    local _itemId = item:GetAttribute("itemId") or item:GetAttribute("item") or item.Name -- Prefixed with _
    
    -- Remove from world
    item:Destroy()
    
    -- Notify client of successful recall
    if self.remoteEventManager then
        self.remoteEventManager:FireClient("ItemRecalled", player, true, "Item recalled successfully", item.Name)
    end
    
    print("MovementManager: Successfully recalled item for player:", player.Name)
    return true
end

-- Get the size of an item for validation
function MovementManager:_GetItemSize(item)
    if item:IsA("Model") then
        local _, size = item:GetBoundingBox()
        return size
    elseif item:IsA("BasePart") then
        return item.Size
    else
        return Vector3.new(4, 4, 4) -- Default size
    end
end

-- Check if currently moving an item
function MovementManager:IsMovingItem()
    return self.isMovingItem
end

-- Get the item currently being moved
function MovementManager:GetMovingItem()
    return self.itemBeingMoved
end

-- Stop all movement operations
function MovementManager:StopAllMovement()
    if self.isMovingItem then
        self:_CancelItemMovement()
    end
    
    self.isRotatingItem = false
    self.itemBeingRotated = nil
end

-- Batch rotate multiple items
function MovementManager:BatchRotateItems(items, player, rotationAxis, angleDegrees)
    local successCount = 0
    local failureCount = 0
    
    for _, item in ipairs(items) do
        if self:RotateItem(item, player, rotationAxis, angleDegrees) then
            successCount = successCount + 1
        else
            failureCount = failureCount + 1
        end
    end
    
    print("MovementManager: Batch rotation completed. Success:", successCount, "Failures:", failureCount)
    return successCount, failureCount
end

-- Get movement statistics
function MovementManager:GetMovementStatistics()
    return {
        isMovingItem = self.isMovingItem,
        movingItemName = self.itemBeingMoved and self.itemBeingMoved.Name or nil,
        isRotatingItem = self.isRotatingItem,
        rotatingItemName = self.itemBeingRotated and self.itemBeingRotated.Name or nil,
        activeConnections = #self.movementConnections
    }
end

return MovementManager