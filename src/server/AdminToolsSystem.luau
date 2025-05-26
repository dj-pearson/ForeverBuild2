-- AdminToolsSystem.luau
-- Comprehensive admin tools for system management and monitoring

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ProductionConfig = require(script.Parent.ProductionConfig)

local AdminToolsSystem = {}
AdminToolsSystem.__index = AdminToolsSystem

function AdminToolsSystem.new(systemManager)
    local self = setmetatable({}, AdminToolsSystem)
    
    self.systemManager = systemManager
    
    -- Admin configuration
    self.adminConfig = {
        logAllCommands = true,
        requireConfirmation = true,
        emergencyBypassEnabled = true,
        maxBatchOperations = 100
    }
    
    -- Admin permissions
    self.permissions = {
        SUPER_ADMIN = {
            systemControl = true,
            emergencyCommands = true,
            playerModeration = true,
            dataManagement = true,
            systemReports = true
        },
        ADMIN = {
            systemControl = false,
            emergencyCommands = false,
            playerModeration = true,
            dataManagement = false,
            systemReports = true
        },
        MODERATOR = {
            systemControl = false,
            emergencyCommands = false,
            playerModeration = true,
            dataManagement = false,
            systemReports = false
        }
    }
    
    -- Command history
    self.commandHistory = {}
    self.maxHistorySize = 1000
    
    self:Initialize()
    return self
end

function AdminToolsSystem:Initialize()
    -- Register admin commands
    self:RegisterAdminCommands()
    
    print("🛠️ Admin tools system initialized")
end

-- Command registration and handling
function AdminToolsSystem:RegisterAdminCommands()
    local commands = {
        -- System management
        ["systemstatus"] = {
            func = self.GetSystemStatus,
            permission = "systemReports",
            description = "Get overall system status"
        },
        ["systemreport"] = {
            func = self.GenerateSystemReport,
            permission = "systemReports",
            description = "Generate detailed system report"
        },
        ["restartsystem"] = {
            func = self.RestartSystem,
            permission = "systemControl",
            description = "Restart a specific system"
        },
        ["emergencymode"] = {
            func = self.ToggleEmergencyMode,
            permission = "emergencyCommands",
            description = "Toggle emergency mode"
        },
        
        -- Performance commands
        ["memorycleanup"] = {
            func = self.ForceMemoryCleanup,
            permission = "systemControl",
            description = "Force memory cleanup"
        },
        ["performancereport"] = {
            func = self.GetPerformanceReport,
            permission = "systemReports",
            description = "Get performance metrics"
        },
        
        -- Security commands
        ["playerstatus"] = {
            func = self.GetPlayerSecurityStatus,
            permission = "playerModeration",
            description = "Get player security status"
        },
        ["resetviolations"] = {
            func = self.ResetPlayerViolations,
            permission = "playerModeration",
            description = "Reset player violations"
        },
        ["securityreport"] = {
            func = self.GetSecurityReport,
            permission = "systemReports",
            description = "Get security and exploit report"
        },
        
        -- Data management
        ["forcebackup"] = {
            func = self.ForceBackup,
            permission = "dataManagement",
            description = "Force immediate backup"
        },
        ["recoverdata"] = {
            func = self.RecoverData,
            permission = "dataManagement",
            description = "Recover from backup"
        },
        ["backupstatus"] = {
            func = self.GetBackupStatus,
            permission = "systemReports",
            description = "Get backup system status"
        },
        
        -- Monitoring commands
        ["analytics"] = {
            func = self.GetAnalytics,
            permission = "systemReports",
            description = "Get analytics overview"
        },
        ["playermetrics"] = {
            func = self.GetPlayerMetrics,
            permission = "systemReports",
            description = "Get player behavior metrics"
        },
        
        -- Emergency commands
        ["shutdown"] = {
            func = self.InitiateShutdown,
            permission = "emergencyCommands",
            description = "Initiate graceful shutdown"
        },
        ["emergencybackup"] = {
            func = self.EmergencyBackup,
            permission = "emergencyCommands",
            description = "Emergency backup all data"
        }
    }
    
    self.commands = commands
    print("📋 Registered", #commands, "admin commands")
end

function AdminToolsSystem:ProcessCommand(player, commandString)
    if not self:IsAdmin(player) then
        self:NotifyPlayer(player, "❌ Access denied - Admin privileges required")
        return false
    end
    
    local parts = commandString:split(" ")
    local commandName = parts[1]:lower()
    local args = {}
    for i = 2, #parts do
        table.insert(args, parts[i])
    end
    
    local command = self.commands[commandName]
    if not command then
        self:NotifyPlayer(player, "❌ Unknown command: " .. commandName)
        self:ShowHelp(player)
        return false
    end
    
    -- Check permissions
    if not self:HasPermission(player, command.permission) then
        self:NotifyPlayer(player, "❌ Insufficient permissions for: " .. commandName)
        return false
    end
    
    -- Log command
    self:LogCommand(player, commandString)
    
    -- Execute command
    local success, result = pcall(function()
        return command.func(self, player, unpack(args))
    end)
    
    if success then
        if result then
            self:NotifyPlayer(player, "✅ " .. result)
        end
        return true
    else
        self:NotifyPlayer(player, "❌ Command failed: " .. tostring(result))
        return false
    end
end

-- System management commands
function AdminToolsSystem:GetSystemStatus(player)
    local status = self.systemManager:GetSystemStatus()
    
    local message = "🏥 SYSTEM STATUS: " .. status.overall .. "\n"
    message = message .. "Last Check: " .. os.date("%H:%M:%S", status.lastHealthCheck) .. "\n"
    message = message .. "Critical Errors: " .. status.criticalErrors .. "\n\n"
    
    for systemName, health in pairs(status.individual) do
        local emoji = health.status == "OPERATIONAL" and "✅" or "❌"
        message = message .. emoji .. " " .. systemName .. ": " .. health.status .. " (" .. health.priority .. ")\n"
    end
    
    self:NotifyPlayer(player, message)
    return "System status retrieved"
end

function AdminToolsSystem:GenerateSystemReport(player)
    local report = self.systemManager:GenerateSystemReport()
    
    local message = "📊 DETAILED SYSTEM REPORT\n"
    message = message .. "Timestamp: " .. report.timestamp .. "\n"
    message = message .. "Uptime: " .. math.floor(report.uptime / 60) .. " minutes\n"
    message = message .. "Emergency Mode: " .. (report.emergencyMode and "ACTIVE" or "INACTIVE") .. "\n"
    message = message .. "Performance: " .. report.performanceMetrics.totalRequests .. " total requests\n"
    message = message .. "Success Rate: " .. math.floor((report.performanceMetrics.successfulRequests / math.max(1, report.performanceMetrics.totalRequests)) * 100) .. "%\n"
    
    self:NotifyPlayer(player, message)
    return "System report generated"
end

function AdminToolsSystem:RestartSystem(player, systemName)
    if not systemName then
        return "Usage: restartsystem <systemName>"
    end
    
    local success = self.systemManager:RestartSystem(systemName)
    if success then
        return "Successfully restarted system: " .. systemName
    else
        return "Failed to restart system: " .. systemName
    end
end

function AdminToolsSystem:ToggleEmergencyMode(player)
    if self.systemManager.config.emergencyMode then
        self.systemManager.config.emergencyMode = false
        return "Emergency mode DISABLED"
    else
        self.systemManager:EnterEmergencyMode()
        return "Emergency mode ENABLED"
    end
end

-- Performance commands
function AdminToolsSystem:ForceMemoryCleanup(player)
    if self.systemManager.systems.memoryManager then
        self.systemManager.systems.memoryManager:EmergencyCleanup()
        return "Memory cleanup completed"
    else
        return "Memory manager not available"
    end
end

function AdminToolsSystem:GetPerformanceReport(player)
    local metrics = self.systemManager:GetPerformanceMetrics()
    
    local message = "⚡ PERFORMANCE METRICS\n"
    message = message .. "Total Requests: " .. metrics.totalRequests .. "\n"
    message = message .. "Successful: " .. metrics.successfulRequests .. "\n"
    message = message .. "Failed: " .. metrics.failedRequests .. "\n"
    message = message .. "Success Rate: " .. math.floor((metrics.successfulRequests / math.max(1, metrics.totalRequests)) * 100) .. "%\n"
    message = message .. "Avg Response Time: " .. math.floor(metrics.averageResponseTime * 1000) .. "ms\n"
    
    -- Memory info if available
    if self.systemManager.systems.memoryManager then
        local memReport = self.systemManager.systems.memoryManager:GenerateMemoryReport()
        message = message .. "Memory Usage: " .. memReport.currentMemory .. "MB\n"
        message = message .. "Optimization Mode: " .. memReport.currentMode .. "\n"
    end
    
    self:NotifyPlayer(player, message)
    return "Performance report generated"
end

-- Security commands
function AdminToolsSystem:GetPlayerSecurityStatus(player, targetPlayerName)
    if not targetPlayerName then
        return "Usage: playerstatus <playerName>"
    end
    
    local targetPlayer = self:FindPlayer(targetPlayerName)
    if not targetPlayer then
        return "Player not found: " .. targetPlayerName
    end
    
    if self.systemManager.systems.antiExploit then
        local suspicion = self.systemManager.systems.antiExploit:GetPlayerSuspicionLevel(targetPlayer)
        local violations = self.systemManager.systems.antiExploit:GetPlayerViolations(targetPlayer)
        
        local message = "🔍 SECURITY STATUS: " .. targetPlayer.Name .. "\n"
        message = message .. "Suspicion Level: " .. suspicion .. "\n"
        message = message .. "Total Violations: " .. #violations .. "\n"
        
        if #violations > 0 then
            message = message .. "\nRecent Violations:\n"
            for i = math.max(1, #violations - 5), #violations do
                local violation = violations[i]
                message = message .. "- " .. violation.type .. " (Severity: " .. violation.severity .. ")\n"
            end
        end
        
        self:NotifyPlayer(player, message)
        return "Security status retrieved"
    else
        return "Anti-exploit system not available"
    end
end

function AdminToolsSystem:ResetPlayerViolations(player, targetPlayerName)
    if not targetPlayerName then
        return "Usage: resetviolations <playerName>"
    end
    
    local targetPlayer = self:FindPlayer(targetPlayerName)
    if not targetPlayer then
        return "Player not found: " .. targetPlayerName
    end
    
    if self.systemManager.systems.antiExploit then
        self.systemManager.systems.antiExploit:ResetPlayerViolations(targetPlayer)
        return "Reset violations for: " .. targetPlayer.Name
    else
        return "Anti-exploit system not available"
    end
end

function AdminToolsSystem:GetSecurityReport(player)
    if self.systemManager.systems.antiExploit then
        local report = self.systemManager.systems.antiExploit:GenerateSecurityReport()
        
        local message = "🔒 SECURITY REPORT\n"
        message = message .. "Total Players: " .. report.totalPlayers .. "\n"
        message = message .. "Suspicious Players: " .. report.suspiciousPlayers .. "\n"
        message = message .. "Total Violations: " .. report.totalViolations .. "\n"
        message = message .. "Breakdown:\n"
        message = message .. "  Minor: " .. report.severityBreakdown.minor .. "\n"
        message = message .. "  Moderate: " .. report.severityBreakdown.moderate .. "\n"
        message = message .. "  Severe: " .. report.severityBreakdown.severe .. "\n"
        
        self:NotifyPlayer(player, message)
        return "Security report generated"
    else
        return "Anti-exploit system not available"
    end
end

-- Data management commands
function AdminToolsSystem:ForceBackup(player)
    local success = self.systemManager:ForceBackup()
    if success then
        return "Backup initiated successfully"
    else
        return "Failed to initiate backup"
    end
end

function AdminToolsSystem:RecoverData(player, backupVersion)
    if not self:HasPermission(player, "emergencyCommands") then
        return "Recovery requires emergency permissions"
    end
    
    if self.systemManager.systems.dataBackup then
        local success = self.systemManager.systems.dataBackup:RecoverFromBackup(backupVersion)
        if success then
            return "Data recovery completed from version: " .. (backupVersion or "LATEST")
        else
            return "Data recovery failed"
        end
    else
        return "Backup system not available"
    end
end

function AdminToolsSystem:GetBackupStatus(player)
    if self.systemManager.systems.dataBackup then
        local report = self.systemManager.systems.dataBackup:GenerateBackupReport()
        
        local message = "💾 BACKUP STATUS\n"
        message = message .. "Is Backing Up: " .. (report.systemHealth.isBackingUp and "YES" or "NO") .. "\n"
        message = message .. "Pending Changes: " .. report.systemHealth.pendingChanges .. "\n"
        message = message .. "Successful Backups: " .. report.backupStats.successfulBackups .. "\n"
        message = message .. "Failed Backups: " .. report.backupStats.failedBackups .. "\n"
        message = message .. "Last Full Backup: " .. report.lastBackups.full .. "\n"
        message = message .. "Last Incremental: " .. report.lastBackups.incremental .. "\n"
        
        self:NotifyPlayer(player, message)
        return "Backup status retrieved"
    else
        return "Backup system not available"
    end
end

-- Analytics commands
function AdminToolsSystem:GetAnalytics(player)
    if self.systemManager.systems.analytics then
        local report = self.systemManager.systems.analytics:GenerateGameHealthReport()
        
        local message = "📈 ANALYTICS OVERVIEW\n"
        message = message .. "Current Players: " .. report.currentPlayers .. "\n"
        message = message .. "Peak Players: " .. report.peakPlayers .. "\n"
        message = message .. "Total Objects: " .. report.totalObjects .. "\n"
        message = message .. "Performance Status: " .. report.performanceStatus .. "\n"
        message = message .. "Economic Health:\n"
        message = message .. "  Coins in Circulation: " .. report.economicHealth.coinsInCirculation .. "\n"
        message = message .. "  Inflation Rate: " .. report.economicHealth.inflationRate .. "%\n"
        
        self:NotifyPlayer(player, message)
        return "Analytics retrieved"
    else
        return "Analytics system not available"
    end
end

function AdminToolsSystem:GetPlayerMetrics(player)
    if self.systemManager.systems.analytics then
        local topItems = self.systemManager.systems.analytics:GetTopItems(5)
        
        local message = "👥 PLAYER METRICS\n"
        message = message .. "Current Sessions: " .. #Players:GetPlayers() .. "\n"
        message = message .. "\nTop Items:\n"
        
        for i, item in ipairs(topItems) do
            message = message .. i .. ". " .. item.name .. " (" .. item.count .. " uses)\n"
        end
        
        self:NotifyPlayer(player, message)
        return "Player metrics retrieved"
    else
        return "Analytics system not available"
    end
end

-- Emergency commands
function AdminToolsSystem:InitiateShutdown(player, reason)
    if not self:HasPermission(player, "emergencyCommands") then
        return "Shutdown requires emergency permissions"
    end
    
    reason = reason or "Admin initiated shutdown"
    
    -- Warn all players
    for _, p in ipairs(Players:GetPlayers()) do
        self:NotifyPlayer(p, "⚠️ SERVER SHUTDOWN IN 30 SECONDS: " .. reason)
    end
    
    -- Wait and shutdown
    wait(30)
    self.systemManager:InitiateGracefulShutdown()
    
    return "Shutdown initiated: " .. reason
end

function AdminToolsSystem:EmergencyBackup(player)
    if self.systemManager.systems.dataBackup then
        self.systemManager.systems.dataBackup:EmergencyBackup()
        return "Emergency backup completed"
    else
        return "Backup system not available"
    end
end

-- Utility functions
function AdminToolsSystem:IsAdmin(player)
    -- Use production configuration for admin detection
    return ProductionConfig.IsAdmin(player.UserId)
end

function AdminToolsSystem:GetAdminLevel(player)
    -- This would determine admin level based on your system
    -- For now, return SUPER_ADMIN for all admins
    if self:IsAdmin(player) then
        return "SUPER_ADMIN"
    end
    return nil
end

function AdminToolsSystem:HasPermission(player, permission)
    local adminLevel = self:GetAdminLevel(player)
    if not adminLevel then return false end
    
    local perms = self.permissions[adminLevel]
    return perms and perms[permission] == true
end

function AdminToolsSystem:FindPlayer(playerName)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name:lower():find(playerName:lower()) then
            return player
        end
    end
    return nil
end

function AdminToolsSystem:NotifyPlayer(player, message)
    print("📢 [ADMIN] " .. player.Name .. ": " .. message)
    -- Implement actual notification system here
end

function AdminToolsSystem:LogCommand(player, command)
    local logEntry = {
        player = player.Name,
        userId = player.UserId,
        command = command,
        timestamp = os.time()
    }
    
    table.insert(self.commandHistory, logEntry)
    
    -- Keep history size manageable
    if #self.commandHistory > self.maxHistorySize then
        table.remove(self.commandHistory, 1)
    end
    
    print("📝 [ADMIN LOG] " .. player.Name .. " executed: " .. command)
end

function AdminToolsSystem:ShowHelp(player)
    local message = "🛠️ AVAILABLE ADMIN COMMANDS:\n\n"
    
    for commandName, command in pairs(self.commands) do
        if self:HasPermission(player, command.permission) then
            message = message .. "/" .. commandName .. " - " .. command.description .. "\n"
        end
    end
    
    self:NotifyPlayer(player, message)
end

-- Get command history
function AdminToolsSystem:GetCommandHistory(limit)
    limit = limit or 10
    local recent = {}
    
    for i = math.max(1, #self.commandHistory - limit + 1), #self.commandHistory do
        table.insert(recent, self.commandHistory[i])
    end
    
    return recent
end

-- Dashboard generation
function AdminToolsSystem:GenerateAdminDashboard()
    local dashboard = {
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        systemHealth = self.systemManager:GetSystemStatus(),
        performance = self.systemManager:GetPerformanceMetrics(),
        players = #Players:GetPlayers(),
        recentCommands = self:GetCommandHistory(5)
    }
    
    if self.systemManager.systems.memoryManager then
        dashboard.memory = self.systemManager.systems.memoryManager:GenerateMemoryReport()
    end
    
    if self.systemManager.systems.antiExploit then
        dashboard.security = self.systemManager.systems.antiExploit:GenerateSecurityReport()
    end
    
    return dashboard
end

return AdminToolsSystem 