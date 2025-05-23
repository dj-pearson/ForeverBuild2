-- Test Inventory Placement Undo System
print("=== TESTING INVENTORY PLACEMENT UNDO ===")

local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Wait for systems to load
task.wait(3)

print("Checking inventory placement undo system...")

-- 1. Check if ItemInteractionClient is loaded and has ItemPlaced handler
local itemClient = _G.ItemInteractionClient
if itemClient then
    print("✅ ItemInteractionClient is available")
    
    -- Check if ItemPlaced remote is cached
    if itemClient.remotes and itemClient.remotes.ItemPlaced then
        print("✅ ItemPlaced remote event is cached")
        print("   Event type:", typeof(itemClient.remotes.ItemPlaced))
        
        -- Set up a test listener to see if events are firing
        local testConnection = itemClient.remotes.ItemPlaced.OnClientEvent:Connect(function(...)
            local args = {...}
            print("🔔 ItemPlaced event fired with args:", table.unpack(args))
            
            -- Also check what the UndoManager does
            local undoManager = _G.UndoManager
            if undoManager then
                print("   UndoManager action count before:", #undoManager.actionHistory)
                
                -- Wait a moment and check again
                task.wait(0.5)
                print("   UndoManager action count after:", #undoManager.actionHistory)
                
                if #undoManager.actionHistory > 0 then
                    local lastAction = undoManager.actionHistory[#undoManager.actionHistory]
                    print("   Last action:", lastAction.type, lastAction.data.itemId)
                end
            end
        end)
        
        -- Clean up the test connection after 30 seconds
        task.delay(30, function()
            testConnection:Disconnect()
            print("🧹 Test listener disconnected")
        end)
        
    else
        print("❌ ItemPlaced remote event NOT found in cached remotes")
        print("   Available remotes:")
        if itemClient.remotes then
            for name, remote in pairs(itemClient.remotes) do
                print("     -", name, typeof(remote))
            end
        else
            print("     No remotes cached at all")
        end
    end
    
    -- Check UndoManager
    if itemClient.undoManager then
        print("✅ UndoManager is attached to ItemInteractionClient")
        print("   Current action count:", #itemClient.undoManager.actionHistory)
    else
        print("❌ UndoManager not found in ItemInteractionClient")
    end
    
else
    print("❌ ItemInteractionClient not available")
    return
end

-- 2. Check if the server has ItemPlaced remote event
print("\n--- CHECKING SERVER REMOTES ---")
local remotes = game.ReplicatedStorage:FindFirstChild("Remotes")
if remotes then
    local itemPlacedEvent = remotes:FindFirstChild("ItemPlaced")
    if itemPlacedEvent then
        print("✅ ItemPlaced remote event exists on server")
        print("   Type:", typeof(itemPlacedEvent))
        print("   ClassName:", itemPlacedEvent.ClassName)
    else
        print("❌ ItemPlaced remote event NOT found on server")
        print("   Available remotes:")
        for _, child in pairs(remotes:GetChildren()) do
            if child:IsA("RemoteEvent") then
                print("     -", child.Name, "(RemoteEvent)")
            elseif child:IsA("RemoteFunction") then
                print("     -", child.Name, "(RemoteFunction)")
            end
        end
    end
else
    print("❌ Remotes folder not found")
end

-- 3. Check PlacementManager to see if it fires ItemPlaced
print("\n--- CHECKING PLACEMENTMANAGER ---")
local SharedModule = _G.SharedModule
if SharedModule and SharedModule.PlacementManager then
    print("✅ PlacementManager available in SharedModule")
    
    -- Check if there's a client instance
    if SharedModule.PlacementManagerClientInstance then
        print("✅ PlacementManagerClientInstance exists")
    else
        print("❌ PlacementManagerClientInstance not found")
    end
else
    print("❌ PlacementManager not found in SharedModule")
end

-- 4. Manual test - let's try to simulate what should happen
print("\n--- MANUAL SIMULATION TEST ---")
local undoManager = _G.UndoManager
if undoManager then
    print("Testing manual undo recording...")
    
    -- Simulate what should happen when an item is placed
    local testActionData = {
        instanceId = "Test_Manual_" .. os.time(),
        itemId = "Grass_Cube",
        actualCost = 0,
        position = Vector3.new(10, 5, 10),
        rotation = CFrame.new()
    }
    
    print("Recording test 'place' action...")
    undoManager:RecordAction("place", testActionData)
    
    print("✅ Manual test complete")
    print("   Action history count:", #undoManager.actionHistory)
    
    if #undoManager.actionHistory > 0 then
        print("   Last action:", undoManager.actionHistory[#undoManager.actionHistory].type)
        print("✅ Manual undo recording works - the issue is event firing")
    end
else
    print("❌ UndoManager not available for manual test")
end

print("\n=== TEST COMPLETE ===")
print("\n📋 NEXT STEPS:")
print("1. Place an item from inventory and watch the output")
print("2. If you see 'ItemPlaced event fired', the event works but undo recording might be broken")
print("3. If you DON'T see the event, the server isn't firing ItemPlaced when placing from inventory")
print("4. Check if ItemPlaced fires from server-side PlacementManager")

print("\n🔍 WATCHING FOR ITEMPLACED EVENTS... (next 30 seconds)")
print("   Go place an item from your inventory now!") 