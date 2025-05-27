-- PlacementSystemWrapper.luau
-- Smart routing wrapper for the unified placement system
-- Inherits from BaseSystemWrapper for consistency and better functionality

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Import the standardized base wrapper and configuration
local BaseSystemWrapper = require(ReplicatedStorage.src.shared.core.BaseSystemWrapper)
local SystemConfig = require(ReplicatedStorage.src.shared.core.SystemConfig)

local PlacementSystemWrapper = setmetatable({}, BaseSystemWrapper)
PlacementSystemWrapper.__index = PlacementSystemWrapper

-- Get placement-specific configuration
local PLACEMENT_CONFIG = SystemConfig.Utils.GetSystemConfig("PLACEMENT")

-- Global instance for easy access
local globalInstance = nil

-- Create new placement system wrapper instance
function PlacementSystemWrapper.new()
    if globalInstance then
        return globalInstance
    end
    
    local self = BaseSystemWrapper.new("PlacementSystem", {
        HEALTH_CHECK_INTERVAL = PLACEMENT_CONFIG.HEALTH_CHECK_INTERVAL or 30,
        DEBUG_MODE = SystemConfig.GLOBAL.DEBUG_MODE,
        MAX_RETRY_ATTEMPTS = SystemConfig.GLOBAL.MAX_RETRY_ATTEMPTS,
        RETRY_DELAY = SystemConfig.GLOBAL.RETRY_DELAY
    })
    
    -- Set up placement-specific metatable
    setmetatable(self, PlacementSystemWrapper)
    
    -- Placement-specific properties
    self.isPlacing = false
    self.currentItem = nil
    self.previewItem = nil
    self.placedItems = {}
    
    -- Store as global instance
    globalInstance = self
    
    return self
end

-- Load the primary placement system (PlacementCore)
function PlacementSystemWrapper:LoadPrimarySystem()
    local primarySystem = self:SafeRequire(script.Parent.PlacementCore, "PlacementCore")
    
    if primarySystem and typeof(primarySystem.new) == "function" then
        -- Get SharedModule for placement system initialization
        local sharedModule = self:SafeRequire(ReplicatedStorage:WaitForChild("shared", 5), "SharedModule")
        
        if sharedModule then
            local instance = primarySystem.new(sharedModule)
            if instance and instance.Initialize and instance:Initialize() then
                self.systemState.primarySystem = instance
                
                print("[PlacementSystemWrapper] Primary PlacementCore loaded successfully")
                return true
            else
                warn("[PlacementSystemWrapper] Primary system initialization failed")
            end
        else
            warn("[PlacementSystemWrapper] SharedModule not available for PlacementCore")
        end
    end
    
    return false
end

-- Load fallback systems for backward compatibility
function PlacementSystemWrapper:LoadFallbackSystems()
    local fallbacks = {}
    
    -- Load fallback systems based on configuration
    for _, fallbackName in ipairs(PLACEMENT_CONFIG.FALLBACK_SYSTEMS) do
        if fallbackName == "PlacementManager_Core" then
            -- Try PlacementManager_Core
            local fallbackSystem = self:SafeRequire(script.Parent.PlacementManager_Core, "PlacementManager_Core")
            if fallbackSystem and typeof(fallbackSystem.new) == "function" then
                local sharedModule = self:SafeRequire(ReplicatedStorage:WaitForChild("shared", 5), "SharedModule")
                if sharedModule then
                    local instance = fallbackSystem.new(sharedModule)
                    if instance then
                        fallbacks.placementManagerCore = instance
                        print("[PlacementSystemWrapper] Loaded PlacementManager_Core fallback")
                    end
                end
            end
        end
    end
    
    -- If no configured fallbacks work, try the minimal fallback
    if self:CountTable(fallbacks) == 0 then
        fallbacks.minimalFallback = self:CreateMinimalFallback()
        print("[PlacementSystemWrapper] Created minimal fallback system")
    end
    
    self.systemState.fallbackSystems = fallbacks
    print(string.format("[PlacementSystemWrapper] Loaded %d fallback systems", self:CountTable(fallbacks)))
end

-- Create minimal fallback system
function PlacementSystemWrapper:CreateMinimalFallback()
    return {
        new = function(sharedModule)
            return {
                Initialize = function(self)
                    print("[MinimalPlacementSystem] Minimal system active - limited functionality")
                    self:ShowWarningNotification()
                    return true
                end,
                
                StartPlacing = function(self, itemId)
                    print("[MinimalPlacementSystem] StartPlacing requested for:", itemId, "- minimal mode")
                    self:ShowPlacementNotification("Placement system is in minimal mode")
                end,
                
                StopPlacing = function(self)
                    print("[MinimalPlacementSystem] StopPlacing requested")
                end,
                
                PlaceItem = function(self, player, itemId, position, rotation)
                    print("[MinimalPlacementSystem] PlaceItem requested - minimal mode")
                    return false, "Placement system is in minimal mode"
                end,
                
                GetItemTemplate = function(self, itemId)
                    print("[MinimalPlacementSystem] GetItemTemplate requested for:", itemId)
                    return nil
                end,
                
                ShowItemInHand = function(self, itemId)
                    print("[MinimalPlacementSystem] ShowItemInHand requested for:", itemId)
                end,
                
                HideItemInHand = function(self)
                    print("[MinimalPlacementSystem] HideItemInHand requested")
                end,
                
                Cleanup = function(self)
                    print("[MinimalPlacementSystem] Cleanup called")
                end,
                
                ShowWarningNotification = function(self)
                    local Players = game:GetService("Players")
                    local player = Players.LocalPlayer
                    if not player then return end
                    
                    local playerGui = player:FindFirstChild("PlayerGui")
                    if playerGui then
                        local screenGui = Instance.new("ScreenGui")
                        screenGui.Name = "PlacementSystemWarning"
                        screenGui.ResetOnSpawn = false
                        screenGui.Parent = playerGui
                        
                        local frame = Instance.new("Frame")
                        frame.Size = UDim2.new(0, 400, 0, 100)
                        frame.Position = UDim2.new(0.5, -200, 0, 160)
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
                        label.Text = "🏗️ Placement System: Minimal Mode\nSome features may not work properly"
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
                
                ShowPlacementNotification = function(self, message)
                    print("[MinimalPlacementSystem]", message)
                end
            }
        end
    }
end

-- Set up global API functions specific to placement system
function PlacementSystemWrapper:SetupGlobalAPI()
    -- Call parent setup first
    BaseSystemWrapper.SetupGlobalAPI(self)
    
    -- Add placement-specific API functions
    self.globalAPI.StartPlacing = function(itemId)
        self.isPlacing = true
        self.currentItem = itemId
        return self:RouteCall("StartPlacing", itemId)
    end
    
    self.globalAPI.StopPlacing = function()
        self.isPlacing = false
        self.currentItem = nil
        return self:RouteCall("StopPlacing")
    end
    
    self.globalAPI.PlaceItem = function(player, itemId, position, rotation)
        local success, result = self:RouteCall("PlaceItem", player, itemId, position, rotation)
        if success then
            self.placedItems[result] = {
                itemId = itemId,
                position = position,
                rotation = rotation,
                placedTime = os.time()
            }
        end
        return success, result
    end
    
    self.globalAPI.GetItemTemplate = function(itemId)
        return self:RouteCall("GetItemTemplate", itemId)
    end
    
    self.globalAPI.ShowItemInHand = function(itemId)
        return self:RouteCall("ShowItemInHand", itemId)
    end
    
    self.globalAPI.HideItemInHand = function()
        return self:RouteCall("HideItemInHand")
    end
    
    self.globalAPI.IsPlacing = function()
        return self.isPlacing
    end
    
    self.globalAPI.GetCurrentItem = function()
        return self.currentItem
    end
    
    self.globalAPI.GetPlacedItems = function()
        return self.placedItems
    end
    
    print("[PlacementSystemWrapper] Placement-specific global API configured")
end

-- Check if primary system is healthy (placement-specific checks)
function PlacementSystemWrapper:CheckPrimarySystemHealth()
    if not self.systemState.primarySystem then
        return false
    end
    
    -- Check if the system is still active
    if self.systemState.primarySystem.isActive == false then
        return false
    end
    
    -- Check if the player still exists (for client-side)
    if RunService:IsClient() then
        local player = Players.LocalPlayer
        if not player then
            return false
        end
    end
    
    -- Check if placement folder exists (for server-side)
    if RunService:IsServer() then
        local workspace = game:GetService("Workspace")
        local worldItems = workspace:FindFirstChild("World_Items")
        if not worldItems then
            return false
        end
    end
    
    return true
end

-- Placement-specific callback handling
function PlacementSystemWrapper:OnItemPlaced(itemId, position, rotation)
    if self.config.DEBUG_MODE then
        print("[PlacementSystemWrapper] Item placed:", itemId, position, rotation)
    end
    
    -- Could add global placement tracking here
end

-- Global functions for easy access (backward compatibility)
function PlacementSystemWrapper.Initialize()
    local instance = PlacementSystemWrapper.GetGlobalInstance()
    return instance:Initialize()
end

function PlacementSystemWrapper.GetGlobalInstance()
    if not globalInstance then
        globalInstance = PlacementSystemWrapper.new()
        globalInstance:Initialize()
    end
    return globalInstance
end

function PlacementSystemWrapper.StartPlacing(itemId)
    local instance = PlacementSystemWrapper.GetGlobalInstance()
    return instance.globalAPI.StartPlacing(itemId)
end

function PlacementSystemWrapper.StopPlacing()
    local instance = PlacementSystemWrapper.GetGlobalInstance()
    return instance.globalAPI.StopPlacing()
end

function PlacementSystemWrapper.PlaceItem(player, itemId, position, rotation)
    local instance = PlacementSystemWrapper.GetGlobalInstance()
    return instance.globalAPI.PlaceItem(player, itemId, position, rotation)
end

function PlacementSystemWrapper.GetItemTemplate(itemId)
    local instance = PlacementSystemWrapper.GetGlobalInstance()
    return instance.globalAPI.GetItemTemplate(itemId)
end

function PlacementSystemWrapper.ShowItemInHand(itemId)
    local instance = PlacementSystemWrapper.GetGlobalInstance()
    return instance.globalAPI.ShowItemInHand(itemId)
end

function PlacementSystemWrapper.HideItemInHand()
    local instance = PlacementSystemWrapper.GetGlobalInstance()
    return instance.globalAPI.HideItemInHand()
end

function PlacementSystemWrapper.IsPlacing()
    local instance = PlacementSystemWrapper.GetGlobalInstance()
    return instance.globalAPI.IsPlacing()
end

function PlacementSystemWrapper.GetCurrentItem()
    local instance = PlacementSystemWrapper.GetGlobalInstance()
    return instance.globalAPI.GetCurrentItem()
end

function PlacementSystemWrapper.GetPlacedItems()
    local instance = PlacementSystemWrapper.GetGlobalInstance()
    return instance.globalAPI.GetPlacedItems()
end

function PlacementSystemWrapper.GetSystemStatus()
    local instance = PlacementSystemWrapper.GetGlobalInstance()
    return instance:GetSystemStatus()
end

-- Utility function to check system health
function PlacementSystemWrapper.CheckSystemHealth()
    local instance = PlacementSystemWrapper.GetGlobalInstance()
    local status = instance:GetSystemStatus()
    
    return {
        unifiedAvailable = status.activeSystem == "primary",
        legacyAvailable = status.availableSystems.fallbacks > 0,
        healthStatus = status.healthStatus,
        activeSystem = status.activeSystem,
        currentlyPlacing = instance.isPlacing,
        currentItem = instance.currentItem,
        placedItemsCount = instance:CountTable(instance.placedItems),
        recommendedAction = status.healthStatus == "failed" and "Restart required" or "System operational"
    }
end

-- Backward compatibility aliases
PlacementSystemWrapper.Place = PlacementSystemWrapper.PlaceItem
PlacementSystemWrapper.Start = PlacementSystemWrapper.StartPlacing
PlacementSystemWrapper.Stop = PlacementSystemWrapper.StopPlacing

return PlacementSystemWrapper 