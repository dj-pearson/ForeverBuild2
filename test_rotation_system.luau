-- Test script for rotation system
print("=== ROTATION SYSTEM TEST ===" )

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Wait for player
local player = Players.LocalPlayer
if not player then
    print("❌ No LocalPlayer found - test only works in game")
    return
end

print("✅ Player found:", player.Name)

-- Test 1: Verify RotationController is available
print("\n🔍 TEST 1: Checking RotationController")

local RotationController
local success, err = pcall(function()
    RotationController = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("core"):WaitForChild("placement"):WaitForChild("RotationController"))
end)

if success and RotationController then
    print("✅ RotationController module loaded successfully")
    
    -- Test creating an instance
    local rotController = RotationController.new()
    if rotController then
        print("✅ RotationController instance created successfully")
        print("   - Initial rotation:", rotController:GetRotation())
        print("   - Is rotating:", rotController:IsRotating())
    else
        print("❌ Failed to create RotationController instance")
    end
else
    print("❌ Failed to load RotationController:", err)
    return
end

-- Test 2: Check PlacementManager integration
print("\n🔍 TEST 2: Checking PlacementManager Rotation Integration")

local SharedModule
local success2, err2 = pcall(function()
    SharedModule = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("inits"))
end)

if success2 and SharedModule then
    print("✅ SharedModule loaded")
    
    local PlacementManager = SharedModule.PlacementManagerClientInstance or SharedModule.PlacementManager
    if PlacementManager then
        print("✅ PlacementManager found")
        
        -- Check if RotatePlacedItem method exists
        if PlacementManager.RotatePlacedItem then
            print("✅ RotatePlacedItem method found")
        else
            print("❌ RotatePlacedItem method not found")
        end
        
        -- Check if rotation controller is initialized
        if PlacementManager.rotationController then
            print("✅ PlacementManager has rotation controller")
        else
            print("❌ PlacementManager missing rotation controller")
        end
    else
        print("❌ PlacementManager not found in SharedModule")
    end
else
    print("❌ Failed to load SharedModule:", err2)
end

-- Test 3: Check for necessary remote events
print("\n🔍 TEST 3: Checking Remote Events")

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if remotesFolder then
    print("✅ Remotes folder found")
    
    local requiredEvents = {
        "RequestRotateItem",
        "ItemUpdated"
    }
    
    for _, eventName in ipairs(requiredEvents) do
        local event = remotesFolder:FindFirstChild(eventName)
        if event then
            print("✅", eventName, "remote event found")
        else
            print("❌", eventName, "remote event missing")
        end
    end
else
    print("❌ Remotes folder not found")
end

-- Test 4: Interactive test instructions
print("\n🎮 INTERACTIVE TESTS:")
print("To test rotation functionality:")
print("1. Place an item from your inventory")
print("2. While placing, press R to enter rotation mode")
print("3. Use R/T keys or scroll wheel to rotate")
print("4. Left-click to confirm rotation")
print("5. For placed items, right-click on them and select 'Rotate' action")

-- Test 5: Create a simple demonstration (if we can access Workspace)
print("\n🔍 TEST 5: Creating Test Demonstration")

if RunService:IsClient() then
    -- Create a test part to demonstrate rotation
    local testPart = Instance.new("Part")
    testPart.Name = "RotationTestPart"
    testPart.Size = Vector3.new(4, 1, 2)
    testPart.Position = Vector3.new(0, 10, 0)
    testPart.BrickColor = BrickColor.new("Bright blue")
    testPart.Material = Enum.Material.Neon
    testPart.Anchored = true
    testPart.Parent = game.Workspace
    
    -- Add attributes to simulate a placed item
    testPart:SetAttribute("instanceId", "test_rotation_part")
    testPart:SetAttribute("owner", player.UserId)
    testPart:SetAttribute("itemId", "test_cube")
    
    print("✅ Created test part for rotation demonstration")
    print("   Position:", testPart.Position)
    print("   Size:", testPart.Size)
    
    -- Test rotation controller with the test part
    if RotationController then
        local testController = RotationController.new()
        
        print("\n🔄 Testing rotation controller with test part...")
        
        local onConfirm = function(item, finalRotation)
            print("✅ Test rotation confirmed at", finalRotation, "degrees")
            testController:StopRotation()
        end
        
        local onCancel = function(item)
            print("❌ Test rotation cancelled")
            testController:StopRotation()
        end
        
        -- Auto-test: start rotation mode and test a few rotations
        task.spawn(function()
            task.wait(2) -- Wait 2 seconds
            
            if testController:StartRotation(testPart, onConfirm, onCancel) then
                print("🔄 Auto-test: Started rotation mode")
                
                task.wait(1)
                testController:RotateBy(45)
                print("🔄 Auto-test: Rotated by 45 degrees")
                
                task.wait(1)
                testController:RotateBy(90)
                print("🔄 Auto-test: Rotated by additional 90 degrees")
                
                task.wait(1)
                testController:SetRotation(0)
                print("🔄 Auto-test: Reset to 0 degrees")
                
                task.wait(1)
                testController:ConfirmRotation()
                print("✅ Auto-test: Confirmed final rotation")
            else
                print("❌ Auto-test: Failed to start rotation mode")
            end
        end)
    end
    
    -- Clean up after test
    task.spawn(function()
        task.wait(10) -- Wait 10 seconds then clean up
        if testPart and testPart.Parent then
            testPart:Destroy()
            print("🧹 Cleaned up test part")
        end
    end)
else
    print("⚠️  Test part creation skipped (server-side test)")
end

print("\n✅ ROTATION SYSTEM TEST COMPLETED")
print("Check the output above for any issues and test interactively in game!") 