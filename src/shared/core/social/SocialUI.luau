-- SocialUI.luau
-- Modern UI for social features including chat, guilds, teams, friends, and project collaboration

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local SocialUI = {}
SocialUI.__index = SocialUI

-- UI Configuration
local UI_CONFIG = {
    MAIN_SIZE = UDim2.new(0, 800, 0, 600),
    ANIMATION_TIME = 0.3,
    CHAT_COLORS = {
        GLOBAL = Color3.fromRGB(100, 149, 237),    -- Cornflower Blue
        GUILD = Color3.fromRGB(255, 215, 0),       -- Gold
        TEAM = Color3.fromRGB(50, 205, 50),        -- Lime Green
        PROJECT = Color3.fromRGB(255, 165, 0),     -- Orange
        PRIVATE = Color3.fromRGB(255, 20, 147)     -- Deep Pink
    },
    TABS = {
        CHAT = {Name = "Chat", Icon = "💬"},
        GUILDS = {Name = "Guilds", Icon = "🏰"},
        TEAMS = {Name = "Teams", Icon = "👥"},
        FRIENDS = {Name = "Friends", Icon = "👫"},
        PROJECTS = {Name = "Projects", Icon = "🔨"}
    }
}

function SocialUI.new(socialManager)
    local self = setmetatable({}, SocialUI)
    
    self.socialManager = socialManager
    self.isVisible = false
    self.currentTab = "CHAT"
    self.connections = {}
    
    -- Create the main UI
    self:CreateMainInterface()
    self:SetupEventHandlers()
    
    return self
end

function SocialUI:CreateMainInterface()
    -- Main ScreenGui
    self.gui = Instance.new("ScreenGui")
    self.gui.Name = "SocialInterface"
    self.gui.ResetOnSpawn = false
    self.gui.Parent = PlayerGui
    
    -- Main Frame
    self.mainFrame = Instance.new("Frame")
    self.mainFrame.Name = "SocialPanel"
    self.mainFrame.Size = UI_CONFIG.MAIN_SIZE
    self.mainFrame.Position = UDim2.new(0.5, -400, 0.5, -300)
    self.mainFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    self.mainFrame.BorderSizePixel = 0
    self.mainFrame.Visible = false
    self.mainFrame.Parent = self.gui
    
    -- Add rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = self.mainFrame
    
    -- Add drop shadow
    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 10, 1, 10)
    shadow.Position = UDim2.new(0, -5, 0, -5)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.7
    shadow.BorderSizePixel = 0
    shadow.ZIndex = self.mainFrame.ZIndex - 1
    shadow.Parent = self.mainFrame
    
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 12)
    shadowCorner.Parent = shadow
    
    -- Header
    self:CreateHeader()
    
    -- Tab System
    self:CreateTabSystem()
    
    -- Content Area
    self:CreateContentArea()
    
    -- Initialize with Chat tab
    self:SwitchTab("CHAT")
end

function SocialUI:CreateHeader()
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 50)
    header.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    header.BorderSizePixel = 0
    header.Parent = self.mainFrame
    
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 12)
    headerCorner.Parent = header
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(0, 200, 1, 0)
    title.Position = UDim2.new(0, 20, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🌟 Social Hub"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = header
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 40, 0, 40)
    closeButton.Position = UDim2.new(1, -50, 0, 5)
    closeButton.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
    closeButton.Text = "✕"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextScaled = true
    closeButton.Font = Enum.Font.GothamBold
    closeButton.BorderSizePixel = 0
    closeButton.Parent = header
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeButton
    
    closeButton.MouseButton1Click:Connect(function()
        self:Hide()
    end)
    
    -- Online status
    local statusFrame = Instance.new("Frame")
    statusFrame.Name = "StatusFrame"
    statusFrame.Size = UDim2.new(0, 150, 0, 30)
    statusFrame.Position = UDim2.new(1, -200, 0, 10)
    statusFrame.BackgroundColor3 = Color3.fromRGB(40, 167, 69)
    statusFrame.BorderSizePixel = 0
    statusFrame.Parent = header
    
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 6)
    statusCorner.Parent = statusFrame
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "Status"
    statusLabel.Size = UDim2.new(1, 0, 1, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "🟢 Online"
    statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    statusLabel.TextScaled = true
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Parent = statusFrame
end

function SocialUI:CreateTabSystem()
    local tabContainer = Instance.new("Frame")
    tabContainer.Name = "TabContainer"
    tabContainer.Size = UDim2.new(1, 0, 0, 50)
    tabContainer.Position = UDim2.new(0, 0, 0, 50)
    tabContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    tabContainer.BorderSizePixel = 0
    tabContainer.Parent = self.mainFrame
    
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    tabLayout.Padding = UDim.new(0, 2)
    tabLayout.Parent = tabContainer
    
    local tabPadding = Instance.new("UIPadding")
    tabPadding.PaddingLeft = UDim.new(0, 10)
    tabPadding.Parent = tabContainer
    
    self.tabs = {}
    
    for tabId, tabInfo in pairs(UI_CONFIG.TABS) do
        local tab = Instance.new("TextButton")
        tab.Name = tabId .. "Tab"
        tab.Size = UDim2.new(0, 140, 0, 35)
        tab.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        tab.Text = tabInfo.Icon .. " " .. tabInfo.Name
        tab.TextColor3 = Color3.fromRGB(200, 200, 200)
        tab.TextScaled = true
        tab.Font = Enum.Font.Gotham
        tab.BorderSizePixel = 0
        tab.Parent = tabContainer
        
        local tabCorner = Instance.new("UICorner")
        tabCorner.CornerRadius = UDim.new(0, 6)
        tabCorner.Parent = tab
        
        tab.MouseButton1Click:Connect(function()
            self:SwitchTab(tabId)
        end)
        
        self.tabs[tabId] = tab
    end
end

function SocialUI:CreateContentArea()
    self.contentFrame = Instance.new("Frame")
    self.contentFrame.Name = "ContentFrame"
    self.contentFrame.Size = UDim2.new(1, 0, 1, -100)
    self.contentFrame.Position = UDim2.new(0, 0, 0, 100)
    self.contentFrame.BackgroundTransparency = 1
    self.contentFrame.Parent = self.mainFrame
    
    -- Create content for each tab
    self:CreateChatContent()
    self:CreateGuildContent()
    self:CreateTeamContent()
    self:CreateFriendContent()
    self:CreateProjectContent()
end

function SocialUI:CreateChatContent()
    local chatContent = Instance.new("Frame")
    chatContent.Name = "ChatContent"
    chatContent.Size = UDim2.new(1, 0, 1, 0)
    chatContent.BackgroundTransparency = 1
    chatContent.Visible = false
    chatContent.Parent = self.contentFrame
    
    -- Channel selector
    local channelFrame = Instance.new("Frame")
    channelFrame.Name = "ChannelFrame"
    channelFrame.Size = UDim2.new(1, 0, 0, 40)
    channelFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    channelFrame.BorderSizePixel = 0
    channelFrame.Parent = chatContent
    
    local channelLayout = Instance.new("UIListLayout")
    channelLayout.FillDirection = Enum.FillDirection.Horizontal
    channelLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    channelLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    channelLayout.Padding = UDim.new(0, 5)
    channelLayout.Parent = channelFrame
    
    local channelPadding = Instance.new("UIPadding")
    channelPadding.PaddingLeft = UDim.new(0, 10)
    channelPadding.Parent = channelFrame
    
    -- Create channel buttons
    self.channelButtons = {}
    for channelName, color in pairs(UI_CONFIG.CHAT_COLORS) do
        local channelBtn = Instance.new("TextButton")
        channelBtn.Name = channelName .. "Channel"
        channelBtn.Size = UDim2.new(0, 80, 0, 30)
        channelBtn.BackgroundColor3 = color
        channelBtn.Text = channelName
        channelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        channelBtn.TextScaled = true
        channelBtn.Font = Enum.Font.GothamBold
        channelBtn.BorderSizePixel = 0
        channelBtn.Parent = channelFrame
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 4)
        btnCorner.Parent = channelBtn
        
        channelBtn.MouseButton1Click:Connect(function()
            self:SwitchChatChannel(channelName:lower())
        end)
        
        self.channelButtons[channelName] = channelBtn
    end
    
    -- Chat history area
    local chatScroll = Instance.new("ScrollingFrame")
    chatScroll.Name = "ChatHistory"
    chatScroll.Size = UDim2.new(1, -20, 1, -90)
    chatScroll.Position = UDim2.new(0, 10, 0, 45)
    chatScroll.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    chatScroll.BorderSizePixel = 0
    chatScroll.ScrollBarThickness = 6
    chatScroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    chatScroll.Parent = chatContent
    
    local chatCorner = Instance.new("UICorner")
    chatCorner.CornerRadius = UDim.new(0, 8)
    chatCorner.Parent = chatScroll
    
    local chatLayout = Instance.new("UIListLayout")
    chatLayout.FillDirection = Enum.FillDirection.Vertical
    chatLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    chatLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    chatLayout.Padding = UDim.new(0, 5)
    chatLayout.Parent = chatScroll
    
    local chatPadding = Instance.new("UIPadding")
    chatPadding.PaddingLeft = UDim.new(0, 10)
    chatPadding.PaddingRight = UDim.new(0, 10)
    chatPadding.PaddingTop = UDim.new(0, 10)
    chatPadding.Parent = chatScroll
    
    -- Chat input area
    local inputFrame = Instance.new("Frame")
    inputFrame.Name = "InputFrame"
    inputFrame.Size = UDim2.new(1, -20, 0, 35)
    inputFrame.Position = UDim2.new(0, 10, 1, -40)
    inputFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    inputFrame.BorderSizePixel = 0
    inputFrame.Parent = chatContent
    
    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 8)
    inputCorner.Parent = inputFrame
    
    local chatInput = Instance.new("TextBox")
    chatInput.Name = "ChatInput"
    chatInput.Size = UDim2.new(1, -80, 1, -6)
    chatInput.Position = UDim2.new(0, 10, 0, 3)
    chatInput.BackgroundTransparency = 1
    chatInput.Text = ""
    chatInput.PlaceholderText = "Type your message..."
    chatInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    chatInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    chatInput.TextScaled = true
    chatInput.Font = Enum.Font.Gotham
    chatInput.TextXAlignment = Enum.TextXAlignment.Left
    chatInput.Parent = inputFrame
    
    local sendButton = Instance.new("TextButton")
    sendButton.Name = "SendButton"
    sendButton.Size = UDim2.new(0, 60, 1, -6)
    sendButton.Position = UDim2.new(1, -65, 0, 3)
    sendButton.BackgroundColor3 = Color3.fromRGB(40, 167, 69)
    sendButton.Text = "Send"
    sendButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    sendButton.TextScaled = true
    sendButton.Font = Enum.Font.GothamBold
    sendButton.BorderSizePixel = 0
    sendButton.Parent = inputFrame
    
    local sendCorner = Instance.new("UICorner")
    sendCorner.CornerRadius = UDim.new(0, 6)
    sendCorner.Parent = sendButton
    
    -- Store references
    self.chatContent = chatContent
    self.chatHistory = chatScroll
    self.chatInput = chatInput
    self.sendButton = sendButton
    
    -- Set up chat input handlers
    self:SetupChatHandlers()
end

function SocialUI:CreateGuildContent()
    local guildContent = Instance.new("Frame")
    guildContent.Name = "GuildContent"
    guildContent.Size = UDim2.new(1, 0, 1, 0)
    guildContent.BackgroundTransparency = 1
    guildContent.Visible = false
    guildContent.Parent = self.contentFrame
    
    -- Guild info panel
    local guildInfo = Instance.new("Frame")
    guildInfo.Name = "GuildInfo"
    guildInfo.Size = UDim2.new(1, -20, 0, 120)
    guildInfo.Position = UDim2.new(0, 10, 0, 10)
    guildInfo.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    guildInfo.BorderSizePixel = 0
    guildInfo.Parent = guildContent
    
    local guildCorner = Instance.new("UICorner")
    guildCorner.CornerRadius = UDim.new(0, 8)
    guildCorner.Parent = guildInfo
    
    -- Guild actions
    local actionsFrame = Instance.new("Frame")
    actionsFrame.Name = "ActionsFrame"
    actionsFrame.Size = UDim2.new(1, -20, 0, 40)
    actionsFrame.Position = UDim2.new(0, 10, 0, 140)
    actionsFrame.BackgroundTransparency = 1
    actionsFrame.Parent = guildContent
    
    local actionLayout = Instance.new("UIListLayout")
    actionLayout.FillDirection = Enum.FillDirection.Horizontal
    actionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    actionLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    actionLayout.Padding = UDim.new(0, 10)
    actionLayout.Parent = actionsFrame
    
    -- Create/Join Guild buttons
    local createGuildBtn = self:CreateActionButton("Create Guild", Color3.fromRGB(40, 167, 69))
    createGuildBtn.Parent = actionsFrame
    
    local joinGuildBtn = self:CreateActionButton("Join Guild", Color3.fromRGB(0, 123, 255))
    joinGuildBtn.Parent = actionsFrame
    
    local leaveGuildBtn = self:CreateActionButton("Leave Guild", Color3.fromRGB(220, 53, 69))
    leaveGuildBtn.Parent = actionsFrame
    
    -- Guild list
    local guildListFrame = Instance.new("Frame")
    guildListFrame.Name = "GuildListFrame"
    guildListFrame.Size = UDim2.new(1, -20, 1, -190)
    guildListFrame.Position = UDim2.new(0, 10, 0, 180)
    guildListFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    guildListFrame.BorderSizePixel = 0
    guildListFrame.Parent = guildContent
    
    local guildListCorner = Instance.new("UICorner")
    guildListCorner.CornerRadius = UDim.new(0, 8)
    guildListCorner.Parent = guildListFrame
    
    self.guildContent = guildContent
    self.guildInfo = guildInfo
end

function SocialUI:CreateTeamContent()
    local teamContent = Instance.new("Frame")
    teamContent.Name = "TeamContent"
    teamContent.Size = UDim2.new(1, 0, 1, 0)
    teamContent.BackgroundTransparency = 1
    teamContent.Visible = false
    teamContent.Parent = self.contentFrame
    
    -- Similar structure to guild content but for teams
    self.teamContent = teamContent
end

function SocialUI:CreateFriendContent()
    local friendContent = Instance.new("Frame")
    friendContent.Name = "FriendContent"
    friendContent.Size = UDim2.new(1, 0, 1, 0)
    friendContent.BackgroundTransparency = 1
    friendContent.Visible = false
    friendContent.Parent = self.contentFrame
    
    -- Friend list and management
    self.friendContent = friendContent
end

function SocialUI:CreateProjectContent()
    local projectContent = Instance.new("Frame")
    projectContent.Name = "ProjectContent"
    projectContent.Size = UDim2.new(1, 0, 1, 0)
    projectContent.BackgroundTransparency = 1
    projectContent.Visible = false
    projectContent.Parent = self.contentFrame
    
    -- Project collaboration tools
    self.projectContent = projectContent
end

function SocialUI:CreateActionButton(text, color)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 120, 0, 35)
    button.BackgroundColor3 = color
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextScaled = true
    button.Font = Enum.Font.GothamBold
    button.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    
    return button
end

function SocialUI:SetupChatHandlers()
    -- Send button click
    self.sendButton.MouseButton1Click:Connect(function()
        self:SendChatMessage()
    end)
    
    -- Enter key to send
    self.chatInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            self:SendChatMessage()
        end
    end)
end

function SocialUI:SendChatMessage()
    local message = self.chatInput.Text
    if message and message:len() > 0 then
        -- Send via SocialManager
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes then
            local sendEvent = remotes:FindFirstChild("SendChatMessage")
            if sendEvent then
                sendEvent:FireServer(self.currentChannel, message)
            end
        end
        
        self.chatInput.Text = ""
    end
end

function SocialUI:SwitchTab(tabId)
    -- Update tab appearance
    for id, tab in pairs(self.tabs) do
        if id == tabId then
            tab.BackgroundColor3 = Color3.fromRGB(100, 149, 237)
            tab.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            tab.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
            tab.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
    end
    
    -- Show/hide content
    for _, child in ipairs(self.contentFrame:GetChildren()) do
        if child:IsA("Frame") then
            child.Visible = false
        end
    end
    
    local contentMap = {
        CHAT = self.chatContent,
        GUILDS = self.guildContent,
        TEAMS = self.teamContent,
        FRIENDS = self.friendContent,
        PROJECTS = self.projectContent
    }
    
    if contentMap[tabId] then
        contentMap[tabId].Visible = true
    end
    
    self.currentTab = tabId
end

function SocialUI:SwitchChatChannel(channelName)
    self.currentChannel = channelName
    
    -- Update channel button appearance
    for name, button in pairs(self.channelButtons) do
        if name:lower() == channelName then
            button.BackgroundTransparency = 0
        else
            button.BackgroundTransparency = 0.3
        end
    end
    
    -- Load chat history for this channel
    self:LoadChatHistory(channelName)
end

function SocialUI:LoadChatHistory(channelName)
    -- Clear current history
    for _, child in ipairs(self.chatHistory:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    -- Load from social manager
    if self.socialManager and self.socialManager.chatHistory then
        local history = self.socialManager.chatHistory[channelName] or {}
        for _, message in ipairs(history) do
            self:AddChatMessage(message)
        end
    end
end

function SocialUI:AddChatMessage(messageData)
    local messageFrame = Instance.new("Frame")
    messageFrame.Size = UDim2.new(1, -20, 0, 50)
    messageFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    messageFrame.BorderSizePixel = 0
    messageFrame.Parent = self.chatHistory
    
    local msgCorner = Instance.new("UICorner")
    msgCorner.CornerRadius = UDim.new(0, 6)
    msgCorner.Parent = messageFrame
    
    -- Author label
    local authorLabel = Instance.new("TextLabel")
    authorLabel.Size = UDim2.new(0, 150, 0, 20)
    authorLabel.Position = UDim2.new(0, 10, 0, 5)
    authorLabel.BackgroundTransparency = 1
    authorLabel.Text = messageData.Author.DisplayName or messageData.Author.Name
    authorLabel.TextColor3 = Color3.fromRGB(100, 149, 237)
    authorLabel.Font = Enum.Font.GothamBold
    authorLabel.TextScaled = true
    authorLabel.TextXAlignment = Enum.TextXAlignment.Left
    authorLabel.Parent = messageFrame
    
    -- Message content
    local contentLabel = Instance.new("TextLabel")
    contentLabel.Size = UDim2.new(1, -20, 0, 25)
    contentLabel.Position = UDim2.new(0, 10, 0, 20)
    contentLabel.BackgroundTransparency = 1
    contentLabel.Text = messageData.Content
    contentLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    contentLabel.Font = Enum.Font.Gotham
    contentLabel.TextScaled = true
    contentLabel.TextXAlignment = Enum.TextXAlignment.Left
    contentLabel.TextWrapped = true
    contentLabel.Parent = messageFrame
    
    -- Auto-scroll to bottom
    self.chatHistory.CanvasPosition = Vector2.new(0, self.chatHistory.AbsoluteCanvasSize.Y)
end

function SocialUI:SetupEventHandlers()
    -- Keyboard shortcut to toggle UI (Ctrl+S for Social)
    self.connections.inputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.S and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            self:Toggle()
        elseif input.KeyCode == Enum.KeyCode.Escape and self.isVisible then
            self:Hide()
        end
    end)
end

function SocialUI:Show()
    self.isVisible = true
    self.mainFrame.Visible = true
    
    -- Animate entrance
    self.mainFrame.Position = UDim2.new(0.5, -400, 0.5, -350)
    self.mainFrame.Size = UDim2.new(0, 700, 0, 500)
    
    local tween = TweenService:Create(self.mainFrame, 
        TweenInfo.new(UI_CONFIG.ANIMATION_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {
            Position = UDim2.new(0.5, -400, 0.5, -300),
            Size = UI_CONFIG.MAIN_SIZE
        }
    )
    tween:Play()
end

function SocialUI:Hide()
    self.isVisible = false
    
    -- Animate exit
    local tween = TweenService:Create(self.mainFrame,
        TweenInfo.new(UI_CONFIG.ANIMATION_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.In),
        {
            Position = UDim2.new(0.5, -400, 0.5, -350),
            Size = UDim2.new(0, 700, 0, 500)
        }
    )
    
    tween:Play()
    tween.Completed:Connect(function()
        self.mainFrame.Visible = false
    end)
end

function SocialUI:Toggle()
    if self.isVisible then
        self:Hide()
    else
        self:Show()
    end
end

function SocialUI:UpdateSocialData(socialData)
    -- Handle updates from SocialManager
    if socialData.Type == "ChatMessage" then
        if socialData.Channel == self.currentChannel then
            self:AddChatMessage(socialData.Data)
        end
    elseif socialData.Type == "GuildCreated" or socialData.Type == "GuildJoined" then
        self:UpdateGuildInfo(socialData.Data)
    elseif socialData.Type == "TeamCreated" then
        self:UpdateTeamInfo(socialData.Data)
    end
end

function SocialUI:UpdateGuildInfo(guildData)
    -- Update guild information display
    -- Implementation for guild UI updates
end

function SocialUI:UpdateTeamInfo(teamData)
    -- Update team information display
    -- Implementation for team UI updates
end

function SocialUI:Cleanup()
    for _, connection in pairs(self.connections) do
        if connection then
            connection:Disconnect()
        end
    end
    
    if self.gui then
        self.gui:Destroy()
    end
    
    print("SocialUI: Cleaned up")
end

return SocialUI 