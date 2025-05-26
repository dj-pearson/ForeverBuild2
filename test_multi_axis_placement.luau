-- Test script for multi-axis placement system
print("=== MULTI-AXIS PLACEMENT TEST ===")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- Wait for player
local player = Players.LocalPlayer
if not player then
    print("❌ No LocalPlayer found - test only works in game")
    return
end

print("✅ Player found:", player.Name)

-- Test 1: Check if multi-axis system is working
print("\n🔍 TEST 1: Checking Multi-Axis Placement System")

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

-- Test 2: Instructions for testing multi-axis placement
print("\n📋 TESTING INSTRUCTIONS:")
print("==========================================")
print("1. Start placing an item (select from inventory)")
print("")
print("2. Test ROTATION while placing:")
print("   🔄 YAW: Use Q/E keys or scroll wheel")
print("   🔺 PITCH: Hold Shift + Q/E or Shift + scroll")
print("   🌀 ROLL: Hold Ctrl + Q/E or Ctrl + scroll")
print("")
print("3. Look for these console messages:")
print("   📐 CLIENT SENDING MULTI-AXIS ROTATION")
print("   📐 SERVER RECEIVED ROTATION DATA")
print("   📐 APPLIED MULTI-AXIS ROTATION TO [MODEL/PART]")
print("")
print("4. After placing, check the item:")
print("   ✓ Item should maintain its rotated orientation")
print("   ✓ Multiple rotations should work together")
print("   ✓ Preview rotation should match final placement")
print("")

-- Test 3: Monitor for successful placements
print("\n🔍 TEST 3: Placement Monitoring")
print("Watching for placement events...")

-- Monitor placed items in workspace
local function checkPlacedItems()
    local placedFolder = workspace:FindFirstChild("PlacedItems")
    if placedFolder then
        for _, item in pairs(placedFolder:GetChildren()) do
            -- Check for rotation attributes
            local rotX = item:GetAttribute("rotationX")
            local rotY = item:GetAttribute("rotationY") 
            local rotZ = item:GetAttribute("rotationZ")
            
            if rotX or rotY or rotZ then
                print("✅ Found placed item with rotation attributes:")
                print("   Item:", item.Name)
                print("   Rotation X:", rotX or "nil")
                print("   Rotation Y:", rotY or "nil") 
                print("   Rotation Z:", rotZ or "nil")
                
                -- Check if actual CFrame matches stored rotation
                local actualRotation
                if item:IsA("Model") and item.PrimaryPart then
                    local rx, ry, rz = item.PrimaryPart.CFrame:ToEulerAnglesXYZ()
                    actualRotation = {
                        X = math.deg(rx),
                        Y = math.deg(ry),
                        Z = math.deg(rz)
                    }
                elseif item:IsA("BasePart") then
                    local rx, ry, rz = item.CFrame:ToEulerAnglesXYZ()
                    actualRotation = {
                        X = math.deg(rx),
                        Y = math.deg(ry),
                        Z = math.deg(rz)
                    }
                end
                
                if actualRotation then
                    print("   Actual CFrame rotation:")
                    print("     X:", math.floor(actualRotation.X + 0.5) .. "°")
                    print("     Y:", math.floor(actualRotation.Y + 0.5) .. "°")
                    print("     Z:", math.floor(actualRotation.Z + 0.5) .. "°")
                    
                    -- Compare stored vs actual (allowing for some rounding differences)
                    local tolerance = 2 -- degrees
                    local xMatch = math.abs((rotX or 0) - actualRotation.X) < tolerance
                    local yMatch = math.abs((rotY or 0) - actualRotation.Y) < tolerance
                    local zMatch = math.abs((rotZ or 0) - actualRotation.Z) < tolerance
                    
                    if xMatch and yMatch and zMatch then
                        print("   ✅ Rotation attributes match actual CFrame!")
                    else
                        print("   ⚠️ Rotation mismatch detected:")
                        print("     Expected X:", rotX, "Actual X:", actualRotation.X)
                        print("     Expected Y:", rotY, "Actual Y:", actualRotation.Y)
                        print("     Expected Z:", rotZ, "Actual Z:", actualRotation.Z)
                    end
                end
            end
        end
    end
end

-- Run check every 5 seconds
spawn(function()
    while true do
        task.wait(5)
        checkPlacedItems()
    end
end)

-- Test 4: Create demonstration objects to show rotation differences
print("\n🔍 TEST 4: Creating Reference Objects")

local function createDemoObject(name, position, rotation)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = Vector3.new(4, 2, 6) -- Rectangular to show rotation clearly
    part.Position = position
    part.Anchored = true
    part.BrickColor = BrickColor.new("Bright blue")
    
    -- Apply rotation
    part.CFrame = CFrame.new(position) * CFrame.Angles(
        math.rad(rotation.X or 0),
        math.rad(rotation.Y or 0), 
        math.rad(rotation.Z or 0)
    )
    
    -- Add visual markers
    local front = Instance.new("Part")
    front.Name = "Front"
    front.Size = Vector3.new(1, 1, 0.5)
    front.BrickColor = BrickColor.new("Bright red")
    front.Anchored = true
    front.Parent = part
    front.CFrame = part.CFrame * CFrame.new(0, 0, -3.25)
    
    local top = Instance.new("Part")
    top.Name = "Top"
    top.Size = Vector3.new(1, 0.5, 1)
    top.BrickColor = BrickColor.new("Bright green")
    top.Anchored = true
    top.Parent = part
    top.CFrame = part.CFrame * CFrame.new(0, 1.25, 0)
    
    part.Parent = workspace
    return part
end

-- Create reference objects showing different rotations
local startPos = player.Character and player.Character.HumanoidRootPart.Position + Vector3.new(15, 0, 0) or Vector3.new(15, 5, 0)

local refs = {
    createDemoObject("Ref_NoRotation", startPos + Vector3.new(0, 0, 0), {X=0, Y=0, Z=0}),
    createDemoObject("Ref_YawOnly", startPos + Vector3.new(10, 0, 0), {X=0, Y=45, Z=0}),
    createDemoObject("Ref_PitchOnly", startPos + Vector3.new(0, 0, 10), {X=30, Y=0, Z=0}),
    createDemoObject("Ref_RollOnly", startPos + Vector3.new(10, 0, 10), {X=0, Y=0, Z=30}),
    createDemoObject("Ref_Combined", startPos + Vector3.new(20, 0, 5), {X=15, Y=45, Z=15})
}

print("✅ Created reference objects showing different rotation types")
print("   Red face = Front, Green face = Top")
print("   Compare your placed items with these references")

-- Cleanup after 2 minutes
task.wait(120)
for _, ref in ipairs(refs) do
    if ref and ref.Parent then
        ref:Destroy()
    end
end
print("🧹 Reference objects cleaned up automatically")

print("\n🎯 MULTI-AXIS PLACEMENT TEST COMPLETE")
print("Now place items with different rotations and verify they work!") 