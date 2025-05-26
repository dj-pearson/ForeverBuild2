# Rotation System Fix - Documentation

## Overview

This document details the fixes applied to the Roblox placement system's rotation functionality. The previous system had issues with input conflicts and rotation not being visually applied to preview items.

## Issues Fixed

### 1. **Input Conflict with Character Movement**

- **Problem**: A/D keys were used for rotation, but also controlled character movement
- **Solution**: Changed rotation controls to Q/E keys which don't conflict with player movement
- **Impact**: Players can now rotate items without their character moving left/right

### 2. **Rotation Not Applied Visually**

- **Problem**: `UpdatePlacementPreview()` used `currentPlacementAngleY` instead of `currentPlacementRotation`
- **Solution**: Modified the preview update to use `currentPlacementRotation` set by `_DirectRotate()`
- **Impact**: Preview items now visually rotate when using rotation controls

### 3. **Inconsistent Control Labels**

- **Problem**: UI showed A/D controls that no longer worked correctly
- **Solution**: Updated `PlacementControlsUI` and `SimpleRotationUI` to show Q/E controls
- **Impact**: UI now accurately reflects the actual controls

## New Control Scheme

### During Item Placement

| Control                | Action                | Platform          |
| ---------------------- | --------------------- | ----------------- |
| **Q**                  | Rotate left 45°       | PC/Console        |
| **E**                  | Rotate right 45°      | PC/Console        |
| **Scroll Wheel**       | Rotate 45° (up/down)  | PC/Mobile/Console |
| **Space**              | Open fine rotation UI | PC/Console        |
| **Left Click**         | Place item            | All               |
| **Right Click/Escape** | Cancel placement      | PC/Console        |

### Fine Rotation UI (Space Key)

| Control               | Action           |
| --------------------- | ---------------- |
| **Q/E or Arrow Keys** | Rotate 45°       |
| **⟲/⟳ buttons**       | Rotate 45°       |
| **◀/▶ buttons**       | Rotate 15°       |
| **⌂ button**          | Reset to 0°      |
| **✓ button**          | Confirm rotation |
| **✖ button**          | Cancel rotation  |

### Console/Gamepad Controls

| Control           | Action                |
| ----------------- | --------------------- |
| **LB/RB Bumpers** | Rotate left/right 45° |
| **Y Button**      | Open fine rotation UI |
| **A Button**      | Place item            |
| **B Button**      | Cancel placement      |

## Technical Changes Made

### 1. PlacementManager.luau

```lua
-- BEFORE: Used A/D keys
if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
    self:_DirectRotate(-45)
elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
    self:_DirectRotate(45)

-- AFTER: Uses Q/E keys
if input.KeyCode == Enum.KeyCode.Q then
    self:_DirectRotate(-45)
elseif input.KeyCode == Enum.KeyCode.E then
    self:_DirectRotate(45)
```

### 2. PlacementControlsUI.luau

```lua
-- BEFORE:
key = isMobile and "SCROLL/TAP" or "SCROLL / A&D",

-- AFTER:
key = isMobile and "SCROLL/TAP" or "SCROLL / Q&E",
```

### 3. SimpleRotationUI.luau

```lua
-- BEFORE:
if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
    self:Rotate(-self.rotationStep)
elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
    self:Rotate(self.rotationStep)

-- AFTER:
if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Left then
    self:Rotate(-self.rotationStep)
elseif input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Right then
    self:Rotate(self.rotationStep)
```

## How It Works

### 1. Direct Rotation (Q/E Keys)

1. Player presses Q or E during placement
2. `_DirectRotate()` is called with ±45 degrees
3. `currentPlacementRotation` is updated
4. `_ApplyRotationToItem()` immediately rotates the preview
5. `UpdatePlacementPreview()` maintains the rotation during movement

### 2. Scroll Wheel Rotation

1. Player scrolls mouse wheel during placement
2. Scroll direction determines rotation (+45 or -45 degrees)
3. Same `_DirectRotate()` flow as keyboard

### 3. Fine Rotation UI (Space Key)

1. Player presses Space to open detailed rotation controls
2. `SimpleRotationUI` provides precise rotation controls
3. Real-time rotation feedback during adjustment
4. Confirm/cancel options preserve or revert changes

### 4. Rotation Persistence

1. Rotation is stored in `currentPlacementRotation`
2. When placing item, rotation is sent to server
3. Server applies rotation and saves to world data
4. Placed items maintain their rotation

## Cross-Platform Compatibility

The system works consistently across:

- **PC**: Keyboard (Q/E) + Mouse (scroll wheel + clicks)
- **Mobile**: Touch controls + scroll gestures
- **Console**: Gamepad (bumpers + buttons)
- **Tablet**: Touch controls + on-screen buttons

## Testing

Use `test_rotation_fix.luau` to verify the fixes:

```lua
-- Creates test parts and verifies rotation functions
-- Tests _ApplyRotationToItem with various angles
-- Validates UI components exist and function
```

## Migration Notes

### For Players

- **Old**: Use A/D to rotate → **New**: Use Q/E to rotate
- All other controls remain the same
- Visual rotation feedback now works properly

### For Developers

- `currentPlacementAngleY` → `currentPlacementRotation` for preview updates
- Input handling now properly isolated from character movement
- UI components updated to reflect new control scheme

## Benefits

1. **No Input Conflicts**: Q/E don't interfere with character movement
2. **Visual Feedback**: Preview items actually rotate when controls are used
3. **Consistent UI**: Control labels match actual functionality
4. **Cross-Platform**: Works reliably on PC, mobile, and console
5. **Backward Compatible**: Existing placed items and rotation data unchanged

## Future Enhancements

Potential improvements that could be added:

- Shift+Q/E for 15° rotation (finer control)
- Ctrl+Q/E for 90° rotation (coarser control)
- Visual rotation indicators (compass/angle display)
- Snap-to-angle options (15°, 30°, 45°, 90° presets)
- Multi-axis rotation (X/Z axes in addition to Y)

---

_Last updated: January 28, 2025_
_Changes tested on Roblox Studio and live servers_
