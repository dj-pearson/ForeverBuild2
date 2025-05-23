-- Test Undo System (5-Second Window)
print("=== TESTING UNDO SYSTEM ===")

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

-- Wait for systems to initialize
task.wait(3)

print("🔄 UNDO SYSTEM TEST INSTRUCTIONS:")
print("1. Look for a placed item (Glass_Cube or Brick_Cube)")
print("2. Press E to interact with it")
print("3. Choose an action (Destroy, Move, etc.)")
print("4. You'll see a notification 'Press Ctrl+Z to Undo [Action]' with countdown")
print("5. Press Ctrl+Z within 5 seconds to undo the action")
print("6. Timer shows: Green (>3s), Orange (2-3s), Red (<2s)")
print("")

-- Check if UndoManager is available
local undoManager = _G.UndoManager
if undoManager then
    print("✅ UndoManager found in _G")
    print("   Action history length:", #undoManager.actionHistory)
    print("   Undo time limit:", undoManager.UNDO_TIME_LIMIT or "unknown")
else
    print("❌ UndoManager not found in _G")
    print("   The undo system may not be initialized yet")
    
    -- Try to find ItemInteractionClient
    local itemClient = _G.ItemInteractionClient
    if itemClient and itemClient.undoManager then
        print("✅ Found UndoManager through ItemInteractionClient")
        undoManager = itemClient.undoManager
        _G.UndoManager = undoManager -- Store it globally for access
    else
        print("❌ ItemInteractionClient or its undoManager not found")
        print("   Please restart the game to initialize the undo system")
        return
    end
end

-- Monitor for undo notifications
print("\n🎯 MONITORING FOR UNDO NOTIFICATIONS:")
local monitorConnection = game:GetService("RunService").Heartbeat:Connect(function()
    local playerGui = player:FindFirstChild("PlayerGui")
    if playerGui then
        local undoUI = playerGui:FindFirstChild("UndoManagerUI")
        if undoUI then
            local notification = undoUI:FindFirstChild("UndoNotification")
            if notification and notification.Visible then
                local undoLabel = notification:FindFirstChild("UndoLabel")
                local timerLabel = notification:FindFirstChild("TimerLabel")
                
                if undoLabel and timerLabel then
                    -- Only print every 30 frames to avoid spam
                    if tick() % 0.5 < 0.016 then -- Roughly every 0.5 seconds
                        print(string.format("🔔 UNDO AVAILABLE: %s | Time left: %s", 
                            undoLabel.Text, timerLabel.Text))
                    end
                end
            end
        end
    end
end)

-- Show current input method
local function getCurrentInputMethod()
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        return "Mobile/Tablet - Undo not available (Ctrl+Z not supported)"
    elseif UserInputService.GamepadEnabled then
        return "Console/Gamepad - Undo not available (Ctrl+Z not supported)"
    else
        return "PC/Keyboard - Ctrl+Z to undo"
    end
end

print("🎮 Input Method:", getCurrentInputMethod())

-- Test with a world item
print("\n📦 WORLD ITEMS AVAILABLE FOR TESTING:")
local worldItems = workspace:FindFirstChild("World_Items")
if worldItems then
    local placed = worldItems:FindFirstChild("Placed")
    if placed then
        for _, item in pairs(placed:GetChildren()) do
            if item:IsA("Model") then
                local instanceId = item:GetAttribute("instanceId")
                local itemId = item:GetAttribute("itemId")
                local position = item.PrimaryPart and item.PrimaryPart.Position or "unknown"
                print(string.format("  📋 %s (ID: %s, Instance: %s) at %s", 
                    item.Name, itemId or "none", instanceId or "none", tostring(position)))
            end
        end
        
        if #placed:GetChildren() == 0 then
            print("  ❌ No placed items found. Place some items first to test undo.")
        end
    else
        print("  ❌ No Placed folder found in World_Items")
    end
else
    print("  ❌ No World_Items folder found")
end

-- Manual undo test function
print("\n🧪 MANUAL TESTING:")
print("You can manually test undo by running:")
print("_G.UndoManager:TryUndo()  -- Force an undo attempt")

-- Stop monitoring after 60 seconds
task.delay(60, function()
    monitorConnection:Disconnect()
    print("🛑 Undo system monitoring stopped after 60 seconds")
end) 