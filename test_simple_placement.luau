-- Simple test to place an item at a known position
print("=== SIMPLE PLACEMENT TEST ===")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for player
local player = Players.LocalPlayer
if not player then
    print("❌ No LocalPlayer found")
    return
end

-- Wait for character
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

print("✅ Player found:", player.Name)
print("✅ Character position:", humanoidRootPart.Position)

-- Test accessing SharedModule and PlacementManager
local SharedModule
local success, err = pcall(function()
    SharedModule = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("inits"))
end)

if not success then
    print("❌ Failed to load SharedModule:", err)
    return
end

print("✅ SharedModule loaded")

-- Access PlacementManager
local PlacementManager = SharedModule.PlacementManager
if not PlacementManager then
    print("❌ PlacementManager not found in SharedModule")
    return
end

print("✅ PlacementManager found")

-- Check remotes
if not PlacementManager.remotes then
    print("❌ PlacementManager.remotes not found")
    return
end

if not PlacementManager.remotes.RequestPlaceItem then
    print("❌ RequestPlaceItem remote not found")
    return
end

print("✅ RequestPlaceItem remote found")

-- Test placement directly at a specific position
local testPosition = humanoidRootPart.Position + Vector3.new(5, 0, 5)
local testNormal = Vector3.new(0, 1, 0)
local testAngleY = 0

print("🎯 Testing direct placement at position:", testPosition)

-- Fire the remote directly with known parameters
PlacementManager.remotes.RequestPlaceItem:FireServer("Brick_Cube", testPosition, testNormal, testAngleY)

print("✅ Placement request sent!")
print("Check the logs and world for a Brick_Cube at position:", testPosition) 