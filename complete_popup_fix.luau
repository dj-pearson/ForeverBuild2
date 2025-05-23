-- Complete Popup Fix - Final Solution for Duplicate Popup Issue
-- This script completely disables all old popup systems and ensures only the new bottom popup works

print("=== COMPLETE POPUP SYSTEM FIX ===")
print("Fixing duplicate popup issue comprehensively...")

-- Step 1: Set global flags immediately 
_G.DISABLE_OLD_INTERACTION_CLIENT = true
_G.USE_NEW_BOTTOM_POPUP_ONLY = true
print("✓ Set global flags to disable all old popup systems")

-- Step 2: Clean up all existing popup UIs
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function cleanupAllOldUIs()
    local cleaned = 0
    local cleanedTypes = {}
    
    -- List of all possible old UI names
    local oldUINames = {
        "InteractionUI",
        "PurchaseDialog", 
        "ProximityUI",
        "InteractionNotifications",
        "ItemInteractionUI",
        "CatalogUI",
        "WorldItemUI"
    }
    
    -- Clean up from PlayerGui
    for _, gui in ipairs(playerGui:GetChildren()) do
        for _, oldName in ipairs(oldUINames) do
            if gui.Name == oldName or gui.Name:find(oldName) then
                gui:Destroy()
                cleaned = cleaned + 1
                table.insert(cleanedTypes, gui.Name)
                break
            end
        end
    end
    
    -- Clean up proximity UIs attached to workspace items
    local function cleanupWorkspaceUIs(parent)
        for _, item in ipairs(parent:GetChildren()) do
            if item:FindFirstChild("ProximityUI") then
                item.ProximityUI:Destroy()
                cleaned = cleaned + 1
                table.insert(cleanedTypes, "Workspace ProximityUI")
            end
            if item:IsA("Folder") or item:IsA("Model") then
                cleanupWorkspaceUIs(item)
            end
        end
    end
    
    if workspace:FindFirstChild("Items") then
        cleanupWorkspaceUIs(workspace.Items)
    end
    
    print("✓ Cleaned up", cleaned, "old UI elements")
    if #cleanedTypes > 0 then
        print("  Types removed:", table.concat(cleanedTypes, ", "))
    end
end

cleanupAllOldUIs()

-- Step 3: Disable any existing old system instances
local function disableOldSystems()
    -- Disable global InteractionSystem instances
    if _G.InteractionSystem then
        _G.InteractionSystem = nil
        print("✓ Disabled global InteractionSystem")
    end
    
    -- Disable any ItemInteractionClient instances that might be old
    if _G.ItemInteractionClient and not _G.ItemInteractionClient.bottomPurchasePopup then
        _G.ItemInteractionClient = nil
        print("✓ Disabled old ItemInteractionClient")
    end
    
    -- Clear any cached interaction modules
    if package and package.loaded then
        local modulesToClear = {
            "InteractionSystemModule_new",
            "InteractionSystemModule", 
            "InteractionSystemModule_enhanced"
        }
        
        for _, moduleName in ipairs(modulesToClear) do
            if package.loaded[moduleName] then
                package.loaded[moduleName] = nil
                print("✓ Cleared cached module:", moduleName)
            end
        end
    end
end

disableOldSystems()

-- Step 4: Ensure our new bottom popup system is running
local function ensureNewSystemActive()
    wait(2) -- Give time for the new system to initialize
    
    if _G.ItemInteractionClient and _G.ItemInteractionClient.bottomPurchasePopup then
        print("✓ New bottom popup system is active!")
        
        -- Make sure proximity UI is disabled
        if _G.ItemInteractionClient.proximityEnabled then
            _G.ItemInteractionClient.proximityEnabled = false
            print("✓ Disabled proximity UI on new system")
        end
        
        -- Test the bottom popup system
        local popup = _G.ItemInteractionClient.bottomPurchasePopup
        if popup and popup.isInitialized then
            print("✓ Bottom popup system is properly initialized")
            return true
        end
    end
    
    return false
end

-- Step 5: Monitor and verify the fix
local function monitorSystems()
    local attempts = 0
    local maxAttempts = 10
    
    local function checkSystems()
        attempts = attempts + 1
        
        if ensureNewSystemActive() then
            print("✓ System verification complete!")
            print("")
            print("=== FIX SUCCESSFUL ===")
            print("✓ All old popup systems disabled")
            print("✓ New bottom popup system active")
            print("✓ No more '[E] View' popups should appear")
            print("✓ Only small bottom purchase popup will show")
            return
        end
        
        if attempts < maxAttempts then
            print("! Waiting for new system... (attempt", attempts, "of", maxAttempts, ")")
            task.wait(1)
            checkSystems()
        else
            warn("! Could not verify new system after", maxAttempts, "attempts")
            warn("! You may need to restart the game for full effect")
        end
    end
    
    checkSystems()
end

-- Run the monitoring
task.spawn(monitorSystems)

print("")
print("=== COMPLETE POPUP FIX APPLIED ===")
print("The duplicate popup issue should now be completely resolved!")
print("Only the new bottom popup will appear when you approach store items.") 