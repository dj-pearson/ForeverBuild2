-- PlacementValidator.luau
-- Handles validation logic for item placement, ownership, and manipulation

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PlacementValidator = {}
PlacementValidator.__index = PlacementValidator

function PlacementValidator.new()
    local self = setmetatable({}, PlacementValidator)
    return self
end

-- Validate that a player can place an item at a specific position
function PlacementValidator:CanPlaceAt(position, itemSize, excludeItem)
    if not position or not itemSize then
        return false, "Invalid position or size parameters"
    end
    
    -- Create a region to check for overlaps
    local halfSize = itemSize / 2
    local region = Region3.new(position - halfSize, position + halfSize)
    
    -- Expand region slightly to account for floating point precision
    local expandedRegion = region:ExpandToGrid(1)
    
    -- Use raycasting instead of ReadVoxels (which doesn't exist)
    -- local parts = Workspace:ReadVoxels(expandedRegion, 1)
    
    -- Check for overlapping placed items
    local worldItems = Workspace:FindFirstChild("World_Items")
    if worldItems then
        local placedItems = worldItems:FindFirstChild("Placed")
        if placedItems then
            for _, child in ipairs(placedItems:GetChildren()) do
                if child ~= excludeItem and (child:IsA("Model") or child:IsA("BasePart")) then
                    if self:_CheckOverlap(position, itemSize, child) then
                        return false, "Position overlaps with existing item: " .. child.Name
                    end
                end
            end
        end
    end
    
    -- Check for static world obstacles
    if self:_CheckStaticObstacles(position, itemSize) then
        return false, "Position conflicts with static world geometry"
    end
    
    return true, "Position is valid for placement"
end

-- Check if two items overlap
function PlacementValidator:_CheckOverlap(position, size, item)
    local itemPosition, itemSize
    
    if item:IsA("Model") then
        if item.PrimaryPart then
            itemPosition = item.PrimaryPart.Position
            local _, modelSize = item:GetBoundingBox()
            itemSize = modelSize
        else
            -- If no primary part, get approximate bounds
            local parts = {}
            for _, part in ipairs(item:GetDescendants()) do
                if part:IsA("BasePart") then
                    table.insert(parts, part)
                end
            end
            
            if #parts == 0 then
                return false -- No parts to overlap with
            end
            
            itemPosition = parts[1].Position
            itemSize = parts[1].Size
        end
    elseif item:IsA("BasePart") then
        itemPosition = item.Position
        itemSize = item.Size
    else
        return false -- Unknown type
    end
    
    -- Simple AABB overlap check
    local halfSize1 = size / 2
    local halfSize2 = itemSize / 2
    
    local distance = (position - itemPosition)
    local totalHalfSize = halfSize1 + halfSize2
    
    return (math.abs(distance.X) < totalHalfSize.X and 
            math.abs(distance.Y) < totalHalfSize.Y and 
            math.abs(distance.Z) < totalHalfSize.Z)
end

-- Check for static world obstacles (terrain, buildings, etc.)
function PlacementValidator:_CheckStaticObstacles(position, size)
    -- Check against static items
    local worldItems = Workspace:FindFirstChild("World_Items")
    if worldItems then
        local staticItems = worldItems:FindFirstChild("Static")
        if staticItems then
            for _, child in ipairs(staticItems:GetDescendants()) do
                if child:IsA("BasePart") then
                    if self:_CheckOverlap(position, size, child) then
                        return true
                    end
                end
            end
        end
    end
    
    -- Check terrain if available
    local terrain = Workspace:FindFirstChild("Terrain")
    if terrain then
        local region = Region3.new(
            position - size / 2,
            position + size / 2
        )
        
        -- Use Region3 for terrain collision check
        -- Note: ReadVoxels doesn't exist in current Roblox API
        -- For now, we'll skip detailed terrain collision checking
        -- and rely on the raycasting in PlacementManager instead
    end
    
    return false
end

-- Validate ownership of an item
function PlacementValidator:IsOwner(player, item)
    if not player or not item then
        return false, "Invalid player or item"
    end
    
    if RunService:IsServer() then
        -- Server-side ownership check
        local ownerAttribute = item:GetAttribute("owner")
        if ownerAttribute then
            local playerId = tostring(player.UserId)
            local ownerString = tostring(ownerAttribute)
            
            if ownerString == playerId then
                return true, "Player is owner"
            else
                return false, "Player is not the owner"
            end
        else
            return false, "Item has no owner attribute"
        end
    else
        -- Client-side ownership check (less secure, for UI purposes)
        local ownerAttribute = item:GetAttribute("owner")
        if ownerAttribute then
            local playerId = tostring(player.UserId)
            local ownerString = tostring(ownerAttribute)
            
            return ownerString == playerId, ownerString == playerId and "Player is owner" or "Player is not the owner"
        else
            return false, "Item has no owner attribute"
        end
    end
end

-- Validate that an item can be moved
function PlacementValidator:CanMoveItem(player, item, newPosition)
    if not player or not item or not newPosition then
        return false, "Invalid parameters for move validation"
    end
    
    -- Check ownership
    local isOwner, ownershipMessage = self:IsOwner(player, item)
    if not isOwner then
        return false, ownershipMessage
    end
    
    -- Get item size for collision check
    local itemSize
    if item:IsA("Model") then
        local _, size = item:GetBoundingBox()
        itemSize = size
    elseif item:IsA("BasePart") then
        itemSize = item.Size
    else
        return false, "Item type not supported for movement"
    end
    
    -- Check if new position is valid (exclude the item being moved)
    local canPlace, placeMessage = self:CanPlaceAt(newPosition, itemSize, item)
    if not canPlace then
        return false, "Cannot move to new position: " .. placeMessage
    end
    
    return true, "Item can be moved to new position"
end

-- Validate that an item can be recalled
function PlacementValidator:CanRecallItem(player, item)
    if not player or not item then
        return false, "Invalid parameters for recall validation"
    end
    
    -- Check ownership
    local isOwner, ownershipMessage = self:IsOwner(player, item)
    if not isOwner then
        return false, ownershipMessage
    end
    
    -- Check if item is in a valid state for recall
    if not item.Parent then
        return false, "Item is not properly placed in world"
    end
    
    -- Additional checks could be added here (cooldowns, special item types, etc.)
    
    return true, "Item can be recalled"
end

-- Validate that an item can be rotated
function PlacementValidator:CanRotateItem(player, item)
    if not player or not item then
        return false, "Invalid parameters for rotation validation"
    end
    
    -- Check ownership
    local isOwner, ownershipMessage = self:IsOwner(player, item)
    if not isOwner then
        return false, ownershipMessage
    end
    
    -- Check if item type supports rotation
    if not (item:IsA("Model") or item:IsA("BasePart")) then
        return false, "Item type does not support rotation"
    end
    
    return true, "Item can be rotated"
end

-- Validate position is within world bounds
function PlacementValidator:IsWithinWorldBounds(position, worldBounds)
    if not position then
        return false, "Invalid position"
    end
    
    -- Default world bounds if not specified
    worldBounds = worldBounds or {
        minX = -1000,
        maxX = 1000,
        minY = 0,
        maxY = 500,
        minZ = -1000,
        maxZ = 1000
    }
    
    return (position.X >= worldBounds.minX and position.X <= worldBounds.maxX and
            position.Y >= worldBounds.minY and position.Y <= worldBounds.maxY and
            position.Z >= worldBounds.minZ and position.Z <= worldBounds.maxZ)
end

-- Validate that a position is on solid ground
function PlacementValidator:IsOnSolidGround(position, itemSize)
    if not position or not itemSize then
        return false, "Invalid parameters"
    end
    
    -- Raycast downward to check for ground
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {}
    
    -- Add preview items and hand items to filter
    for _, item in ipairs(Workspace:GetDescendants()) do
        if item:GetAttribute("is_preview") or item:GetAttribute("is_hand_item") then
            table.insert(raycastParams.FilterDescendantsInstances, item)
        end
    end
    
    local rayDirection = Vector3.new(0, -itemSize.Y - 10, 0)
    local rayResult = Workspace:Raycast(position, rayDirection, raycastParams)
    
    if rayResult then
        -- Check if the hit surface is relatively flat
        local surfaceNormal = rayResult.Normal
        local upVector = Vector3.new(0, 1, 0)
        local dotProduct = surfaceNormal:Dot(upVector)
        
        -- Surface is considered "solid ground" if it's mostly upward-facing
        return dotProduct > 0.8, dotProduct > 0.8 and "Position is on solid ground" or "Surface is too steep"
    else
        return false, "No ground found below position"
    end
end

return PlacementValidator 