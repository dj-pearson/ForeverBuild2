-- Test script for the new clear placement controls system
print("=== PLACEMENT CONTROLS SYSTEM TEST ===")

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

-- Test 1: Check if PlacementControlsUI is available
print("\n🔍 TEST 1: Checking PlacementControlsUI")

local PlacementControlsUI
local success, err = pcall(function()
    PlacementControlsUI = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("core"):WaitForChild("placement"):WaitForChild("PlacementControlsUI"))
end)

if success and PlacementControlsUI then
    print("✅ PlacementControlsUI module loaded successfully")
    
    -- Test creating an instance
    local controlsUI = PlacementControlsUI.new()
    if controlsUI then
        print("✅ PlacementControlsUI instance created successfully")
        print("   - Is active:", controlsUI:IsActive())
    else
        print("❌ Failed to create PlacementControlsUI instance")
    end
else
    print("❌ Failed to load PlacementControlsUI:", err)
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
        
        -- Check if placement controls UI is initialized
        if PlacementManager.placementControlsUI then
            print("✅ PlacementManager has PlacementControlsUI")
        else
            print("❌ PlacementManager missing PlacementControlsUI")
        end
        
        -- Check if rotation UI is still available
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

-- Test 3: Demo the placement controls interface
print("\n🔍 TEST 3: Creating Demo Placement Controls")

if PlacementControlsUI and RunService:IsClient() then
    local demoControlsUI = PlacementControlsUI.new()
    
    -- Demo callbacks
    local onRotate = function()
        print("🔄 Demo: Rotate button activated!")
        demoControlsUI:PulseControl(2) -- Pulse the rotate control
    end
    
    local onPlace = function()
        print("✅ Demo: Place button activated!")
        demoControlsUI:PulseControl(1) -- Pulse the place control
    end
    
    local onCancel = function()
        print("❌ Demo: Cancel button activated!")
        demoControlsUI:Hide()
    end
    
    -- Show demo after a delay
    task.spawn(function()
        task.wait(2)
        print("\n🎮 DEMO: Showing PlacementControlsUI in 3 seconds...")
        task.wait(3)
        
        print("📋 DEMO: Placement controls activated!")
        print("   Try the following:")
        print("   📱 Mobile: Tap the controls in the UI")
        print("   🖥️  PC: Use SPACE for rotate, CLICK for place, RIGHT-CLICK for cancel")
        print("   🎮 Console: Use Y for rotate, A for place, B for cancel")
        
        demoControlsUI:Show("Demo_Cube", onRotate, onPlace, onCancel)
        
        -- Auto-demo some features
        task.wait(2)
        print("🔄 Demo: Auto-rotating...")
        onRotate()
        
        task.wait(2)
        print("📍 Demo: Auto-placing...")
        onPlace()
    end)
    
    -- Clean up after demo
    task.spawn(function()
        task.wait(20) -- Wait 20 seconds then clean up
        if demoControlsUI and demoControlsUI:IsActive() then
            demoControlsUI:Hide()
            print("🧹 Cleaned up demo controls UI")
        end
    end)
    
else
    print("⚠️  Demo controls creation skipped (missing PlacementControlsUI or not client)")
end

-- Test 4: Instructions for real testing
print("\n🎮 REAL TESTING INSTRUCTIONS:")
print("To test the new clear controls system:")
print("")
print("1. 📦 Select an item from your inventory")
print("2. 👀 Look for the controls panel in the BOTTOM LEFT corner")
print("3. 🎮 The panel shows three clear options:")
print("   🖱️  LEFT CLICK (or A button): Place Item")
print("   🔄 SPACE (or Y button): Rotate Item")  
print("   📦 RIGHT CLICK (or B button): Return to Inventory")
print("")
print("4. 🔄 Try clicking the rotate button (or press SPACE)")
print("5. 🎛️  The rotation UI will appear with clear controls")
print("6. ✅ Confirm rotation or ❌ cancel to return to placement")
print("7. 🖱️  Left-click to place the item where you want")
print("8. 📦 Right-click anytime to return item to inventory")

print("\n🎯 NEW FEATURES:")
print("• 📋 Clear visual instructions in bottom left")
print("• 🎮 Platform-aware controls (shows correct buttons)")
print("• 🔄 SPACE key for rotation (instead of R)")
print("• 📦 RIGHT-CLICK preserved for returning to inventory")
print("• 🖱️  Clickable controls for touch/mobile users")
print("• 🎮 Console controller support")

print("\n✅ PLACEMENT CONTROLS SYSTEM TEST COMPLETED")
print("")
print("🎉 The system now clearly shows:")
print("   • What item you're placing")
print("   • What controls are available")
print("   • How to use them on your platform")
print("   • Visual feedback when you use them")
print("")
print("No more confusion about controls! 🚀") 