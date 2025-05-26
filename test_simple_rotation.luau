-- Test script for the simple cross-platform rotation system
print("=== SIMPLE ROTATION SYSTEM TEST ===")

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

-- Test 1: Check if SimpleRotationUI is available
print("\n🔍 TEST 1: Checking SimpleRotationUI")

local SimpleRotationUI
local success, err = pcall(function()
    SimpleRotationUI = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("core"):WaitForChild("placement"):WaitForChild("SimpleRotationUI"))
end)

if success and SimpleRotationUI then
    print("✅ SimpleRotationUI module loaded successfully")
    
    -- Test creating an instance
    local rotUI = SimpleRotationUI.new()
    if rotUI then
        print("✅ SimpleRotationUI instance created successfully")
        print("   - Initial rotation:", rotUI:GetRotation())
        print("   - Is active:", rotUI:IsActive())
    else
        print("❌ Failed to create SimpleRotationUI instance")
    end
else
    print("❌ Failed to load SimpleRotationUI:", err)
    return
end

-- Test 2: Check PlacementManager integration
print("\n🔍 TEST 2: Checking PlacementManager Integration")

local SharedModule
local success2, err2 = pcall(function()
    SharedModule = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("inits"))
end)

if success2 and SharedModule then
    print("✅ SharedModule loaded")
    
    local PlacementManager = SharedModule.PlacementManagerClientInstance or SharedModule.PlacementManager
    if PlacementManager then
        print("✅ PlacementManager found")
        
        -- Check if the new rotation methods exist
        if PlacementManager.RotatePlacedItem then
            print("✅ RotatePlacedItem method found")
        else
            print("❌ RotatePlacedItem method not found")
        end
        
        -- Check if SimpleRotationUI is initialized
        if PlacementManager.simpleRotationUI then
            print("✅ PlacementManager has SimpleRotationUI")
        else
            print("❌ PlacementManager missing SimpleRotationUI")
        end
    else
        print("❌ PlacementManager not found in SharedModule")
    end
else
    print("❌ Failed to load SharedModule:", err2)
end

-- Test 3: Create a demo rotation interface
print("\n🔍 TEST 3: Creating Demo Rotation Interface")

if SimpleRotationUI and RunService:IsClient() then
    -- Create a test part
    local testPart = Instance.new("Part")
    testPart.Name = "SimpleRotationTestPart"
    testPart.Size = Vector3.new(4, 1, 2)
    testPart.Position = Vector3.new(0, 10, 0)
    testPart.BrickColor = BrickColor.new("Bright green")
    testPart.Material = Enum.Material.Neon
    testPart.Anchored = true
    testPart.Parent = game.Workspace
    
    -- Add attributes
    testPart:SetAttribute("instanceId", "simple_test_part")
    testPart:SetAttribute("owner", player.UserId)
    testPart:SetAttribute("itemId", "test_cube")
    
    print("✅ Created test part for rotation demonstration")
    print("   Position:", testPart.Position)
    print("   Size:", testPart.Size)
    
    -- Create rotation UI instance
    local demoRotationUI = SimpleRotationUI.new()
    
    -- Demo callbacks
    local onRotationChanged = function(item, rotation)
        print("🔄 Demo: Rotation changed to", rotation, "degrees")
        -- Apply rotation to the test part
        if item and item:IsA("BasePart") then
            local pos = item.Position
            item.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(rotation), 0)
        end
    end
    
    local onConfirm = function(item, finalRotation)
        print("✅ Demo: Rotation confirmed at", finalRotation, "degrees")
        demoRotationUI:Hide()
    end
    
    local onCancel = function(item)
        print("❌ Demo: Rotation cancelled")
        -- Reset to 0 degrees
        if item and item:IsA("BasePart") then
            local pos = item.Position
            item.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, 0)
        end
        demoRotationUI:Hide()
    end
    
    -- Show demo after a delay
    task.spawn(function()
        task.wait(2)
        print("\n🎮 DEMO: Showing SimpleRotationUI in 3 seconds...")
        task.wait(3)
        
        print("🔄 DEMO: Rotation UI activated! Try the controls:")
        print("   📱 Touch/Mobile: Use the on-screen buttons")
        print("   🖱️  PC: Use A/D or arrow keys, or buttons")
        print("   🎮 Console: Use A/D keys or buttons")
        print("   🖲️  All: Use scroll wheel for fine rotation")
        
        demoRotationUI:Show(testPart, onRotationChanged, onConfirm, onCancel)
    end)
    
    -- Clean up after demo
    task.spawn(function()
        task.wait(30) -- Wait 30 seconds then clean up
        if testPart and testPart.Parent then
            testPart:Destroy()
            print("🧹 Cleaned up demo test part")
        end
        if demoRotationUI and demoRotationUI:IsActive() then
            demoRotationUI:Hide()
            print("🧹 Cleaned up demo rotation UI")
        end
    end)
    
else
    print("⚠️  Demo interface creation skipped (missing SimpleRotationUI or not client)")
end

-- Test 4: Instructions for real testing
print("\n🎮 INTERACTIVE TESTING INSTRUCTIONS:")
print("To test the rotation system in-game:")
print("1. 📦 Pick an item from your inventory")
print("2. 🔄 Press R to show the rotation interface")
print("3. 🖱️  Use the on-screen buttons or keyboard:")
print("   • ⟲/⟳ buttons: Rotate by 45°")
print("   • ◀/▶ buttons: Rotate by 15°")
print("   • ⌂ button: Reset to 0°")
print("   • A/D or Arrow keys: Rotate")
print("   • Scroll wheel: Fine rotation")
print("4. ✅ Click the green ✓ to confirm")
print("5. ❌ Click the red ✖ to cancel")
print("")
print("For placed items:")
print("1. 👆 Right-click on any placed item")
print("2. 🔄 Select 'Rotate' from the menu")
print("3. 🖱️  Use the same controls as above")

print("\n✅ SIMPLE ROTATION SYSTEM TEST COMPLETED")
print("🎯 The new system is designed to work on:")
print("   📱 Mobile/Tablet (touch buttons)")
print("   🖥️  PC (keyboard + buttons)")
print("   🎮 Console (controller + buttons)")
print("   🖲️  All platforms (scroll wheel)")
print("")
print("Try it out in game and see how intuitive it feels!") 