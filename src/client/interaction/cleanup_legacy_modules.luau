-- cleanup_legacy_modules.luau
-- Script to safely archive legacy interaction modules
-- Run this after confirming the unified system works properly

local RunService = game:GetService("RunService")

-- Only run in Studio for safety
if not RunService:IsStudio() then
    error("This cleanup script should only be run in Roblox Studio")
end

local CleanupManager = {}

-- Modules to archive (move to legacy folder)
local MODULES_TO_ARCHIVE = {
    "InteractionSystemModule_emergency.lua",
    "InteractionSystemModule_enhanced.lua", 
    "InteractionSystemModule_new.lua",
    "InteractionSystemModule.lua" -- The original 1,581 line monster
}

-- Modules to evaluate separately (not auto-archived)
local MODULES_TO_EVALUATE = {
    "EnhancedPurchaseIntegration.luau",
    "EnhancedPurchaseSystem.luau",
    "UndoManager.luau",
    "FixItemTypes.luau",
    "CatalogItemUI.luau"
}

-- Core modules to keep
local CORE_MODULES = {
    "InteractionManager.luau",
    "InteractionSystemWrapper.luau", 
    "InteractionIntegrationTest.luau",
    "ItemInteractionClient.luau", -- Keep as legacy fallback
    "BottomPurchasePopup.luau" -- Keep for purchase functionality
}

function CleanupManager.AnalyzeCurrentState()
    print("=== INTERACTION SYSTEM CLEANUP ANALYSIS ===")
    
    local interactionFolder = script.Parent
    local totalFiles = 0
    local totalLines = 0
    
    print("\n📁 Current Files:")
    for _, child in ipairs(interactionFolder:GetChildren()) do
        if child:IsA("ModuleScript") or child:IsA("Script") then
            totalFiles = totalFiles + 1
            -- Note: Can't get line count in runtime, but we know from analysis
            print("  " .. child.Name)
        end
    end
    
    print(string.format("\n📊 Current State: %d files, ~7,000+ lines", totalFiles))
    print("📊 Target State: ~6 core files, ~2,500 lines")
    print("📊 Estimated Reduction: ~65% fewer lines, ~60% fewer files")
    
    print("\n🗂️ Modules to Archive:")
    for _, moduleName in ipairs(MODULES_TO_ARCHIVE) do
        local module = interactionFolder:FindFirstChild(moduleName)
        print("  " .. (module and "✅" or "❌") .. " " .. moduleName)
    end
    
    print("\n🔍 Modules to Evaluate Separately:")
    for _, moduleName in ipairs(MODULES_TO_EVALUATE) do
        local module = interactionFolder:FindFirstChild(moduleName)
        print("  " .. (module and "✅" or "❌") .. " " .. moduleName)
    end
    
    print("\n✅ Core Modules to Keep:")
    for _, moduleName in ipairs(CORE_MODULES) do
        local module = interactionFolder:FindFirstChild(moduleName)
        print("  " .. (module and "✅" or "❌") .. " " .. moduleName)
    end
end

function CleanupManager.TestSystemHealth()
    print("\n=== SYSTEM HEALTH CHECK ===")
    
    -- Test unified system
    local unifiedSuccess, unifiedResult = pcall(function()
        return require(script.Parent.InteractionManager)
    end)
    
    print("Unified System (InteractionManager):", unifiedSuccess and "✅ Working" or "❌ Failed")
    if not unifiedSuccess then
        warn("  Error:", unifiedResult)
    end
    
    -- Test wrapper
    local wrapperSuccess, wrapperResult = pcall(function()
        local wrapper = require(script.Parent.InteractionSystemWrapper)
        local instance = wrapper.new()
        local info = instance:GetSystemInfo()
        return info
    end)
    
    print("Wrapper System:", wrapperSuccess and "✅ Working" or "❌ Failed")
    if wrapperSuccess then
        print("  Selected System:", wrapperResult.selectedSystem)
        print("  Is Unified:", wrapperResult.isUnified)
    else
        warn("  Error:", wrapperResult)
    end
    
    -- Test legacy fallback
    local legacySuccess, legacyResult = pcall(function()
        return require(script.Parent.ItemInteractionClient)
    end)
    
    print("Legacy Fallback (ItemInteractionClient):", legacySuccess and "✅ Working" or "❌ Failed")
    if not legacySuccess then
        warn("  Error:", legacyResult)
    end
    
    return unifiedSuccess and wrapperSuccess
end

function CleanupManager.CreateLegacyFolder()
    local interactionFolder = script.Parent
    local legacyFolder = interactionFolder:FindFirstChild("legacy")
    
    if not legacyFolder then
        legacyFolder = Instance.new("Folder")
        legacyFolder.Name = "legacy"
        legacyFolder.Parent = interactionFolder
        print("✅ Created legacy folder")
    else
        print("✅ Legacy folder already exists")
    end
    
    return legacyFolder
end

function CleanupManager.ArchiveModule(moduleName, legacyFolder)
    local interactionFolder = script.Parent
    local module = interactionFolder:FindFirstChild(moduleName)
    
    if module then
        -- Check if already archived
        local existingArchive = legacyFolder:FindFirstChild(moduleName)
        if existingArchive then
            print("⚠️  " .. moduleName .. " already archived, skipping")
            return false
        end
        
        -- Clone to legacy folder
        local clone = module:Clone()
        clone.Parent = legacyFolder
        
        -- Remove original
        module:Destroy()
        
        print("✅ Archived: " .. moduleName)
        return true
    else
        print("❌ Not found: " .. moduleName)
        return false
    end
end

function CleanupManager.PerformCleanup()
    print("\n=== PERFORMING CLEANUP ===")
    
    -- First, test system health
    if not CleanupManager.TestSystemHealth() then
        error("❌ System health check failed! Cannot proceed with cleanup.")
    end
    
    print("✅ System health check passed")
    
    -- Create legacy folder
    local legacyFolder = CleanupManager.CreateLegacyFolder()
    
    -- Archive legacy modules
    local archivedCount = 0
    for _, moduleName in ipairs(MODULES_TO_ARCHIVE) do
        if CleanupManager.ArchiveModule(moduleName, legacyFolder) then
            archivedCount = archivedCount + 1
        end
    end
    
    print(string.format("\n✅ Cleanup complete! Archived %d modules", archivedCount))
    print("📁 Legacy modules moved to: " .. legacyFolder:GetFullName())
    
    -- Final health check
    print("\n=== FINAL HEALTH CHECK ===")
    if CleanupManager.TestSystemHealth() then
        print("✅ System still working after cleanup!")
    else
        error("❌ System broken after cleanup! Check legacy folder for restoration.")
    end
end

function CleanupManager.RestoreFromLegacy(moduleName)
    local interactionFolder = script.Parent
    local legacyFolder = interactionFolder:FindFirstChild("legacy")
    
    if not legacyFolder then
        error("Legacy folder not found")
    end
    
    local archivedModule = legacyFolder:FindFirstChild(moduleName)
    if not archivedModule then
        error("Module not found in legacy folder: " .. moduleName)
    end
    
    -- Check if module already exists
    local existing = interactionFolder:FindFirstChild(moduleName)
    if existing then
        warn("Module already exists, removing old version: " .. moduleName)
        existing:Destroy()
    end
    
    -- Restore from legacy
    local restored = archivedModule:Clone()
    restored.Parent = interactionFolder
    
    print("✅ Restored from legacy: " .. moduleName)
end

-- Auto-run analysis when required
CleanupManager.AnalyzeCurrentState()

-- Provide instructions
print("\n=== CLEANUP INSTRUCTIONS ===")
print("1. First run: CleanupManager.TestSystemHealth()")
print("2. If healthy: CleanupManager.PerformCleanup()")
print("3. If issues: CleanupManager.RestoreFromLegacy('ModuleName')")
print("\nExample usage:")
print("  local cleanup = require(path.to.cleanup_legacy_modules)")
print("  cleanup.PerformCleanup()")

return CleanupManager 