# Multi-Axis Rotation System - Documentation

## Overview

The Roblox placement system now supports **full 3D rotation** with separate controls for each axis:

- **Yaw (Y-axis)**: Left/Right rotation
- **Pitch (X-axis)**: Up/Down tilting
- **Roll (Z-axis)**: Spinning around forward axis

## Features

### ✨ Multi-Axis Support

- **Independent axis control** - rotate around X, Y, and Z axes separately
- **Combined rotations** - multiple axes can be rotated simultaneously
- **Real-time preview** - see rotation changes immediately during placement
- **Cross-platform compatibility** - consistent controls across PC, mobile, and console

### 🎮 Control Schemes

#### **PC Controls**

| Action           | Keys            | Mouse              | Description               |
| ---------------- | --------------- | ------------------ | ------------------------- |
| **Yaw**          | `Q` / `E`       | `Scroll Wheel`     | Left/Right rotation       |
| **Pitch**        | `Shift` + `Q/E` | `Shift` + `Scroll` | Up/Down tilting           |
| **Roll**         | `Ctrl` + `Q/E`  | `Ctrl` + `Scroll`  | Forward axis spinning     |
| **Fine Control** | `Space`         | -                  | Opens precise rotation UI |

#### **Console/Gamepad Controls**

| Action           | Buttons        | Description               |
| ---------------- | -------------- | ------------------------- |
| **Yaw**          | `L1` / `R1`    | Left/Right rotation       |
| **Pitch**        | `R2` + `L1/R1` | Up/Down tilting           |
| **Roll**         | `L2` + `L1/R1` | Forward axis spinning     |
| **Fine Control** | `Y`            | Opens precise rotation UI |

#### **Mobile Controls**

| Action           | Touch              | Description               |
| ---------------- | ------------------ | ------------------------- |
| **Yaw**          | `Scroll` / `Tap`   | Left/Right rotation       |
| **Pitch**        | `Shift` + `Scroll` | Up/Down tilting           |
| **Roll**         | `Ctrl` + `Scroll`  | Forward axis spinning     |
| **Fine Control** | `Tap Space`        | Opens precise rotation UI |

## Technical Implementation

### Core Components

#### 1. **PlacementManager.luau**

```lua
-- New rotation variables for each axis
self.currentPlacementRotationX = 0  -- Pitch (up/down)
self.currentPlacementRotationY = 0  -- Yaw (left/right)
self.currentPlacementRotationZ = 0  -- Roll (spinning)

-- Multi-axis rotation function
function PlacementManager:_DirectRotateAxis(axis, degrees)
    -- Updates specified axis and applies rotation to preview
end

-- Multi-axis rotation application
function PlacementManager:_ApplyMultiAxisRotation(item, rotationX, rotationY, rotationZ)
    -- Applies CFrame.Angles(X, Y, Z) rotation to item
end
```

#### 2. **Input Handling**

- **Modifier Key Detection**: `Shift` and `Ctrl` keys modify rotation axis
- **Cross-Platform Input**: Handles keyboard, mouse, gamepad, and touch inputs
- **Real-Time Feedback**: Console messages show current rotation state

#### 3. **UI Integration**

- **PlacementControlsUI.luau**: Updated to show all three rotation types
- **Color-coded actions**: Different colors for each rotation type
- **Platform-aware display**: Shows appropriate controls for current platform

### Rotation Mathematics

```lua
-- CFrame rotation order: X (Pitch), Y (Yaw), Z (Roll)
local rotationCFrame = CFrame.Angles(
    math.rad(rotationX),  -- Pitch: up/down tilt
    math.rad(rotationY),  -- Yaw: left/right turn
    math.rad(rotationZ)   -- Roll: forward axis spin
)

-- Applied to item position
local finalCFrame = CFrame.new(position) * rotationCFrame
```

## Usage Examples

### Basic Rotation

```lua
-- Place item and rotate with Q/E (yaw only)
-- This rotates the item left/right like a lazy susan
```

### Advanced Multi-Axis

```lua
-- 1. Rotate yaw: Q/E (turn left/right)
-- 2. Hold Shift, use Q/E for pitch (tilt up/down)
-- 3. Hold Ctrl, use Q/E for roll (spin around forward axis)
-- 4. Combine all three for complex orientations
```

### Platform-Specific Usage

#### PC Example

1. Start placing an item
2. Use **mouse scroll** for quick yaw rotation
3. Hold **Shift + scroll** to tilt the item up/down
4. Hold **Ctrl + scroll** to spin the item
5. Use **Space** for fine-tuned rotation control

#### Console Example

1. Start placing an item
2. Use **L1/R1** for basic left/right rotation
3. Hold **R2 + L1/R1** to tilt up/down
4. Hold **L2 + L1/R1** to spin
5. Press **Y** for fine-tuned rotation control

## Rotation Axis Explanation

### **Yaw (Y-axis) - "Looking Left/Right"**

- Rotates item around vertical axis
- Like turning your head left/right
- Most common rotation type
- **Controls**: Q/E, Scroll, L1/R1

### **Pitch (X-axis) - "Nodding Up/Down"**

- Rotates item around horizontal side-to-side axis
- Like nodding your head up/down
- Useful for angled placements
- **Controls**: Shift+Q/E, R2+L1/R1

### **Roll (Z-axis) - "Tilting Head Side-to-Side"**

- Rotates item around forward-back axis
- Like tilting your head to your shoulder
- For artistic/creative orientations
- **Controls**: Ctrl+Q/E, L2+L1/R1

## Troubleshooting

### Common Issues

#### **Rotation Not Visible**

- ✅ Check that preview item is active
- ✅ Verify rotation variables are being updated
- ✅ Ensure `_ApplyMultiAxisRotation` is being called

#### **Controls Not Working**

- ✅ Check platform detection (PC/Console/Mobile)
- ✅ Verify input connections are active during placement
- ✅ Ensure modifier keys (Shift/Ctrl) are detected properly

#### **Unexpected Behavior**

- ✅ Check rotation normalization (angles should stay within -360° to 360°)
- ✅ Verify CFrame calculation order (X, Y, Z)
- ✅ Ensure backward compatibility with existing single-axis code

### Debug Information

The system provides detailed console output:

```
🔄 Direct Y-axis rotation: 45 degrees (Total: X=0°, Y=45°, Z=0°)
🖱️ Scroll wheel pitch (X): -45 degrees
🎮 R2+R1: Pitch up (X) 45 degrees
```

## Migration Notes

### Backward Compatibility

- Existing `currentPlacementRotation` still works (mapped to Y-axis)
- Old `_DirectRotate(degrees)` function preserved
- Previous rotation behavior unchanged for existing code

### New Code Should Use

- `currentPlacementRotationX/Y/Z` for axis-specific rotation
- `_DirectRotateAxis(axis, degrees)` for new rotation calls
- `_ApplyMultiAxisRotation(item, x, y, z)` for multi-axis application

## Performance Considerations

- **Minimal overhead**: Only calculates rotation when actively placing
- **Efficient CFrame operations**: Single CFrame.Angles call per update
- **Platform optimization**: Only processes relevant input types per platform
- **Memory efficient**: No persistent rotation tracking outside placement mode

## Future Enhancements

### Potential Additions

- **Snap to angles**: 15°, 30°, 45°, 90° snap options
- **Rotation presets**: Save/load common rotation combinations
- **Visual rotation guides**: Overlay showing rotation axes
- **Undo/redo rotation**: Step back through rotation history
- **Rotation constraints**: Limit certain items to specific axes

---

## Quick Reference

### All Controls Summary

```
PC:           Q/E, Shift+Q/E, Ctrl+Q/E, Scroll+Modifiers, Space
Console:      L1/R1, R2+L1/R1, L2+L1/R1, Y
Mobile:       Scroll/Tap, Shift+Scroll, Ctrl+Scroll, Space

Axes:         Y=Yaw(L/R), X=Pitch(U/D), Z=Roll(Spin)
Colors:       🔄Yellow, 🔺Orange, 🌀Pink
```
