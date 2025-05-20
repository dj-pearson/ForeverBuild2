-- ItemInteractionClient.luau
-- Client-side module for interacting with catalog items and placed world items

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Import shared modules with fallback
print("ItemInteractionClient: Attempting to require shared module")
local SharedModule
local Constants

local success, errorMessage = pcall(function()
    SharedModule = require(ReplicatedStorage:WaitForChild("shared", 5))
    Constants = SharedModule.Constants
    return true
end)

if not success then
    warn("ItemInteractionClient: Failed to require SharedModule:", errorMessage)
    print("ItemInteractionClient: Creating minimal SharedModule fallback")
    -- Create minimal fallback for Constants
    Constants = {
        INTERACTION_DISTANCE = 10,
        ITEM_ACTIONS = {
            clone = { cost = 100 },
            move = { cost = 10 },
            rotate = { cost = 5 },
            destroy = { cost = 20 }
        },
        UI_COLORS = {
            PRIMARY = Color3.fromRGB(0, 170, 255),
            SECONDARY = Color3.fromRGB(40, 40, 40),
            TEXT = Color3.fromRGB(255, 255, 255)
        }
    }
    SharedModule = {
        Constants = Constants,
        GameManager = nil,
        LazyLoadModules = {
            register = function() return true end,
            require = function() return nil end
        }
    }
else
    print("ItemInteractionClient: Successfully required SharedModule")
end

local ItemInteractionClient = {}
ItemInteractionClient.__index = ItemInteractionClient

function ItemInteractionClient.new()
    local self = setmetatable({}, ItemInteractionClient)
    
    -- Remote events/functions
    self.remotes = {}
    
    -- UI elements
    self.catalogUI = nil
    self.worldItemUI = nil
    self.inventoryUI = nil
    self.proximityUI = nil
    self.notificationUI = nil
    
    -- State tracking
    self.currentTarget = nil
    self.isInteracting = false
    self.maxInteractionDistance = 10 -- Units
    self.proximityEnabled = true
    
    -- Connection tracking for cleanup
    self.connections = {}
    
    return self
end

function ItemInteractionClient:Initialize()
    print("ItemInteractionClient initializing...")
    
    -- Cache remote events/functions
    self:SetupRemotes()
    
    -- Create UI components
    self:SetupUI()
    
    -- Set up input handling
    self:SetupInputHandling()
    
    -- Set up mouse movement tracking
    self:SetupMouseTracking()
    
    -- Add notification to show system is ready
    self:ShowNotification("Interaction system ready! Press E to interact with objects.")
    
    print("ItemInteractionClient initialized successfully")
    return true
end

function ItemInteractionClient:SetupRemotes()
    -- Get the Remotes folder
    local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 5)
    if not remotesFolder then
        warn("Remotes folder not found - some functionality may be limited")
        remotesFolder = Instance.new("Folder")
        remotesFolder.Name = "Remotes"
        remotesFolder.Parent = ReplicatedStorage
    end
    
    -- Cache remote functions
    self:CacheRemoteFunction(remotesFolder, "GetItemCatalog")
    self:CacheRemoteFunction(remotesFolder, "GetItemData")
    self:CacheRemoteFunction(remotesFolder, "GetAvailableInteractions")
    self:CacheRemoteFunction(remotesFolder, "GetInventory")
    self:CacheRemoteFunction(remotesFolder, "IsItemAffordable")
    
    -- Cache remote events
    self:CacheRemoteEvent(remotesFolder, "PurchaseItem")
    self:CacheRemoteEvent(remotesFolder, "PlaceItem")
    self:CacheRemoteEvent(remotesFolder, "MoveItem")
    self:CacheRemoteEvent(remotesFolder, "RotateItem")
    self:CacheRemoteEvent(remotesFolder, "CloneItem")
    self:CacheRemoteEvent(remotesFolder, "DestroyItem")
    self:CacheRemoteEvent(remotesFolder, "ChangeItemColor")
    self:CacheRemoteEvent(remotesFolder, "AddToInventory")
    self:CacheRemoteEvent(remotesFolder, "RemoveFromInventory")
    self:CacheRemoteEvent(remotesFolder, "NotifyPlayer")
    
    -- Connect to notifications
    if self.remotes.NotifyPlayer then
        self.remotes.NotifyPlayer.OnClientEvent:Connect(function(message)
            self:ShowNotification(message)
        end)
    end
end

function ItemInteractionClient:CacheRemoteFunction(parent, name)
    local remoteFunc = parent:FindFirstChild(name)
    if remoteFunc and remoteFunc:IsA("RemoteFunction") then
        self.remotes[name] = remoteFunc
    else
        warn("Remote function '" .. name .. "' not found")
    end
end

function ItemInteractionClient:CacheRemoteEvent(parent, name)
    local remoteEvent = parent:FindFirstChild(name)
    if remoteEvent and remoteEvent:IsA("RemoteEvent") then
        self.remotes[name] = remoteEvent
    else
        warn("Remote event '" .. name .. "' not found")
    end
end

function ItemInteractionClient:SetupUI()
    -- Create notification UI
    self:CreateNotificationUI()
    
    -- Create proximity UI for highlighting interactable objects
    self:CreateProximityUI()
    
    -- Load the catalog UI, inventory UI and world item UI modules
    -- These would typically be loaded from the SharedModule
    self:LoadUIModules()
end

function ItemInteractionClient:CreateNotificationUI()
    -- Create notification UI for displaying messages to the player
    local playerGui = player:WaitForChild("PlayerGui")
    
    -- Create ScreenGui for notifications
    self.notificationUI = Instance.new("ScreenGui")
    self.notificationUI.Name = "InteractionNotifications"
    self.notificationUI.ResetOnSpawn = false
    self.notificationUI.Parent = playerGui
    
    -- Create a container for notifications
    local container = Instance.new("Frame")
    container.Name = "NotificationContainer"
    container.Size = UDim2.new(0, 300, 0, 200)
    container.Position = UDim2.new(1, -320, 0, 20)
    container.BackgroundTransparency = 1
    container.Parent = self.notificationUI
    
    -- Add UI list layout for stacking notifications
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 5)
    layout.Parent = container
end

function ItemInteractionClient:CreateProximityUI()
    -- Create a billboard gui template for highlighting interactable objects
    self.proximityUI = Instance.new("BillboardGui")
    self.proximityUI.Name = "ProximityInteractUI"
    self.proximityUI.Size = UDim2.new(0, 220, 0, 60)
    self.proximityUI.StudsOffset = Vector3.new(0, 3, 0)
    self.proximityUI.AlwaysOnTop = true
    self.proximityUI.Enabled = false
    
    -- Add background frame
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    bg.BackgroundTransparency = 0.2
    bg.BorderSizePixel = 0
    bg.Parent = self.proximityUI
    
    -- Add rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = bg
    
    -- Add stroke for visibility
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 170, 255)
    stroke.Thickness = 2
    stroke.Parent = bg
    
    -- Add text label
    local label = Instance.new("TextLabel")
    label.Name = "Title"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 22
    label.Font = Enum.Font.GothamBold
    label.Text = "[E] Interact"
    label.Parent = bg
end

function ItemInteractionClient:LoadUIModules()
    -- Create the catalog UI
    local CatalogItemUI = require(script.Parent:WaitForChild("CatalogItemUI"))
    self.catalogUI = CatalogItemUI.new()
    self.catalogUI:Initialize()
    
    -- Create the world item UI
    self:CreateWorldItemUI()
    
    -- Define UI show functions
    self.ShowCatalogUI = function(itemName)
        self.catalogUI:Show(itemName)
    end
    
    self.ShowWorldItemUI = function(itemGuid)
        self:ShowInteractionUI(itemGuid)
    end
    
    self.ShowInventoryUI = function()
        self:ShowNotification("Opening inventory...")
        -- This would be implemented with a separate inventory UI module
    end
end

-- Create UI for interacting with placed world items
function ItemInteractionClient:CreateWorldItemUI()
    local playerGui = player:WaitForChild("PlayerGui")
    
    -- Create ScreenGui
    self.worldItemUI = Instance.new("ScreenGui")
    self.worldItemUI.Name = "WorldItemUI"
    self.worldItemUI.ResetOnSpawn = false
    self.worldItemUI.Enabled = false
    self.worldItemUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self.worldItemUI.Parent = playerGui
    
    -- Create main frame
    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 400, 0, 300)
    frame.Position = UDim2.new(0.5, -200, 0.5, -150)
    frame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    frame.BorderSizePixel = 0
    frame.Parent = self.worldItemUI
    
    -- Add rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = frame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = titleBar
    
    -- Title text
    local titleText = Instance.new("TextLabel")
    titleText.Name = "TitleText"
    titleText.Size = UDim2.new(1, -20, 1, 0)
    titleText.Position = UDim2.new(0, 10, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleText.TextSize = 24
    titleText.Font = Enum.Font.GothamBold
    titleText.Text = "Item Interaction"
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = titleBar
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 40, 0, 40)
    closeButton.Position = UDim2.new(1, -45, 0, 5)
    closeButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    closeButton.BorderSizePixel = 0
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextSize = 20
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeButton
    
    -- Connect close button
    closeButton.MouseButton1Click:Connect(function()
        self:HideInteractionUI()
    end)
    
    -- Create a scroll frame for interaction buttons
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "InteractionsFrame"
    scrollFrame.Size = UDim2.new(1, -40, 1, -70)
    scrollFrame.Position = UDim2.new(0, 20, 0, 60)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 170, 255)
    scrollFrame.Parent = frame
    
    -- Add a UIListLayout for organizing buttons
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 10)
    listLayout.Parent = scrollFrame
    
    -- Update scrolling frame content size when list layout changes
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
    end)
end

function ItemInteractionClient:ShowInteractionUI(itemGuid)
    -- Get available interactions from server
    local interactions = self:GetAvailableInteractions(itemGuid)
    if #interactions == 0 then
        self:ShowNotification("No interactions available for this item")
        return
    end
    
    -- Get reference to the interactions frame
    local scrollFrame = self.worldItemUI.MainFrame.InteractionsFrame
    
    -- Clear existing buttons
    for _, child in ipairs(scrollFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    -- Create interaction buttons
    for i, interaction in ipairs(interactions) do
        local button = Instance.new("TextButton")
        button.Name = interaction
        button.Size = UDim2.new(1, 0, 0, 50)
        button.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
        button.BorderSizePixel = 0
        button.Text = interaction:sub(1, 1):upper() .. interaction:sub(2)
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 18
        button.Font = Enum.Font.GothamBold
        button.LayoutOrder = i
        button.Parent = scrollFrame
        
        -- Add rounded corners
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = button
        
        -- Add icon and cost
        local cost = 0
        if interaction == "move" then
            cost = Constants.ITEM_ACTIONS.move.cost
        elseif interaction == "rotate" then
            cost = Constants.ITEM_ACTIONS.rotate.cost
        elseif interaction == "clone" then
            cost = Constants.ITEM_ACTIONS.clone.cost
        elseif interaction == "destroy" then
            cost = Constants.ITEM_ACTIONS.destroy.cost
        end
        
        -- Display cost if applicable
        if cost > 0 then
            local costLabel = Instance.new("TextLabel")
            costLabel.Name = "CostLabel"
            costLabel.Size = UDim2.new(0, 80, 0, 30)
            costLabel.Position = UDim2.new(1, -90, 0.5, -15)
            costLabel.BackgroundTransparency = 0.5
            costLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
            costLabel.BorderSizePixel = 0
            costLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            costLabel.Text = cost .. " coins"
            costLabel.TextSize = 14
            costLabel.Font = Enum.Font.Gotham
            costLabel.Parent = button
            
            local costCorner = Instance.new("UICorner")
            costCorner.CornerRadius = UDim.new(0, 4)
            costCorner.Parent = costLabel
        end
        
        -- Connect button click to handle interaction
        button.MouseButton1Click:Connect(function()
            self:HandleInteraction(itemGuid, interaction)
        end)
    end
    
    -- Update the scrolling frame canvas size
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, scrollFrame.UIListLayout.AbsoluteContentSize.Y)
    
    -- Show the UI
    self.worldItemUI.Enabled = true
    
    -- Save current item GUID
    self.currentItemGuid = itemGuid
end

function ItemInteractionClient:HideInteractionUI()
    self.worldItemUI.Enabled = false
    self.currentItemGuid = nil
end

function ItemInteractionClient:HandleInteraction(itemGuid, interaction)
    -- Hide the UI first
    self:HideInteractionUI()
    
    -- Process different interaction types
    if interaction == "move" then
        self:ShowNotification("Starting move interaction...")
        -- This would call a function to start a drag/move interaction
    elseif interaction == "rotate" then
        self:ShowNotification("Starting rotation interaction...")
        -- This would call a function to start a rotation interface
    elseif interaction == "clone" then
        -- Send clone request to server
        pcall(function()
            if self.remotes.CloneItem then
                self.remotes.CloneItem:FireServer(itemGuid)
            end
        end)
    elseif interaction == "destroy" then
        -- Send destroy request to server
        pcall(function()
            if self.remotes.DestroyItem then
                self.remotes.DestroyItem:FireServer(itemGuid)
            end
        end)
    elseif interaction == "changeColor" then
        self:ShowNotification("Starting color change interaction...")
        -- This would open a color picker UI
    end
end

function ItemInteractionClient:SetupInputHandling()
    -- Handle E key for interaction
    local inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.E then
            self:TryInteract()
        elseif input.KeyCode == Enum.KeyCode.I then
            self:ShowInventoryUI()
        end
    end)
    table.insert(self.connections, inputConnection)
    
    -- Handle mobile touch input
    local touchConnection = UserInputService.TouchTap:Connect(function(touchPositions, gameProcessed)
        if gameProcessed then return end
        
        -- Use the first touch position
        local touchPosition = touchPositions[1]
        if touchPosition then
            -- If we have a current target, interact with it
            if self.currentTarget then
                self:TryInteract()
            else
                -- Otherwise, try to find a target based on touch position
                local camera = workspace.CurrentCamera
                local ray = camera:ScreenPointToRay(touchPosition.X, touchPosition.Y)
                
                -- Set up raycast parameters
                local raycastParams = RaycastParams.new()
                raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                raycastParams.FilterDescendantsInstances = {player.Character}
                
                -- Cast ray
                local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * 50, raycastParams)
                if raycastResult and raycastResult.Instance then
                    local target = self:GetInteractableFromPart(raycastResult.Instance)
                    if target then
                        self.currentTarget = target
                        self:ShowProximityUI(target)
                        self:TryInteract()
                    end
                end
            end
        end
    end)
    table.insert(self.connections, touchConnection)
    
    -- Handle cleanup when player leaves
    player.AncestryChanged:Connect(function()
        self:Cleanup()
    end)
end

function ItemInteractionClient:SetupMouseTracking()
    -- Update target on mouse movement
    local mouseConnection = RunService.RenderStepped:Connect(function()
        self:UpdateCurrentTarget()
    end)
    table.insert(self.connections, mouseConnection)
end

function ItemInteractionClient:UpdateCurrentTarget()
    -- Don't update if we're already interacting
    if self.isInteracting then return end
    
    -- Get character and humanoid root part
    local character = player.Character
    if not character then return end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    -- Check if we're pointing at an interactable object
    local target = mouse.Target
    if not target then
        -- Hide UI and clear target if we're not pointing at anything
        if self.currentTarget then
            self:HideProximityUI()
            self.currentTarget = nil
        end
        return
    end
    
    -- Check if we're pointing at an interactable object
    local interactable = self:GetInteractableFromPart(target)
    if not interactable then
        -- Hide UI and clear target if we're not pointing at an interactable
        if self.currentTarget then
            self:HideProximityUI()
            self.currentTarget = nil
        end
        return
    end
    
    -- Check distance to the object
    local objectPosition = interactable.PrimaryPart and interactable.PrimaryPart.Position or interactable:GetModelCFrame().Position
    local distance = (hrp.Position - objectPosition).Magnitude
    
    if distance > self.maxInteractionDistance then
        -- Hide UI and clear target if we're too far away
        if self.currentTarget then
            self:HideProximityUI()
            self.currentTarget = nil
        end
        return
    end
    
    -- Set new target and show UI
    if interactable ~= self.currentTarget then
        self.currentTarget = interactable
        self:ShowProximityUI(interactable)
    end
end

function ItemInteractionClient:GetInteractableFromPart(part)
    -- Check if the part is part of an interactable object
    
    -- First check if it's in the Items folder (store catalog item)
    local itemsFolder = workspace:FindFirstChild("Items")
    if itemsFolder and part:IsDescendantOf(itemsFolder) then
        -- Find the model this part belongs to
        local ancestor = part
        while ancestor and ancestor.Parent ~= itemsFolder and not ancestor:IsDescendantOf(itemsFolder) do
            ancestor = ancestor.Parent
        end
        
        -- Check if it's a model with a primary part
        if ancestor and ancestor:IsA("Model") and ancestor.PrimaryPart then
            return ancestor
        end
    end
    
    -- Next check if it's in the World_Items folder (placed item)
    local worldFolder = workspace:FindFirstChild("World_Items")
    if worldFolder and part:IsDescendantOf(worldFolder) then
        -- Find the model this part belongs to
        local ancestor = part
        while ancestor and ancestor.Parent ~= worldFolder do
            ancestor = ancestor.Parent
        end
        
        -- Check if it's a model with a primary part
        if ancestor and ancestor:IsA("Model") and ancestor.PrimaryPart then
            return ancestor
        end
    end
    
    return nil
end

function ItemInteractionClient:ShowProximityUI(target)
    -- Don't show if proximity UI is disabled
    if not self.proximityEnabled then return end
    
    -- Clone the proximity UI template
    local ui = self.proximityUI:Clone()
    
    -- Update the UI based on the target type
    local isStoreItem = self:IsStoreItem(target)
    local label = ui:FindFirstChild("Title", true)
    
    if label then
        if isStoreItem then
            -- Store item UI
            local itemName = target.Name:gsub("_", " ")
            label.Text = "[E] View " .. itemName
        else
            -- World item UI
            label.Text = "[E] Interact"
        end
    end
    
    -- Attach to target and show
    ui.Adornee = target
    ui.Enabled = true
    ui.Parent = player.PlayerGui
    
    -- Store reference for cleanup
    if target:FindFirstChild("ProximityUI") then
        target:FindFirstChild("ProximityUI"):Destroy()
    end
    ui.Name = "ProximityUI"
    ui.Parent = target
end

function ItemInteractionClient:HideProximityUI()
    -- Remove proximity UI from current target
    if self.currentTarget and self.currentTarget:FindFirstChild("ProximityUI") then
        self.currentTarget:FindFirstChild("ProximityUI"):Destroy()
    end
end

function ItemInteractionClient:TryInteract()
    -- Don't interact if we're already interacting
    if self.isInteracting then return end
    
    -- Need a valid target to interact with
    if not self.currentTarget then return end
    
    -- Set interacting flag
    self.isInteracting = true
    
    -- Hide proximity UI
    self:HideProximityUI()
    
    -- Determine interaction type
    local isStoreItem = self:IsStoreItem(self.currentTarget)
    
    if isStoreItem then
        -- Handle store item interaction
        local itemName = self.currentTarget.Name:gsub("_", " ")
        self:InteractWithStoreItem(self.currentTarget)
    else
        -- Handle world item interaction
        self:InteractWithWorldItem(self.currentTarget)
    end
    
    -- Clear flags and target after short delay
    task.delay(0.2, function()
        self.isInteracting = false
        self.currentTarget = nil
    end)
end

function ItemInteractionClient:IsStoreItem(target)
    -- Check if the target is in the Items folder (store catalog item)
    local itemsFolder = workspace:FindFirstChild("Items")
    return itemsFolder and target:IsDescendantOf(itemsFolder)
end

function ItemInteractionClient:InteractWithStoreItem(target)
    -- Get the item name
    local itemName = target.Name
    
    -- Check if the item is in the catalog
    local itemData
    pcall(function()
        if self.remotes.GetItemData then
            itemData = self.remotes.GetItemData:InvokeServer(itemName)
        end
    end)
    
    if not itemData then
        self:ShowNotification("Error: Item data not found")
        return
    end
    
    -- Show catalog UI for this item
    self:ShowCatalogUI(itemName)
end

function ItemInteractionClient:InteractWithWorldItem(target)
    -- Get the item GUID from attributes
    local itemGuid = target:GetAttribute("guid")
    if not itemGuid then
        self:ShowNotification("Error: Item ID not found")
        return
    end
    
    -- Show world item UI
    self:ShowWorldItemUI(itemGuid)
end

function ItemInteractionClient:GetAvailableInteractions(itemGuid)
    -- Get available interactions from server
    local interactions = {}
    
    pcall(function()
        if self.remotes.GetAvailableInteractions then
            interactions = self.remotes.GetAvailableInteractions:InvokeServer(itemGuid)
        end
    end)
    
    -- If server call fails, return default interactions
    if #interactions == 0 then
        interactions = {"move", "rotate", "clone", "destroy"}
    end
    
    return interactions
end

function ItemInteractionClient:ShowNotification(message)
    -- Create a notification UI element
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui or not self.notificationUI then return end
    
    local container = self.notificationUI:FindFirstChild("NotificationContainer")
    if not container then return end
    
    -- Create notification
    local notification = Instance.new("Frame")
    notification.Size = UDim2.new(1, 0, 0, 40)
    notification.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    notification.BorderSizePixel = 0
    
    -- Add rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = notification
    
    -- Add stroke for visibility
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 60)
    stroke.Thickness = 1
    stroke.Parent = notification
    
    -- Add text label
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 16
    label.Font = Enum.Font.Gotham
    label.Text = message
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.Parent = notification
    
    -- Set layout order for proper stacking
    notification.LayoutOrder = tick() * -1
    notification.Parent = container
    
    -- Animate in
    notification.BackgroundTransparency = 1
    label.TextTransparency = 1
    
    -- Fade in
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    game:GetService("TweenService"):Create(notification, tweenInfo, {BackgroundTransparency = 0.2}):Play()
    game:GetService("TweenService"):Create(label, tweenInfo, {TextTransparency = 0}):Play()
    
    -- Remove after delay
    task.delay(5, function()
        -- Fade out
        game:GetService("TweenService"):Create(notification, tweenInfo, {BackgroundTransparency = 1}):Play()
        game:GetService("TweenService"):Create(label, tweenInfo, {TextTransparency = 1}):Play()
        
        -- Remove after fade out
        task.delay(0.3, function()
            notification:Destroy()
        end)
    end)
end

function ItemInteractionClient:Cleanup()
    -- Disconnect all connections
    for _, connection in ipairs(self.connections) do
        if typeof(connection) == "RBXScriptConnection" and connection.Connected then
            connection:Disconnect()
        end
    end
    self.connections = {}
    
    -- Remove UIs
    if self.notificationUI then
        self.notificationUI:Destroy()
        self.notificationUI = nil
    end
    
    -- Remove proximity UI from current target
    self:HideProximityUI()
    
    print("ItemInteractionClient cleaned up successfully")
end

return ItemInteractionClient