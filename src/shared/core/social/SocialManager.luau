-- SocialManager.luau
-- Comprehensive social system for player interactions, guilds, teams, and communication

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MessagingService = game:GetService("MessagingService")
local TextService = game:GetService("TextService")

local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()

local SocialManager = {}
SocialManager.__index = SocialManager

-- Social system configuration
local SOCIAL_CONFIG = {
    MAX_GUILD_SIZE = 20,
    MAX_TEAM_SIZE = 6,
    MAX_CHAT_HISTORY = 100,
    CHAT_FILTER_ENABLED = true,
    FRIEND_LIMIT = 50,
    
    -- Chat channels
    CHAT_CHANNELS = {
        GLOBAL = "global",
        GUILD = "guild", 
        TEAM = "team",
        PROJECT = "project",
        PRIVATE = "private"
    },
    
    -- Social features
    FEATURES = {
        ENHANCED_CHAT = true,
        GUILD_SYSTEM = true,
        TEAM_FORMATION = true,
        FRIEND_SYSTEM = true,
        PROJECT_COLLABORATION = true,
        EMOTE_SYSTEM = true
    }
}

function SocialManager.new()
    local self = setmetatable({}, SocialManager)
    
    if IS_SERVER then
        -- Server-side data
        self.guilds = {}
        self.teams = {}
        self.chatChannels = {}
        self.friendConnections = {}
        self.projectTeams = {}
        self.playerSocialData = {}
        self.connections = {}
        
        -- Initialize chat channels
        for channelName, _ in pairs(SOCIAL_CONFIG.CHAT_CHANNELS) do
            self.chatChannels[channelName] = {
                messages = {},
                subscribers = {},
                moderators = {}
            }
        end
        
    elseif IS_CLIENT then
        -- Client-side data
        self.localPlayerData = {}
        self.chatHistory = {}
        self.currentChannel = SOCIAL_CONFIG.CHAT_CHANNELS.GLOBAL
        self.ui = nil
        self.connections = {}
    end
    
    return self
end

-- Initialize the social system
function SocialManager:Initialize()
    if IS_SERVER then
        self:SetupServerSide()
        print("SocialManager: Server initialized")
    elseif IS_CLIENT then
        self:SetupClientSide()
        print("SocialManager: Client initialized")
    end
end

-- Server-side setup
function SocialManager:SetupServerSide()
    -- Set up remote events
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then
        remotes = Instance.new("Folder")
        remotes.Name = "Remotes"
        remotes.Parent = ReplicatedStorage
    end
    
    -- Create social remote events
    self:CreateRemoteEvents(remotes)
    
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
end

-- Create remote events for social features
function SocialManager:CreateRemoteEvents(remotes)
    local remoteEvents = {
        -- Chat system
        "SendChatMessage",
        "JoinChatChannel", 
        "LeaveChatChannel",
        
        -- Guild system
        "CreateGuild",
        "JoinGuild",
        "LeaveGuild",
        "InviteToGuild",
        "KickFromGuild",
        "UpdateGuildInfo",
        
        -- Team system
        "CreateTeam",
        "JoinTeam", 
        "LeaveTeam",
        "InviteToTeam",
        
        -- Friend system
        "SendFriendRequest",
        "AcceptFriendRequest",
        "RemoveFriend",
        
        -- Project collaboration
        "CreateProjectTeam",
        "JoinProject",
        "RequestHelp",
        
        -- General updates
        "UpdateSocialData",
        "RequestSocialInfo"
    }
    
    for _, eventName in ipairs(remoteEvents) do
        if not remotes:FindFirstChild(eventName) then
            local remoteEvent = Instance.new("RemoteEvent")
            remoteEvent.Name = eventName
            remoteEvent.Parent = remotes
            
            -- Connect to appropriate handler
            remoteEvent.OnServerEvent:Connect(function(player, ...)
                self:HandleRemoteEvent(eventName, player, ...)
            end)
        end
    end
    
    -- Request function for getting social data
    if not remotes:FindFirstChild("GetSocialData") then
        local requestFunc = Instance.new("RemoteFunction")
        requestFunc.Name = "GetSocialData"
        requestFunc.Parent = remotes
        
        requestFunc.OnServerInvoke = function(player, dataType)
            return self:GetSocialData(player, dataType)
        end
    end
end

-- Client-side setup
function SocialManager:SetupClientSide()
    -- Connect to social updates
    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    
    local updateEvent = remotes:WaitForChild("UpdateSocialData")
    self.connections.updateReceived = updateEvent.OnClientEvent:Connect(function(socialData)
        self:ProcessSocialUpdate(socialData)
    end)
    
    -- Request initial social data
    task.wait(1)
    self:RequestSocialData()
end

-- Add a player to the social system
function SocialManager:AddPlayer(player)
    if not IS_SERVER then return end
    
    local playerData = {
        UserId = player.UserId,
        Name = player.Name,
        DisplayName = player.DisplayName,
        Guild = nil,
        Team = nil,
        Friends = {},
        BlockedUsers = {},
        ChatChannels = {SOCIAL_CONFIG.CHAT_CHANNELS.GLOBAL},
        SocialStatus = "Available", -- Available, Busy, Building, Away
        JoinTime = tick(),
        Reputation = 0,
        SocialLevel = 1
    }
    
    self.playerSocialData[player.UserId] = playerData
    
    -- Add to global chat by default
    self:AddPlayerToChannel(player, SOCIAL_CONFIG.CHAT_CHANNELS.GLOBAL)
    
    print("SocialManager: Added player", player.Name, "to social system")
end

-- Remove a player from the social system
function SocialManager:RemovePlayer(player)
    if not IS_SERVER then return end
    
    local playerData = self.playerSocialData[player.UserId]
    if not playerData then return end
    
    -- Remove from all chat channels
    for channelName, _ in pairs(self.chatChannels) do
        self:RemovePlayerFromChannel(player, channelName)
    end
    
    -- Remove from guild if in one
    if playerData.Guild then
        self:LeaveGuild(player)
    end
    
    -- Remove from team if in one
    if playerData.Team then
        self:LeaveTeam(player)
    end
    
    self.playerSocialData[player.UserId] = nil
    print("SocialManager: Removed player", player.Name, "from social system")
end

-- Handle remote events
function SocialManager:HandleRemoteEvent(eventName, player, ...)
    local args = {...}
    
    if eventName == "SendChatMessage" then
        self:HandleChatMessage(player, args[1], args[2]) -- channel, message
    elseif eventName == "CreateGuild" then
        self:CreateGuild(player, args[1], args[2]) -- name, description
    elseif eventName == "JoinGuild" then
        self:JoinGuild(player, args[1]) -- guildId
    elseif eventName == "CreateTeam" then
        self:CreateTeam(player, args[1], args[2]) -- name, purpose
    elseif eventName == "SendFriendRequest" then
        self:SendFriendRequest(player, args[1]) -- targetUserId
    elseif eventName == "RequestHelp" then
        self:RequestHelp(player, args[1], args[2]) -- projectType, description
    -- Add more event handlers as needed
    end
end

-- Enhanced Chat System
function SocialManager:HandleChatMessage(player, channel, message)
    if not IS_SERVER then return end
    
    -- Validate player and channel
    local playerData = self.playerSocialData[player.UserId]
    if not playerData then return end
    
    local channelData = self.chatChannels[channel]
    if not channelData then return end
    
    -- Check if player has access to this channel
    if not table.find(playerData.ChatChannels, channel) then
        return
    end
    
    -- Filter message if enabled
    local filteredMessage = message
    if SOCIAL_CONFIG.CHAT_FILTER_ENABLED then
        local success, result = pcall(function()
            return TextService:FilterStringAsync(message, player.UserId)
        end)
        
        if success then
            filteredMessage = result:GetNonChatStringForBroadcastAsync()
        end
    end
    
    -- Create message object
    local messageObj = {
        Id = game:GetService("HttpService"):GenerateGUID(false),
        Author = {
            UserId = player.UserId,
            Name = player.Name,
            DisplayName = player.DisplayName
        },
        Content = filteredMessage,
        Channel = channel,
        Timestamp = tick(),
        Type = "chat" -- chat, system, announcement
    }
    
    -- Add to channel history
    table.insert(channelData.messages, messageObj)
    
    -- Limit history size
    if #channelData.messages > SOCIAL_CONFIG.MAX_CHAT_HISTORY then
        table.remove(channelData.messages, 1)
    end
    
    -- Broadcast to channel subscribers
    self:BroadcastToChannel(channel, "ChatMessage", messageObj)
    
    print("SocialManager: Chat message from", player.Name, "in", channel, ":", filteredMessage)
end

-- Guild System
function SocialManager:CreateGuild(player, guildName, description)
    if not IS_SERVER then return end
    
    local playerData = self.playerSocialData[player.UserId]
    if not playerData or playerData.Guild then return end -- Already in a guild
    
    local guildId = game:GetService("HttpService"):GenerateGUID(false)
    local guild = {
        Id = guildId,
        Name = guildName,
        Description = description,
        Leader = player.UserId,
        Members = {player.UserId},
        Created = tick(),
        Level = 1,
        Experience = 0,
        Resources = {},
        Projects = {},
        ChatChannel = "guild_" .. guildId
    }
    
    self.guilds[guildId] = guild
    playerData.Guild = guildId
    
    -- Create guild chat channel
    self.chatChannels[guild.ChatChannel] = {
        messages = {},
        subscribers = {player.UserId},
        moderators = {player.UserId}
    }
    
    -- Add player to guild chat
    table.insert(playerData.ChatChannels, guild.ChatChannel)
    
    -- Broadcast guild creation
    self:BroadcastSocialUpdate(player, "GuildCreated", guild)
    
    print("SocialManager: Guild created:", guildName, "by", player.Name)
    return guild
end

function SocialManager:JoinGuild(player, guildId)
    if not IS_SERVER then return end
    
    local playerData = self.playerSocialData[player.UserId]
    local guild = self.guilds[guildId]
    
    if not playerData or not guild or playerData.Guild then return end
    
    -- Check guild size limit
    if #guild.Members >= SOCIAL_CONFIG.MAX_GUILD_SIZE then return end
    
    -- Add player to guild
    table.insert(guild.Members, player.UserId)
    playerData.Guild = guildId
    
    -- Add to guild chat
    table.insert(playerData.ChatChannels, guild.ChatChannel)
    table.insert(self.chatChannels[guild.ChatChannel].subscribers, player.UserId)
    
    -- Broadcast join
    self:BroadcastSocialUpdate(player, "GuildJoined", {guild = guild, player = playerData})
    
    print("SocialManager: Player", player.Name, "joined guild", guild.Name)
end

-- Team Formation System
function SocialManager:CreateTeam(player, teamName, purpose)
    if not IS_SERVER then return end
    
    local playerData = self.playerSocialData[player.UserId]
    if not playerData or playerData.Team then return end
    
    local teamId = game:GetService("HttpService"):GenerateGUID(false)
    local team = {
        Id = teamId,
        Name = teamName,
        Purpose = purpose, -- "building", "exploration", "competition", "general"
        Leader = player.UserId,
        Members = {player.UserId},
        Created = tick(),
        MaxSize = SOCIAL_CONFIG.MAX_TEAM_SIZE,
        Status = "recruiting", -- recruiting, active, completed
        ChatChannel = "team_" .. teamId
    }
    
    self.teams[teamId] = team
    playerData.Team = teamId
    
    -- Create team chat channel
    self.chatChannels[team.ChatChannel] = {
        messages = {},
        subscribers = {player.UserId},
        moderators = {player.UserId}
    }
    
    table.insert(playerData.ChatChannels, team.ChatChannel)
    
    self:BroadcastSocialUpdate(player, "TeamCreated", team)
    
    print("SocialManager: Team created:", teamName, "by", player.Name)
    return team
end

-- Project Collaboration System
function SocialManager:RequestHelp(player, projectType, description)
    if not IS_SERVER then return end
    
    local helpRequest = {
        Id = game:GetService("HttpService"):GenerateGUID(false),
        RequesterId = player.UserId,
        RequesterName = player.Name,
        ProjectType = projectType,
        Description = description,
        Timestamp = tick(),
        Status = "open", -- open, in_progress, completed
        Helpers = {},
        MaxHelpers = 5
    }
    
    -- Broadcast help request to all players
    self:BroadcastToChannel(SOCIAL_CONFIG.CHAT_CHANNELS.GLOBAL, "HelpRequest", helpRequest)
    
    print("SocialManager: Help requested by", player.Name, "for", projectType)
end

-- Friend System
function SocialManager:SendFriendRequest(player, targetUserId)
    if not IS_SERVER then return end
    
    local playerData = self.playerSocialData[player.UserId]
    if not playerData then return end
    
    -- Check if already friends or request exists
    if table.find(playerData.Friends, targetUserId) then return end
    
    local targetPlayer = Players:GetPlayerByUserId(targetUserId)
    if not targetPlayer then return end
    
    local friendRequest = {
        FromUserId = player.UserId,
        FromName = player.Name,
        ToUserId = targetUserId,
        Timestamp = tick()
    }
    
    -- Send to target player
    self:SendToPlayer(targetPlayer, "FriendRequest", friendRequest)
    
    print("SocialManager: Friend request sent from", player.Name, "to", targetPlayer.Name)
end

-- Communication utilities
function SocialManager:AddPlayerToChannel(player, channelName)
    local channelData = self.chatChannels[channelName]
    if not channelData then return end
    
    if not table.find(channelData.subscribers, player.UserId) then
        table.insert(channelData.subscribers, player.UserId)
    end
end

function SocialManager:RemovePlayerFromChannel(player, channelName)
    local channelData = self.chatChannels[channelName]
    if not channelData then return end
    
    local index = table.find(channelData.subscribers, player.UserId)
    if index then
        table.remove(channelData.subscribers, index)
    end
end

function SocialManager:BroadcastToChannel(channelName, eventType, data)
    local channelData = self.chatChannels[channelName]
    if not channelData then return end
    
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then return end
    
    local updateEvent = remotes:FindFirstChild("UpdateSocialData")
    if not updateEvent then return end
    
    for _, userId in ipairs(channelData.subscribers) do
        local player = Players:GetPlayerByUserId(userId)
        if player then
            updateEvent:FireClient(player, {
                Type = eventType,
                Channel = channelName,
                Data = data
            })
        end
    end
end

function SocialManager:SendToPlayer(player, eventType, data)
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then return end
    
    local updateEvent = remotes:FindFirstChild("UpdateSocialData")
    if updateEvent then
        updateEvent:FireClient(player, {
            Type = eventType,
            Data = data
        })
    end
end

function SocialManager:BroadcastSocialUpdate(player, eventType, data)
    -- Broadcast to all players
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then return end
    
    local updateEvent = remotes:FindFirstChild("UpdateSocialData")
    if updateEvent then
        updateEvent:FireAllClients({
            Type = eventType,
            Player = {
                UserId = player.UserId,
                Name = player.Name
            },
            Data = data
        })
    end
end

-- Get social data for client requests
function SocialManager:GetSocialData(player, dataType)
    if not IS_SERVER then return {} end
    
    local playerData = self.playerSocialData[player.UserId]
    if not playerData then return {} end
    
    if dataType == "playerData" then
        return playerData
    elseif dataType == "guilds" then
        return self.guilds
    elseif dataType == "teams" then
        return self.teams
    elseif dataType == "chatChannels" then
        local accessibleChannels = {}
        for _, channelName in ipairs(playerData.ChatChannels) do
            accessibleChannels[channelName] = self.chatChannels[channelName]
        end
        return accessibleChannels
    end
    
    return {}
end

-- Client-side functions
function SocialManager:ProcessSocialUpdate(socialData)
    if not IS_CLIENT then return end
    
    -- Update local data and UI
    if socialData.Type == "ChatMessage" then
        self:AddChatMessage(socialData.Data)
    elseif socialData.Type == "GuildCreated" or socialData.Type == "GuildJoined" then
        self:UpdateGuildInfo(socialData.Data)
    elseif socialData.Type == "TeamCreated" then
        self:UpdateTeamInfo(socialData.Data)
    elseif socialData.Type == "FriendRequest" then
        self:ShowFriendRequest(socialData.Data)
    elseif socialData.Type == "HelpRequest" then
        self:ShowHelpRequest(socialData.Data)
    end
    
    -- Update UI if available
    if self.ui then
        self.ui:UpdateSocialData(socialData)
    end
end

function SocialManager:AddChatMessage(message)
    if not IS_CLIENT then return end
    
    local channelHistory = self.chatHistory[message.Channel] or {}
    table.insert(channelHistory, message)
    
    -- Limit history
    if #channelHistory > SOCIAL_CONFIG.MAX_CHAT_HISTORY then
        table.remove(channelHistory, 1)
    end
    
    self.chatHistory[message.Channel] = channelHistory
end

function SocialManager:RequestSocialData()
    if not IS_CLIENT then return end
    
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local requestFunc = remotes:FindFirstChild("GetSocialData")
        if requestFunc then
            -- Request different types of social data
            local dataTypes = {"playerData", "guilds", "teams", "chatChannels"}
            for _, dataType in ipairs(dataTypes) do
                task.spawn(function()
                    local success, result = pcall(function()
                        return requestFunc:InvokeServer(dataType)
                    end)
                    
                    if success and result then
                        self:ProcessSocialUpdate({
                            Type = "Initial" .. dataType,
                            Data = result
                        })
                    end
                end)
            end
        end
    end
end

-- Cleanup
function SocialManager:Cleanup()
    for _, connection in pairs(self.connections) do
        if connection then
            connection:Disconnect()
        end
    end
    
    if self.ui then
        self.ui:Destroy()
    end
    
    print("SocialManager: Cleaned up")
end

return SocialManager 