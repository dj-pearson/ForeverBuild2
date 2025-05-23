-- Test script to diagnose GridSnapSystem loading issues
print("🔧 GRID SNAP SYSTEM LOADING TEST 🔧")

-- Test 1: Check global availability
print("\n=== Test 1: Check Global Availability ===")
local gridSnapSystem = _G.GridSnapSystem
if gridSnapSystem then
    print("✅ GridSnapSystem is available globally")
    print("   Type:", type(gridSnapSystem))
    print("   Grid size:", gridSnapSystem.gridSize or "undefined")
    print("   Enabled:", gridSnapSystem.enabled or "undefined")
else
    print("❌ GridSnapSystem not found globally")
end

-- Test 2: Try manual require with different paths
print("\n=== Test 2: Manual Require Test ===")
local paths = {
    "game.ReplicatedStorage.shared.client.placement.GridSnapSystem",
    "game.Workspace.src.client.placement.GridSnapSystem",
}

for i, path in ipairs(paths) do
    print("Testing path " .. i .. ": " .. path)
    local success, result = pcall(function()
        return require(loadstring("return " .. path)())
    end)
    
    if success then
        print("✅ Path " .. i .. " works!")
        print("   Module type:", type(result))
        if type(result) == "table" then
            print("   Has .new method:", result.new ~= nil)
        end
        break
    else
        print("❌ Path " .. i .. " failed:", result)
    end
end

-- Test 3: Check if ItemInteractionClient has initialized GridSnapSystem
print("\n=== Test 3: ItemInteractionClient Check ===")
if _G.ItemInteractionClient then
    print("✅ ItemInteractionClient is available globally")
    if _G.ItemInteractionClient.gridSnapSystem then
        print("✅ ItemInteractionClient.gridSnapSystem exists")
        print("   Type:", type(_G.ItemInteractionClient.gridSnapSystem))
    else
        print("❌ ItemInteractionClient.gridSnapSystem is nil")
    end
else
    print("❌ ItemInteractionClient not found globally")
end

-- Test 4: Try to manually create and initialize
print("\n=== Test 4: Manual Creation Test ===")
if not gridSnapSystem then
    local success, GridSnapSystem = pcall(function()
        return require(game.ReplicatedStorage.shared.client.placement.GridSnapSystem)
    end)
    
    if success then
        print("✅ Successfully required GridSnapSystem module")
        local instance = GridSnapSystem.new()
        if instance then
            print("✅ Successfully created GridSnapSystem instance")
            instance:Initialize()
            _G.GridSnapSystem = instance
            print("✅ Manually initialized and stored globally")
            
            -- Test the G key functionality
            print("✅ GridSnapSystem should now respond to G key presses")
        else
            print("❌ Failed to create GridSnapSystem instance")
        end
    else
        print("❌ Failed to require GridSnapSystem:", GridSnapSystem)
    end
end

print("\n🔧 Grid Snap System Loading Test Complete 🔧") 