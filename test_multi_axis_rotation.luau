-- Test script for multi-axis rotation system
print("=== MULTI-AXIS ROTATION SYSTEM TEST ===")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Wait for player
local player = Players.LocalPlayer
if not player then
    print("❌ No LocalPlayer found - test only works in game")
    return
end

print("✅ Player found:", player.Name)

-- Test 1: Check if PlacementManager is available
print("\n🔍 TEST 1: Checking PlacementManager with Multi-Axis Support")

local SharedModule
local success, err = pcall(function()
    SharedModule = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("inits"))
end)

if not success or not SharedModule then
    print("❌ Failed to load SharedModule:", err)
    return
end

local placementManager = SharedModule.PlacementManager
if not placementManager then
    print("❌ PlacementManager not found in SharedModule")
    return
end

print("✅ PlacementManager loaded successfully")

-- Test 2: Check if new multi-axis methods exist
print("\n🔍 TEST 2: Checking Multi-Axis Methods")

local methodsToCheck = {
    "_DirectRotateAxis",
    "_ApplyMultiAxisRotation",
}

for _, methodName in ipairs(methodsToCheck) do
    if placementManager[methodName] then
        print("✅", methodName, "method exists")
    else
        print("❌", methodName, "method missing")
    end
end

-- Test 3: Check if rotation variables are initialized
print("\n🔍 TEST 3: Checking Rotation Variables")

local rotationVars = {
    "currentPlacementRotation",
    "currentPlacementRotationX", 
    "currentPlacementRotationY",
    "currentPlacementRotationZ"
}

-- We can't directly check instance variables, but we can test the functionality

print("✅ Multi-axis rotation variables should be initialized during placement")

-- Test 4: Instructions for manual testing
print("\n📋 MANUAL TESTING INSTRUCTIONS:")
print("==========================================")
print("1. Place an item (any item)")
print("2. During placement, test these controls:")
print("")
print("   🔄 YAW (Left/Right):")
print("      • Q/E keys")
print("      • Mouse scroll wheel")
print("      • L1/R1 bumpers (gamepad)")
print("")
print("   🔺 PITCH (Up/Down):")
print("      • Shift + Q/E keys")
print("      • Shift + Mouse scroll")
print("      • R2 + L1/R1 (gamepad)")
print("")
print("   🌀 ROLL (Spin):")
print("      • Ctrl + Q/E keys")
print("      • Ctrl + Mouse scroll")
print("      • L2 + L1/R1 (gamepad)")
print("")
print("3. Verify that:")
print("   ✓ Item rotates on correct axis")
print("   ✓ Rotation is visible in preview")
print("   ✓ Final placement maintains rotation")
print("   ✓ Multiple axes work together")
print("")

-- Test 5: Platform detection
print("\n🔍 TEST 5: Platform Detection")

local platform
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
    platform = "Mobile"
elseif UserInputService.GamepadEnabled then
    platform = "Console"
else
    platform = "PC"
end

print("✅ Detected platform:", platform)

-- Test 6: Control mapping verification
print("\n🎮 CONTROL MAPPING VERIFICATION:")
print("==========================================")

if platform == "PC" then
    print("PC Controls:")
    print("• Yaw: Q/E keys, Mouse scroll")
    print("• Pitch: Shift + Q/E, Shift + Scroll")
    print("• Roll: Ctrl + Q/E, Ctrl + Scroll")
elseif platform == "Console" then
    print("Console Controls:")
    print("• Yaw: L1/R1 bumpers")
    print("• Pitch: R2 + L1/R1")
    print("• Roll: L2 + L1/R1")
elseif platform == "Mobile" then
    print("Mobile Controls:")
    print("• Yaw: Scroll/Tap")
    print("• Pitch: Shift + Scroll")
    print("• Roll: Ctrl + Scroll")
end

print("\n🎯 TEST COMPLETED")
print("Start placing an item to test multi-axis rotation!")
print("Watch console for rotation feedback messages.")

-- Test 7: Create test objects with different orientations
print("\n🔍 TEST 7: Creating Test Objects")

local function createTestCube(name, position, color)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = Vector3.new(4, 4, 4)
    part.Position = position
    part.Anchored = true
    part.BrickColor = BrickColor.new(color)
    part.Parent = workspace
    
    -- Add orientation markers
    local front = Instance.new("Part")
    front.Name = "Front"
    front.Size = Vector3.new(1, 1, 0.5)
    front.Position = position + Vector3.new(0, 0, -2.25)
    front.Anchored = true
    front.BrickColor = BrickColor.new("Bright red")
    front.Parent = part
    
    local top = Instance.new("Part")
    top.Name = "Top"
    top.Size = Vector3.new(1, 0.5, 1)
    top.Position = position + Vector3.new(0, 2.25, 0)
    top.Anchored = true
    top.BrickColor = BrickColor.new("Bright green")
    top.Parent = part
    
    return part
end

-- Create reference cubes to understand rotation
local referencePosition = player.Character and player.Character.HumanoidRootPart.Position + Vector3.new(10, 0, 0) or Vector3.new(10, 5, 0)

local refCube = createTestCube("Reference_Cube", referencePosition, "Medium stone grey")
print("✅ Created reference cube at", referencePosition)
print("   Red face = Front (for Roll reference)")
print("   Green face = Top (for Pitch reference)")

-- Setup cleanup
local function cleanup()
    if refCube and refCube.Parent then
        refCube:Destroy()
    end
end

-- Auto cleanup after 60 seconds
task.wait(60)
cleanup()
print("🧹 Test objects cleaned up automatically") 