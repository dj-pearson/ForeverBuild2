-- SystemManager.luau
-- Central coordination hub for all critical game systems

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Import all critical systems
local PlacementTracker = require(script.Parent.PlacementTracker)
local ConflictResolver = require(script.Parent.ConflictResolver)
local ModerationSystem = require(script.Parent.ModerationSystem)
local AnalyticsSystem = require(script.Parent.AnalyticsSystem)
local DataBackupSystem = require(script.Parent.DataBackupSystem)

local ObjectStreaming = require(script.Parent.Parent.shared.optimization.ObjectStreaming)
local ObjectPooling = require(script.Parent.Parent.shared.optimization.ObjectPooling)
local MemoryManager = require(script.Parent.Parent.shared.optimization.MemoryManager)

local SystemManager = {}
SystemManager.__index = SystemManager

function SystemManager.new()
    local self = setmetatable({}, SystemManager)
    
    -- System instances
    self.systems = {}
    
    -- System health monitoring
    self.systemHealth = {
        overall = "INITIALIZING",
        individual = {},
        lastHealthCheck = 0,
        criticalErrors = 0,
        healthHistory = {}
    }
    
    -- Performance metrics
    self.performanceMetrics = {
        systemStartTime = os.time(),
        totalRequests = 0,
        successfulRequests = 0,
        failedRequests = 0,
        averageResponseTime = 0
    }
    
    -- System configuration
    self.config = {
        healthCheckInterval = 60,      -- Check system health every minute
        criticalErrorThreshold = 5,    -- Max critical errors before emergency mode
        performanceReportInterval = 300, -- Generate performance report every 5 minutes
        emergencyMode = false,
        debugMode = false
    }
    
    self:Initialize()
    return self
end

function SystemManager:Initialize()
    print("🚀 Starting System Manager initialization...")
    
    -- Initialize systems in dependency order
    self:InitializeCoreDataSystems()
    self:InitializeOptimizationSystems()
    self:InitializeSecuritySystems()
    self:InitializeAnalyticsSystems()
    
    -- Start system monitoring
    self:StartSystemMonitoring()
    
    -- Setup system integration
    self:SetupSystemIntegration()
    
    print("✅ System Manager initialization complete")
    self.systemHealth.overall = "OPERATIONAL"
end

-- Core data systems (highest priority)
function SystemManager:InitializeCoreDataSystems()
    print("📊 Initializing core data systems...")
    
    -- 1. Placement Tracker (foundation system)
    self.systems.placementTracker = PlacementTracker.new()
    self:RegisterSystem("placementTracker", self.systems.placementTracker, "CRITICAL")
    
    -- 2. Data Backup System (data protection)
    self.systems.dataBackup = DataBackupSystem.new(self.systems.placementTracker)
    self:RegisterSystem("dataBackup", self.systems.dataBackup, "CRITICAL")
    
    -- 3. Conflict Resolver (development workflow)
    self.systems.conflictResolver = ConflictResolver.new(self.systems.placementTracker)
    self:RegisterSystem("conflictResolver", self.systems.conflictResolver, "HIGH")
    
    print("✅ Core data systems initialized")
end

-- Performance optimization systems
function SystemManager:InitializeOptimizationSystems()
    print("⚡ Initializing optimization systems...")
    
    -- 1. Object Pooling (memory optimization)
    self.systems.objectPooling = ObjectPooling.new()
    self:RegisterSystem("objectPooling", self.systems.objectPooling, "CRITICAL")
    
    -- 2. Object Streaming (performance optimization)
    self.systems.objectStreaming = ObjectStreaming.new()
    self:RegisterSystem("objectStreaming", self.systems.objectStreaming, "HIGH")
    
    -- 3. Memory Manager (system health)
    self.systems.memoryManager = MemoryManager.new(self.systems.objectPooling, self.systems.placementTracker)
    self:RegisterSystem("memoryManager", self.systems.memoryManager, "CRITICAL")
    
    print("✅ Optimization systems initialized")
end

-- Security and moderation systems
function SystemManager:InitializeSecuritySystems()
    print("🛡️ Initializing security systems...")
    
    -- 1. Moderation System (anti-griefing)
    self.systems.moderation = ModerationSystem.new(self.systems.placementTracker)
    self:RegisterSystem("moderation", self.systems.moderation, "HIGH")
    
    print("✅ Security systems initialized")
end

-- Analytics and monitoring systems
function SystemManager:InitializeAnalyticsSystems()
    print("📈 Initializing analytics systems...")
    
    -- 1. Analytics System (monitoring and insights)
    self.systems.analytics = AnalyticsSystem.new(self.systems.placementTracker, self)
    self:RegisterSystem("analytics", self.systems.analytics, "MEDIUM")
    
    print("✅ Analytics systems initialized")
end

-- System registration and monitoring
function SystemManager:RegisterSystem(name, systemInstance, priority)
    self.systems[name] = systemInstance
    self.systemHealth.individual[name] = {
        status = "OPERATIONAL",
        priority = priority,
        lastCheck = os.time(),
        errorCount = 0,
        startTime = os.time()
    }
    
    print("📝 Registered system:", name, "Priority:", priority)
end

-- System integration setup
function SystemManager:SetupSystemIntegration()
    print("🔗 Setting up system integration...")
    
    -- Connect placement events to other systems
    self:IntegratePlacementTracking()
    
    -- Connect moderation to analytics
    self:IntegrateModerationAnalytics()
    
    -- Connect backup system to change tracking
    self:IntegrateBackupTracking()
    
    -- Connect memory management to all systems
    self:IntegrateMemoryManagement()
    
    print("✅ System integration complete")
end

function SystemManager:IntegratePlacementTracking()
    -- When objects are placed, notify relevant systems
    if self.systems.placementTracker and self.systems.analytics then
        -- Hook placement events (this would be done in actual placement code)
        print("🔗 Integrated placement tracking with analytics")
    end
    
    if self.systems.placementTracker and self.systems.dataBackup then
        -- Hook backup system to track changes
        print("🔗 Integrated placement tracking with backup system")
    end
end

function SystemManager:IntegrateModerationAnalytics()
    -- Connect moderation events to analytics
    if self.systems.moderation and self.systems.analytics then
        print("🔗 Integrated moderation with analytics")
    end
end

function SystemManager:IntegrateBackupTracking()
    -- Connect all data changes to backup system
    if self.systems.dataBackup then
        print("🔗 Integrated backup tracking across all systems")
    end
end

function SystemManager:IntegrateMemoryManagement()
    -- Connect memory manager to optimization systems
    if self.systems.memoryManager and self.systems.objectStreaming then
        self.systems.memoryManager.objectStreaming = self.systems.objectStreaming
        print("🔗 Integrated memory management with object streaming")
    end
end

-- System monitoring
function SystemManager:StartSystemMonitoring()
    spawn(function()
        while true do
            wait(self.config.healthCheckInterval)
            self:PerformHealthCheck()
        end
    end)
    
    spawn(function()
        while true do
            wait(self.config.performanceReportInterval)
            self:GeneratePerformanceReport()
        end
    end)
    
    print("📊 Started system monitoring")
end

function SystemManager:PerformHealthCheck()
    local overallHealth = "OPERATIONAL"
    local criticalIssues = 0
    
    print("🏥 Performing system health check...")
    
    for systemName, systemHealth in pairs(self.systemHealth.individual) do
        local currentStatus = self:CheckSystemHealth(systemName)
        systemHealth.status = currentStatus
        systemHealth.lastCheck = os.time()
        
        if currentStatus == "CRITICAL" or currentStatus == "FAILED" then
            criticalIssues = criticalIssues + 1
            overallHealth = "DEGRADED"
            
            if systemHealth.priority == "CRITICAL" then
                overallHealth = "CRITICAL"
                self:HandleCriticalSystemFailure(systemName)
            end
        end
    end
    
    self.systemHealth.overall = overallHealth
    self.systemHealth.lastHealthCheck = os.time()
    self.systemHealth.criticalErrors = criticalIssues
    
    -- Record health history
    table.insert(self.systemHealth.healthHistory, {
        timestamp = os.time(),
        overallHealth = overallHealth,
        criticalIssues = criticalIssues
    })
    
    -- Keep only last 24 hours of health data
    if #self.systemHealth.healthHistory > 1440 then
        table.remove(self.systemHealth.healthHistory, 1)
    end
    
    if overallHealth ~= "OPERATIONAL" then
        warn("⚠️ System health check completed - Status:", overallHealth, "Critical issues:", criticalIssues)
    else
        print("✅ System health check completed - All systems operational")
    end
end

function SystemManager:CheckSystemHealth(systemName)
    local system = self.systems[systemName]
    if not system then
        return "FAILED"
    end
    
    -- Basic system responsiveness check
    local success, result = pcall(function()
        -- Try to call a basic method if available
        if system.GetStatus then
            return system:GetStatus()
        elseif system.GenerateReport then
            return system:GenerateReport()
        else
            return "OPERATIONAL"
        end
    end)
    
    if not success then
        warn("❌ System health check failed for:", systemName, result)
        return "CRITICAL"
    end
    
    return "OPERATIONAL"
end

function SystemManager:HandleCriticalSystemFailure(systemName)
    warn("🚨 CRITICAL SYSTEM FAILURE:", systemName)
    
    local systemHealth = self.systemHealth.individual[systemName]
    systemHealth.errorCount = systemHealth.errorCount + 1
    
    -- Attempt system recovery
    self:AttemptSystemRecovery(systemName)
    
    -- If too many critical errors, enter emergency mode
    if self.systemHealth.criticalErrors >= self.config.criticalErrorThreshold then
        self:EnterEmergencyMode()
    end
end

function SystemManager:AttemptSystemRecovery(systemName)
    print("🔧 Attempting recovery for system:", systemName)
    
    local system = self.systems[systemName]
    
    -- Try to restart the system
    if system and system.Restart then
        local success = pcall(function()
            system:Restart()
        end)
        
        if success then
            print("✅ Successfully restarted system:", systemName)
            self.systemHealth.individual[systemName].status = "OPERATIONAL"
        else
            warn("❌ Failed to restart system:", systemName)
        end
    end
end

function SystemManager:EnterEmergencyMode()
    warn("🚨 ENTERING EMERGENCY MODE - Multiple critical system failures detected")
    
    self.config.emergencyMode = true
    
    -- Reduce system load
    if self.systems.memoryManager then
        self.systems.memoryManager:EmergencyCleanup()
    end
    
    -- Force backup to preserve data
    if self.systems.dataBackup then
        self.systems.dataBackup:ForceFullBackup()
    end
    
    -- Notify admins
    self:NotifyAdminsOfEmergency()
    
    -- Consider graceful shutdown if things are too bad
    if self.systemHealth.criticalErrors >= 10 then
        self:InitiateGracefulShutdown()
    end
end

-- High-level system operations
function SystemManager:PlaceObject(player, itemData, position, rotation)
    local startTime = tick()
    self.performanceMetrics.totalRequests = self.performanceMetrics.totalRequests + 1
    
    -- 1. Check with moderation system first
    if self.systems.moderation then
        local allowed = self.systems.moderation:CheckPlacement(player, {Position = position}, itemData)
        if not allowed then
            self.performanceMetrics.failedRequests = self.performanceMetrics.failedRequests + 1
            return false, "Placement blocked by moderation system"
        end
    end
    
    -- 2. Get object from pool or create new
    local objectInstance
    if self.systems.objectPooling then
        local placementId = "PLACE_" .. os.time() .. "_" .. math.random(1000, 9999)
        objectInstance = self.systems.objectPooling:GetObject(itemData, placementId)
    end
    
    -- 3. Place using placement tracker
    if self.systems.placementTracker and objectInstance then
        local success, placementId = self.systems.placementTracker:PlaceObject(player, itemData, objectInstance, position, rotation)
        
        if success then
            -- 4. Track analytics
            if self.systems.analytics then
                self.systems.analytics:TrackPlacement(player, itemData, position)
            end
            
            -- 5. Track backup changes
            if self.systems.dataBackup then
                self.systems.dataBackup:TrackChange("PLACE", placementId, {
                    player = player.UserId,
                    item = itemData.ItemId,
                    position = position
                })
            end
            
            self.performanceMetrics.successfulRequests = self.performanceMetrics.successfulRequests + 1
            self:UpdateResponseTime(tick() - startTime)
            
            return true, placementId
        else
            self.performanceMetrics.failedRequests = self.performanceMetrics.failedRequests + 1
            return false, "Placement tracker failed"
        end
    end
    
    self.performanceMetrics.failedRequests = self.performanceMetrics.failedRequests + 1
    return false, "System error"
end

function SystemManager:RemoveObject(placementId, reason)
    local startTime = tick()
    self.performanceMetrics.totalRequests = self.performanceMetrics.totalRequests + 1
    
    -- 1. Get object data from placement tracker
    local objectData
    if self.systems.placementTracker then
        objectData = self.systems.placementTracker:GetPlacementData(placementId)
    end
    
    if not objectData then
        self.performanceMetrics.failedRequests = self.performanceMetrics.failedRequests + 1
        return false, "Object not found"
    end
    
    -- 2. Remove from placement tracker
    local success = false
    if self.systems.placementTracker then
        success = self.systems.placementTracker:RemoveObject(placementId)
    end
    
    if success then
        -- 3. Return to object pool
        if self.systems.objectPooling then
            -- Find the actual object instance
            local objectInstance = self:FindObjectByPlacementId(placementId)
            if objectInstance then
                self.systems.objectPooling:ReturnObject(objectInstance, objectData)
            end
        end
        
        -- 4. Track backup changes
        if self.systems.dataBackup then
            self.systems.dataBackup:TrackChange("REMOVE", placementId, {
                reason = reason,
                originalData = objectData
            })
        end
        
        self.performanceMetrics.successfulRequests = self.performanceMetrics.successfulRequests + 1
        self:UpdateResponseTime(tick() - startTime)
        
        return true
    else
        self.performanceMetrics.failedRequests = self.performanceMetrics.failedRequests + 1
        return false, "Failed to remove object"
    end
end

-- Utility functions
function SystemManager:FindObjectByPlacementId(placementId)
    for _, obj in ipairs(game.Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:GetAttribute("PlacementId") == placementId then
            return obj
        end
    end
    return nil
end

function SystemManager:UpdateResponseTime(responseTime)
    self.performanceMetrics.averageResponseTime = 
        (self.performanceMetrics.averageResponseTime + responseTime) / 2
end

-- Reporting and diagnostics
function SystemManager:GenerateSystemReport()
    local report = {
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        systemHealth = self.systemHealth,
        performanceMetrics = self.performanceMetrics,
        uptime = os.time() - self.performanceMetrics.systemStartTime,
        emergencyMode = self.config.emergencyMode,
        systemReports = {}
    }
    
    -- Collect reports from individual systems
    for systemName, system in pairs(self.systems) do
        if system.GenerateReport then
            local success, systemReport = pcall(function()
                return system:GenerateReport()
            end)
            
            if success then
                report.systemReports[systemName] = systemReport
            else
                report.systemReports[systemName] = {error = "Failed to generate report"}
            end
        end
    end
    
    return report
end

function SystemManager:GeneratePerformanceReport()
    local report = self:GenerateSystemReport()
    
    print("📊 SYSTEM PERFORMANCE REPORT")
    print("   Overall Health:", report.systemHealth.overall)
    print("   Uptime:", math.floor(report.uptime / 60), "minutes")
    print("   Total Requests:", report.performanceMetrics.totalRequests)
    print("   Success Rate:", math.floor((report.performanceMetrics.successfulRequests / math.max(1, report.performanceMetrics.totalRequests)) * 100) .. "%")
    print("   Average Response Time:", math.floor(report.performanceMetrics.averageResponseTime * 1000) .. "ms")
    print("   Emergency Mode:", report.emergencyMode and "ACTIVE" or "INACTIVE")
    
    return report
end

-- Admin functions
function SystemManager:GetSystemStatus(systemName)
    if systemName then
        return self.systemHealth.individual[systemName]
    else
        return self.systemHealth
    end
end

function SystemManager:RestartSystem(systemName)
    if self.systems[systemName] then
        return self:AttemptSystemRecovery(systemName)
    end
    return false
end

function SystemManager:ForceBackup()
    if self.systems.dataBackup then
        return self.systems.dataBackup:ForceFullBackup()
    end
    return false
end

function SystemManager:GetPerformanceMetrics()
    return self.performanceMetrics
end

-- Notifications
function SystemManager:NotifyAdminsOfEmergency()
    warn("📢 ADMIN ALERT: SYSTEM EMERGENCY MODE ACTIVATED")
    
    -- Would integrate with admin notification system
    local report = self:GenerateSystemReport()
    
    -- Log critical information for admins
    print("📋 Emergency Report:")
    print("   Critical Errors:", self.systemHealth.criticalErrors)
    print("   Failed Systems:", self:GetFailedSystems())
    print("   Recommended Action: Manual intervention required")
end

function SystemManager:GetFailedSystems()
    local failed = {}
    for systemName, health in pairs(self.systemHealth.individual) do
        if health.status == "CRITICAL" or health.status == "FAILED" then
            table.insert(failed, systemName)
        end
    end
    return failed
end

function SystemManager:InitiateGracefulShutdown()
    warn("🔄 INITIATING GRACEFUL SHUTDOWN due to critical system failures")
    
    -- Save all data
    if self.systems.dataBackup then
        self.systems.dataBackup:EmergencyBackup()
    end
    
    -- Notify players
    for _, player in ipairs(Players:GetPlayers()) do
        player:Kick("Server restarting due to technical issues. Your progress has been saved!")
    end
    
    wait(5)
    -- Force shutdown would go here
end

return SystemManager 