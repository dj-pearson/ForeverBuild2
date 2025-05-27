-- CurrencySystemWrapper.luau
-- Smart routing wrapper for the unified currency system
-- Now inherits from BaseSystemWrapper for consistency and better functionality

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Import the standardized base wrapper and configuration
local BaseSystemWrapper = require(ReplicatedStorage.src.shared.core.BaseSystemWrapper)
local SystemConfig = require(ReplicatedStorage.src.shared.core.SystemConfig)

local CurrencySystemWrapper = setmetatable({}, BaseSystemWrapper)
CurrencySystemWrapper.__index = CurrencySystemWrapper

-- Get currency-specific configuration
local CURRENCY_CONFIG = SystemConfig.Utils.GetSystemConfig("CURRENCY")

-- Global instance for easy access
local globalInstance = nil

-- Create new currency system wrapper instance
function CurrencySystemWrapper.new()
    if globalInstance then
        return globalInstance
    end
    
    local self = BaseSystemWrapper.new("CurrencySystem", {
        HEALTH_CHECK_INTERVAL = CURRENCY_CONFIG.HEALTH_CHECK_INTERVAL or 30,
        DEBUG_MODE = SystemConfig.GLOBAL.DEBUG_MODE,
        MAX_RETRY_ATTEMPTS = SystemConfig.GLOBAL.MAX_RETRY_ATTEMPTS,
        RETRY_DELAY = SystemConfig.GLOBAL.RETRY_DELAY
    })
    
    -- Set up currency-specific metatable
    setmetatable(self, CurrencySystemWrapper)
    
    -- Store as global instance
    globalInstance = self
    
    return self
end

-- Load the primary currency system (CurrencyManager)
function CurrencySystemWrapper:LoadPrimarySystem()
    local primarySystem = self:SafeRequire(script.Parent.CurrencyManager, "CurrencyManager")
    
    if primarySystem and typeof(primarySystem.new) == "function" then
        local instance = primarySystem.new()
        if instance and instance.Initialize and instance:Initialize() then
            self.systemState.primarySystem = instance
            print("[CurrencySystemWrapper] Primary CurrencyManager loaded successfully")
            return true
        else
            warn("[CurrencySystemWrapper] Primary system initialization failed")
        end
    end
    
    return false
end

-- Load fallback systems for backward compatibility
function CurrencySystemWrapper:LoadFallbackSystems()
    local fallbacks = {}
    
    -- Load fallback systems based on configuration
    for _, fallbackName in ipairs(CURRENCY_CONFIG.FALLBACK_SYSTEMS) do
        if fallbackName == "SharedCurrencyUI" then
            local sharedModule = self:SafeRequire(ReplicatedStorage:WaitForChild("shared", 5), "SharedModule")
            if sharedModule and sharedModule.CurrencyUI then
                fallbacks.sharedCurrencyUI = sharedModule.CurrencyUI
                print("[CurrencySystemWrapper] Loaded SharedModule.CurrencyUI fallback")
            end
            
        elseif fallbackName == "LegacyCurrencyUI" then
            local legacyCurrencyUI = self:SafeRequire(script.Parent.CurrencyUI, "LegacyCurrencyUI")
            if legacyCurrencyUI then
                fallbacks.legacyCurrencyUI = legacyCurrencyUI
                print("[CurrencySystemWrapper] Loaded legacy CurrencyUI fallback")
            end
        end
    end
    
    self.systemState.fallbackSystems = fallbacks
    print(string.format("[CurrencySystemWrapper] Loaded %d fallback systems", self:CountTable(fallbacks)))
end

-- Set up global API functions specific to currency system
function CurrencySystemWrapper:SetupGlobalAPI()
    -- Call parent setup first
    BaseSystemWrapper.SetupGlobalAPI(self)
    
    -- Add currency-specific API functions
    self.globalAPI.UpdateGlobalBalance = function(balance)
        return self:RouteCall("UpdateBalance", balance)
    end
    
    self.globalAPI.ShowGlobalPurchaseMenu = function()
        return self:RouteCall("ShowPurchaseMenu")
    end
    
    self.globalAPI.GetGlobalBalance = function()
        return self:RouteCall("GetBalance")
    end
    
    self.globalAPI.HideGlobalPurchaseMenu = function()
        return self:RouteCall("HidePurchaseMenu")
    end
    
    print("[CurrencySystemWrapper] Currency-specific global API configured")
end

-- Check if primary system is healthy (currency-specific checks)
function CurrencySystemWrapper:CheckPrimarySystemHealth()
    if not self.systemState.primarySystem then
        return false
    end
    
    -- Check if the system is still active
    if self.systemState.primarySystem.isActive == false then
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

-- Global functions for easy access (backward compatibility)
function CurrencySystemWrapper.Initialize()
    local instance = CurrencySystemWrapper.GetGlobalInstance()
    return instance:Initialize()
end

function CurrencySystemWrapper.GetGlobalInstance()
    if not globalInstance then
        globalInstance = CurrencySystemWrapper.new()
        globalInstance:Initialize()
    end
    return globalInstance
end

function CurrencySystemWrapper.UpdateGlobalBalance(balance)
    local instance = CurrencySystemWrapper.GetGlobalInstance()
    return instance.globalAPI.UpdateGlobalBalance(balance)
end

function CurrencySystemWrapper.ShowGlobalPurchaseMenu()
    local instance = CurrencySystemWrapper.GetGlobalInstance()
    return instance.globalAPI.ShowGlobalPurchaseMenu()
end

function CurrencySystemWrapper.GetGlobalBalance()
    local instance = CurrencySystemWrapper.GetGlobalInstance()
    return instance.globalAPI.GetGlobalBalance()
end

function CurrencySystemWrapper.HideGlobalPurchaseMenu()
    local instance = CurrencySystemWrapper.GetGlobalInstance()
    return instance.globalAPI.HideGlobalPurchaseMenu()
end

function CurrencySystemWrapper.GetSystemStatus()
    local instance = CurrencySystemWrapper.GetGlobalInstance()
    return instance:GetSystemStatus()
end

-- Backward compatibility aliases
CurrencySystemWrapper.UpdateBalance = CurrencySystemWrapper.UpdateGlobalBalance
CurrencySystemWrapper.ShowPurchaseMenu = CurrencySystemWrapper.ShowGlobalPurchaseMenu
CurrencySystemWrapper.GetBalance = CurrencySystemWrapper.GetGlobalBalance

return CurrencySystemWrapper 