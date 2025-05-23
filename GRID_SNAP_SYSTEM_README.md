# Professional Grid Snap System

## Overview

The Grid Snap System provides professional-grade placement assistance for building in your Roblox game. It includes visual grid display, multiple snap sizes, collision detection, and surface snapping to create a smooth, precise building experience.

## 🎮 Controls

### Basic Controls

- **G** - Toggle grid snap on/off
- **Shift+G** - Cycle through grid sizes (1, 2, 4, 8, 16 studs)

### Visual Feedback

- **Blue Grid Lines** - Appear when placing items to show snap points
- **Green Highlight** - Indicates valid placement position
- **Red Highlight** - Indicates collision detected (placement blocked)
- **Status UI** - Shows current grid state and size in top-left corner

## ✨ Features

### 1. Grid Snapping

- **Multiple Grid Sizes**: 1, 2, 4, 8, 16 stud intervals
- **Precise Alignment**: Items snap to nearest grid intersection
- **Default Size**: 4 studs (perfect for most building)
- **Visual Feedback**: Blue grid lines show snap points during placement

### 2. Collision Detection

- **Overlap Prevention**: Prevents placing items on top of each other
- **Smart Detection**: Uses multiple raycast directions for accuracy
- **Visual Warning**: Red highlight when collision detected
- **Tolerance Setting**: Small overlap tolerance for natural placement

### 3. Surface Snapping

- **Automatic Surface Detection**: Items snap to surfaces below them
- **Smart Positioning**: Automatically adjusts height to sit on surfaces
- **Distance Limit**: 2-stud maximum snap distance
- **Works with Grid**: Combines with grid snapping for perfect alignment

### 4. Visual Grid Display

- **Real-time Grid**: Shows during placement only
- **Auto-hide**: Disappears when not placing
- **Customizable Range**: 50-stud display radius
- **Performance Optimized**: Efficient line rendering

## 🔧 Technical Implementation

### Core Components

#### GridSnapSystem.luau

- Main system controller
- Handles input processing
- Manages visual elements
- Provides snapping calculations

#### Integration Points

- **PlacementManager**: UpdatePlacementPreview function enhanced
- **ItemInteractionClient**: Automatic initialization
- **Global Access**: Available via `_G.GridSnapSystem`

### Key Functions

```lua
-- Enable/disable grid snapping
gridSnapSystem:ToggleGridSnap()

-- Change grid size
gridSnapSystem:CycleGridSize()

-- Snap position to grid
local snappedPos = gridSnapSystem:SnapToGrid(position)

-- Process complete placement with all features
local finalPos, finalRot, hasCollision, collidingObject =
    gridSnapSystem:ProcessPlacement(position, rotation, itemSize, excludeInstance)
```

## 🎯 Usage Scenarios

### Basic Building

1. **Place from Inventory**: Items automatically snap to grid
2. **Use Visual Grid**: Blue lines guide precise placement
3. **Avoid Collisions**: Red highlight warns of overlaps
4. **Surface Alignment**: Items automatically sit on surfaces

### Advanced Building

1. **Fine Detail Work**: Use 1-stud grid for precision
2. **Large Structures**: Use 8+ stud grid for quick layout
3. **Toggle As Needed**: Turn off for organic/artistic builds
4. **Mix Grid Sizes**: Different sizes for different building phases

### Professional Workflows

1. **Foundation Layout**: Use large grid (8-16 studs)
2. **Wall Placement**: Use medium grid (4 studs)
3. **Detail Work**: Use small grid (1-2 studs)
4. **Finishing**: Turn off grid for organic elements

## 🔍 Configuration Options

### Grid Sizes

```lua
self.availableGridSizes = {1, 2, 4, 8, 16}
```

### Visual Settings

```lua
self.gridRange = 50          -- Display radius
self.gridVisual = true       -- Show visual grid
```

### Collision Settings

```lua
self.collisionEnabled = true
self.overlapTolerance = 0.1  -- Small tolerance for placement
```

### Surface Snapping

```lua
self.surfaceSnapEnabled = true
self.surfaceSnapDistance = 2 -- Maximum snap distance
```

## 🚀 Benefits

### For Players

- **Faster Building**: Snap to grid instead of manual alignment
- **Professional Results**: Perfectly aligned structures
- **No Overlaps**: Collision detection prevents mistakes
- **Intuitive Controls**: Simple G key toggles
- **Visual Guidance**: Clear grid lines and status display

### For Developers

- **Easy Integration**: Drop-in system with existing placement
- **Configurable**: Adjust grid sizes and behaviors
- **Performance Optimized**: Efficient visual rendering
- **Extensible**: Add custom snap behaviors
- **Compatible**: Works with existing undo system

## 🧪 Testing

### Automated Tests

Run `test_grid_snap_system.luau` to verify:

- Grid snapping calculations
- Collision detection
- Surface snapping
- UI creation
- Control responsiveness

### Manual Testing Checklist

- [ ] G key toggles grid on/off
- [ ] Shift+G cycles grid sizes
- [ ] Visual grid appears during placement
- [ ] Items snap to grid intersections
- [ ] Collision detection shows red highlight
- [ ] Surface snapping works on existing items
- [ ] Status UI updates correctly
- [ ] Grid auto-hides after placement

## 📊 Performance Notes

### Optimizations

- **Efficient Raycasting**: Limited ray directions for collision
- **Smart Visual Updates**: Grid only renders when needed
- **Connection Management**: Proper cleanup of event connections
- **Memory Efficient**: Reuses grid line objects when possible

### Best Practices

- Grid visual automatically hides to reduce overhead
- Collision detection uses spatial optimization
- Surface snapping limits raycast distance
- UI updates only when values change

## 🔄 Integration with Existing Systems

### Undo System Compatibility

- Works seamlessly with the 5-second undo system
- Grid-snapped placements can be undone normally
- Collision prevention doesn't interfere with undo recording

### PlacementManager Integration

- Enhanced `UpdatePlacementPreview` function
- Added `_UpdatePreviewCollisionFeedback` for visual feedback
- Maintains all existing placement functionality

### No Breaking Changes

- All existing placement features continue to work
- Grid system can be disabled without affecting normal placement
- Backward compatible with existing item interaction

## 🎊 Conclusion

The Professional Grid Snap System transforms building from a tedious alignment process into a smooth, efficient, and enjoyable experience. Players can create perfectly aligned structures with professional precision while maintaining the creative freedom to build organically when desired.

The system is designed to feel natural and unobtrusive - it helps when you need it and stays out of the way when you don't. Combined with the existing undo system, it provides a complete professional building toolkit that rivals dedicated building software.

**Ready to build like a pro! 🚀**
