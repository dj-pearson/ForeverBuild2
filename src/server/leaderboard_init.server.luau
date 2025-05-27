-- leaderboard_init.server.luau
-- Server-side initialization for leaderboard system

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

print("LeaderboardServer: Initializing...")

-- Wait for shared module
local shared = ReplicatedStorage:WaitForChild("shared", 10)
if not shared then
    warn("LeaderboardServer: Could not find shared module")
    return
end

local SharedModule = require(shared)
if not SharedModule.LeaderboardManager then
    warn("LeaderboardServer: LeaderboardManager not found in SharedModule")
    return
end

-- Initialize LeaderboardManager
local leaderboardManager = SharedModule.LeaderboardManager.new()
leaderboardManager:Initialize()

-- Store global reference for integration
_G.LeaderboardManager = leaderboardManager

print("LeaderboardServer: Initialized successfully")

-- Integration with existing systems
task.spawn(function()
    task.wait(5) -- Wait for other systems to load
    
    -- Hook into currency changes
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local updateBalanceEvent = remotes:FindFirstChild("UpdateBalance")
        if updateBalanceEvent then
            print("LeaderboardServer: Found UpdateBalance event, hooking into currency changes")
            
            -- Monitor currency updates and update leaderboard
            local originalFire = updateBalanceEvent.FireClient
            updateBalanceEvent.FireClient = function(self, player, balance)
                -- Update leaderboard with new balance
                leaderboardManager:UpdatePlayerStat(player, "Cash", balance)
                
                -- Call original function
                return originalFire(self, player, balance)
            end
        end
        
        -- Hook into progression updates
        local updateProgressionEvent = remotes:FindFirstChild("UpdateProgression")
        if updateProgressionEvent then
            print("LeaderboardServer: Found UpdateProgression event, hooking into progression changes")
            
            updateProgressionEvent.OnServerEvent:Connect(function(player, progressionData)
                if progressionData then
                    leaderboardManager:UpdatePlayerStat(player, "Level", progressionData.level or 1)
                    leaderboardManager:UpdatePlayerStat(player, "TotalXP", progressionData.totalXP or 0)
                    leaderboardManager:UpdatePlayerStat(player, "ItemsPlaced", progressionData.itemsPlaced or 0)
                end
            end)
        end
    end
    
    -- Hook into placement system if available
    if _G.PlacementManager then
        print("LeaderboardServer: Hooking into PlacementManager for item tracking")
        -- This would need to be implemented based on your specific placement system
    end
    
    print("LeaderboardServer: Integration hooks established")
end)

-- Create some sample data for testing
task.spawn(function()
    task.wait(10) -- Wait for players to join and systems to settle
    
    if #Players:GetPlayers() > 0 then
        print("LeaderboardServer: Creating sample data for testing...")
        
        for _, player in ipairs(Players:GetPlayers()) do
            -- Set some sample stats for testing
            leaderboardManager:UpdatePlayerStat(player, "Cash", math.random(100, 10000))
            leaderboardManager:UpdatePlayerStat(player, "ItemsPlaced", math.random(0, 500))
            leaderboardManager:UpdatePlayerStat(player, "Level", math.random(1, 25))
            leaderboardManager:UpdatePlayerStat(player, "TotalXP", math.random(0, 5000))
            
            -- Simulate some playtime
            leaderboardManager:UpdatePlayerStat(player, "PlayTime", math.random(300, 7200)) -- 5 minutes to 2 hours
        end
        
        print("LeaderboardServer: Sample data created")
    end
end)

-- Demo function to simulate stat changes (for testing)
task.spawn(function()
    while true do
        task.wait(30) -- Every 30 seconds
        
        local players = Players:GetPlayers()
        if #players > 0 then
            local randomPlayer = players[math.random(1, #players)]
            
            -- Simulate random stat increases
            local statChanges = {
                {stat = "Cash", amount = math.random(10, 100)},
                {stat = "ItemsPlaced", amount = 1},
                {stat = "TotalXP", amount = math.random(5, 25)}
            }
            
            local change = statChanges[math.random(1, #statChanges)]
            leaderboardManager:IncrementPlayerStat(randomPlayer, change.stat, change.amount)
            
            print("LeaderboardServer: Incremented", randomPlayer.Name, change.stat, "by", change.amount)
        end
    end
end) 