-- Quick Test for Interaction & Undo Systems
print("=== QUICK SYSTEM TEST ===")

local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Wait a moment for systems to load
task.wait(2)

print("Testing system status after syntax fix...")

-- 1. Check if ItemInteractionClient loaded
local itemClient = _G.ItemInteractionClient
if itemClient then
    print("✅ ItemInteractionClient is loaded")
    
    -- Check if it has undo manager
    if itemClient.undoManager then
        print("✅ UndoManager is available through ItemInteractionClient")
        print("   Action history length:", #itemClient.undoManager.actionHistory)
        
        -- Check if it's also in global
        if _G.UndoManager then
            print("✅ UndoManager also available globally")
        else
            print("⚠️  UndoManager not in _G, but available through ItemInteractionClient")
        end
    else
        print("❌ UndoManager not found in ItemInteractionClient")
    end
    
    -- Check proximity settings
    if itemClient.proximityEnabled then
        print("✅ Proximity UI is enabled")
    else
        print("❌ Proximity UI is disabled")
    end
else
    print("❌ ItemInteractionClient not found in _G")
    print("   The interaction system is not loaded")
end

-- 2. Check for undo UI
local playerGui = player:FindFirstChild("PlayerGui")
if playerGui then
    local undoUI = playerGui:FindFirstChild("UndoManagerUI")
    if undoUI then
        print("✅ UndoManagerUI found in PlayerGui")
        
        local notification = undoUI:FindFirstChild("UndoNotification")
        if notification then
            print("✅ UndoNotification frame exists")
            print("   Currently visible:", notification.Visible)
        else
            print("❌ UndoNotification frame not found")
        end
    else
        print("❌ UndoManagerUI not found in PlayerGui")
    end
else
    print("❌ PlayerGui not found")
end

-- 3. Check for interaction targets
print("\n🎯 INTERACTION TARGETS:")
local worldItems = workspace:FindFirstChild("World_Items")
if worldItems then
    local placed = worldItems:FindFirstChild("Placed")
    if placed and #placed:GetChildren() > 0 then
        print("✅ Found " .. #placed:GetChildren() .. " placed items to interact with")
        
        -- List first few items
        for i, item in ipairs(placed:GetChildren()) do
            if i <= 3 then
                local instanceId = item:GetAttribute("instanceId")
                local itemId = item:GetAttribute("itemId")
                print(string.format("   📦 %s (ID: %s, Instance: %s)", 
                    item.Name, itemId or "none", instanceId or "none"))
            end
        end
    else
        print("❌ No placed items found to interact with")
        print("   Place some items first to test interactions")
    end
else
    print("❌ World_Items folder not found")
end

-- 4. Simple instructions
print("\n📋 TESTING INSTRUCTIONS:")
if itemClient and itemClient.proximityEnabled then
    print("1. Walk near a placed item")
    print("2. Look for '[E] Interact' prompt to appear")
    print("3. Press E to open the action menu")
    print("4. Choose an action (Destroy, Clone, etc.)")
    print("5. Look for undo notification with countdown timer")
    print("6. Press Ctrl+Z within 5 seconds to undo")
else
    print("⚠️  Systems not ready - restart the game to reload")
end

print("=== TEST COMPLETE ===") 