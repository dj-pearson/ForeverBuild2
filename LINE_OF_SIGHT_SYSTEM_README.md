# Line of Sight Detection System

## 📋 Overview

The **Line of Sight Detection System** prevents purchase prompts from appearing when items are behind walls, floors, or other obstacles. This solves the immersion-breaking issue where players would see purchase prompts for items they couldn't actually see.

### **Problem Solved**

- ❌ Purchase prompts showing through walls
- ❌ Prompts for items on different floors
- ❌ Prompts for items inside enclosed buildings
- ❌ Confusing UX where players can't find the item they're prompted to buy

### **Solution Implemented**

- ✅ Multi-point raycast detection
- ✅ Works in all directions (360° + vertical)
- ✅ Configurable transparency and collision handling
- ✅ Performance-optimized with caching
- ✅ Debug visualization for testing

---

## 🏗️ **System Architecture**

### **Core Components**

#### 1. **LineOfSightChecker.luau**

The main detection engine that uses advanced raycasting to determine visibility.

```lua
-- Basic usage
local checker = LineOfSightChecker:Init()
local hasLineOfSight = checker:HasLineOfSight(player, item)
```

#### 2. **BottomPurchasePopup.luau** (Enhanced)

The purchase popup system now includes line of sight checking before showing prompts.

```lua
-- Automatic integration - line of sight is checked before showing popups
local popup = BottomPurchasePopup.new()
popup:Initialize()
```

---

## 🔧 **How It Works**

### **Multi-Point Raycast Detection**

Instead of a single raycast, the system casts multiple rays to different points on the target item:

1. **Center Point**: The item's central position
2. **Edge Points**: Corners and edges of the item's bounding box
3. **Surface Points**: Points on different faces of the item

```
Player → [Ray 1] → Item Center
Player → [Ray 2] → Item Top
Player → [Ray 3] → Item Left
Player → [Ray 4] → Item Right
...
```

### **Visibility Calculation**

An item is considered "visible" if **at least 30%** of the raycast points reach the item unobstructed.

```lua
-- Configuration
MIN_CLEAR_PERCENTAGE = 0.3  -- 30% of rays must be clear
```

This allows for:

- Partially visible items (around corners)
- Items with small obstructions
- More realistic line of sight detection

---

## ⚙️ **Configuration Options**

### **Distance Settings**

```lua
checker:SetMaxDistance(15)  -- Maximum interaction distance in studs
```

### **Visibility Threshold**

```lua
checker:SetMinClearPercentage(0.3)  -- 30% of rays must be clear
```

### **Transparency Handling**

```lua
checker:SetTransparentPartsBlock(false)  -- Transparent parts don't block line of sight
```

### **Debug Mode**

```lua
checker:SetDebugMode(true)  -- Enable visual debug rays
```

---

## 🎮 **Real-World Scenarios**

### **Scenario 1: House Interior**

```
Player (outside) → [Wall] → Item (inside house)
Result: ❌ No purchase prompt (blocked by wall)
```

### **Scenario 2: Multi-Floor Building**

```
Player (ground floor) → [Floor/Ceiling] → Item (upper floor)
Result: ❌ No purchase prompt (blocked by floor)
```

### **Scenario 3: Around Corner**

```
Player → [Partial wall] → Item (30% visible around corner)
Result: ✅ Purchase prompt shown (enough visibility)
```

### **Scenario 4: Through Window**

```
Player → [Transparent window] → Item (inside)
Result: ✅ Purchase prompt shown (transparent parts don't block)
```

---

## 🔍 **Advanced Features**

### **Smart Filtering**

The system automatically excludes certain objects from blocking line of sight:

- **Player Characters**: Other players don't block your view
- **Preview Items**: Placement previews are ignored
- **Transparent Parts**: Glass, windows, etc. (configurable)
- **Non-Collidable Parts**: Decorative elements that shouldn't block
- **Force Fields**: Special materials that don't obstruct view

### **Performance Optimization**

1. **Distance Pre-Check**: Items beyond max distance are filtered out immediately
2. **Result Caching**: Line of sight results are cached for 0.5 seconds
3. **Adaptive Point Count**: Number of raycast points adapts to item size
4. **Spatial Optimization**: Only checks when player moves significantly

### **Cache System**

```lua
-- Results are cached based on:
-- - Player ID
-- - Target Item
-- - Player Position (rounded to nearest stud)
-- - Timestamp (expires after 0.5 seconds)
```

---

## 🧪 **Testing & Debugging**

### **Debug Visualization**

Enable debug mode to see visual raycast lines:

```lua
checker:SetDebugMode(true)
```

- **Green Lines**: Clear line of sight
- **Red Lines**: Blocked by obstacle
- **Lines appear for 2 seconds** during testing

### **Test Script**

Run `test_line_of_sight_system.luau` for comprehensive testing:

```lua
-- Creates test scenarios:
-- ✅ Clear line of sight
-- ❌ Behind wall
-- ❌ Above with floor obstacle
-- ❌ Too far away
-- ❌ Through transparent wall (configurable)
```

### **Console Messages**

The system provides detailed logging:

```
LineOfSight Debug: ITEM_NAME Clear: 6/8 Percentage: 75%
BottomPurchasePopup: Item BLOCKED_ITEM is close but blocked by obstacle
```

---

## 📊 **Performance Metrics**

### **Benchmark Results**

- **Excellent**: < 10ms per check
- **Good**: < 20ms per check
- **Acceptable**: < 50ms per check

### **Optimization Features**

- **Cached Results**: Avoid redundant calculations
- **Efficient Raycasting**: Optimized raycast parameters
- **Smart Updates**: Only check when necessary
- **Configurable Accuracy**: Adjust point count vs. performance

---

## 🔧 **Integration Guide**

### **Adding to Existing Systems**

1. **Import the Module**

```lua
local LineOfSightChecker = require(ReplicatedStorage.shared.core.interaction.LineOfSightChecker)
```

2. **Initialize**

```lua
local checker = LineOfSightChecker:Init()
```

3. **Check Line of Sight**

```lua
if checker:HasLineOfSight(player, item) then
    -- Show purchase prompt
else
    -- Don't show prompt
end
```

### **Custom Configuration**

```lua
-- Configure for your specific needs
checker:SetMaxDistance(20)           -- Longer interaction range
checker:SetMinClearPercentage(0.5)   -- Require 50% visibility
checker:SetTransparentPartsBlock(true) -- Glass blocks view
```

---

## 🛠️ **Edge Cases Handled**

### **Thin Walls**

Multiple raycast points ensure thin walls are properly detected.

### **Partial Visibility**

Items that are partially visible (around corners) can still trigger prompts.

### **Floating Items**

Items suspended in air are handled correctly with 3D raycasting.

### **Complex Geometry**

Works with unions, meshes, and complex model hierarchies.

### **Moving Players**

System updates as player moves and changes viewing angle.

---

## 🎯 **Configuration Examples**

### **Conservative Settings** (Strict visibility required)

```lua
checker:SetMaxDistance(10)
checker:SetMinClearPercentage(0.7)    -- 70% visibility required
checker:SetTransparentPartsBlock(true) -- Even glass blocks
```

### **Permissive Settings** (More forgiving)

```lua
checker:SetMaxDistance(20)
checker:SetMinClearPercentage(0.2)    -- Only 20% visibility required
checker:SetTransparentPartsBlock(false) -- Glass doesn't block
```

### **Performance-Focused** (Faster but less accurate)

```lua
-- Use fewer raycast points in LineOfSightChecker CONFIG
RAYCAST_POINTS_PER_ITEM = 4
CACHE_DURATION = 1.0  -- Cache results longer
```

---

## 🐛 **Troubleshooting**

### **Purchase Prompts Still Show Through Walls**

1. Check if LineOfSightChecker is properly loaded
2. Verify BottomPurchasePopup integration
3. Enable debug mode to see raycast lines
4. Check console for error messages

### **No Purchase Prompts Appearing**

1. Verify items are marked as purchasable
2. Check if distance is too restrictive
3. Lower the minimum clear percentage
4. Disable line of sight temporarily for testing

### **Performance Issues**

1. Reduce raycast points per item
2. Increase cache duration
3. Reduce update frequency
4. Check for excessive debug output

---

## 📈 **Future Enhancements**

### **Planned Features**

- **Adaptive Point Count**: Automatically adjust raycast points based on item size
- **View Angle Detection**: Only show prompts for items in player's field of view
- **Occlusion Culling**: Integration with Roblox's occlusion system
- **Zone-Based Detection**: Special handling for indoor/outdoor areas

### **Possible Optimizations**

- **Spatial Indexing**: Use octree or similar for faster item lookup
- **LOD System**: Fewer raycast points for distant items
- **Async Processing**: Move raycast calculations to separate thread
- **GPU Acceleration**: Use compute shaders for large-scale detection

---

## 🎉 **Benefits**

### **For Players**

- ✅ No more confusing purchase prompts for invisible items
- ✅ Realistic interaction system
- ✅ Better immersion and UX
- ✅ Clear visual feedback about what can be purchased

### **For Developers**

- ✅ Easy to integrate and configure
- ✅ Performance-optimized out of the box
- ✅ Comprehensive debugging tools
- ✅ Handles complex scenarios automatically

### **For Game Design**

- ✅ Enables realistic building interiors
- ✅ Supports multi-level structures
- ✅ Allows for hidden/secret areas
- ✅ Creates more engaging exploration gameplay

---

## 🚀 **Quick Start**

1. **Add the module** to your game
2. **Run the test script** to verify it works
3. **Configure settings** for your specific needs
4. **Test in real scenarios** with debug mode enabled
5. **Deploy** and monitor performance

The Line of Sight Detection System is now protecting your players from confusing purchase prompts and creating a more immersive, realistic interaction experience! 🎯
