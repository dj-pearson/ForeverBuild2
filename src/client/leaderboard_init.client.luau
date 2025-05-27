-- leaderboard_init.client.luau
-- Client-side initialization for leaderboard UI

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

print("LeaderboardClient: Initializing...")

-- Wait for shared module
local shared = ReplicatedStorage:WaitForChild("shared", 10)
if not shared then
    warn("LeaderboardClient: Could not find shared module")
    return
end

local SharedModule = require(shared)
if not SharedModule.LeaderboardManager or not SharedModule.LeaderboardUI then
    warn("LeaderboardClient: Required modules not found in SharedModule")
    return
end

-- Initialize LeaderboardManager (client-side)
local leaderboardManager = SharedModule.LeaderboardManager.new()
leaderboardManager:Initialize()

-- Initialize LeaderboardUI
local leaderboardUI = SharedModule.LeaderboardUI.new()
leaderboardUI:Initialize()

-- Connect UI to manager
leaderboardManager.ui = leaderboardUI

-- Store global references
_G.LeaderboardManager = leaderboardManager
_G.LeaderboardUI = leaderboardUI

print("LeaderboardClient: Initialized successfully")
print("LeaderboardClient: Press Ctrl+L to toggle leaderboard")

-- Wait a bit then request initial data
task.spawn(function()
    task.wait(3) -- Wait for server to be ready
    
    -- Request initial leaderboard data
    leaderboardManager:RequestLeaderboardData()
    
    print("LeaderboardClient: Requested initial leaderboard data")
end) 