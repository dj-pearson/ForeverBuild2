-- InventoryManager.luau
-- Unified inventory system that consolidates all inventory functionality
-- Replaces multiple conflicting inventory modules

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Safe SharedModule loading with comprehensive fallbacks
local SharedModule
local Constants
local LazyLoadModules

local function loadSharedModule()
    local success, result = pcall(function()
        return require(ReplicatedStorage:WaitForChild("shared", 5))
    end)
    
    if success and result then
        SharedModule = result
        Constants = result.Constants or {}
        LazyLoadModules = result.LazyLoadModules or {
            register = function() end,
            require = function() return nil end
        }
        print("[InventoryManager] Successfully loaded SharedModule")
        return true
    else
        warn("[InventoryManager] Failed to load SharedModule:", result)
        return false
    end
end

-- Initialize with fallbacks
if not loadSharedModule() then
    print("[InventoryManager] Creating fallback systems")
    Constants = {
        GAME = {
            MAX_INVENTORY_SLOTS = 50,
            CURRENCY_TYPES = {"Coins", "Gems"},
            DEFAULT_CURRENCY = "Coins"
        },
        UI_COLORS = {
            PRIMARY = Color3.fromRGB(0, 170, 255),
            SECONDARY = Color3.fromRGB(40, 40, 40),
            TEXT = Color3.fromRGB(255, 255, 255),
            SUCCESS = Color3.fromRGB(0, 170, 0),
            WARNING = Color3.fromRGB(255, 215, 0),
            ERROR = Color3.fromRGB(200, 50, 50)
        },
        ITEMS = {}
    }
    LazyLoadModules = {
        register = function() end,
        require = function() return nil end
    }
    SharedModule = {
        Constants = Constants,
        LazyLoadModules = LazyLoadModules
    }
end

local InventoryManager = {}
InventoryManager.__index = InventoryManager

-- Configuration
local CONFIG = {
    ANIMATION_DURATION = 0.3,
    ITEM_SIZE = UDim2.new(0, 100, 0, 120),
    ITEMS_PER_ROW = 4,
    ITEM_PADDING = 10,
    SIDEBAR_WIDTH = 140,
    INVENTORY_SIZE = UDim2.new(0, 700, 0, 450),
    UPDATE_INTERVAL = 0.5,
    DEBUG_MODE = false,
    MAX_NOTIFICATIONS = 5,
    NOTIFICATION_DURATION = 4
}

-- Tier configuration
local TIER_TABS = {
    {name = "Basic", tiers = {"BASIC", "Basic", "basic"}},
    {name = "Level 1", tiers = {"LEVEL_1", "Level_1", "level_1", "Level 1"}},
    {name = "Level 2", tiers = {"LEVEL_2", "Level_2", "level_2", "Level 2"}},
    {name = "Level 3", tiers = {"LEVEL_3", "Level_3", "level_3", "Level 3"}},
    {name = "Level 4", tiers = {"LEVEL_4", "Level_4", "level_4", "Level 4"}},
    {name = "Rare", tiers = {"RARE", "Rare", "rare"}},
    {name = "Exclusive", tiers = {"EXCLUSIVE", "Exclusive", "exclusive"}},
    {name = "Weapons", tiers = {"WEAPON", "Weapons", "weapons", "weapon"}},
    {name = "Other", tiers = {"OTHER", "Other", "other", "FREE", "HOLIDAY", "EVENT", nil}}
}

function InventoryManager.new()
    local self = setmetatable({}, InventoryManager)
    
    -- Core properties
    self.player = Players.LocalPlayer
    self.isActive = false
    self.isVisible = false
    
    -- Data
    self.inventoryData = {}
    self.currency = 0
    self.currentTier = "Basic"
    
    -- UI components
    self.gui = nil
    self.mainFrame = nil
    self.itemsContainer = nil
    self.sidebar = nil
    self.notificationContainer = nil
    self.notifications = {}
    
    -- Connections for cleanup
    self.connections = {}
    
    -- Remote events
    self.remotes = {}
    
    -- Callbacks
    self.OnItemSelected = nil
    
    -- State tracking
    self.lastUpdateTime = 0
    
    return self
end

function InventoryManager:Initialize()
    print("[InventoryManager] Initializing...")
    
    if not self.player then
        warn("[InventoryManager] No LocalPlayer found")
        return false
    end
    
    -- Setup remote events
    self:SetupRemoteEvents()
    
    -- Create UI components
    self:CreateUI()
    
    -- Setup input handling
    self:SetupInputHandling()
    
    -- Setup update loop
    self:StartUpdateLoop()
    
    -- Setup event handlers
    self:SetupEventHandlers()
    
    self.isActive = true
    print("[InventoryManager] Initialization complete")
    return true
end

function InventoryManager:SetupRemoteEvents()
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotesFolder then
        remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
    end
    
    if not remotesFolder then
        warn("[InventoryManager] Remotes folder not found")
        return
    end
    
    -- Cache commonly used remote events
    local remoteNames = {
        "GetInventory", "UseItem", "RecallItem", "AddToInventory"
    }
    
    for _, remoteName in ipairs(remoteNames) do
        local remote = remotesFolder:FindFirstChild(remoteName)
        if remote then
            self.remotes[remoteName] = remote
        else
            if CONFIG.DEBUG_MODE then
                warn("[InventoryManager] Remote not found:", remoteName)
            end
        end
    end
    
    print("[InventoryManager] Remote events cached:", #remoteNames, "requested,", 
          self:CountTable(self.remotes), "found")
end

function InventoryManager:CreateUI()
    local playerGui = self.player:FindFirstChild("PlayerGui")
    if not playerGui then
        warn("[InventoryManager] PlayerGui not found")
        return false
    end
    
    -- Remove existing inventory UI
    local existingUI = playerGui:FindFirstChild("InventoryUI")
    if existingUI then
        existingUI:Destroy()
    end
    
    -- Create main ScreenGui
    self.gui = Instance.new("ScreenGui")
    self.gui.Name = "InventoryUI"
    self.gui.ResetOnSpawn = false
    self.gui.Parent = playerGui
    
    -- Create main frame
    self.mainFrame = Instance.new("Frame")
    self.mainFrame.Name = "InventoryFrame"
    self.mainFrame.Size = CONFIG.INVENTORY_SIZE
    self.mainFrame.Position = UDim2.new(0.5, -CONFIG.INVENTORY_SIZE.X.Offset/2, 0.5, -CONFIG.INVENTORY_SIZE.Y.Offset/2)
    self.mainFrame.BackgroundColor3 = Constants.UI_COLORS.SECONDARY
    self.mainFrame.BorderSizePixel = 0
    self.mainFrame.Visible = false
    self.mainFrame.Parent = self.gui
    
    -- Add corner radius and shadow
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = self.mainFrame
    
    -- Create title bar
    self:CreateTitleBar()
    
    -- Create sidebar for tier tabs
    self:CreateSidebar()
    
    -- Create items container
    self:CreateItemsContainer()
    
    -- Create notification system
    self:CreateNotificationSystem()
    
    -- Create inventory button
    self:CreateInventoryButton()
    
    print("[InventoryManager] UI components created")
    return true
end

function InventoryManager:CreateTitleBar()
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundColor3 = Constants.UI_COLORS.PRIMARY
    titleBar.BorderSizePixel = 0
    titleBar.Parent = self.mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = titleBar
    
    -- Title text
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(0.6, 0, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Inventory"
    title.TextColor3 = Constants.UI_COLORS.TEXT
    title.TextSize = 24
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    -- Currency display
    local currencyFrame = Instance.new("Frame")
    currencyFrame.Name = "CurrencyFrame"
    currencyFrame.Size = UDim2.new(0.3, 0, 0.8, 0)
    currencyFrame.Position = UDim2.new(0.6, 0, 0.1, 0)
    currencyFrame.BackgroundColor3 = Constants.UI_COLORS.SECONDARY
    currencyFrame.BorderSizePixel = 0
    currencyFrame.Parent = titleBar
    
    local currencyCorner = Instance.new("UICorner")
    currencyCorner.CornerRadius = UDim.new(0, 4)
    currencyCorner.Parent = currencyFrame
    
    local currencyLabel = Instance.new("TextLabel")
    currencyLabel.Name = "Currency"
    currencyLabel.Size = UDim2.new(1, -10, 1, 0)
    currencyLabel.Position = UDim2.new(0, 5, 0, 0)
    currencyLabel.BackgroundTransparency = 1
    currencyLabel.Text = "0 Coins"
    currencyLabel.TextColor3 = Constants.UI_COLORS.WARNING
    currencyLabel.TextSize = 16
    currencyLabel.Font = Enum.Font.GothamBold
    currencyLabel.TextXAlignment = Enum.TextXAlignment.Center
    currencyLabel.Parent = currencyFrame
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -40, 0, 10)
    closeButton.BackgroundColor3 = Constants.UI_COLORS.ERROR
    closeButton.Text = "✕"
    closeButton.TextColor3 = Constants.UI_COLORS.TEXT
    closeButton.TextSize = 18
    closeButton.Font = Enum.Font.GothamBold
    closeButton.BorderSizePixel = 0
    closeButton.Parent = titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = closeButton
    
    -- Close button functionality
    closeButton.MouseButton1Click:Connect(function()
        self:Hide()
    end)
end

function InventoryManager:CreateSidebar()
    self.sidebar = Instance.new("Frame")
    self.sidebar.Name = "Sidebar"
    self.sidebar.Size = UDim2.new(0, CONFIG.SIDEBAR_WIDTH, 1, -60)
    self.sidebar.Position = UDim2.new(0, 10, 0, 60)
    self.sidebar.BackgroundColor3 = Constants.UI_COLORS.SECONDARY
    self.sidebar.BackgroundTransparency = 0.5
    self.sidebar.BorderSizePixel = 0
    self.sidebar.Parent = self.mainFrame
    
    local sidebarCorner = Instance.new("UICorner")
    sidebarCorner.CornerRadius = UDim.new(0, 6)
    sidebarCorner.Parent = self.sidebar
    
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 5)
    layout.Parent = self.sidebar
    
    -- Create tier tabs
    for i, tierInfo in ipairs(TIER_TABS) do
        local tab = Instance.new("TextButton")
        tab.Name = tierInfo.name .. "Tab"
        tab.Size = UDim2.new(1, -10, 0, 35)
        tab.BackgroundColor3 = Constants.UI_COLORS.SECONDARY
        tab.Text = tierInfo.name
        tab.TextColor3 = Color3.new(0.8, 0.8, 0.8)
        tab.TextSize = 14
        tab.Font = Enum.Font.Gotham
        tab.BorderSizePixel = 0
        tab.LayoutOrder = i
        tab.Parent = self.sidebar
        
        local tabCorner = Instance.new("UICorner")
        tabCorner.CornerRadius = UDim.new(0, 4)
        tabCorner.Parent = tab
        
        -- Selection indicator
        local indicator = Instance.new("Frame")
        indicator.Name = "Indicator"
        indicator.Size = UDim2.new(0, 3, 1, 0)
        indicator.Position = UDim2.new(0, 0, 0, 0)
        indicator.BackgroundColor3 = Constants.UI_COLORS.PRIMARY
        indicator.BorderSizePixel = 0
        indicator.Visible = false
        indicator.Parent = tab
        
        -- Tab functionality
        tab.MouseButton1Click:Connect(function()
            self:SelectTier(tierInfo.name)
        end)
        
        -- Hover effects
        tab.MouseEnter:Connect(function()
            if self.currentTier ~= tierInfo.name then
                TweenService:Create(tab, TweenInfo.new(0.2), {
                    BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                }):Play()
            end
        end)
        
        tab.MouseLeave:Connect(function()
            if self.currentTier ~= tierInfo.name then
                TweenService:Create(tab, TweenInfo.new(0.2), {
                    BackgroundColor3 = Constants.UI_COLORS.SECONDARY
                }):Play()
            end
        end)
    end
end

function InventoryManager:CreateItemsContainer()
    -- Container frame
    local containerFrame = Instance.new("Frame")
    containerFrame.Name = "ContainerFrame"
    containerFrame.Size = UDim2.new(1, -CONFIG.SIDEBAR_WIDTH - 30, 1, -70)
    containerFrame.Position = UDim2.new(0, CONFIG.SIDEBAR_WIDTH + 20, 0, 60)
    containerFrame.BackgroundColor3 = Constants.UI_COLORS.SECONDARY
    containerFrame.BackgroundTransparency = 0.8
    containerFrame.BorderSizePixel = 0
    containerFrame.Parent = self.mainFrame
    
    local containerCorner = Instance.new("UICorner")
    containerCorner.CornerRadius = UDim.new(0, 6)
    containerCorner.Parent = containerFrame
    
    -- Scrolling frame for items
    self.itemsContainer = Instance.new("ScrollingFrame")
    self.itemsContainer.Name = "ItemsContainer"
    self.itemsContainer.Size = UDim2.new(1, -20, 1, -20)
    self.itemsContainer.Position = UDim2.new(0, 10, 0, 10)
    self.itemsContainer.BackgroundTransparency = 1
    self.itemsContainer.BorderSizePixel = 0
    self.itemsContainer.ScrollBarThickness = 8
    self.itemsContainer.ScrollBarImageColor3 = Constants.UI_COLORS.PRIMARY
    self.itemsContainer.Parent = containerFrame
    
    -- Grid layout for items
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = CONFIG.ITEM_SIZE
    gridLayout.CellPadding = UDim2.new(0, CONFIG.ITEM_PADDING, 0, CONFIG.ITEM_PADDING)
    gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    gridLayout.Parent = self.itemsContainer
    
    -- No items label
    local noItemsLabel = Instance.new("TextLabel")
    noItemsLabel.Name = "NoItemsLabel"
    noItemsLabel.Size = UDim2.new(1, 0, 0, 100)
    noItemsLabel.Position = UDim2.new(0, 0, 0.4, 0)
    noItemsLabel.BackgroundTransparency = 1
    noItemsLabel.Text = "No items in this category"
    noItemsLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    noItemsLabel.TextSize = 18
    noItemsLabel.Font = Enum.Font.Gotham
    noItemsLabel.TextWrapped = true
    noItemsLabel.Visible = false
    noItemsLabel.Parent = containerFrame
end

function InventoryManager:CreateNotificationSystem()
    self.notificationContainer = Instance.new("Frame")
    self.notificationContainer.Name = "NotificationContainer"
    self.notificationContainer.Size = UDim2.new(0, 300, 0, 200)
    self.notificationContainer.Position = UDim2.new(1, -320, 0, 20)
    self.notificationContainer.BackgroundTransparency = 1
    self.notificationContainer.Parent = self.gui
    
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 5)
    layout.Parent = self.notificationContainer
end

function InventoryManager:CreateInventoryButton()
    -- Create inventory button in a separate ScreenGui
    local buttonGui = Instance.new("ScreenGui")
    buttonGui.Name = "InventoryButtonUI"
    buttonGui.ResetOnSpawn = false
    buttonGui.Parent = self.player.PlayerGui
    
    local button = Instance.new("TextButton")
    button.Name = "InventoryButton"
    button.Size = UDim2.new(0, 120, 0, 40)
    button.Position = UDim2.new(0.5, -60, 1, -60)
    button.BackgroundColor3 = Constants.UI_COLORS.SECONDARY
    button.Text = "Inventory"
    button.TextColor3 = Constants.UI_COLORS.TEXT
    button.TextSize = 18
    button.Font = Enum.Font.GothamBold
    button.BorderSizePixel = 0
    button.Parent = buttonGui
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 4)
    buttonCorner.Parent = button
    
    -- Button functionality
    button.MouseButton1Click:Connect(function()
        self:Toggle()
    end)
    
    -- Hover effects
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {
            BackgroundColor3 = Constants.UI_COLORS.PRIMARY
        }):Play()
    end)
    
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {
            BackgroundColor3 = Constants.UI_COLORS.SECONDARY
        }):Play()
    end)
end

function InventoryManager:SetupInputHandling()
    -- Tab key to toggle inventory
    local connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.Tab then
            self:Toggle()
        end
    end)
    table.insert(self.connections, connection)
    
    print("[InventoryManager] Input handling setup complete")
end

function InventoryManager:StartUpdateLoop()
    local connection = RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        if currentTime - self.lastUpdateTime >= CONFIG.UPDATE_INTERVAL then
            self:Update()
            self.lastUpdateTime = currentTime
        end
    end)
    table.insert(self.connections, connection)
    
    print("[InventoryManager] Update loop started")
end

function InventoryManager:SetupEventHandlers()
    -- Listen for inventory updates from server
    if self.remotes.AddToInventory then
        local connection = self.remotes.AddToInventory.OnClientEvent:Connect(function(itemData)
            self:OnItemAdded(itemData)
        end)
        table.insert(self.connections, connection)
    end
end

function InventoryManager:Update()
    if not self.isActive then return end
    
    -- Periodic refresh of inventory data if visible
    if self.isVisible then
        self:RefreshInventory()
    end
end

function InventoryManager:SelectTier(tierName)
    self.currentTier = tierName
    
    -- Update tab appearance
    if self.sidebar then
        for _, tab in ipairs(self.sidebar:GetChildren()) do
            if tab:IsA("TextButton") then
                local indicator = tab:FindFirstChild("Indicator")
                local isSelected = tab.Name == tierName .. "Tab"
                
                if isSelected then
                    -- Selected state
                    tab.BackgroundColor3 = Constants.UI_COLORS.WARNING
                    tab.TextColor3 = Color3.new(0, 0, 0)
                    if indicator then indicator.Visible = true end
                else
                    -- Unselected state
                    tab.BackgroundColor3 = Constants.UI_COLORS.SECONDARY
                    tab.TextColor3 = Color3.new(0.8, 0.8, 0.8)
                    if indicator then indicator.Visible = false end
                end
            end
        end
    end
    
    -- Update the inventory display
    self:UpdateInventoryDisplay()
    
    if CONFIG.DEBUG_MODE then
        print("[InventoryManager] Selected tier:", tierName)
    end
end

function InventoryManager:GetTierCategory(itemTier)
    if not itemTier then
        return "Other"
    end
    
    for _, tierTab in ipairs(TIER_TABS) do
        for _, tier in ipairs(tierTab.tiers) do
            if tier == itemTier then
                return tierTab.name
            end
        end
    end
    
    return "Other"
end

function InventoryManager:ItemBelongsToTier(item, selectedTier)
    local itemTier = item.tier
    local category = self:GetTierCategory(itemTier)
    return category == selectedTier
end

function InventoryManager:CreateItemButton(displayName, itemInfo, quantity)
    local button = Instance.new("TextButton")
    button.Size = CONFIG.ITEM_SIZE
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    button.BorderSizePixel = 0
    button.Text = ""
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button
    
    -- Item icon (placeholder)
    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0.7, 0, 0.6, 0)
    icon.Position = UDim2.new(0.15, 0, 0.05, 0)
    icon.BackgroundTransparency = 1
    icon.Image = itemInfo.icon or ""
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Parent = button
    
    -- If no icon, show placeholder
    if not itemInfo.icon or itemInfo.icon == "" then
        icon.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        icon.BackgroundTransparency = 0
        
        local iconCorner = Instance.new("UICorner")
        iconCorner.CornerRadius = UDim.new(0, 4)
        iconCorner.Parent = icon
    end
    
    -- Item name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -10, 0.25, 0)
    nameLabel.Position = UDim2.new(0, 5, 0.65, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = displayName
    nameLabel.TextColor3 = Constants.UI_COLORS.TEXT
    nameLabel.TextSize = 12
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextWrapped = true
    nameLabel.TextScaled = true
    nameLabel.Parent = button
    
    -- Quantity badge
    if quantity > 1 then
        local quantityBadge = Instance.new("Frame")
        quantityBadge.Size = UDim2.new(0, 25, 0, 20)
        quantityBadge.Position = UDim2.new(1, -30, 0, 5)
        quantityBadge.BackgroundColor3 = Constants.UI_COLORS.PRIMARY
        quantityBadge.BorderSizePixel = 0
        quantityBadge.Parent = button
        
        local badgeCorner = Instance.new("UICorner")
        badgeCorner.CornerRadius = UDim.new(0, 10)
        badgeCorner.Parent = quantityBadge
        
        local quantityLabel = Instance.new("TextLabel")
        quantityLabel.Size = UDim2.new(1, 0, 1, 0)
        quantityLabel.BackgroundTransparency = 1
        quantityLabel.Text = tostring(quantity)
        quantityLabel.TextColor3 = Constants.UI_COLORS.TEXT
        quantityLabel.TextSize = 12
        quantityLabel.Font = Enum.Font.GothamBold
        quantityLabel.Parent = quantityBadge
    end
    
    -- Hover effects
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        }):Play()
    end)
    
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        }):Play()
    end)
    
    return button
end

function InventoryManager:UpdateInventoryDisplay()
    if not self.itemsContainer then
        warn("[InventoryManager] Items container not found")
        return
    end
    
    -- Clear existing items
    for _, child in ipairs(self.itemsContainer:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    local itemCount = 0
    
    -- Filter and display items for current tier
    for itemName, item in pairs(self.inventoryData) do
        if self:ItemBelongsToTier(item, self.currentTier) then
            local quantity = item.quantity or 1
            
            -- Clean up display name
            local displayName = itemName:gsub("_", " ")
            displayName = displayName:gsub("Cube", "")
            displayName = displayName:gsub("  ", " ")
            displayName = displayName:gsub("^%s+", ""):gsub("%s+$", "")
            
            -- Capitalize first letter of each word
            displayName = displayName:gsub("(%a)([%w_']*)", function(first, rest)
                return first:upper() .. rest:lower()
            end)
            
            -- Get item info
            local itemInfo = {
                icon = (Constants.ITEMS[itemName] and Constants.ITEMS[itemName].icon) or item.icon or nil,
                tier = item.tier or "COMMON"
            }
            
            -- Create button
            local button = self:CreateItemButton(displayName, itemInfo, quantity)
            button.Parent = self.itemsContainer
            
            -- Store original item name
            button:SetAttribute("originalItemName", itemName)
            
            -- Set up click handler
            button.MouseButton1Click:Connect(function()
                self:OnItemClicked(itemName, {
                    id = itemName,
                    name = itemName,
                    displayName = displayName,
                    count = quantity,
                    tier = item.tier
                })
            end)
            
            itemCount = itemCount + 1
        end
    end
    
    -- Show/hide no items message
    local containerFrame = self.itemsContainer.Parent
    local noItemsLabel = containerFrame:FindFirstChild("NoItemsLabel")
    if noItemsLabel then
        noItemsLabel.Visible = (itemCount == 0)
        if itemCount == 0 then
            noItemsLabel.Text = "No items in " .. self.currentTier .. " category."
        end
    end
    
    -- Update canvas size
    local rows = math.ceil(itemCount / CONFIG.ITEMS_PER_ROW)
    self.itemsContainer.CanvasSize = UDim2.new(0, 0, 0, rows * (CONFIG.ITEM_SIZE.Y.Offset + CONFIG.ITEM_PADDING) + CONFIG.ITEM_PADDING)
    
    if CONFIG.DEBUG_MODE then
        print("[InventoryManager] Updated display with", itemCount, "items in", self.currentTier, "tier")
    end
end

function InventoryManager:OnItemClicked(itemName, itemData)
    print("[InventoryManager] Item clicked:", itemName)
    
    -- Hide inventory
    self:Hide()
    
    -- Call callback if set
    if self.OnItemSelected then
        task.delay(0.1, function()
            self.OnItemSelected(itemName, itemData)
        end)
    end
    
    -- Show notification
    self:ShowNotification("Selected: " .. itemData.displayName)
end

function InventoryManager:RefreshInventory()
    if not self.remotes.GetInventory then
        warn("[InventoryManager] GetInventory remote not available")
        return
    end
    
    local success, result = pcall(function()
        return self.remotes.GetInventory:InvokeServer()
    end)
    
    if success and result then
        if type(result) == "table" then
            if result.success ~= false then
                self:UpdateInventory(result.inventory or result, result.currency or 0)
            else
                warn("[InventoryManager] Server returned error:", result.message)
            end
        else
            warn("[InventoryManager] Unexpected result format:", type(result))
        end
    else
        warn("[InventoryManager] Failed to get inventory:", result)
    end
end

function InventoryManager:UpdateInventory(inventory, currency)
    self.inventoryData = inventory or {}
    self.currency = currency or 0
    
    -- Update currency display
    if self.mainFrame then
        local currencyLabel = self.mainFrame:FindFirstChild("TitleBar"):FindFirstChild("CurrencyFrame"):FindFirstChild("Currency")
        if currencyLabel then
            currencyLabel.Text = tostring(self.currency) .. " " .. (Constants.GAME.DEFAULT_CURRENCY or "Coins")
        end
    end
    
    -- Update display
    self:UpdateInventoryDisplay()
    
    if CONFIG.DEBUG_MODE then
        print("[InventoryManager] Updated inventory:", self:CountTable(self.inventoryData), "items,", self.currency, "currency")
    end
end

function InventoryManager:OnItemAdded(itemData)
    print("[InventoryManager] Item added to inventory:", itemData.id)
    
    -- Add to local data
    if self.inventoryData[itemData.id] then
        self.inventoryData[itemData.id].quantity = (self.inventoryData[itemData.id].quantity or 1) + (itemData.quantity or 1)
    else
        self.inventoryData[itemData.id] = itemData
    end
    
    -- Update display if visible
    if self.isVisible then
        self:UpdateInventoryDisplay()
    end
    
    -- Show notification
    self:ShowNotification("Added: " .. (itemData.displayName or itemData.id))
end

function InventoryManager:Toggle()
    if self.isVisible then
        self:Hide()
    else
        self:Show()
    end
end

function InventoryManager:Show()
    if not self.mainFrame then
        warn("[InventoryManager] UI not initialized")
        return
    end
    
    print("[InventoryManager] Showing inventory")
    
    -- Refresh data before showing
    self:RefreshInventory()
    
    -- Select default tier
    self:SelectTier(self.currentTier)
    
    -- Show with animation
    self.mainFrame.Visible = true
    self.mainFrame.BackgroundTransparency = 1
    
    local showTween = TweenService:Create(self.mainFrame, TweenInfo.new(CONFIG.ANIMATION_DURATION), {
        BackgroundTransparency = 0
    })
    showTween:Play()
    
    self.isVisible = true
end

function InventoryManager:Hide()
    if not self.mainFrame then
        return
    end
    
    print("[InventoryManager] Hiding inventory")
    
    local hideTween = TweenService:Create(self.mainFrame, TweenInfo.new(CONFIG.ANIMATION_DURATION), {
        BackgroundTransparency = 1
    })
    
    hideTween.Completed:Connect(function()
        self.mainFrame.Visible = false
    end)
    
    hideTween:Play()
    self.isVisible = false
end

function InventoryManager:ShowNotification(message, duration)
    if not self.notificationContainer then return end
    
    duration = duration or CONFIG.NOTIFICATION_DURATION
    
    -- Create notification frame
    local notification = Instance.new("Frame")
    notification.Size = UDim2.new(1, 0, 0, 40)
    notification.BackgroundColor3 = Constants.UI_COLORS.SECONDARY
    notification.BackgroundTransparency = 0.2
    notification.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = notification
    
    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, -20, 1, 0)
    text.Position = UDim2.new(0, 10, 0, 0)
    text.BackgroundTransparency = 1
    text.TextColor3 = Constants.UI_COLORS.TEXT
    text.TextSize = 16
    text.Font = Enum.Font.Gotham
    text.Text = message
    text.TextWrapped = true
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.Parent = notification
    
    notification.Parent = self.notificationContainer
    
    -- Animate in
    notification.Position = UDim2.new(1, 20, 0, 0)
    notification:TweenPosition(UDim2.new(0, 0, 0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.3, true)
    
    -- Store and manage notifications
    table.insert(self.notifications, notification)
    
    -- Remove old notifications if too many
    while #self.notifications > CONFIG.MAX_NOTIFICATIONS do
        local oldest = table.remove(self.notifications, 1)
        if oldest and oldest.Parent then
            oldest:Destroy()
        end
    end
    
    -- Auto-remove after duration
    task.spawn(function()
        task.wait(duration - 0.3)
        notification:TweenPosition(UDim2.new(1, 20, 0, 0), Enum.EasingDirection.In, Enum.EasingStyle.Quart, 0.3, true)
        task.wait(0.3)
        
        if notification and notification.Parent then
            notification:Destroy()
            
            -- Remove from notifications list
            for i, notif in ipairs(self.notifications) do
                if notif == notification then
                    table.remove(self.notifications, i)
                    break
                end
            end
        end
    end)
end

function InventoryManager:CountTable(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

function InventoryManager:Cleanup()
    print("[InventoryManager] Cleaning up...")
    
    self.isActive = false
    
    -- Disconnect all connections
    for _, connection in ipairs(self.connections) do
        if connection then
            connection:Disconnect()
        end
    end
    self.connections = {}
    
    -- Clean up UI
    if self.gui then
        self.gui:Destroy()
    end
    
    print("[InventoryManager] Cleanup complete")
end

return InventoryManager 