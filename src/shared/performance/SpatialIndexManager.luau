-- SpatialIndexManager.luau
-- Enterprise-level spatial indexing system for optimal collision detection and spatial queries
-- Part of Phase 2.3 Algorithm Optimization

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SpatialIndexManager = {}
SpatialIndexManager.__index = SpatialIndexManager

-- Configuration
local CONFIG = {
    -- Grid configuration
    GRID_SIZE = 16, -- Size of each grid cell in studs
    MAX_OBJECTS_PER_CELL = 50, -- Maximum objects per cell before subdivision
    MAX_SUBDIVISION_DEPTH = 6, -- Maximum octree depth
    
    -- Performance settings
    UPDATE_FREQUENCY = 0.1, -- How often to update moving objects (seconds)
    BATCH_SIZE = 100, -- Objects to process per frame
    CACHE_SIZE = 1000, -- Maximum cached spatial queries
    
    -- Query optimization
    QUERY_CACHE_TTL = 5, -- Query cache time-to-live (seconds)
    COLLISION_TOLERANCE = 0.1, -- Collision detection tolerance
    BROAD_PHASE_EXPANSION = 2, -- Expansion factor for broad phase
    
    -- Memory management
    CLEANUP_INTERVAL = 30, -- Cleanup interval (seconds)
    MAX_MEMORY_USAGE = 50 * 1024 * 1024, -- 50MB memory limit
}

-- Spatial indexing structures
local STRUCTURES = {
    GRID = "grid",
    OCTREE = "octree",
    QUADTREE = "quadtree",
    SPATIAL_HASH = "spatial_hash"
}

function SpatialIndexManager.new()
    local self = setmetatable({}, SpatialIndexManager)
    
    -- Core data structures
    self.spatialGrid = {} -- 3D grid for fast spatial queries
    self.objectRegistry = {} -- All tracked objects
    self.movingObjects = {} -- Objects that need frequent updates
    self.staticObjects = {} -- Objects that rarely move
    
    -- Octree for hierarchical spatial indexing
    self.octree = {
        root = nil,
        nodes = {},
        leafCount = 0,
        maxDepth = 0
    }
    
    -- Query optimization
    self.queryCache = {} -- Cached spatial queries
    self.collisionPairs = {} -- Cached collision pairs
    self.lastQueryTime = {}
    
    -- Performance metrics
    self.metrics = {
        totalObjects = 0,
        gridCells = 0,
        octreeNodes = 0,
        queriesPerSecond = 0,
        avgQueryTime = 0,
        collisionChecks = 0,
        cacheHitRate = 0,
        memoryUsage = 0,
        lastCleanup = os.time()
    }
    
    -- Update management
    self.updateBatch = {}
    self.batchIndex = 0
    self.lastUpdate = os.time()
    
    -- Initialize systems
    self:InitializeGrid()
    self:InitializeOctree()
    self:SetupUpdateLoop()
    
    print("SpatialIndexManager: Initialized with enterprise-level spatial indexing")
    return self
end

-- Initialize 3D spatial grid
function SpatialIndexManager:InitializeGrid()
    self.spatialGrid = {}
    self.gridBounds = {
        minX = -1000, maxX = 1000,
        minY = -100, maxY = 500,
        minZ = -1000, maxZ = 1000
    }
    
    print("SpatialIndexManager: 3D spatial grid initialized")
end

-- Initialize octree structure
function SpatialIndexManager:InitializeOctree()
    local bounds = {
        center = Vector3.new(0, 200, 0),
        size = Vector3.new(2000, 600, 2000)
    }
    
    self.octree.root = self:CreateOctreeNode(bounds, 0, nil)
    print("SpatialIndexManager: Octree initialized with root bounds:", bounds.center, bounds.size)
end

-- Create octree node
function SpatialIndexManager:CreateOctreeNode(bounds, depth, parent)
    local node = {
        bounds = bounds,
        depth = depth,
        parent = parent,
        children = {},
        objects = {},
        isLeaf = true,
        objectCount = 0,
        subdivided = false
    }
    
    self.octree.nodes[#self.octree.nodes + 1] = node
    self.metrics.octreeNodes = #self.octree.nodes
    self.octree.maxDepth = math.max(self.octree.maxDepth, depth)
    
    return node
end

-- Get grid cell key for position
function SpatialIndexManager:GetGridKey(position)
    local x = math.floor(position.X / CONFIG.GRID_SIZE)
    local y = math.floor(position.Y / CONFIG.GRID_SIZE)
    local z = math.floor(position.Z / CONFIG.GRID_SIZE)
    return string.format("%d,%d,%d", x, y, z)
end

-- Get grid cell for position
function SpatialIndexManager:GetGridCell(position)
    local key = self:GetGridKey(position)
    if not self.spatialGrid[key] then
        self.spatialGrid[key] = {
            objects = {},
            staticObjects = {},
            movingObjects = {},
            lastUpdate = os.time(),
            queryCount = 0
        }
        self.metrics.gridCells = self.metrics.gridCells + 1
    end
    return self.spatialGrid[key]
end

-- Add object to spatial index
function SpatialIndexManager:AddObject(object, isStatic)
    if not object or not object.Parent then return false end
    
    local position = self:GetObjectPosition(object)
    if not position then return false end
    
    local size = self:GetObjectSize(object)
    local objectId = self:GetObjectId(object)
    
    -- Create object data
    local objectData = {
        id = objectId,
        object = object,
        position = position,
        size = size,
        isStatic = isStatic or false,
        lastUpdate = os.time(),
        gridCells = {},
        octreeNode = nil,
        bounds = self:CalculateBounds(position, size)
    }
    
    -- Add to registry
    self.objectRegistry[objectId] = objectData
    
    -- Add to appropriate lists
    if isStatic then
        self.staticObjects[objectId] = objectData
    else
        self.movingObjects[objectId] = objectData
    end
    
    -- Add to spatial structures
    self:AddToGrid(objectData)
    self:AddToOctree(objectData)
    
    self.metrics.totalObjects = self.metrics.totalObjects + 1
    return true
end

-- Remove object from spatial index
function SpatialIndexManager:RemoveObject(object)
    local objectId = self:GetObjectId(object)
    local objectData = self.objectRegistry[objectId]
    
    if not objectData then return false end
    
    -- Remove from grid
    self:RemoveFromGrid(objectData)
    
    -- Remove from octree
    self:RemoveFromOctree(objectData)
    
    -- Remove from registries
    self.objectRegistry[objectId] = nil
    self.staticObjects[objectId] = nil
    self.movingObjects[objectId] = nil
    
    self.metrics.totalObjects = self.metrics.totalObjects - 1
    return true
end

-- Update object position in spatial index
function SpatialIndexManager:UpdateObject(object)
    local objectId = self:GetObjectId(object)
    local objectData = self.objectRegistry[objectId]
    
    if not objectData then
        -- Try to add as new object
        return self:AddObject(object, false)
    end
    
    local newPosition = self:GetObjectPosition(object)
    if not newPosition then return false end
    
    -- Check if position changed significantly
    local oldPosition = objectData.position
    local distanceMoved = (newPosition - oldPosition).Magnitude
    
    if distanceMoved < CONFIG.COLLISION_TOLERANCE then
        return true -- Position hasn't changed enough
    end
    
    -- Remove from old locations
    self:RemoveFromGrid(objectData)
    self:RemoveFromOctree(objectData)
    
    -- Update object data
    objectData.position = newPosition
    objectData.lastUpdate = os.time()
    objectData.bounds = self:CalculateBounds(newPosition, objectData.size)
    
    -- Add to new locations
    self:AddToGrid(objectData)
    self:AddToOctree(objectData)
    
    return true
end

-- Add object to grid
function SpatialIndexManager:AddToGrid(objectData)
    local cellKeys = self:GetObjectGridCells(objectData)
    objectData.gridCells = cellKeys
    
    for _, key in ipairs(cellKeys) do
        local cell = self:GetGridCell(objectData.position) -- Use position to get proper cell
        table.insert(cell.objects, objectData.id)
        
        if objectData.isStatic then
            table.insert(cell.staticObjects, objectData.id)
        else
            table.insert(cell.movingObjects, objectData.id)
        end
    end
end

-- Remove object from grid
function SpatialIndexManager:RemoveFromGrid(objectData)
    for _, key in ipairs(objectData.gridCells or {}) do
        local cell = self.spatialGrid[key]
        if cell then
            self:RemoveFromArray(cell.objects, objectData.id)
            self:RemoveFromArray(cell.staticObjects, objectData.id)
            self:RemoveFromArray(cell.movingObjects, objectData.id)
        end
    end
    objectData.gridCells = {}
end

-- Add object to octree
function SpatialIndexManager:AddToOctree(objectData)
    local node = self:FindOctreeNode(self.octree.root, objectData.position)
    if node then
        table.insert(node.objects, objectData.id)
        node.objectCount = node.objectCount + 1
        objectData.octreeNode = node
        
        -- Check if subdivision is needed
        if node.objectCount > CONFIG.MAX_OBJECTS_PER_CELL and 
           node.depth < CONFIG.MAX_SUBDIVISION_DEPTH and 
           not node.subdivided then
            self:SubdivideOctreeNode(node)
        end
    end
end

-- Remove object from octree
function SpatialIndexManager:RemoveFromOctree(objectData)
    local node = objectData.octreeNode
    if node then
        self:RemoveFromArray(node.objects, objectData.id)
        node.objectCount = node.objectCount - 1
        objectData.octreeNode = nil
    end
end

-- Find octree node for position
function SpatialIndexManager:FindOctreeNode(node, position)
    if not node then return nil end
    
    -- Check if position is within bounds
    if not self:IsPositionInBounds(position, node.bounds) then
        return nil
    end
    
    -- If leaf node, return it
    if node.isLeaf then
        return node
    end
    
    -- Find appropriate child
    for _, child in ipairs(node.children) do
        local childNode = self:FindOctreeNode(child, position)
        if childNode then return childNode end
    end
    
    return node -- Fallback to current node
end

-- Subdivide octree node
function SpatialIndexManager:SubdivideOctreeNode(node)
    if node.subdivided or node.depth >= CONFIG.MAX_SUBDIVISION_DEPTH then
        return
    end
    
    local bounds = node.bounds
    local halfSize = bounds.size / 2
    local center = bounds.center
    
    -- Create 8 child nodes
    local offsets = {
        Vector3.new(-1, -1, -1), Vector3.new(1, -1, -1),
        Vector3.new(-1, 1, -1), Vector3.new(1, 1, -1),
        Vector3.new(-1, -1, 1), Vector3.new(1, -1, 1),
        Vector3.new(-1, 1, 1), Vector3.new(1, 1, 1)
    }
    
    for _, offset in ipairs(offsets) do
        local childCenter = center + offset * halfSize / 2
        local childBounds = {
            center = childCenter,
            size = halfSize
        }
        local childNode = self:CreateOctreeNode(childBounds, node.depth + 1, node)
        table.insert(node.children, childNode)
    end
    
    node.isLeaf = false
    node.subdivided = true
    
    -- Redistribute objects to children
    local objectsToRedistribute = {}
    for _, objectId in ipairs(node.objects) do
        table.insert(objectsToRedistribute, objectId)
    end
    
    node.objects = {}
    node.objectCount = 0
    
    for _, objectId in ipairs(objectsToRedistribute) do
        local objectData = self.objectRegistry[objectId]
        if objectData then
            self:AddToOctree(objectData)
        end
    end
end

-- Fast collision detection using spatial indexing
function SpatialIndexManager:CheckCollision(object1, object2)
    local start = os.clock()
    
    local pos1 = self:GetObjectPosition(object1)
    local pos2 = self:GetObjectPosition(object2)
    local size1 = self:GetObjectSize(object1)
    local size2 = self:GetObjectSize(object2)
    
    if not pos1 or not pos2 or not size1 or not size2 then
        return false
    end
    
    -- AABB collision detection
    local bounds1 = self:CalculateBounds(pos1, size1)
    local bounds2 = self:CalculateBounds(pos2, size2)
    
    local hasCollision = self:CheckAABBCollision(bounds1, bounds2)
    
    self.metrics.collisionChecks = self.metrics.collisionChecks + 1
    self.metrics.avgQueryTime = (self.metrics.avgQueryTime + (os.clock() - start)) / 2
    
    return hasCollision
end

-- Get nearby objects using spatial indexing
function SpatialIndexManager:GetNearbyObjects(position, radius, includeStatic)
    local start = os.clock()
    local cacheKey = string.format("nearby_%.2f_%.2f_%.2f_%.2f_%s", 
        position.X, position.Y, position.Z, radius, tostring(includeStatic or false))
    
    -- Check cache
    local cached = self.queryCache[cacheKey]
    if cached and os.time() - cached.timestamp < CONFIG.QUERY_CACHE_TTL then
        self.metrics.cacheHitRate = (self.metrics.cacheHitRate * 0.9) + (1 * 0.1)
        return cached.result
    end
    
    local nearbyObjects = {}
    local radiusSquared = radius * radius
    
    -- Get grid cells to check
    local gridCells = self:GetGridCellsInRadius(position, radius)
    
    for _, cellKey in ipairs(gridCells) do
        local cell = self.spatialGrid[cellKey]
        if cell then
            local objectsToCheck = includeStatic and cell.objects or cell.movingObjects
            
            for _, objectId in ipairs(objectsToCheck) do
                local objectData = self.objectRegistry[objectId]
                if objectData then
                    local distance = (objectData.position - position).Magnitude
                    if distance <= radius then
                        table.insert(nearbyObjects, {
                            object = objectData.object,
                            distance = distance,
                            id = objectId
                        })
                    end
                end
            end
        end
    end
    
    -- Sort by distance
    table.sort(nearbyObjects, function(a, b) return a.distance < b.distance end)
    
    -- Cache result
    self.queryCache[cacheKey] = {
        result = nearbyObjects,
        timestamp = os.time()
    }
    
    self.metrics.queriesPerSecond = self.metrics.queriesPerSecond + 1
    self.metrics.avgQueryTime = (self.metrics.avgQueryTime + (os.clock() - start)) / 2
    self.metrics.cacheHitRate = (self.metrics.cacheHitRate * 0.9) + (0 * 0.1)
    
    return nearbyObjects
end

-- Get objects in region
function SpatialIndexManager:GetObjectsInRegion(minPoint, maxPoint)
    local objects = {}
    local gridCells = self:GetGridCellsInRegion(minPoint, maxPoint)
    
    for _, cellKey in ipairs(gridCells) do
        local cell = self.spatialGrid[cellKey]
        if cell then
            for _, objectId in ipairs(cell.objects) do
                local objectData = self.objectRegistry[objectId]
                if objectData and self:IsObjectInRegion(objectData, minPoint, maxPoint) then
                    table.insert(objects, objectData.object)
                end
            end
        end
    end
    
    return objects
end

-- Ray casting with spatial optimization
function SpatialIndexManager:Raycast(origin, direction, maxDistance)
    local hits = {}
    local normalizedDirection = direction.Unit
    local endPoint = origin + normalizedDirection * maxDistance
    
    -- Get grid cells along ray path
    local cellsAlongRay = self:GetGridCellsAlongRay(origin, endPoint)
    
    for _, cellKey in ipairs(cellsAlongRay) do
        local cell = self.spatialGrid[cellKey]
        if cell then
            for _, objectId in ipairs(cell.objects) do
                local objectData = self.objectRegistry[objectId]
                if objectData then
                    local hit = self:CheckRayObjectIntersection(origin, normalizedDirection, maxDistance, objectData)
                    if hit then
                        table.insert(hits, hit)
                    end
                end
            end
        end
    end
    
    -- Sort hits by distance
    table.sort(hits, function(a, b) return a.distance < b.distance end)
    
    return hits
end

-- Setup update loop
function SpatialIndexManager:SetupUpdateLoop()
    if RunService:IsClient() then
        self.updateConnection = RunService.Heartbeat:Connect(function()
            self:UpdateSpatialIndex()
        end)
    else
        self.updateConnection = RunService.Heartbeat:Connect(function()
            self:UpdateSpatialIndex()
        end)
    end
    
    -- Cleanup timer
    task.spawn(function()
        while true do
            wait(CONFIG.CLEANUP_INTERVAL)
            self:CleanupSpatialIndex()
        end
    end)
end

-- Update spatial index
function SpatialIndexManager:UpdateSpatialIndex()
    local currentTime = os.time()
    
    -- Update moving objects in batches
    local objectsToUpdate = {}
    for objectId, objectData in pairs(self.movingObjects) do
        if currentTime - objectData.lastUpdate > CONFIG.UPDATE_FREQUENCY then
            table.insert(objectsToUpdate, objectData)
        end
    end
    
    -- Process batch
    local endIndex = math.min(self.batchIndex + CONFIG.BATCH_SIZE, #objectsToUpdate)
    for i = self.batchIndex + 1, endIndex do
        local objectData = objectsToUpdate[i]
        if objectData and objectData.object.Parent then
            self:UpdateObject(objectData.object)
        end
    end
    
    self.batchIndex = endIndex >= #objectsToUpdate and 0 or endIndex
    
    -- Update metrics
    if currentTime - self.lastUpdate >= 1 then
        self:UpdateMetrics()
        self.lastUpdate = currentTime
    end
end

-- Cleanup spatial index
function SpatialIndexManager:CleanupSpatialIndex()
    local currentTime = os.time()
    
    -- Clean up destroyed objects
    local objectsToRemove = {}
    for objectId, objectData in pairs(self.objectRegistry) do
        if not objectData.object.Parent then
            table.insert(objectsToRemove, objectId)
        end
    end
    
    for _, objectId in ipairs(objectsToRemove) do
        local objectData = self.objectRegistry[objectId]
        if objectData then
            self:RemoveFromGrid(objectData)
            self:RemoveFromOctree(objectData)
            self.objectRegistry[objectId] = nil
            self.staticObjects[objectId] = nil
            self.movingObjects[objectId] = nil
        end
    end
    
    -- Clean up query cache
    local expiredQueries = {}
    for cacheKey, cached in pairs(self.queryCache) do
        if currentTime - cached.timestamp > CONFIG.QUERY_CACHE_TTL then
            table.insert(expiredQueries, cacheKey)
        end
    end
    
    for _, cacheKey in ipairs(expiredQueries) do
        self.queryCache[cacheKey] = nil
    end
    
    -- Clean up empty grid cells
    local emptyCells = {}
    for cellKey, cell in pairs(self.spatialGrid) do
        if #cell.objects == 0 and currentTime - cell.lastUpdate > 60 then
            table.insert(emptyCells, cellKey)
        end
    end
    
    for _, cellKey in ipairs(emptyCells) do
        self.spatialGrid[cellKey] = nil
        self.metrics.gridCells = self.metrics.gridCells - 1
    end
    
    self.metrics.lastCleanup = currentTime
    print("SpatialIndexManager: Cleanup completed, removed", #objectsToRemove, "objects and", #expiredQueries, "cached queries")
end

-- Utility functions
function SpatialIndexManager:GetObjectPosition(object)
    if object:IsA("Model") and object.PrimaryPart then
        return object.PrimaryPart.Position
    elseif object:IsA("BasePart") then
        return object.Position
    end
    return nil
end

function SpatialIndexManager:GetObjectSize(object)
    if object:IsA("Model") then
        local cf, size = object:GetBoundingBox()
        return size
    elseif object:IsA("BasePart") then
        return object.Size
    end
    return Vector3.new(1, 1, 1)
end

function SpatialIndexManager:GetObjectId(object)
    local id = object:GetAttribute("InstanceId") or object:GetAttribute("UniqueId")
    if not id then
        id = tostring(object:GetDebugId())
        object:SetAttribute("SpatialIndexId", id)
    end
    return id
end

function SpatialIndexManager:CalculateBounds(position, size)
    local halfSize = size / 2
    return {
        min = position - halfSize,
        max = position + halfSize,
        center = position,
        size = size
    }
end

function SpatialIndexManager:CheckAABBCollision(bounds1, bounds2)
    return bounds1.min.X <= bounds2.max.X and bounds1.max.X >= bounds2.min.X and
           bounds1.min.Y <= bounds2.max.Y and bounds1.max.Y >= bounds2.min.Y and
           bounds1.min.Z <= bounds2.max.Z and bounds1.max.Z >= bounds2.min.Z
end

function SpatialIndexManager:IsPositionInBounds(position, bounds)
    local halfSize = bounds.size / 2
    local min = bounds.center - halfSize
    local max = bounds.center + halfSize
    
    return position.X >= min.X and position.X <= max.X and
           position.Y >= min.Y and position.Y <= max.Y and
           position.Z >= min.Z and position.Z <= max.Z
end

function SpatialIndexManager:GetObjectGridCells(objectData)
    local cellKeys = {}
    local bounds = objectData.bounds
    
    -- Get all cells that the object overlaps
    local minCell = self:GetGridKey(bounds.min)
    local maxCell = self:GetGridKey(bounds.max)
    
    -- Parse cell coordinates
    local minX, minY, minZ = minCell:match("(-?%d+),(-?%d+),(-?%d+)")
    local maxX, maxY, maxZ = maxCell:match("(-?%d+),(-?%d+),(-?%d+)")
    
    if minX and maxX then
        for x = tonumber(minX), tonumber(maxX) do
            for y = tonumber(minY), tonumber(maxY) do
                for z = tonumber(minZ), tonumber(maxZ) do
                    table.insert(cellKeys, string.format("%d,%d,%d", x, y, z))
                end
            end
        end
    end
    
    return cellKeys
end

function SpatialIndexManager:GetGridCellsInRadius(position, radius)
    local cellKeys = {}
    local cellRadius = math.ceil(radius / CONFIG.GRID_SIZE)
    local centerCell = self:GetGridKey(position)
    local centerX, centerY, centerZ = centerCell:match("(-?%d+),(-?%d+),(-?%d+)")
    
    if centerX then
        centerX, centerY, centerZ = tonumber(centerX), tonumber(centerY), tonumber(centerZ)
        
        for x = centerX - cellRadius, centerX + cellRadius do
            for y = centerY - cellRadius, centerY + cellRadius do
                for z = centerZ - cellRadius, centerZ + cellRadius do
                    table.insert(cellKeys, string.format("%d,%d,%d", x, y, z))
                end
            end
        end
    end
    
    return cellKeys
end

function SpatialIndexManager:GetGridCellsInRegion(minPoint, maxPoint)
    local cellKeys = {}
    local minCell = self:GetGridKey(minPoint)
    local maxCell = self:GetGridKey(maxPoint)
    
    local minX, minY, minZ = minCell:match("(-?%d+),(-?%d+),(-?%d+)")
    local maxX, maxY, maxZ = maxCell:match("(-?%d+),(-?%d+),(-?%d+)")
    
    if minX and maxX then
        for x = tonumber(minX), tonumber(maxX) do
            for y = tonumber(minY), tonumber(maxY) do
                for z = tonumber(minZ), tonumber(maxZ) do
                    table.insert(cellKeys, string.format("%d,%d,%d", x, y, z))
                end
            end
        end
    end
    
    return cellKeys
end

function SpatialIndexManager:GetGridCellsAlongRay(origin, endPoint)
    local cellKeys = {}
    local direction = (endPoint - origin).Unit
    local distance = (endPoint - origin).Magnitude
    local stepSize = CONFIG.GRID_SIZE / 2
    
    for i = 0, distance, stepSize do
        local point = origin + direction * i
        local cellKey = self:GetGridKey(point)
        if not table.find(cellKeys, cellKey) then
            table.insert(cellKeys, cellKey)
        end
    end
    
    return cellKeys
end

function SpatialIndexManager:IsObjectInRegion(objectData, minPoint, maxPoint)
    local bounds = objectData.bounds
    return bounds.max.X >= minPoint.X and bounds.min.X <= maxPoint.X and
           bounds.max.Y >= minPoint.Y and bounds.min.Y <= maxPoint.Y and
           bounds.max.Z >= minPoint.Z and bounds.min.Z <= maxPoint.Z
end

function SpatialIndexManager:CheckRayObjectIntersection(origin, direction, maxDistance, objectData)
    local bounds = objectData.bounds
    
    -- Simple AABB ray intersection
    local tMin = (bounds.min - origin) / direction
    local tMax = (bounds.max - origin) / direction
    
    local tMinX, tMaxX = math.min(tMin.X, tMax.X), math.max(tMin.X, tMax.X)
    local tMinY, tMaxY = math.min(tMin.Y, tMax.Y), math.max(tMin.Y, tMax.Y)
    local tMinZ, tMaxZ = math.min(tMin.Z, tMax.Z), math.max(tMin.Z, tMax.Z)
    
    local tEnter = math.max(tMinX, tMinY, tMinZ)
    local tExit = math.min(tMaxX, tMaxY, tMaxZ)
    
    if tEnter <= tExit and tEnter >= 0 and tEnter <= maxDistance then
        return {
            object = objectData.object,
            distance = tEnter,
            point = origin + direction * tEnter,
            normal = Vector3.new(0, 1, 0) -- Simplified
        }
    end
    
    return nil
end

function SpatialIndexManager:RemoveFromArray(array, value)
    for i = #array, 1, -1 do
        if array[i] == value then
            table.remove(array, i)
        end
    end
end

function SpatialIndexManager:UpdateMetrics()
    self.metrics.memoryUsage = collectgarbage("count") * 1024
    
    -- Reset per-second counters
    self.metrics.queriesPerSecond = 0
end

-- Get performance metrics
function SpatialIndexManager:GetMetrics()
    return {
        totalObjects = self.metrics.totalObjects,
        gridCells = self.metrics.gridCells,
        octreeNodes = self.metrics.octreeNodes,
        queriesPerSecond = self.metrics.queriesPerSecond,
        avgQueryTime = self.metrics.avgQueryTime,
        collisionChecks = self.metrics.collisionChecks,
        cacheHitRate = self.metrics.cacheHitRate,
        memoryUsage = self.metrics.memoryUsage,
        lastCleanup = self.metrics.lastCleanup,
        octreeMaxDepth = self.octree.maxDepth,
        octreeLeafCount = self.octree.leafCount
    }
end

-- Shutdown spatial index
function SpatialIndexManager:Shutdown()
    if self.updateConnection then
        self.updateConnection:Disconnect()
    end
    
    self.spatialGrid = {}
    self.objectRegistry = {}
    self.movingObjects = {}
    self.staticObjects = {}
    self.queryCache = {}
    
    print("SpatialIndexManager: Shutdown completed")
end

return SpatialIndexManager 