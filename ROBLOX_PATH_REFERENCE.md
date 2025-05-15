# ForeverBuild Roblox Path Reference Guide

## Project Structure Mapping

This document explains how your project folders map to Roblox game paths after syncing.

### From `second.project.json`:

| Local Directory | Roblox Path |
|-----------------|-------------|
| `src/shared` | `ReplicatedStorage.shared` |
| `src/server` | `ServerScriptService.server` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.client` |
| `src/StarterGui` | `StarterGui.StarterGui` |

### Runtime Path Changes:

When the game runs, some paths change:

| Design-time Path | Runtime Path |
|------------------|-------------|
| `StarterPlayer.StarterPlayerScripts.client` | `Players.[PlayerName].PlayerScripts.client` |
| `StarterGui.StarterGui` | `Players.[PlayerName].PlayerGui.StarterGui` |

## Important Paths for Module References:

### SharedModule:
```lua
-- Correct path to access SharedModule:
local SharedModule = require(game.ReplicatedStorage.shared)
```

### Client Core:
```lua
-- Correct path to access client_core:
local clientCore = require(game.Players.LocalPlayer.PlayerScripts.client.client_core)
```

### Interaction System:
```lua
-- Correct path to access InteractionSystemModule:
local InteractionSystem = require(game.Players.LocalPlayer.PlayerScripts.client.interaction.InteractionSystemModule_fixed)
```

## Common Path Mistakes:

1. **Missing capitalization**: Some services are case-sensitive 
   - Correct: `ReplicatedStorage`
   - Incorrect: `replicatedStorage`

2. **Wrong folder path during runtime**: 
   - Remember that `StarterPlayerScripts` content moves to `PlayerScripts` during runtime

3. **Searching in wrong location**: 
   - UI elements are in `PlayerGui` not `PlayerScripts`
   
## Debugging Path Issues:

If you're having path issues, use the `ROBLOX_STRUCTURE_MAPPER.lua` script to see the actual runtime structure of your game. This will help identify where folders and scripts actually exist in the Roblox environment.

## Example of using WaitForChild correctly:

```lua
-- Safely get a path that might not be immediately available:
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared", 10) -- timeout after 10 seconds

-- If you need to wait for multiple paths:
local function safeRequire(path)
    local success, result = pcall(function()
        return require(path)
    end)
    if success then
        return result
    else
        warn("Failed to require module at path:", path:GetFullName())
        return nil
    end
end

-- This safely navigates a path even if some parts aren't loaded yet
local function getModuleSafely(parent, pathParts)
    local current = parent
    for i, part in ipairs(pathParts) do
        current = current:WaitForChild(part, 5)
        if not current then
            warn("Failed to find path part:", part)
            return nil
        end
    end
    return current
end

-- Example use:
local clientCore = getModuleSafely(game.Players.LocalPlayer.PlayerScripts, {"client", "client_core"})
if clientCore then
    local clientCoreModule = safeRequire(clientCore)
    -- Use clientCoreModule here...
end
```

## Always Use pcall with require:

```lua
local success, module = pcall(function()
    return require(path)
end)

if success then
    -- Use module
else
    -- Handle error
    warn("Failed to require module:", module) -- module contains the error message here
end
```
