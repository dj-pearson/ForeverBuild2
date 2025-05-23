-- Test Undo System for Both Placement and Actions
print("=== TESTING UNDO SYSTEM FOR PLACEMENTS AND ACTIONS ===")

local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Wait for systems to load
task.wait(3)

print("Testing undo system functionality...")

-- 1. Check if UndoManager is available
local undoManager = _G.UndoManager
if undoManager then
    print("✅ UndoManager is available globally")
    print("   Action history length:", #undoManager.actionHistory)
else
    print("❌ UndoManager not found globally")
    return
end

-- 2. Check if ItemInteractionClient has undo manager
local itemClient = _G.ItemInteractionClient
if itemClient then
    print("✅ ItemInteractionClient is available")
    if itemClient.undoManager then
        print("✅ ItemInteractionClient has UndoManager")
    else
        print("❌ ItemInteractionClient missing UndoManager")
    end
else
    print("❌ ItemInteractionClient not available")
end

-- 3. Test function to simulate placement
local function simulatePlacement()
    print("\n--- SIMULATING ITEM PLACEMENT ---")
    
    -- Simulate what happens when an item is placed from inventory
    -- This would normally be triggered by the ItemPlaced event
    if undoManager then
        local testActionData = {
            instanceId = "Test_Cube_" .. os.time(),
            itemId = "Test_Cube",
            actualCost = 0,
            position = Vector3.new(10, 5, 10),
            rotation = CFrame.new()
        }
        
        undoManager:RecordAction("place", testActionData)
        print("✅ Recorded test placement action")
        print("   New action history length:", #undoManager.actionHistory)
        
        return testActionData
    end
    
    return nil
end

-- 4. Test undo functionality
local function testUndo(actionData)
    if not actionData then return end
    
    print("\n--- TESTING UNDO FUNCTIONALITY ---")
    
    -- Try to undo the placement
    local undoButton = undoManager.ui and undoManager.ui:FindFirstChild("UndoButton")
    if undoButton then
        print("✅ Undo button found")
        print("   Button text:", undoButton.Text)
        print("   Button visible:", undoButton.Visible)
        
        -- Check if button is clickable (should be true if there are actions)
        if #undoManager.actionHistory > 0 then
            print("✅ Undo should be available (actions in history)")
            
            -- Simulate clicking undo button
            print("🔄 Attempting to trigger undo...")
            local success, result = pcall(function()
                return undoManager:TryUndo()
            end)
            
            if success and result then
                print("✅ Undo operation succeeded")
            else
                print("❌ Undo operation failed:", result)
            end
        else
            print("❌ No actions available for undo")
        end
    else
        print("❌ Undo button not found")
    end
end

-- 5. Check remote events for undo
local function checkRemoteEvents()
    print("\n--- CHECKING REMOTE EVENTS FOR UNDO ---")
    
    local remotes = game.ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        print("✅ Remotes folder found")
        
        local requiredEvents = {"PlaceItem", "ItemPlaced", "DestroyItem", "CloneItem", "RecallItem"}
        for _, eventName in ipairs(requiredEvents) do
            local event = remotes:FindFirstChild(eventName)
            if event then
                print("✅", eventName, "remote found")
            else
                print("❌", eventName, "remote missing")
            end
        end
    else
        print("❌ Remotes folder not found")
    end
end

-- 6. Test ItemPlaced handler setup
local function checkItemPlacedHandler()
    print("\n--- CHECKING ITEMPLACED HANDLER SETUP ---")
    
    if itemClient and itemClient.remotes then
        local itemPlacedEvent = itemClient.remotes.ItemPlaced
        if itemPlacedEvent then
            print("✅ ItemPlaced remote event found in ItemInteractionClient")
            
            -- Check if there are connections (hard to verify without internal access)
            print("   Event type:", typeof(itemPlacedEvent))
        else
            print("❌ ItemPlaced remote event not found in ItemInteractionClient")
        end
    else
        print("❌ Cannot check - ItemInteractionClient or remotes not available")
    end
end

-- Run all tests
print("\n🔍 Starting comprehensive undo system test...")

checkRemoteEvents()
checkItemPlacedHandler()

local placementData = simulatePlacement()
testUndo(placementData)

-- 7. Print current undo system status
print("\n--- CURRENT UNDO SYSTEM STATUS ---")
if undoManager then
    print("Action history count:", #undoManager.actionHistory)
    print("Undo enabled:", undoManager.enabled)
    print("Time window:", undoManager.timeWindow, "seconds")
    
    -- List recent actions
    if #undoManager.actionHistory > 0 then
        print("Recent actions:")
        for i = math.max(1, #undoManager.actionHistory - 2), #undoManager.actionHistory do
            local action = undoManager.actionHistory[i]
            local timeLeft = (action.timestamp + undoManager.timeWindow) - tick()
            print(string.format("  %d. %s (%s) - %.1fs left", i, action.type, action.data.itemId or "unknown", timeLeft))
        end
    else
        print("No actions in history")
    end
end

print("\n=== UNDO SYSTEM TEST COMPLETE ===")

-- Instructions for user
print("\n📋 TESTING INSTRUCTIONS:")
print("1. Place an item from your inventory")
print("2. Look for the undo UI to appear with a 5-second countdown")
print("3. Try pressing Ctrl+Z or clicking the undo button")
print("4. The item should be destroyed and you should get it back in inventory")
print("5. Then try performing an action on a placed item (destroy, clone, etc.)")
print("6. Again look for the undo UI and test undoing that action") 