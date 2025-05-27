-- BlueprintUI.luau
-- Modern UI for blueprint management including creation, browsing, sharing, and marketplace

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local BlueprintUI = {}
BlueprintUI.__index = BlueprintUI

-- UI Configuration
local UI_CONFIG = {
    MAIN_SIZE = UDim2.new(0, 900, 0, 700),
    ANIMATION_TIME = 0.3,
    COLORS = {
        PRIMARY = Color3.fromRGB(45, 45, 55),
        SECONDARY = Color3.fromRGB(35, 35, 45),
        ACCENT = Color3.fromRGB(100, 149, 237),
        SUCCESS = Color3.fromRGB(40, 167, 69),
        WARNING = Color3.fromRGB(255, 193, 7),
        ERROR = Color3.fromRGB(220, 53, 69)
    },
    TABS = {
        MY_BLUEPRINTS = {Name = "My Blueprints", Icon = "📋"},
        MARKETPLACE = {Name = "Marketplace", Icon = "🏪"},
        CREATE = {Name = "Create", Icon = "✨"},
        FEATURED = {Name = "Featured", Icon = "⭐"},
        SEARCH = {Name = "Search", Icon = "🔍"}
    }
}

function BlueprintUI.new(blueprintManager)
    local self = setmetatable({}, BlueprintUI)
    
    self.blueprintManager = blueprintManager
    self.isVisible = false
    self.currentTab = "MY_BLUEPRINTS"
    self.connections = {}
    self.searchResults = {}
    
    -- Create the main UI
    self:CreateMainInterface()
    self:SetupEventHandlers()
    
    return self
end

function BlueprintUI:CreateMainInterface()
    -- Main ScreenGui
    self.gui = Instance.new("ScreenGui")
    self.gui.Name = "BlueprintInterface"
    self.gui.ResetOnSpawn = false
    self.gui.Parent = PlayerGui
    
    -- Main Frame
    self.mainFrame = Instance.new("Frame")
    self.mainFrame.Name = "BlueprintPanel"
    self.mainFrame.Size = UI_CONFIG.MAIN_SIZE
    self.mainFrame.Position = UDim2.new(0.5, -450, 0.5, -350)
    self.mainFrame.BackgroundColor3 = UI_CONFIG.COLORS.PRIMARY
    self.mainFrame.BorderSizePixel = 0
    self.mainFrame.Visible = false
    self.mainFrame.Parent = self.gui
    
    -- Add rounded corners and shadow
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = self.mainFrame
    
    -- Header
    self:CreateHeader()
    
    -- Tab System
    self:CreateTabSystem()
    
    -- Content Area
    self:CreateContentArea()
    
    -- Initialize with My Blueprints tab
    self:SwitchTab("MY_BLUEPRINTS")
end

function BlueprintUI:CreateHeader()
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 60)
    header.BackgroundColor3 = UI_CONFIG.COLORS.SECONDARY
    header.BorderSizePixel = 0
    header.Parent = self.mainFrame
    
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 12)
    headerCorner.Parent = header
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(0, 250, 1, 0)
    title.Position = UDim2.new(0, 20, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "📐 Blueprint Workshop"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = header
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 40, 0, 40)
    closeButton.Position = UDim2.new(1, -50, 0, 10)
    closeButton.BackgroundColor3 = UI_CONFIG.COLORS.ERROR
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
end

function BlueprintUI:CreateTabSystem()
    local tabContainer = Instance.new("Frame")
    tabContainer.Name = "TabContainer"
    tabContainer.Size = UDim2.new(1, 0, 0, 50)
    tabContainer.Position = UDim2.new(0, 0, 0, 60)
    tabContainer.BackgroundColor3 = UI_CONFIG.COLORS.SECONDARY
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
        tab.Size = UDim2.new(0, 160, 0, 35)
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

function BlueprintUI:CreateContentArea()
    self.contentFrame = Instance.new("Frame")
    self.contentFrame.Name = "ContentFrame"
    self.contentFrame.Size = UDim2.new(1, 0, 1, -110)
    self.contentFrame.Position = UDim2.new(0, 0, 0, 110)
    self.contentFrame.BackgroundTransparency = 1
    self.contentFrame.Parent = self.mainFrame
    
    -- Create content for each tab
    self:CreateMyBlueprintsContent()
    self:CreateMarketplaceContent()
    self:CreateCreateContent()
    self:CreateFeaturedContent()
    self:CreateSearchContent()
end

function BlueprintUI:CreateMyBlueprintsContent()
    local content = Instance.new("Frame")
    content.Name = "MyBlueprintsContent"
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.Visible = false
    content.Parent = self.contentFrame
    
    -- Actions bar
    local actionsBar = Instance.new("Frame")
    actionsBar.Name = "ActionsBar"
    actionsBar.Size = UDim2.new(1, -20, 0, 40)
    actionsBar.Position = UDim2.new(0, 10, 0, 10)
    actionsBar.BackgroundTransparency = 1
    actionsBar.Parent = content
    
    local actionsLayout = Instance.new("UIListLayout")
    actionsLayout.FillDirection = Enum.FillDirection.Horizontal
    actionsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    actionsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    actionsLayout.Padding = UDim.new(0, 10)
    actionsLayout.Parent = actionsBar
    
    -- Create Blueprint button
    local createBtn = self:CreateActionButton("📋 New Blueprint", UI_CONFIG.COLORS.SUCCESS)
    createBtn.Parent = actionsBar
    createBtn.MouseButton1Click:Connect(function()
        self:ShowCreateBlueprintDialog()
    end)
    
    -- Blueprints grid
    local blueprintsScroll = Instance.new("ScrollingFrame")
    blueprintsScroll.Name = "BlueprintsGrid"
    blueprintsScroll.Size = UDim2.new(1, -20, 1, -60)
    blueprintsScroll.Position = UDim2.new(0, 10, 0, 50)
    blueprintsScroll.BackgroundColor3 = UI_CONFIG.COLORS.SECONDARY
    blueprintsScroll.BorderSizePixel = 0
    blueprintsScroll.ScrollBarThickness = 8
    blueprintsScroll.Parent = content
    
    local gridCorner = Instance.new("UICorner")
    gridCorner.CornerRadius = UDim.new(0, 8)
    gridCorner.Parent = blueprintsScroll
    
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 200, 0, 150)
    gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
    gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    gridLayout.Parent = blueprintsScroll
    
    local gridPadding = Instance.new("UIPadding")
    gridPadding.PaddingAll = UDim.new(0, 10)
    gridPadding.Parent = blueprintsScroll
    
    self.myBlueprintsContent = content
    self.myBlueprintsGrid = blueprintsScroll
end

function BlueprintUI:CreateMarketplaceContent()
    local content = Instance.new("Frame")
    content.Name = "MarketplaceContent"
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.Visible = false
    content.Parent = self.contentFrame
    
    -- Categories sidebar
    local sidebar = Instance.new("Frame")
    sidebar.Name = "CategoriesSidebar"
    sidebar.Size = UDim2.new(0, 200, 1, -20)
    sidebar.Position = UDim2.new(0, 10, 0, 10)
    sidebar.BackgroundColor3 = UI_CONFIG.COLORS.SECONDARY
    sidebar.BorderSizePixel = 0
    sidebar.Parent = content
    
    local sidebarCorner = Instance.new("UICorner")
    sidebarCorner.CornerRadius = UDim.new(0, 8)
    sidebarCorner.Parent = sidebar
    
    -- Marketplace grid
    local marketplaceScroll = Instance.new("ScrollingFrame")
    marketplaceScroll.Name = "MarketplaceGrid"
    marketplaceScroll.Size = UDim2.new(1, -230, 1, -20)
    marketplaceScroll.Position = UDim2.new(0, 220, 0, 10)
    marketplaceScroll.BackgroundColor3 = UI_CONFIG.COLORS.SECONDARY
    marketplaceScroll.BorderSizePixel = 0
    marketplaceScroll.ScrollBarThickness = 8
    marketplaceScroll.Parent = content
    
    local marketCorner = Instance.new("UICorner")
    marketCorner.CornerRadius = UDim.new(0, 8)
    marketCorner.Parent = marketplaceScroll
    
    self.marketplaceContent = content
    self.categoriesSidebar = sidebar
    self.marketplaceGrid = marketplaceScroll
end

function BlueprintUI:CreateCreateContent()
    local content = Instance.new("Frame")
    content.Name = "CreateContent"
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.Visible = false
    content.Parent = self.contentFrame
    
    -- Instructions panel
    local instructionsPanel = Instance.new("Frame")
    instructionsPanel.Name = "InstructionsPanel"
    instructionsPanel.Size = UDim2.new(1, -20, 0, 200)
    instructionsPanel.Position = UDim2.new(0, 10, 0, 10)
    instructionsPanel.BackgroundColor3 = UI_CONFIG.COLORS.SECONDARY
    instructionsPanel.BorderSizePixel = 0
    instructionsPanel.Parent = content
    
    local instCorner = Instance.new("UICorner")
    instCorner.CornerRadius = UDim.new(0, 8)
    instCorner.Parent = instructionsPanel
    
    local instructions = Instance.new("TextLabel")
    instructions.Size = UDim2.new(1, -20, 1, -20)
    instructions.Position = UDim2.new(0, 10, 0, 10)
    instructions.BackgroundTransparency = 1
    instructions.Text = [[📋 How to Create Blueprints:

1. 🔧 Open Building Tools (Press B)
2. 🎯 Select the items you want to include
3. ✨ Click "Create Blueprint" in this tab
4. 📝 Fill in the blueprint details
5. 💾 Save your blueprint!

💡 Tips:
• Keep blueprints under 100 items for best performance
• Use descriptive names and tags
• Test your blueprints before sharing]]
    instructions.TextColor3 = Color3.fromRGB(255, 255, 255)
    instructions.TextSize = 16
    instructions.Font = Enum.Font.Gotham
    instructions.TextXAlignment = Enum.TextXAlignment.Left
    instructions.TextYAlignment = Enum.TextYAlignment.Top
    instructions.TextWrapped = true
    instructions.Parent = instructionsPanel
    
    -- Create form
    local createForm = Instance.new("Frame")
    createForm.Name = "CreateForm"
    createForm.Size = UDim2.new(1, -20, 1, -220)
    createForm.Position = UDim2.new(0, 10, 0, 220)
    createForm.BackgroundColor3 = UI_CONFIG.COLORS.SECONDARY
    createForm.BorderSizePixel = 0
    createForm.Parent = content
    
    local formCorner = Instance.new("UICorner")
    formCorner.CornerRadius = UDim.new(0, 8)
    formCorner.Parent = createForm
    
    self.createContent = content
    self.createForm = createForm
end

function BlueprintUI:CreateFeaturedContent()
    local content = Instance.new("Frame")
    content.Name = "FeaturedContent"
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.Visible = false
    content.Parent = self.contentFrame
    
    -- Featured blueprints showcase
    local featuredScroll = Instance.new("ScrollingFrame")
    featuredScroll.Name = "FeaturedGrid"
    featuredScroll.Size = UDim2.new(1, -20, 1, -20)
    featuredScroll.Position = UDim2.new(0, 10, 0, 10)
    featuredScroll.BackgroundColor3 = UI_CONFIG.COLORS.SECONDARY
    featuredScroll.BorderSizePixel = 0
    featuredScroll.ScrollBarThickness = 8
    featuredScroll.Parent = content
    
    local featCorner = Instance.new("UICorner")
    featCorner.CornerRadius = UDim.new(0, 8)
    featCorner.Parent = featuredScroll
    
    self.featuredContent = content
    self.featuredGrid = featuredScroll
end

function BlueprintUI:CreateSearchContent()
    local content = Instance.new("Frame")
    content.Name = "SearchContent"
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.Visible = false
    content.Parent = self.contentFrame
    
    -- Search bar
    local searchBar = Instance.new("Frame")
    searchBar.Name = "SearchBar"
    searchBar.Size = UDim2.new(1, -20, 0, 50)
    searchBar.Position = UDim2.new(0, 10, 0, 10)
    searchBar.BackgroundColor3 = UI_CONFIG.COLORS.SECONDARY
    searchBar.BorderSizePixel = 0
    searchBar.Parent = content
    
    local searchCorner = Instance.new("UICorner")
    searchCorner.CornerRadius = UDim.new(0, 8)
    searchCorner.Parent = searchBar
    
    local searchInput = Instance.new("TextBox")
    searchInput.Name = "SearchInput"
    searchInput.Size = UDim2.new(1, -120, 1, -10)
    searchInput.Position = UDim2.new(0, 10, 0, 5)
    searchInput.BackgroundTransparency = 1
    searchInput.Text = ""
    searchInput.PlaceholderText = "Search blueprints..."
    searchInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    searchInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    searchInput.TextSize = 16
    searchInput.Font = Enum.Font.Gotham
    searchInput.Parent = searchBar
    
    local searchButton = Instance.new("TextButton")
    searchButton.Name = "SearchButton"
    searchButton.Size = UDim2.new(0, 100, 1, -10)
    searchButton.Position = UDim2.new(1, -105, 0, 5)
    searchButton.BackgroundColor3 = UI_CONFIG.COLORS.ACCENT
    searchButton.Text = "🔍 Search"
    searchButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    searchButton.TextSize = 14
    searchButton.Font = Enum.Font.GothamBold
    searchButton.BorderSizePixel = 0
    searchButton.Parent = searchBar
    
    local searchBtnCorner = Instance.new("UICorner")
    searchBtnCorner.CornerRadius = UDim.new(0, 6)
    searchBtnCorner.Parent = searchButton
    
    -- Search results
    local resultsScroll = Instance.new("ScrollingFrame")
    resultsScroll.Name = "SearchResults"
    resultsScroll.Size = UDim2.new(1, -20, 1, -80)
    resultsScroll.Position = UDim2.new(0, 10, 0, 70)
    resultsScroll.BackgroundColor3 = UI_CONFIG.COLORS.SECONDARY
    resultsScroll.BorderSizePixel = 0
    resultsScroll.ScrollBarThickness = 8
    resultsScroll.Parent = content
    
    local resultsCorner = Instance.new("UICorner")
    resultsCorner.CornerRadius = UDim.new(0, 8)
    resultsCorner.Parent = resultsScroll
    
    self.searchContent = content
    self.searchInput = searchInput
    self.searchButton = searchButton
    self.searchResults = resultsScroll
end

function BlueprintUI:CreateActionButton(text, color)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 140, 0, 35)
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

function BlueprintUI:CreateBlueprintCard(blueprint)
    local card = Instance.new("Frame")
    card.Name = "BlueprintCard_" .. (blueprint.id or "unknown")
    card.Size = UDim2.new(0, 200, 0, 150)
    card.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
    card.BorderSizePixel = 0
    
    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 8)
    cardCorner.Parent = card
    
    -- Blueprint preview (placeholder)
    local preview = Instance.new("Frame")
    preview.Name = "Preview"
    preview.Size = UDim2.new(1, -10, 0, 100)
    preview.Position = UDim2.new(0, 5, 0, 5)
    preview.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    preview.BorderSizePixel = 0
    preview.Parent = card
    
    local previewCorner = Instance.new("UICorner")
    previewCorner.CornerRadius = UDim.new(0, 6)
    previewCorner.Parent = preview
    
    local previewIcon = Instance.new("TextLabel")
    previewIcon.Size = UDim2.new(1, 0, 1, 0)
    previewIcon.BackgroundTransparency = 1
    previewIcon.Text = "📐"
    previewIcon.TextColor3 = Color3.fromRGB(200, 200, 200)
    previewIcon.TextSize = 48
    previewIcon.Font = Enum.Font.Gotham
    previewIcon.Parent = preview
    
    -- Blueprint info
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, -10, 0, 20)
    nameLabel.Position = UDim2.new(0, 5, 0, 110)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = blueprint.name or "Unnamed Blueprint"
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextSize = 14
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = card
    
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "InfoLabel"
    infoLabel.Size = UDim2.new(1, -10, 0, 15)
    infoLabel.Position = UDim2.new(0, 5, 0, 130)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = (blueprint.itemCount or 0) .. " items • " .. (blueprint.category or "other")
    infoLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    infoLabel.TextSize = 12
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.Parent = card
    
    -- Click handler
    local clickButton = Instance.new("TextButton")
    clickButton.Size = UDim2.new(1, 0, 1, 0)
    clickButton.BackgroundTransparency = 1
    clickButton.Text = ""
    clickButton.Parent = card
    
    clickButton.MouseButton1Click:Connect(function()
        self:ShowBlueprintDetails(blueprint)
    end)
    
    return card
end

function BlueprintUI:SwitchTab(tabId)
    -- Update tab appearance
    for id, tab in pairs(self.tabs) do
        if id == tabId then
            tab.BackgroundColor3 = UI_CONFIG.COLORS.ACCENT
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
        MY_BLUEPRINTS = self.myBlueprintsContent,
        MARKETPLACE = self.marketplaceContent,
        CREATE = self.createContent,
        FEATURED = self.featuredContent,
        SEARCH = self.searchContent
    }
    
    if contentMap[tabId] then
        contentMap[tabId].Visible = true
        
        -- Load content for the tab
        if tabId == "MY_BLUEPRINTS" then
            self:LoadMyBlueprints()
        elseif tabId == "MARKETPLACE" then
            self:LoadMarketplace()
        elseif tabId == "FEATURED" then
            self:LoadFeaturedBlueprints()
        end
    end
    
    self.currentTab = tabId
end

function BlueprintUI:LoadMyBlueprints()
    -- Clear existing blueprints
    for _, child in ipairs(self.myBlueprintsGrid:GetChildren()) do
        if child:IsA("Frame") and child.Name:find("BlueprintCard_") then
            child:Destroy()
        end
    end
    
    -- Load from blueprint manager
    if self.blueprintManager and self.blueprintManager.localBlueprints then
        for _, blueprint in ipairs(self.blueprintManager.localBlueprints) do
            local card = self:CreateBlueprintCard(blueprint)
            card.Parent = self.myBlueprintsGrid
        end
    end
    
    -- Request player blueprints from server
    self:RequestPlayerBlueprints()
end

function BlueprintUI:RequestPlayerBlueprints()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local requestFunc = remotes:FindFirstChild("GetBlueprintData")
        if requestFunc then
            task.spawn(function()
                local success, result = pcall(function()
                    return requestFunc:InvokeServer("playerBlueprints")
                end)
                
                if success and result then
                    self:DisplayBlueprints(result, self.myBlueprintsGrid)
                end
            end)
        end
    end
end

function BlueprintUI:DisplayBlueprints(blueprints, container)
    -- Clear existing
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Frame") and child.Name:find("BlueprintCard_") then
            child:Destroy()
        end
    end
    
    -- Add new blueprints
    for _, blueprint in ipairs(blueprints) do
        local card = self:CreateBlueprintCard(blueprint)
        card.Parent = container
    end
    
    -- Update canvas size
    if container:FindFirstChild("UIGridLayout") then
        local gridLayout = container.UIGridLayout
        local rows = math.ceil(#blueprints / math.floor(container.AbsoluteSize.X / (gridLayout.CellSize.X.Offset + gridLayout.CellPadding.X.Offset)))
        container.CanvasSize = UDim2.new(0, 0, 0, rows * (gridLayout.CellSize.Y.Offset + gridLayout.CellPadding.Y.Offset) + 20)
    end
end

function BlueprintUI:ShowCreateBlueprintDialog()
    -- Implementation for create blueprint dialog
    self:SwitchTab("CREATE")
end

function BlueprintUI:ShowBlueprintDetails(blueprint)
    -- Implementation for blueprint details dialog
    print("BlueprintUI: Showing details for blueprint:", blueprint.name)
end

function BlueprintUI:SetupEventHandlers()
    -- Keyboard shortcut to toggle UI (Ctrl+B for Blueprint)
    self.connections.inputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.B and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            self:Toggle()
        elseif input.KeyCode == Enum.KeyCode.Escape and self.isVisible then
            self:Hide()
        end
    end)
end

function BlueprintUI:Show()
    self.isVisible = true
    self.mainFrame.Visible = true
    
    -- Animate entrance
    self.mainFrame.Position = UDim2.new(0.5, -450, 0.5, -400)
    self.mainFrame.Size = UDim2.new(0, 800, 0, 600)
    
    local tween = TweenService:Create(self.mainFrame, 
        TweenInfo.new(UI_CONFIG.ANIMATION_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {
            Position = UDim2.new(0.5, -450, 0.5, -350),
            Size = UI_CONFIG.MAIN_SIZE
        }
    )
    tween:Play()
end

function BlueprintUI:Hide()
    self.isVisible = false
    
    -- Animate exit
    local tween = TweenService:Create(self.mainFrame,
        TweenInfo.new(UI_CONFIG.ANIMATION_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.In),
        {
            Position = UDim2.new(0.5, -450, 0.5, -400),
            Size = UDim2.new(0, 800, 0, 600)
        }
    )
    
    tween:Play()
    tween.Completed:Connect(function()
        self.mainFrame.Visible = false
    end)
end

function BlueprintUI:Toggle()
    if self.isVisible then
        self:Hide()
    else
        self:Show()
    end
end

function BlueprintUI:UpdateBlueprintData(blueprintData)
    -- Handle updates from BlueprintManager
    if blueprintData.Type == "BlueprintCreated" then
        self:LoadMyBlueprints() -- Refresh the list
    elseif blueprintData.Type == "InitialplayerBlueprints" then
        if self.currentTab == "MY_BLUEPRINTS" then
            self:DisplayBlueprints(blueprintData.Data, self.myBlueprintsGrid)
        end
    end
end

function BlueprintUI:Cleanup()
    for _, connection in pairs(self.connections) do
        if connection then
            connection:Disconnect()
        end
    end
    
    if self.gui then
        self.gui:Destroy()
    end
    
    print("BlueprintUI: Cleaned up")
end

return BlueprintUI 