-- InteractionSystemWrapper.luau
-- Smart routing wrapper for the unified interaction system
-- Now inherits from BaseSystemWrapper for consistency and better functionality

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Import the standardized base wrapper and configuration
local BaseSystemWrapper = require(game.ReplicatedStorage.shared.core.BaseSystemWrapper)
local SystemConfig = require(game.ReplicatedStorage.shared.core.SystemConfig)

local InteractionSystemWrapper = setmetatable({}, BaseSystemWrapper)
InteractionSystemWrapper.__index = InteractionSystemWrapper

-- Get interaction-specific configuration
local INTERACTION_CONFIG = SystemConfig.Utils.GetSystemConfig("INTERACTION")

-- Global instance for easy access
local globalInstance = nil

-- Create new interaction system wrapper instance
function InteractionSystemWrapper.new()
    if globalInstance then
        return globalInstance
    end
    
    local self = BaseSystemWrapper.new("InteractionSystem", {
        HEALTH_CHECK_INTERVAL = INTERACTION_CONFIG.HEALTH_CHECK_INTERVAL or 30,
        DEBUG_MODE = SystemConfig.GLOBAL.DEBUG_MODE,
        MAX_RETRY_ATTEMPTS = SystemConfig.GLOBAL.MAX_RETRY_ATTEMPTS,
        RETRY_DELAY = SystemConfig.GLOBAL.RETRY_DELAY
    })
    
    -- Set up interaction-specific metatable
    setmetatable(self, InteractionSystemWrapper)
    
    -- Store as global instance
    globalInstance = self
    
    return self
end

-- Load the primary interaction system (InteractionManager)
function InteractionSystemWrapper:LoadPrimarySystem()
    local primarySystem = self:SafeRequire(game.StarterPlayer.StarterPlayerScripts.client.interaction.InteractionManager, "InteractionManager")
    
    if primarySystem and typeof(primarySystem.new) == "function" then
        local instance = primarySystem.new()
        if instance and instance.Initialize and instance:Initialize() then
            self.systemState.primarySystem = instance
            print("[InteractionSystemWrapper] Primary InteractionManager loaded successfully")
            return true
        else
            warn("[InteractionSystemWrapper] Primary system initialization failed")
        end
    end
    
    return false
end

-- Load fallback systems for backward compatibility
function InteractionSystemWrapper:LoadFallbackSystems()
    local fallbacks = {}
    
    -- Load fallback systems based on configuration
    for _, fallbackName in ipairs(INTERACTION_CONFIG.FALLBACK_SYSTEMS) do
        if fallbackName == "ItemInteractionClient" then
            local itemInteractionClient = self:SafeRequire(game.StarterPlayer.StarterPlayerScripts.client.interaction.ItemInteractionClient, "ItemInteractionClient")
            if itemInteractionClient then
                fallbacks.itemInteractionClient = itemInteractionClient
                print("[InteractionSystemWrapper] Loaded ItemInteractionClient fallback")
            end
        end
    end
    
    -- If no configured fallbacks work, try the minimal fallback
    if self:CountTable(fallbacks) == 0 then
        fallbacks.minimalFallback = self:CreateMinimalFallback()
        print("[InteractionSystemWrapper] Created minimal fallback system")
    end
    
    self.systemState.fallbackSystems = fallbacks
    print(string.format("[InteractionSystemWrapper] Loaded %d fallback systems", self:CountTable(fallbacks)))
end

-- Create minimal fallback system
function InteractionSystemWrapper:CreateMinimalFallback()
    return {
        new = function()
            return {
                Initialize = function(self)
                    print("[MinimalInteractionSystem] Minimal system active - limited functionality")
                    self:ShowWarningNotification()
                    return true
                end,
                
                Update = function(self) end,
                
                ShowInteractionUI = function(self, item)
                    print("[MinimalInteractionSystem] Interaction attempted with:", item and item.Name or "unknown")
                    self:ShowInteractionNotification("Interaction system is in minimal mode")
                end,
                
                HideInteractionUI = function(self) end,
                
                Cleanup = function(self)
                    print("[MinimalInteractionSystem] Cleanup called")
                end,
                
                ShowWarningNotification = function(self)
                    local Players = game:GetService("Players")
                    local player = Players.LocalPlayer
                    local playerGui = player:FindFirstChild("PlayerGui")
                    
                    if playerGui then
                        local screenGui = Instance.new("ScreenGui")
                        screenGui.Name = "InteractionSystemWarning"
                        screenGui.ResetOnSpawn = false
                        screenGui.Parent = playerGui
                        
                        local frame = Instance.new("Frame")
                        frame.Size = UDim2.new(0, 400, 0, 100)
                        frame.Position = UDim2.new(0.5, -200, 0, 20)
                        frame.BackgroundColor3 = SystemConfig.UI_THEME.WARNING_COLOR
                        frame.BorderSizePixel = 0
                        frame.Parent = screenGui
                        
                        local corner = Instance.new("UICorner")
                        corner.CornerRadius = UDim.new(0, 8)
                        corner.Parent = frame
                        
                        local label = Instance.new("TextLabel")
                        label.Size = UDim2.new(1, -20, 1, -20)
                        label.Position = UDim2.new(0, 10, 0, 10)
                        label.BackgroundTransparency = 1
                        label.TextColor3 = SystemConfig.UI_THEME.TEXT_COLOR
                        label.TextSize = 16
                        label.Font = SystemConfig.UI_THEME.PRIMARY_FONT
                        label.Text = "⚠️ Interaction System: Minimal Mode\nSome features may not work properly"
                        label.TextWrapped = true
                        label.Parent = frame
                        
                        -- Auto-hide after configured duration
                        task.spawn(function()
                            task.wait(10)
                            if screenGui and screenGui.Parent then
                                screenGui:Destroy()
                            end
                        end)
                    end
                end,
                
                ShowInteractionNotification = function(self, message)
                    print("[MinimalInteractionSystem]", message)
                end
            }
        end
    }
end

-- Set up global API functions specific to interaction system
function InteractionSystemWrapper:SetupGlobalAPI()
    -- Call parent setup first
    BaseSystemWrapper.SetupGlobalAPI(self)
    
    -- Add interaction-specific API functions
    self.globalAPI.ShowInteractionUI = function(item)
        return self:RouteCall("ShowInteractionUI", item)
    end
    
    self.globalAPI.HideInteractionUI = function()
        return self:RouteCall("HideInteractionUI")
    end
    
    self.globalAPI.UpdateInteractionTarget = function(target)
        return self:RouteCall("UpdateTarget", target)
    end
    
    self.globalAPI.GetCurrentTarget = function()
        return self:RouteCall("GetCurrentTarget")
    end
    
    self.globalAPI.SetInteractionDistance = function(distance)
        return self:RouteCall("SetInteractionDistance", distance)
    end
    
    print("[InteractionSystemWrapper] Interaction-specific global API configured")
end

-- Check if primary system is healthy (interaction-specific checks)
function InteractionSystemWrapper:CheckPrimarySystemHealth()
    if not self.systemState.primarySystem then
        return false
    end
    
    -- Check if the system is still active
    if self.systemState.primarySystem.isActive == false then
        return false
    end
    
    -- Check if the player still exists
    local player = Players.LocalPlayer
    if not player then
        return false
    end
    
    -- Check if the system's update loop is still running
    if self.systemState.primarySystem.lastUpdateTime then
        local timeSinceUpdate = tick() - self.systemState.primarySystem.lastUpdateTime
        if timeSinceUpdate > 5 then -- 5 seconds without update indicates problem
            return false
        end
    end
    
    return true
end

-- Global functions for easy access (backward compatibility)
function InteractionSystemWrapper.Initialize()
    local instance = InteractionSystemWrapper.GetGlobalInstance()
    return instance:Initialize()
end

function InteractionSystemWrapper.GetGlobalInstance()
    if not globalInstance then
        globalInstance = InteractionSystemWrapper.new()
        globalInstance:Initialize()
    end
    return globalInstance
end

function InteractionSystemWrapper.ShowInteractionUI(item)
    local instance = InteractionSystemWrapper.GetGlobalInstance()
    return instance.globalAPI.ShowInteractionUI(item)
end

function InteractionSystemWrapper.HideInteractionUI()
    local instance = InteractionSystemWrapper.GetGlobalInstance()
    return instance.globalAPI.HideInteractionUI()
end

function InteractionSystemWrapper.UpdateInteractionTarget(target)
    local instance = InteractionSystemWrapper.GetGlobalInstance()
    return instance.globalAPI.UpdateInteractionTarget(target)
end

function InteractionSystemWrapper.GetCurrentTarget()
    local instance = InteractionSystemWrapper.GetGlobalInstance()
    return instance.globalAPI.GetCurrentTarget()
end

function InteractionSystemWrapper.GetSystemStatus()
    local instance = InteractionSystemWrapper.GetGlobalInstance()
    return instance:GetSystemStatus()
end

-- Utility function to check system health
function InteractionSystemWrapper.CheckSystemHealth()
    local instance = InteractionSystemWrapper.GetGlobalInstance()
    local status = instance:GetSystemStatus()
    
    return {
        unifiedAvailable = status.activeSystem == "primary",
        legacyAvailable = status.availableSystems.fallbacks > 0,
        healthStatus = status.healthStatus,
        activeSystem = status.activeSystem,
        recommendedAction = status.healthStatus == "failed" and "Restart required" or "System operational"
    }
end

-- Backward compatibility aliases
InteractionSystemWrapper.ShowInteraction = InteractionSystemWrapper.ShowInteractionUI
InteractionSystemWrapper.HideInteraction = InteractionSystemWrapper.HideInteractionUI
InteractionSystemWrapper.UpdateTarget = InteractionSystemWrapper.UpdateInteractionTarget

return InteractionSystemWrapper 