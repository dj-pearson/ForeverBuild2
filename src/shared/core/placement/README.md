# Modular Placement System

This directory contains a modular replacement for the monolithic `PlacementManager.luau` file. The system is broken down into focused, maintainable modules.

## Architecture

### Core Components

1. **`PlacementCore.luau`** - Main orchestrator that maintains the existing PlacementManager API
2. **`modules/ItemTemplateManager.luau`** - Handles finding and managing item templates
3. **`modules/PreviewManager.luau`** - Manages preview items and hand items
4. **`modules/PlacementValidator.luau`** - Validation logic for placement, ownership, etc.
5. **`modules/ItemDataManager.luau`** - World data save/load operations
6. **`modules/RemoteEventManager.luau`** - Remote event setup and handling
7. **`modules/MovementManager.luau`** - Item movement, rotation, and recall logic

## Benefits

- **Maintainability**: Each module has a single responsibility
- **Testability**: Individual modules can be tested in isolation
- **Readability**: Much easier to understand and modify specific functionality
- **Version Control**: Smaller files mean cleaner diffs and easier merging
- **Performance**: Only load the modules you need

## Usage

### Basic Usage (Legacy API Compatible)

```lua
-- The PlacementCore maintains the same API as PlacementManager
local PlacementCore = require(script.Parent.placement.PlacementCore)
local placement = PlacementCore.new(sharedModule)

-- All existing methods work the same way
placement:StartPlacing("Stone_Cube")
placement:ShowItemInHand("Glass_Cube")
local template = placement:GetItemTemplate("Wood_Cube")
```

### Testing the New System

In `src/client/inventory/InventoryItemHandler.luau`, change:

```lua
local USE_NEW_PLACEMENT_CORE = true  -- Set to true to test new system
```

### Direct Module Usage

```lua
-- Use individual modules directly for more control
local ItemTemplateManager = require(script.Parent.placement.modules.ItemTemplateManager)
local PreviewManager = require(script.Parent.placement.modules.PreviewManager)

local templateManager = ItemTemplateManager.new()
local previewManager = PreviewManager.new(templateManager)

-- Create a preview item
local preview = previewManager:CreatePreviewItem("Stone_Cube")

-- Show item in hand with custom callbacks
previewManager:ShowItemInHand("Glass_Cube", function(itemId)
    print("Player wants to place:", itemId)
end, function()
    print("Player cancelled")
end)
```

## Migration Strategy

1. **Phase 1** ✅ - Create core modules (ItemTemplateManager, PreviewManager, PlacementValidator)
2. **Phase 2** ✅ - Create PlacementCore that maintains existing API
3. **Phase 3** ✅ - Add remaining modules (ItemDataManager, RemoteEventManager, MovementManager)
4. **Phase 4** - Gradually migrate functionality from PlacementManager to modules
5. **Phase 5** - Remove old PlacementManager.luau when fully replaced

## Current Status

- ✅ `ItemTemplateManager` - Template finding and management (156 lines)
- ✅ `PreviewManager` - Preview items and hand items (284 lines)
- ✅ `PlacementValidator` - Validation logic (304 lines)
- ✅ `PlacementCore` - Main orchestrator with legacy API (359 lines)
- ✅ `ItemDataManager` - Save/load operations (307 lines)
- ✅ `RemoteEventManager` - Remote event handling (380 lines)
- ✅ `MovementManager` - Movement, rotation, recall (366 lines)

**Total: 7 modules, 2,156 lines vs original 3,767 lines**

## Testing

The system is designed to work alongside the existing PlacementManager. Use the `USE_NEW_PLACEMENT_CORE` flag to test functionality without breaking existing features.

## Benefits Observed

1. **Faster Development**: Much easier to find and modify specific functionality
2. **Better Organization**: Related code is grouped together logically
3. **Easier Debugging**: Smaller, focused modules are easier to debug
4. **Cleaner Diffs**: Changes are localized to specific modules
5. **Better Tool Support**: Rojo/Agron sync much faster with smaller files
6. **Improved Maintainability**: Single responsibility principle applied throughout

## Module Breakdown

- **ItemTemplateManager**: Finds templates across ReplicatedStorage, ServerStorage, Workspace
- **PreviewManager**: Handles translucent previews, hand items with rotation and highlighting
- **PlacementValidator**: AABB overlap checking, ownership verification, world bounds validation
- **ItemDataManager**: DataStore save/load, item serialization/restoration, player tracking
- **RemoteEventManager**: Event setup, client/server communication, default handlers
- **MovementManager**: Item movement, rotation, recall with visual feedback
- **PlacementCore**: Orchestrates all modules while maintaining backward compatibility
