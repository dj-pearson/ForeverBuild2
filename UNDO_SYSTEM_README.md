# ⏮️ Undo System Implementation

## **🎯 Overview**

The Undo System provides players with a **5-second window** to undo recent actions, preventing accidental mistakes and improving user experience.

## **✨ Features**

- **5-second undo window** for all item actions
- **Visual countdown timer** with color-coded urgency
- **Ctrl+Z hotkey** for PC users
- **Smart action recording** with necessary data for reversal
- **Elegant UI notifications** with smooth animations

## **🎮 Supported Actions**

| Action      | Undo Behavior                          | Data Recorded                 |
| ----------- | -------------------------------------- | ----------------------------- |
| **Destroy** | Recreates item at original position    | Position, rotation, item type |
| **Move**    | Moves item back to original position   | Original position             |
| **Rotate**  | Rotates item back to original rotation | Original rotation             |
| **Clone**   | Destroys the cloned item               | Cloned instance ID            |
| **Recall**  | Replaces item at original position     | Position, rotation, item type |

## **🖥️ User Interface**

### Undo Notification

- **Location**: Top-center of screen
- **Content**: Action name + countdown timer
- **Colors**:
  - 🟢 Green (>3s remaining)
  - 🟠 Orange (2-3s remaining)
  - 🔴 Red (<2s remaining)

### Input Methods

- **PC**: `Ctrl+Z` to undo
- **Mobile/Console**: Not supported (requires keyboard)

## **📁 Files Added/Modified**

### New Files

- `src/client/interaction/UndoManager.luau` - Core undo system
- `test_undo_system.luau` - Testing script

### Modified Files

- `src/client/interaction/ItemInteractionClient.luau` - Integration with action system

## **🔧 Technical Implementation**

### UndoManager Class

```lua
-- Core functionality
UndoManager.new()                          -- Constructor
UndoManager:Initialize()                   -- Setup UI and connections
UndoManager:RecordAction(type, data)       -- Record undoable action
UndoManager:TryUndo()                      -- Attempt to undo latest action
UndoManager:Cleanup()                      -- Clean up connections
```

### Action Recording

Each action records specific data needed for reversal:

```lua
local actionData = {
    instanceId = itemInstance:GetAttribute("instanceId"),
    itemId = itemInstance:GetAttribute("itemId"),
    actualCost = actualCost,
    position = originalPosition,  -- For destroy/recall/move
    rotation = originalRotation,  -- For destroy/recall/rotate
    -- ... other action-specific data
}
```

### Integration Points

1. **PlacedItemDialog.OnActionSelected** - Hooked to record actions before execution
2. **Remote Events** - Uses existing DestroyItem, PlaceItem, MoveItem, etc.
3. **Global Access** - `_G.UndoManager` for easy testing and debugging

## **🧪 Testing**

### Run Test Script

```lua
-- In Roblox Studio console
loadstring(game:HttpGet("file:///test_undo_system.luau"))()
```

### Manual Testing Steps

1. Place some items in the world
2. Press E near a placed item to interact
3. Choose an action (Destroy recommended for easy testing)
4. Watch for undo notification with countdown
5. Press `Ctrl+Z` before timer expires
6. Verify action was reversed

### Debug Commands

```lua
-- Check if system is loaded
print(_G.UndoManager and "✅ Loaded" or "❌ Not loaded")

-- View action history
for i, action in ipairs(_G.UndoManager.actionHistory) do
    print(i, action.type, action.timestamp)
end

-- Force undo attempt
_G.UndoManager:TryUndo()
```

## **⚠️ Known Limitations**

1. **Clone Actions**: Complex to undo perfectly (destroys clone but doesn't refund inventory)
2. **Network Latency**: Undo timing affected by server response time
3. **Input Methods**: Only supports Ctrl+Z (PC keyboard only)
4. **Concurrent Actions**: Multiple rapid actions may conflict

## **🚀 Future Enhancements**

- Mobile/console undo button
- Multiple action undo (Ctrl+Z multiple times)
- Visual undo preview
- Server-side undo validation
- Undo history UI panel
- Action cost refunding on undo

## **🎯 UX Goals Achieved**

- ✅ **Safety Net**: Prevents accidental item loss
- ✅ **Immediate Feedback**: Clear visual countdown
- ✅ **Non-Intrusive**: Small notification, doesn't block gameplay
- ✅ **Familiar**: Standard Ctrl+Z hotkey
- ✅ **Responsive**: Works within 5-second window
