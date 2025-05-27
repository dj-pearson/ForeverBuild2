-- AdminDashboard.luau
-- Enterprise-level admin monitoring dashboard for security and system oversight
-- Provides real-time monitoring of exploits, rate limits, and system health

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- Import security modules
local SecurityValidator
local RateLimiter
local ExploitDetector
local BehaviorAnalyzer

local function loadSecurityModules()
    local success, result = pcall(function()
        SecurityValidator = require(ReplicatedStorage.src.shared.security.SecurityValidator)
        RateLimiter = require(ReplicatedStorage.src.shared.security.RateLimiter)
        ExploitDetector = require(ReplicatedStorage.src.shared.security.ExploitDetector)
        BehaviorAnalyzer = require(ReplicatedStorage.src.shared.security.BehaviorAnalyzer)
        return true
    end)
    
    if success then
        print("[AdminDashboard] Security modules loaded successfully")
        return true
    else
        warn("[AdminDashboard] Failed to load security modules:", result)
        return false
    end
end

loadSecurityModules()

local AdminDashboard = {}
AdminDashboard.__index = AdminDashboard

-- Configuration
local CONFIG = {
    UPDATE_INTERVAL = 1.0, -- Update every second
    CHART_HISTORY_LENGTH = 60, -- Keep 60 data points for charts
    ALERT_THRESHOLD_VIOLATIONS = 5, -- Alert after 5 violations
    ALERT_THRESHOLD_RATE_LIMIT = 10, -- Alert after 10 rate limit hits
    DASHBOARD_SIZE = UDim2.new(0, 1200, 0, 800),
    PANEL_PADDING = 10,
    ANIMATION_DURATION = 0.3
}

-- Color scheme
local COLORS = {
    BACKGROUND = Color3.fromRGB(25, 25, 35),
    PANEL = Color3.fromRGB(35, 35, 45),
    ACCENT = Color3.fromRGB(0, 170, 255),
    SUCCESS = Color3.fromRGB(0, 200, 100),
    WARNING = Color3.fromRGB(255, 200, 0),
    ERROR = Color3.fromRGB(255, 100, 100),
    TEXT = Color3.fromRGB(255, 255, 255),
    TEXT_SECONDARY = Color3.fromRGB(180, 180, 180)
}

function AdminDashboard.new()
    local self = setmetatable({}, AdminDashboard)
    
    -- Core properties
    self.player = Players.LocalPlayer
    self.isVisible = false
    self.isAdmin = false
    
    -- UI components
    self.gui = nil
    self.mainFrame = nil
    self.panels = {}
    
    -- Data tracking
    self.securityData = {
        violations = {},
        rateLimits = {},
        exploitAttempts = {},
        systemHealth = {}
    }
    
    -- Chart data
    self.chartData = {
        violations = {},
        rateLimits = {},
        exploits = {},
        performance = {}
    }
    
    -- Connections
    self.connections = {}
    
    -- Update timer
    self.lastUpdate = 0
    
    return self
end

function AdminDashboard:Initialize()
    print("[AdminDashboard] Initializing admin monitoring dashboard...")
    
    -- Check admin permissions
    if not self:IsPlayerAdmin() then
        warn("[AdminDashboard] Player is not an admin")
        return false
    end
    
    self.isAdmin = true
    
    -- Create UI
    self:CreateUI()
    
    -- Setup input handling
    self:SetupInputHandling()
    
    -- Start update loop
    self:StartUpdateLoop()
    
    -- Setup remote events for server data
    self:SetupRemoteEvents()
    
    print("[AdminDashboard] Admin dashboard initialized successfully")
    return true
end

function AdminDashboard:IsPlayerAdmin()
    -- Check if player is admin
    local adminIds = {
        3246397734, -- Default Roblox test account ID
        7768610061  -- Your actual user ID (Xdjpearsonx)
    }
    
    for _, adminId in ipairs(adminIds) do
        if self.player.UserId == adminId then
            return true
        end
    end
    
    return self.player:GetAttribute("IsAdmin") == true
end

function AdminDashboard:CreateUI()
    -- Create main ScreenGui
    self.gui = Instance.new("ScreenGui")
    self.gui.Name = "AdminDashboard"
    self.gui.ResetOnSpawn = false
    self.gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self.gui.Parent = self.player.PlayerGui
    
    -- Main frame
    self.mainFrame = Instance.new("Frame")
    self.mainFrame.Name = "MainFrame"
    self.mainFrame.Size = CONFIG.DASHBOARD_SIZE
    self.mainFrame.Position = UDim2.new(0.5, -CONFIG.DASHBOARD_SIZE.X.Offset/2, 0.5, -CONFIG.DASHBOARD_SIZE.Y.Offset/2)
    self.mainFrame.BackgroundColor3 = COLORS.BACKGROUND
    self.mainFrame.BorderSizePixel = 0
    self.mainFrame.Visible = false
    self.mainFrame.Parent = self.gui
    
    -- Add corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = self.mainFrame
    
    -- Add drop shadow effect
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 20, 1, 20)
    shadow.Position = UDim2.new(0, -10, 0, -10)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxasset://textures/ui/Controls/DropShadow.png"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.5
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(12, 12, 12, 12)
    shadow.ZIndex = -1
    shadow.Parent = self.mainFrame
    
    -- Title bar
    self:CreateTitleBar()
    
    -- Create panels
    self:CreateSecurityOverviewPanel()
    self:CreateRateLimitingPanel()
    self:CreateExploitDetectionPanel()
    self:CreateSystemHealthPanel()
    self:CreatePlayerMonitoringPanel()
    self:CreateAlertsPanel()
    
    print("[AdminDashboard] UI created successfully")
end

function AdminDashboard:CreateTitleBar()
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundColor3 = COLORS.PANEL
    titleBar.BorderSizePixel = 0
    titleBar.Parent = self.mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar
    
    -- Title text
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(0, 300, 1, 0)
    title.Position = UDim2.new(0, 20, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🛡️ Admin Security Dashboard"
    title.TextColor3 = COLORS.TEXT
    title.TextSize = 24
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    -- Status indicator
    local statusFrame = Instance.new("Frame")
    statusFrame.Name = "StatusFrame"
    statusFrame.Size = UDim2.new(0, 150, 0, 30)
    statusFrame.Position = UDim2.new(1, -170, 0.5, -15)
    statusFrame.BackgroundColor3 = COLORS.SUCCESS
    statusFrame.BorderSizePixel = 0
    statusFrame.Parent = titleBar
    
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 15)
    statusCorner.Parent = statusFrame
    
    local statusText = Instance.new("TextLabel")
    statusText.Name = "StatusText"
    statusText.Size = UDim2.new(1, 0, 1, 0)
    statusText.BackgroundTransparency = 1
    statusText.Text = "🟢 SECURE"
    statusText.TextColor3 = COLORS.TEXT
    statusText.TextSize = 14
    statusText.Font = Enum.Font.GothamBold
    statusText.Parent = statusFrame
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -40, 0.5, -15)
    closeButton.BackgroundColor3 = COLORS.ERROR
    closeButton.Text = "✕"
    closeButton.TextColor3 = COLORS.TEXT
    closeButton.TextSize = 18
    closeButton.Font = Enum.Font.GothamBold
    closeButton.BorderSizePixel = 0
    closeButton.Parent = titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 15)
    closeCorner.Parent = closeButton
    
    closeButton.MouseButton1Click:Connect(function()
        self:Hide()
    end)
    
    self.panels.titleBar = titleBar
end

function AdminDashboard:CreateSecurityOverviewPanel()
    local panel = self:CreatePanel("SecurityOverview", "🔒 Security Overview", UDim2.new(0.33, -7, 0.4, -5), UDim2.new(0, 10, 0, 60))
    
    -- Metrics grid
    local metricsFrame = Instance.new("Frame")
    metricsFrame.Name = "MetricsFrame"
    metricsFrame.Size = UDim2.new(1, -20, 1, -40)
    metricsFrame.Position = UDim2.new(0, 10, 0, 30)
    metricsFrame.BackgroundTransparency = 1
    metricsFrame.Parent = panel
    
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0.5, -5, 0.5, -5)
    gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
    gridLayout.Parent = metricsFrame
    
    -- Create metric cards
    local metrics = {
        {name = "Total Violations", value = "0", color = COLORS.ERROR},
        {name = "Rate Limits Hit", value = "0", color = COLORS.WARNING},
        {name = "Exploit Attempts", value = "0", color = COLORS.ERROR},
        {name = "System Health", value = "100%", color = COLORS.SUCCESS}
    }
    
    for _, metric in ipairs(metrics) do
        local card = self:CreateMetricCard(metric.name, metric.value, metric.color)
        card.Parent = metricsFrame
    end
    
    self.panels.securityOverview = panel
end

function AdminDashboard:CreateRateLimitingPanel()
    local panel = self:CreatePanel("RateLimiting", "⏱️ Rate Limiting", UDim2.new(0.33, -7, 0.4, -5), UDim2.new(0.33, 3, 0, 60))
    
    -- Rate limiting statistics
    local statsFrame = Instance.new("ScrollingFrame")
    statsFrame.Name = "StatsFrame"
    statsFrame.Size = UDim2.new(1, -20, 1, -40)
    statsFrame.Position = UDim2.new(0, 10, 0, 30)
    statsFrame.BackgroundTransparency = 1
    statsFrame.BorderSizePixel = 0
    statsFrame.ScrollBarThickness = 6
    statsFrame.ScrollBarImageColor3 = COLORS.ACCENT
    statsFrame.Parent = panel
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 5)
    listLayout.Parent = statsFrame
    
    self.panels.rateLimiting = panel
end

function AdminDashboard:CreateExploitDetectionPanel()
    local panel = self:CreatePanel("ExploitDetection", "🚨 Exploit Detection", UDim2.new(0.33, -7, 0.4, -5), UDim2.new(0.66, -3, 0, 60))
    
    -- Recent exploits list
    local exploitsFrame = Instance.new("ScrollingFrame")
    exploitsFrame.Name = "ExploitsFrame"
    exploitsFrame.Size = UDim2.new(1, -20, 1, -40)
    exploitsFrame.Position = UDim2.new(0, 10, 0, 30)
    exploitsFrame.BackgroundTransparency = 1
    exploitsFrame.BorderSizePixel = 0
    exploitsFrame.ScrollBarThickness = 6
    exploitsFrame.ScrollBarImageColor3 = COLORS.ACCENT
    exploitsFrame.Parent = panel
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 3)
    listLayout.Parent = exploitsFrame
    
    self.panels.exploitDetection = panel
end

function AdminDashboard:CreateSystemHealthPanel()
    local panel = self:CreatePanel("SystemHealth", "💚 System Health", UDim2.new(0.5, -7, 0.4, -5), UDim2.new(0, 10, 0.4, 15))
    
    -- Health metrics
    local healthFrame = Instance.new("Frame")
    healthFrame.Name = "HealthFrame"
    healthFrame.Size = UDim2.new(1, -20, 1, -40)
    healthFrame.Position = UDim2.new(0, 10, 0, 30)
    healthFrame.BackgroundTransparency = 1
    healthFrame.Parent = panel
    
    -- Performance chart placeholder
    local chartFrame = Instance.new("Frame")
    chartFrame.Name = "ChartFrame"
    chartFrame.Size = UDim2.new(1, 0, 0.7, 0)
    chartFrame.Position = UDim2.new(0, 0, 0, 0)
    chartFrame.BackgroundColor3 = COLORS.BACKGROUND
    chartFrame.BorderSizePixel = 0
    chartFrame.Parent = healthFrame
    
    local chartCorner = Instance.new("UICorner")
    chartCorner.CornerRadius = UDim.new(0, 8)
    chartCorner.Parent = chartFrame
    
    local chartLabel = Instance.new("TextLabel")
    chartLabel.Size = UDim2.new(1, 0, 1, 0)
    chartLabel.BackgroundTransparency = 1
    chartLabel.Text = "📊 Performance Chart\n(Real-time monitoring)"
    chartLabel.TextColor3 = COLORS.TEXT_SECONDARY
    chartLabel.TextSize = 16
    chartLabel.Font = Enum.Font.Gotham
    chartLabel.Parent = chartFrame
    
    self.panels.systemHealth = panel
end

function AdminDashboard:CreatePlayerMonitoringPanel()
    local panel = self:CreatePanel("PlayerMonitoring", "👥 Player Monitoring", UDim2.new(0.5, -7, 0.4, -5), UDim2.new(0.5, 3, 0.4, 15))
    
    -- Player list
    local playersFrame = Instance.new("ScrollingFrame")
    playersFrame.Name = "PlayersFrame"
    playersFrame.Size = UDim2.new(1, -20, 1, -40)
    playersFrame.Position = UDim2.new(0, 10, 0, 30)
    playersFrame.BackgroundTransparency = 1
    playersFrame.BorderSizePixel = 0
    playersFrame.ScrollBarThickness = 6
    playersFrame.ScrollBarImageColor3 = COLORS.ACCENT
    playersFrame.Parent = panel
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 3)
    listLayout.Parent = playersFrame
    
    self.panels.playerMonitoring = panel
end

function AdminDashboard:CreateAlertsPanel()
    local panel = self:CreatePanel("Alerts", "🚨 Security Alerts", UDim2.new(1, -20, 0.2, -5), UDim2.new(0, 10, 0.8, 10))
    
    -- Alerts list
    local alertsFrame = Instance.new("ScrollingFrame")
    alertsFrame.Name = "AlertsFrame"
    alertsFrame.Size = UDim2.new(1, -20, 1, -40)
    alertsFrame.Position = UDim2.new(0, 10, 0, 30)
    alertsFrame.BackgroundTransparency = 1
    alertsFrame.BorderSizePixel = 0
    alertsFrame.ScrollBarThickness = 6
    alertsFrame.ScrollBarImageColor3 = COLORS.ACCENT
    alertsFrame.Parent = panel
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 3)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = alertsFrame
    
    self.panels.alerts = panel
end

function AdminDashboard:CreatePanel(name, title, size, position)
    local panel = Instance.new("Frame")
    panel.Name = name
    panel.Size = size
    panel.Position = position
    panel.BackgroundColor3 = COLORS.PANEL
    panel.BorderSizePixel = 0
    panel.Parent = self.mainFrame
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = panel
    
    -- Panel title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, -20, 0, 25)
    titleLabel.Position = UDim2.new(0, 10, 0, 5)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = COLORS.TEXT
    titleLabel.TextSize = 16
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = panel
    
    return panel
end

function AdminDashboard:CreateMetricCard(name, value, color)
    local card = Instance.new("Frame")
    card.Name = name:gsub(" ", "")
    card.BackgroundColor3 = COLORS.BACKGROUND
    card.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = card
    
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Name = "Value"
    valueLabel.Size = UDim2.new(1, 0, 0.6, 0)
    valueLabel.Position = UDim2.new(0, 0, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = value
    valueLabel.TextColor3 = color
    valueLabel.TextSize = 24
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.Parent = card
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.Size = UDim2.new(1, -10, 0.4, 0)
    nameLabel.Position = UDim2.new(0, 5, 0.6, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = name
    nameLabel.TextColor3 = COLORS.TEXT_SECONDARY
    nameLabel.TextSize = 12
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextWrapped = true
    nameLabel.Parent = card
    
    return card
end

function AdminDashboard:SetupInputHandling()
    -- Toggle dashboard with F9 key
    local connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.F9 and self.isAdmin then
            self:Toggle()
        end
    end)
    table.insert(self.connections, connection)
end

function AdminDashboard:SetupRemoteEvents()
    -- Setup remote events to receive server-side security data
    -- This would connect to server-side security monitoring
    print("[AdminDashboard] Remote events setup (placeholder)")
end

function AdminDashboard:StartUpdateLoop()
    local connection = RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        
        if currentTime - self.lastUpdate >= CONFIG.UPDATE_INTERVAL then
            if self.isVisible then
                self:UpdateDashboard()
            end
            self.lastUpdate = currentTime
        end
    end)
    table.insert(self.connections, connection)
end

function AdminDashboard:UpdateDashboard()
    -- Update security overview
    self:UpdateSecurityOverview()
    
    -- Update rate limiting panel
    self:UpdateRateLimitingPanel()
    
    -- Update exploit detection
    self:UpdateExploitDetectionPanel()
    
    -- Update system health
    self:UpdateSystemHealthPanel()
    
    -- Update player monitoring
    self:UpdatePlayerMonitoringPanel()
    
    -- Update alerts
    self:UpdateAlertsPanel()
end

function AdminDashboard:UpdateSecurityOverview()
    local panel = self.panels.securityOverview
    if not panel then return end
    
    local metricsFrame = panel:FindFirstChild("MetricsFrame")
    if not metricsFrame then return end
    
    -- Update metric values (placeholder data)
    local totalViolations = metricsFrame:FindFirstChild("TotalViolations")
    if totalViolations then
        local valueLabel = totalViolations:FindFirstChild("Value")
        if valueLabel then
            valueLabel.Text = tostring(math.random(0, 15))
        end
    end
    
    local rateLimitsHit = metricsFrame:FindFirstChild("RateLimitsHit")
    if rateLimitsHit then
        local valueLabel = rateLimitsHit:FindFirstChild("Value")
        if valueLabel then
            valueLabel.Text = tostring(math.random(0, 25))
        end
    end
    
    local exploitAttempts = metricsFrame:FindFirstChild("ExploitAttempts")
    if exploitAttempts then
        local valueLabel = exploitAttempts:FindFirstChild("Value")
        if valueLabel then
            valueLabel.Text = tostring(math.random(0, 5))
        end
    end
    
    local systemHealth = metricsFrame:FindFirstChild("SystemHealth")
    if systemHealth then
        local valueLabel = systemHealth:FindFirstChild("Value")
        if valueLabel then
            valueLabel.Text = tostring(math.random(95, 100)) .. "%"
        end
    end
end

function AdminDashboard:UpdateRateLimitingPanel()
    -- Update rate limiting statistics
    local panel = self.panels.rateLimiting
    if not panel then return end
    
    local statsFrame = panel:FindFirstChild("StatsFrame")
    if not statsFrame then return end
    
    -- Clear existing entries
    for _, child in ipairs(statsFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    -- Add current rate limiting stats
    local endpoints = {"PlaceItem", "PurchaseItem", "GetInventory", "OnItemClicked"}
    
    for i, endpoint in ipairs(endpoints) do
        local statEntry = self:CreateStatEntry(endpoint, math.random(0, 50), math.random(0, 10))
        statEntry.LayoutOrder = i
        statEntry.Parent = statsFrame
    end
    
    -- Update canvas size
    statsFrame.CanvasSize = UDim2.new(0, 0, 0, #endpoints * 35)
end

function AdminDashboard:UpdateExploitDetectionPanel()
    -- Update exploit detection data
    local panel = self.panels.exploitDetection
    if not panel then return end
    
    local exploitsFrame = panel:FindFirstChild("ExploitsFrame")
    if not exploitsFrame then return end
    
    -- Add recent exploit attempts (simulated)
    if math.random() < 0.1 then -- 10% chance to add new exploit attempt
        local exploitTypes = {"Speed Hack", "Teleportation", "Duplication", "Invalid Input"}
        local players = Players:GetPlayers()
        
        if #players > 0 then
            local randomPlayer = players[math.random(1, #players)]
            local exploitType = exploitTypes[math.random(1, #exploitTypes)]
            
            local exploitEntry = self:CreateExploitEntry(randomPlayer.Name, exploitType, tick())
            exploitEntry.Parent = exploitsFrame
            
            -- Limit to 10 entries
            local children = exploitsFrame:GetChildren()
            if #children > 10 then
                children[1]:Destroy()
            end
            
            exploitsFrame.CanvasSize = UDim2.new(0, 0, 0, #children * 30)
        end
    end
end

function AdminDashboard:UpdateSystemHealthPanel()
    -- Update system health metrics
    local panel = self.panels.systemHealth
    if not panel then return end
    
    -- Update performance data (placeholder)
    table.insert(self.chartData.performance, {
        time = tick(),
        value = math.random(90, 100)
    })
    
    -- Keep only recent data
    if #self.chartData.performance > CONFIG.CHART_HISTORY_LENGTH then
        table.remove(self.chartData.performance, 1)
    end
end

function AdminDashboard:UpdatePlayerMonitoringPanel()
    -- Update player monitoring
    local panel = self.panels.playerMonitoring
    if not panel then return end
    
    local playersFrame = panel:FindFirstChild("PlayersFrame")
    if not playersFrame then return end
    
    -- Clear existing entries
    for _, child in ipairs(playersFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    -- Add current players
    local players = Players:GetPlayers()
    
    for i, player in ipairs(players) do
        local playerEntry = self:CreatePlayerEntry(player)
        playerEntry.LayoutOrder = i
        playerEntry.Parent = playersFrame
    end
    
    playersFrame.CanvasSize = UDim2.new(0, 0, 0, #players * 40)
end

function AdminDashboard:UpdateAlertsPanel()
    -- Update security alerts
    local panel = self.panels.alerts
    if not panel then return end
    
    local alertsFrame = panel:FindFirstChild("AlertsFrame")
    if not alertsFrame then return end
    
    -- Add new alerts based on thresholds
    if math.random() < 0.05 then -- 5% chance for new alert
        local alertTypes = {
            {text = "🚨 High rate limit violations detected", color = COLORS.ERROR},
            {text = "⚠️ Suspicious player behavior observed", color = COLORS.WARNING},
            {text = "🔒 Security validation blocked malicious request", color = COLORS.SUCCESS}
        }
        
        local alert = alertTypes[math.random(1, #alertTypes)]
        local alertEntry = self:CreateAlertEntry(alert.text, alert.color, tick())
        alertEntry.Parent = alertsFrame
        
        -- Limit to 20 alerts
        local children = alertsFrame:GetChildren()
        if #children > 20 then
            children[1]:Destroy()
        end
        
        alertsFrame.CanvasSize = UDim2.new(0, 0, 0, #children * 25)
    end
end

function AdminDashboard:CreateStatEntry(endpoint, requests, blocked)
    local entry = Instance.new("Frame")
    entry.Name = endpoint
    entry.Size = UDim2.new(1, 0, 0, 30)
    entry.BackgroundColor3 = COLORS.BACKGROUND
    entry.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = entry
    
    local endpointLabel = Instance.new("TextLabel")
    endpointLabel.Size = UDim2.new(0.5, 0, 1, 0)
    endpointLabel.Position = UDim2.new(0, 5, 0, 0)
    endpointLabel.BackgroundTransparency = 1
    endpointLabel.Text = endpoint
    endpointLabel.TextColor3 = COLORS.TEXT
    endpointLabel.TextSize = 12
    endpointLabel.Font = Enum.Font.Gotham
    endpointLabel.TextXAlignment = Enum.TextXAlignment.Left
    endpointLabel.Parent = entry
    
    local statsLabel = Instance.new("TextLabel")
    statsLabel.Size = UDim2.new(0.5, -5, 1, 0)
    statsLabel.Position = UDim2.new(0.5, 0, 0, 0)
    statsLabel.BackgroundTransparency = 1
    statsLabel.Text = string.format("%d req, %d blocked", requests, blocked)
    statsLabel.TextColor3 = blocked > 0 and COLORS.WARNING or COLORS.SUCCESS
    statsLabel.TextSize = 12
    statsLabel.Font = Enum.Font.Gotham
    statsLabel.TextXAlignment = Enum.TextXAlignment.Right
    statsLabel.Parent = entry
    
    return entry
end

function AdminDashboard:CreateExploitEntry(playerName, exploitType, timestamp)
    local entry = Instance.new("Frame")
    entry.Size = UDim2.new(1, 0, 0, 25)
    entry.BackgroundColor3 = COLORS.ERROR
    entry.BackgroundTransparency = 0.8
    entry.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = entry
    
    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, -10, 1, 0)
    text.Position = UDim2.new(0, 5, 0, 0)
    text.BackgroundTransparency = 1
    text.Text = string.format("🚨 %s: %s (%s)", playerName, exploitType, os.date("%H:%M:%S", timestamp))
    text.TextColor3 = COLORS.TEXT
    text.TextSize = 11
    text.Font = Enum.Font.Gotham
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.Parent = entry
    
    return entry
end

function AdminDashboard:CreatePlayerEntry(player)
    local entry = Instance.new("Frame")
    entry.Name = player.Name
    entry.Size = UDim2.new(1, 0, 0, 35)
    entry.BackgroundColor3 = COLORS.BACKGROUND
    entry.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = entry
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0.4, 0, 1, 0)
    nameLabel.Position = UDim2.new(0, 5, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.Name
    nameLabel.TextColor3 = COLORS.TEXT
    nameLabel.TextSize = 12
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = entry
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0.6, -5, 1, 0)
    statusLabel.Position = UDim2.new(0.4, 0, 0, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "🟢 Normal"
    statusLabel.TextColor3 = COLORS.SUCCESS
    statusLabel.TextSize = 11
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextXAlignment = Enum.TextXAlignment.Right
    statusLabel.Parent = entry
    
    return entry
end

function AdminDashboard:CreateAlertEntry(text, color, timestamp)
    local entry = Instance.new("Frame")
    entry.Size = UDim2.new(1, 0, 0, 20)
    entry.BackgroundTransparency = 1
    entry.BorderSizePixel = 0
    
    local alertText = Instance.new("TextLabel")
    alertText.Size = UDim2.new(1, -10, 1, 0)
    alertText.Position = UDim2.new(0, 5, 0, 0)
    alertText.BackgroundTransparency = 1
    alertText.Text = string.format("[%s] %s", os.date("%H:%M:%S", timestamp), text)
    alertText.TextColor3 = color
    alertText.TextSize = 11
    alertText.Font = Enum.Font.Gotham
    alertText.TextXAlignment = Enum.TextXAlignment.Left
    alertText.Parent = entry
    
    return entry
end

function AdminDashboard:Show()
    if not self.isAdmin then return end
    
    self.mainFrame.Visible = true
    self.isVisible = true
    
    -- Animate in
    self.mainFrame.Size = UDim2.new(0, 0, 0, 0)
    local showTween = TweenService:Create(self.mainFrame, TweenInfo.new(CONFIG.ANIMATION_DURATION), {
        Size = CONFIG.DASHBOARD_SIZE
    })
    showTween:Play()
    
    print("[AdminDashboard] Dashboard shown")
end

function AdminDashboard:Hide()
    if not self.isVisible then return end
    
    local hideTween = TweenService:Create(self.mainFrame, TweenInfo.new(CONFIG.ANIMATION_DURATION), {
        Size = UDim2.new(0, 0, 0, 0)
    })
    
    hideTween.Completed:Connect(function()
        self.mainFrame.Visible = false
    end)
    
    hideTween:Play()
    self.isVisible = false
    
    print("[AdminDashboard] Dashboard hidden")
end

function AdminDashboard:Toggle()
    if self.isVisible then
        self:Hide()
    else
        self:Show()
    end
end

function AdminDashboard:Cleanup()
    print("[AdminDashboard] Cleaning up...")
    
    -- Disconnect all connections
    for _, connection in ipairs(self.connections) do
        if connection then
            connection:Disconnect()
        end
    end
    self.connections = {}
    
    -- Destroy UI
    if self.gui then
        self.gui:Destroy()
    end
    
    print("[AdminDashboard] Cleanup complete")
end

return AdminDashboard 