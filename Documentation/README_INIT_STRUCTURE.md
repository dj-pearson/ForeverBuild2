# ForeverBuild2 - Initialization Structure Guide

## Overview

This document explains the initialization structure of the ForeverBuild2 project and how to properly work with it when using Rojo/Argon for syncing.

## The Init File Challenge

When using Rojo/Argon, files named `init.lua`, `init.server.lua`, or `init.client.lua` (and their Luau variants) cause their parent folder to be transformed into a script instance. This can complicate path resolution and module loading.

## Our Solution

We've implemented a simplified initialization structure with just three main init files:

1. **Client**: `src/client/inits.client.luau`
2. **Server**: `src/server/inits.server.luau`
3. **Shared**: `src/shared/inits.luau`

### Workflow for Syncing

1. **Development Mode**:
   - Work with files named `inits.client.luau`, `inits.server.luau`, and `inits.luau`
   - This prevents Rojo from transforming folders into script instances during sync
   - All paths and module loading will work as expected

2. **After Syncing to Roblox Studio**:
   - Manually rename the files from "inits" to "init" within Roblox Studio:
     - `inits.client.luau` → `init.client.luau`
     - `inits.server.luau` → `init.server.luau`
     - `inits.luau` → `init.luau`
   - The folder structure remains intact (unlike with Rojo's automatic init handling)
   - This gives you the init functionality without changing your folder structure during development

## Module Organization

### Client-Side

- **Entry Point**: `src/client/inits.client.luau`
  - Loads the shared module
  - Loads and runs `client_core.luau`

- **Main Logic**: `src/client/client_core.luau`
  - Initializes UI components
  - Loads the `InteractionSystem`
  - Handles all client-side game logic

### Server-Side

- **Entry Point**: `src/server/inits.server.luau`
  - Creates necessary remote events and functions
  - Initializes all server-side managers
  - Sets up event handlers
  - Manages player join/leave events

### Shared

- **Entry Point**: `src/shared/inits.luau`
  - Directly loads all core modules without requiring a separate core init file
  - Provides access to all modules through a single entry point
  - Handles initialization of core systems

## Path Resolution

- In `client_core.luau`, the shared module is loaded from `ReplicatedStorage:WaitForChild("shared")`
- In the shared module, core modules are loaded directly from their paths (e.g., `script.core.GameManager`)
- All paths use `WaitForChild` with timeouts to ensure instances exist before requiring them

## Best Practices

1. **Adding New Modules**:
   - Add new module paths to the `modulePaths` table in `src/shared/inits.luau`
   - Follow the existing pattern for initialization in the appropriate init script

2. **Debugging**:
   - Use the provided diagnostic tool to check instance paths and module loading
   - Check the output logs for detailed information about module loading
   - Verify that paths are resolved correctly

3. **Error Handling**:
   - All module loading uses `pcall` to handle errors gracefully
   - Detailed error messages are printed to the output window
   - Fallback behavior is provided when modules fail to load

## Common Issues

1. **Module Not Found**:
   - Check if the module is correctly defined in the `modulePaths` table
   - Verify that the module exists at the expected path
   - Use the diagnostic tool to check the actual instance hierarchy

2. **Invalid Arguments to Require**:
   - This usually means the path is nil or not a valid ModuleScript
   - Add print statements to check the path before requiring
   - Use `WaitForChild` with a timeout to ensure the instance exists

3. **UI Not Appearing**:
   - Verify that UI components are properly initialized
   - Check that initialization is happening in the correct order
   - Look for errors in the output logs

By following this structure and workflow, we can maintain a clean and predictable codebase while avoiding the path resolution issues that come with Rojo's handling of init scripts. 