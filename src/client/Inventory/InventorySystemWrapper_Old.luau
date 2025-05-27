-- InventorySystemWrapper.luau
-- Smart wrapper that routes to the best available inventory system
-- Provides backward compatibility while enabling migration to the new unified system

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Configuration: Set to true to use the new unified system
local USE_UNIFIED_SYSTEM = true

-- Simplified fallback strategy - only keep essential systems
local FALLBACK_MODULES = {
    {name = "InventoryManager", isUnified = true},
    {name = "InventoryUI", isLegacy = true}, -- Keep as primary legacy fallback
    -- Removed: Multiple conflicting inventory loaders and handlers
}

local InventorySystemWrapper = {}
InventorySystemWrapper.__index = InventorySystemWrapper

-- Global instance for easy access
local globalInstance = nil

function InventorySystemWrapper.new()
    if globalInstance then
        return globalInstance
    end
    
    local self = setmetatable({}, InventorySystemWrapper)
    
    -- Core properties
    self.activeSystem = nil
    self.systemType = "none"
    self.isInitialized = false
    self.player = Players.LocalPlayer
    
    -- Callbacks
    self.OnItemSelected = nil
    
    -- Store as global instance
    globalInstance = self
    
    return self
end

function InventorySystemWrapper:Initialize()
    print("[InventorySystemWrapper] Initializing...")
    
    if self.isInitialized then
        print("[InventorySystemWrapper] Already initialized")
        return true
    end
    
    -- Try to load the best available system
    local success = self:LoadBestSystem()
    
    if success then
        self.isInitialized = true
        print("[InventorySystemWrapper] Initialization complete using", self.systemType, "system")
        return true
    else
        warn("[InventorySystemWrapper] Failed to initialize any inventory system")
        return false
    end
end

function InventorySystemWrapper:LoadBestSystem()
    -- Try unified system first if enabled
    if USE_UNIFIED_SYSTEM then
        local success = self:TryLoadUnifiedSystem()
        if success then
            return true
        end
        print("[InventorySystemWrapper] Unified system failed, trying fallbacks...")
    end
    
    -- Try legacy systems
    for _, moduleInfo in ipairs(FALLBACK_MODULES) do
        if moduleInfo.isLegacy then
            local success = self:TryLoadLegacySystem(moduleInfo.name)
            if success then
                return true
            end
        end
    end
    
    warn("[InventorySystemWrapper] No inventory systems could be loaded")
    return false
end

function InventorySystemWrapper:TryLoadUnifiedSystem()
    local success, result = pcall(function()
        -- Try to load from the new location
        local inventoryManager = require(script.Parent.InventoryManager)
        local instance = inventoryManager.new()
        
        if instance and instance.Initialize then
            local initSuccess = instance:Initialize()
            if initSuccess then
                self.activeSystem = instance
                self.systemType = "unified"
                
                -- Set up callbacks
                instance.OnItemSelected = function(itemName, itemData)
                    if self.OnItemSelected then
                        self.OnItemSelected(itemName, itemData)
                    end
                end
                
                print("[InventorySystemWrapper] Successfully loaded unified InventoryManager")
                return true
            end
        end
        return false
    end)
    
    if success and result then
        return true
    else
        if result then
            warn("[InventorySystemWrapper] Unified system error:", result)
        end
        return false
    end
end

function InventorySystemWrapper:TryLoadLegacySystem(moduleName)
    local success, result = pcall(function()
        -- Try SharedModule first
        local shared = ReplicatedStorage:FindFirstChild("shared")
        if shared then
            local sharedModule = require(shared)
            if sharedModule and sharedModule[moduleName] then
                local legacySystem = sharedModule[moduleName]
                
                -- Check if it's a functional module
                if type(legacySystem) == "table" then
                    -- Try to initialize if it has an Initialize method
                    if legacySystem.Initialize and not legacySystem._isInitialized then
                        legacySystem.Initialize()
                        legacySystem._isInitialized = true
                    end
                    
                    self.activeSystem = legacySystem
                    self.systemType = "legacy_" .. moduleName
                    
                    -- Set up callbacks if supported
                    if legacySystem.OnItemSelected ~= nil then
                        legacySystem.OnItemSelected = function(itemName, itemData)
                            if self.OnItemSelected then
                                self.OnItemSelected(itemName, itemData)
                            end
                        end
                    end
                    
                    print("[InventorySystemWrapper] Successfully loaded legacy system:", moduleName)
                    return true
                end
            end
        end
        
        return false
    end)
    
    if success and result then
        return true
    else
        if result then
            warn("[InventorySystemWrapper] Legacy system error for", moduleName .. ":", result)
        end
        return false
    end
end

-- Public API methods that route to the active system
function InventorySystemWrapper:Show()
    if not self.activeSystem then
        warn("[InventorySystemWrapper] No active system to show")
        return
    end
    
    if self.activeSystem.Show then
        self.activeSystem:Show()
    elseif self.activeSystem.show then
        self.activeSystem.show()
    else
        warn("[InventorySystemWrapper] Active system has no Show method")
    end
end

function InventorySystemWrapper:Hide()
    if not self.activeSystem then
        return
    end
    
    if self.activeSystem.Hide then
        self.activeSystem:Hide()
    elseif self.activeSystem.hide then
        self.activeSystem.hide()
    end
end

function InventorySystemWrapper:Toggle()
    if not self.activeSystem then
        warn("[InventorySystemWrapper] No active system to toggle")
        return
    end
    
    if self.activeSystem.Toggle then
        self.activeSystem:Toggle()
    elseif self.activeSystem.toggle then
        self.activeSystem.toggle()
    else
        -- Fallback: try show/hide
        if self.activeSystem.isVisible or (self.activeSystem._isVisible) then
            self:Hide()
        else
            self:Show()
        end
    end
end

function InventorySystemWrapper:UpdateInventory(inventory, currency)
    if not self.activeSystem then
        return
    end
    
    if self.activeSystem.UpdateInventory then
        self.activeSystem:UpdateInventory(inventory, currency)
    elseif self.activeSystem.updateInventory then
        self.activeSystem.updateInventory(inventory, currency)
    end
end

function InventorySystemWrapper:RefreshInventory()
    if not self.activeSystem then
        return
    end
    
    if self.activeSystem.RefreshInventory then
        self.activeSystem:RefreshInventory()
    elseif self.activeSystem.refreshInventory then
        self.activeSystem.refreshInventory()
    end
end

-- Utility function to check system health
function InventorySystemWrapper.CheckSystemHealth()
    local results = {
        unifiedAvailable = false,
        legacyAvailable = false,
        recommendedAction = ""
    }
    
    -- Check unified system
    local unifiedSuccess = pcall(function()
        return require(script.Parent.InventoryManager)
    end)
    results.unifiedAvailable = unifiedSuccess
    
    -- Check legacy systems
    local legacyCount = 0
    for _, moduleInfo in ipairs(FALLBACK_MODULES) do
        if moduleInfo.isLegacy then
            local success = pcall(function()
                local shared = ReplicatedStorage:FindFirstChild("shared")
                if shared then
                    local sharedModule = require(shared)
                    return sharedModule and sharedModule[moduleInfo.name]
                end
                return false
            end)
            if success then
                legacyCount = legacyCount + 1
            end
        end
    end
    results.legacyAvailable = legacyCount > 0
    
    -- Determine recommendation
    if results.unifiedAvailable then
        results.recommendedAction = "✅ Unified system available - optimal performance"
    elseif results.legacyAvailable then
        results.recommendedAction = "⚠️ Using legacy fallback - consider updating"
    else
        results.recommendedAction = "❌ No inventory systems available - check installation"
    end
    
    return results
end

-- Global functions for easy access
function InventorySystemWrapper.GetGlobalInstance()
    if not globalInstance then
        globalInstance = InventorySystemWrapper.new()
        globalInstance:Initialize()
    end
    return globalInstance
end

function InventorySystemWrapper.ShowInventory()
    local instance = InventorySystemWrapper.GetGlobalInstance()
    instance:Show()
end

function InventorySystemWrapper.HideInventory()
    local instance = InventorySystemWrapper.GetGlobalInstance()
    instance:Hide()
end

function InventorySystemWrapper.ToggleInventory()
    local instance = InventorySystemWrapper.GetGlobalInstance()
    instance:Toggle()
end

function InventorySystemWrapper.UpdateGlobalInventory(inventory, currency)
    local instance = InventorySystemWrapper.GetGlobalInstance()
    instance:UpdateInventory(inventory, currency)
end

function InventorySystemWrapper.SetGlobalItemSelectedCallback(callback)
    local instance = InventorySystemWrapper.GetGlobalInstance()
    instance.OnItemSelected = callback
end

-- Debug function
function InventorySystemWrapper.DebugInfo()
    local instance = InventorySystemWrapper.GetGlobalInstance()
    local health = InventorySystemWrapper.CheckSystemHealth()
    
    print("=== Inventory System Debug Info ===")
    print("Wrapper initialized:", instance.isInitialized)
    print("Active system type:", instance.systemType)
    print("Active system:", instance.activeSystem ~= nil and "loaded" or "none")
    print("Unified available:", health.unifiedAvailable)
    print("Legacy available:", health.legacyAvailable)
    print("Recommendation:", health.recommendedAction)
    print("=====================================")
    
    return {
        initialized = instance.isInitialized,
        systemType = instance.systemType,
        hasActiveSystem = instance.activeSystem ~= nil,
        health = health
    }
end

-- Auto-initialize if in client environment
if RunService:IsClient() then
    task.spawn(function()
        task.wait(1) -- Give other systems time to load
        local instance = InventorySystemWrapper.GetGlobalInstance()
        print("[InventorySystemWrapper] Auto-initialized with system type:", instance.systemType)
    end)
end

return InventorySystemWrapper 