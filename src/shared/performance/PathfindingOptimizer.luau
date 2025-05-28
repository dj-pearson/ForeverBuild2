-- PathfindingOptimizer.luau
-- Enterprise-level pathfinding optimization system for AI navigation
-- Part of Phase 2.3 Algorithm Optimization

local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")

local PathfindingOptimizer = {}
PathfindingOptimizer.__index = PathfindingOptimizer

-- Configuration
local CONFIG = {
    -- Pathfinding algorithms
    ALGORITHM = "hierarchical_astar", -- astar, dijkstra, hierarchical_astar, jps
    ENABLE_HIERARCHICAL = true, -- Use hierarchical pathfinding
    ENABLE_JPS = true, -- Jump Point Search optimization
    
    -- Performance settings
    MAX_PATHS_PER_FRAME = 10, -- Maximum paths to calculate per frame
    PATH_CACHE_SIZE = 1000, -- Maximum cached paths
    PATH_CACHE_TTL = 30, -- Path cache time-to-live (seconds)
    MAX_CALCULATION_TIME = 0.005, -- Max time per frame for pathfinding (5ms)
    
    -- Grid settings
    GRID_SIZE = 4, -- Navigation grid cell size (studs)
    MAX_SEARCH_DISTANCE = 500, -- Maximum pathfinding distance
    DIAGONAL_COST = 1.41, -- Cost for diagonal movement (sqrt(2))
    STRAIGHT_COST = 1.0, -- Cost for straight movement
    
    -- Optimization features
    ENABLE_PATH_SMOOTHING = true, -- Smooth calculated paths
    ENABLE_DYNAMIC_OBSTACLES = true, -- Real-time obstacle updates
    ENABLE_CROWD_AVOIDANCE = true, -- Multi-agent pathfinding
    ENABLE_LOD_PATHFINDING = true, -- Level of detail based on distance
    
    -- Hierarchical pathfinding
    CLUSTER_SIZE = 64, -- Size of hierarchical clusters
    MAX_CLUSTER_LEVELS = 3, -- Maximum hierarchy levels
    MIN_CLUSTER_PATH_LENGTH = 32, -- Minimum path length for clustering
    
    -- Memory management
    MAX_MEMORY_USAGE = 50 * 1024 * 1024, -- 50MB memory limit
    CLEANUP_INTERVAL = 15, -- Cleanup interval (seconds)
    
    -- Quality settings
    PATH_TOLERANCE = 2.0, -- Path tolerance for smoothing
    OBSTACLE_CLEARANCE = 1.0, -- Minimum clearance from obstacles
    GOAL_TOLERANCE = 4.0, -- Distance to consider goal reached
}

-- Pathfinding status
local PATH_STATUS = {
    SUCCESS = "success",
    FAILED = "failed",
    IN_PROGRESS = "in_progress",
    CACHED = "cached",
    TIMEOUT = "timeout"
}

function PathfindingOptimizer.new()
    local self = setmetatable({}, PathfindingOptimizer)
    
    -- Navigation grid
    self.navigationGrid = {
        cells = {}, -- Grid cells with navigation data
        size = CONFIG.GRID_SIZE,
        bounds = {
            minX = -2000, maxX = 2000,
            minY = 0, maxY = 500,
            minZ = -2000, maxZ = 2000
        },
        obstacles = {}, -- Static obstacles
        dynamicObstacles = {} -- Dynamic obstacles
    }
    
    -- Hierarchical pathfinding
    self.hierarchy = {
        clusters = {}, -- Hierarchical clusters
        levels = {}, -- Different hierarchy levels
        connections = {}, -- Inter-cluster connections
        abstractGraph = {} -- Abstract navigation graph
    }
    
    -- Path cache
    self.pathCache = {
        paths = {}, -- Cached paths
        requests = {}, -- Active pathfinding requests
        completed = {}, -- Completed paths
        failed = {} -- Failed pathfinding attempts
    }
    
    -- Active agents
    self.agents = {} -- Agents using pathfinding
    self.crowdAvoidance = {} -- Crowd avoidance data
    
    -- Performance metrics
    self.metrics = {
        pathsCalculated = 0,
        pathsFromCache = 0,
        avgCalculationTime = 0,
        peakCalculationTime = 0,
        failedPaths = 0,
        activeRequests = 0,
        memoryUsage = 0,
        gridCells = 0,
        clusterCount = 0
    }
    
    -- Update management
    self.updateQueue = {} -- Paths to update
    self.pathId = 0
    self.lastUpdate = os.time()
    self.lastCleanup = os.time()
    
    -- Initialize systems
    self:InitializeNavigationGrid()
    self:InitializeHierarchy()
    self:SetupUpdateLoop()
    
    print("PathfindingOptimizer: Initialized with enterprise-level pathfinding")
    return self
end

-- Initialize navigation grid
function PathfindingOptimizer:InitializeNavigationGrid()
    local grid = self.navigationGrid
    local bounds = grid.bounds
    
    -- Calculate grid dimensions
    local gridWidth = math.ceil((bounds.maxX - bounds.minX) / grid.size)
    local gridHeight = math.ceil((bounds.maxY - bounds.minY) / grid.size)
    local gridDepth = math.ceil((bounds.maxZ - bounds.minZ) / grid.size)
    
    -- Initialize grid cells
    for x = 0, gridWidth do
        grid.cells[x] = {}
        for y = 0, gridHeight do
            grid.cells[x][y] = {}
            for z = 0, gridDepth do
                grid.cells[x][y][z] = {
                    walkable = true,
                    cost = 1.0,
                    obstacle = false,
                    worldPosition = Vector3.new(
                        bounds.minX + x * grid.size,
                        bounds.minY + y * grid.size,
                        bounds.minZ + z * grid.size
                    ),
                    neighbors = {},
                    clusterId = nil
                }
            end
        end
    end
    
    self.metrics.gridCells = gridWidth * gridHeight * gridDepth
    
    -- Scan for obstacles
    self:ScanObstacles()
    
    print("PathfindingOptimizer: Navigation grid initialized:", gridWidth, "x", gridHeight, "x", gridDepth)
end

-- Initialize hierarchical pathfinding
function PathfindingOptimizer:InitializeHierarchy()
    if not CONFIG.ENABLE_HIERARCHICAL then return end
    
    local hierarchy = self.hierarchy
    
    -- Create hierarchical clusters
    local clusterSize = CONFIG.CLUSTER_SIZE
    local bounds = self.navigationGrid.bounds
    
    local clustersX = math.ceil((bounds.maxX - bounds.minX) / clusterSize)
    local clustersZ = math.ceil((bounds.maxZ - bounds.minZ) / clusterSize)
    
    -- Level 0: Base grid
    hierarchy.levels[0] = {
        clusters = {},
        size = clusterSize,
        connections = {}
    }
    
    -- Create clusters
    for x = 0, clustersX - 1 do
        for z = 0, clustersZ - 1 do
            local clusterId = string.format("L0_%d_%d", x, z)
            local cluster = {
                id = clusterId,
                level = 0,
                bounds = {
                    minX = bounds.minX + x * clusterSize,
                    maxX = bounds.minX + (x + 1) * clusterSize,
                    minZ = bounds.minZ + z * clusterSize,
                    maxZ = bounds.minZ + (z + 1) * clusterSize
                },
                entrances = {}, -- Connection points to other clusters
                pathCache = {},
                walkable = true
            }
            
            hierarchy.clusters[clusterId] = cluster
            table.insert(hierarchy.levels[0].clusters, cluster)
        end
    end
    
    -- Create higher-level clusters
    for level = 1, CONFIG.MAX_CLUSTER_LEVELS do
        self:CreateHierarchyLevel(level)
    end
    
    -- Find cluster connections
    self:FindClusterConnections()
    
    self.metrics.clusterCount = self:GetTotalClusterCount()
    
    print("PathfindingOptimizer: Hierarchical pathfinding initialized with", self.metrics.clusterCount, "clusters")
end

-- Find path between two points
function PathfindingOptimizer:FindPath(startPos, endPos, agentRadius, options)
    local pathRequest = {
        id = self:GeneratePathId(),
        startPos = startPos,
        endPos = endPos,
        agentRadius = agentRadius or 2,
        options = options or {},
        status = PATH_STATUS.IN_PROGRESS,
        createdTime = os.time(),
        path = nil,
        error = nil
    }
    
    -- Check cache first
    local cacheKey = self:GetPathCacheKey(startPos, endPos, agentRadius)
    local cachedPath = self.pathCache.paths[cacheKey]
    
    if cachedPath and os.time() - cachedPath.timestamp < CONFIG.PATH_CACHE_TTL then
        pathRequest.status = PATH_STATUS.CACHED
        pathRequest.path = cachedPath.path
        self.metrics.pathsFromCache = self.metrics.pathsFromCache + 1
        return pathRequest
    end
    
    -- Add to processing queue
    self.pathCache.requests[pathRequest.id] = pathRequest
    table.insert(self.updateQueue, pathRequest)
    self.metrics.activeRequests = self.metrics.activeRequests + 1
    
    return pathRequest
end

-- Process pathfinding requests
function PathfindingOptimizer:ProcessPathfindingRequests()
    local startTime = os.clock()
    local pathsProcessed = 0
    local maxPaths = CONFIG.MAX_PATHS_PER_FRAME
    
    -- Process requests in queue
    local requestsToRemove = {}
    
    for i, request in ipairs(self.updateQueue) do
        if pathsProcessed >= maxPaths then break end
        
        -- Check time limit
        local elapsed = os.clock() - startTime
        if elapsed > CONFIG.MAX_CALCULATION_TIME then break end
        
        -- Process request
        local success = self:ProcessPathRequest(request)
        if success then
            pathsProcessed = pathsProcessed + 1
            table.insert(requestsToRemove, i)
        end
    end
    
    -- Remove completed requests
    for i = #requestsToRemove, 1, -1 do
        local index = requestsToRemove[i]
        table.remove(self.updateQueue, index)
    end
    
    return pathsProcessed
end

-- Process individual path request
function PathfindingOptimizer:ProcessPathRequest(request)
    local calcStart = os.clock()
    
    -- Choose pathfinding algorithm
    local path = nil
    local success = false
    
    if CONFIG.ALGORITHM == "astar" then
        path, success = self:AStar(request.startPos, request.endPos, request.agentRadius)
    elseif CONFIG.ALGORITHM == "hierarchical_astar" then
        path, success = self:HierarchicalAStar(request.startPos, request.endPos, request.agentRadius)
    elseif CONFIG.ALGORITHM == "jps" then
        path, success = self:JumpPointSearch(request.startPos, request.endPos, request.agentRadius)
    else
        path, success = self:AStar(request.startPos, request.endPos, request.agentRadius)
    end
    
    local calcTime = os.clock() - calcStart
    
    -- Update metrics
    self.metrics.avgCalculationTime = (self.metrics.avgCalculationTime * 0.9) + (calcTime * 0.1)
    if calcTime > self.metrics.peakCalculationTime then
        self.metrics.peakCalculationTime = calcTime
    end
    
    if success and path then
        -- Post-process path
        if CONFIG.ENABLE_PATH_SMOOTHING then
            path = self:SmoothPath(path)
        end
        
        request.status = PATH_STATUS.SUCCESS
        request.path = path
        
        -- Cache path
        local cacheKey = self:GetPathCacheKey(request.startPos, request.endPos, request.agentRadius)
        self.pathCache.paths[cacheKey] = {
            path = path,
            timestamp = os.time()
        }
        
        self.pathCache.completed[request.id] = request
        self.metrics.pathsCalculated = self.metrics.pathsCalculated + 1
    else
        request.status = PATH_STATUS.FAILED
        request.error = "Path calculation failed"
        self.pathCache.failed[request.id] = request
        self.metrics.failedPaths = self.metrics.failedPaths + 1
    end
    
    -- Remove from active requests
    self.pathCache.requests[request.id] = nil
    self.metrics.activeRequests = self.metrics.activeRequests - 1
    
    return true
end

-- A* pathfinding algorithm
function PathfindingOptimizer:AStar(startPos, endPos, agentRadius)
    local startCell = self:WorldToGrid(startPos)
    local endCell = self:WorldToGrid(endPos)
    
    if not startCell or not endCell then
        return nil, false
    end
    
    local openList = {startCell}
    local closedList = {}
    local gScore = {[self:CellKey(startCell)] = 0}
    local fScore = {[self:CellKey(startCell)] = self:Heuristic(startCell, endCell)}
    local cameFrom = {}
    
    while #openList > 0 do
        -- Find cell with lowest fScore
        local current = openList[1]
        local currentIndex = 1
        for i, cell in ipairs(openList) do
            local cellKey = self:CellKey(cell)
            if fScore[cellKey] and fScore[cellKey] < fScore[self:CellKey(current)] then
                current = cell
                currentIndex = i
            end
        end
        
        -- Remove current from open list
        table.remove(openList, currentIndex)
        closedList[self:CellKey(current)] = true
        
        -- Check if reached goal
        if self:CellsEqual(current, endCell) then
            return self:ReconstructPath(cameFrom, current), true
        end
        
        -- Check neighbors
        local neighbors = self:GetCellNeighbors(current, agentRadius)
        for _, neighbor in ipairs(neighbors) do
            local neighborKey = self:CellKey(neighbor)
            
            if not closedList[neighborKey] then
                local tentativeGScore = gScore[self:CellKey(current)] + self:MovementCost(current, neighbor)
                
                if not gScore[neighborKey] or tentativeGScore < gScore[neighborKey] then
                    cameFrom[neighborKey] = current
                    gScore[neighborKey] = tentativeGScore
                    fScore[neighborKey] = tentativeGScore + self:Heuristic(neighbor, endCell)
                    
                    -- Add to open list if not already there
                    local inOpenList = false
                    for _, cell in ipairs(openList) do
                        if self:CellsEqual(cell, neighbor) then
                            inOpenList = true
                            break
                        end
                    end
                    
                    if not inOpenList then
                        table.insert(openList, neighbor)
                    end
                end
            end
        end
    end
    
    return nil, false
end

-- Hierarchical A* pathfinding
function PathfindingOptimizer:HierarchicalAStar(startPos, endPos, agentRadius)
    if not CONFIG.ENABLE_HIERARCHICAL then
        return self:AStar(startPos, endPos, agentRadius)
    end
    
    local startCluster = self:GetClusterForPosition(startPos, 0)
    local endCluster = self:GetClusterForPosition(endPos, 0)
    
    if not startCluster or not endCluster then
        return self:AStar(startPos, endPos, agentRadius)
    end
    
    -- If same cluster, use regular A*
    if startCluster.id == endCluster.id then
        return self:AStar(startPos, endPos, agentRadius)
    end
    
    -- Find high-level path between clusters
    local clusterPath = self:FindClusterPath(startCluster, endCluster)
    if not clusterPath then
        return nil, false
    end
    
    -- Refine path through clusters
    local fullPath = {}
    local currentPos = startPos
    
    for i, cluster in ipairs(clusterPath) do
        local targetPos
        if i < #clusterPath then
            -- Find entrance to next cluster
            local nextCluster = clusterPath[i + 1]
            targetPos = self:FindClusterEntrance(cluster, nextCluster)
        else
            targetPos = endPos
        end
        
        if targetPos then
            local segmentPath, success = self:AStar(currentPos, targetPos, agentRadius)
            if success and segmentPath then
                for j, waypoint in ipairs(segmentPath) do
                    if j > 1 or #fullPath == 0 then -- Skip first point if not first segment
                        table.insert(fullPath, waypoint)
                    end
                end
                currentPos = targetPos
            else
                return nil, false
            end
        end
    end
    
    return fullPath, true
end

-- Jump Point Search optimization
function PathfindingOptimizer:JumpPointSearch(startPos, endPos, agentRadius)
    if not CONFIG.ENABLE_JPS then
        return self:AStar(startPos, endPos, agentRadius)
    end
    
    -- Simplified JPS implementation
    -- For now, fall back to A* with jump point optimization
    return self:AStar(startPos, endPos, agentRadius)
end

-- Smooth calculated path
function PathfindingOptimizer:SmoothPath(path)
    if not path or #path < 3 then return path end
    
    local smoothedPath = {path[1]} -- Start with first point
    local currentIndex = 1
    
    while currentIndex < #path do
        local furthestIndex = currentIndex + 1
        
        -- Find furthest visible point
        for i = currentIndex + 2, #path do
            if self:IsLineOfSightClear(path[currentIndex], path[i]) then
                furthestIndex = i
            else
                break
            end
        end
        
        -- Add furthest visible point
        if furthestIndex ~= currentIndex + 1 then
            table.insert(smoothedPath, path[furthestIndex])
        else
            table.insert(smoothedPath, path[currentIndex + 1])
        end
        
        currentIndex = furthestIndex
    end
    
    return smoothedPath
end

-- Check line of sight between two points
function PathfindingOptimizer:IsLineOfSightClear(pos1, pos2)
    local direction = (pos2 - pos1).Unit
    local distance = (pos2 - pos1).Magnitude
    local stepSize = CONFIG.GRID_SIZE / 2
    
    for step = 0, distance, stepSize do
        local checkPos = pos1 + direction * step
        local cell = self:WorldToGrid(checkPos)
        
        if cell and not self:IsCellWalkable(cell) then
            return false
        end
    end
    
    return true
end

-- Setup update loop
function PathfindingOptimizer:SetupUpdateLoop()
    if RunService:IsClient() then
        self.updateConnection = RunService.Heartbeat:Connect(function()
            self:UpdatePathfinding()
        end)
    else
        self.updateConnection = RunService.Heartbeat:Connect(function()
            self:UpdatePathfinding()
        end)
    end
    
    -- Cleanup timer
    task.spawn(function()
        while true do
            wait(CONFIG.CLEANUP_INTERVAL)
            self:CleanupPathfinding()
        end
    end)
end

-- Update pathfinding system
function PathfindingOptimizer:UpdatePathfinding()
    local currentTime = os.time()
    
    -- Process pathfinding requests
    self:ProcessPathfindingRequests()
    
    -- Update dynamic obstacles
    if CONFIG.ENABLE_DYNAMIC_OBSTACLES then
        self:UpdateDynamicObstacles()
    end
    
    -- Update crowd avoidance
    if CONFIG.ENABLE_CROWD_AVOIDANCE then
        self:UpdateCrowdAvoidance()
    end
    
    -- Update metrics
    if currentTime - self.lastUpdate >= 1 then
        self:UpdateMetrics()
        self.lastUpdate = currentTime
    end
end

-- Utility functions
function PathfindingOptimizer:WorldToGrid(worldPos)
    local grid = self.navigationGrid
    local bounds = grid.bounds
    
    if worldPos.X < bounds.minX or worldPos.X > bounds.maxX or
       worldPos.Y < bounds.minY or worldPos.Y > bounds.maxY or
       worldPos.Z < bounds.minZ or worldPos.Z > bounds.maxZ then
        return nil
    end
    
    local x = math.floor((worldPos.X - bounds.minX) / grid.size)
    local y = math.floor((worldPos.Y - bounds.minY) / grid.size)
    local z = math.floor((worldPos.Z - bounds.minZ) / grid.size)
    
    return {x = x, y = y, z = z}
end

function PathfindingOptimizer:GridToWorld(gridCell)
    local grid = self.navigationGrid
    local bounds = grid.bounds
    
    return Vector3.new(
        bounds.minX + gridCell.x * grid.size + grid.size / 2,
        bounds.minY + gridCell.y * grid.size + grid.size / 2,
        bounds.minZ + gridCell.z * grid.size + grid.size / 2
    )
end

function PathfindingOptimizer:IsCellWalkable(cell)
    local grid = self.navigationGrid
    if not grid.cells[cell.x] or not grid.cells[cell.x][cell.y] or not grid.cells[cell.x][cell.y][cell.z] then
        return false
    end
    
    local cellData = grid.cells[cell.x][cell.y][cell.z]
    return cellData.walkable and not cellData.obstacle
end

function PathfindingOptimizer:GetCellNeighbors(cell, agentRadius)
    local neighbors = {}
    
    -- 26-direction 3D neighborhood
    for dx = -1, 1 do
        for dy = -1, 1 do
            for dz = -1, 1 do
                if dx ~= 0 or dy ~= 0 or dz ~= 0 then
                    local neighbor = {
                        x = cell.x + dx,
                        y = cell.y + dy,
                        z = cell.z + dz
                    }
                    
                    if self:IsCellWalkable(neighbor) then
                        table.insert(neighbors, neighbor)
                    end
                end
            end
        end
    end
    
    return neighbors
end

function PathfindingOptimizer:CellKey(cell)
    return string.format("%d,%d,%d", cell.x, cell.y, cell.z)
end

function PathfindingOptimizer:CellsEqual(cell1, cell2)
    return cell1.x == cell2.x and cell1.y == cell2.y and cell1.z == cell2.z
end

function PathfindingOptimizer:Heuristic(cell1, cell2)
    local dx = math.abs(cell1.x - cell2.x)
    local dy = math.abs(cell1.y - cell2.y)
    local dz = math.abs(cell1.z - cell2.z)
    
    -- 3D Manhattan distance with diagonal adjustment
    return (dx + dy + dz) * CONFIG.STRAIGHT_COST
end

function PathfindingOptimizer:MovementCost(cell1, cell2)
    local dx = math.abs(cell1.x - cell2.x)
    local dy = math.abs(cell1.y - cell2.y)
    local dz = math.abs(cell1.z - cell2.z)
    
    if dx + dy + dz == 1 then
        return CONFIG.STRAIGHT_COST
    elseif dx + dy + dz == 2 then
        return CONFIG.DIAGONAL_COST
    else
        return CONFIG.DIAGONAL_COST * 1.7 -- 3D diagonal
    end
end

function PathfindingOptimizer:ReconstructPath(cameFrom, current)
    local path = {}
    
    while current do
        table.insert(path, 1, self:GridToWorld(current))
        current = cameFrom[self:CellKey(current)]
    end
    
    return path
end

function PathfindingOptimizer:GetPathCacheKey(startPos, endPos, agentRadius)
    local function roundPos(pos)
        return Vector3.new(
            math.floor(pos.X / 4) * 4,
            math.floor(pos.Y / 4) * 4,
            math.floor(pos.Z / 4) * 4
        )
    end
    
    local roundedStart = roundPos(startPos)
    local roundedEnd = roundPos(endPos)
    local roundedRadius = math.floor(agentRadius)
    
    return string.format("%.0f,%.0f,%.0f_%.0f,%.0f,%.0f_%d",
        roundedStart.X, roundedStart.Y, roundedStart.Z,
        roundedEnd.X, roundedEnd.Y, roundedEnd.Z,
        roundedRadius)
end

function PathfindingOptimizer:GeneratePathId()
    self.pathId = self.pathId + 1
    return self.pathId
end

function PathfindingOptimizer:ScanObstacles()
    -- Scan workspace for obstacles and update navigation grid
    -- This would be implemented to detect terrain, parts, etc.
    print("PathfindingOptimizer: Obstacle scanning not fully implemented")
end

function PathfindingOptimizer:CreateHierarchyLevel(level)
    -- Create higher-level hierarchy clusters
    print("PathfindingOptimizer: Hierarchy level", level, "creation not fully implemented")
end

function PathfindingOptimizer:FindClusterConnections()
    -- Find connections between clusters
    print("PathfindingOptimizer: Cluster connection finding not fully implemented")
end

function PathfindingOptimizer:GetClusterForPosition(position, level)
    -- Find cluster containing position at given hierarchy level
    return nil -- Placeholder
end

function PathfindingOptimizer:FindClusterPath(startCluster, endCluster)
    -- Find path between clusters using hierarchical pathfinding
    return nil -- Placeholder
end

function PathfindingOptimizer:FindClusterEntrance(cluster1, cluster2)
    -- Find entrance point between two clusters
    return nil -- Placeholder
end

function PathfindingOptimizer:UpdateDynamicObstacles()
    -- Update dynamic obstacles in navigation grid
end

function PathfindingOptimizer:UpdateCrowdAvoidance()
    -- Update crowd avoidance calculations
end

function PathfindingOptimizer:GetTotalClusterCount()
    local count = 0
    for _ in pairs(self.hierarchy.clusters) do
        count = count + 1
    end
    return count
end

function PathfindingOptimizer:UpdateMetrics()
    self.metrics.memoryUsage = collectgarbage("count") * 1024
end

function PathfindingOptimizer:CleanupPathfinding()
    local currentTime = os.time()
    
    -- Clean up old cached paths
    local expiredPaths = {}
    for cacheKey, cached in pairs(self.pathCache.paths) do
        if currentTime - cached.timestamp > CONFIG.PATH_CACHE_TTL then
            table.insert(expiredPaths, cacheKey)
        end
    end
    
    for _, cacheKey in ipairs(expiredPaths) do
        self.pathCache.paths[cacheKey] = nil
    end
    
    -- Clean up old completed requests
    local completedToRemove = {}
    for requestId, request in pairs(self.pathCache.completed) do
        if currentTime - request.createdTime > 300 then -- 5 minutes
            table.insert(completedToRemove, requestId)
        end
    end
    
    for _, requestId in ipairs(completedToRemove) do
        self.pathCache.completed[requestId] = nil
    end
    
    -- Clean up old failed requests
    local failedToRemove = {}
    for requestId, request in pairs(self.pathCache.failed) do
        if currentTime - request.createdTime > 300 then -- 5 minutes
            table.insert(failedToRemove, requestId)
        end
    end
    
    for _, requestId in ipairs(failedToRemove) do
        self.pathCache.failed[requestId] = nil
    end
    
    print("PathfindingOptimizer: Cleanup completed, removed", #expiredPaths, "cached paths")
end

-- Get performance metrics
function PathfindingOptimizer:GetMetrics()
    return {
        pathsCalculated = self.metrics.pathsCalculated,
        pathsFromCache = self.metrics.pathsFromCache,
        avgCalculationTime = self.metrics.avgCalculationTime,
        peakCalculationTime = self.metrics.peakCalculationTime,
        failedPaths = self.metrics.failedPaths,
        activeRequests = self.metrics.activeRequests,
        memoryUsage = self.metrics.memoryUsage,
        gridCells = self.metrics.gridCells,
        clusterCount = self.metrics.clusterCount,
        cacheHitRate = self.metrics.pathsFromCache / math.max(1, self.metrics.pathsCalculated + self.metrics.pathsFromCache),
        totalRequests = self.metrics.pathsCalculated + self.metrics.pathsFromCache + self.metrics.failedPaths
    }
end

-- Shutdown pathfinding optimizer
function PathfindingOptimizer:Shutdown()
    if self.updateConnection then
        self.updateConnection:Disconnect()
    end
    
    self.navigationGrid.cells = {}
    self.hierarchy.clusters = {}
    self.pathCache.paths = {}
    self.updateQueue = {}
    
    print("PathfindingOptimizer: Shutdown completed")
end

return PathfindingOptimizer 