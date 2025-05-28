-- CollisionOptimizer.luau
-- Enterprise-level collision detection optimization system
-- Part of Phase 2.3 Algorithm Optimization

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CollisionOptimizer = {}
CollisionOptimizer.__index = CollisionOptimizer

-- Configuration
local CONFIG = {
    -- Collision detection phases
    BROAD_PHASE_METHOD = "spatial_hash", -- spatial_hash, grid, octree
    NARROW_PHASE_METHOD = "sat", -- sat, gjk, aabb
    
    -- Performance settings
    MAX_CHECKS_PER_FRAME = 500, -- Maximum collision checks per frame
    BATCH_SIZE = 50, -- Objects to process per batch
    PRIORITY_UPDATE_FREQUENCY = 0.016, -- High priority objects (60 FPS)
    NORMAL_UPDATE_FREQUENCY = 0.033, -- Normal priority objects (30 FPS)
    LOW_UPDATE_FREQUENCY = 0.1, -- Low priority objects (10 FPS)
    
    -- Optimization features
    ENABLE_SLEEPING = true, -- Objects that don't move go to sleep
    ENABLE_PREDICTIVE_COLLISION = true, -- Predict future collisions
    ENABLE_COLLISION_GROUPS = true, -- Group similar objects
    ENABLE_LOD_COLLISION = true, -- Level of detail for distant objects
    
    -- Spatial partitioning
    GRID_SIZE = 32, -- Size of spatial grid cells
    MAX_OBJECTS_PER_CELL = 25, -- Maximum objects per cell
    DYNAMIC_GRID_RESIZE = true, -- Automatically resize grid
    
    -- Memory management
    CACHE_SIZE = 2000, -- Maximum cached collision results
    CLEANUP_INTERVAL = 15, -- Cleanup interval (seconds)
    MAX_MEMORY_USAGE = 25 * 1024 * 1024, -- 25MB memory limit
    
    -- Quality settings
    COLLISION_TOLERANCE = 0.01, -- Minimum distance for collision
    PREDICTION_TIME = 0.1, -- How far ahead to predict collisions
    SLEEP_THRESHOLD = 0.001, -- Velocity threshold for sleeping
    WAKE_DISTANCE = 5, -- Distance to wake sleeping objects
}

-- Collision groups for optimization
local COLLISION_GROUPS = {
    STATIC = "static", -- Static objects (terrain, buildings)
    DYNAMIC = "dynamic", -- Moving objects (players, vehicles)
    PROJECTILE = "projectile", -- Fast-moving projectiles
    TRIGGER = "trigger", -- Trigger volumes
    UI = "ui", -- UI elements
}

-- Priority levels for collision checking
local PRIORITY = {
    CRITICAL = 1, -- Player-related collisions
    HIGH = 2, -- Important gameplay objects
    NORMAL = 3, -- Regular objects
    LOW = 4, -- Background/decorative objects
}

function CollisionOptimizer.new()
    local self = setmetatable({}, CollisionOptimizer)
    
    -- Core collision systems
    self.spatialIndex = nil -- Will be injected
    self.collisionPairs = {} -- Active collision pairs
    self.sleepingObjects = {} -- Objects that are sleeping
    self.awakeObjects = {} -- Active objects
    self.priorityQueues = {} -- Collision check queues by priority
    
    -- Collision groups
    self.collisionGroups = {}
    for _, group in pairs(COLLISION_GROUPS) do
        self.collisionGroups[group] = {}
    end
    
    -- Broad phase collision detection
    self.broadPhase = {
        spatialHash = {},
        grid = {},
        octree = nil,
        candidates = {}
    }
    
    -- Narrow phase collision detection
    self.narrowPhase = {
        cache = {}, -- Cached collision results
        methods = {}, -- Available collision methods
        activeChecks = 0
    }
    
    -- Performance metrics
    self.metrics = {
        totalCollisionChecks = 0,
        broadPhaseChecks = 0,
        narrowPhaseChecks = 0,
        collisionPairsFound = 0,
        sleepingObjectCount = 0,
        avgCheckTime = 0,
        frameTime = 0,
        cacheHitRate = 0,
        memoryUsage = 0,
        lastOptimization = os.time()
    }
    
    -- Update management
    self.updateQueues = {}
    for i = 1, 4 do
        self.updateQueues[i] = {}
    end
    self.currentQueueIndex = 1
    self.lastUpdate = os.time()
    
    -- Initialize systems
    self:InitializeBroadPhase()
    self:InitializeNarrowPhase()
    self:SetupUpdateLoop()
    
    print("CollisionOptimizer: Initialized with enterprise-level collision optimization")
    return self
end

-- Set spatial index (dependency injection)
function CollisionOptimizer:SetSpatialIndex(spatialIndex)
    self.spatialIndex = spatialIndex
    print("CollisionOptimizer: Spatial index injected")
end

-- Initialize broad phase collision detection
function CollisionOptimizer:InitializeBroadPhase()
    -- Initialize spatial hash
    self.broadPhase.spatialHash = {}
    
    -- Initialize grid
    self.broadPhase.grid = {
        cells = {},
        size = CONFIG.GRID_SIZE,
        bounds = {
            minX = -2000, maxX = 2000,
            minY = -500, maxY = 1000,
            minZ = -2000, maxZ = 2000
        }
    }
    
    print("CollisionOptimizer: Broad phase initialized")
end

-- Initialize narrow phase collision detection
function CollisionOptimizer:InitializeNarrowPhase()
    -- Initialize collision methods
    self.narrowPhase.methods = {
        aabb = function(obj1, obj2) return self:CheckAABBCollision(obj1, obj2) end,
        sat = function(obj1, obj2) return self:CheckSATCollision(obj1, obj2) end,
        gjk = function(obj1, obj2) return self:CheckGJKCollision(obj1, obj2) end,
        sphere = function(obj1, obj2) return self:CheckSphereCollision(obj1, obj2) end
    }
    
    -- Initialize cache
    self.narrowPhase.cache = {}
    
    print("CollisionOptimizer: Narrow phase initialized")
end

-- Register object for collision detection
function CollisionOptimizer:RegisterObject(object, group, priority)
    if not object or not object.Parent then return false end
    
    local objectId = self:GetObjectId(object)
    local collisionData = {
        id = objectId,
        object = object,
        group = group or COLLISION_GROUPS.DYNAMIC,
        priority = priority or PRIORITY.NORMAL,
        isStatic = group == COLLISION_GROUPS.STATIC,
        isSleeping = false,
        lastPosition = self:GetObjectPosition(object),
        lastVelocity = Vector3.new(0, 0, 0),
        lastUpdate = os.time(),
        collisionCallbacks = {},
        bounds = self:CalculateObjectBounds(object)
    }
    
    -- Add to appropriate group
    self.collisionGroups[group][objectId] = collisionData
    
    -- Add to priority queue
    if not self.priorityQueues[priority] then
        self.priorityQueues[priority] = {}
    end
    self.priorityQueues[priority][objectId] = collisionData
    
    -- Add to awake objects if not static
    if not collisionData.isStatic then
        self.awakeObjects[objectId] = collisionData
    end
    
    -- Register with spatial index if available
    if self.spatialIndex then
        self.spatialIndex:AddObject(object, collisionData.isStatic)
    end
    
    return true
end

-- Unregister object from collision detection
function CollisionOptimizer:UnregisterObject(object)
    local objectId = self:GetObjectId(object)
    
    -- Remove from all groups
    for _, group in pairs(self.collisionGroups) do
        group[objectId] = nil
    end
    
    -- Remove from priority queues
    for _, queue in pairs(self.priorityQueues) do
        queue[objectId] = nil
    end
    
    -- Remove from sleeping/awake lists
    self.sleepingObjects[objectId] = nil
    self.awakeObjects[objectId] = nil
    
    -- Remove from spatial index if available
    if self.spatialIndex then
        self.spatialIndex:RemoveObject(object)
    end
    
    return true
end

-- Main collision detection update
function CollisionOptimizer:UpdateCollisions()
    local frameStart = os.clock()
    local checksPerformed = 0
    local maxChecks = CONFIG.MAX_CHECKS_PER_FRAME
    
    -- Update object states
    self:UpdateObjectStates()
    
    -- Process priority queues
    for priority = 1, 4 do
        if checksPerformed >= maxChecks then break end
        
        local queue = self.priorityQueues[priority]
        if queue then
            local remaining = maxChecks - checksPerformed
            local performed = self:ProcessPriorityQueue(queue, priority, remaining)
            checksPerformed = checksPerformed + performed
        end
    end
    
    -- Update metrics
    self.metrics.frameTime = os.clock() - frameStart
    self.metrics.totalCollisionChecks = self.metrics.totalCollisionChecks + checksPerformed
    
    -- Cleanup if needed
    if os.time() - self.metrics.lastOptimization > CONFIG.CLEANUP_INTERVAL then
        self:OptimizeCollisionSystem()
        self.metrics.lastOptimization = os.time()
    end
end

-- Update object states (sleeping, awake, etc.)
function CollisionOptimizer:UpdateObjectStates()
    local currentTime = os.time()
    
    -- Check for sleeping objects
    if CONFIG.ENABLE_SLEEPING then
        for objectId, collisionData in pairs(self.awakeObjects) do
            if self:ShouldObjectSleep(collisionData) then
                self:PutObjectToSleep(objectId, collisionData)
            end
        end
    end
    
    -- Check for objects that should wake up
    for objectId, collisionData in pairs(self.sleepingObjects) do
        if self:ShouldObjectWakeUp(collisionData) then
            self:WakeUpObject(objectId, collisionData)
        end
    end
    
    -- Update object positions and velocities
    for objectId, collisionData in pairs(self.awakeObjects) do
        local currentPosition = self:GetObjectPosition(collisionData.object)
        if currentPosition then
            local deltaTime = currentTime - collisionData.lastUpdate
            if deltaTime > 0 then
                collisionData.lastVelocity = (currentPosition - collisionData.lastPosition) / deltaTime
                collisionData.lastPosition = currentPosition
                collisionData.lastUpdate = currentTime
                collisionData.bounds = self:CalculateObjectBounds(collisionData.object)
            end
        end
    end
end

-- Process collision checks for a priority queue
function CollisionOptimizer:ProcessPriorityQueue(queue, priority, maxChecks)
    local checksPerformed = 0
    local updateFrequency = self:GetUpdateFrequency(priority)
    local currentTime = os.time()
    
    for objectId, collisionData in pairs(queue) do
        if checksPerformed >= maxChecks then break end
        
        -- Skip if not time to update
        if currentTime - collisionData.lastUpdate < updateFrequency then
            -- Skip this iteration
        elseif collisionData.isSleeping then
            -- Skip sleeping objects
        else
            -- Perform collision detection
            local collisions = self:DetectCollisions(collisionData)
            checksPerformed = checksPerformed + 1
            
            -- Process collision results
            if #collisions > 0 then
                self:ProcessCollisions(collisionData, collisions)
            end
        end
    end
    
    return checksPerformed
end

-- Detect collisions for an object
function CollisionOptimizer:DetectCollisions(collisionData)
    local collisions = {}
    
    -- Broad phase: Get potential collision candidates
    local candidates = self:BroadPhaseDetection(collisionData)
    self.metrics.broadPhaseChecks = self.metrics.broadPhaseChecks + #candidates
    
    -- Narrow phase: Check actual collisions
    for _, candidate in ipairs(candidates) do
        local isColliding = self:NarrowPhaseDetection(collisionData, candidate)
        if isColliding then
            table.insert(collisions, {
                object1 = collisionData,
                object2 = candidate,
                type = self:GetCollisionType(collisionData, candidate)
            })
        end
        self.metrics.narrowPhaseChecks = self.metrics.narrowPhaseChecks + 1
    end
    
    return collisions
end

-- Broad phase collision detection
function CollisionOptimizer:BroadPhaseDetection(collisionData)
    local candidates = {}
    
    if CONFIG.BROAD_PHASE_METHOD == "spatial_hash" then
        candidates = self:SpatialHashBroadPhase(collisionData)
    elseif CONFIG.BROAD_PHASE_METHOD == "grid" then
        candidates = self:GridBroadPhase(collisionData)
    elseif CONFIG.BROAD_PHASE_METHOD == "octree" then
        candidates = self:OctreeBroadPhase(collisionData)
    end
    
    -- Filter candidates based on collision groups
    candidates = self:FilterCandidatesByGroup(collisionData, candidates)
    
    return candidates
end

-- Spatial hash broad phase
function CollisionOptimizer:SpatialHashBroadPhase(collisionData)
    local candidates = {}
    
    if self.spatialIndex then
        local position = collisionData.lastPosition
        local bounds = collisionData.bounds
        local size = bounds.size
        local radius = math.max(size.X, size.Y, size.Z) / 2
        
        local nearby = self.spatialIndex:GetNearbyObjects(position, radius * 2, true)
        for _, nearbyData in ipairs(nearby) do
            local nearbyId = self:GetObjectId(nearbyData.object)
            local candidateData = self:GetCollisionDataById(nearbyId)
            if candidateData and candidateData.id ~= collisionData.id then
                table.insert(candidates, candidateData)
            end
        end
    end
    
    return candidates
end

-- Grid broad phase
function CollisionOptimizer:GridBroadPhase(collisionData)
    local candidates = {}
    local grid = self.broadPhase.grid
    local position = collisionData.lastPosition
    
    -- Get grid cell
    local cellX = math.floor(position.X / grid.size)
    local cellY = math.floor(position.Y / grid.size)
    local cellZ = math.floor(position.Z / grid.size)
    
    -- Check surrounding cells
    for dx = -1, 1 do
        for dy = -1, 1 do
            for dz = -1, 1 do
                local cellKey = string.format("%d,%d,%d", cellX + dx, cellY + dy, cellZ + dz)
                local cell = grid.cells[cellKey]
                if cell then
                    for _, candidateData in ipairs(cell) do
                        if candidateData.id ~= collisionData.id then
                            table.insert(candidates, candidateData)
                        end
                    end
                end
            end
        end
    end
    
    return candidates
end

-- Octree broad phase
function CollisionOptimizer:OctreeBroadPhase(collisionData)
    local candidates = {}
    
    -- Use spatial index octree if available
    if self.spatialIndex then
        local position = collisionData.lastPosition
        local bounds = collisionData.bounds
        local minPoint = bounds.min
        local maxPoint = bounds.max
        
        local objects = self.spatialIndex:GetObjectsInRegion(minPoint, maxPoint)
        for _, object in ipairs(objects) do
            local objectId = self:GetObjectId(object)
            local candidateData = self:GetCollisionDataById(objectId)
            if candidateData and candidateData.id ~= collisionData.id then
                table.insert(candidates, candidateData)
            end
        end
    end
    
    return candidates
end

-- Narrow phase collision detection
function CollisionOptimizer:NarrowPhaseDetection(collisionData1, collisionData2)
    local start = os.clock()
    
    -- Check cache first
    local cacheKey = self:GetCollisionCacheKey(collisionData1.id, collisionData2.id)
    local cached = self.narrowPhase.cache[cacheKey]
    if cached and os.time() - cached.timestamp < 0.1 then
        self.metrics.cacheHitRate = (self.metrics.cacheHitRate * 0.9) + (1 * 0.1)
        return cached.result
    end
    
    -- Determine collision method
    local method = self:GetCollisionMethod(collisionData1, collisionData2)
    local collisionFunction = self.narrowPhase.methods[method]
    
    if not collisionFunction then
        return false
    end
    
    -- Perform collision check
    local isColliding = collisionFunction(collisionData1, collisionData2)
    
    -- Cache result
    self.narrowPhase.cache[cacheKey] = {
        result = isColliding,
        timestamp = os.time()
    }
    
    -- Update metrics
    local checkTime = os.clock() - start
    self.metrics.avgCheckTime = (self.metrics.avgCheckTime * 0.9) + (checkTime * 0.1)
    self.metrics.cacheHitRate = (self.metrics.cacheHitRate * 0.9) + (0 * 0.1)
    
    return isColliding
end

-- AABB collision detection
function CollisionOptimizer:CheckAABBCollision(collisionData1, collisionData2)
    local bounds1 = collisionData1.bounds
    local bounds2 = collisionData2.bounds
    
    return bounds1.min.X <= bounds2.max.X and bounds1.max.X >= bounds2.min.X and
           bounds1.min.Y <= bounds2.max.Y and bounds1.max.Y >= bounds2.min.Y and
           bounds1.min.Z <= bounds2.max.Z and bounds1.max.Z >= bounds2.min.Z
end

-- Sphere collision detection
function CollisionOptimizer:CheckSphereCollision(collisionData1, collisionData2)
    local pos1 = collisionData1.lastPosition
    local pos2 = collisionData2.lastPosition
    local radius1 = collisionData1.bounds.radius or collisionData1.bounds.size.Magnitude / 2
    local radius2 = collisionData2.bounds.radius or collisionData2.bounds.size.Magnitude / 2
    
    local distance = (pos1 - pos2).Magnitude
    return distance <= (radius1 + radius2)
end

-- SAT (Separating Axis Theorem) collision detection
function CollisionOptimizer:CheckSATCollision(collisionData1, collisionData2)
    -- Simplified SAT implementation for boxes
    local bounds1 = collisionData1.bounds
    local bounds2 = collisionData2.bounds
    
    -- For now, fallback to AABB
    return self:CheckAABBCollision(collisionData1, collisionData2)
end

-- GJK collision detection
function CollisionOptimizer:CheckGJKCollision(collisionData1, collisionData2)
    -- Simplified GJK implementation
    -- For now, fallback to AABB
    return self:CheckAABBCollision(collisionData1, collisionData2)
end

-- Put object to sleep
function CollisionOptimizer:PutObjectToSleep(objectId, collisionData)
    collisionData.isSleeping = true
    self.sleepingObjects[objectId] = collisionData
    self.awakeObjects[objectId] = nil
    self.metrics.sleepingObjectCount = self.metrics.sleepingObjectCount + 1
end

-- Wake up object
function CollisionOptimizer:WakeUpObject(objectId, collisionData)
    collisionData.isSleeping = false
    self.awakeObjects[objectId] = collisionData
    self.sleepingObjects[objectId] = nil
    self.metrics.sleepingObjectCount = self.metrics.sleepingObjectCount - 1
end

-- Check if object should sleep
function CollisionOptimizer:ShouldObjectSleep(collisionData)
    if collisionData.isStatic then return false end
    
    local velocity = collisionData.lastVelocity
    local speed = velocity.Magnitude
    
    return speed < CONFIG.SLEEP_THRESHOLD
end

-- Check if object should wake up
function CollisionOptimizer:ShouldObjectWakeUp(collisionData)
    -- Check if nearby objects are moving
    if self.spatialIndex then
        local position = collisionData.lastPosition
        local nearby = self.spatialIndex:GetNearbyObjects(position, CONFIG.WAKE_DISTANCE, false)
        
        for _, nearbyData in ipairs(nearby) do
            local nearbyId = self:GetObjectId(nearbyData.object)
            local nearbyCollisionData = self:GetCollisionDataById(nearbyId)
            if nearbyCollisionData and not nearbyCollisionData.isSleeping then
                local velocity = nearbyCollisionData.lastVelocity
                if velocity.Magnitude > CONFIG.SLEEP_THRESHOLD then
                    return true
                end
            end
        end
    end
    
    return false
end

-- Setup update loop
function CollisionOptimizer:SetupUpdateLoop()
    if RunService:IsClient() then
        self.updateConnection = RunService.Heartbeat:Connect(function()
            self:UpdateCollisions()
        end)
    else
        self.updateConnection = RunService.Heartbeat:Connect(function()
            self:UpdateCollisions()
        end)
    end
end

-- Optimize collision system
function CollisionOptimizer:OptimizeCollisionSystem()
    local start = os.clock()
    
    -- Clean up destroyed objects
    self:CleanupDestroyedObjects()
    
    -- Clean up cache
    self:CleanupCache()
    
    -- Optimize spatial structures
    self:OptimizeSpatialStructures()
    
    -- Update memory usage
    self.metrics.memoryUsage = collectgarbage("count") * 1024
    
    local optimizationTime = os.clock() - start
    print("CollisionOptimizer: Optimization completed in", optimizationTime, "seconds")
end

-- Utility functions
function CollisionOptimizer:GetObjectId(object)
    return object:GetAttribute("InstanceId") or object:GetAttribute("UniqueId") or tostring(object:GetDebugId())
end

function CollisionOptimizer:GetObjectPosition(object)
    if object:IsA("Model") and object.PrimaryPart then
        return object.PrimaryPart.Position
    elseif object:IsA("BasePart") then
        return object.Position
    end
    return Vector3.new(0, 0, 0)
end

function CollisionOptimizer:CalculateObjectBounds(object)
    local position = self:GetObjectPosition(object)
    local size
    
    if object:IsA("Model") then
        local cf, modelSize = object:GetBoundingBox()
        size = modelSize
    elseif object:IsA("BasePart") then
        size = object.Size
    else
        size = Vector3.new(1, 1, 1)
    end
    
    local halfSize = size / 2
    return {
        min = position - halfSize,
        max = position + halfSize,
        center = position,
        size = size,
        radius = size.Magnitude / 2
    }
end

function CollisionOptimizer:GetCollisionDataById(objectId)
    for _, group in pairs(self.collisionGroups) do
        local data = group[objectId]
        if data then return data end
    end
    return nil
end

function CollisionOptimizer:GetUpdateFrequency(priority)
    if priority == PRIORITY.CRITICAL then
        return CONFIG.PRIORITY_UPDATE_FREQUENCY
    elseif priority == PRIORITY.HIGH then
        return CONFIG.NORMAL_UPDATE_FREQUENCY
    else
        return CONFIG.LOW_UPDATE_FREQUENCY
    end
end

function CollisionOptimizer:GetCollisionMethod(collisionData1, collisionData2)
    -- Choose method based on object types and performance requirements
    if CONFIG.NARROW_PHASE_METHOD == "aabb" then
        return "aabb"
    elseif CONFIG.NARROW_PHASE_METHOD == "sphere" then
        return "sphere"
    elseif CONFIG.NARROW_PHASE_METHOD == "sat" then
        return "sat"
    else
        return "aabb" -- Default fallback
    end
end

function CollisionOptimizer:GetCollisionCacheKey(id1, id2)
    if id1 < id2 then
        return id1 .. "_" .. id2
    else
        return id2 .. "_" .. id1
    end
end

function CollisionOptimizer:FilterCandidatesByGroup(collisionData, candidates)
    local filtered = {}
    
    -- Add group-based filtering logic here
    for _, candidate in ipairs(candidates) do
        if self:ShouldCheckCollision(collisionData, candidate) then
            table.insert(filtered, candidate)
        end
    end
    
    return filtered
end

function CollisionOptimizer:ShouldCheckCollision(collisionData1, collisionData2)
    -- Skip if both objects are static
    if collisionData1.isStatic and collisionData2.isStatic then
        return false
    end
    
    -- Skip if both objects are sleeping
    if collisionData1.isSleeping and collisionData2.isSleeping then
        return false
    end
    
    return true
end

function CollisionOptimizer:GetCollisionType(collisionData1, collisionData2)
    if collisionData1.group == COLLISION_GROUPS.TRIGGER or collisionData2.group == COLLISION_GROUPS.TRIGGER then
        return "trigger"
    else
        return "collision"
    end
end

function CollisionOptimizer:ProcessCollisions(collisionData, collisions)
    for _, collision in ipairs(collisions) do
        -- Fire collision callbacks
        for _, callback in ipairs(collisionData.collisionCallbacks) do
            pcall(callback, collision)
        end
        
        self.metrics.collisionPairsFound = self.metrics.collisionPairsFound + 1
    end
end

function CollisionOptimizer:CleanupDestroyedObjects()
    local objectsToRemove = {}
    
    for group, objects in pairs(self.collisionGroups) do
        for objectId, collisionData in pairs(objects) do
            if not collisionData.object.Parent then
                table.insert(objectsToRemove, {group = group, id = objectId})
            end
        end
    end
    
    for _, removal in ipairs(objectsToRemove) do
        self:UnregisterObject({GetAttribute = function() return removal.id end})
    end
end

function CollisionOptimizer:CleanupCache()
    local currentTime = os.time()
    local expiredEntries = {}
    
    for cacheKey, cached in pairs(self.narrowPhase.cache) do
        if currentTime - cached.timestamp > 1 then -- 1 second TTL
            table.insert(expiredEntries, cacheKey)
        end
    end
    
    for _, cacheKey in ipairs(expiredEntries) do
        self.narrowPhase.cache[cacheKey] = nil
    end
end

function CollisionOptimizer:OptimizeSpatialStructures()
    -- Optimize grid if needed
    if CONFIG.DYNAMIC_GRID_RESIZE then
        -- Check if grid needs resizing based on object distribution
        -- Implementation would go here
    end
end

-- Get performance metrics
function CollisionOptimizer:GetMetrics()
    return {
        totalCollisionChecks = self.metrics.totalCollisionChecks,
        broadPhaseChecks = self.metrics.broadPhaseChecks,
        narrowPhaseChecks = self.metrics.narrowPhaseChecks,
        collisionPairsFound = self.metrics.collisionPairsFound,
        sleepingObjectCount = self.metrics.sleepingObjectCount,
        awakeObjectCount = self:GetAwakeObjectCount(),
        avgCheckTime = self.metrics.avgCheckTime,
        frameTime = self.metrics.frameTime,
        cacheHitRate = self.metrics.cacheHitRate,
        memoryUsage = self.metrics.memoryUsage,
        lastOptimization = self.metrics.lastOptimization
    }
end

function CollisionOptimizer:GetAwakeObjectCount()
    local count = 0
    for _ in pairs(self.awakeObjects) do
        count = count + 1
    end
    return count
end

-- Shutdown collision optimizer
function CollisionOptimizer:Shutdown()
    if self.updateConnection then
        self.updateConnection:Disconnect()
    end
    
    self.collisionGroups = {}
    self.priorityQueues = {}
    self.sleepingObjects = {}
    self.awakeObjects = {}
    self.narrowPhase.cache = {}
    
    print("CollisionOptimizer: Shutdown completed")
end

return CollisionOptimizer 