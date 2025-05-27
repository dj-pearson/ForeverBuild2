# Placement System Migration Guide

## Overview
This guide helps you transition from the monolithic `PlacementManager_Core` to the new modular placement system while maintaining backward compatibility.

## Current Architecture

### Monolithic System (Current)
```
PlacementManager.luau (wrapper)
├── PlacementManager_Core.luau (981 lines, everything in one file)
└── Placement_Utils.luau (helper functions)
```

### Modular System (New)
```
PlacementManager.luau (smart wrapper)
├── PlacementCore.luau (orchestrator)
└── modules/
    ├── ItemTemplateManager.luau
    ├── PreviewManager.luau
    ├── PlacementValidator.luau
    ├── ItemDataManager.luau
    ├── RemoteEventManager.luau
    └── MovementManager.luau
```

## Migration Steps

### Phase 1: Fix Current Issues (COMPLETED ✅)
- [x] Separated client/server logic in PlacementManager_Core
- [x] Fixed remote event setup conflicts
- [x] Added proper error handling and logging
- [x] Created integration test suite

### Phase 2: Gradual Migration (OPTIONAL)
To switch to the modular system:

1. **Update the wrapper configuration:**
   ```lua
   -- In PlacementManager.luau, change:
   local USE_MODULAR_SYSTEM = true
   ```

2. **Test thoroughly:**
   ```lua
   -- Run integration tests
   local test = require(path.to.PlacementIntegrationTest)
   test:RunAllTests()
   ```

3. **Update any direct references:**
   - Change `PlacementManager_Core` → `PlacementManager`
   - Ensure all calls go through the wrapper

### Phase 3: Full Migration (FUTURE)
When ready to fully migrate:

1. **Move custom logic to appropriate modules**
2. **Update SharedModule.luau references**
3. **Remove PlacementManager_Core.luau**
4. **Set USE_MODULAR_SYSTEM = true permanently**

## Integration Checklist

### ✅ Critical Fixes Applied
- [x] **Server/Client Separation**: Fixed mixed logic in constructor
- [x] **Remote Events**: Cleaned up duplicate setup code
- [x] **Error Handling**: Added proper pcall wrapping
- [x] **Logging**: Added clear debug messages
- [x] **Backward Compatibility**: Maintained existing API

### 🔍 Things to Monitor

#### 1. **Remote Event Synchronization**
```lua
-- Ensure these events exist and work:
- RequestPlaceItem / ItemPlaced
- RequestRecallItem / ItemRecalled  
- RequestMoveItem / ItemUpdated
- RequestRotateItem / ItemUpdated
```

#### 2. **Module Dependencies**
```lua
-- Watch for these potential issues:
- UniqueItemIdAssigner (server-only)
- RotationControlsUI (client-only)
- ItemPurchaseHandler (shared)
- DataService (shared)
```

#### 3. **State Management**
```lua
-- Verify these work correctly:
- placedItemsByPlayer tracking
- ItemsByInstanceId lookup
- World folder structure
- Preview item cleanup
```

#### 4. **Cross-Platform Compatibility**
```lua
-- Test on both:
- PC (mouse + keyboard)
- Mobile (touch)
- Console (gamepad)
```

## Testing Strategy

### Automated Tests
Run the integration test suite:
```lua
local PlacementIntegrationTest = require(ReplicatedStorage.shared.core.placement.PlacementIntegrationTest)
local success, results = PlacementIntegrationTest:RunAllTests()
```

### Manual Testing
1. **Basic Placement Flow:**
   - Select item from inventory
   - Place item in world
   - Verify item appears and persists

2. **Item Actions:**
   - Recall item (with cost)
   - Clone item (with cost)
   - Rotate item
   - Move item
   - Destroy item

3. **Edge Cases:**
   - Server restart (data persistence)
   - Player disconnect during placement
   - Network lag scenarios
   - Multiple players placing simultaneously

### Performance Testing
Monitor these metrics:
- Memory usage (watch for leaks)
- Frame rate during placement
- Network traffic (remote events)
- Server response times

## Common Issues & Solutions

### Issue 1: "PlacementManager.RecallItem function not found"
**Solution:** This was fixed by routing through `processItemActionRequest` in `init.server.luau`

### Issue 2: Remote events not connecting
**Solution:** 
- Check server creates events before client tries to access
- Verify proper client/server separation
- Use the integration test to validate

### Issue 3: Template not found errors
**Solution:**
- Ensure ItemTemplates folder exists in ReplicatedStorage
- Check itemTemplateMap for numeric ID mappings
- Verify template names match exactly

### Issue 4: Preview items not cleaning up
**Solution:**
- Call `ResetPlacementState()` on errors
- Ensure `ClearItemFromHand()` is called
- Check for orphaned preview items in Workspace

## Performance Optimizations

### Current Optimizations
- Raycast filtering for preview updates
- Throttled placement preview updates (0.05s interval)
- Efficient template caching
- Proper connection cleanup

### Future Optimizations (Modular System)
- Object pooling for preview items
- Spatial partitioning for collision detection
- Lazy loading of UI components
- Compressed remote event data

## Rollback Plan

If issues arise, you can quickly rollback:

1. **Immediate Rollback:**
   ```lua
   -- In PlacementManager.luau:
   local USE_MODULAR_SYSTEM = false
   ```

2. **Emergency Rollback:**
   - Revert to previous git commit
   - Restore backup of working files
   - Restart servers

## Support & Debugging

### Debug Commands
```lua
-- Enable verbose logging:
game.ReplicatedStorage.Remotes.DebugPlacement:FireServer("verbose", true)

-- Check placement state:
local pm = require(ReplicatedStorage.shared.core.placement.PlacementManager)
local instance = pm.new(SharedModule)
print("Is placing:", instance.isPlacing)
print("Selected item:", instance.selectedItem)

-- Validate remote events:
for name, event in pairs(instance.remotes) do
    print(name, event and "✅" or "❌")
end
```

### Log Analysis
Look for these patterns in server logs:
- `PlacementManager_Core: Successfully required`
- `PlacementManager_Core: Server remote events setup complete`
- `PlacementManager_Core: World data saved`

Look for these patterns in client logs:
- `PlacementManager_Core: Client remote events cached`
- `PlacementManager_Core: Template retrieved for`
- `PlacementManager_Core: StartPlacing succeeded`

## Conclusion

The placement system has been stabilized with proper client/server separation and error handling. The modular system is available as an opt-in upgrade path, but the current monolithic system should work reliably.

**Key Takeaway:** You can continue using the current system safely, and migrate to the modular system when you're ready for the additional benefits of better maintainability and extensibility. 