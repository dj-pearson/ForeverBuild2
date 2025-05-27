-- test_leaderboard.client.luau
-- Test script for leaderboard functionality

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

print("LeaderboardTest: Starting test script...")

-- Wait for leaderboard to be initialized
task.wait(5)

if not _G.LeaderboardUI or not _G.LeaderboardManager then
    warn("LeaderboardTest: Leaderboard system not found. Make sure leaderboard_init.client.luau has run.")
    return
end

local leaderboardUI = _G.LeaderboardUI
local leaderboardManager = _G.LeaderboardManager

print("LeaderboardTest: Found leaderboard system!")
print("LeaderboardTest: Available commands:")
print("  - Press 'L' to show/hide leaderboard")
print("  - Press 'T' to show test info")
print("  - Press 'R' to refresh leaderboard data")

-- Test functions
local function showTestInfo()
    print("=== LEADERBOARD TEST INFO ===")
    print("UI Visible:", leaderboardUI.isVisible)
    print("Current Tab:", leaderboardUI.currentTab)
    
    local cachedData = leaderboardManager.cachedLeaderboards
    for statName, data in pairs(cachedData) do
        print("Cached", statName, "entries:", #data)
        if #data > 0 then
            print("  Top player:", data[1].Name, "with", data[1].Value)
        end
    end
    print("========================")
end

local function refreshLeaderboard()
    print("LeaderboardTest: Refreshing leaderboard data...")
    leaderboardManager:RequestLeaderboardData()
end

-- Set up test controls
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.L then
        leaderboardUI:Toggle()
        print("LeaderboardTest: Toggled leaderboard display")
    elseif input.KeyCode == Enum.KeyCode.T then
        showTestInfo()
    elseif input.KeyCode == Enum.KeyCode.R then
        refreshLeaderboard()
    end
end)

-- Monitor leaderboard updates
local originalProcessUpdate = leaderboardManager.ProcessLeaderboardUpdate
leaderboardManager.ProcessLeaderboardUpdate = function(self, leaderboardData)
    print("LeaderboardTest: Received update for", leaderboardData.StatName, "with", #leaderboardData.Data, "entries")
    
    -- Call original function
    return originalProcessUpdate(self, leaderboardData)
end

-- Show initial test info after a delay
task.spawn(function()
    task.wait(3)
    showTestInfo()
    
    -- Auto-show leaderboard for demo
    task.wait(2)
    if not leaderboardUI.isVisible then
        leaderboardUI:Show()
        print("LeaderboardTest: Auto-showing leaderboard for demo")
    end
end)

print("LeaderboardTest: Test controls active!") 