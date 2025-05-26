-- LineOfSightChecker: Advanced line of sight detection for purchase prompts
local LineOfSightChecker = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Configuration
local CONFIG = {
    -- Maximum interaction distance (studs)
    MAX_INTERACTION_DISTANCE = 15,
    
    -- Minimum percentage of raycast points that must be clear for line of sight
    MIN_CLEAR_PERCENTAGE = 0.3, -- 30% of points must be visible
    
    -- Raycast points per item (more points = better accuracy, but more expensive)
    RAYCAST_POINTS_PER_ITEM = 8,
    
    -- Whether transparent parts should block line of sight
    TRANSPARENT_PARTS_BLOCK = false,
    
    -- Whether non-collidable parts should block line of sight
    NON_COLLIDABLE_PARTS_BLOCK = true,
    
    -- Minimum transparency for a part to be considered "see-through"
    TRANSPARENCY_THRESHOLD = 0.8,
    
    -- Cache duration for line of sight results (seconds)
    CACHE_DURATION = 0.1, -- Reduced for faster response
    
    -- Debug visualization (set to true for testing)
    DEBUG_RAYS = false
}

-- Cache for line of sight results
local lineOfSightCache = {}

-- Initialize the module
function LineOfSightChecker:Init()
    print("LineOfSightChecker: Initializing line of sight detection system")
    
    -- Clear cache periodically
    spawn(function()
        while true do
            task.wait(CONFIG.CACHE_DURATION * 2)
            self:_ClearExpiredCache()
        end
    end)
    
    return self
end

-- Main function: Check if player has line of sight to an item
function LineOfSightChecker:HasLineOfSight(player, targetItem)
    if not player or not targetItem then
        return false
    end
    
    -- Get player position (camera for more accurate view-based detection)
    local camera = Workspace.CurrentCamera
    local playerPosition
    
    if camera then
        playerPosition = camera.CFrame.Position
    elseif player.Character and player.Character:FindFirstChild("Head") then
        playerPosition = player.Character.Head.Position
    else
        return false -- Can't determine player position
    end
    
    -- Get target item position and bounds
    local targetPosition, targetBounds = self:_GetItemPositionAndBounds(targetItem)
    if not targetPosition then
        return false
    end
    
    -- Distance check first (quick elimination)
    local distance = (playerPosition - targetPosition).Magnitude
    if distance > CONFIG.MAX_INTERACTION_DISTANCE then
        return false
    end
    
    -- Check cache first
    local cacheKey = self:_GenerateCacheKey(player, targetItem, playerPosition)
    local cachedResult = lineOfSightCache[cacheKey]
    if cachedResult and tick() - cachedResult.timestamp < CONFIG.CACHE_DURATION then
        return cachedResult.hasLineOfSight
    end
    
    -- Perform multi-point raycast check
    local hasLineOfSight = self:_MultiPointRaycast(playerPosition, targetItem, targetPosition, targetBounds)
    
    -- Cache the result
    lineOfSightCache[cacheKey] = {
        hasLineOfSight = hasLineOfSight,
        timestamp = tick()
    }
    
    return hasLineOfSight
end

-- Get the position and bounding information for an item
function LineOfSightChecker:_GetItemPositionAndBounds(item)
    local position
    local bounds = {}
    
    if item:IsA("Model") then
        if item.PrimaryPart then
            position = item.PrimaryPart.Position
            bounds.size = item:GetExtentsSize()
            bounds.cframe = item:GetPrimaryPartCFrame()
        else
            -- Fallback: find the first BasePart
            local firstPart = item:FindFirstChildOfClass("BasePart")
            if firstPart then
                position = firstPart.Position
                bounds.size = firstPart.Size
                bounds.cframe = firstPart.CFrame
            end
        end
    elseif item:IsA("BasePart") then
        position = item.Position
        bounds.size = item.Size
        bounds.cframe = item.CFrame
    end
    
    return position, bounds
end

-- Perform multiple raycasts to different points on the target item
function LineOfSightChecker:_MultiPointRaycast(playerPosition, targetItem, targetPosition, targetBounds)
    local raycastPoints = self:_GenerateRaycastPoints(targetPosition, targetBounds)
    local clearRaycastCount = 0
    local totalRaycasts = #raycastPoints
    
    -- Create raycast filter
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = self:_GetFilterInstances(targetItem)
    
    -- Test each raycast point
    for i, raycastPoint in ipairs(raycastPoints) do
        local direction = (raycastPoint - playerPosition)
        local distance = direction.Magnitude
        direction = direction.Unit
        
        -- Cast ray
        local raycastResult = Workspace:Raycast(playerPosition, direction * distance, raycastParams)
        
        -- Debug visualization
        if CONFIG.DEBUG_RAYS then
            self:_VisualizeRay(playerPosition, raycastPoint, raycastResult ~= nil)
        end
        
        -- Check if ray reached the target unobstructed
        if not raycastResult then
            -- Ray reached target without hitting anything
            clearRaycastCount = clearRaycastCount + 1
        else
            -- Ray hit something - check if it should block line of sight
            local hitPart = raycastResult.Instance
            if not self:_ShouldPartBlockLineOfSight(hitPart) then
                clearRaycastCount = clearRaycastCount + 1
            end
        end
    end
    
    -- Calculate clear percentage
    local clearPercentage = clearRaycastCount / totalRaycasts
    
    -- Debug info
    if CONFIG.DEBUG_RAYS then
        print("LineOfSight Debug:", targetItem.Name, 
              "Clear:", clearRaycastCount, "/", totalRaycasts, 
              "Percentage:", math.floor(clearPercentage * 100) .. "%")
    end
    
    return clearPercentage >= CONFIG.MIN_CLEAR_PERCENTAGE
end

-- Generate multiple raycast points around the target item
function LineOfSightChecker:_GenerateRaycastPoints(targetPosition, targetBounds)
    local points = {}
    
    -- Always include the center point
    table.insert(points, targetPosition)
    
    if targetBounds and targetBounds.size and targetBounds.cframe then
        local size = targetBounds.size
        local cframe = targetBounds.cframe
        
        -- Generate points around the bounding box
        local offsets = {
            Vector3.new(size.X/2, 0, 0),           -- Right
            Vector3.new(-size.X/2, 0, 0),          -- Left
            Vector3.new(0, size.Y/2, 0),           -- Top
            Vector3.new(0, -size.Y/2, 0),          -- Bottom
            Vector3.new(0, 0, size.Z/2),           -- Front
            Vector3.new(0, 0, -size.Z/2),          -- Back
            Vector3.new(size.X/3, size.Y/3, 0),    -- Top-right
            Vector3.new(-size.X/3, size.Y/3, 0),   -- Top-left
        }
        
        -- Limit the number of points based on configuration
        local maxPoints = math.min(CONFIG.RAYCAST_POINTS_PER_ITEM - 1, #offsets)
        
        for i = 1, maxPoints do
            local worldPoint = cframe:PointToWorldSpace(offsets[i])
            table.insert(points, worldPoint)
        end
    end
    
    return points
end

-- Get instances to exclude from raycast (player character and target item)
function LineOfSightChecker:_GetFilterInstances(targetItem)
    local filterInstances = {}
    
    -- Exclude all player characters
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character then
            table.insert(filterInstances, player.Character)
        end
    end
    
    -- Exclude the target item itself
    table.insert(filterInstances, targetItem)
    
    -- Exclude any preview items or temporary objects
    for _, obj in pairs(Workspace:GetChildren()) do
        if obj.Name:find("Preview_") or obj:GetAttribute("is_preview") then
            table.insert(filterInstances, obj)
        end
    end
    
    return filterInstances
end

-- Determine if a part should block line of sight
function LineOfSightChecker:_ShouldPartBlockLineOfSight(part)
    if not part:IsA("BasePart") then
        return false
    end
    
    -- Check transparency
    if not CONFIG.TRANSPARENT_PARTS_BLOCK then
        if part.Transparency >= CONFIG.TRANSPARENCY_THRESHOLD then
            return false -- Transparent parts don't block
        end
    end
    
    -- Check collision
    if not CONFIG.NON_COLLIDABLE_PARTS_BLOCK then
        if not part.CanCollide then
            return false -- Non-collidable parts don't block
        end
    end
    
    -- Check for special materials or properties that shouldn't block
    if part.Material == Enum.Material.ForceField then
        return false
    end
    
    -- Default: part blocks line of sight
    return true
end

-- Generate cache key for line of sight results
function LineOfSightChecker:_GenerateCacheKey(player, targetItem, playerPosition)
    -- Create a key based on player, target, and approximate position
    local roundedPos = Vector3.new(
        math.floor(playerPosition.X + 0.5),
        math.floor(playerPosition.Y + 0.5), 
        math.floor(playerPosition.Z + 0.5)
    )
    
    return string.format("%s_%s_%s", 
        tostring(player.UserId), 
        tostring(targetItem),
        tostring(roundedPos)
    )
end

-- Clear expired cache entries
function LineOfSightChecker:_ClearExpiredCache()
    local currentTime = tick()
    local removedCount = 0
    
    for key, cachedData in pairs(lineOfSightCache) do
        if currentTime - cachedData.timestamp > CONFIG.CACHE_DURATION then
            lineOfSightCache[key] = nil
            removedCount = removedCount + 1
        end
    end
    
    if removedCount > 0 then
        print("LineOfSightChecker: Cleared", removedCount, "expired cache entries")
    end
end

-- Debug function: Visualize raycast for testing
function LineOfSightChecker:_VisualizeRay(startPos, endPos, wasBlocked)
    local ray = Instance.new("Part")
    ray.Name = "DebugRay"
    ray.Size = Vector3.new(0.1, 0.1, (endPos - startPos).Magnitude)
    ray.CFrame = CFrame.lookAt(startPos + (endPos - startPos)/2, endPos)
    ray.Anchored = true
    ray.CanCollide = false
    ray.BrickColor = wasBlocked and BrickColor.new("Bright red") or BrickColor.new("Bright green")
    ray.Material = Enum.Material.Neon
    ray.Parent = Workspace
    
    -- Remove after 2 seconds
    game:GetService("Debris"):AddItem(ray, 2)
end

-- Configuration functions
function LineOfSightChecker:SetMaxDistance(distance)
    CONFIG.MAX_INTERACTION_DISTANCE = distance
end

function LineOfSightChecker:SetMinClearPercentage(percentage)
    CONFIG.MIN_CLEAR_PERCENTAGE = math.clamp(percentage, 0, 1)
end

function LineOfSightChecker:SetDebugMode(enabled)
    CONFIG.DEBUG_RAYS = enabled
end

function LineOfSightChecker:SetTransparentPartsBlock(shouldBlock)
    CONFIG.TRANSPARENT_PARTS_BLOCK = shouldBlock
end

function LineOfSightChecker:SetCacheDuration(duration)
    CONFIG.CACHE_DURATION = math.max(0.05, duration) -- Minimum 50ms cache
end

-- Quick test function for a specific player and item
function LineOfSightChecker:TestLineOfSight(player, targetItem)
    if not player then
        player = Players.LocalPlayer
    end
    
    if not targetItem then
        print("❌ No target item specified for line of sight test")
        return false
    end
    
    CONFIG.DEBUG_RAYS = true -- Enable debug for test
    
    local result = self:HasLineOfSight(player, targetItem)
    print("🔍 Line of Sight Test Result:", result and "✅ CLEAR" or "❌ BLOCKED")
    
    -- Disable debug after test
    task.wait(3)
    CONFIG.DEBUG_RAYS = false
    
    return result
end

return LineOfSightChecker 