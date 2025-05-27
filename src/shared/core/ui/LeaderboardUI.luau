-- LeaderboardUI.luau
-- UI component for displaying player leaderboards

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LeaderboardUI = {}
LeaderboardUI.__index = LeaderboardUI

function LeaderboardUI.new()
    local self = setmetatable({}, LeaderboardUI)
    
    self.isVisible = false
    self.ui = nil
    self.currentTab = "Cash"
    self.leaderboardData = {}
    
    return self
end

function LeaderboardUI:Initialize()
    self:CreateUI()
    self:SetupKeyboardShortcuts()
    print("LeaderboardUI: Initialized")
end

function LeaderboardUI:CreateUI()
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    
    -- Remove existing UI
    local existing = playerGui:FindFirstChild("LeaderboardUI")
    if existing then existing:Destroy() end
    
    -- Main UI
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LeaderboardUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Main panel
    local mainPanel = Instance.new("Frame")
    mainPanel.Name = "MainPanel"
    mainPanel.Size = UDim2.new(0, 500, 0, 600)
    mainPanel.Position = UDim2.new(0.5, -250, 0.5, -300)
    mainPanel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    mainPanel.BorderSizePixel = 0
    mainPanel.Visible = false
    mainPanel.Parent = screenGui
    
    -- Add shadow and corner
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainPanel
    
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 20, 1, 20)
    shadow.Position = UDim2.new(0, -10, 0, -10)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://5554236805"
    shadow.ImageColor3 = Color3.new(0, 0, 0)
    shadow.ImageTransparency = 0.7
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(23, 23, 277, 277)
    shadow.ZIndex = -1
    shadow.Parent = mainPanel
    
    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 60)
    titleBar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainPanel
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 1, 0)
    title.Position = UDim2.new(0, 20, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🏆 Leaderboards"
    title.TextColor3 = Color3.fromRGB(255, 215, 0)
    title.TextSize = 24
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 40, 0, 40)
    closeBtn.Position = UDim2.new(1, -50, 0, 10)
    closeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.TextSize = 18
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = titleBar
    
    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 8)
    closeBtnCorner.Parent = closeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        self:Hide()
    end)
    
    -- Tab buttons
    local tabFrame = Instance.new("Frame")
    tabFrame.Size = UDim2.new(1, -20, 0, 50)
    tabFrame.Position = UDim2.new(0, 10, 0, 70)
    tabFrame.BackgroundTransparency = 1
    tabFrame.Parent = mainPanel
    
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Padding = UDim.new(0, 5)
    tabLayout.Parent = tabFrame
    
    local tabs = {
        {name = "Cash", icon = "💰", color = Color3.fromRGB(255, 215, 0)},
        {name = "ItemsPlaced", icon = "🔨", color = Color3.fromRGB(100, 200, 100)},
        {name = "Level", icon = "⭐", color = Color3.fromRGB(100, 150, 255)},
        {name = "TotalXP", icon = "📈", color = Color3.fromRGB(255, 100, 100)},
        {name = "PlayTime", icon = "⏱️", color = Color3.fromRGB(200, 100, 255)}
    }
    
    self.tabButtons = {}
    for i, tab in ipairs(tabs) do
        local btn = self:CreateTabButton(tab, i == 1)
        btn.Parent = tabFrame
        btn.MouseButton1Click:Connect(function()
            self:SwitchTab(tab.name)
        end)
        self.tabButtons[tab.name] = btn
    end
    
    -- Content area
    local contentFrame = Instance.new("ScrollingFrame")
    contentFrame.Name = "ContentFrame"
    contentFrame.Size = UDim2.new(1, -20, 1, -140)
    contentFrame.Position = UDim2.new(0, 10, 0, 130)
    contentFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    contentFrame.BorderSizePixel = 0
    contentFrame.ScrollBarThickness = 8
    contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    contentFrame.Parent = mainPanel
    
    local contentCorner = Instance.new("UICorner")
    contentCorner.CornerRadius = UDim.new(0, 8)
    contentCorner.Parent = contentFrame
    
    local contentLayout = Instance.new("UIListLayout")
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    contentLayout.Padding = UDim.new(0, 2)
    contentLayout.Parent = contentFrame
    
    -- Toggle button
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 140, 0, 45)
    toggleBtn.Position = UDim2.new(1, -160, 0, 20)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    toggleBtn.Text = "🏆 Leaderboard"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 215, 0)
    toggleBtn.TextSize = 16
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.Parent = screenGui
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 8)
    toggleCorner.Parent = toggleBtn
    
    local toggleStroke = Instance.new("UIStroke")
    toggleStroke.Thickness = 2
    toggleStroke.Color = Color3.fromRGB(255, 215, 0)
    toggleStroke.Transparency = 0.8
    toggleStroke.Parent = toggleBtn
    
    toggleBtn.MouseButton1Click:Connect(function()
        self:Toggle()
    end)
    
    -- Hover effect for toggle
    toggleBtn.MouseEnter:Connect(function()
        TweenService:Create(toggleBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        }):Play()
        TweenService:Create(toggleStroke, TweenInfo.new(0.2), {
            Transparency = 0.4
        }):Play()
    end)
    
    toggleBtn.MouseLeave:Connect(function()
        TweenService:Create(toggleBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        }):Play()
        TweenService:Create(toggleStroke, TweenInfo.new(0.2), {
            Transparency = 0.8
        }):Play()
    end)
    
    self.ui = screenGui
end

function LeaderboardUI:CreateTabButton(tab, isActive)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 90, 1, 0)
    btn.BackgroundColor3 = isActive and tab.color or Color3.fromRGB(60, 60, 60)
    btn.Text = tab.icon .. "\n" .. tab.name
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    
    -- Store tab data
    btn:SetAttribute("TabName", tab.name)
    btn:SetAttribute("TabColor", tab.color.R .. "," .. tab.color.G .. "," .. tab.color.B)
    
    return btn
end

function LeaderboardUI:SwitchTab(tabName)
    self.currentTab = tabName
    
    -- Update tab button appearances
    for name, button in pairs(self.tabButtons) do
        local colorStr = button:GetAttribute("TabColor")
        local r, g, b = colorStr:match("([^,]+),([^,]+),([^,]+)")
        local tabColor = Color3.new(tonumber(r), tonumber(g), tonumber(b))
        
        if name == tabName then
            button.BackgroundColor3 = tabColor
        else
            button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        end
    end
    
    -- Update leaderboard display
    self:UpdateLeaderboard(tabName, self.leaderboardData[tabName] or {})
end

function LeaderboardUI:UpdateLeaderboard(statName, data)
    if not self.ui then return end
    
    -- Store the data
    self.leaderboardData[statName] = data
    
    -- Only update display if this is the current tab
    if statName ~= self.currentTab then return end
    
    local contentFrame = self.ui.MainPanel.ContentFrame
    
    -- Clear existing entries
    for _, child in ipairs(contentFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    -- Create new entries
    for i, entry in ipairs(data) do
        local entryFrame = self:CreateLeaderboardEntry(entry, i)
        entryFrame.Parent = contentFrame
    end
    
    -- Update canvas size
    local layout = contentFrame:FindFirstChild("UIListLayout")
    if layout then
        contentFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
    end
end

function LeaderboardUI:CreateLeaderboardEntry(entry, rank)
    local entryFrame = Instance.new("Frame")
    entryFrame.Name = "Entry" .. rank
    entryFrame.Size = UDim2.new(1, -10, 0, 50)
    entryFrame.LayoutOrder = rank
    
    -- Color based on rank
    local bgColor = Color3.fromRGB(45, 45, 45)
    if rank == 1 then
        bgColor = Color3.fromRGB(70, 50, 20) -- Gold tint
    elseif rank == 2 then
        bgColor = Color3.fromRGB(50, 50, 50) -- Silver tint
    elseif rank == 3 then
        bgColor = Color3.fromRGB(60, 45, 30) -- Bronze tint
    end
    
    entryFrame.BackgroundColor3 = bgColor
    entryFrame.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = entryFrame
    
    -- Rank number/medal
    local rankLabel = Instance.new("TextLabel")
    rankLabel.Size = UDim2.new(0, 50, 1, 0)
    rankLabel.Position = UDim2.new(0, 10, 0, 0)
    rankLabel.BackgroundTransparency = 1
    rankLabel.Font = Enum.Font.GothamBold
    rankLabel.TextSize = 18
    rankLabel.TextXAlignment = Enum.TextXAlignment.Center
    rankLabel.Parent = entryFrame
    
    if rank == 1 then
        rankLabel.Text = "🥇"
        rankLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    elseif rank == 2 then
        rankLabel.Text = "🥈"
        rankLabel.TextColor3 = Color3.fromRGB(192, 192, 192)
    elseif rank == 3 then
        rankLabel.Text = "🥉"
        rankLabel.TextColor3 = Color3.fromRGB(205, 127, 50)
    else
        rankLabel.Text = "#" .. rank
        rankLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    end
    
    -- Player name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0, 200, 1, 0)
    nameLabel.Position = UDim2.new(0, 70, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = entry.DisplayName or entry.Name
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.TextSize = 16
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = entryFrame
    
    -- Value
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0, 150, 1, 0)
    valueLabel.Position = UDim2.new(1, -160, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    valueLabel.TextSize = 16
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = entryFrame
    
    -- Format value based on stat type
    local formattedValue = self:FormatStatValue(self.currentTab, entry.Value)
    valueLabel.Text = formattedValue
    
    return entryFrame
end

function LeaderboardUI:FormatStatValue(statType, value)
    if statType == "Cash" then
        if value >= 1000000 then
            return string.format("💰 %.1fM", value / 1000000)
        elseif value >= 1000 then
            return string.format("💰 %.1fK", value / 1000)
        else
            return "💰 " .. tostring(value)
        end
    elseif statType == "ItemsPlaced" then
        return "🔨 " .. tostring(value)
    elseif statType == "Level" then
        return "⭐ " .. tostring(value)
    elseif statType == "TotalXP" then
        if value >= 1000 then
            return string.format("📈 %.1fK XP", value / 1000)
        else
            return "📈 " .. tostring(value) .. " XP"
        end
    elseif statType == "PlayTime" then
        local hours = math.floor(value / 3600)
        local minutes = math.floor((value % 3600) / 60)
        if hours > 0 then
            return string.format("⏱️ %dh %dm", hours, minutes)
        else
            return string.format("⏱️ %dm", minutes)
        end
    else
        return tostring(value)
    end
end

function LeaderboardUI:SetupKeyboardShortcuts()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.L and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            self:Toggle()
        end
    end)
end

function LeaderboardUI:Show()
    if not self.ui then return end
    
    local panel = self.ui.MainPanel
    panel.Visible = true
    panel.Size = UDim2.new(0, 0, 0, 0)
    panel.Position = UDim2.new(0.5, 0, 0.5, 0)
    
    local tween = TweenService:Create(panel, TweenInfo.new(0.4, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, 500, 0, 600),
        Position = UDim2.new(0.5, -250, 0.5, -300)
    })
    tween:Play()
    
    self.isVisible = true
end

function LeaderboardUI:Hide()
    if not self.ui then return end
    
    local panel = self.ui.MainPanel
    local tween = TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0)
    })
    tween.Completed:Connect(function()
        panel.Visible = false
    end)
    tween:Play()
    
    self.isVisible = false
end

function LeaderboardUI:Toggle()
    if self.isVisible then
        self:Hide()
    else
        self:Show()
    end
end

function LeaderboardUI:Destroy()
    if self.ui then
        self.ui:Destroy()
        self.ui = nil
    end
end

return LeaderboardUI 