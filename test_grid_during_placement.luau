-- Test script to verify grid shows during placement
print("🔧 GRID DURING PLACEMENT TEST 🔧")

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Check if GridSnapSystem is available
local gridSnapSystem = _G.GridSnapSystem
if not gridSnapSystem then
    print("❌ GridSnapSystem not found globally")
    return
end

print("✅ GridSnapSystem found")
print("   Current state: " .. (gridSnapSystem.enabled and "ENABLED" or "DISABLED"))
print("   Grid size: " .. gridSnapSystem.gridSize)

-- Enable grid if it's disabled
if not gridSnapSystem.enabled then
    print("🔧 Enabling grid snap for testing...")
    gridSnapSystem:ToggleGridSnap()
end

-- Test function to simulate placement preview
local function simulatePlacementPreview()
    print("🔄 Simulating placement preview...")
    
    -- Get mouse hit position
    local hitPos = mouse.Hit.Position
    print("   Mouse position:", hitPos)
    
    -- Test ProcessPlacement function
    local itemSize = Vector3.new(4, 4, 4) -- Standard cube size
    local snappedPos, snappedRot, hasCollision, collidingObject = gridSnapSystem:ProcessPlacement(
        hitPos, 
        CFrame.new(), 
        itemSize, 
        nil
    )
    
    print("   Snapped position:", snappedPos)
    print("   Has collision:", hasCollision)
    if collidingObject then
        print("   Colliding with:", collidingObject.Name)
    end
    
    return snappedPos
end

-- Instructions
print("🎮 INSTRUCTIONS:")
print("   1. Press G to toggle grid snap on/off")
print("   2. Press Shift+G to cycle grid sizes")
print("   3. Press SPACE to test placement at mouse position")
print("   4. Move your mouse around to see grid follow")

-- Set up space key to test placement
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.Space then
        local snappedPos = simulatePlacementPreview()
        print("✅ Placement test completed at:", snappedPos)
    end
end)

-- Continuous mouse tracking for grid preview
local lastGridUpdate = 0
local gridUpdateInterval = 0.1 -- Update grid every 100ms

game:GetService("RunService").Heartbeat:Connect(function()
    local now = tick()
    if now - lastGridUpdate >= gridUpdateInterval then
        lastGridUpdate = now
        
        -- Show grid at mouse position if grid is enabled
        if gridSnapSystem.enabled then
            local hitPos = mouse.Hit.Position
            gridSnapSystem:ShowGrid(hitPos)
        end
    end
end)

print("🔧 Grid During Placement Test Setup Complete 🔧")
print("🔹 Move your mouse around to test grid following!") 