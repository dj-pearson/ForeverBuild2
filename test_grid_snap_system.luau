-- Test Grid Snap System
print("=== TESTING GRID SNAP SYSTEM ===")

local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Wait for systems to load
task.wait(3)

print("Testing Grid Snap System functionality...")

-- 1. Check if GridSnapSystem is available
local gridSnapSystem = _G.GridSnapSystem
if gridSnapSystem then
    print("✅ GridSnapSystem is available globally")
    print("   Current grid size:", gridSnapSystem.gridSize)
    print("   Grid enabled:", gridSnapSystem.enabled)
    print("   Available grid sizes:", table.concat(gridSnapSystem.availableGridSizes, ", "))
else
    print("❌ GridSnapSystem not found globally")
    
    -- Try to create one manually for testing
    local success, GridSnapSystem = pcall(function()
        return require(game.ReplicatedStorage.shared.client.placement.GridSnapSystem)
    end)
    
    if success then
        print("✅ Successfully required GridSnapSystem module")
        gridSnapSystem = GridSnapSystem.new()
        if gridSnapSystem then
            gridSnapSystem:Initialize()
            _G.GridSnapSystem = gridSnapSystem
            print("✅ Created and initialized GridSnapSystem manually")
        end
    else
        print("❌ Failed to require GridSnapSystem module:", GridSnapSystem)
        return
    end
end

-- 2. Test basic grid snapping
print("\n--- TESTING BASIC GRID SNAPPING ---")
if gridSnapSystem then
    local testPosition = Vector3.new(12.3, 5.7, 8.9)
    local snappedPosition = gridSnapSystem:SnapToGrid(testPosition)
    
    print("Original position:", testPosition)
    print("Snapped position:", snappedPosition)
    print("Grid size:", gridSnapSystem.gridSize)
    
    -- Verify snapping worked correctly
    local expectedX = math.round(testPosition.X / gridSnapSystem.gridSize) * gridSnapSystem.gridSize
    local expectedZ = math.round(testPosition.Z / gridSnapSystem.gridSize) * gridSnapSystem.gridSize
    
    if math.abs(snappedPosition.X - expectedX) < 0.001 and math.abs(snappedPosition.Z - expectedZ) < 0.001 then
        print("✅ Grid snapping works correctly")
    else
        print("❌ Grid snapping failed")
        print("   Expected X:", expectedX, "Got:", snappedPosition.X)
        print("   Expected Z:", expectedZ, "Got:", snappedPosition.Z)
    end
end

-- 3. Test collision detection
print("\n--- TESTING COLLISION DETECTION ---")
if gridSnapSystem then
    local testPos = Vector3.new(0, 10, 0)
    local testSize = Vector3.new(4, 4, 4)
    
    local hasCollision, collidingObject = gridSnapSystem:CheckCollision(testPos, testSize, nil)
    print("Collision test at", testPos, "with size", testSize)
    print("Has collision:", hasCollision)
    if collidingObject then
        print("Colliding with:", collidingObject.Name)
    end
end

-- 4. Test surface snapping
print("\n--- TESTING SURFACE SNAPPING ---")
if gridSnapSystem then
    local testPos = Vector3.new(0, 100, 0) -- High up
    local testSize = Vector3.new(4, 4, 4)
    
    local snappedPos = gridSnapSystem:GetSurfaceSnapPosition(testPos, testSize)
    print("Original position:", testPos)
    print("Surface snapped position:", snappedPos)
    
    if snappedPos.Y < testPos.Y then
        print("✅ Surface snapping moved position down as expected")
    else
        print("ℹ️ Surface snapping didn't change position (no surface found)")
    end
end

-- 5. Test UI and controls
print("\n--- TESTING UI AND CONTROLS ---")
if gridSnapSystem then
    -- Check if UI exists
    local playerGui = player:WaitForChild("PlayerGui")
    local gridUI = playerGui:FindFirstChild("GridSnapUI")
    
    if gridUI then
        print("✅ Grid Snap UI found")
        local statusFrame = gridUI:FindFirstChild("GridStatus")
        if statusFrame then
            print("✅ Status frame found")
            local statusLabel = statusFrame:FindFirstChild("StatusLabel")
            local gridSizeLabel = statusFrame:FindFirstChild("GridSizeLabel")
            local controlsLabel = statusFrame:FindFirstChild("ControlsLabel")
            
            if statusLabel then
                print("✅ Status label:", statusLabel.Text)
            end
            if gridSizeLabel then
                print("✅ Grid size label:", gridSizeLabel.Text)
            end
            if controlsLabel then
                print("✅ Controls label:", controlsLabel.Text)
            end
        end
    else
        print("❌ Grid Snap UI not found")
    end
end

-- 6. Test complete placement processing
print("\n--- TESTING COMPLETE PLACEMENT PROCESSING ---")
if gridSnapSystem then
    local testPos = Vector3.new(15.7, 20.3, 25.1)
    local testRotation = CFrame.Angles(0, math.rad(45), 0)
    local testSize = Vector3.new(4, 4, 4)
    
    local finalPos, finalRot, hasCollision, collidingObject = gridSnapSystem:ProcessPlacement(
        testPos, 
        testRotation, 
        testSize, 
        nil
    )
    
    print("Input position:", testPos)
    print("Final position:", finalPos)
    print("Has collision:", hasCollision)
    print("Grid visual should now be showing...")
end

-- 7. Instructions for manual testing
print("\n=== MANUAL TESTING INSTRUCTIONS ===")
print("🎮 Controls to test:")
print("   G          - Toggle grid snap on/off")
print("   Shift+G    - Cycle through grid sizes (1, 2, 4, 8, 16 studs)")
print("")
print("🔧 What to test:")
print("   1. Place items from inventory - they should snap to grid")
print("   2. Items should show blue grid lines when placing")
print("   3. Preview should turn red if collision detected")
print("   4. UI should show current grid status")
print("   5. Different grid sizes should work properly")
print("")
print("✨ Expected behavior:")
print("   - Items snap to nearest grid intersection")
print("   - Visual grid appears during placement")
print("   - Collision prevention works")
print("   - Surface snapping to other objects")
print("   - Smooth grid size transitions")

print("\n=== TEST COMPLETE ===")
print("Grid Snap System is ready for professional building!") 