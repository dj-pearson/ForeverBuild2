-- InventorySystemWrapper.luau
-- Smart routing wrapper for the unified inventory system
-- Now inherits from BaseSystemWrapper for consistency and better functionality

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Import the standardized base wrapper and configuration
local BaseSystemWrapper = require(ReplicatedStorage.src.shared.core.BaseSystemWrapper)
local SystemConfig = require(ReplicatedStorage.src.shared.core.SystemConfig)

local InventorySystemWrapper = setmetatable({}, BaseSystemWrapper)
InventorySystemWrapper.__index = InventorySystemWrapper

-- Get inventory-specific configuration
local INVENTORY_CONFIG = SystemConfig.Utils.GetSystemConfig("INVENTORY")

-- Global instance for easy access
local globalInstance = nil

-- Create new inventory system wrapper instance
function InventorySystemWrapper.new()
    if globalInstance then
        return globalInstance
    end
    
    local self = BaseSystemWrapper.new("InventorySystem", {
        HEALTH_CHECK_INTERVAL = INVENTORY_CONFIG.HEALTH_CHECK_INTERVAL or 30,
        DEBUG_MODE = SystemConfig.GLOBAL.DEBUG_MODE,
        MAX_RETRY_ATTEMPTS = SystemConfig.GLOBAL.MAX_RETRY_ATTEMPTS,
        RETRY_DELAY = SystemConfig.GLOBAL.RETRY_DELAY
    })
    
    -- Set up inventory-specific metatable
    setmetatable(self, InventorySystemWrapper)
    
    -- Inventory-specific properties
    self.isVisible = false
    self.currentInventory = {}
    self.currentCurrency = 0
    
    -- Store as global instance
    globalInstance = self
    
    return self
end

-- Load the primary inventory system (InventoryManager)
function InventorySystemWrapper:LoadPrimarySystem()
    local primarySystem = self:SafeRequire(script.Parent.InventoryManager, "InventoryManager")
    
    if primarySystem and typeof(primarySystem.new) == "function" then
        local instance = primarySystem.new()
        if instance and instance.Initialize and instance:Initialize() then
            self.systemState.primarySystem = instance
            
            -- Set up callbacks
            if instance.OnItemSelected then
                instance.OnItemSelected = function(itemName, itemData)
                    self:OnItemSelected(itemName, itemData)
                end
            end
            
            print("[InventorySystemWrapper] Primary InventoryManager loaded successfully")
            return true
        else
            warn("[InventorySystemWrapper] Primary system initialization failed")
        end
    end
    
    return false
end

-- Load fallback systems for backward compatibility
function InventorySystemWrapper:LoadFallbackSystems()
    local fallbacks = {}
    
    -- Load fallback systems based on configuration
    for _, fallbackName in ipairs(INVENTORY_CONFIG.FALLBACK_SYSTEMS) do
        if fallbackName == "InventoryUI" then
            -- Try SharedModule InventoryUI
            local sharedModule = self:SafeRequire(ReplicatedStorage:WaitForChild("shared", 5), "SharedModule")
            if sharedModule and sharedModule.InventoryUI then
                fallbacks.sharedInventoryUI = sharedModule.InventoryUI
                print("[InventorySystemWrapper] Loaded SharedModule.InventoryUI fallback")
            end
        end
    end
    
    -- If no configured fallbacks work, try the minimal fallback
    if self:CountTable(fallbacks) == 0 then
        fallbacks.minimalFallback = self:CreateMinimalFallback()
        print("[InventorySystemWrapper] Created minimal fallback system")
    end
    
    self.systemState.fallbackSystems = fallbacks
    print(string.format("[InventorySystemWrapper] Loaded %d fallback systems", self:CountTable(fallbacks)))
end

-- Create minimal fallback system
function InventorySystemWrapper:CreateMinimalFallback()
    return {
        new = function()
            return {
                Initialize = function(self)
                    print("[MinimalInventorySystem] Minimal system active - limited functionality")
                    self:ShowWarningNotification()
                    return true
                end,
                
                Show = function(self)
                    print("[MinimalInventorySystem] Show requested - minimal mode")
                    self:ShowInventoryNotification("Inventory system is in minimal mode")
                end,
                
                Hide = function(self)
                    print("[MinimalInventorySystem] Hide requested")
                end,
                
                Toggle = function(self)
                    print("[MinimalInventorySystem] Toggle requested - minimal mode")
                    self:ShowInventoryNotification("Inventory system is in minimal mode")
                end,
                
                UpdateInventory = function(self, inventory, currency)
                    print("[MinimalInventorySystem] Inventory updated:", #(inventory or {}), "items,", currency or 0, "currency")
                end,
                
                Cleanup = function(self)
                    print("[MinimalInventorySystem] Cleanup called")
                end,
                
                ShowWarningNotification = function(self)
                    local Players = game:GetService("Players")
                    local player = Players.LocalPlayer
                    local playerGui = player:FindFirstChild("PlayerGui")
                    
                    if playerGui then
                        local screenGui = Instance.new("ScreenGui")
                        screenGui.Name = "InventorySystemWarning"
                        screenGui.ResetOnSpawn = false
                        screenGui.Parent = playerGui
                        
                        local frame = Instance.new("Frame")
                        frame.Size = UDim2.new(0, 400, 0, 100)
                        frame.Position = UDim2.new(0.5, -200, 0, 120)
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
                        label.Text = "📦 Inventory System: Minimal Mode\nSome features may not work properly"
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
                
                ShowInventoryNotification = function(self, message)
                    print("[MinimalInventorySystem]", message)
                end
            }
        end
    }
end

-- Set up global API functions specific to inventory system
function InventorySystemWrapper:SetupGlobalAPI()
    -- Call parent setup first
    BaseSystemWrapper.SetupGlobalAPI(self)
    
    -- Add inventory-specific API functions
    self.globalAPI.ShowInventory = function()
        return self:RouteCall("Show")
    end
    
    self.globalAPI.HideInventory = function()
        return self:RouteCall("Hide")
    end
    
    self.globalAPI.ToggleInventory = function()
        return self:RouteCall("Toggle")
    end
    
    self.globalAPI.UpdateInventory = function(inventory, currency)
        self.currentInventory = inventory or {}
        self.currentCurrency = currency or 0
        return self:RouteCall("UpdateInventory", inventory, currency)
    end
    
    self.globalAPI.GetCurrentInventory = function()
        return self.currentInventory, self.currentCurrency
    end
    
    self.globalAPI.IsVisible = function()
        return self.isVisible
    end
    
    print("[InventorySystemWrapper] Inventory-specific global API configured")
end

-- Check if primary system is healthy (inventory-specific checks)
function InventorySystemWrapper:CheckPrimarySystemHealth()
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
    
    -- Check if the system's UI is still accessible
    if player:FindFirstChild("PlayerGui") then
        local inventoryUI = player.PlayerGui:FindFirstChild("InventoryUI")
        -- It's okay if UI doesn't exist yet, but if it exists it should be functional
        if inventoryUI and not inventoryUI.Parent then
            return false
        end
    end
    
    return true
end

-- Inventory-specific callback handling
function InventorySystemWrapper:OnItemSelected(itemName, itemData)
    if self.config.DEBUG_MODE then
        print("[InventorySystemWrapper] Item selected:", itemName, itemData)
    end
    
    -- Could add global item selection handling here
end

-- Global functions for easy access (backward compatibility)
function InventorySystemWrapper.Initialize()
    local instance = InventorySystemWrapper.GetGlobalInstance()
    return instance:Initialize()
end

function InventorySystemWrapper.GetGlobalInstance()
    if not globalInstance then
        globalInstance = InventorySystemWrapper.new()
        globalInstance:Initialize()
    end
    return globalInstance
end

function InventorySystemWrapper.ShowInventory()
    local instance = InventorySystemWrapper.GetGlobalInstance()
    return instance.globalAPI.ShowInventory()
end

function InventorySystemWrapper.HideInventory()
    local instance = InventorySystemWrapper.GetGlobalInstance()
    return instance.globalAPI.HideInventory()
end

function InventorySystemWrapper.ToggleInventory()
    local instance = InventorySystemWrapper.GetGlobalInstance()
    return instance.globalAPI.ToggleInventory()
end

function InventorySystemWrapper.UpdateInventory(inventory, currency)
    local instance = InventorySystemWrapper.GetGlobalInstance()
    return instance.globalAPI.UpdateInventory(inventory, currency)
end

function InventorySystemWrapper.GetCurrentInventory()
    local instance = InventorySystemWrapper.GetGlobalInstance()
    return instance.globalAPI.GetCurrentInventory()
end

function InventorySystemWrapper.IsVisible()
    local instance = InventorySystemWrapper.GetGlobalInstance()
    return instance.globalAPI.IsVisible()
end

function InventorySystemWrapper.GetSystemStatus()
    local instance = InventorySystemWrapper.GetGlobalInstance()
    return instance:GetSystemStatus()
end

-- Utility function to check system health
function InventorySystemWrapper.CheckSystemHealth()
    local instance = InventorySystemWrapper.GetGlobalInstance()
    local status = instance:GetSystemStatus()
    
    return {
        unifiedAvailable = status.activeSystem == "primary",
        legacyAvailable = status.availableSystems.fallbacks > 0,
        healthStatus = status.healthStatus,
        activeSystem = status.activeSystem,
        currentItems = #instance.currentInventory,
        currentCurrency = instance.currentCurrency,
        recommendedAction = status.healthStatus == "failed" and "Restart required" or "System operational"
    }
end

-- Backward compatibility aliases
InventorySystemWrapper.Show = InventorySystemWrapper.ShowInventory
InventorySystemWrapper.Hide = InventorySystemWrapper.HideInventory
InventorySystemWrapper.Toggle = InventorySystemWrapper.ToggleInventory

return InventorySystemWrapper 