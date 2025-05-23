-- Quick test to verify GridSnapSystem functionality
print("🔧 QUICK GRID SNAP TEST 🔧")

-- Check if GridSnapSystem is available
local gridSnapSystem = _G.GridSnapSystem
if gridSnapSystem then
    print("✅ GridSnapSystem found globally")
    print("   Enabled:", gridSnapSystem.enabled)
    print("   Grid size:", gridSnapSystem.gridSize)
    
    -- Test if status UI exists
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    local gridUI = playerGui:FindFirstChild("GridSnapUI")
    
    if gridUI then
        print("✅ GridSnapUI found in PlayerGui")
        local statusFrame = gridUI:FindFirstChild("GridStatus")
        if statusFrame then
            print("✅ Status frame found")
            print("   Visible:", statusFrame.Visible)
            
            -- Show the UI temporarily for testing
            statusFrame.Visible = true
            print("✅ Made status UI visible for testing")
            
            -- Hide it after 3 seconds
            task.delay(3, function()
                statusFrame.Visible = false
                print("🔹 Status UI auto-hidden after 3 seconds")
            end)
        else
            print("❌ Status frame not found")
        end
    else
        print("❌ GridSnapUI not found in PlayerGui")
    end
    
    -- Test grid snapping function
    local testPos = Vector3.new(5.7, 10.3, 8.9)
    local snappedPos = gridSnapSystem:SnapToGrid(testPos)
    print("✅ Grid snapping test:")
    print("   Original:", testPos)
    print("   Snapped:", snappedPos)
    
    -- Test showing grid
    if gridSnapSystem.enabled then
        print("✅ Showing test grid at origin")
        gridSnapSystem:ShowGrid(Vector3.new(0, 0, 0))
        
        task.delay(5, function()
            gridSnapSystem:HideGrid()
            print("🔹 Test grid hidden after 5 seconds")
        end)
    else
        print("🔹 Grid snap is disabled - enable with G key to see grid")
    end
else
    print("❌ GridSnapSystem not found globally")
end

print("🔧 Quick Grid Snap Test Complete 🔧") 