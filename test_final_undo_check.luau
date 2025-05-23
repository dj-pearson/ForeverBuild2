-- Final Comprehensive Test for Inventory Placement Undo
print("=== FINAL UNDO SYSTEM COMPREHENSIVE TEST ===")

local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Wait for systems to load
task.wait(3)

print("🔍 Testing all undo system components...")

-- 1. Check ItemInteractionClient
local itemClient = _G.ItemInteractionClient
print("\n--- ItemInteractionClient Status ---")
if itemClient then
    print("✅ ItemInteractionClient is available")
    
    -- Check remote caching
    if itemClient.remotes then
        print("✅ Remotes are cached:")
        for name, remote in pairs(itemClient.remotes) do
            print(string.format("   - %s (%s)", name, typeof(remote)))
        end
        
        if itemClient.remotes.ItemPlaced then
            print("✅ ItemPlaced remote is cached and ready")
        else
            print("❌ ItemPlaced remote NOT cached")
        end
    else
        print("❌ No remotes cached")
    end
    
    -- Check UndoManager
    if itemClient.undoManager then
        print("✅ UndoManager is attached")
    else
        print("❌ UndoManager not attached")
    end
else
    print("❌ ItemInteractionClient NOT available")
end

-- 2. Check UndoManager
local undoManager = _G.UndoManager
print("\n--- UndoManager Status ---")
if undoManager then
    print("✅ UndoManager is available globally")
    print("   Action history count:", #undoManager.actionHistory)
    
    -- Check remote caching
    if undoManager.remotes then
        print("✅ UndoManager remotes cached:")
        for name, remote in pairs(undoManager.remotes) do
            print(string.format("   - %s (%s)", name, typeof(remote)))
        end
        
        if undoManager.remotes.DestroyItem then
            print("✅ DestroyItem remote available for undoing placements")
        else
            print("❌ DestroyItem remote NOT available - undo won't work")
        end
    else
        print("❌ UndoManager has no remotes cached")
    end
    
    -- Check UI
    if undoManager.undoUI then
        print("✅ UndoManager UI created")
        local notification = undoManager.undoUI:FindFirstChild("UndoNotification")
        if notification then
            print("✅ Undo notification UI found")
        else
            print("❌ Undo notification UI missing")
        end
    else
        print("❌ UndoManager UI not created")
    end
else
    print("❌ UndoManager NOT available globally")
end

-- 3. Test manual undo recording
print("\n--- Manual Undo Test ---")
if undoManager then
    local beforeCount = #undoManager.actionHistory
    
    -- Simulate a placement action
    local testData = {
        instanceId = "TestItem_" .. os.time(),
        itemId = "Grass_Cube",
        actualCost = 0,
        position = Vector3.new(10, 5, 10),
        rotation = CFrame.new()
    }
    
    undoManager:RecordAction("place", testData)
    local afterCount = #undoManager.actionHistory
    
    if afterCount > beforeCount then
        print("✅ Manual undo recording works")
        print("   Action count increased from", beforeCount, "to", afterCount)
        
        -- Try to undo
        print("🔄 Testing undo functionality...")
        task.wait(0.5) -- Brief delay
        
        local undoSuccess, undoResult = pcall(function()
            return undoManager:TryUndo()
        end)
        
        if undoSuccess then
            print("✅ Undo operation completed without errors")
        else
            print("❌ Undo operation failed:", undoResult)
        end
    else
        print("❌ Manual undo recording failed")
    end
else
    print("❌ Cannot test - UndoManager not available")
end

-- 4. Set up ItemPlaced event monitoring
print("\n--- ItemPlaced Event Monitoring ---")
if itemClient and itemClient.remotes and itemClient.remotes.ItemPlaced then
    print("✅ Setting up ItemPlaced event monitor...")
    
    local monitorConnection = itemClient.remotes.ItemPlaced.OnClientEvent:Connect(function(...)
        local args = {...}
        print("🔔 DETECTED ITEMPLACED EVENT:")
        print("   Args:", table.unpack(args))
        
        -- Check if undo was recorded
        task.wait(0.2)
        if undoManager then
            print("   UndoManager action count after event:", #undoManager.actionHistory)
            if #undoManager.actionHistory > 0 then
                local lastAction = undoManager.actionHistory[1]
                print("   Last recorded action:", lastAction.type, lastAction.data.itemId)
                print("✅ UNDO FOR INVENTORY PLACEMENT IS WORKING!")
            else
                print("❌ No undo action recorded after ItemPlaced event")
            end
        end
    end)
    
    -- Clean up after 60 seconds
    task.delay(60, function()
        monitorConnection:Disconnect()
        print("🧹 ItemPlaced monitor disconnected")
    end)
    
    print("✅ ItemPlaced monitor active for 60 seconds")
else
    print("❌ Cannot monitor - ItemPlaced remote not available")
end

-- 5. Check server-side setup
print("\n--- Server-Side Check ---")
local remotes = game.ReplicatedStorage:FindFirstChild("Remotes")
if remotes then
    local itemPlaced = remotes:FindFirstChild("ItemPlaced")
    local destroyItem = remotes:FindFirstChild("RequestDestroyItem") or remotes:FindFirstChild("DestroyItem")
    
    print("✅ Remotes folder found")
    print("   ItemPlaced remote:", itemPlaced and "✅ Found" or "❌ Missing")
    print("   DestroyItem remote:", destroyItem and "✅ Found" or "❌ Missing")
    
    if itemPlaced and destroyItem then
        print("✅ All required remotes are available")
    else
        print("❌ Missing required remotes for undo system")
    end
else
    print("❌ Remotes folder not found")
end

print("\n=== TEST COMPLETE ===")

-- Final status
local allSystemsGo = itemClient and undoManager and 
                    itemClient.remotes and itemClient.remotes.ItemPlaced and
                    undoManager.remotes and undoManager.remotes.DestroyItem

if allSystemsGo then
    print("\n🎉 ALL SYSTEMS GREEN!")
    print("📋 TESTING INSTRUCTIONS:")
    print("1. Place an item from your inventory")
    print("2. You should see: '🔔 DETECTED ITEMPLACED EVENT' in output")
    print("3. Undo UI should appear with 5-second countdown")
    print("4. Press Ctrl+Z or wait for countdown to test undo")
    print("5. Item should be destroyed and returned to inventory")
else
    print("\n❌ SOME SYSTEMS NOT READY")
    print("Check the errors above to see what's missing")
end

print("\n🔍 MONITORING FOR EVENTS... Place an item now!") 