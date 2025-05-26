-- GameHealthMonitor.luau
-- Real-time game health monitoring and alerting system

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")

local ProductionConfig = require(script.Parent.ProductionConfig)

local GameHealthMonitor = {}
GameHealthMonitor.__index = GameHealthMonitor

function GameHealthMonitor.new(systemManager)
    local self = setmetatable({}, GameHealthMonitor)
    
    self.systemManager = systemManager
    self.config = ProductionConfig.GetConfig()
    
    -- Health metrics tracking
    self.metrics = {
        performance = {
            fps = 0,
            memory = 0,
            ping = 0,
            serverLoad = 0,
            responseTime = 0
        },
        players = {
            current = 0,
            peak = 0,
            joinRate = 0,
            leaveRate = 0,
            averageSessionTime = 0
        },
        systems = {
            operational = 0,
            degraded = 0,
            critical = 0,
            offline = 0
        },
        security = {
            violations = 0,
            suspiciousPlayers = 0,
            exploitAttempts = 0,
            bannedToday = 0
        },
        economy = {
            totalCoins = 0,
            coinsSpent = 0,
            itemsPurchased = 0,
            inflationRate = 0
        }
    }
    
    -- Alert thresholds
    self.alertThresholds = {
        performance = {
            lowFPS = 20,
            highMemory = self.config.performance.memoryCriticalThreshold,
            highPing = 300,
            highServerLoad = 80
        },
        players = {
            highJoinRate = 10, -- players per minute
            highLeaveRate = 8,
            lowSessionTime = 120 -- seconds
        },
        security = {
            highViolationRate = 5, -- per minute
            highExploitRate = 3
        }
    }
    
    -- Alert history
    self.alertHistory = {}
    self.maxAlertHistory = 100
    
    -- Monitoring intervals
    self.intervals = {
        metricsUpdate = 5,    -- Update metrics every 5 seconds
        healthCheck = 30,     -- Health check every 30 seconds
        reportGeneration = 300 -- Generate reports every 5 minutes
    }
    
    -- Player session tracking
    self.playerSessions = {}
    
    self:Initialize()
    return self
end

function GameHealthMonitor:Initialize()
    print("📊 Initializing Game Health Monitor...")
    
    -- Start monitoring systems
    self:StartMetricsCollection()
    self:StartHealthChecks()
    self:StartReportGeneration()
    self:SetupPlayerTracking()
    
    print("✅ Game Health Monitor initialized")
end

-- Metrics collection
function GameHealthMonitor:StartMetricsCollection()
    spawn(function()
        while true do
            self:UpdatePerformanceMetrics()
            self:UpdatePlayerMetrics()
            self:UpdateSystemMetrics()
            self:UpdateSecurityMetrics()
            self:UpdateEconomyMetrics()
            
            wait(self.intervals.metricsUpdate)
        end
    end)
end

function GameHealthMonitor:UpdatePerformanceMetrics()
    -- FPS from server heartbeat
    self.metrics.performance.fps = math.floor(1 / RunService.Heartbeat:Wait())
    
    -- Memory usage
    local memory = Stats:GetTotalMemoryUsageMb()
    self.metrics.performance.memory = math.floor(memory)
    
    -- Server load (approximation)
    local startTime = tick()
    wait(0.01)
    local endTime = tick()
    local actualWait = endTime - startTime
    self.metrics.performance.serverLoad = math.min(100, math.floor((actualWait / 0.01) * 100))
    
    -- Check for performance alerts
    self:CheckPerformanceAlerts()
end

function GameHealthMonitor:UpdatePlayerMetrics()
    local currentPlayers = #Players:GetPlayers()
    
    self.metrics.players.current = currentPlayers
    
    if currentPlayers > self.metrics.players.peak then
        self.metrics.players.peak = currentPlayers
    end
    
    -- Calculate session times
    local totalSessionTime = 0
    local validSessions = 0
    
    for userId, sessionData in pairs(self.playerSessions) do
        if sessionData.joinTime then
            local sessionTime = os.time() - sessionData.joinTime
            totalSessionTime = totalSessionTime + sessionTime
            validSessions = validSessions + 1
        end
    end
    
    if validSessions > 0 then
        self.metrics.players.averageSessionTime = math.floor(totalSessionTime / validSessions)
    end
    
    -- Check for player alerts
    self:CheckPlayerAlerts()
end

function GameHealthMonitor:UpdateSystemMetrics()
    if not self.systemManager then return end
    
    local systemStatus = self.systemManager:GetSystemStatus()
    
    self.metrics.systems.operational = 0
    self.metrics.systems.degraded = 0
    self.metrics.systems.critical = 0
    self.metrics.systems.offline = 0
    
    for _, health in pairs(systemStatus.individual) do
        if health.status == "OPERATIONAL" then
            self.metrics.systems.operational = self.metrics.systems.operational + 1
        elseif health.status == "DEGRADED" then
            self.metrics.systems.degraded = self.metrics.systems.degraded + 1
        elseif health.status == "CRITICAL" then
            self.metrics.systems.critical = self.metrics.systems.critical + 1
        else
            self.metrics.systems.offline = self.metrics.systems.offline + 1
        end
    end
end

function GameHealthMonitor:UpdateSecurityMetrics()
    if not self.systemManager.systems.antiExploit then return end
    
    local securityReport = self.systemManager.systems.antiExploit:GenerateSecurityReport()
    
    self.metrics.security.violations = securityReport.totalViolations
    self.metrics.security.suspiciousPlayers = securityReport.suspiciousPlayers
    self.metrics.security.exploitAttempts = securityReport.severityBreakdown.severe
    
    -- Check for security alerts
    self:CheckSecurityAlerts()
end

function GameHealthMonitor:UpdateEconomyMetrics()
    if not self.systemManager.systems.analytics then return end
    
    -- This would integrate with your economy system
    -- For now, placeholder values
    self.metrics.economy.totalCoins = 0
    self.metrics.economy.coinsSpent = 0
    self.metrics.economy.itemsPurchased = 0
    self.metrics.economy.inflationRate = 0
end

-- Alert system
function GameHealthMonitor:CheckPerformanceAlerts()
    local perf = self.metrics.performance
    local thresholds = self.alertThresholds.performance
    
    if perf.fps < thresholds.lowFPS then
        self:TriggerAlert("PERFORMANCE", "LOW_FPS", "FPS dropped to " .. perf.fps, "HIGH")
    end
    
    if perf.memory > thresholds.highMemory then
        self:TriggerAlert("PERFORMANCE", "HIGH_MEMORY", "Memory usage: " .. perf.memory .. "MB", "CRITICAL")
    end
    
    if perf.serverLoad > thresholds.highServerLoad then
        self:TriggerAlert("PERFORMANCE", "HIGH_LOAD", "Server load: " .. perf.serverLoad .. "%", "HIGH")
    end
end

function GameHealthMonitor:CheckPlayerAlerts()
    local players = self.metrics.players
    local thresholds = self.alertThresholds.players
    
    if players.averageSessionTime < thresholds.lowSessionTime then
        self:TriggerAlert("PLAYERS", "LOW_RETENTION", "Average session: " .. players.averageSessionTime .. "s", "MEDIUM")
    end
end

function GameHealthMonitor:CheckSecurityAlerts()
    local security = self.metrics.security
    local thresholds = self.alertThresholds.security
    
    if security.exploitAttempts > thresholds.highExploitRate then
        self:TriggerAlert("SECURITY", "HIGH_EXPLOITS", "Exploit attempts: " .. security.exploitAttempts, "CRITICAL")
    end
    
    if security.violations > thresholds.highViolationRate then
        self:TriggerAlert("SECURITY", "HIGH_VIOLATIONS", "Violations: " .. security.violations, "HIGH")
    end
end

function GameHealthMonitor:TriggerAlert(category, type, message, severity)
    local alert = {
        timestamp = os.time(),
        category = category,
        type = type,
        message = message,
        severity = severity,
        resolved = false
    }
    
    -- Add to history
    table.insert(self.alertHistory, alert)
    
    -- Keep history manageable
    if #self.alertHistory > self.maxAlertHistory then
        table.remove(self.alertHistory, 1)
    end
    
    -- Log alert with appropriate level
    local logFunction = severity == "CRITICAL" and warn or print
    logFunction("🚨 [" .. severity .. "] " .. category .. " - " .. type .. ": " .. message)
    
    -- Notify admins if configured
    self:NotifyAdmins(alert)
    
    -- Take automated action if needed
    self:HandleAutomaticResponse(alert)
end

function GameHealthMonitor:NotifyAdmins(alert)
    -- Notify online admins
    for _, player in ipairs(Players:GetPlayers()) do
        if ProductionConfig.IsAdmin(player.UserId) then
            -- This would send an in-game notification
            print("📢 [ADMIN ALERT] " .. player.Name .. ": " .. alert.message)
        end
    end
end

function GameHealthMonitor:HandleAutomaticResponse(alert)
    -- Automatic responses to certain alerts
    if alert.category == "PERFORMANCE" and alert.type == "HIGH_MEMORY" then
        if self.systemManager.systems.memoryManager then
            print("🤖 Auto-response: Triggering memory cleanup")
            self.systemManager.systems.memoryManager:EmergencyCleanup()
        end
    end
    
    if alert.category == "SECURITY" and alert.type == "HIGH_EXPLOITS" then
        if self.systemManager.config then
            print("🤖 Auto-response: Enabling strict security mode")
            self.systemManager.config.emergencyMode = true
        end
    end
end

-- Player session tracking
function GameHealthMonitor:SetupPlayerTracking()
    Players.PlayerAdded:Connect(function(player)
        self.playerSessions[player.UserId] = {
            joinTime = os.time(),
            leaveTime = nil
        }
        
        self.metrics.players.joinRate = self.metrics.players.joinRate + 1
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        if self.playerSessions[player.UserId] then
            self.playerSessions[player.UserId].leaveTime = os.time()
            self.metrics.players.leaveRate = self.metrics.players.leaveRate + 1
        end
    end)
end

-- Health checks
function GameHealthMonitor:StartHealthChecks()
    spawn(function()
        while true do
            self:PerformHealthCheck()
            wait(self.intervals.healthCheck)
        end
    end)
end

function GameHealthMonitor:PerformHealthCheck()
    local healthStatus = {
        overall = "HEALTHY",
        systems = self:CheckSystemsHealth(),
        performance = self:CheckPerformanceHealth(),
        security = self:CheckSecurityHealth(),
        timestamp = os.time()
    }
    
    -- Determine overall health
    if healthStatus.performance == "CRITICAL" or healthStatus.security == "CRITICAL" then
        healthStatus.overall = "CRITICAL"
    elseif healthStatus.performance == "DEGRADED" or healthStatus.security == "DEGRADED" then
        healthStatus.overall = "DEGRADED"
    end
    
    return healthStatus
end

function GameHealthMonitor:CheckSystemsHealth()
    local systems = self.metrics.systems
    
    if systems.critical > 0 or systems.offline > 0 then
        return "CRITICAL"
    elseif systems.degraded > 0 then
        return "DEGRADED"
    else
        return "HEALTHY"
    end
end

function GameHealthMonitor:CheckPerformanceHealth()
    local perf = self.metrics.performance
    
    if perf.fps < 15 or perf.memory > self.alertThresholds.performance.highMemory then
        return "CRITICAL"
    elseif perf.fps < 25 or perf.memory > (self.alertThresholds.performance.highMemory * 0.8) then
        return "DEGRADED"
    else
        return "HEALTHY"
    end
end

function GameHealthMonitor:CheckSecurityHealth()
    local security = self.metrics.security
    
    if security.exploitAttempts > 10 then
        return "CRITICAL"
    elseif security.exploitAttempts > 5 then
        return "DEGRADED"
    else
        return "HEALTHY"
    end
end

-- Report generation
function GameHealthMonitor:StartReportGeneration()
    spawn(function()
        while true do
            self:GenerateHealthReport()
            wait(self.intervals.reportGeneration)
        end
    end)
end

function GameHealthMonitor:GenerateHealthReport()
    local report = {
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        environment = self.config.environment,
        metrics = self.metrics,
        alerts = {
            total = #self.alertHistory,
            recent = self:GetRecentAlerts(10),
            unresolved = self:GetUnresolvedAlerts()
        },
        health = self:PerformHealthCheck()
    }
    
    -- Log summary if in debug mode
    if self.config.performance.debugMode then
        self:LogHealthSummary(report)
    end
    
    return report
end

function GameHealthMonitor:LogHealthSummary(report)
    print("📊 HEALTH SUMMARY (" .. report.timestamp .. ")")
    print("Overall:", report.health.overall)
    print("Players:", report.metrics.players.current, "FPS:", report.metrics.performance.fps, "Memory:", report.metrics.performance.memory .. "MB")
    print("Systems:", report.metrics.systems.operational, "operational,", report.metrics.systems.critical, "critical")
    print("Security:", report.metrics.security.violations, "violations,", report.metrics.security.exploitAttempts, "exploits")
    
    if #report.alerts.unresolved > 0 then
        print("Unresolved alerts:", #report.alerts.unresolved)
    end
end

-- Alert management
function GameHealthMonitor:GetRecentAlerts(count)
    count = count or 10
    local recent = {}
    
    for i = math.max(1, #self.alertHistory - count + 1), #self.alertHistory do
        table.insert(recent, self.alertHistory[i])
    end
    
    return recent
end

function GameHealthMonitor:GetUnresolvedAlerts()
    local unresolved = {}
    
    for _, alert in ipairs(self.alertHistory) do
        if not alert.resolved then
            table.insert(unresolved, alert)
        end
    end
    
    return unresolved
end

function GameHealthMonitor:ResolveAlert(alertIndex)
    if self.alertHistory[alertIndex] then
        self.alertHistory[alertIndex].resolved = true
        self.alertHistory[alertIndex].resolvedAt = os.time()
        return true
    end
    return false
end

-- Public API for admin tools
function GameHealthMonitor:GetCurrentMetrics()
    return self.metrics
end

function GameHealthMonitor:GetHealthStatus()
    return self:PerformHealthCheck()
end

function GameHealthMonitor:GetAlertSummary()
    return {
        total = #self.alertHistory,
        unresolved = #self:GetUnresolvedAlerts(),
        recent = self:GetRecentAlerts(5)
    }
end

-- Emergency procedures
function GameHealthMonitor:DeclareEmergency(reason)
    self:TriggerAlert("SYSTEM", "EMERGENCY_DECLARED", "Emergency declared: " .. reason, "CRITICAL")
    
    -- Enable emergency mode
    if self.systemManager then
        self.systemManager:EnterEmergencyMode()
    end
    
    ProductionConfig.SetEmergencyOverride("enableEmergencyMode", true)
    
    warn("🚨 EMERGENCY MODE ACTIVATED: " .. reason)
end

function GameHealthMonitor:ClearEmergency()
    ProductionConfig.SetEmergencyOverride("enableEmergencyMode", false)
    
    if self.systemManager then
        self.systemManager.config.emergencyMode = false
    end
    
    print("✅ Emergency mode cleared")
end

return GameHealthMonitor 