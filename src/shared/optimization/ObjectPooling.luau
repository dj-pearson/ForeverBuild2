-- ObjectPooling.luau
-- High-performance object pooling system for placed objects

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ObjectPooling = {}
ObjectPooling.__index = ObjectPooling

function ObjectPooling.new()
    local self = setmetatable({}, ObjectPooling)
    
    -- Object pools organized by item type
    self.objectPools = {}
    self.poolStats = {}
    
    -- Pool configuration
    self.maxPoolSize = 50 -- Max objects per item type
    self.preloadCount = 5 -- Objects to preload for common items
    self.cleanupInterval = 300 -- Clean unused pools every 5 minutes
    
    -- Performance tracking
    self.performanceMetrics = {
        poolHits = 0,
        poolMisses = 0,
        objectsCreated = 0,
        objectsDestroyed = 0,
        objectsReused = 0,
        memoryReclaimed = 0
    }
    
    self:Initialize()
    return self
end

function ObjectPooling:Initialize()
    -- Start periodic cleanup
    spawn(function()
        while true do
            wait(self.cleanupInterval)
            self:CleanupUnusedPools()
        end
    end)
    
    -- Performance monitoring
    spawn(function()
        while true do
            wait(60) -- Log stats every minute
            self:LogPerformanceStats()
        end
    end)
    
    print("🔄 Object pooling system initialized")
end

-- Get or create an object for placement
function ObjectPooling:GetObject(itemData, placementId)
    local itemId = itemData.ItemId or itemData.Name
    
    -- Try to get from pool first
    local pooledObject = self:GetFromPool(itemId)
    if pooledObject then
        self:PreparePooledObject(pooledObject, itemData, placementId)
        self.performanceMetrics.poolHits = self.performanceMetrics.poolHits + 1
        self.performanceMetrics.objectsReused = self.performanceMetrics.objectsReused + 1
        return pooledObject
    end
    
    -- Create new object if pool is empty
    local newObject = self:CreateNewObject(itemData, placementId)
    self.performanceMetrics.poolMisses = self.performanceMetrics.poolMisses + 1
    self.performanceMetrics.objectsCreated = self.performanceMetrics.objectsCreated + 1
    
    return newObject
end

-- Return object to pool when removed
function ObjectPooling:ReturnObject(objectInstance, itemData)
    local itemId = itemData.ItemId or itemData.Name
    
    if self:CanReturnToPool(objectInstance, itemId) then
        self:CleanObjectForPooling(objectInstance)
        self:AddToPool(itemId, objectInstance)
        self.performanceMetrics.objectsDestroyed = self.performanceMetrics.objectsDestroyed + 1
        return true
    else
        -- Destroy if can't be pooled
        objectInstance:Destroy()
        self.performanceMetrics.objectsDestroyed = self.performanceMetrics.objectsDestroyed + 1
        return false
    end
end

-- Pool management functions
function ObjectPooling:GetFromPool(itemId)
    if not self.objectPools[itemId] or #self.objectPools[itemId] == 0 then
        return nil
    end
    
    local pooledObject = table.remove(self.objectPools[itemId], #self.objectPools[itemId])
    
    -- Update stats
    self.poolStats[itemId] = self.poolStats[itemId] or {retrieved = 0, stored = 0}
    self.poolStats[itemId].retrieved = self.poolStats[itemId].retrieved + 1
    
    return pooledObject
end

function ObjectPooling:AddToPool(itemId, objectInstance)
    -- Initialize pool if needed
    if not self.objectPools[itemId] then
        self.objectPools[itemId] = {}
        self.poolStats[itemId] = {retrieved = 0, stored = 0}
    end
    
    -- Check pool size limit
    if #self.objectPools[itemId] >= self.maxPoolSize then
        -- Destroy oldest object to make room
        local oldestObject = table.remove(self.objectPools[itemId], 1)
        oldestObject:Destroy()
        self.performanceMetrics.memoryReclaimed = self.performanceMetrics.memoryReclaimed + 1
    end
    
    -- Add to pool
    table.insert(self.objectPools[itemId], objectInstance)
    self.poolStats[itemId].stored = self.poolStats[itemId].stored + 1
    
    print("♻️ Returned", itemId, "to pool. Pool size:", #self.objectPools[itemId])
end

-- Object preparation functions
function ObjectPooling:PreparePooledObject(objectInstance, itemData, placementId)
    -- Reset object state
    objectInstance.Name = itemData.Name or "PlacedObject"
    objectInstance:SetAttribute("PlacementId", placementId)
    objectInstance:SetAttribute("ItemId", itemData.ItemId)
    objectInstance:SetAttribute("IsPooled", false)
    
    -- Reset visual properties
    objectInstance.Transparency = 0
    objectInstance.CanCollide = true
    
    -- Remove any temporary modifications
    local warning = objectInstance:FindFirstChild("ModerationWarning")
    if warning then
        warning:Destroy()
    end
    
    -- Re-enable components
    for _, child in ipairs(objectInstance:GetDescendants()) do
        if child:IsA("PointLight") or child:IsA("SpotLight") then
            child.Enabled = true
        elseif child:IsA("ParticleEmitter") then
            child.Enabled = true
        elseif child:IsA("Sound") then
            child.Playing = false
        end
    end
    
    print("♻️ Prepared pooled object:", objectInstance.Name)
end

function ObjectPooling:CleanObjectForPooling(objectInstance)
    -- Mark as pooled
    objectInstance:SetAttribute("IsPooled", true)
    objectInstance:SetAttribute("PlacementId", nil)
    
    -- Reset position to origin
    objectInstance:SetPrimaryPartCFrame(CFrame.new(0, -1000, 0))
    
    -- Make invisible and non-collidable
    objectInstance.Transparency = 1
    objectInstance.CanCollide = false
    
    -- Disable resource-intensive components
    for _, child in ipairs(objectInstance:GetDescendants()) do
        if child:IsA("PointLight") or child:IsA("SpotLight") then
            child.Enabled = false
        elseif child:IsA("ParticleEmitter") then
            child.Enabled = false
        elseif child:IsA("Sound") then
            child:Stop()
        end
    end
    
    -- Remove any temporary UI or effects
    for _, child in ipairs(objectInstance:GetChildren()) do
        if child:IsA("BillboardGui") or child:IsA("SurfaceGui") then
            child:Destroy()
        end
    end
end

function ObjectPooling:CreateNewObject(itemData, placementId)
    -- This would integrate with your existing object creation logic
    -- For now, creating a basic placeholder
    local newObject = Instance.new("Model")
    newObject.Name = itemData.Name or "PlacedObject"
    newObject:SetAttribute("PlacementId", placementId)
    newObject:SetAttribute("ItemId", itemData.ItemId)
    newObject:SetAttribute("IsPooled", false)
    
    -- Add basic part (you'd replace this with actual item loading)
    local primaryPart = Instance.new("Part")
    primaryPart.Name = "PrimaryPart"
    primaryPart.Size = Vector3.new(4, 4, 4)
    primaryPart.Material = Enum.Material.Plastic
    primaryPart.BrickColor = BrickColor.new("Bright blue")
    primaryPart.Parent = newObject
    newObject.PrimaryPart = primaryPart
    
    print("🆕 Created new object:", itemData.Name)
    return newObject
end

-- Validation functions
function ObjectPooling:CanReturnToPool(objectInstance, itemId)
    -- Check if object is suitable for pooling
    if not objectInstance or not objectInstance.Parent then
        return false
    end
    
    -- Don't pool if destroyed or corrupted
    if not objectInstance:FindFirstChild("PrimaryPart") then
        return false
    end
    
    -- Don't pool objects with active scripts (potential security risk)
    for _, child in ipairs(objectInstance:GetDescendants()) do
        if child:IsA("Script") or child:IsA("LocalScript") then
            return false
        end
    end
    
    return true
end

-- Preload common objects
function ObjectPooling:PreloadCommonObjects(commonItems)
    for _, itemData in ipairs(commonItems) do
        local itemId = itemData.ItemId or itemData.Name
        
        print("🔄 Preloading pool for:", itemId)
        
        for i = 1, self.preloadCount do
            local tempObject = self:CreateNewObject(itemData, "PRELOAD_" .. i)
            self:CleanObjectForPooling(tempObject)
            self:AddToPool(itemId, tempObject)
        end
    end
    
    print("✅ Preloaded", #commonItems, "item types")
end

-- Maintenance functions
function ObjectPooling:CleanupUnusedPools()
    local cleaned = 0
    
    for itemId, pool in pairs(self.objectPools) do
        local stats = self.poolStats[itemId]
        
        -- Remove pools that haven't been used recently
        if stats and stats.retrieved == 0 and #pool > 0 then
            for _, obj in ipairs(pool) do
                obj:Destroy()
                cleaned = cleaned + 1
            end
            
            self.objectPools[itemId] = nil
            self.poolStats[itemId] = nil
            print("🧹 Cleaned unused pool:", itemId)
        else
            -- Reset usage stats for next cycle
            if stats then
                stats.retrieved = 0
                stats.stored = 0
            end
        end
    end
    
    if cleaned > 0 then
        print("🧹 Pool cleanup: destroyed", cleaned, "unused objects")
        self.performanceMetrics.memoryReclaimed = self.performanceMetrics.memoryReclaimed + cleaned
    end
end

function ObjectPooling:LogPerformanceStats()
    local totalPooled = 0
    local poolCount = 0
    
    for itemId, pool in pairs(self.objectPools) do
        totalPooled = totalPooled + #pool
        poolCount = poolCount + 1
    end
    
    print("📊 Object Pool Performance:")
    print("   Pools active:", poolCount)
    print("   Total pooled objects:", totalPooled)
    print("   Pool hits:", self.performanceMetrics.poolHits)
    print("   Pool misses:", self.performanceMetrics.poolMisses)
    print("   Objects reused:", self.performanceMetrics.objectsReused)
    print("   Memory reclaimed:", self.performanceMetrics.memoryReclaimed)
    
    if self.performanceMetrics.poolHits + self.performanceMetrics.poolMisses > 0 then
        local hitRate = self.performanceMetrics.poolHits / (self.performanceMetrics.poolHits + self.performanceMetrics.poolMisses) * 100
        print("   Pool hit rate:", math.floor(hitRate) .. "%")
    end
end

-- Performance analysis
function ObjectPooling:GetPoolingEfficiency()
    local totalRequests = self.performanceMetrics.poolHits + self.performanceMetrics.poolMisses
    if totalRequests == 0 then return 0 end
    
    return {
        hitRate = self.performanceMetrics.poolHits / totalRequests * 100,
        reuseRate = self.performanceMetrics.objectsReused / self.performanceMetrics.objectsCreated * 100,
        memoryEfficiency = self.performanceMetrics.memoryReclaimed,
        totalPools = 0, -- Will be calculated
        totalPooledObjects = 0 -- Will be calculated
    }
end

-- Get current pool status
function ObjectPooling:GetPoolStatus()
    local status = {}
    
    for itemId, pool in pairs(self.objectPools) do
        status[itemId] = {
            poolSize = #pool,
            maxSize = self.maxPoolSize,
            stats = self.poolStats[itemId] or {retrieved = 0, stored = 0}
        }
    end
    
    return status
end

-- Force cleanup for memory management
function ObjectPooling:ForceCleanup()
    local destroyed = 0
    
    for itemId, pool in pairs(self.objectPools) do
        for _, obj in ipairs(pool) do
            obj:Destroy()
            destroyed = destroyed + 1
        end
        self.objectPools[itemId] = {}
    end
    
    print("💥 Force cleanup: destroyed", destroyed, "pooled objects")
    self.performanceMetrics.memoryReclaimed = self.performanceMetrics.memoryReclaimed + destroyed
    
    return destroyed
end

return ObjectPooling 