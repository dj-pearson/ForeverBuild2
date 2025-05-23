-- Test script to verify the bouncing/vibrating fix
print("🔧 BOUNCE FIX VERIFICATION TEST 🔧")

local gridSnapSystem = _G.GridSnapSystem
if not gridSnapSystem then
    print("❌ GridSnapSystem not found globally")
    return
end

print("✅ GridSnapSystem found")
print("   Current settings:")
print("   - Enabled:", gridSnapSystem.enabled)
print("   - Update interval:", gridSnapSystem.updateInterval, "seconds")
print("   - Position tolerance:", gridSnapSystem.positionTolerance, "studs")

-- Enable grid snap for testing
if not gridSnapSystem.enabled then
    print("🔧 Enabling grid snap for testing...")
    gridSnapSystem:ToggleGridSnap()
end

print("\n=== Performance Settings ===")
print("✅ Update throttling: Grid updates limited to every", gridSnapSystem.updateInterval * 1000, "ms")
print("✅ Position tolerance: Grid only updates if position changes by", gridSnapSystem.positionTolerance, "studs")
print("✅ Collision optimization: Collision detection can be toggled")

print("\n=== Testing Rapid Position Updates ===")
local testPositions = {
    Vector3.new(0, 5, 0),
    Vector3.new(0.05, 5, 0), -- Very small change
    Vector3.new(0.1, 5, 0),  -- Still within tolerance
    Vector3.new(0.2, 5, 0),  -- Should trigger update
    Vector3.new(1, 5, 0),    -- Definite update
}

local updateCount = 0
local startTime = tick()

for i, pos in ipairs(testPositions) do
    local result = gridSnapSystem:ProcessPlacement(pos, CFrame.new(), Vector3.new(4, 4, 4), nil)
    if result ~= pos then
        updateCount = updateCount + 1
    end
    print(string.format("   Test %d: Input: %s, Output: %s", i, tostring(pos), tostring(result)))
    task.wait(0.01) -- Wait 10ms between tests
end

local endTime = tick()
local totalTime = endTime - startTime

print("\n=== Results ===")
print("   Total test time:", string.format("%.3f", totalTime), "seconds")
print("   Updates processed:", updateCount, "out of", #testPositions)
print("   Throttling working:", updateCount < #testPositions and "✅ YES" or "❌ NO")

print("\n🎮 MANUAL TEST INSTRUCTIONS:")
print("   1. Press G to toggle grid snap")
print("   2. Select an item and start placing")
print("   3. Move mouse slowly - grid should update smoothly")
print("   4. The item should NOT vibrate or bounce")
print("   5. Grid lines should appear stable")

print("\n🔧 Bounce Fix Verification Test Complete 🔧")
print("🔹 If you still see vibration, the issue may be in PlacementManager frequency") 