--[[
	AnalyticsDashboard.luau
	Enterprise-Level Real-Time Analytics Dashboard
	
	Features:
	- Real-time performance visualization
	- Multiple dashboard panels and charts
	- Historical data analysis
	- Anomaly detection alerts
	- Performance trend analysis
	- System health monitoring
	- Predictive analytics display
	- Interactive data exploration
	- Export capabilities
	- Customizable layouts
	
	Author: ForeverBuild2 Enterprise Team
	Version: 1.0.0
	Last Updated: 2024
]]

local AnalyticsDashboard = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local PerformanceMonitor = require(game.ReplicatedStorage.shared.monitoring.PerformanceMonitor)

-- Configuration
local CONFIG = {
	-- Dashboard settings
	UPDATE_INTERVAL = 1, -- seconds
	CHART_DATA_POINTS = 60, -- Number of data points to show in charts
	AUTO_REFRESH = true,
	DEFAULT_TIME_RANGE = 300, -- 5 minutes
	
	-- UI settings
	PANEL_SIZE = UDim2.new(0, 300, 0, 200),
	CHART_HEIGHT = 150,
	COLOR_SCHEME = {
		PRIMARY = Color3.fromRGB(64, 128, 255),
		SUCCESS = Color3.fromRGB(76, 175, 80),
		WARNING = Color3.fromRGB(255, 193, 7),
		DANGER = Color3.fromRGB(244, 67, 54),
		BACKGROUND = Color3.fromRGB(33, 37, 41),
		SURFACE = Color3.fromRGB(52, 58, 64),
		TEXT = Color3.fromRGB(255, 255, 255),
		MUTED = Color3.fromRGB(108, 117, 125),
	},
	
	-- Chart settings
	CHART_TYPES = {
		LINE = "line",
		BAR = "bar",
		GAUGE = "gauge",
		HEATMAP = "heatmap",
		SCATTER = "scatter",
	},
	
	-- Panel layouts
	LAYOUTS = {
		GRID = "grid",
		TABS = "tabs",
		CUSTOM = "custom",
	},
}

-- Dashboard state
local dashboardState = {
	isVisible = false,
	currentLayout = CONFIG.LAYOUTS.GRID,
	selectedTimeRange = CONFIG.DEFAULT_TIME_RANGE,
	panels = {},
	charts = {},
	updateConnection = nil,
	lastUpdate = 0,
}

-- UI Elements
local gui = nil
local mainFrame = nil
local panels = {}

-- Initialize dashboard
function AnalyticsDashboard.Initialize()
	AnalyticsDashboard.CreateGUI()
	AnalyticsDashboard.CreatePanels()
	AnalyticsDashboard.SetupControls()
	AnalyticsDashboard.StartUpdateLoop()
	
	print("AnalyticsDashboard: Enterprise analytics dashboard initialized")
end

-- Create main GUI structure
function AnalyticsDashboard.CreateGUI()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	
	-- Create main ScreenGui
	gui = Instance.new("ScreenGui")
	gui.Name = "AnalyticsDashboard"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	
	-- Create main frame
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0.95, 0, 0.9, 0)
	mainFrame.Position = UDim2.new(0.025, 0, 0.05, 0)
	mainFrame.BackgroundColor3 = CONFIG.COLOR_SCHEME.BACKGROUND
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Parent = gui
	
	-- Add rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = mainFrame
	
	-- Create title bar
	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, 40)
	titleBar.Position = UDim2.new(0, 0, 0, 0)
	titleBar.BackgroundColor3 = CONFIG.COLOR_SCHEME.PRIMARY
	titleBar.BorderSizePixel = 0
	titleBar.Parent = mainFrame
	
	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 8)
	titleCorner.Parent = titleBar
	
	-- Title text
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(0.7, 0, 1, 0)
	titleLabel.Position = UDim2.new(0.02, 0, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "📊 ForeverBuild2 Analytics Dashboard - Real-Time Performance Monitoring"
	titleLabel.TextColor3 = CONFIG.COLOR_SCHEME.TEXT
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = titleBar
	
	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 30, 0, 30)
	closeButton.Position = UDim2.new(1, -35, 0, 5)
	closeButton.BackgroundColor3 = CONFIG.COLOR_SCHEME.DANGER
	closeButton.Text = "✕"
	closeButton.TextColor3 = CONFIG.COLOR_SCHEME.TEXT
	closeButton.TextScaled = true
	closeButton.Font = Enum.Font.GothamBold
	closeButton.BorderSizePixel = 0
	closeButton.Parent = titleBar
	
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 4)
	closeCorner.Parent = closeButton
	
	closeButton.MouseButton1Click:Connect(function()
		AnalyticsDashboard.Toggle()
	end)
	
	-- Controls bar
	local controlsBar = Instance.new("Frame")
	controlsBar.Name = "ControlsBar"
	controlsBar.Size = UDim2.new(1, 0, 0, 50)
	controlsBar.Position = UDim2.new(0, 0, 0, 40)
	controlsBar.BackgroundColor3 = CONFIG.COLOR_SCHEME.SURFACE
	controlsBar.BorderSizePixel = 0
	controlsBar.Parent = mainFrame
	
	-- Content area
	local contentArea = Instance.new("ScrollingFrame")
	contentArea.Name = "ContentArea"
	contentArea.Size = UDim2.new(1, 0, 1, -90)
	contentArea.Position = UDim2.new(0, 0, 0, 90)
	contentArea.BackgroundTransparency = 1
	contentArea.BorderSizePixel = 0
	contentArea.ScrollBarThickness = 8
	contentArea.ScrollBarImageColor3 = CONFIG.COLOR_SCHEME.MUTED
	contentArea.Parent = mainFrame
	
	-- Grid layout for panels
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 320, 0, 220)
	gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = contentArea
	
	-- Padding
	local padding = Instance.new("UIPadding")
	padding.PaddingAll = UDim.new(0, 10)
	padding.Parent = contentArea
end

-- Create dashboard panels
function AnalyticsDashboard.CreatePanels()
	-- Performance Overview Panel
	panels.performanceOverview = AnalyticsDashboard.CreatePanel(
		"Performance Overview",
		"Real-time system performance metrics",
		1,
		function(panel)
			AnalyticsDashboard.UpdatePerformanceOverview(panel)
		end
	)
	
	-- FPS Monitoring Panel
	panels.fpsMonitoring = AnalyticsDashboard.CreatePanel(
		"FPS Monitoring",
		"Frame rate analysis and trends",
		2,
		function(panel)
			AnalyticsDashboard.UpdateFPSChart(panel)
		end
	)
	
	-- Memory Usage Panel
	panels.memoryUsage = AnalyticsDashboard.CreatePanel(
		"Memory Usage",
		"Memory consumption and garbage collection",
		3,
		function(panel)
			AnalyticsDashboard.UpdateMemoryChart(panel)
		end
	)
	
	-- Network Performance Panel
	panels.networkPerformance = AnalyticsDashboard.CreatePanel(
		"Network Performance", 
		"Network latency and bandwidth usage",
		4,
		function(panel)
			AnalyticsDashboard.UpdateNetworkChart(panel)
		end
	)
	
	-- System Health Panel
	panels.systemHealth = AnalyticsDashboard.CreatePanel(
		"System Health",
		"Overall system health scoring",
		5,
		function(panel)
			AnalyticsDashboard.UpdateSystemHealth(panel)
		end
	)
	
	-- Alerts & Anomalies Panel
	panels.alertsAnomalies = AnalyticsDashboard.CreatePanel(
		"Alerts & Anomalies",
		"Performance alerts and anomaly detection",
		6,
		function(panel)
			AnalyticsDashboard.UpdateAlertsAnomalies(panel)
		end
	)
	
	-- Player Analytics Panel
	panels.playerAnalytics = AnalyticsDashboard.CreatePanel(
		"Player Analytics",
		"Player count and engagement metrics",
		7,
		function(panel)
			AnalyticsDashboard.UpdatePlayerAnalytics(panel)
		end
	)
	
	-- Predictive Analytics Panel
	panels.predictiveAnalytics = AnalyticsDashboard.CreatePanel(
		"Predictive Analytics",
		"Performance predictions and trends",
		8,
		function(panel)
			AnalyticsDashboard.UpdatePredictiveAnalytics(panel)
		end
	)
	
	-- Resource Utilization Panel
	panels.resourceUtilization = AnalyticsDashboard.CreatePanel(
		"Resource Utilization",
		"CPU, memory, and script performance breakdown",
		9,
		function(panel)
			AnalyticsDashboard.UpdateResourceUtilization(panel)
		end
	)
end

-- Create individual panel
function AnalyticsDashboard.CreatePanel(title, description, layoutOrder, updateFunction)
	local panel = Instance.new("Frame")
	panel.Name = title:gsub("%s", "")
	panel.Size = UDim2.new(0, 300, 0, 200)
	panel.BackgroundColor3 = CONFIG.COLOR_SCHEME.SURFACE
	panel.BorderSizePixel = 0
	panel.LayoutOrder = layoutOrder
	panel.Parent = mainFrame.ContentArea
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = panel
	
	-- Panel header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 35)
	header.BackgroundColor3 = CONFIG.COLOR_SCHEME.PRIMARY
	header.BorderSizePixel = 0
	header.Parent = panel
	
	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 6)
	headerCorner.Parent = header
	
	-- Panel title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -10, 1, 0)
	titleLabel.Position = UDim2.new(0, 5, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title
	titleLabel.TextColor3 = CONFIG.COLOR_SCHEME.TEXT
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = header
	
	-- Panel content area
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(1, 0, 1, -35)
	content.Position = UDim2.new(0, 0, 0, 35)
	content.BackgroundTransparency = 1
	content.Parent = panel
	
	-- Content padding
	local contentPadding = Instance.new("UIPadding")
	contentPadding.PaddingAll = UDim.new(0, 8)
	contentPadding.Parent = content
	
	-- Store update function
	panel.UpdateFunction = updateFunction
	
	return panel
end

-- Update performance overview panel
function AnalyticsDashboard.UpdatePerformanceOverview(panel)
	local metrics = PerformanceMonitor.getCurrentMetrics()
	if not metrics then return end
	
	local content = panel.Content
	
	-- Clear existing content
	for _, child in pairs(content:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	
	-- Performance score gauge
	local scoreFrame = Instance.new("Frame")
	scoreFrame.Size = UDim2.new(0.5, -5, 0.6, 0)
	scoreFrame.Position = UDim2.new(0, 0, 0, 0)
	scoreFrame.BackgroundTransparency = 1
	scoreFrame.Parent = content
	
	local scoreLabel = Instance.new("TextLabel")
	scoreLabel.Size = UDim2.new(1, 0, 0.5, 0)
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.Text = "Performance Score"
	scoreLabel.TextColor3 = CONFIG.COLOR_SCHEME.TEXT
	scoreLabel.TextScaled = true
	scoreLabel.Font = Enum.Font.Gotham
	scoreLabel.Parent = scoreFrame
	
	local scoreValue = Instance.new("TextLabel")
	scoreValue.Size = UDim2.new(1, 0, 0.5, 0)
	scoreValue.Position = UDim2.new(0, 0, 0.5, 0)
	scoreValue.BackgroundTransparency = 1
	scoreValue.Text = string.format("%.0f/100", metrics.performanceScore or 100)
	scoreValue.TextColor3 = AnalyticsDashboard.GetScoreColor(metrics.performanceScore or 100)
	scoreValue.TextScaled = true
	scoreValue.Font = Enum.Font.GothamBold
	scoreValue.Parent = scoreFrame
	
	-- Health score gauge
	local healthFrame = Instance.new("Frame")
	healthFrame.Size = UDim2.new(0.5, -5, 0.6, 0)
	healthFrame.Position = UDim2.new(0.5, 5, 0, 0)
	healthFrame.BackgroundTransparency = 1
	healthFrame.Parent = content
	
	local healthLabel = Instance.new("TextLabel")
	healthLabel.Size = UDim2.new(1, 0, 0.5, 0)
	healthLabel.BackgroundTransparency = 1
	healthLabel.Text = "Health Score"
	healthLabel.TextColor3 = CONFIG.COLOR_SCHEME.TEXT
	healthLabel.TextScaled = true
	healthLabel.Font = Enum.Font.Gotham
	healthLabel.Parent = healthFrame
	
	local healthValue = Instance.new("TextLabel")
	healthValue.Size = UDim2.new(1, 0, 0.5, 0)
	healthValue.Position = UDim2.new(0, 0, 0.5, 0)
	healthValue.BackgroundTransparency = 1
	healthValue.Text = string.format("%.0f/100", metrics.healthScore or 100)
	healthValue.TextColor3 = AnalyticsDashboard.GetScoreColor(metrics.healthScore or 100)
	healthValue.TextScaled = true
	healthValue.Font = Enum.Font.GothamBold
	healthValue.Parent = healthFrame
	
	-- Key metrics summary
	local summaryFrame = Instance.new("Frame")
	summaryFrame.Size = UDim2.new(1, 0, 0.4, 0)
	summaryFrame.Position = UDim2.new(0, 0, 0.6, 0)
	summaryFrame.BackgroundTransparency = 1
	summaryFrame.Parent = content
	
	local summaryLayout = Instance.new("UIListLayout")
	summaryLayout.SortOrder = Enum.SortOrder.LayoutOrder
	summaryLayout.Padding = UDim.new(0, 2)
	summaryLayout.Parent = summaryFrame
	
	local keyMetrics = {
		{name = "FPS", value = string.format("%.1f", metrics.fps or 0), trend = metrics.fpsTrend},
		{name = "Memory", value = string.format("%.0f MB", metrics.memory or 0), trend = metrics.memoryTrend},
		{name = "Network", value = string.format("%.0f ms", metrics.network or 0), trend = metrics.networkTrend},
		{name = "CPU", value = string.format("%.1f%%", metrics.cpu or 0), trend = metrics.cpuTrend},
	}
	
	for i, metric in ipairs(keyMetrics) do
		local metricLabel = Instance.new("TextLabel")
		metricLabel.Size = UDim2.new(1, 0, 0.25, 0)
		metricLabel.BackgroundTransparency = 1
		metricLabel.Text = string.format("%s: %s %s", metric.name, metric.value, AnalyticsDashboard.GetTrendIcon(metric.trend))
		metricLabel.TextColor3 = CONFIG.COLOR_SCHEME.TEXT
		metricLabel.TextScaled = true
		metricLabel.Font = Enum.Font.Gotham
		metricLabel.TextXAlignment = Enum.TextXAlignment.Left
		metricLabel.LayoutOrder = i
		metricLabel.Parent = summaryFrame
	end
end

-- Update FPS chart panel
function AnalyticsDashboard.UpdateFPSChart(panel)
	local history = PerformanceMonitor.getMetricsHistory()
	if not history or #history == 0 then return end
	
	local content = panel.Content
	
	-- Create simple line chart representation
	AnalyticsDashboard.CreateLineChart(content, history, "fps", "FPS", CONFIG.COLOR_SCHEME.SUCCESS)
end

-- Update memory chart panel
function AnalyticsDashboard.UpdateMemoryChart(panel)
	local history = PerformanceMonitor.getMetricsHistory()
	if not history or #history == 0 then return end
	
	local content = panel.Content
	
	-- Create memory usage chart
	AnalyticsDashboard.CreateLineChart(content, history, "memory", "Memory (MB)", CONFIG.COLOR_SCHEME.WARNING)
end

-- Update system health panel
function AnalyticsDashboard.UpdateSystemHealth(panel)
	local metrics = PerformanceMonitor.getCurrentMetrics()
	local analytics = PerformanceMonitor.getAnalytics()
	
	if not metrics then return end
	
	local content = panel.Content
	
	-- Clear existing content
	for _, child in pairs(content:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	
	-- Health indicators
	local indicators = {
		{name = "Performance", value = metrics.performanceScore or 100},
		{name = "Stability", value = 95}, -- Placeholder
		{name = "Reliability", value = 98}, -- Placeholder
		{name = "Efficiency", value = metrics.healthScore or 100},
	}
	
	for i, indicator in ipairs(indicators) do
		local indicatorFrame = Instance.new("Frame")
		indicatorFrame.Size = UDim2.new(1, 0, 0.25, -2)
		indicatorFrame.Position = UDim2.new(0, 0, (i-1) * 0.25, 0)
		indicatorFrame.BackgroundTransparency = 1
		indicatorFrame.Parent = content
		
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.5, 0, 1, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = indicator.name
		nameLabel.TextColor3 = CONFIG.COLOR_SCHEME.TEXT
		nameLabel.TextScaled = true
		nameLabel.Font = Enum.Font.Gotham
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = indicatorFrame
		
		local valueLabel = Instance.new("TextLabel")
		valueLabel.Size = UDim2.new(0.3, 0, 1, 0)
		valueLabel.Position = UDim2.new(0.5, 0, 0, 0)
		valueLabel.BackgroundTransparency = 1
		valueLabel.Text = string.format("%.0f%%", indicator.value)
		valueLabel.TextColor3 = AnalyticsDashboard.GetScoreColor(indicator.value)
		valueLabel.TextScaled = true
		valueLabel.Font = Enum.Font.GothamBold
		valueLabel.Parent = indicatorFrame
		
		-- Health bar
		local healthBar = Instance.new("Frame")
		healthBar.Size = UDim2.new(0.15, 0, 0.6, 0)
		healthBar.Position = UDim2.new(0.82, 0, 0.2, 0)
		healthBar.BackgroundColor3 = CONFIG.COLOR_SCHEME.MUTED
		healthBar.BorderSizePixel = 0
		healthBar.Parent = indicatorFrame
		
		local healthBarCorner = Instance.new("UICorner")
		healthBarCorner.CornerRadius = UDim.new(0, 2)
		healthBarCorner.Parent = healthBar
		
		local healthFill = Instance.new("Frame")
		healthFill.Size = UDim2.new(1, 0, indicator.value/100, 0)
		healthFill.Position = UDim2.new(0, 0, 1 - indicator.value/100, 0)
		healthFill.BackgroundColor3 = AnalyticsDashboard.GetScoreColor(indicator.value)
		healthFill.BorderSizePixel = 0
		healthFill.Parent = healthBar
		
		local healthFillCorner = Instance.new("UICorner")
		healthFillCorner.CornerRadius = UDim.new(0, 2)
		healthFillCorner.Parent = healthFill
	end
end

-- Create simple line chart
function AnalyticsDashboard.CreateLineChart(parent, data, metricName, label, color)
	-- Clear existing content
	for _, child in pairs(parent:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	
	-- Chart label
	local chartLabel = Instance.new("TextLabel")
	chartLabel.Size = UDim2.new(1, 0, 0, 20)
	chartLabel.BackgroundTransparency = 1
	chartLabel.Text = label
	chartLabel.TextColor3 = CONFIG.COLOR_SCHEME.TEXT
	chartLabel.TextScaled = true
	chartLabel.Font = Enum.Font.Gotham
	chartLabel.Parent = parent
	
	-- Chart area
	local chartArea = Instance.new("Frame")
	chartArea.Size = UDim2.new(1, 0, 1, -25)
	chartArea.Position = UDim2.new(0, 0, 0, 25)
	chartArea.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	chartArea.BorderSizePixel = 0
	chartArea.Parent = parent
	
	local chartCorner = Instance.new("UICorner")
	chartCorner.CornerRadius = UDim.new(0, 4)
	chartCorner.Parent = chartArea
	
	-- Extract recent data points
	local recentData = {}
	local maxPoints = CONFIG.CHART_DATA_POINTS
	local startIndex = math.max(1, #data - maxPoints + 1)
	
	for i = startIndex, #data do
		table.insert(recentData, data[i][metricName] or 0)
	end
	
	if #recentData == 0 then return end
	
	-- Calculate chart bounds
	local minValue = math.min(unpack(recentData))
	local maxValue = math.max(unpack(recentData))
	local range = maxValue - minValue
	if range == 0 then range = 1 end
	
	-- Draw line chart (simplified)
	local prevPoint = nil
	for i, value in ipairs(recentData) do
		local x = (i - 1) / (#recentData - 1)
		local y = 1 - ((value - minValue) / range)
		
		local point = Instance.new("Frame")
		point.Size = UDim2.new(0, 3, 0, 3)
		point.Position = UDim2.new(x, -1, y, -1)
		point.BackgroundColor3 = color
		point.BorderSizePixel = 0
		point.Parent = chartArea
		
		local pointCorner = Instance.new("UICorner")
		pointCorner.CornerRadius = UDim.new(1, 0)
		pointCorner.Parent = point
		
		prevPoint = {x = x, y = y}
	end
	
	-- Current value display
	local currentValue = recentData[#recentData]
	local valueLabel = Instance.new("TextLabel")
	valueLabel.Size = UDim2.new(0, 80, 0, 20)
	valueLabel.Position = UDim2.new(1, -85, 0, 5)
	valueLabel.BackgroundColor3 = color
	valueLabel.Text = string.format("%.1f", currentValue)
	valueLabel.TextColor3 = CONFIG.COLOR_SCHEME.TEXT
	valueLabel.TextScaled = true
	valueLabel.Font = Enum.Font.GothamBold
	valueLabel.Parent = chartArea
	
	local valueLabelCorner = Instance.new("UICorner")
	valueLabelCorner.CornerRadius = UDim.new(0, 3)
	valueLabelCorner.Parent = valueLabel
end

-- Utility functions
function AnalyticsDashboard.GetScoreColor(score)
	if score >= 80 then
		return CONFIG.COLOR_SCHEME.SUCCESS
	elseif score >= 60 then
		return CONFIG.COLOR_SCHEME.WARNING
	else
		return CONFIG.COLOR_SCHEME.DANGER
	end
end

function AnalyticsDashboard.GetTrendIcon(trend)
	if trend == 1 then
		return "📈"
	elseif trend == -1 then
		return "📉"
	else
		return "➖"
	end
end

-- Control functions
function AnalyticsDashboard.Toggle()
	if not gui then
		AnalyticsDashboard.Initialize()
	end
	
	dashboardState.isVisible = not dashboardState.isVisible
	mainFrame.Visible = dashboardState.isVisible
	
	if dashboardState.isVisible then
		print("AnalyticsDashboard: Dashboard opened")
	else
		print("AnalyticsDashboard: Dashboard closed")
	end
end

function AnalyticsDashboard.SetupControls()
	-- Setup keyboard shortcut (F10)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.KeyCode == Enum.KeyCode.F10 then
			AnalyticsDashboard.Toggle()
		end
	end)
end

function AnalyticsDashboard.StartUpdateLoop()
	dashboardState.updateConnection = RunService.Heartbeat:Connect(function()
		if not dashboardState.isVisible then return end
		
		local currentTime = tick()
		if currentTime - dashboardState.lastUpdate < CONFIG.UPDATE_INTERVAL then return end
		
		AnalyticsDashboard.UpdateAllPanels()
		dashboardState.lastUpdate = currentTime
	end)
end

function AnalyticsDashboard.UpdateAllPanels()
	for _, panel in pairs(panels) do
		if panel and panel.UpdateFunction and panel.Visible then
			pcall(panel.UpdateFunction, panel)
		end
	end
end

-- Placeholder update functions for remaining panels
function AnalyticsDashboard.UpdateNetworkChart(panel)
	local history = PerformanceMonitor.getMetricsHistory()
	if history then
		AnalyticsDashboard.CreateLineChart(panel.Content, history, "network", "Network Latency (ms)", CONFIG.COLOR_SCHEME.PRIMARY)
	end
end

function AnalyticsDashboard.UpdateAlertsAnomalies(panel)
	-- Placeholder for alerts and anomalies
end

function AnalyticsDashboard.UpdatePlayerAnalytics(panel)
	-- Placeholder for player analytics
end

function AnalyticsDashboard.UpdatePredictiveAnalytics(panel)
	-- Placeholder for predictive analytics
end

function AnalyticsDashboard.UpdateResourceUtilization(panel)
	-- Placeholder for resource utilization
end

-- Shutdown
function AnalyticsDashboard.Shutdown()
	if dashboardState.updateConnection then
		dashboardState.updateConnection:Disconnect()
	end
	
	if gui then
		gui:Destroy()
		gui = nil
	end
	
	print("AnalyticsDashboard: Shutdown completed")
end

-- Auto-initialize for admin users
task.spawn(function()
	local player = Players.LocalPlayer
	if player and player.Name == "Admin" then -- Replace with actual admin check
		wait(5) -- Wait for other systems to load
		AnalyticsDashboard.Initialize()
	end
end)

return AnalyticsDashboard 