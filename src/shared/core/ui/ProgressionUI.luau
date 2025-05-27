-- ProgressionUI.luau
-- Handles the display of player progression information

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local IS_CLIENT = RunService:IsClient()

local ProgressionUI = {}
ProgressionUI.__index = ProgressionUI

function ProgressionUI.new()
    local self = setmetatable({}, ProgressionUI)
    
    if IS_CLIENT then
        self.player = Players.LocalPlayer
        self.playerGui = self.player:WaitForChild("PlayerGui")
        self.screenGui = nil
        self.progressionFrame = nil
        self.levelLabel = nil
        self.xpBar = nil
        self.xpLabel = nil
        self.discountLabel = nil
        self.itemsPlacedLabel = nil
        
        -- Progression data
        self.currentProgression = {
            level = 1,
            totalXP = 0,
            currentLevelXP = 0,
            xpForNextLevel = 0,
            itemsPlaced = 0,
            discountPercent = 0,
            isMaxLevel = false
        }
        
        self.isVisible = false
    end
    
    return self
end

-- Initialize the ProgressionUI
function ProgressionUI:Initialize()
    if not IS_CLIENT then return end
    
    print("ProgressionUI: Initializing...")
    
    -- Create the UI
    self:CreateUI()
    
    -- Set up remote events for progression updates
    self:SetupRemoteEvents()
    
    print("ProgressionUI: Initialization complete")
end

-- Create the progression UI
function ProgressionUI:CreateUI()
    if not IS_CLIENT then return end
    
    -- Create ScreenGui
    self.screenGui = Instance.new("ScreenGui")
    self.screenGui.Name = "ProgressionUI"
    self.screenGui.ResetOnSpawn = false
    self.screenGui.Parent = self.playerGui
    
    -- Main progression frame
    self.progressionFrame = Instance.new("Frame")
    self.progressionFrame.Name = "ProgressionFrame"
    self.progressionFrame.Size = UDim2.new(0, 300, 0, 120)
    self.progressionFrame.Position = UDim2.new(1, -320, 0, 20) -- Top right corner
    self.progressionFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    self.progressionFrame.BorderSizePixel = 0
    self.progressionFrame.Parent = self.screenGui
    
    -- Add corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = self.progressionFrame
    
    -- Add stroke
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(100, 100, 100)
    stroke.Thickness = 1
    stroke.Parent = self.progressionFrame
    
    -- Level label
    self.levelLabel = Instance.new("TextLabel")
    self.levelLabel.Name = "LevelLabel"
    self.levelLabel.Size = UDim2.new(1, 0, 0, 25)
    self.levelLabel.Position = UDim2.new(0, 0, 0, 5)
    self.levelLabel.BackgroundTransparency = 1
    self.levelLabel.Text = "Level 1"
    self.levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.levelLabel.TextScaled = true
    self.levelLabel.Font = Enum.Font.GothamBold
    self.levelLabel.Parent = self.progressionFrame
    
    -- XP Bar Background
    local xpBarBg = Instance.new("Frame")
    xpBarBg.Name = "XPBarBackground"
    xpBarBg.Size = UDim2.new(1, -20, 0, 15)
    xpBarBg.Position = UDim2.new(0, 10, 0, 35)
    xpBarBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    xpBarBg.BorderSizePixel = 0
    xpBarBg.Parent = self.progressionFrame
    
    local xpBarCorner = Instance.new("UICorner")
    xpBarCorner.CornerRadius = UDim.new(0, 4)
    xpBarCorner.Parent = xpBarBg
    
    -- XP Bar Fill
    self.xpBar = Instance.new("Frame")
    self.xpBar.Name = "XPBar"
    self.xpBar.Size = UDim2.new(0, 0, 1, 0)
    self.xpBar.Position = UDim2.new(0, 0, 0, 0)
    self.xpBar.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    self.xpBar.BorderSizePixel = 0
    self.xpBar.Parent = xpBarBg
    
    local xpBarFillCorner = Instance.new("UICorner")
    xpBarFillCorner.CornerRadius = UDim.new(0, 4)
    xpBarFillCorner.Parent = self.xpBar
    
    -- XP Label
    self.xpLabel = Instance.new("TextLabel")
    self.xpLabel.Name = "XPLabel"
    self.xpLabel.Size = UDim2.new(1, 0, 0, 20)
    self.xpLabel.Position = UDim2.new(0, 0, 0, 55)
    self.xpLabel.BackgroundTransparency = 1
    self.xpLabel.Text = "0 / 0 XP"
    self.xpLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    self.xpLabel.TextScaled = true
    self.xpLabel.Font = Enum.Font.Gotham
    self.xpLabel.Parent = self.progressionFrame
    
    -- Discount Label
    self.discountLabel = Instance.new("TextLabel")
    self.discountLabel.Name = "DiscountLabel"
    self.discountLabel.Size = UDim2.new(0.5, -5, 0, 20)
    self.discountLabel.Position = UDim2.new(0, 0, 0, 75)
    self.discountLabel.BackgroundTransparency = 1
    self.discountLabel.Text = "Discount: 0%"
    self.discountLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
    self.discountLabel.TextScaled = true
    self.discountLabel.Font = Enum.Font.Gotham
    self.discountLabel.Parent = self.progressionFrame
    
    -- Items Placed Label
    self.itemsPlacedLabel = Instance.new("TextLabel")
    self.itemsPlacedLabel.Name = "ItemsPlacedLabel"
    self.itemsPlacedLabel.Size = UDim2.new(0.5, -5, 0, 20)
    self.itemsPlacedLabel.Position = UDim2.new(0.5, 5, 0, 75)
    self.itemsPlacedLabel.BackgroundTransparency = 1
    self.itemsPlacedLabel.Text = "Items: 0"
    self.itemsPlacedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    self.itemsPlacedLabel.TextScaled = true
    self.itemsPlacedLabel.Font = Enum.Font.Gotham
    self.itemsPlacedLabel.Parent = self.progressionFrame
    
    -- Toggle button
    local toggleButton = Instance.new("TextButton")
    toggleButton.Name = "ToggleButton"
    toggleButton.Size = UDim2.new(0, 30, 0, 30)
    toggleButton.Position = UDim2.new(1, -35, 0, -35)
    toggleButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    toggleButton.Text = "📊"
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.TextScaled = true
    toggleButton.Font = Enum.Font.Gotham
    toggleButton.Parent = self.screenGui
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 15)
    toggleCorner.Parent = toggleButton
    
    -- Toggle functionality
    toggleButton.MouseButton1Click:Connect(function()
        self:ToggleVisibility()
    end)
    
    -- Start hidden
    self.progressionFrame.Visible = false
    self.isVisible = false
    
    print("ProgressionUI: UI created successfully")
end

-- Set up remote events for progression updates
function ProgressionUI:SetupRemoteEvents()
    if not IS_CLIENT then return end
    
    -- Wait for remotes folder
    local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
    if not remotes then
        warn("ProgressionUI: Remotes folder not found")
        return
    end
    
    -- Create or find progression update remote
    local progressionUpdateRemote = remotes:FindFirstChild("UpdateProgression")
    if not progressionUpdateRemote then
        -- The server should create this, but we'll wait for it
        progressionUpdateRemote = remotes:WaitForChild("UpdateProgression", 10)
    end
    
    if progressionUpdateRemote then
        progressionUpdateRemote.OnClientEvent:Connect(function(progressionData)
            self:UpdateProgression(progressionData)
        end)
        print("ProgressionUI: Connected to UpdateProgression remote")
    else
        warn("ProgressionUI: UpdateProgression remote not found")
    end
end

-- Update progression display
function ProgressionUI:UpdateProgression(progressionData)
    if not IS_CLIENT or not progressionData then return end
    
    -- Store the new progression data
    self.currentProgression = progressionData
    
    -- Update level label
    if progressionData.isMaxLevel then
        self.levelLabel.Text = string.format("Level %d (MAX)", progressionData.level)
        self.levelLabel.TextColor3 = Color3.fromRGB(255, 215, 0) -- Gold color for max level
    else
        self.levelLabel.Text = string.format("Level %d", progressionData.level)
        self.levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
    
    -- Update XP bar and label
    if progressionData.isMaxLevel then
        self.xpBar.Size = UDim2.new(1, 0, 1, 0)
        self.xpLabel.Text = "MAX LEVEL"
        self.xpBar.BackgroundColor3 = Color3.fromRGB(255, 215, 0) -- Gold color
    else
        local xpProgress = progressionData.xpForNextLevel > 0 and (progressionData.currentLevelXP / progressionData.xpForNextLevel) or 0
        
        -- Animate XP bar
        local targetSize = UDim2.new(xpProgress, 0, 1, 0)
        local tween = TweenService:Create(self.xpBar, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {Size = targetSize})
        tween:Play()
        
        self.xpLabel.Text = string.format("%d / %d XP", progressionData.currentLevelXP, progressionData.xpForNextLevel)
    end
    
    -- Update discount label
    self.discountLabel.Text = string.format("Discount: %d%%", progressionData.discountPercent)
    
    -- Update items placed label
    self.itemsPlacedLabel.Text = string.format("Items: %d", progressionData.itemsPlaced)
    
    print(string.format("ProgressionUI: Updated - Level %d, XP %d/%d, Discount %d%%, Items %d", 
        progressionData.level, progressionData.currentLevelXP, progressionData.xpForNextLevel, 
        progressionData.discountPercent, progressionData.itemsPlaced))
end

-- Toggle UI visibility
function ProgressionUI:ToggleVisibility()
    if not IS_CLIENT then return end
    
    self.isVisible = not self.isVisible
    self.progressionFrame.Visible = self.isVisible
    
    if self.isVisible then
        -- Animate in
        self.progressionFrame.Position = UDim2.new(1, -20, 0, 20)
        local tween = TweenService:Create(self.progressionFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), 
            {Position = UDim2.new(1, -320, 0, 20)})
        tween:Play()
    end
end

-- Show UI
function ProgressionUI:Show()
    if not IS_CLIENT then return end
    
    self.isVisible = true
    self.progressionFrame.Visible = true
end

-- Hide UI
function ProgressionUI:Hide()
    if not IS_CLIENT then return end
    
    self.isVisible = false
    self.progressionFrame.Visible = false
end

-- Request progression update from server
function ProgressionUI:RequestUpdate()
    if not IS_CLIENT then return end
    
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local requestProgressionRemote = remotes:FindFirstChild("RequestProgression")
        if requestProgressionRemote then
            requestProgressionRemote:FireServer()
        end
    end
end

return ProgressionUI 