-- Disable Old Systems Early - Run this FIRST to prevent old popup systems
-- This script should be run at the very beginning to set the global flag

print("=== DISABLING OLD POPUP SYSTEMS EARLY ===")

-- Set the global flag immediately to prevent old systems from initializing
_G.DISABLE_OLD_INTERACTION_CLIENT = true
print("✓ Set DISABLE_OLD_INTERACTION_CLIENT flag to prevent old popup systems")

-- Also set a backup flag for extra safety
_G.USE_NEW_BOTTOM_POPUP_ONLY = true
print("✓ Set USE_NEW_BOTTOM_POPUP_ONLY flag for backup")

-- Clean up any existing UI immediately
local Players = game:GetService("Players")
local player = Players.LocalPlayer

if player and player:FindFirstChild("PlayerGui") then
    local playerGui = player.PlayerGui
    
    -- Remove old popup UIs
    local oldUIs = {
        "InteractionUI",
        "PurchaseDialog", 
        "ProximityUI",
        "InteractionNotifications"
    }
    
    for _, uiName in ipairs(oldUIs) do
        local ui = playerGui:FindFirstChild(uiName)
        if ui then
            ui:Destroy()
            print("✓ Removed existing UI:", uiName)
        end
    end
end

print("✓ Early cleanup complete - old popup systems should be prevented from loading")
print("")
print("Now the new bottom popup system should be the only one that loads!") 