-- ModelDisplayRunner.server.lua
-- Server script to initialize and run the model display utility

local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

-- Configuration
local CHECK_INTERVAL_STUDIO = 60   -- Check every 60 seconds in Studio (increased from 30)
local CHECK_INTERVAL_PROD = 300    -- Check every 5 minutes in production
local ENABLE_VERBOSE_LOGGING = false  -- Set to true for debug mode
local ENABLE_PERIODIC_DISPLAY = false -- Set to true to show full model lists periodically

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
    local checkCount = 0
    
    while true do
        checkCount = checkCount + 1
        
        -- Only show verbose output if explicitly enabled
        if isStudio and ENABLE_PERIODIC_DISPLAY and ENABLE_VERBOSE_LOGGING then
            print("\n=== PERIODIC MODEL DISPLAY ===")
            ModelDisplayUtil:DisplayModels(workspace.World_Items)
            print("=============================\n")
        elseif isStudio and checkCount % 10 == 1 then -- Show summary every 10 checks
            local worldItems = workspace:FindFirstChild("World_Items")
            if worldItems then
                local placed = worldItems:FindFirstChild("Placed")
                local static = worldItems:FindFirstChild("Static") 
                local placedCount = placed and #placed:GetChildren() or 0
                local staticCount = static and #static:GetChildren() or 0
                print("ModelDisplayRunner: Check #" .. checkCount .. " - Placed items: " .. placedCount .. ", Static items: " .. staticCount)
            end
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
    if ENABLE_VERBOSE_LOGGING then
        print("ModelDisplayRunner: Player joined, checking models: " .. player.Name)
    end
    
    -- Wait a moment to let the player fully load in
    wait(2)
    
    -- Run a restoration check
    local restoredCount = ModelDisplayUtil:RestoreMissingModels()
    if restoredCount > 0 then
        print("ModelDisplayRunner: Restored " .. restoredCount .. " missing models after player joined")
    end
end)

print("ModelDisplayRunner: Setup complete (Verbose logging: " .. tostring(ENABLE_VERBOSE_LOGGING) .. ", Periodic display: " .. tostring(ENABLE_PERIODIC_DISPLAY) .. ")") 