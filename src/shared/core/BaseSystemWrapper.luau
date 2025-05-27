-- BaseSystemWrapper.luau
-- Standardized base class for all system wrappers
-- Provides consistent patterns for health monitoring, fallbacks, and error handling

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BaseSystemWrapper = {}
BaseSystemWrapper.__index = BaseSystemWrapper

-- Default configuration that can be overridden
local DEFAULT_CONFIG = {
    HEALTH_CHECK_INTERVAL = 30,
    FALLBACK_TIMEOUT = 5,
    DEBUG_MODE = false,
    MAX_RETRY_ATTEMPTS = 3,
    RETRY_DELAY = 1
}

-- Create a new system wrapper
function BaseSystemWrapper.new(systemName, config)
    local self = setmetatable({}, BaseSystemWrapper)
    
    -- Core properties
    self.systemName = systemName or "UnknownSystem"
    self.config = setmetatable(config or {}, {__index = DEFAULT_CONFIG})
    
    -- System state tracking
    self.systemState = {
        primarySystem = nil,
        fallbackSystems = {},
        isInitialized = false,
        lastHealthCheck = 0,
        healthStatus = "unknown", -- "healthy", "degraded", "failed"
        activeSystem = "none", -- "primary", "fallback", "none"
        retryCount = 0,
        errors = {}
    }
    
    -- Global API functions
    self.globalAPI = {}
    
    print(string.format("[%s] BaseSystemWrapper created", self.systemName))
    return self
end

-- Initialize the wrapper system (to be overridden by subclasses)
function BaseSystemWrapper:Initialize()
    print(string.format("[%s] Initializing system wrapper...", self.systemName))
    
    -- Load primary system
    local primarySuccess = self:LoadPrimarySystem()
    
    -- Load fallback systems
    self:LoadFallbackSystems()
    
    -- Start health monitoring
    if self.config.HEALTH_CHECK_INTERVAL > 0 then
        self:StartHealthMonitoring()
    end
    
    -- Set up global API
    self:SetupGlobalAPI()
    
    self.systemState.isInitialized = true
    
    -- Determine active system
    if primarySuccess then
        self.systemState.activeSystem = "primary"
        self.systemState.healthStatus = "healthy"
        print(string.format("[%s] ✅ Initialization complete - Primary system active", self.systemName))
    elseif self:CountTable(self.systemState.fallbackSystems) > 0 then
        self.systemState.activeSystem = "fallback"
        self.systemState.healthStatus = "degraded"
        print(string.format("[%s] ⚠️ Initialization complete - Fallback system active", self.systemName))
    else
        self.systemState.activeSystem = "none"
        self.systemState.healthStatus = "failed"
        warn(string.format("[%s] ❌ Initialization failed - No systems available", self.systemName))
    end
    
    return self.systemState.isInitialized
end

-- Load the primary system (to be implemented by subclasses)
function BaseSystemWrapper:LoadPrimarySystem()
    warn(string.format("[%s] LoadPrimarySystem not implemented by subclass", self.systemName))
    return false
end

-- Load fallback systems (to be implemented by subclasses)
function BaseSystemWrapper:LoadFallbackSystems()
    warn(string.format("[%s] LoadFallbackSystems not implemented by subclass", self.systemName))
end

-- Set up global API functions (to be implemented by subclasses)
function BaseSystemWrapper:SetupGlobalAPI()
    -- Default implementation - subclasses should override
    self.globalAPI.GetSystemStatus = function()
        return self:GetSystemStatus()
    end
    
    print(string.format("[%s] Basic global API configured", self.systemName))
end

-- Start health monitoring system
function BaseSystemWrapper:StartHealthMonitoring()
    task.spawn(function()
        while self.systemState.isInitialized do
            task.wait(self.config.HEALTH_CHECK_INTERVAL)
            self:PerformHealthCheck()
        end
    end)
    
    print(string.format("[%s] Health monitoring started", self.systemName))
end

-- Perform health check on active systems
function BaseSystemWrapper:PerformHealthCheck()
    self.systemState.lastHealthCheck = tick()
    
    if self.config.DEBUG_MODE then
        print(string.format("[%s] Performing health check...", self.systemName))
    end
    
    -- Check primary system health
    if self.systemState.primarySystem then
        local isHealthy = self:CheckPrimarySystemHealth()
        
        if isHealthy and self.systemState.activeSystem ~= "primary" then
            -- Primary system recovered, switch back
            self.systemState.activeSystem = "primary"
            self.systemState.healthStatus = "healthy"
            self.systemState.retryCount = 0
            print(string.format("[%s] ✅ Primary system recovered, switching back", self.systemName))
        elseif not isHealthy and self.systemState.activeSystem == "primary" then
            -- Primary system failed, switch to fallback
            self.systemState.activeSystem = "fallback"
            self.systemState.healthStatus = "degraded"
            warn(string.format("[%s] ⚠️ Primary system failed, switching to fallback", self.systemName))
        end
    end
    
    -- Update overall health status
    if self.systemState.activeSystem == "primary" then
        self.systemState.healthStatus = "healthy"
    elseif self.systemState.activeSystem == "fallback" then
        self.systemState.healthStatus = "degraded"
    else
        self.systemState.healthStatus = "failed"
    end
end

-- Check if primary system is healthy (to be implemented by subclasses)
function BaseSystemWrapper:CheckPrimarySystemHealth()
    if not self.systemState.primarySystem then
        return false
    end
    
    -- Basic health check - subclasses should override with specific checks
    return self.systemState.primarySystem.isActive ~= false
end

-- Route function calls to the appropriate system
function BaseSystemWrapper:RouteCall(functionName, ...)
    local args = {...}
    
    if self.config.DEBUG_MODE then
        print(string.format("[%s] Routing call: %s to %s system", 
            self.systemName, functionName, self.systemState.activeSystem))
    end
    
    -- Try primary system first
    if self.systemState.activeSystem == "primary" and self.systemState.primarySystem then
        local success, result = pcall(function()
            local func = self.systemState.primarySystem[functionName]
            if func and typeof(func) == "function" then
                return func(self.systemState.primarySystem, unpack(args))
            else
                error("Function not found: " .. functionName)
            end
        end)
        
        if success then
            if self.config.DEBUG_MODE then
                print(string.format("[%s] Primary system call successful", self.systemName))
            end
            return result
        else
            warn(string.format("[%s] Primary system call failed: %s", self.systemName, result))
            self:RecordError("primary_call_failed", result)
            -- Fall through to fallback systems
        end
    end
    
    -- Try fallback systems
    if self.systemState.activeSystem == "fallback" or self.systemState.activeSystem == "primary" then
        for systemName, system in pairs(self.systemState.fallbackSystems) do
            local success, result = pcall(function()
                if typeof(system) == "table" then
                    -- Try OOP style first
                    if system[functionName] and typeof(system[functionName]) == "function" then
                        return system[functionName](system, unpack(args))
                    end
                    
                    -- Try creating instance if it's a class
                    if system.new and typeof(system.new) == "function" then
                        local instance = system.new()
                        if instance[functionName] and typeof(instance[functionName]) == "function" then
                            return instance[functionName](instance, unpack(args))
                        end
                    end
                end
                
                error("Function not found in " .. systemName)
            end)
            
            if success then
                if self.config.DEBUG_MODE then
                    print(string.format("[%s] Fallback system call successful: %s", self.systemName, systemName))
                end
                return result
            else
                if self.config.DEBUG_MODE then
                    warn(string.format("[%s] Fallback system call failed: %s - %s", self.systemName, systemName, result))
                end
                self:RecordError("fallback_call_failed", result, systemName)
            end
        end
    end
    
    -- All systems failed
    local errorMsg = string.format("All systems failed for function: %s", functionName)
    warn(string.format("[%s] %s", self.systemName, errorMsg))
    self:RecordError("all_systems_failed", errorMsg, functionName)
    return nil
end

-- Get comprehensive system status
function BaseSystemWrapper:GetSystemStatus()
    return {
        systemName = self.systemName,
        isInitialized = self.systemState.isInitialized,
        activeSystem = self.systemState.activeSystem,
        healthStatus = self.systemState.healthStatus,
        lastHealthCheck = self.systemState.lastHealthCheck,
        retryCount = self.systemState.retryCount,
        availableSystems = {
            primary = self.systemState.primarySystem ~= nil,
            fallbacks = self:CountTable(self.systemState.fallbackSystems)
        },
        errors = self.systemState.errors,
        config = {
            healthCheckInterval = self.config.HEALTH_CHECK_INTERVAL,
            debugMode = self.config.DEBUG_MODE,
            maxRetryAttempts = self.config.MAX_RETRY_ATTEMPTS
        }
    }
end

-- Record errors for debugging and monitoring
function BaseSystemWrapper:RecordError(errorType, errorMessage, context)
    local errorRecord = {
        type = errorType,
        message = errorMessage,
        context = context,
        timestamp = tick(),
        activeSystem = self.systemState.activeSystem
    }
    
    table.insert(self.systemState.errors, errorRecord)
    
    -- Keep only last 10 errors to prevent memory bloat
    if #self.systemState.errors > 10 then
        table.remove(self.systemState.errors, 1)
    end
end

-- Retry failed operations
function BaseSystemWrapper:RetryOperation(functionName, ...)
    if self.systemState.retryCount >= self.config.MAX_RETRY_ATTEMPTS then
        warn(string.format("[%s] Max retry attempts reached for: %s", self.systemName, functionName))
        return nil
    end
    
    self.systemState.retryCount = self.systemState.retryCount + 1
    
    task.wait(self.config.RETRY_DELAY)
    
    print(string.format("[%s] Retrying operation: %s (attempt %d)", 
        self.systemName, functionName, self.systemState.retryCount))
    
    return self:RouteCall(functionName, ...)
end

-- Switch to fallback system manually
function BaseSystemWrapper:SwitchToFallback(reason)
    if self:CountTable(self.systemState.fallbackSystems) == 0 then
        warn(string.format("[%s] Cannot switch to fallback: No fallback systems available", self.systemName))
        return false
    end
    
    self.systemState.activeSystem = "fallback"
    self.systemState.healthStatus = "degraded"
    
    print(string.format("[%s] Manually switched to fallback system. Reason: %s", self.systemName, reason or "Unknown"))
    self:RecordError("manual_fallback", reason or "Manual switch to fallback")
    
    return true
end

-- Get the currently active system instance
function BaseSystemWrapper:GetActiveSystem()
    if self.systemState.activeSystem == "primary" then
        return self.systemState.primarySystem
    elseif self.systemState.activeSystem == "fallback" then
        -- Return the first available fallback system
        for _, system in pairs(self.systemState.fallbackSystems) do
            return system
        end
    end
    return nil
end

-- Cleanup function
function BaseSystemWrapper:Cleanup()
    print(string.format("[%s] Cleaning up...", self.systemName))
    
    self.systemState.isInitialized = false
    
    -- Cleanup primary system
    if self.systemState.primarySystem and self.systemState.primarySystem.Cleanup then
        pcall(function()
            self.systemState.primarySystem:Cleanup()
        end)
    end
    
    -- Clear references
    self.systemState.primarySystem = nil
    self.systemState.fallbackSystems = {}
    self.systemState.activeSystem = "none"
    self.systemState.healthStatus = "unknown"
    
    print(string.format("[%s] Cleanup complete", self.systemName))
end

-- Utility function to count table entries
function BaseSystemWrapper:CountTable(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- Safe require function with error handling
function BaseSystemWrapper:SafeRequire(modulePath, moduleName)
    local success, result = pcall(function()
        return require(modulePath)
    end)
    
    if success then
        print(string.format("[%s] Successfully loaded %s", self.systemName, moduleName or "module"))
        return result
    else
        warn(string.format("[%s] Failed to load %s: %s", self.systemName, moduleName or "module", result))
        self:RecordError("module_load_failed", result, moduleName)
        return nil
    end
end

-- Create a standardized error handler
function BaseSystemWrapper:CreateErrorHandler(context)
    return function(errorMessage)
        local fullMessage = string.format("[%s] Error in %s: %s", self.systemName, context, errorMessage)
        warn(fullMessage)
        self:RecordError("runtime_error", errorMessage, context)
        return nil
    end
end

return BaseSystemWrapper 