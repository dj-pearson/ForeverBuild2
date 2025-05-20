-- ModelDisplayRunner.server.lua
-- Server script to initialize and run the model display utility

local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

-- Configuration
local CHECK_INTERVAL_STUDIO = 30  -- Check every 30 seconds in Studio
local CHECK_INTERVAL_PROD = 300    -- Check every 5 minutes in production

-- Wait for the server to fully initialize
wait(3)

-- Try to load the ModelDisplayUtil module
local ModelDisplayUtil
local success, errorMsg = pcall(function()
    ModelDisplayUtil = require(ServerScriptService.server.ModelDisplayUtil)
    return true
end)

if not success or not ModelDisplayUtil then
    warn("Failed to load ModelDisplayUtil:", errorMsg)
    -- Try an alternative path
    success, errorMsg = pcall(function()
        ModelDisplayUtil = require(script.Parent.ModelDisplayUtil)
        return true
    end)
    
    if not success or not ModelDisplayUtil then
        warn("Could not find ModelDisplayUtil module. Make sure it exists in the server folder.")
        return
    end
end

-- Initialize the utility
print("ModelDisplayRunner: Starting ModelDisplayUtil...")
ModelDisplayUtil:Initialize()

-- Set up periodic model checking
local function runPeriodically()
    local isStudio = RunService:IsStudio()
    local interval = isStudio and CHECK_INTERVAL_STUDIO or CHECK_INTERVAL_PROD
    
    while true do
        if isStudio then
            print("\n=== PERIODIC MODEL DISPLAY ===")
            ModelDisplayUtil:DisplayModels(workspace.World_Items)
            print("=============================\n")
        end
        
        -- Always restore missing models regardless of environment
        local restoredCount = ModelDisplayUtil:RestoreMissingModels()
        if restoredCount > 0 then
            print("ModelDisplayRunner: Restored " .. restoredCount .. " missing models")
        end
        
        wait(interval)
    end
end

-- Start the periodic check in a separate thread
spawn(runPeriodically)

-- Add a model restoration check on player join
-- This helps ensure models are present when players join the game
game:GetService("Players").PlayerAdded:Connect(function(player)
    print("ModelDisplayRunner: Player joined, checking models: " .. player.Name)
    
    -- Wait a moment to let the player fully load in
    wait(2)
    
    -- Run a restoration check
    local restoredCount = ModelDisplayUtil:RestoreMissingModels()
    if restoredCount > 0 then
        print("ModelDisplayRunner: Restored " .. restoredCount .. " missing models after player joined")
    end
end)

print("ModelDisplayRunner: Setup complete") 