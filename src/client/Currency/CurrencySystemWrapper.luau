-- CurrencySystemWrapper.luau
-- Smart routing wrapper for the unified currency system
-- Provides backward compatibility and automatic fallback to legacy systems
-- Global API functions for easy access throughout the codebase

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CurrencySystemWrapper = {}
CurrencySystemWrapper.__index = CurrencySystemWrapper

-- Configuration
local CONFIG = {
    HEALTH_CHECK_INTERVAL = 30, -- seconds
    FALLBACK_TIMEOUT = 5, -- seconds
    DEBUG_MODE = true,
    MAX_RETRY_ATTEMPTS = 3,
    RETRY_DELAY = 1 -- seconds
}

-- System state tracking
local systemState = {
    primarySystem = nil, -- CurrencyManager instance
    fallbackSystems = {}, -- Legacy system references
    isInitialized = false,
    lastHealthCheck = 0,
    healthStatus = "unknown", -- "healthy", "degraded", "failed"
    activeSystem = "none", -- "primary", "fallback", "none"
    retryCount = 0
}

-- Global API functions (accessible from anywhere)
local GlobalAPI = {}

-- Initialize the wrapper system
function CurrencySystemWrapper.Initialize()
    print("[CurrencySystemWrapper] Initializing currency system wrapper...")
    
    -- Try to load the primary system (CurrencyManager)
    local primarySuccess = CurrencySystemWrapper._LoadPrimarySystem()
    
    -- Load fallback systems
    CurrencySystemWrapper._LoadFallbackSystems()
    
    -- Start health monitoring
    CurrencySystemWrapper._StartHealthMonitoring()
    
    -- Set up global API
    CurrencySystemWrapper._SetupGlobalAPI()
    
    systemState.isInitialized = true
    
    if primarySuccess then
        systemState.activeSystem = "primary"
        systemState.healthStatus = "healthy"
        print("[CurrencySystemWrapper] ✅ Initialization complete - Primary system active")
    elseif #systemState.fallbackSystems > 0 then
        systemState.activeSystem = "fallback"
        systemState.healthStatus = "degraded"
        print("[CurrencySystemWrapper] ⚠️ Initialization complete - Fallback system active")
    else
        systemState.activeSystem = "none"
        systemState.healthStatus = "failed"
        warn("[CurrencySystemWrapper] ❌ Initialization failed - No systems available")
    end
    
    return systemState.isInitialized
end

-- Load the primary currency system (CurrencyManager)
function CurrencySystemWrapper._LoadPrimarySystem()
    local success, result = pcall(function()
        local CurrencyManager = require(script.Parent.CurrencyManager)
        local instance = CurrencyManager.new()
        
        if instance:Initialize() then
            systemState.primarySystem = instance
            print("[CurrencySystemWrapper] Primary system (CurrencyManager) loaded successfully")
            return true
        else
            warn("[CurrencySystemWrapper] Primary system initialization failed")
            return false
        end
    end)
    
    if not success then
        warn("[CurrencySystemWrapper] Failed to load primary system:", result)
        return false
    end
    
    return result
end

-- Load fallback systems for backward compatibility
function CurrencySystemWrapper._LoadFallbackSystems()
    local fallbacks = {}
    
    -- Try to load SharedModule CurrencyUI
    local sharedSuccess, sharedModule = pcall(function()
        return require(ReplicatedStorage:WaitForChild("shared", 5))
    end)
    
    if sharedSuccess and sharedModule and sharedModule.CurrencyUI then
        fallbacks.sharedCurrencyUI = sharedModule.CurrencyUI
        print("[CurrencySystemWrapper] Loaded SharedModule.CurrencyUI fallback")
    end
    
    -- Try to load legacy CurrencyUI
    local legacySuccess, legacyCurrencyUI = pcall(function()
        return require(script.Parent.CurrencyUI)
    end)
    
    if legacySuccess and legacyCurrencyUI then
        fallbacks.legacyCurrencyUI = legacyCurrencyUI
        print("[CurrencySystemWrapper] Loaded legacy CurrencyUI fallback")
    end
    
    -- Try to load server-side CurrencyManager
    local serverSuccess, serverCurrencyManager = pcall(function()
        local shared = ReplicatedStorage:FindFirstChild("shared")
        if shared then
            local core = shared:FindFirstChild("core")
            if core then
                local economy = core:FindFirstChild("economy")
                if economy then
                    local currencyManager = economy:FindFirstChild("CurrencyManager")
                    if currencyManager then
                        return require(currencyManager)
                    end
                end
            end
        end
        return nil
    end)
    
    if serverSuccess and serverCurrencyManager then
        fallbacks.serverCurrencyManager = serverCurrencyManager
        print("[CurrencySystemWrapper] Loaded server CurrencyManager fallback")
    end
    
    systemState.fallbackSystems = fallbacks
    print("[CurrencySystemWrapper] Loaded", CurrencySystemWrapper._CountTable(fallbacks), "fallback systems")
end

-- Start health monitoring system
function CurrencySystemWrapper._StartHealthMonitoring()
    task.spawn(function()
        while systemState.isInitialized do
            task.wait(CONFIG.HEALTH_CHECK_INTERVAL)
            CurrencySystemWrapper._PerformHealthCheck()
        end
    end)
    
    print("[CurrencySystemWrapper] Health monitoring started")
end

-- Perform health check on active systems
function CurrencySystemWrapper._PerformHealthCheck()
    systemState.lastHealthCheck = tick()
    
    if CONFIG.DEBUG_MODE then
        print("[CurrencySystemWrapper] Performing health check...")
    end
    
    -- Check primary system health
    if systemState.primarySystem then
        local isHealthy = CurrencySystemWrapper._CheckPrimarySystemHealth()
        
        if isHealthy and systemState.activeSystem ~= "primary" then
            -- Primary system recovered, switch back
            systemState.activeSystem = "primary"
            systemState.healthStatus = "healthy"
            systemState.retryCount = 0
            print("[CurrencySystemWrapper] ✅ Primary system recovered, switching back")
        elseif not isHealthy and systemState.activeSystem == "primary" then
            -- Primary system failed, switch to fallback
            systemState.activeSystem = "fallback"
            systemState.healthStatus = "degraded"
            warn("[CurrencySystemWrapper] ⚠️ Primary system failed, switching to fallback")
        end
    end
    
    -- Update overall health status
    if systemState.activeSystem == "primary" then
        systemState.healthStatus = "healthy"
    elseif systemState.activeSystem == "fallback" then
        systemState.healthStatus = "degraded"
    else
        systemState.healthStatus = "failed"
    end
end

-- Check if primary system is healthy
function CurrencySystemWrapper._CheckPrimarySystemHealth()
    if not systemState.primarySystem then
        return false
    end
    
    -- Check if the system is still active
    if not systemState.primarySystem.isActive then
        return false
    end
    
    -- Check if UI is still present
    local player = Players.LocalPlayer
    if player and player:FindFirstChild("PlayerGui") then
        local currencyUI = player.PlayerGui:FindFirstChild("CurrencyUI")
        if not currencyUI then
            return false
        end
    end
    
    return true
end

-- Set up global API functions
function CurrencySystemWrapper._SetupGlobalAPI()
    -- Update balance function
    GlobalAPI.UpdateGlobalBalance = function(balance)
        return CurrencySystemWrapper._RouteCall("UpdateBalance", balance)
    end
    
    -- Show purchase menu function
    GlobalAPI.ShowGlobalPurchaseMenu = function()
        return CurrencySystemWrapper._RouteCall("ShowPurchaseMenu")
    end
    
    -- Get current balance function
    GlobalAPI.GetGlobalBalance = function()
        return CurrencySystemWrapper._RouteCall("GetBalance")
    end
    
    -- Hide purchase menu function
    GlobalAPI.HideGlobalPurchaseMenu = function()
        return CurrencySystemWrapper._RouteCall("HidePurchaseMenu")
    end
    
    -- Get system status function
    GlobalAPI.GetSystemStatus = function()
        return {
            isInitialized = systemState.isInitialized,
            activeSystem = systemState.activeSystem,
            healthStatus = systemState.healthStatus,
            lastHealthCheck = systemState.lastHealthCheck,
            retryCount = systemState.retryCount,
            availableSystems = {
                primary = systemState.primarySystem ~= nil,
                fallbacks = CurrencySystemWrapper._CountTable(systemState.fallbackSystems)
            }
        }
    end
    
    print("[CurrencySystemWrapper] Global API functions configured")
end

-- Route function calls to the appropriate system
function CurrencySystemWrapper._RouteCall(functionName, ...)
    local args = {...}
    
    if CONFIG.DEBUG_MODE then
        print("[CurrencySystemWrapper] Routing call:", functionName, "to", systemState.activeSystem, "system")
    end
    
    -- Try primary system first
    if systemState.activeSystem == "primary" and systemState.primarySystem then
        local success, result = pcall(function()
            local func = systemState.primarySystem[functionName]
            if func and typeof(func) == "function" then
                return func(systemState.primarySystem, unpack(args))
            else
                error("Function not found: " .. functionName)
            end
        end)
        
        if success then
            if CONFIG.DEBUG_MODE then
                print("[CurrencySystemWrapper] Primary system call successful")
            end
            return result
        else
            warn("[CurrencySystemWrapper] Primary system call failed:", result)
            -- Fall through to fallback systems
        end
    end
    
    -- Try fallback systems
    if systemState.activeSystem == "fallback" or systemState.activeSystem == "primary" then
        for systemName, system in pairs(systemState.fallbackSystems) do
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
                if CONFIG.DEBUG_MODE then
                    print("[CurrencySystemWrapper] Fallback system call successful:", systemName)
                end
                return result
            else
                if CONFIG.DEBUG_MODE then
                    warn("[CurrencySystemWrapper] Fallback system call failed:", systemName, result)
                end
            end
        end
    end
    
    -- All systems failed
    warn("[CurrencySystemWrapper] All systems failed for function:", functionName)
    return nil
end

-- Retry failed operations
function CurrencySystemWrapper._RetryOperation(functionName, ...)
    if systemState.retryCount >= CONFIG.MAX_RETRY_ATTEMPTS then
        warn("[CurrencySystemWrapper] Max retry attempts reached for:", functionName)
        return nil
    end
    
    systemState.retryCount = systemState.retryCount + 1
    
    task.wait(CONFIG.RETRY_DELAY)
    
    print("[CurrencySystemWrapper] Retrying operation:", functionName, "(attempt", systemState.retryCount, ")")
    
    return CurrencySystemWrapper._RouteCall(functionName, ...)
end

-- Utility function to count table entries
function CurrencySystemWrapper._CountTable(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- Cleanup function
function CurrencySystemWrapper.Cleanup()
    print("[CurrencySystemWrapper] Cleaning up...")
    
    systemState.isInitialized = false
    
    -- Cleanup primary system
    if systemState.primarySystem and systemState.primarySystem.Cleanup then
        systemState.primarySystem:Cleanup()
    end
    
    -- Clear references
    systemState.primarySystem = nil
    systemState.fallbackSystems = {}
    systemState.activeSystem = "none"
    systemState.healthStatus = "unknown"
    
    print("[CurrencySystemWrapper] Cleanup complete")
end

-- Export global API functions for easy access
CurrencySystemWrapper.UpdateGlobalBalance = function(balance)
    return GlobalAPI.UpdateGlobalBalance(balance)
end

CurrencySystemWrapper.ShowGlobalPurchaseMenu = function()
    return GlobalAPI.ShowGlobalPurchaseMenu()
end

CurrencySystemWrapper.GetGlobalBalance = function()
    return GlobalAPI.GetGlobalBalance()
end

CurrencySystemWrapper.HideGlobalPurchaseMenu = function()
    return GlobalAPI.HideGlobalPurchaseMenu()
end

CurrencySystemWrapper.GetSystemStatus = function()
    return GlobalAPI.GetSystemStatus()
end

-- Backward compatibility aliases
CurrencySystemWrapper.UpdateBalance = CurrencySystemWrapper.UpdateGlobalBalance
CurrencySystemWrapper.ShowPurchaseMenu = CurrencySystemWrapper.ShowGlobalPurchaseMenu
CurrencySystemWrapper.GetBalance = CurrencySystemWrapper.GetGlobalBalance

return CurrencySystemWrapper 