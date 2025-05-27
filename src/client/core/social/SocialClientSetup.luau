-- SocialClientSetup.luau
-- Client-side initialization for the social system

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- Load the social system modules
local SharedModules = ReplicatedStorage:WaitForChild("Shared")
local SocialManager = require(SharedModules.Core.Social.SocialManager)
local SocialUI = require(SharedModules.Core.Social.SocialUI)

local SocialClientSetup = {}

-- Initialize the social system on the client
function SocialClientSetup.Initialize()
    print("SocialClientSetup: Initializing client social system...")
    
    -- Wait for player to fully load
    repeat task.wait() until LocalPlayer.Character
    
    -- Create the social manager
    local socialManager = SocialManager.new()
    socialManager:Initialize()
    
    -- Create the social UI
    local socialUI = SocialUI.new(socialManager)
    
    -- Connect UI to manager
    socialManager.ui = socialUI
    
    -- Store globally for access by other systems
    if not _G.ForeverBuildSystems then
        _G.ForeverBuildSystems = {}
    end
    _G.ForeverBuildSystems.SocialManager = socialManager
    _G.ForeverBuildSystems.SocialUI = socialUI
    
    -- Set up additional client features
    SocialClientSetup.SetupClientFeatures(socialManager, socialUI)
    
    print("SocialClientSetup: Client social system initialized successfully!")
    return socialManager, socialUI
end

-- Set up additional client-specific social features
function SocialClientSetup.SetupClientFeatures(socialManager, socialUI)
    print("SocialClientSetup: Setting up client features...")
    
    -- Set up emote system
    SocialClientSetup.SetupEmoteSystem(socialManager)
    
    -- Set up notification system
    SocialClientSetup.SetupNotificationSystem(socialManager)
    
    -- Set up status indicator
    SocialClientSetup.SetupStatusIndicator(socialManager)
    
    -- Set up integration with other client systems
    SocialClientSetup.SetupClientIntegration(socialManager, socialUI)
    
    print("SocialClientSetup: Client features set up!")
end

-- Set up emote system for social interactions
function SocialClientSetup.SetupEmoteSystem(socialManager)
    local emotes = {
        [Enum.KeyCode.One] = {Name = "Wave", Animation = "rbxassetid://507770239", Duration = 2},
        [Enum.KeyCode.Two] = {Name = "Thumbs Up", Animation = "rbxassetid://507770677", Duration = 1.5},
        [Enum.KeyCode.Three] = {Name = "Cheer", Animation = "rbxassetid://507770375", Duration = 3},
        [Enum.KeyCode.Four] = {Name = "Point", Animation = "rbxassetid://507770512", Duration = 2},
        [Enum.KeyCode.Five] = {Name = "Clap", Animation = "rbxassetid://507770508", Duration = 2.5}
    }
    
    local emoteConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        -- Check for Alt + Number key combinations
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
            local emote = emotes[input.KeyCode]
            if emote and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                -- Play emote animation
                local humanoid = LocalPlayer.Character.Humanoid
                local animator = humanoid:FindFirstChild("Animator")
                
                if animator then
                    local animationTrack = animator:LoadAnimation(emote.Animation)
                    animationTrack:Play()
                    
                    -- Send emote to other players
                    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                    if remotes then
                        local sendEvent = remotes:FindFirstChild("SendChatMessage")
                        if sendEvent then
                            sendEvent:FireServer("global", "🎭 " .. LocalPlayer.DisplayName .. " " .. emote.Name:lower() .. "s!")
                        end
                    end
                    
                    -- Auto-stop after duration
                    task.wait(emote.Duration)
                    animationTrack:Stop()
                end
            end
        end
    end)
    
    -- Store connection for cleanup
    socialManager.connections.emoteHandler = emoteConnection
    
    print("SocialClientSetup: Emote system ready! (Alt + 1-5 for emotes)")
end

-- Set up notification system for social events
function SocialClientSetup.SetupNotificationSystem(socialManager)
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    
    -- Create notification container
    local notificationGui = Instance.new("ScreenGui")
    notificationGui.Name = "SocialNotifications"
    notificationGui.ResetOnSpawn = false
    notificationGui.Parent = PlayerGui
    
    local notificationFrame = Instance.new("Frame")
    notificationFrame.Name = "NotificationContainer"
    notificationFrame.Size = UDim2.new(0, 350, 1, 0)
    notificationFrame.Position = UDim2.new(1, -370, 0, 20)
    notificationFrame.BackgroundTransparency = 1
    notificationFrame.Parent = notificationGui
    
    local notificationLayout = Instance.new("UIListLayout")
    notificationLayout.FillDirection = Enum.FillDirection.Vertical
    notificationLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    notificationLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    notificationLayout.Padding = UDim.new(0, 10)
    notificationLayout.Parent = notificationFrame
    
    -- Function to show notifications
    socialManager.ShowNotification = function(title, message, notificationType)
        SocialClientSetup.ShowNotification(notificationFrame, title, message, notificationType)
    end
    
    print("SocialClientSetup: Notification system ready!")
end

-- Show a notification to the player
function SocialClientSetup.ShowNotification(container, title, message, notificationType)
    local colors = {
        success = Color3.fromRGB(40, 167, 69),
        error = Color3.fromRGB(220, 53, 69),
        warning = Color3.fromRGB(255, 193, 7),
        info = Color3.fromRGB(23, 162, 184)
    }
    
    local color = colors[notificationType] or colors.info
    
    -- Create notification frame
    local notification = Instance.new("Frame")
    notification.Size = UDim2.new(1, 0, 0, 80)
    notification.BackgroundColor3 = color
    notification.BorderSizePixel = 0
    notification.Parent = container
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = notification
    
    -- Title label
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -20, 0, 25)
    titleLabel.Position = UDim2.new(0, 10, 0, 5)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = notification
    
    -- Message label
    local messageLabel = Instance.new("TextLabel")
    messageLabel.Size = UDim2.new(1, -20, 0, 45)
    messageLabel.Position = UDim2.new(0, 10, 0, 25)
    messageLabel.BackgroundTransparency = 1
    messageLabel.Text = message
    messageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    messageLabel.TextScaled = true
    messageLabel.Font = Enum.Font.Gotham
    messageLabel.TextXAlignment = Enum.TextXAlignment.Left
    messageLabel.TextWrapped = true
    messageLabel.Parent = notification
    
    -- Animate in
    notification.Position = UDim2.new(1, 50, 0, 0)
    notification:TweenPosition(UDim2.new(0, 0, 0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.3)
    
    -- Auto-remove after delay
    task.wait(4)
    notification:TweenPosition(UDim2.new(1, 50, 0, 0), Enum.EasingDirection.In, Enum.EasingStyle.Back, 0.3)
    task.wait(0.3)
    notification:Destroy()
end

-- Set up social status indicator
function SocialClientSetup.SetupStatusIndicator(socialManager)
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    
    -- Create status indicator
    local statusGui = Instance.new("ScreenGui")
    statusGui.Name = "SocialStatusIndicator"
    statusGui.ResetOnSpawn = false
    statusGui.Parent = PlayerGui
    
    local statusFrame = Instance.new("Frame")
    statusFrame.Name = "StatusFrame"
    statusFrame.Size = UDim2.new(0, 200, 0, 35)
    statusFrame.Position = UDim2.new(0, 20, 1, -55)
    statusFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    statusFrame.BorderSizePixel = 0
    statusFrame.Parent = statusGui
    
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 8)
    statusCorner.Parent = statusFrame
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -20, 1, 0)
    statusLabel.Position = UDim2.new(0, 10, 0, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "🟢 Online | 👥 Global Chat"
    statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    statusLabel.TextScaled = true
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = statusFrame
    
    -- Update status periodically
    task.spawn(function()
        while statusLabel.Parent do
            local playerCount = #Players:GetPlayers()
            local status = "🟢 Online | 👥 " .. playerCount .. " players"
            
            -- Add guild/team info if available
            if socialManager.localPlayerData then
                if socialManager.localPlayerData.Guild then
                    status = status .. " | 🏰 In Guild"
                end
                if socialManager.localPlayerData.Team then
                    status = status .. " | 👥 In Team"
                end
            end
            
            statusLabel.Text = status
            task.wait(5)
        end
    end)
    
    print("SocialClientSetup: Status indicator ready!")
end

-- Set up integration with other client systems
function SocialClientSetup.SetupClientIntegration(socialManager, socialUI)
    -- Connect to existing XP system notifications
    if _G.ForeverBuildSystems and _G.ForeverBuildSystems.XPManager then
        local xpManager = _G.ForeverBuildSystems.XPManager
        
        -- Hook into level up events for social sharing
        if xpManager.connections then
            xpManager.connections.socialLevelUp = xpManager.levelUpEvent.Event:Connect(function(playerData)
                -- Share level up with guild/team
                local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                if remotes then
                    local sendEvent = remotes:FindFirstChild("SendChatMessage")
                    if sendEvent then
                        -- Check current channel and send appropriate message
                        if socialUI.currentChannel and socialUI.currentChannel ~= "global" then
                            sendEvent:FireServer(socialUI.currentChannel, 
                                "🎉 " .. LocalPlayer.DisplayName .. " reached level " .. playerData.level .. "!")
                        end
                    end
                end
            end)
        end
    end
    
    -- Connect to building system for project collaboration
    if _G.ForeverBuildSystems and _G.ForeverBuildSystems.BuildingToolsManager then
        local buildingManager = _G.ForeverBuildSystems.BuildingToolsManager
        
        -- Share major building achievements
        local originalPlaceItem = buildingManager.PlaceItem
        if originalPlaceItem then
            buildingManager.PlaceItem = function(self, ...)
                local result = originalPlaceItem(self, ...)
                
                -- Track building milestones
                if result and self.placedItemsCount and self.placedItemsCount % 100 == 0 then
                    -- Every 100 items, share with team/guild
                    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                    if remotes and socialUI.currentChannel ~= "global" then
                        local sendEvent = remotes:FindFirstChild("SendChatMessage")
                        if sendEvent then
                            sendEvent:FireServer(socialUI.currentChannel, 
                                "🏗️ " .. LocalPlayer.DisplayName .. " has placed " .. self.placedItemsCount .. " items!")
                        end
                    end
                end
                
                return result
            end
        end
    end
    
    print("SocialClientSetup: Client integrations ready!")
end

-- Handle social data updates from server
function SocialClientSetup.HandleSocialUpdate(socialData)
    local socialManager = _G.ForeverBuildSystems.SocialManager
    if not socialManager then return end
    
    -- Handle notifications
    if socialData.Type == "SocialNotification" then
        if socialManager.ShowNotification then
            socialManager.ShowNotification(
                socialData.Data.Title,
                socialData.Data.Message,
                socialData.Data.NotificationType
            )
        end
    end
    
    -- Handle help requests
    if socialData.Type == "HelpRequest" then
        if socialManager.ShowNotification then
            socialManager.ShowNotification(
                "🆘 Help Request",
                socialData.Data.RequesterName .. " needs help with " .. socialData.Data.ProjectType,
                "info"
            )
        end
    end
    
    -- Handle player actions (guild/team updates)
    if socialData.Type == "PlayerAction" then
        if socialManager.ShowNotification then
            socialManager.ShowNotification(
                "👥 " .. socialData.Data.Player.DisplayName,
                socialData.Data.Action .. ": " .. socialData.Data.Details,
                "info"
            )
        end
    end
end

-- Export setup functions
return SocialClientSetup 