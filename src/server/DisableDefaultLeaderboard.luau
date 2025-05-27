-- DisableDefaultLeaderboard.luau
-- Server-side initialization for hybrid leaderboard system

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Server-side setup for hybrid leaderboard system
local DisableDefaultLeaderboard = {}

function DisableDefaultLeaderboard.Initialize()
    print("DisableDefaultLeaderboard: Server-side hybrid leaderboard system setup")
    
    -- The actual leaderboard disabling and HUD creation is now handled client-side
    -- This server script just handles initialization and any server-side coordination
    
    -- Set up any server-side data needed for the hybrid system
    if not _G.ForeverBuildSystems then
        _G.ForeverBuildSystems = {}
    end
    
    -- Mark hybrid leaderboard as initialized
    _G.ForeverBuildSystems.HybridLeaderboardEnabled = true
    
    return true
end

-- Initialize immediately when required
DisableDefaultLeaderboard.Initialize()

print("DisableDefaultLeaderboard: Server-side initialization complete")

-- Return a module table to satisfy Roblox's ModuleScript requirements
return {
    name = "DisableDefaultLeaderboard",
    version = "1.0.0", 
    initialized = true,
    Initialize = DisableDefaultLeaderboard.Initialize
} 