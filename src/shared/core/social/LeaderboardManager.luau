-- LeaderboardManager.luau
-- Manages player rankings and leaderboard data

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()

local LeaderboardManager = {}
LeaderboardManager.__index = LeaderboardManager

-- Leaderboard configuration
local LEADERBOARD_CONFIG = {
    UPDATE_INTERVAL = 5, -- Update every 5 seconds
    MAX_PLAYERS_DISPLAYED = 20, -- Top 20 players
    STATS_TO_TRACK = {
        "Cash",
        "ItemsPlaced", 
        "Level",
        "TotalXP",
        "PlayTime"
    }
}

function LeaderboardManager.new()
    local self = setmetatable({}, LeaderboardManager)
    
    if IS_SERVER then
        -- Server-side data
        self.playerStats = {}
        self.leaderboards = {}
        self.connections = {}
        self.updateTimer = 0
        
        -- Initialize leaderboard types
        for _, statName in ipairs(LEADERBOARD_CONFIG.STATS_TO_TRACK) do
            self.leaderboards[statName] = {}
        end
        
    elseif IS_CLIENT then
        -- Client-side data
        self.cachedLeaderboards = {}
        self.connections = {}
        self.ui = nil
    end
    
    return self
end

-- Initialize the leaderboard system
function LeaderboardManager:Initialize()
    if IS_SERVER then
        self:SetupServerSide()
        print("LeaderboardManager: Server initialized")
    elseif IS_CLIENT then
        self:SetupClientSide()
        print("LeaderboardManager: Client initialized")
    end
end

-- Server-side setup
function LeaderboardManager:SetupServerSide()
    -- Set up remote events
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then
        remotes = Instance.new("Folder")
        remotes.Name = "Remotes"
        remotes.Parent = ReplicatedStorage
    end
    
    -- Create leaderboard remote events
    if not remotes:FindFirstChild("UpdateLeaderboard") then
        local updateEvent = Instance.new("RemoteEvent")
        updateEvent.Name = "UpdateLeaderboard"
        updateEvent.Parent = remotes
    end
    
    if not remotes:FindFirstChild("RequestLeaderboard") then
        local requestFunc = Instance.new("RemoteFunction")
        requestFunc.Name = "RequestLeaderboard"
        requestFunc.Parent = remotes
        
        requestFunc.OnServerInvoke = function(player, statType)
            return self:GetLeaderboard(statType)
        end
    end
    
    -- Track player connections
    self.connections.playerAdded = Players.PlayerAdded:Connect(function(player)
        self:AddPlayer(player)
    end)
    
    self.connections.playerRemoving = Players.PlayerRemoving:Connect(function(player)
        self:RemovePlayer(player)
    end)
    
    -- Add existing players
    for _, player in ipairs(Players:GetPlayers()) do
        self:AddPlayer(player)
    end
    
    -- Set up periodic updates
    self.connections.heartbeat = RunService.Heartbeat:Connect(function(deltaTime)
        self.updateTimer = self.updateTimer + deltaTime
        if self.updateTimer >= LEADERBOARD_CONFIG.UPDATE_INTERVAL then
            self:UpdateAllLeaderboards()
            self.updateTimer = 0
        end
    end)
end

-- Client-side setup
function LeaderboardManager:SetupClientSide()
    -- Connect to leaderboard updates
    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    local updateEvent = remotes:WaitForChild("UpdateLeaderboard")
    
    self.connections.updateReceived = updateEvent.OnClientEvent:Connect(function(leaderboardData)
        self:ProcessLeaderboardUpdate(leaderboardData)
    end)
    
    -- Request initial leaderboard data
    task.wait(1) -- Wait for server to be ready
    self:RequestLeaderboardData()
end

-- Add a player to tracking
function LeaderboardManager:AddPlayer(player)
    if not IS_SERVER then return end
    
    local playerData = {
        UserId = player.UserId,
        Name = player.Name,
        DisplayName = player.DisplayName,
        Cash = 0,
        ItemsPlaced = 0,
        Level = 1,
        TotalXP = 0,
        PlayTime = 0,
        JoinTime = tick()
    }
    
    -- Try to load existing data from DataStore or other systems
    self:LoadPlayerData(player, playerData)
    
    self.playerStats[player.UserId] = playerData
    print("LeaderboardManager: Added player", player.Name, "to tracking")
end

-- Remove a player from tracking
function LeaderboardManager:RemovePlayer(player)
    if not IS_SERVER then return end
    
    if self.playerStats[player.UserId] then
        -- Update play time before removing
        self.playerStats[player.UserId].PlayTime = 
            self.playerStats[player.UserId].PlayTime + (tick() - self.playerStats[player.UserId].JoinTime)
        
        -- Save data before removing
        self:SavePlayerData(player, self.playerStats[player.UserId])
        
        self.playerStats[player.UserId] = nil
        print("LeaderboardManager: Removed player", player.Name, "from tracking")
    end
end

-- Load player data from existing systems
function LeaderboardManager:LoadPlayerData(player, playerData)
    -- Try to get data from currency manager
    if _G.CurrencyManager then
        local balance = _G.CurrencyManager:GetPlayerBalance(player)
        if balance then
            playerData.Cash = balance
        end
    end
    
    -- Try to get data from progression manager
    if _G.ProgressionManager then
        local progression = _G.ProgressionManager:GetPlayerProgression(player.UserId)
        if progression then
            playerData.Level = progression.level or 1
            playerData.TotalXP = progression.totalXP or 0
            playerData.ItemsPlaced = progression.itemsPlaced or 0
        end
    end
end

-- Save player data
function LeaderboardManager:SavePlayerData(player, playerData)
    -- This would integrate with your DataStore system
    -- For now, just print for debugging
    print("LeaderboardManager: Saving data for", player.Name, playerData)
end

-- Update player stat
function LeaderboardManager:UpdatePlayerStat(player, statName, value)
    if not IS_SERVER then return end
    
    local playerData = self.playerStats[player.UserId]
    if playerData then
        playerData[statName] = value
        
        -- Mark for leaderboard update
        if statName == "Cash" or statName == "ItemsPlaced" or statName == "Level" or statName == "TotalXP" then
            -- Trigger immediate update for important stats
            task.spawn(function()
                self:UpdateLeaderboard(statName)
                self:BroadcastLeaderboardUpdate(statName)
            end)
        end
    end
end

-- Increment player stat
function LeaderboardManager:IncrementPlayerStat(player, statName, amount)
    if not IS_SERVER then return end
    
    local playerData = self.playerStats[player.UserId]
    if playerData then
        playerData[statName] = (playerData[statName] or 0) + (amount or 1)
        
        -- Update play time
        if statName ~= "PlayTime" then
            playerData.PlayTime = playerData.PlayTime + (tick() - playerData.JoinTime)
            playerData.JoinTime = tick()
        end
        
        -- Trigger leaderboard update for tracked stats
        if table.find(LEADERBOARD_CONFIG.STATS_TO_TRACK, statName) then
            task.spawn(function()
                self:UpdateLeaderboard(statName)
                self:BroadcastLeaderboardUpdate(statName)
            end)
        end
    end
end

-- Update a specific leaderboard
function LeaderboardManager:UpdateLeaderboard(statName)
    if not IS_SERVER then return end
    
    local leaderboard = {}
    
    -- Collect and sort player data
    for userId, playerData in pairs(self.playerStats) do
        local value = playerData[statName] or 0
        table.insert(leaderboard, {
            UserId = userId,
            Name = playerData.Name,
            DisplayName = playerData.DisplayName,
            Value = value,
            Rank = 0 -- Will be set after sorting
        })
    end
    
    -- Sort by value (descending)
    table.sort(leaderboard, function(a, b)
        return a.Value > b.Value
    end)
    
    -- Assign ranks and limit to max display count
    for i, entry in ipairs(leaderboard) do
        entry.Rank = i
        if i > LEADERBOARD_CONFIG.MAX_PLAYERS_DISPLAYED then
            table.remove(leaderboard, i)
        end
    end
    
    self.leaderboards[statName] = leaderboard
end

-- Update all leaderboards
function LeaderboardManager:UpdateAllLeaderboards()
    if not IS_SERVER then return end
    
    for _, statName in ipairs(LEADERBOARD_CONFIG.STATS_TO_TRACK) do
        self:UpdateLeaderboard(statName)
    end
    
    -- Broadcast update to all clients
    self:BroadcastAllLeaderboards()
end

-- Get leaderboard data
function LeaderboardManager:GetLeaderboard(statName)
    if not IS_SERVER then return {} end
    
    statName = statName or "Cash" -- Default to cash leaderboard
    return self.leaderboards[statName] or {}
end

-- Broadcast leaderboard update to clients
function LeaderboardManager:BroadcastLeaderboardUpdate(statName)
    if not IS_SERVER then return end
    
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local updateEvent = remotes:FindFirstChild("UpdateLeaderboard")
        if updateEvent then
            local leaderboardData = {
                StatName = statName,
                Data = self.leaderboards[statName] or {}
            }
            updateEvent:FireAllClients(leaderboardData)
        end
    end
end

-- Broadcast all leaderboards to clients
function LeaderboardManager:BroadcastAllLeaderboards()
    if not IS_SERVER then return end
    
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local updateEvent = remotes:FindFirstChild("UpdateLeaderboard")
        if updateEvent then
            for statName, leaderboard in pairs(self.leaderboards) do
                local leaderboardData = {
                    StatName = statName,
                    Data = leaderboard
                }
                updateEvent:FireAllClients(leaderboardData)
            end
        end
    end
end

-- Client: Process leaderboard update
function LeaderboardManager:ProcessLeaderboardUpdate(leaderboardData)
    if not IS_CLIENT then return end
    
    self.cachedLeaderboards[leaderboardData.StatName] = leaderboardData.Data
    
    -- Update UI if it exists
    if self.ui then
        self.ui:UpdateLeaderboard(leaderboardData.StatName, leaderboardData.Data)
    end
    
    print("LeaderboardManager: Updated", leaderboardData.StatName, "leaderboard with", #leaderboardData.Data, "entries")
end

-- Client: Request leaderboard data
function LeaderboardManager:RequestLeaderboardData()
    if not IS_CLIENT then return end
    
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local requestFunc = remotes:FindFirstChild("RequestLeaderboard")
        if requestFunc then
            for _, statName in ipairs(LEADERBOARD_CONFIG.STATS_TO_TRACK) do
                task.spawn(function()
                    local success, result = pcall(function()
                        return requestFunc:InvokeServer(statName)
                    end)
                    
                    if success and result then
                        self:ProcessLeaderboardUpdate({
                            StatName = statName,
                            Data = result
                        })
                    end
                end)
            end
        end
    end
end

-- Client: Get cached leaderboard
function LeaderboardManager:GetCachedLeaderboard(statName)
    if not IS_CLIENT then return {} end
    
    return self.cachedLeaderboards[statName] or {}
end

-- Integration with existing systems
function LeaderboardManager:IntegrateWithCurrency()
    if not IS_SERVER then return end
    
    -- This will be called when currency changes
    -- Hook into existing currency system events
end

function LeaderboardManager:IntegrateWithProgression()
    if not IS_SERVER then return end
    
    -- This will be called when progression changes
    -- Hook into existing progression system events
end

-- Cleanup
function LeaderboardManager:Cleanup()
    for _, connection in pairs(self.connections) do
        if connection then
            connection:Disconnect()
        end
    end
    
    if self.ui then
        self.ui:Destroy()
    end
    
    print("LeaderboardManager: Cleaned up")
end

return LeaderboardManager 