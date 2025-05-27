-- InteractionSystemWrapper.luau
-- Smart wrapper that routes to the best available interaction system
-- Provides backward compatibility while enabling migration to the new unified system

local RunService = game:GetService("RunService")

-- Configuration: Set to true to use the new unified system
local USE_UNIFIED_SYSTEM = true

-- Simplified fallback strategy - only keep essential systems
local FALLBACK_MODULES = {
    {name = "InteractionManager", isUnified = true},
    {name = "ItemInteractionClient", isLegacy = true}, -- Keep as primary legacy fallback
    -- Removed: InteractionSystemModule_enhanced, InteractionSystemModule_emergency, InteractionSystemModule_new
    -- These are redundant and create unnecessary complexity
}

local InteractionSystemWrapper = {}

function InteractionSystemWrapper.new()
    print("[InteractionSystemWrapper] Initializing interaction system...")
    
    local selectedModule = nil
    local selectedModuleName = ""
    
    if USE_UNIFIED_SYSTEM then
        -- Try the new unified system first
        local success, result = pcall(function()
            return require(script.Parent.InteractionManager)
        end)
        
        if success and result then
            selectedModule = result
            selectedModuleName = "InteractionManager (Unified)"
            print("[InteractionSystemWrapper] Using unified InteractionManager")
        else
            warn("[InteractionSystemWrapper] Failed to load unified system:", result)
        end
    end
    
    -- If unified system failed or not enabled, try fallbacks
    if not selectedModule then
        print("[InteractionSystemWrapper] Trying fallback systems...")
        
        for _, moduleInfo in ipairs(FALLBACK_MODULES) do
            if moduleInfo.isUnified and not USE_UNIFIED_SYSTEM then
                -- Skip unified if disabled
                continue
            end
            
            local success, result = pcall(function()
                local moduleScript = script.Parent:FindFirstChild(moduleInfo.name)
                if not moduleScript then
                    error("Module not found: " .. moduleInfo.name)
                end
                return require(moduleScript)
            end)
            
            if success and result then
                selectedModule = result
                selectedModuleName = moduleInfo.name
                
                if moduleInfo.isLegacy then
                    warn("[InteractionSystemWrapper] Using legacy fallback:", moduleInfo.name)
                else
                    print("[InteractionSystemWrapper] Using fallback system:", moduleInfo.name)
                end
                break
            else
                warn("[InteractionSystemWrapper] Failed to load", moduleInfo.name .. ":", result)
            end
        end
    end
    
    -- If all else fails, create a minimal fallback
    if not selectedModule then
        warn("[InteractionSystemWrapper] All interaction systems failed! Creating minimal fallback")
        selectedModule = InteractionSystemWrapper.CreateMinimalFallback()
        selectedModuleName = "Minimal Fallback"
    end
    
    -- Create instance and add metadata
    local instance = selectedModule.new()
    instance._wrapperInfo = {
        selectedSystem = selectedModuleName,
        isUnified = selectedModuleName:find("InteractionManager") ~= nil,
        isLegacy = selectedModuleName:find("ItemInteractionClient") ~= nil,
        isFallback = selectedModuleName == "Minimal Fallback"
    }
    
    -- Add wrapper methods
    instance.GetSystemInfo = function(self)
        return self._wrapperInfo
    end
    
    instance.ReloadSystem = function(self)
        warn("[InteractionSystemWrapper] System reload requested - this requires manual intervention")
        return false
    end
    
    print("[InteractionSystemWrapper] Successfully initialized:", selectedModuleName)
    return instance
end

function InteractionSystemWrapper.CreateMinimalFallback()
    print("[InteractionSystemWrapper] Creating minimal fallback system")
    
    return {
        new = function()
            return {
                Initialize = function(self)
                    print("[MinimalInteractionSystem] Minimal system active - limited functionality")
                    
                    -- Create a simple notification
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
                        frame.BackgroundColor3 = Color3.fromRGB(200, 100, 0)
                        frame.BorderSizePixel = 0
                        frame.Parent = screenGui
                        
                        local corner = Instance.new("UICorner")
                        corner.CornerRadius = UDim.new(0, 8)
                        corner.Parent = frame
                        
                        local label = Instance.new("TextLabel")
                        label.Size = UDim2.new(1, -20, 1, -20)
                        label.Position = UDim2.new(0, 10, 0, 10)
                        label.BackgroundTransparency = 1
                        label.TextColor3 = Color3.fromRGB(255, 255, 255)
                        label.TextSize = 16
                        label.Font = Enum.Font.GothamBold
                        label.Text = "⚠️ Interaction System: Minimal Mode\nSome features may not work properly"
                        label.TextWrapped = true
                        label.Parent = frame
                        
                        -- Auto-hide after 10 seconds
                        task.spawn(function()
                            task.wait(10)
                            if screenGui and screenGui.Parent then
                                screenGui:Destroy()
                            end
                        end)
                    end
                    
                    return true
                end,
                
                Update = function(self) end,
                
                ShowInteractionUI = function(self, item)
                    print("[MinimalInteractionSystem] Interaction attempted with:", item and item.Name or "unknown")
                end,
                
                HideInteractionUI = function(self) end,
                
                Cleanup = function(self)
                    print("[MinimalInteractionSystem] Cleanup called")
                end,
                
                _wrapperInfo = {
                    selectedSystem = "Minimal Fallback",
                    isUnified = false,
                    isLegacy = true,
                    isFallback = true
                }
            }
        end
    }
end

-- Utility function to check system health
function InteractionSystemWrapper.CheckSystemHealth()
    local results = {
        unifiedAvailable = false,
        legacyAvailable = false,
        archivedModulesCount = 0,
        recommendedAction = ""
    }
    
    -- Check unified system
    local unifiedSuccess = pcall(function()
        return require(script.Parent.InteractionManager)
    end)
    results.unifiedAvailable = unifiedSuccess
    
    -- Check legacy systems
    local legacyCount = 0
    for _, moduleInfo in ipairs(FALLBACK_MODULES) do
        if moduleInfo.isLegacy then
            local success = pcall(function()
                local moduleScript = script.Parent:FindFirstChild(moduleInfo.name)
                return moduleScript and require(moduleScript)
            end)
            if success then
                legacyCount = legacyCount + 1
            end
        end
    end
    results.legacyAvailable = legacyCount > 0
    
    -- Check for archived modules
    local legacyFolder = script.Parent:FindFirstChild("legacy")
    if legacyFolder then
        for _, child in ipairs(legacyFolder:GetChildren()) do
            if child:IsA("ModuleScript") then
                results.archivedModulesCount = results.archivedModulesCount + 1
            end
        end
    end
    
    -- Determine recommendation
    if results.unifiedAvailable then
        if results.archivedModulesCount > 0 then
            results.recommendedAction = "System optimal - unified system active, legacy modules archived"
        else
            results.recommendedAction = "System healthy - unified system available, consider archiving legacy modules"
        end
    elseif results.legacyAvailable then
        results.recommendedAction = "Using legacy fallback - unified system may have issues"
    else
        results.recommendedAction = "CRITICAL: No interaction systems available"
    end
    
    return results
end

-- Global debug function
_G.InteractionSystemDebug = {
    CheckHealth = InteractionSystemWrapper.CheckSystemHealth,
    GetCurrentSystem = function()
        if _G.InteractionSystem and _G.InteractionSystem.GetSystemInfo then
            return _G.InteractionSystem:GetSystemInfo()
        end
        return {error = "No active interaction system"}
    end,
    ForceReload = function()
        warn("InteractionSystem force reload not implemented - requires manual restart")
        return false
    end
}

return InteractionSystemWrapper 