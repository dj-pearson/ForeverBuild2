-- InteractionManager.luau
-- Unified interaction system that consolidates all interaction functionality
-- Replaces the multiple conflicting interaction modules

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Import SecurityValidator for enterprise-level security
local SecurityValidator
local securityValidator
if RunService:IsClient() then
    local success, result = pcall(function()
        return require(ReplicatedStorage.src.shared.security.SecurityValidator)
    end)
    if success then
        SecurityValidator = result
        securityValidator = SecurityValidator.new()
        print("InteractionManager: SecurityValidator loaded successfully")
    else
        warn("InteractionManager: Failed to load SecurityValidator:", result)
    end
end

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
        print("[InteractionManager] Successfully loaded SharedModule")
        return true
    else
        warn("[InteractionManager] Failed to load SharedModule:", result)
        return false
    end
end

-- Initialize with fallbacks
if not loadSharedModule() then
    print("[InteractionManager] Creating fallback systems")
    Constants = {
        INTERACTION_DISTANCE = 10,
        CURRENCY = { INGAME = "Coins" },
        ITEMS = {},
        UI_COLORS = {
            PRIMARY = Color3.fromRGB(0, 170, 255),
            SECONDARY = Color3.fromRGB(40, 40, 40),
            TEXT = Color3.fromRGB(255, 255, 255)
        }
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

local InteractionManager = {}
InteractionManager.__index = InteractionManager

-- Configuration
local CONFIG = {
    INTERACTION_DISTANCE = Constants.INTERACTION_DISTANCE or 10,
    UPDATE_INTERVAL = 0.1,
    DEBUG_MODE = false,
    MAX_NOTIFICATIONS = 5,
    NOTIFICATION_DURATION = 4
}

function InteractionManager.new()
    local self = setmetatable({}, InteractionManager)
    
    -- Core properties
    self.player = Players.LocalPlayer
    self.currentTarget = nil
    self.isActive = false
    
    -- UI components
    self.billboardTemplate = nil
    self.currentUI = nil
    self.notificationContainer = nil
    self.notifications = {}
    
    -- Connections for cleanup
    self.connections = {}
    
    -- Remote events
    self.remotes = {}
    
    -- State tracking
    self.lastUpdateTime = 0
    self.interactables = {}
    
    return self
end

function InteractionManager:Initialize()
    print("[InteractionManager] Initializing...")
    
    if not self.player then
        warn("[InteractionManager] No LocalPlayer found")
        return false
    end
    
    -- Setup remote events
    self:SetupRemoteEvents()
    
    -- Create UI components
    self:CreateUIComponents()
    
    -- Setup input handling
    self:SetupInputHandling()
    
    -- Start update loop
    self:StartUpdateLoop()
    
    self.isActive = true
    print("[InteractionManager] Initialization complete")
    return true
end

function InteractionManager:SetupRemoteEvents()
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotesFolder then
        remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
    end
    
    if not remotesFolder then
        warn("[InteractionManager] Remotes folder not found")
        return
    end
    
    -- Cache commonly used remote events
    local remoteNames = {
        "PurchaseItem", "InteractWithItem", "UseItem", "CollectItem",
        "ToggleItemState", "SearchContainer", "NPCInteraction"
    }
    
    for _, remoteName in ipairs(remoteNames) do
        local remote = remotesFolder:FindFirstChild(remoteName)
        if remote then
            self.remotes[remoteName] = remote
        else
            if CONFIG.DEBUG_MODE then
                warn("[InteractionManager] Remote not found:", remoteName)
            end
        end
    end
    
    print("[InteractionManager] Remote events cached:", #remoteNames, "requested,", 
          self:CountTable(self.remotes), "found")
end

function InteractionManager:CreateUIComponents()
    -- Create billboard template for proximity indicators
    self.billboardTemplate = Instance.new("BillboardGui")
    self.billboardTemplate.Size = UDim2.new(0, 200, 0, 50)
    self.billboardTemplate.StudsOffset = Vector3.new(0, 3, 0)
    self.billboardTemplate.AlwaysOnTop = true
    self.billboardTemplate.Enabled = false
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Constants.UI_COLORS.SECONDARY
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = self.billboardTemplate
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Constants.UI_COLORS.PRIMARY
    stroke.Thickness = 2
    stroke.Parent = frame
    
    local label = Instance.new("TextLabel")
    label.Name = "InteractionLabel"
    label.Size = UDim2.new(1, -10, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Constants.UI_COLORS.TEXT
    label.TextSize = 18
    label.Font = Enum.Font.GothamBold
    label.Text = "[E] Interact"
    label.TextScaled = true
    label.Parent = frame
    
    -- Create notification container
    self:CreateNotificationSystem()
    
    print("[InteractionManager] UI components created")
end

function InteractionManager:CreateNotificationSystem()
    local playerGui = self.player:FindFirstChild("PlayerGui")
    if not playerGui then return end
    
    local screenGui = playerGui:FindFirstChild("InteractionNotifications")
    if screenGui then screenGui:Destroy() end
    
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "InteractionNotifications"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    self.notificationContainer = Instance.new("Frame")
    self.notificationContainer.Name = "NotificationContainer"
    self.notificationContainer.Size = UDim2.new(0, 300, 0, 200)
    self.notificationContainer.Position = UDim2.new(1, -320, 0, 20)
    self.notificationContainer.BackgroundTransparency = 1
    self.notificationContainer.Parent = screenGui
    
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 5)
    layout.Parent = self.notificationContainer
end

function InteractionManager:SetupInputHandling()
    -- Primary interaction key (E)
    local connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.E then
            self:HandleInteraction()
        end
    end)
    table.insert(self.connections, connection)
    
    -- Touch support for mobile
    local touchConnection = UserInputService.TouchTap:Connect(function(touchPositions, gameProcessed)
        if gameProcessed or not self.currentTarget then return end
        
        -- Simple touch interaction - if we have a target, interact with it
        self:HandleInteraction()
    end)
    table.insert(self.connections, touchConnection)
    
    print("[InteractionManager] Input handling setup complete")
end

function InteractionManager:StartUpdateLoop()
    local connection = RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        if currentTime - self.lastUpdateTime >= CONFIG.UPDATE_INTERVAL then
            self:Update()
            self.lastUpdateTime = currentTime
        end
    end)
    table.insert(self.connections, connection)
    
    print("[InteractionManager] Update loop started")
end

function InteractionManager:Update()
    if not self.isActive then return end
    
    local nearbyInteractables = self:FindNearbyInteractables()
    
    if #nearbyInteractables > 0 then
        local closest = nearbyInteractables[1]
        if not self.currentTarget or self.currentTarget.instance ~= closest.instance then
            self:SetTarget(closest)
        end
    else
        if self.currentTarget then
            self:ClearTarget()
        end
    end
end

function InteractionManager:FindNearbyInteractables()
    local character = self.player.Character
    if not character then return {} end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return {} end
    
    local playerPosition = rootPart.Position
    local interactables = {}
    
    -- Search in multiple locations for interactable items
    local searchLocations = {
        workspace:FindFirstChild("PlacedItems"),
        workspace:FindFirstChild("World_Items") and workspace.World_Items:FindFirstChild("Placed"),
        workspace:FindFirstChild("Items")
    }
    
    for _, location in ipairs(searchLocations) do
        if location then
            self:ScanForInteractables(location, playerPosition, interactables)
        end
    end
    
    -- Sort by distance
    table.sort(interactables, function(a, b)
        return a.distance < b.distance
    end)
    
    return interactables
end

function InteractionManager:ScanForInteractables(parent, playerPosition, results)
    for _, child in ipairs(parent:GetChildren()) do
        if self:IsInteractable(child) then
            local position = self:GetInstancePosition(child)
            if position then
                local distance = (position - playerPosition).Magnitude
                if distance <= CONFIG.INTERACTION_DISTANCE then
                    table.insert(results, {
                        instance = child,
                        position = position,
                        distance = distance,
                        id = child:GetAttribute("ItemID") or child.Name
                    })
                end
            end
        elseif child:IsA("Folder") then
            -- Recursively search folders
            self:ScanForInteractables(child, playerPosition, results)
        end
    end
end

function InteractionManager:IsInteractable(instance)
    -- Check if an instance can be interacted with
    return instance:GetAttribute("Interactable") == true or
           instance:GetAttribute("Purchasable") == true or
           instance:GetAttribute("Price") ~= nil or
           instance:GetAttribute("InteractionType") ~= nil
end

function InteractionManager:GetInstancePosition(instance)
    if instance:IsA("Model") then
        return instance:GetPivot().Position
    elseif instance:IsA("BasePart") then
        return instance.Position
    end
    return nil
end

function InteractionManager:SetTarget(targetData)
    self:ClearTarget()
    
    self.currentTarget = targetData
    self:ShowInteractionUI(targetData)
    
    if CONFIG.DEBUG_MODE then
        print("[InteractionManager] Target set:", targetData.id)
    end
end

function InteractionManager:ClearTarget()
    if self.currentTarget then
        self:HideInteractionUI()
        self.currentTarget = nil
        
        if CONFIG.DEBUG_MODE then
            print("[InteractionManager] Target cleared")
        end
    end
end

function InteractionManager:ShowInteractionUI(targetData)
    if not targetData or not targetData.instance then return end
    
    local billboard = self.billboardTemplate:Clone()
    billboard.Adornee = targetData.instance
    billboard.Enabled = true
    
    local label = billboard:FindFirstChild("InteractionLabel", true)
    if label then
        local interactionText = self:GetInteractionText(targetData)
        label.Text = interactionText
    end
    
    billboard.Parent = self.player.PlayerGui
    self.currentUI = billboard
    
    -- Add highlight effect
    self:AddHighlight(targetData.instance)
end

function InteractionManager:HideInteractionUI()
    if self.currentUI then
        self.currentUI:Destroy()
        self.currentUI = nil
    end
    
    self:RemoveHighlight()
end

function InteractionManager:GetInteractionText(targetData)
    local instance = targetData.instance
    
    -- Check for purchase items
    if instance:GetAttribute("Purchasable") or instance:GetAttribute("Price") then
        return "[E] Purchase"
    end
    
    -- Check interaction type
    local interactionType = instance:GetAttribute("InteractionType")
    if interactionType then
        if interactionType == "PICKUP" then
            return "[E] Pick Up"
        elseif interactionType == "USE" then
            return "[E] Use"
        elseif interactionType == "CUSTOMIZE" then
            return "[E] Customize"
        end
    end
    
    -- Default interaction
    return "[E] Interact"
end

function InteractionManager:AddHighlight(instance)
    self:RemoveHighlight()
    
    local highlight = Instance.new("Highlight")
    highlight.FillColor = Constants.UI_COLORS.PRIMARY
    highlight.OutlineColor = Constants.UI_COLORS.PRIMARY
    highlight.FillTransparency = 0.7
    highlight.OutlineTransparency = 0
    highlight.Parent = instance
    
    self.currentHighlight = highlight
end

function InteractionManager:RemoveHighlight()
    if self.currentHighlight then
        self.currentHighlight:Destroy()
        self.currentHighlight = nil
    end
end

function InteractionManager:HandleInteraction()
    if not self.currentTarget then return end
    
    local instance = self.currentTarget.instance
    local interactionType = self:DetermineInteractionType(instance)
    
    if CONFIG.DEBUG_MODE then
        print("[InteractionManager] Handling interaction:", interactionType, "for", self.currentTarget.id)
    end
    
    -- Route to appropriate handler
    if interactionType == "purchase" then
        self:HandlePurchase(self.currentTarget)
    elseif interactionType == "pickup" then
        self:HandlePickup(self.currentTarget)
    elseif interactionType == "use" then
        self:HandleUse(self.currentTarget)
    elseif interactionType == "customize" then
        self:HandleCustomize(self.currentTarget)
    else
        self:HandleGenericInteraction(self.currentTarget)
    end
end

function InteractionManager:DetermineInteractionType(instance)
    -- Determine what type of interaction this should be
    if instance:GetAttribute("Purchasable") or instance:GetAttribute("Price") then
        return "purchase"
    end
    
    local interactionType = instance:GetAttribute("InteractionType")
    if interactionType then
        return interactionType:lower()
    end
    
    return "generic"
end

function InteractionManager:HandlePurchase(targetData)
    -- 🔒 SECURITY VALIDATION - Enterprise-level purchase validation
    if securityValidator then
        -- Validate targetData structure
        if not targetData or typeof(targetData) ~= "table" then
            warn("🚨 SECURITY: Invalid targetData in HandlePurchase")
            self:ShowNotification("Invalid purchase request")
            return
        end
        
        -- Validate instance
        if not targetData.instance or not targetData.instance.Parent then
            warn("🚨 SECURITY: Invalid instance in HandlePurchase")
            self:ShowNotification("Invalid item for purchase")
            return
        end
        
        -- Validate targetData.id
        if targetData.id then
            local idValidation = securityValidator:ValidateString(targetData.id, "TargetId", {maxLength = 100})
            if not idValidation.success then
                warn("🚨 SECURITY: Invalid target ID in HandlePurchase:", idValidation.error)
                self:ShowNotification("Invalid item identifier")
                return
            end
        end
        
        print("✅ SECURITY: Purchase validation passed for", targetData.id or "unknown")
    else
        warn("⚠️ SECURITY: SecurityValidator not available for purchase validation")
    end

    local instance = targetData.instance
    local price = instance:GetAttribute("Price") or instance:GetAttribute("priceIngame") or 50
    local itemName = instance.Name:gsub("_", " ")
    
    -- Additional security: Validate price
    if securityValidator then
        local priceValidation = securityValidator:ValidateCurrency(price, "INGAME", self.player)
        if not priceValidation.success then
            warn("🚨 SECURITY: Invalid price in HandlePurchase:", priceValidation.error)
            self:ShowNotification("Invalid item price")
            return
        end
        price = priceValidation.data.amount
    end
    
    -- Use the BottomPurchasePopup if available
    local BottomPurchasePopup = self:TryRequireModule("BottomPurchasePopup")
    if BottomPurchasePopup and BottomPurchasePopup.ShowPurchaseDialog then
        BottomPurchasePopup.ShowPurchaseDialog(instance, {
            itemName = itemName,
            price = price,
            onPurchase = function(currencyType)
                self:ExecutePurchase(targetData.id, currencyType)
            end
        })
        return
    end
    
    -- Fallback to simple purchase dialog
    self:ShowSimplePurchaseDialog(targetData, itemName, price)
end

function InteractionManager:HandlePickup(targetData)
    -- 🔒 SECURITY VALIDATION - Enterprise-level pickup validation
    if securityValidator then
        -- Validate targetData
        if not targetData or typeof(targetData) ~= "table" then
            warn("🚨 SECURITY: Invalid targetData in HandlePickup")
            self:ShowNotification("Invalid pickup request")
            return
        end
        
        -- Validate targetData.id
        if targetData.id then
            local idValidation = securityValidator:ValidateString(targetData.id, "PickupId", {maxLength = 100})
            if not idValidation.success then
                warn("🚨 SECURITY: Invalid pickup ID:", idValidation.error)
                self:ShowNotification("Invalid item for pickup")
                return
            end
        end
        
        print("✅ SECURITY: Pickup validation passed for", targetData.id or "unknown")
    end

    if self.remotes.CollectItem then
        local success = self.remotes.CollectItem:InvokeServer(targetData.id)
        if success then
            self:ShowNotification("Picked up " .. targetData.id)
            self:ClearTarget()
        else
            self:ShowNotification("Cannot pick up item")
        end
    else
        self:ShowNotification("Pickup not available")
    end
end

function InteractionManager:HandleUse(targetData)
    -- 🔒 SECURITY VALIDATION - Enterprise-level use validation
    if securityValidator then
        -- Validate targetData
        if not targetData or typeof(targetData) ~= "table" then
            warn("🚨 SECURITY: Invalid targetData in HandleUse")
            self:ShowNotification("Invalid use request")
            return
        end
        
        -- Validate targetData.id
        if targetData.id then
            local idValidation = securityValidator:ValidateString(targetData.id, "UseId", {maxLength = 100})
            if not idValidation.success then
                warn("🚨 SECURITY: Invalid use ID:", idValidation.error)
                self:ShowNotification("Invalid item for use")
                return
            end
        end
        
        print("✅ SECURITY: Use validation passed for", targetData.id or "unknown")
    end

    if self.remotes.UseItem then
        local success, message = self.remotes.UseItem:InvokeServer(targetData.id)
        self:ShowNotification(message or (success and "Used " .. targetData.id or "Cannot use item"))
    else
        self:ShowNotification("Use not available")
    end
end

function InteractionManager:HandleCustomize(targetData)
    -- Open customization UI (placeholder)
    self:ShowNotification("Customization coming soon!")
end

function InteractionManager:HandleGenericInteraction(targetData)
    if self.remotes.InteractWithItem then
        self.remotes.InteractWithItem:FireServer(targetData.id)
        self:ShowNotification("Interacted with " .. targetData.id)
    else
        self:ShowNotification("Interaction not available")
    end
end

function InteractionManager:ExecutePurchase(itemId, currencyType)
    -- 🔒 SECURITY VALIDATION - Enterprise-level purchase execution validation
    if securityValidator then
        -- Validate itemId
        if not itemId or typeof(itemId) ~= "string" then
            warn("🚨 SECURITY: Invalid itemId in ExecutePurchase")
            self:ShowNotification("Invalid purchase item")
            return
        end
        
        local itemIdValidation = securityValidator:ValidateString(itemId, "PurchaseItemId", {maxLength = 100})
        if not itemIdValidation.success then
            warn("🚨 SECURITY: Invalid purchase itemId:", itemIdValidation.error)
            self:ShowNotification("Invalid item for purchase")
            return
        end
        
        -- Validate currencyType
        if currencyType then
            local currencyTypeValidation = securityValidator:ValidateString(currencyType, "CurrencyType", {maxLength = 20})
            if not currencyTypeValidation.success then
                warn("🚨 SECURITY: Invalid currency type:", currencyTypeValidation.error)
                self:ShowNotification("Invalid currency type")
                return
            end
            
            -- Ensure currency type is from allowed list
            local allowedCurrencies = {"INGAME", "ROBUX", "COINS", "GEMS"}
            if not table.find(allowedCurrencies, currencyType) then
                warn("🚨 SECURITY: Unauthorized currency type:", currencyType)
                self:ShowNotification("Unauthorized currency type")
                return
            end
        end
        
        print("✅ SECURITY: Purchase execution validation passed for", itemId, "with currency", currencyType or "default")
    end

    if self.remotes.PurchaseItem then
        self.remotes.PurchaseItem:FireServer(itemId, 1, currencyType)
        self:ShowNotification("Purchase request sent")
    else
        self:ShowNotification("Purchase not available")
    end
end

function InteractionManager:ShowSimplePurchaseDialog(targetData, itemName, price)
    -- Create a simple purchase confirmation dialog
    local playerGui = self.player:FindFirstChild("PlayerGui")
    if not playerGui then return end
    
    -- Remove existing dialog
    local existing = playerGui:FindFirstChild("SimplePurchaseDialog")
    if existing then existing:Destroy() end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SimplePurchaseDialog"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Background overlay
    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.BorderSizePixel = 0
    overlay.Parent = screenGui
    
    -- Dialog frame
    local dialog = Instance.new("Frame")
    dialog.Size = UDim2.new(0, 300, 0, 200)
    dialog.Position = UDim2.new(0.5, -150, 0.5, -100)
    dialog.BackgroundColor3 = Constants.UI_COLORS.SECONDARY
    dialog.BorderSizePixel = 0
    dialog.Parent = overlay
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = dialog
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 40)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "Purchase " .. itemName
    title.TextColor3 = Constants.UI_COLORS.TEXT
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.Parent = dialog
    
    -- Price label
    local priceLabel = Instance.new("TextLabel")
    priceLabel.Size = UDim2.new(1, -20, 0, 30)
    priceLabel.Position = UDim2.new(0, 10, 0, 60)
    priceLabel.BackgroundTransparency = 1
    priceLabel.Text = "Price: " .. price .. " Coins"
    priceLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    priceLabel.TextSize = 16
    priceLabel.Font = Enum.Font.Gotham
    priceLabel.Parent = dialog
    
    -- Buttons
    local buyButton = Instance.new("TextButton")
    buyButton.Size = UDim2.new(0.4, 0, 0, 35)
    buyButton.Position = UDim2.new(0.05, 0, 0, 120)
    buyButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
    buyButton.Text = "Buy"
    buyButton.TextColor3 = Constants.UI_COLORS.TEXT
    buyButton.TextSize = 16
    buyButton.Font = Enum.Font.GothamBold
    buyButton.Parent = dialog
    
    local cancelButton = Instance.new("TextButton")
    cancelButton.Size = UDim2.new(0.4, 0, 0, 35)
    cancelButton.Position = UDim2.new(0.55, 0, 0, 120)
    cancelButton.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
    cancelButton.Text = "Cancel"
    cancelButton.TextColor3 = Constants.UI_COLORS.TEXT
    cancelButton.TextSize = 16
    cancelButton.Font = Enum.Font.GothamBold
    cancelButton.Parent = dialog
    
    -- Button functionality
    local function closeDialog()
        screenGui:Destroy()
    end
    
    buyButton.MouseButton1Click:Connect(function()
        self:ExecutePurchase(targetData.id, "INGAME")
        closeDialog()
    end)
    
    cancelButton.MouseButton1Click:Connect(closeDialog)
    overlay.MouseButton1Click:Connect(closeDialog)
end

function InteractionManager:ShowNotification(message, duration)
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

function InteractionManager:TryRequireModule(moduleName)
    -- Try multiple ways to require a module
    local attempts = {
        function() return require(script.Parent:WaitForChild(moduleName)) end,
        function() return LazyLoadModules.require(moduleName) end,
        function() return SharedModule[moduleName] end
    }
    
    for _, attempt in ipairs(attempts) do
        local success, result = pcall(attempt)
        if success and result then
            return result
        end
    end
    
    return nil
end

function InteractionManager:CountTable(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

function InteractionManager:Cleanup()
    print("[InteractionManager] Cleaning up...")
    
    self.isActive = false
    
    -- Disconnect all connections
    for _, connection in ipairs(self.connections) do
        if connection then
            connection:Disconnect()
        end
    end
    self.connections = {}
    
    -- Clean up UI
    self:ClearTarget()
    
    if self.notificationContainer and self.notificationContainer.Parent then
        self.notificationContainer.Parent:Destroy()
    end
    
    print("[InteractionManager] Cleanup complete")
end

return InteractionManager 