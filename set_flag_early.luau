-- Set Flag Early - Simple script to disable old popup systems
-- Run this BEFORE starting the game

print("=== SETTING FLAG TO DISABLE OLD POPUP SYSTEMS ===")

-- Set the flags immediately
_G.DISABLE_OLD_INTERACTION_CLIENT = true
_G.USE_NEW_BOTTOM_POPUP_ONLY = true

print("✓ Flags set - old popup systems should be disabled")
print("✓ Only the new bottom popup should work now")

-- Clean up any existing old UIs quickly
local Players = game:GetService("Players")
local player = Players.LocalPlayer

if player and player:FindFirstChild("PlayerGui") then
    local playerGui = player.PlayerGui
    
    for _, gui in ipairs(playerGui:GetChildren()) do
        if gui.Name == "InteractionUI" then
            gui:Destroy()
            print("✓ Removed old InteractionUI")
        end
    end
end

print("=== FLAG SET COMPLETE ===") 