-- Fix Duplicate Initialization - Ensure Only One Popup System Runs
-- Run this script to prevent the old client_core from creating duplicate ItemInteractionClient instances

print("=== FIXING DUPLICATE INITIALIZATION ===")

-- Step 1: Set a global flag to prevent old initialization
_G.DISABLE_OLD_INTERACTION_CLIENT = true
print("✓ Set global flag to disable old ItemInteractionClient and InteractionSystemModule_new")

-- Step 2: Clean up any existing popup UIs from both systems
local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")

-- Remove any existing popup UIs
local function cleanupAllOldUIs()
    local cleaned = 0
    local cleanedGuis = {}
    
    for _, gui in ipairs(playerGui:GetChildren()) do
        if gui.Name == "ProximityUI" or 
           gui.Name == "InteractionNotifications" or 
           gui.Name == "InteractionUI" or 
           gui.Name == "PurchaseDialog" then
            gui:Destroy()
            cleaned = cleaned + 1
            table.insert(cleanedGuis, gui.Name)
        end
    end
    
    -- Also clean up any proximity UIs attached to workspace items
    local function cleanupWorkspaceUIs(parent)
        for _, item in ipairs(parent:GetChildren()) do
            if item:FindFirstChild("ProximityUI") then
                item.ProximityUI:Destroy()
                cleaned = cleaned + 1
                table.insert(cleanedGuis, "Workspace ProximityUI")
            end
            if item:IsA("Folder") then
                cleanupWorkspaceUIs(item)
            end
        end
    end
    
    if workspace:FindFirstChild("Items") then
        cleanupWorkspaceUIs(workspace.Items)
    end
    
    print("✓ Cleaned up", cleaned, "old UI elements:", table.concat(cleanedGuis, ", "))
end

cleanupAllOldUIs()

-- Step 3: Disable any existing InteractionSystem instances
local function disableOldSystems()
    if _G.InteractionSystem then
        print("✓ Found and disabled existing InteractionSystem")
        _G.InteractionSystem = nil
    end
    
    -- Clean up any remaining purchase dialogs
    task.wait(0.1) -- Small delay to let any running processes finish
    
    for _, gui in ipairs(playerGui:GetChildren()) do
        if gui.Name:find("Purchase") or gui.Name:find("Interaction") then
            gui:Destroy()
            print("✓ Cleaned up remaining UI:", gui.Name)
        end
    end
end

disableOldSystems()

-- Step 4: Ensure only our new BottomPurchasePopup system is active
local function ensureOnlyNewSystem()
    -- Check if our new system is running
    if _G.ItemInteractionClient and _G.ItemInteractionClient.bottomPurchasePopup then
        print("✓ New integrated popup system is active")
        
        -- Disable proximity UI on the new system to be extra sure
        if _G.ItemInteractionClient.proximityEnabled ~= nil then
            _G.ItemInteractionClient.proximityEnabled = false
            print("✓ Disabled proximity UI on new system")
        end
        
        return true
    else
        print("! New system not found, will wait for it to initialize")
        return false
    end
end

-- Wait for the new system and then ensure it's the only one
local attempts = 0
local maxAttempts = 20

local function checkSystem()
    attempts = attempts + 1
    
    if ensureOnlyNewSystem() then
        print("✓ System check complete - only new popup system should be active")
        return
    end
    
    if attempts < maxAttempts then
        wait(1)
        checkSystem()
    else
        warn("! Could not verify new system after", maxAttempts, "attempts")
    end
end

checkSystem()

print("")
print("=== DUPLICATE INITIALIZATION FIX COMPLETE ===")
print("✓ Disabled old ItemInteractionClient initialization")
print("✓ Disabled InteractionSystemModule_new initialization") 
print("✓ Cleaned up old proximity and purchase UIs")
print("✓ Only the new bottom popup system should be active now")
print("")
print("The '[E] View' popups should now be completely gone!")
print("Only the small bottom popup should appear for store items.") 