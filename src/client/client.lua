-- File: c:\Users\pears\OneDrive\Documents\ForeverBuild\ForeverBuild\ForeverBuild2\src\client\client.lua
-- This is the main LocalScript for the client.
-- It will load and run the client_core.luau ModuleScript.

print("Main client.lua LocalScript started. Attempting to load client_core ModuleScript...")

-- client_core.luau is expected to be a sibling of this LocalScript, under the same parent instance (script.Parent).
-- We assume its name in the game hierarchy will be "client_core".
local clientCoreModuleScript = script.Parent:WaitForChild("client_core", 10)

if clientCoreModuleScript then
    print("[client.lua] Found client_core ModuleScript instance: " .. clientCoreModuleScript:GetFullName())
    
    -- Require the ModuleScript. This will execute the code within client_core.luau.
    -- The variable 'clientCoreAPI' will hold whatever client_core.luau returns (typically a table of functions/data).
    local success, clientCoreAPI = pcall(require, clientCoreModuleScript)
    
    if success then
        print("[client.lua] client_core.luau ModuleScript loaded and executed successfully.")
        
        -- If client_core.luau returns an API table with an Initialize function,
        -- you might call it here, though it seems client_core.luau handles its own initialization.
        -- Example:
        -- if typeof(clientCoreAPI) == "table" and typeof(clientCoreAPI.Initialize) == "function" then
        --     print("[client.lua] Calling Initialize on the returned API from client_core.")
        --     clientCoreAPI.Initialize()
        -- end
        
        -- The GetGameManager and ShowInventory functions returned by client_core.luau
        -- are now available via clientCoreAPI if needed by other scripts that might get a reference
        -- to the environment of this LocalScript, though typically ModuleScripts are shared via ReplicatedStorage
        -- or by passing their returned table around.
        -- For now, client.lua's main job is just to kick off client_core.luau.

    else
        warn("[client.lua] Failed to load (require) client_core.luau ModuleScript. Error: ", tostring(clientCoreAPI))
    end
else
    warn("[client.lua] Could not find the 'client_core' ModuleScript as a sibling (under script.Parent) after 10 seconds.")
    warn("[client.lua] Ensure client_core.luau is in the src/client/ folder and Rojo is configured for them to be siblings under a common parent.")
end

print("Main client.lua LocalScript execution finished.")
