-- Test ItemInteractionClient Loading After Syntax Fix
print("=== TESTING ITEMINTERACTIONCLIENT LOADING ===")

local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Wait for systems to load
task.wait(2)

print("Testing if ItemInteractionClient loads properly...")

-- 1. Check if ItemInteractionClient is available globally
local itemClient = _G.ItemInteractionClient
if itemClient then
    print("✅ ItemInteractionClient is available globally")
    
    -- Check key properties
    if itemClient.undoManager then
        print("✅ UndoManager is attached to ItemInteractionClient")
        print("   Action history length:", #itemClient.undoManager.actionHistory)
    else
        print("❌ UndoManager not found in ItemInteractionClient")
    end
    
    if itemClient.proximityEnabled then
        print("✅ Proximity UI is enabled")
    else
        print("❌ Proximity UI is disabled")
    end
    
    if itemClient.remotes then
        print("✅ Remote events are cached")
        local remoteCount = 0
        for name, remote in pairs(itemClient.remotes) do
            remoteCount = remoteCount + 1
        end
        print("   Number of cached remotes:", remoteCount)
    else
        print("❌ No remote events cached")
    end
    
else
    print("❌ ItemInteractionClient is NOT available globally")
    print("   This means the module failed to load due to syntax errors")
end

-- 2. Check if UndoManager is available globally
local undoManager = _G.UndoManager
if undoManager then
    print("✅ UndoManager is available globally")
    if undoManager.ui then
        print("✅ UndoManager UI is created")
    else
        print("❌ UndoManager UI not found")
    end
else
    print("❌ UndoManager is NOT available globally")
end

-- 3. Check if proximity UI system is working
print("\n--- PROXIMITY UI TEST ---")
if itemClient and itemClient.proximityEnabled then
    print("✅ Proximity system should be working")
    print("   Max interaction distance:", itemClient.maxInteractionDistance)
    
    if itemClient.proximityUI then
        print("✅ Proximity UI template exists")
    else
        print("❌ Proximity UI template missing")
    end
else
    print("❌ Proximity system not working")
end

-- 4. Check PlacedItemDialog integration
print("\n--- PLACEDITEMDIALOG INTEGRATION TEST ---")
local SharedModule = _G.SharedModule or require(game.ReplicatedStorage:FindFirstChild("shared"))
if SharedModule and SharedModule.PlacedItemDialog then
    print("✅ PlacedItemDialog is available in SharedModule")
    
    -- Check if ItemInteractionClient properly set up the callback
    if SharedModule.PlacedItemDialog.OnActionSelected then
        print("✅ PlacedItemDialog.OnActionSelected callback is set")
    else
        print("❌ PlacedItemDialog.OnActionSelected callback not set")
    end
else
    print("❌ PlacedItemDialog not found in SharedModule")
end

print("\n=== LOADING TEST COMPLETE ===")

if itemClient and undoManager then
    print("🎉 SUCCESS: All core systems appear to be loading properly!")
    print("📋 You should now see:")
    print("   - '[E] Interact' UI when approaching items")
    print("   - Action menu when pressing E on placed items") 
    print("   - Undo UI when performing actions")
    print("   - Undo UI when placing items from inventory")
else
    print("❌ FAILURE: Core systems are not loading properly")
    print("   Please check for any remaining syntax errors")
end 