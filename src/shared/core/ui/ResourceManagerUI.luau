-- ResourceManagerUI.luau
-- Enhanced UI for managing resources and projects

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ResourceManagerUI = {}
ResourceManagerUI.__index = ResourceManagerUI

function ResourceManagerUI.new()
    local self = setmetatable({}, ResourceManagerUI)
    
    self.isVisible = false
    self.ui = nil
    self.currentFilter = "all"
    self.searchQuery = ""
    
    return self
end

function ResourceManagerUI:Initialize()
    self:CreateUI()
    self:SetupKeyboardShortcuts()
    print("ResourceManagerUI: Initialized")
end

function ResourceManagerUI:CreateUI()
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    
    -- Remove existing UI
    local existing = playerGui:FindFirstChild("ResourceManagerUI")
    if existing then existing:Destroy() end
    
    -- Main UI
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ResourceManagerUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Main panel
    local mainPanel = Instance.new("Frame")
    mainPanel.Name = "MainPanel"
    mainPanel.Size = UDim2.new(0, 600, 0, 500)
    mainPanel.Position = UDim2.new(0.5, -300, 0.5, -250)
    mainPanel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    mainPanel.BorderSizePixel = 0
    mainPanel.Visible = false
    mainPanel.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainPanel
    
    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainPanel
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 1, 0)
    title.Position = UDim2.new(0, 20, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "📦 Resource Manager"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextSize = 20
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 40, 0, 40)
    closeBtn.Position = UDim2.new(1, -45, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.TextSize = 18
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = titleBar
    
    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 6)
    closeBtnCorner.Parent = closeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        self:Hide()
    end)
    
    -- Search bar
    local searchFrame = Instance.new("Frame")
    searchFrame.Size = UDim2.new(1, -40, 0, 40)
    searchFrame.Position = UDim2.new(0, 20, 0, 70)
    searchFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    searchFrame.BorderSizePixel = 0
    searchFrame.Parent = mainPanel
    
    local searchCorner = Instance.new("UICorner")
    searchCorner.CornerRadius = UDim.new(0, 8)
    searchCorner.Parent = searchFrame
    
    local searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(1, -50, 1, 0)
    searchBox.Position = UDim2.new(0, 15, 0, 0)
    searchBox.BackgroundTransparency = 1
    searchBox.PlaceholderText = "🔍 Search resources..."
    searchBox.Text = ""
    searchBox.TextColor3 = Color3.new(1, 1, 1)
    searchBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    searchBox.TextSize = 16
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextXAlignment = Enum.TextXAlignment.Left
    searchBox.Parent = searchFrame
    
    -- Filter buttons
    local filterFrame = Instance.new("Frame")
    filterFrame.Size = UDim2.new(1, -40, 0, 35)
    filterFrame.Position = UDim2.new(0, 20, 0, 125)
    filterFrame.BackgroundTransparency = 1
    filterFrame.Parent = mainPanel
    
    local filterLayout = Instance.new("UIListLayout")
    filterLayout.FillDirection = Enum.FillDirection.Horizontal
    filterLayout.SortOrder = Enum.SortOrder.LayoutOrder
    filterLayout.Padding = UDim.new(0, 10)
    filterLayout.Parent = filterFrame
    
    local filters = {"All", "Materials", "Tools", "Decorations", "Projects"}
    for i, filter in ipairs(filters) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 100, 1, 0)
        btn.BackgroundColor3 = i == 1 and Color3.fromRGB(0, 120, 0) or Color3.fromRGB(60, 60, 60)
        btn.Text = filter
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.TextSize = 14
        btn.Font = Enum.Font.Gotham
        btn.Parent = filterFrame
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            self:SetFilter(filter:lower())
            self:UpdateFilterButtons(filterFrame, btn)
        end)
    end
    
    -- Content area
    local contentFrame = Instance.new("ScrollingFrame")
    contentFrame.Size = UDim2.new(1, -40, 1, -190)
    contentFrame.Position = UDim2.new(0, 20, 0, 170)
    contentFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    contentFrame.BorderSizePixel = 0
    contentFrame.ScrollBarThickness = 8
    contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    contentFrame.Parent = mainPanel
    
    local contentCorner = Instance.new("UICorner")
    contentCorner.CornerRadius = UDim.new(0, 8)
    contentCorner.Parent = contentFrame
    
    local contentLayout = Instance.new("UIListLayout")
    contentLayout.SortOrder = Enum.SortOrder.Name
    contentLayout.Padding = UDim.new(0, 5)
    contentLayout.Parent = contentFrame
    
    -- Toggle button
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 160, 0, 40)
    toggleBtn.Position = UDim2.new(0, 20, 1, -160)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    toggleBtn.Text = "📦 Resources"
    toggleBtn.TextColor3 = Color3.new(1, 1, 1)
    toggleBtn.TextSize = 16
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.Parent = screenGui
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 8)
    toggleCorner.Parent = toggleBtn
    
    toggleBtn.MouseButton1Click:Connect(function()
        self:Toggle()
    end)
    
    self.ui = screenGui
    self:PopulateContent()
end

function ResourceManagerUI:UpdateFilterButtons(parent, activeBtn)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("TextButton") then
            child.BackgroundColor3 = child == activeBtn and Color3.fromRGB(0, 120, 0) or Color3.fromRGB(60, 60, 60)
        end
    end
end

function ResourceManagerUI:SetFilter(filter)
    self.currentFilter = filter
    self:PopulateContent()
end

function ResourceManagerUI:PopulateContent()
    if not self.ui then return end
    
    local contentFrame = self.ui.MainPanel:FindFirstChild("ContentFrame") or self.ui.MainPanel:GetChildren()[4]
    
    -- Clear existing content
    for _, child in ipairs(contentFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    -- Sample resource data
    local resources = {
        {name = "Wood Planks", type = "materials", count = 150, icon = "🪵"},
        {name = "Stone Blocks", type = "materials", count = 75, icon = "🪨"},
        {name = "Metal Sheets", type = "materials", count = 45, icon = "⚙️"},
        {name = "Building Hammer", type = "tools", count = 1, icon = "🔨"},
        {name = "Precision Drill", type = "tools", count = 1, icon = "🔧"},
        {name = "Decorative Flowers", type = "decorations", count = 20, icon = "🌸"},
        {name = "Light Fixtures", type = "decorations", count = 8, icon = "💡"},
        {name = "Castle Project", type = "projects", count = 1, icon = "🏰"},
        {name = "Bridge Project", type = "projects", count = 1, icon = "🌉"}
    }
    
    -- Filter resources
    local filteredResources = {}
    for _, resource in ipairs(resources) do
        if self.currentFilter == "all" or resource.type == self.currentFilter then
            if self.searchQuery == "" or string.find(resource.name:lower(), self.searchQuery:lower()) then
                table.insert(filteredResources, resource)
            end
        end
    end
    
    -- Create resource items
    for i, resource in ipairs(filteredResources) do
        local item = self:CreateResourceItem(resource, i)
        item.Parent = contentFrame
    end
    
    -- Update canvas size
    local layout = contentFrame:FindFirstChild("UIListLayout")
    if layout then
        contentFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
    end
end

function ResourceManagerUI:CreateResourceItem(resource, index)
    local item = Instance.new("Frame")
    item.Name = "ResourceItem" .. index
    item.Size = UDim2.new(1, -20, 0, 60)
    item.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    item.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = item
    
    -- Icon
    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(0, 40, 0, 40)
    icon.Position = UDim2.new(0, 10, 0, 10)
    icon.BackgroundTransparency = 1
    icon.Text = resource.icon
    icon.TextSize = 24
    icon.Parent = item
    
    -- Name
    local name = Instance.new("TextLabel")
    name.Size = UDim2.new(0, 200, 0, 25)
    name.Position = UDim2.new(0, 60, 0, 10)
    name.BackgroundTransparency = 1
    name.Text = resource.name
    name.TextColor3 = Color3.new(1, 1, 1)
    name.TextSize = 16
    name.Font = Enum.Font.GothamBold
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.Parent = item
    
    -- Count
    local count = Instance.new("TextLabel")
    count.Size = UDim2.new(0, 100, 0, 20)
    count.Position = UDim2.new(0, 60, 0, 35)
    count.BackgroundTransparency = 1
    count.Text = "Count: " .. resource.count
    count.TextColor3 = Color3.fromRGB(180, 180, 180)
    count.TextSize = 14
    count.Font = Enum.Font.Gotham
    count.TextXAlignment = Enum.TextXAlignment.Left
    count.Parent = item
    
    -- Action button
    local actionBtn = Instance.new("TextButton")
    actionBtn.Size = UDim2.new(0, 80, 0, 30)
    actionBtn.Position = UDim2.new(1, -90, 0, 15)
    actionBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
    actionBtn.Text = "Use"
    actionBtn.TextColor3 = Color3.new(1, 1, 1)
    actionBtn.TextSize = 14
    actionBtn.Font = Enum.Font.GothamBold
    actionBtn.Parent = item
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = actionBtn
    
    actionBtn.MouseButton1Click:Connect(function()
        print("Using resource:", resource.name)
    end)
    
    return item
end

function ResourceManagerUI:SetupKeyboardShortcuts()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.R and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            self:Toggle()
        end
    end)
end

function ResourceManagerUI:Show()
    if not self.ui then return end
    
    local panel = self.ui.MainPanel
    panel.Visible = true
    panel.Size = UDim2.new(0, 0, 0, 0)
    panel.Position = UDim2.new(0.5, 0, 0.5, 0)
    
    local tween = TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, 600, 0, 500),
        Position = UDim2.new(0.5, -300, 0.5, -250)
    })
    tween:Play()
    
    self.isVisible = true
end

function ResourceManagerUI:Hide()
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

function ResourceManagerUI:Toggle()
    if self.isVisible then
        self:Hide()
    else
        self:Show()
    end
end

return ResourceManagerUI 