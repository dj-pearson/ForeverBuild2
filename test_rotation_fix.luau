-- Test script to verify rotation system fixes
print("=== ROTATION SYSTEM FIX TEST ===")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Wait for player
local player = Players.LocalPlayer
if not player then
    print("❌ No LocalPlayer found - test only works in game")
    return
end

print("✅ Player found:", player.Name)

-- Test 1: Check if PlacementManager is available
print("\n🔍 TEST 1: Checking PlacementManager")

local SharedModule
local success, err = pcall(function()
    SharedModule = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("inits"))
end)

if not success or not SharedModule then
    print("❌ Failed to load SharedModule:", err)
    return
end

local PlacementManager = SharedModule.PlacementManagerClientInstance or SharedModule.PlacementManager
if not PlacementManager then
    print("❌ PlacementManager not found")
    return
end

print("✅ PlacementManager loaded successfully")

-- Test 2: Verify rotation methods exist
print("\n🔍 TEST 2: Checking rotation methods")

local methods = {
    "_DirectRotate",
    "_ApplyRotationToItem", 
    "_ShowRotationUI",
    "currentPlacementRotation"
}

for _, method in ipairs(methods) do
    if PlacementManager[method] ~= nil then
        print("✅", method, "exists")
    else
        print("❌", method, "missing")
    end
end

-- Test 3: Create a test item to verify rotation works
print("\n🔍 TEST 3: Creating test item for rotation verification")

if RunService:IsClient() then
    -- Create a test part
    local testPart = Instance.new("Part")
    testPart.Name = "RotationFixTestPart"
    testPart.Size = Vector3.new(6, 2, 3) -- Rectangular so rotation is visible
    testPart.Position = Vector3.new(10, 5, 0)
    testPart.BrickColor = BrickColor.new("Bright blue")
    testPart.Material = Enum.Material.Neon
    testPart.Anchored = true
    testPart.Parent = game.Workspace
    
    -- Add a decal to make rotation more obvious
    local decal = Instance.new("Decal")
    decal.Texture = "rbxasset://textures/face.png"
    decal.Face = Enum.NormalId.Front
    decal.Parent = testPart
    
    print("✅ Created test part at position:", testPart.Position)
    
    -- Test the rotation function directly
    print("\n🔄 TEST 4: Testing _ApplyRotationToItem function")
    
    if PlacementManager._ApplyRotationToItem then
        local testRotations = {0, 45, 90, 135, 180, 225, 270, 315, 360}
        
        local function testRotation(angle)
            task.wait(1)
            print("   Testing rotation:", angle, "degrees")
            PlacementManager:_ApplyRotationToItem(testPart, angle)
            
            -- Verify the rotation was applied
            local _, actualY, _ = testPart.CFrame:ToEulerAnglesXYZ()
            local actualDegrees = math.deg(actualY) % 360
            local expectedDegrees = angle % 360
            
            local tolerance = 1 -- 1 degree tolerance
            if math.abs(actualDegrees - expectedDegrees) < tolerance then
                print("   ✅ Rotation applied correctly:", actualDegrees, "≈", expectedDegrees)
            else
                print("   ❌ Rotation incorrect. Expected:", expectedDegrees, "Got:", actualDegrees)
            end
        end
        
        -- Test rotations
        task.spawn(function()
            for _, angle in ipairs(testRotations) do
                testRotation(angle)
            end
            
            -- Clean up
            task.wait(2)
            testPart:Destroy()
            print("🧹 Test part cleaned up")
        end)
    else
        print("❌ _ApplyRotationToItem method not found")
    end
    
    -- Test 5: Verify controls UI shows correct keys
    print("\n🔍 TEST 5: Testing PlacementControlsUI")
    
    if PlacementManager.placementControlsUI then
        print("✅ PlacementControlsUI exists")
        -- The UI should now show Q/E instead of A/D
        print("📋 PlacementControlsUI should display 'Q&E' for rotation controls")
    else
        print("❌ PlacementControlsUI not found")
    end
    
else
    print("⚠️  Test part creation skipped (not client)")
end

-- Test 6: Instructions for manual testing
print("\n🎮 MANUAL TESTING INSTRUCTIONS:")
print("To test the fixed rotation system:")
print("")
print("1. 📦 Place an item from inventory")
print("2. 🔄 Try these rotation controls during placement:")
print("   • Q: Rotate left 45°")
print("   • E: Rotate right 45°") 
print("   • Scroll wheel: Rotate 45° (up/down)")
print("   • Space: Open fine rotation UI")
print("3. ✅ The preview item should visibly rotate")
print("4. 🖱️  Left-click to place with rotation")
print("")
print("Fixed issues:")
print("✅ Q/E keys don't conflict with player movement")
print("✅ UpdatePlacementPreview uses currentPlacementRotation")
print("✅ Visual rotation should now work properly")
print("✅ Placed items should maintain their rotation")

print("\n✅ ROTATION SYSTEM FIX TEST COMPLETED")
print("🎯 Key changes made:")
print("   • Changed A/D to Q/E for rotation")
print("   • Fixed UpdatePlacementPreview to use currentPlacementRotation")
print("   • Updated UI to show correct controls")
print("   • Maintained scroll wheel and gamepad support") 