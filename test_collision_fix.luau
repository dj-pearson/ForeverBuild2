-- Test script to verify collision detection fix
print("🔧 COLLISION DETECTION FIX TEST 🔧")

local gridSnapSystem = _G.GridSnapSystem
if not gridSnapSystem then
    print("❌ GridSnapSystem not found globally")
    return
end

print("✅ GridSnapSystem found")

-- Enable grid snap if not already enabled
if not gridSnapSystem.enabled then
    gridSnapSystem:ToggleGridSnap()
    print("✅ Grid snap enabled for testing")
end

-- Test collision detection function directly
print("\n=== Testing Collision Detection ===")
local testPosition = Vector3.new(0, 5, 0)
local testSize = Vector3.new(4, 4, 4)

local hasCollision, collidingObject = gridSnapSystem:CheckCollision(testPosition, testSize, nil)
print("Collision test at", testPosition)
print("   Has collision:", hasCollision)
if collidingObject then
    print("   Colliding with:", collidingObject.Name)
else
    print("   No collision detected")
end

-- Test ProcessPlacement function
print("\n=== Testing ProcessPlacement Function ===")
local snappedPos, snappedRot, collision, collider = gridSnapSystem:ProcessPlacement(
    testPosition, 
    CFrame.new(), 
    testSize, 
    nil
)

print("ProcessPlacement test:")
print("   Original position:", testPosition)
print("   Snapped position:", snappedPos)
print("   Has collision:", collision)
if collider then
    print("   Colliding with:", collider.Name)
end

print("✅ Collision detection should now work without errors!")
print("🔧 You can now try placing items and the grid should appear without errors")

print("\n🔧 Collision Detection Fix Test Complete 🔧") 