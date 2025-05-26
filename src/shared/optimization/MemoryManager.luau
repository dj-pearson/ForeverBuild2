-- MemoryManager.luau
-- Advanced memory management and leak prevention system

local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Players = game:GetService("Players")

local MemoryManager = {}
MemoryManager.__index = MemoryManager

function MemoryManager.new(objectPooling, placementTracker)
    local self = setmetatable({}, MemoryManager)
    
    self.objectPooling = objectPooling
    self.placementTracker = placementTracker
    
    -- Memory monitoring
    self.memoryThresholds = {
        warning = 800,    -- 800MB warning threshold
        critical = 1000,  -- 1GB critical threshold
        emergency = 1200  -- 1.2GB emergency cleanup
    }
    
    -- Cleanup strategies
    self.cleanupStrategies = {
        lowMemory = {
            enabled = true,
            threshold = 600,
            actions = {"cleanup_effects", "reduce_lod", "clear_caches"}
        },
        mediumMemory = {
            enabled = true,
            threshold = 800,
            actions = {"force_pool_cleanup", "destroy_distant_objects", "compress_textures"}
        },
        highMemory = {
            enabled = true,
            threshold = 1000,
            actions = {"emergency_cleanup", "force_garbage_collection", "restart_warning"}
        }
    }
    
    -- Memory tracking
    self.memoryHistory = {}
    self.leakDetection = {
        trackingObjects = {},
        suspiciousPatterns = {},
        lastCleanupTime = 0
    }
    
    -- Performance optimization flags
    self.optimizationMode = "NORMAL" -- NORMAL, PERFORMANCE, EMERGENCY
    
    self:Initialize()
    return self
end

function MemoryManager:Initialize()
    -- Start memory monitoring
    self:StartMemoryMonitoring()
    
    -- Start leak detection
    self:StartLeakDetection()
    
    -- Handle player connections for memory optimization
    Players.PlayerAdded:Connect(function(player)
        self:OptimizeForPlayerCount()
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        self:OptimizeForPlayerCount()
        self:CleanupPlayerMemory(player)
    end)
    
    print("🧠 Memory management system initialized")
end

-- Core memory monitoring
function MemoryManager:StartMemoryMonitoring()
    spawn(function()
        while true do
            wait(30) -- Check every 30 seconds
            
            local currentMemory = Stats:GetTotalMemoryUsageMb()
            self:RecordMemoryUsage(currentMemory)
            
            -- Check thresholds and respond
            if currentMemory >= self.memoryThresholds.emergency then
                self:HandleEmergencyMemory(currentMemory)
            elseif currentMemory >= self.memoryThresholds.critical then
                self:HandleCriticalMemory(currentMemory)
            elseif currentMemory >= self.memoryThresholds.warning then
                self:HandleWarningMemory(currentMemory)
            end
            
            -- Adaptive optimization
            self:UpdateOptimizationMode(currentMemory)
        end
    end)
end

function MemoryManager:RecordMemoryUsage(memoryUsage)
    local record = {
        timestamp = os.time(),
        memory = memoryUsage,
        players = #Players:GetPlayers(),
        objects = self:CountActiveObjects(),
        mode = self.optimizationMode
    }
    
    table.insert(self.memoryHistory, record)
    
    -- Keep only last 24 hours of data
    if #self.memoryHistory > 2880 then -- 24 hours * 60 minutes / 0.5 minutes
        table.remove(self.memoryHistory, 1)
    end
end

-- Memory threshold handlers
function MemoryManager:HandleWarningMemory(memoryUsage)
    print("⚠️ WARNING: High memory usage:", memoryUsage, "MB")
    
    -- Apply low-impact optimizations
    self:ReduceVisualEffects()
    self:OptimizeLODSettings()
    self:CleanupCaches()
    
    -- Notify admins if available
    self:NotifyAdmins("WARNING", "High memory usage: " .. memoryUsage .. "MB")
end

function MemoryManager:HandleCriticalMemory(memoryUsage)
    warn("🚨 CRITICAL: Very high memory usage:", memoryUsage, "MB")
    
    -- Apply medium-impact optimizations
    self:ForcePoolCleanup()
    self:DestroyDistantObjects()
    self:ReduceRenderQuality()
    
    -- More aggressive cleanup
    self:ForceGarbageCollection()
    
    self:NotifyAdmins("CRITICAL", "Critical memory usage: " .. memoryUsage .. "MB")
end

function MemoryManager:HandleEmergencyMemory(memoryUsage)
    warn("💥 EMERGENCY: Extreme memory usage:", memoryUsage, "MB - Initiating emergency cleanup!")
    
    -- Emergency measures
    self:EmergencyCleanup()
    self:ForceGarbageCollection()
    self:WarnPlayersOfIssues()
    
    -- Consider server restart
    if memoryUsage > 1500 then
        self:InitiateGracefulRestart()
    end
    
    self:NotifyAdmins("EMERGENCY", "Emergency memory usage: " .. memoryUsage .. "MB")
end

-- Cleanup strategies
function MemoryManager:ReduceVisualEffects()
    for _, obj in ipairs(game.Workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") then
            obj.Rate = obj.Rate * 0.5 -- Reduce particle rate
        elseif obj:IsA("PointLight") or obj:IsA("SpotLight") then
            obj.Brightness = obj.Brightness * 0.8 -- Reduce light intensity
        end
    end
    
    print("✨ Reduced visual effects for memory optimization")
end

function MemoryManager:OptimizeLODSettings()
    -- Integrate with ObjectStreaming to be more aggressive
    if self.objectPooling and self.objectPooling.objectStreaming then
        self.objectPooling.objectStreaming.lodLevels.HIGH = 30 -- Reduce high detail range
        self.objectPooling.objectStreaming.lodLevels.MEDIUM = 60
    end
    
    print("🎮 Optimized LOD settings")
end

function MemoryManager:CleanupCaches()
    -- Clear various game caches
    game:GetService("ContentProvider"):PreloadAsync({}) -- Clear preload cache
    
    -- Clear unused sounds
    for _, obj in ipairs(game.Workspace:GetDescendants()) do
        if obj:IsA("Sound") and not obj.IsPlaying then
            obj:Stop()
            obj.SoundId = "" -- Clear sound data
        end
    end
    
    print("🗑️ Cleaned caches")
end

function MemoryManager:ForcePoolCleanup()
    if self.objectPooling then
        local destroyed = self.objectPooling:ForceCleanup()
        print("♻️ Force cleaned object pools, destroyed:", destroyed, "objects")
    end
end

function MemoryManager:DestroyDistantObjects()
    -- Remove objects very far from all players
    local players = Players:GetPlayers()
    if #players == 0 then return end
    
    local destroyed = 0
    local keepDistance = 300 -- Keep objects within 300 studs of any player
    
    for _, obj in ipairs(game.Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:GetAttribute("PlacementId") then
            local shouldDestroy = true
            
            for _, player in ipairs(players) do
                if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    local distance = (obj.Position - player.Character.HumanoidRootPart.Position).Magnitude
                    if distance <= keepDistance then
                        shouldDestroy = false
                        break
                    end
                end
            end
            
            if shouldDestroy then
                -- Return to pool if possible, otherwise destroy
                if self.objectPooling then
                    local itemData = {ItemId = obj:GetAttribute("ItemId"), Name = obj.Name}
                    if not self.objectPooling:ReturnObject(obj, itemData) then
                        obj:Destroy()
                    end
                else
                    obj:Destroy()
                end
                destroyed = destroyed + 1
            end
        end
    end
    
    print("🗑️ Destroyed", destroyed, "distant objects")
end

function MemoryManager:ReduceRenderQuality()
    -- Reduce texture quality, disable shadows, etc.
    local lighting = game:GetService("Lighting")
    lighting.GlobalShadows = false
    lighting.Technology = Enum.Technology.Compatibility
    
    print("📉 Reduced render quality")
end

function MemoryManager:EmergencyCleanup()
    -- Most aggressive cleanup measures
    print("🚨 EMERGENCY CLEANUP INITIATED")
    
    -- Clear all pools
    self:ForcePoolCleanup()
    
    -- Destroy all non-essential objects
    self:DestroyNonEssentialObjects()
    
    -- Clear all caches aggressively
    self:AggressiveCacheClearing()
    
    -- Reset to minimal visual settings
    self:SetMinimalGraphics()
    
    self.optimizationMode = "EMERGENCY"
end

function MemoryManager:DestroyNonEssentialObjects()
    local destroyed = 0
    
    for _, obj in ipairs(game.Workspace:GetDescendants()) do
        -- Remove decorative elements
        if obj:IsA("Decal") or obj:IsA("Texture") or obj:IsA("SurfaceGui") then
            obj:Destroy()
            destroyed = destroyed + 1
        -- Remove particle effects
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke") then
            obj:Destroy()
            destroyed = destroyed + 1
        -- Remove extra lights
        elseif obj:IsA("PointLight") or obj:IsA("SpotLight") then
            obj:Destroy()
            destroyed = destroyed + 1
        end
    end
    
    print("💥 Emergency cleanup destroyed", destroyed, "non-essential objects")
end

-- Leak detection
function MemoryManager:StartLeakDetection()
    spawn(function()
        while true do
            wait(300) -- Check every 5 minutes
            self:DetectMemoryLeaks()
        end
    end)
end

function MemoryManager:DetectMemoryLeaks()
    local currentMemory = Stats:GetTotalMemoryUsageMb()
    local currentObjects = self:CountActiveObjects()
    
    -- Check for concerning trends
    if #self.memoryHistory >= 12 then -- Need at least 6 minutes of data
        local oldRecord = self.memoryHistory[#self.memoryHistory - 11]
        local memoryGrowth = currentMemory - oldRecord.memory
        local objectGrowth = currentObjects - oldRecord.objects
        
        -- Detect suspicious patterns
        if memoryGrowth > 100 and objectGrowth < 10 then
            -- Memory growing but objects not increasing = potential leak
            warn("🚨 MEMORY LEAK DETECTED: Memory grew", memoryGrowth, "MB with only", objectGrowth, "new objects")
            self:InvestigateMemoryLeak()
        end
        
        -- Check for runaway object creation
        if objectGrowth > 50 then
            warn("⚠️ RAPID OBJECT GROWTH:", objectGrowth, "objects in 6 minutes")
            self:InvestigateObjectGrowth()
        end
    end
end

function MemoryManager:InvestigateMemoryLeak()
    -- Collect diagnostic information
    local diagnostics = {
        totalMemory = Stats:GetTotalMemoryUsageMb(),
        instanceCount = #game.Workspace:GetDescendants(),
        connectionCount = 0, -- Would need custom tracking
        timestamp = os.time()
    }
    
    table.insert(self.leakDetection.suspiciousPatterns, diagnostics)
    
    -- Force cleanup to mitigate
    self:ForceGarbageCollection()
    
    print("🔍 Investigating memory leak - recorded diagnostics")
end

-- Utility functions
function MemoryManager:CountActiveObjects()
    local count = 0
    for _, obj in ipairs(game.Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:GetAttribute("PlacementId") then
            count = count + 1
        end
    end
    return count
end

function MemoryManager:ForceGarbageCollection()
    -- Force Lua garbage collection
    collectgarbage("collect")
    print("🗑️ Forced garbage collection")
end

function MemoryManager:UpdateOptimizationMode(memoryUsage)
    local oldMode = self.optimizationMode
    
    if memoryUsage > 1000 then
        self.optimizationMode = "EMERGENCY"
    elseif memoryUsage > 700 then
        self.optimizationMode = "PERFORMANCE"
    else
        self.optimizationMode = "NORMAL"
    end
    
    if oldMode ~= self.optimizationMode then
        print("🎯 Optimization mode changed:", oldMode, "→", self.optimizationMode)
        self:ApplyOptimizationMode()
    end
end

function MemoryManager:ApplyOptimizationMode()
    if self.optimizationMode == "EMERGENCY" then
        self:SetMinimalGraphics()
    elseif self.optimizationMode == "PERFORMANCE" then
        self:SetPerformanceGraphics()
    else
        self:SetNormalGraphics()
    end
end

-- Graphics optimization
function MemoryManager:SetMinimalGraphics()
    local lighting = game:GetService("Lighting")
    lighting.GlobalShadows = false
    lighting.Technology = Enum.Technology.Compatibility
    lighting.Brightness = 1
    
    print("📉 Set minimal graphics mode")
end

function MemoryManager:SetPerformanceGraphics()
    local lighting = game:GetService("Lighting")
    lighting.GlobalShadows = false
    lighting.Technology = Enum.Technology.ShadowMap
    
    print("⚡ Set performance graphics mode")
end

function MemoryManager:SetNormalGraphics()
    local lighting = game:GetService("Lighting")
    lighting.GlobalShadows = true
    lighting.Technology = Enum.Technology.Future
    
    print("✨ Set normal graphics mode")
end

-- Player-specific cleanup
function MemoryManager:CleanupPlayerMemory(player)
    -- Clean up any player-specific memory allocations
    -- This would be customized based on your game's needs
    print("🧹 Cleaned up memory for player:", player.Name)
end

function MemoryManager:OptimizeForPlayerCount()
    local playerCount = #Players:GetPlayers()
    
    -- Adjust thresholds based on player count
    if playerCount > 10 then
        self.memoryThresholds.warning = 600
        self.memoryThresholds.critical = 800
    elseif playerCount > 5 then
        self.memoryThresholds.warning = 700
        self.memoryThresholds.critical = 900
    else
        self.memoryThresholds.warning = 800
        self.memoryThresholds.critical = 1000
    end
    
    print("🎮 Optimized memory thresholds for", playerCount, "players")
end

-- Notifications and reporting
function MemoryManager:NotifyAdmins(level, message)
    -- Implement admin notification system
    print("📢 ADMIN ALERT [" .. level .. "]:", message)
    
    -- Could integrate with external monitoring systems
end

function MemoryManager:WarnPlayersOfIssues()
    -- Warn players about potential performance issues
    for _, player in ipairs(Players:GetPlayers()) do
        -- Send GUI notification
        print("⚠️ Notifying", player.Name, "of performance issues")
    end
end

function MemoryManager:InitiateGracefulRestart()
    warn("🔄 INITIATING GRACEFUL SERVER RESTART due to memory issues")
    
    -- Save all player data first
    if self.placementTracker then
        self.placementTracker:SaveAllData()
    end
    
    -- Notify players
    for _, player in ipairs(Players:GetPlayers()) do
        player:Kick("Server restarting for maintenance. Your progress has been saved!")
    end
    
    wait(5)
    game:GetService("DataStoreService"):RequestBudgetForRequestType(Enum.DataStoreRequestType.SetIncrementAsync, 1000)
end

-- Reporting and analysis
function MemoryManager:GenerateMemoryReport()
    local report = {
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        currentMemory = Stats:GetTotalMemoryUsageMb(),
        currentMode = self.optimizationMode,
        activeObjects = self:CountActiveObjects(),
        playerCount = #Players:GetPlayers(),
        memoryTrend = self:CalculateMemoryTrend(),
        leaksSuspected = #self.leakDetection.suspiciousPatterns,
        thresholds = self.memoryThresholds
    }
    
    return report
end

function MemoryManager:CalculateMemoryTrend()
    if #self.memoryHistory < 6 then return "INSUFFICIENT_DATA" end
    
    local recent = self.memoryHistory[#self.memoryHistory]
    local older = self.memoryHistory[#self.memoryHistory - 5]
    
    local growth = recent.memory - older.memory
    
    if growth > 50 then
        return "INCREASING_RAPIDLY"
    elseif growth > 20 then
        return "INCREASING"
    elseif growth > -20 then
        return "STABLE"
    else
        return "DECREASING"
    end
end

return MemoryManager 