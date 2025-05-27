-- SocialServerSetup.luau
-- Server-side initialization and integration for the social system

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Load the social system
local SharedModules = ReplicatedStorage:WaitForChild("Shared")
local SocialManager = require(SharedModules.Core.Social.SocialManager)

-- Load existing systems for integration
local CurrencyManager = require(SharedModules.Core.Economy.CurrencyManager)
local XPManager = require(SharedModules.Core.Progression.XPManager)

local SocialServerSetup = {}

-- Initialize the social system on the server
function SocialServerSetup.Initialize()
    print("SocialServerSetup: Initializing social system...")
    
    -- Create the main social manager
    local socialManager = SocialManager.new()
    socialManager:Initialize()
    
    -- Store globally for access by other systems
    if not _G.ForeverBuildSystems then
        _G.ForeverBuildSystems = {}
    end
    _G.ForeverBuildSystems.SocialManager = socialManager
    
    -- Set up integration hooks
    SocialServerSetup.SetupIntegrationHooks(socialManager)
    
    -- Set up testing environment
    if RunService:IsStudio() then
        SocialServerSetup.SetupTestingEnvironment(socialManager)
    end
    
    print("SocialServerSetup: Social system initialized successfully!")
    return socialManager
end

-- Set up integration hooks with existing systems
function SocialServerSetup.SetupIntegrationHooks(socialManager)
    print("SocialServerSetup: Setting up integration hooks...")
    
    -- Hook into XP system for social rewards
    if _G.ForeverBuildSystems and _G.ForeverBuildSystems.XPManager then
        local xpManager = _G.ForeverBuildSystems.XPManager
        
        -- Reward XP for social interactions
        local originalAwardXP = xpManager.AwardXP
        xpManager.AwardXP = function(self, player, amount, source)
            -- Call original method
            originalAwardXP(self, player, amount, source)
            
            -- Add social XP bonuses
            if source and source:find("social_") then
                local bonusAmount = math.floor(amount * 0.1) -- 10% social bonus
                if bonusAmount > 0 then
                    -- Send social bonus notification
                    SocialServerSetup.SendSocialNotification(player, "XP Bonus!", 
                        "+" .. bonusAmount .. " XP social bonus!", "success")
                end
            end
        end
    end
    
    -- Hook into currency system for guild/team shared resources
    if _G.ForeverBuildSystems and _G.ForeverBuildSystems.CurrencyManager then
        local currencyManager = _G.ForeverBuildSystems.CurrencyManager
        
        -- Track large purchases for guild/team notifications
        local originalDeductCurrency = currencyManager.DeductCurrency
        currencyManager.DeductCurrency = function(self, player, amount, reason)
            local success = originalDeductCurrency(self, player, amount, reason)
            
            if success and amount >= 1000 then -- Large purchase
                SocialServerSetup.BroadcastPlayerAction(socialManager, player, 
                    "💰 Made a large purchase", amount .. " coins spent")
            end
            
            return success
        end
    end
    
    print("SocialServerSetup: Integration hooks set up!")
end

-- Send social notification to a player
function SocialServerSetup.SendSocialNotification(player, title, message, notificationType)
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local updateEvent = remotes:FindFirstChild("UpdateSocialData")
        if updateEvent then
            updateEvent:FireClient(player, {
                Type = "SocialNotification",
                Data = {
                    Title = title,
                    Message = message,
                    NotificationType = notificationType or "info",
                    Timestamp = tick()
                }
            })
        end
    end
end

-- Broadcast player action to their guild/team
function SocialServerSetup.BroadcastPlayerAction(socialManager, player, action, details)
    local playerData = socialManager.playerSocialData[player.UserId]
    if not playerData then return end
    
    local actionData = {
        Player = {
            UserId = player.UserId,
            Name = player.Name,
            DisplayName = player.DisplayName
        },
        Action = action,
        Details = details,
        Timestamp = tick()
    }
    
    -- Broadcast to guild
    if playerData.Guild then
        local guild = socialManager.guilds[playerData.Guild]
        if guild then
            socialManager:BroadcastToChannel(guild.ChatChannel, "PlayerAction", actionData)
        end
    end
    
    -- Broadcast to team
    if playerData.Team then
        local team = socialManager.teams[playerData.Team]
        if team then
            socialManager:BroadcastToChannel(team.ChatChannel, "PlayerAction", actionData)
        end
    end
end

-- Set up testing environment for development
function SocialServerSetup.SetupTestingEnvironment(socialManager)
    print("SocialServerSetup: Setting up testing environment...")
    
    -- Create sample guilds and teams after a delay
    task.wait(2)
    
    -- Create sample guild
    local sampleGuild = {
        Id = "sample_guild_1",
        Name = "The Builders United",
        Description = "A guild for collaborative building projects and sharing techniques.",
        Leader = 0, -- System guild
        Members = {},
        Created = tick(),
        Level = 3,
        Experience = 1250,
        Resources = {
            Wood = 5000,
            Stone = 3000,
            Metal = 1500
        },
        Projects = {
            "Grand Castle Construction",
            "Community Garden Project"
        },
        ChatChannel = "guild_sample_guild_1"
    }
    
    socialManager.guilds[sampleGuild.Id] = sampleGuild
    socialManager.chatChannels[sampleGuild.ChatChannel] = {
        messages = {
            {
                Id = "sample_msg_1",
                Author = {UserId = 0, Name = "System", DisplayName = "System"},
                Content = "Welcome to The Builders United! Let's create amazing structures together! 🏗️",
                Channel = sampleGuild.ChatChannel,
                Timestamp = tick() - 3600,
                Type = "system"
            },
            {
                Id = "sample_msg_2", 
                Author = {UserId = 0, Name = "GuildBot", DisplayName = "Guild Bot"},
                Content = "Tip: Use '/project help' to get assistance with your builds!",
                Channel = sampleGuild.ChatChannel,
                Timestamp = tick() - 1800,
                Type = "system"
            }
        },
        subscribers = {},
        moderators = {}
    }
    
    -- Create sample team
    local sampleTeam = {
        Id = "sample_team_1",
        Name = "Sky Bridge Builders",
        Purpose = "building",
        Leader = 0,
        Members = {},
        Created = tick() - 7200,
        MaxSize = 6,
        Status = "recruiting",
        ChatChannel = "team_sample_team_1"
    }
    
    socialManager.teams[sampleTeam.Id] = sampleTeam
    socialManager.chatChannels[sampleTeam.ChatChannel] = {
        messages = {
            {
                Id = "sample_team_msg_1",
                Author = {UserId = 0, Name = "TeamBot", DisplayName = "Team Bot"},
                Content = "Team objective: Build a bridge connecting the floating islands! 🌉",
                Channel = sampleTeam.ChatChannel,
                Timestamp = tick() - 3600,
                Type = "system"
            }
        },
        subscribers = {},
        moderators = {}
    }
    
    -- Add sample help requests
    task.spawn(function()
        while true do
            task.wait(math.random(30, 120)) -- Random intervals
            
            local helpRequests = {
                {
                    projectType = "Castle Building",
                    description = "Need help with medieval castle towers and battlements!"
                },
                {
                    projectType = "Modern Architecture", 
                    description = "Looking for teammates to build a futuristic city district."
                },
                {
                    projectType = "Landscape Design",
                    description = "Creating a beautiful garden area, need creative minds!"
                },
                {
                    projectType = "Redstone Engineering",
                    description = "Complex contraption needs debugging - logic experts welcome!"
                }
            }
            
            local request = helpRequests[math.random(1, #helpRequests)]
            local helpRequest = {
                Id = game:GetService("HttpService"):GenerateGUID(false),
                RequesterId = 0,
                RequesterName = "Community Member",
                ProjectType = request.projectType,
                Description = request.description,
                Timestamp = tick(),
                Status = "open",
                Helpers = {},
                MaxHelpers = 5
            }
            
            socialManager:BroadcastToChannel("global", "HelpRequest", helpRequest)
        end
    end)
    
    -- Simulate global chat activity
    task.spawn(function()
        local sampleMessages = {
            "Just finished an amazing castle build! 🏰",
            "Anyone want to collaborate on a floating island project?",
            "The new building tools are fantastic! Great work devs! 👍",
            "Looking for inspiration - what's your favorite build style?",
            "Found a great spot for a community project near spawn!",
            "Pro tip: Use the grid alignment for perfect symmetry! ⚡",
            "Working on a medieval village - could use some help with houses!",
            "The teamwork on the grand bridge project was incredible! 🌉"
        }
        
        while true do
            task.wait(math.random(45, 180))
            
            local message = sampleMessages[math.random(1, #sampleMessages)]
            local messageObj = {
                Id = game:GetService("HttpService"):GenerateGUID(false),
                Author = {
                    UserId = 0,
                    Name = "CommunityBot",
                    DisplayName = "Community Bot"
                },
                Content = message,
                Channel = "global",
                Timestamp = tick(),
                Type = "chat"
            }
            
            -- Add to global channel
            table.insert(socialManager.chatChannels.global.messages, messageObj)
            
            -- Limit history
            if #socialManager.chatChannels.global.messages > 100 then
                table.remove(socialManager.chatChannels.global.messages, 1)
            end
            
            -- Broadcast to subscribers
            socialManager:BroadcastToChannel("global", "ChatMessage", messageObj)
        end
    end)
    
    print("SocialServerSetup: Testing environment ready!")
end

-- Add new players to sample social structures
function SocialServerSetup.AddPlayerToSampleStructures(socialManager, player)
    task.wait(1) -- Wait for player data to be set up
    
    local playerData = socialManager.playerSocialData[player.UserId]
    if not playerData then return end
    
    -- Auto-join sample guild for testing (optional)
    if math.random() < 0.3 then -- 30% chance
        local sampleGuild = socialManager.guilds["sample_guild_1"]
        if sampleGuild and #sampleGuild.Members < 20 then
            table.insert(sampleGuild.Members, player.UserId)
            playerData.Guild = sampleGuild.Id
            table.insert(playerData.ChatChannels, sampleGuild.ChatChannel)
            table.insert(socialManager.chatChannels[sampleGuild.ChatChannel].subscribers, player.UserId)
            
            -- Send welcome message
            SocialServerSetup.SendSocialNotification(player, "Guild Joined!", 
                "Welcome to " .. sampleGuild.Name .. "! Check the Guild tab to get started.", "success")
        end
    end
    
    -- Send welcome tip about social features
    task.wait(5)
    SocialServerSetup.SendSocialNotification(player, "Social Features Available!", 
        "Press Ctrl+S to open the Social Hub - chat with others, join guilds, form teams, and collaborate on projects!", "info")
end

-- Export setup functions
return SocialServerSetup 