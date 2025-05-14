--[[
    InteractionSystem Emergency Setup Script
    
    This script can be run directly in Roblox Studio to fix interaction system issues.
    It will:
    1. Check if InteractionSystemModule exists
    2. If missing, create it
    3. Create a backup of any existing module
    4. Create a direct emergency script that will run even if module loading fails
    
    Usage:
    - Insert this script into ServerScriptService in Roblox Studio
    - Run it once (it will auto-delete after running)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local ServerScriptService = game:GetService("ServerScriptService")

local function createPathRecursive(parent, paths)
    local current = parent
    for _, path in ipairs(paths) do
        local found = current:FindFirstChild(path)
        if not found then
            found = Instance.new("Folder")
            found.Name = path
            found.Parent = current
        end
        current = found
    end
    return current
end

local function backupExistingModule(moduleScript)
    if not moduleScript then return end
    
    local backup = moduleScript:Clone()
    backup.Name = moduleScript.Name .. "_backup_" .. os.time()
    backup.Parent = moduleScript.Parent
    print("Created backup:", backup.Name)
end

print("🔧 Starting InteractionSystem Emergency Setup 🔧")

-- Make sure client scripts path exists
local clientFolder = StarterPlayer:FindFirstChild("StarterPlayerScripts")
if not clientFolder then
    clientFolder = Instance.new("StarterPlayerScripts")
    clientFolder.Name = "StarterPlayerScripts"
    clientFolder.Parent = StarterPlayer
end

local clientScriptFolder = clientFolder:FindFirstChild("client")
if not clientScriptFolder then
    clientScriptFolder = Instance.new("Folder")
    clientScriptFolder.Name = "client"
    clientScriptFolder.Parent = clientFolder
end

-- Create interaction folder if it doesn't exist
local interactionFolder = clientScriptFolder:FindFirstChild("interaction")
if not interactionFolder then
    interactionFolder = Instance.new("Folder")
    interactionFolder.Name = "interaction"
    interactionFolder.Parent = clientScriptFolder
    print("Created missing interaction folder")
end

-- Check for existing InteractionSystemModule
local existingModule = interactionFolder:FindFirstChild("InteractionSystemModule")
if existingModule then
    print("Found existing InteractionSystemModule, creating backup...")
    backupExistingModule(existingModule)
end

-- Create new InteractionSystemModule
local interactionModuleScript = existingModule or Instance.new("ModuleScript")
interactionModuleScript.Name = "InteractionSystemModule"
interactionModuleScript.Parent = interactionFolder

-- Set the module content
interactionModuleScript.Source = [[
--[[
    InteractionSystemModule - ForeverBuild2
    Enhanced version with better error handling and debug control
    
    This module handles all player interactions with placed items in the game.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

-- Add debug print to confirm module is loading
print("InteractionSystem module loading...")

-- Limit debug logging with a toggle
local DEBUG_VERBOSE = false -- Set to true for detailed logging
local function debugLog(...)
    if DEBUG_VERBOSE then
        print("[DEBUG]", ...)
    end
end

-- Safely load dependencies with fallbacks
local LazyLoadModules
local Constants

-- Try to load LazyLoadModules
local lazyLoadSuccess, lazyLoadError = pcall(function()
    LazyLoadModules = require(ReplicatedStorage.shared.core.LazyLoadModules)
    return true
end)

if not lazyLoadSuccess then
    warn("[InteractionSystem] Failed to load LazyLoadModules:", lazyLoadError)
    -- Create a minimal fallback implementation
    LazyLoadModules = {
        register = function() end,
        require = function() return {} end
    }
else
    print("[InteractionSystem] Successfully loaded LazyLoadModules")
end

-- Try to load Constants
local constantsSuccess, constantsError = pcall(function()
    Constants = require(ReplicatedStorage.shared.core.Constants)
    return true
end)

if not constantsSuccess then
    warn("[InteractionSystem] Failed to load Constants:", constantsError)
    -- Create fallback constants
    Constants = {
        UI_COLORS = {
            PRIMARY = Color3.fromRGB(0, 170, 255),
            SECONDARY = Color3.fromRGB(40, 40, 40),
            TEXT = Color3.fromRGB(255, 255, 255)
        },
        ITEMS = {} -- Empty items table as fallback
    }
else
    print("[InteractionSystem] Successfully loaded Constants")
end

-- Register UI modules for lazy loading if LazyLoadModules is available
if typeof(LazyLoadModules.register) == "function" then
    pcall(function()
        LazyLoadModules.register("PurchaseDialog", ReplicatedStorage.shared.core.ui.PurchaseDialog)
        LazyLoadModules.register("InventoryUI", ReplicatedStorage.shared.core.ui.InventoryUI)
        LazyLoadModules.register("PlacedItemDialog", ReplicatedStorage.shared.core.ui.PlacedItemDialog)
    end)
end

local InteractionSystem = {}
InteractionSystem.__index = InteractionSystem

function InteractionSystem.new()
    local self = setmetatable({}, InteractionSystem)
    self.player = Players.LocalPlayer
    self.currentTarget = nil
    self.interactionDistance = 10 -- Maximum distance for interaction
    self.ui = nil
    
    -- Make sure Remotes folder exists
    self.remoteEvents = ReplicatedStorage:FindFirstChild("Remotes")
    if not self.remoteEvents then
        self.remoteEvents = Instance.new("Folder")
        self.remoteEvents.Name = "Remotes"
        self.remoteEvents.Parent = ReplicatedStorage
        warn("[InteractionSystem] Created missing Remotes folder in ReplicatedStorage")
    end
    
    -- Create a notification system for feedback when server communication fails
    self.notifications = {}
    
    return self
end

function InteractionSystem:Initialize()
    print("[DEBUG] InteractionSystem:Initialize() called")

    if not self.player then
        self.player = Players.LocalPlayer
        if not self.player then
            warn("[InteractionSystem] Critical: LocalPlayer not available at Initialize.")
            return -- Cannot proceed without player
        end
    end
    
    self.mouse = self.player:GetMouse() -- Initialize mouse here
    if not self.mouse then
        warn("[InteractionSystem] Warning: player:GetMouse() returned nil at Initialize.")
    end

    -- Create needed UI elements
    self:CreateUI()
    
    -- Set up input and event handlers
    self:SetupInputHandling()
    self:SetupEventHandlers()
    
    -- Setup mouse handling if available
    if self.mouse then
        self:SetupMouseHandling()
    else
        print("[InteractionSystem] Mouse not available, using alternative interaction methods")
        self:SetupAlternativeInteraction()
    end
    
    print("[InteractionSystem] Initialization complete")
    return true
end

function InteractionSystem:CreateUI()
    -- Prepare BillboardGui template for proximity popup
    self.billboardTemplate = Instance.new("BillboardGui")
    self.billboardTemplate.Name = "ProximityInteractUI"
    self.billboardTemplate.Size = UDim2.new(0, 200, 0, 50)
    self.billboardTemplate.StudsOffset = Vector3.new(0, 3, 0)
    self.billboardTemplate.AlwaysOnTop = true
    self.billboardTemplate.Enabled = false

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Constants.UI_COLORS.SECONDARY
    bg.BackgroundTransparency = 0.2
    bg.BorderSizePixel = 0
    bg.Parent = self.billboardTemplate

    local label = Instance.new("TextLabel")
    label.Name = "Title"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Constants.UI_COLORS.TEXT
    label.TextSize = 20
    label.Font = Enum.Font.GothamBold
    label.Text = "[E] Interact"
    label.Parent = bg
    
    -- Create notification UI for local messages
    local playerGui = self.player:FindFirstChild("PlayerGui")
    if playerGui then
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
        
        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 5)
        layout.Parent = container
    end
end

function InteractionSystem:SetupInputHandling()
    -- Handle interaction input (E key)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.E then
            debugLog("E key pressed")
            self:AttemptInteraction()
        elseif input.KeyCode == Enum.KeyCode.I then
            debugLog("I key pressed")
            self:ToggleInventory()
        end
    end)
end

function InteractionSystem:SetupMouseHandling()
    -- Don't flood the output with UpdateCurrentTarget logs
    local RunService = game:GetService("RunService")
    RunService.RenderStepped:Connect(function()
        self:UpdateCurrentTarget()
    end)
    
    -- Listen for mouse clicks on placed items
    self.mouse.Button1Down:Connect(function()
        local target = self.mouse.Target
        if not target then return end
        
        local placedItem = self:GetPlacedItemFromPart(target)
        if placedItem then
            debugLog("Clicked placed item:", placedItem.id)
            self.currentTarget = placedItem
            local interactions = self:GetAvailableInteractions(placedItem)
            self:ShowInteractionMenu(interactions)
        end
    end)
end

function InteractionSystem:SetupAlternativeInteraction()
    -- For devices without a mouse, create a proximity-based interaction system
    game:GetService("RunService").Heartbeat:Connect(function()
        if not self.player.Character then return end
        
        local rootPart = self.player.Character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end
        
        -- Find nearby items
        local nearestItem = nil
        local nearestDistance = self.interactionDistance
        
        -- Check placed items
        for _, model in ipairs(workspace:GetDescendants()) do
            if model:IsA("Model") and model:GetAttribute("item") then
                local primaryPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
                if primaryPart then
                    local distance = (primaryPart.Position - rootPart.Position).Magnitude
                    if distance < nearestDistance then
                        nearestItem = {
                            id = model.Name,
                            model = model
                        }
                        nearestDistance = distance
                    end
                end
            end
        end
        
        -- If we found a nearby item and it's different from current target
        if nearestItem and (not self.currentTarget or self.currentTarget.id ~= nearestItem.id) then
            self.currentTarget = nearestItem
            self:ShowInteractionUI(nearestItem)
        elseif not nearestItem and self.currentTarget then
            self:ClearCurrentTarget()
        end
    end)
end

function InteractionSystem:SetupEventHandlers()
    -- Handle player added event
    Players.PlayerAdded:Connect(function(player)
        if player == self.player then
            -- When character is added, update reference
            player.CharacterAdded:Connect(function(character)
                debugLog("Character added")
                -- Reset any ongoing interactions
                self:ClearCurrentTarget()
            end)
        end
    end)
    
    -- Handle player leaving
    Players.PlayerRemoving:Connect(function(player)
        if player == self.player then
            self:Cleanup()
        end
    end)
    
    -- Handle game closing
    game:BindToClose(function()
        self:Cleanup()
    end)
end

function InteractionSystem:Cleanup()
    -- Clean up any resources when player leaves or game closes
    self:HideInteractionUI()
    self:ClearCurrentTarget()
    
    -- Clean up notifications
    if self.notificationUI then
        self.notificationUI:Destroy()
    end
end

function InteractionSystem:UpdateCurrentTarget()
    if not self.mouse then return end
    
    local target = self.mouse.Target
    if not target then
        if self.currentTarget then
            self:ClearCurrentTarget()
        end
        return
    end
    
    -- Check items folder for purchasable items
    local itemsFolder = workspace:FindFirstChild("Items")
    if itemsFolder and target:IsDescendantOf(itemsFolder) then
        self.currentTarget = { id = target.Name, model = target }
        self:ShowPriceUI(self.currentTarget)
        return
    end
    
    -- Check for placed items
    local placedItem = self:GetPlacedItemFromPart(target)
    if not placedItem then
        if self.currentTarget then
            self:ClearCurrentTarget()
        end
        return
    end
    
    -- Check if player is close enough to interact
    if self.player.Character and self.player.Character:FindFirstChild("HumanoidRootPart") then
        local distance = (target.Position - self.player.Character.HumanoidRootPart.Position).Magnitude
        if distance > self.interactionDistance then
            if self.currentTarget then
                self:ClearCurrentTarget()
            end
            return
        end
    end
    
    -- Set current target
    if not self.currentTarget or self.currentTarget.id ~= placedItem.id then
        self.currentTarget = placedItem
        self:ShowInteractionUI(placedItem)
    end
end

function InteractionSystem:ClearCurrentTarget()
    if self.currentTarget then
        self:HideInteractionUI()
        self.currentTarget = nil
    end
end

function InteractionSystem:GetPlacedItemFromPart(part)
    if not part then return nil end
    
    local current = part
    local maxDepth = 10 -- Prevent infinite loops
    local depth = 0
    
    while current and current ~= workspace and depth < maxDepth do
        if current:IsA("Model") and current:GetAttribute("item") then
            return {
                id = current.Name,
                model = current
            }
        end
        current = current.Parent
        depth = depth + 1
    end
    
    return nil
end

function InteractionSystem:ShowInteractionUI(placedItem)
    if not placedItem or not placedItem.model then return end
    
    -- Attach BillboardGui to the item model's PrimaryPart
    local primaryPart = placedItem.model.PrimaryPart
    if not primaryPart then
        primaryPart = placedItem.model:FindFirstChildWhichIsA("BasePart")
        if primaryPart then
            placedItem.model.PrimaryPart = primaryPart
        end
    end
    
    if not primaryPart then return end

    -- Remove any existing BillboardGui
    local existing = primaryPart:FindFirstChild("ProximityInteractUI")
    if existing then existing:Destroy() end

    local bb = self.billboardTemplate:Clone()
    bb.Enabled = true
    bb.Parent = primaryPart
end

function InteractionSystem:HideInteractionUI()
    -- Remove BillboardGui from all items in workspace
    for _, model in ipairs(workspace:GetDescendants()) do
        if model:IsA("Model") and model.PrimaryPart then
            local bb = model.PrimaryPart:FindFirstChild("ProximityInteractUI")
            if bb then bb:Destroy() end
        end
    end
end

function InteractionSystem:ShowPriceUI(worldItem)
    if not worldItem or not worldItem.model then return end
    
    -- Check if world item model has a primary part
    local targetPart = worldItem.model
    if worldItem.model:IsA("Model") then
        targetPart = worldItem.model.PrimaryPart or worldItem.model:FindFirstChildWhichIsA("BasePart")
        if not targetPart then return end
    end
    
    -- Remove any existing price GUIs
    local existing = targetPart:FindFirstChild("PriceBillboard")
    if existing then existing:Destroy() end
    
    -- Get item data, with fallback
    local itemData = Constants.ITEMS and Constants.ITEMS[worldItem.id]
    if not itemData then
        itemData = { price = { INGAME = 10 } }
    end
    
    -- Create price UI
    local priceGui = Instance.new("BillboardGui")
    priceGui.Name = "PriceBillboard"
    priceGui.Size = UDim2.new(0, 200, 0, 60)
    priceGui.StudsOffset = Vector3.new(0, 4, 0)
    priceGui.AlwaysOnTop = true
    priceGui.Parent = targetPart
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = priceGui
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0.5, 0)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 0)
    label.TextSize = 20
    label.Font = Enum.Font.GothamBold
    label.Text = "Price: " .. tostring(itemData.price and itemData.price.INGAME or "?")
    label.Parent = frame
    
    local prompt = Instance.new("TextLabel")
    prompt.Size = UDim2.new(1, 0, 0.5, 0)
    prompt.Position = UDim2.new(0, 0, 0.5, 0)
    prompt.BackgroundTransparency = 1
    prompt.TextColor3 = Color3.fromRGB(255, 255, 255)
    prompt.TextSize = 18
    prompt.Font = Enum.Font.Gotham
    prompt.Text = "Press E to interact"
    prompt.Parent = frame
end

function InteractionSystem:AttemptInteraction()
    if not self.currentTarget then return end
    
    local itemsFolder = workspace:FindFirstChild("Items")
    if itemsFolder and self.currentTarget.model and self.currentTarget.model:IsDescendantOf(itemsFolder) then
        
        local pickupEvent = self.remoteEvents:FindFirstChild("PickupItem")
        if pickupEvent then
            pickupEvent:FireServer(self.currentTarget.id)
        else
            self:ShowLocalNotification("Can't pick up item: Remote event missing")
        end
        return
    end
    
    local interactions = self:GetAvailableInteractions(self.currentTarget)
    if not interactions or #interactions == 0 then return end
    
    if #interactions == 1 then
        self:PerformInteraction(self.currentTarget, interactions[1])
        return
    end
    
    self:ShowInteractionMenu(interactions)
end

function InteractionSystem:GetAvailableInteractions(placedItem)
    -- Check if the remote function exists
    if not self.remoteEvents:FindFirstChild("GetAvailableInteractions") then
        -- Return default interactions
        return {"examine", "clone"}
    end
    
    -- Request available interactions from server
    local success, result = pcall(function()
        return self.remoteEvents.GetAvailableInteractions:InvokeServer(placedItem)
    end)
    
    if not success or not result then
        result = {"examine"}
    end
    
    -- Always add 'examine' for placed items
    if not table.find(result, "examine") then
        table.insert(result, "examine")
    end
    
    return result
end

function InteractionSystem:ShowInteractionMenu(interactions)
    if not interactions or #interactions == 0 or not self.currentTarget then return end
    
    -- Try to use PlacedItemDialog if available
    local PlacedItemDialog = LazyLoadModules.PlacedItemDialog
    if PlacedItemDialog and typeof(PlacedItemDialog.Show) == "function" then
        PlacedItemDialog.Show(self.currentTarget, interactions, function(action)
            self:PerformInteraction(self.currentTarget, action)
        end)
        return
    end
    
    -- Fallback to a simple UI if PlacedItemDialog isn't available
    self:ShowSimpleInteractionMenu(interactions)
end

function InteractionSystem:ShowSimpleInteractionMenu(interactions)
    -- Clean up any existing menus
    local playerGui = self.player:FindFirstChild("PlayerGui")
    if not playerGui then return end
    
    local existingMenu = playerGui:FindFirstChild("SimpleInteractionMenu")
    if existingMenu then existingMenu:Destroy() end
    
    -- Create a simple menu
    local menu = Instance.new("ScreenGui")
    menu.Name = "SimpleInteractionMenu"
    menu.ResetOnSpawn = false
    menu.Parent = playerGui
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 30 * #interactions + 40)
    frame.Position = UDim2.new(0.5, -100, 0.5, -frame.Size.Y.Offset / 2)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.Parent = menu
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 0.5
    title.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.Text = "Interact with " .. self.currentTarget.id
    title.Parent = frame
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -30, 0, 0)
    closeButton.BackgroundTransparency = 1
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextSize = 18
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Text = "X"
    closeButton.Parent = frame
    
    closeButton.MouseButton1Click:Connect(function()
        menu:Destroy()
    end)
    
    -- Add buttons for each interaction
    for i, action in ipairs(interactions) do
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(0.8, 0, 0, 25)
        button.Position = UDim2.new(0.1, 0, 0, 35 + (i-1) * 30)
        button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 16
        button.Font = Enum.Font.Gotham
        button.Text = action:sub(1,1):upper() .. action:sub(2)
        button.Parent = frame
        
        button.MouseButton1Click:Connect(function()
            menu:Destroy()
            self:PerformInteraction(self.currentTarget, action)
        end)
    end
end

function InteractionSystem:PerformInteraction(item, action)
    -- Handle different interaction types
    if action == "examine" then
        self:ExamineItem(item)
        return
    end
    
    if action == "clone" then
        self:CloneItem(item)
        return
    end
    
    if action == "pickup" then
        self:PickupItem(item)
        return
    end
    
    -- For any other actions, send to server
    if self.remoteEvents:FindFirstChild("InteractWithItem") then
        self.remoteEvents.InteractWithItem:FireServer(item.id, action)
    else
        self:ShowLocalNotification("Can't perform action: Remote event missing")
    end
end

function InteractionSystem:ExamineItem(item)
    -- Get item data from server if possible
    local getItemDataFunc = self.remoteEvents:FindFirstChild("GetItemData")
    local itemData
    
    if getItemDataFunc then
        local success, result = pcall(function()
            return getItemDataFunc:InvokeServer(item.id)
        end)
        
        if success and result then
            itemData = result
        end
    end
    
    -- Fallback to Constants if server data not available
    if not itemData and Constants.ITEMS then
        itemData = Constants.ITEMS[item.id]
    end
    
    -- Default info if nothing else is available
    if not itemData then
        itemData = {
            name = item.id,
            description = "No information available"
        }
    end
    
    -- Show item info UI
    local playerGui = self.player:FindFirstChild("PlayerGui")
    if not playerGui then return end
    
    local existing = playerGui:FindFirstChild("ItemInfoUI")
    if existing then existing:Destroy() end
    
    local infoUI = Instance.new("ScreenGui")
    infoUI.Name = "ItemInfoUI"
    infoUI.ResetOnSpawn = false
    infoUI.Parent = playerGui
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 200)
    frame.Position = UDim2.new(0.5, -150, 0.5, -100)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.Parent = infoUI
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 0.5
    title.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.Text = itemData.name or item.id
    title.Parent = frame
    
    local description = Instance.new("TextLabel")
    description.Size = UDim2.new(0.9, 0, 0, 140)
    description.Position = UDim2.new(0.05, 0, 0.15, 20)
    description.BackgroundTransparency = 1
    description.TextColor3 = Color3.fromRGB(255, 255, 255)
    description.TextSize = 16
    description.Font = Enum.Font.Gotham
    description.Text = itemData.description or "No description available"
    description.TextWrapped = true
    description.TextXAlignment = Enum.TextXAlignment.Left
    description.TextYAlignment = Enum.TextYAlignment.Top
    description.Parent = frame
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -30, 0, 0)
    closeButton.BackgroundTransparency = 1
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextSize = 18
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Text = "X"
    closeButton.Parent = frame
    
    closeButton.MouseButton1Click:Connect(function()
        infoUI:Destroy()
    end)
end

function InteractionSystem:CloneItem(item)
    local cloneEvent = self.remoteEvents:FindFirstChild("CloneItem")
    
    if cloneEvent then
        cloneEvent:FireServer(item.id)
    else
        self:ShowLocalNotification("Cannot clone item: Remote event missing")
    end
end

function InteractionSystem:PickupItem(item)
    local pickupEvent = self.remoteEvents:FindFirstChild("PickupItem")
    
    if pickupEvent then
        pickupEvent:FireServer(item.id)
    else
        self:ShowLocalNotification("Cannot pick up item: Remote event missing")
    end
end

function InteractionSystem:ToggleInventory()
    -- Ensure InventoryUI is loaded
    local InventoryUI = LazyLoadModules.InventoryUI
    if InventoryUI and typeof(InventoryUI.ToggleUI) == "function" then
        InventoryUI.ToggleUI()
    else
        self:ShowLocalNotification("Inventory UI not available")
    end
end

function InteractionSystem:ShowLocalNotification(message)
    if not self.player or not self.player:FindFirstChild("PlayerGui") or not self.notificationUI then
        return
    end
    
    local container = self.notificationUI:FindFirstChild("NotificationContainer")
    if not container then return end
    
    -- Create notification
    local notification = Instance.new("Frame")
    notification.Name = "Notification_" .. tostring(#self.notifications + 1)
    notification.Size = UDim2.new(1, 0, 0, 40)
    notification.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    notification.BackgroundTransparency = 0.2
    notification.BorderSizePixel = 0
    table.insert(self.notifications, notification)
    notification.LayoutOrder = #self.notifications
    notification.Parent = container
    
    -- Add text
    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, -10, 1, 0)
    text.Position = UDim2.new(0, 5, 0, 0)
    text.BackgroundTransparency = 1
    text.TextColor3 = Color3.fromRGB(255, 255, 255)
    text.TextSize = 16
    text.Font = Enum.Font.Gotham
    text.Text = message
    text.TextWrapped = true
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.Parent = notification
    
    -- Add animations
    notification.BackgroundTransparency = 1
    text.TextTransparency = 1
    
    -- Fade in
    local tweenService = game:GetService("TweenService")
    local fadeInInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local fadeIn = tweenService:Create(notification, fadeInInfo, {BackgroundTransparency = 0.2})
    local textFadeIn = tweenService:Create(text, fadeInInfo, {TextTransparency = 0})
    fadeIn:Play()
    textFadeIn:Play()
    
    -- Remove after delay
    task.delay(5, function()
        local fadeOutInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        local fadeOut = tweenService:Create(notification, fadeOutInfo, {BackgroundTransparency = 1})
        local textFadeOut = tweenService:Create(text, fadeOutInfo, {TextTransparency = 1})
        
        fadeOut.Completed:Connect(function()
            notification:Destroy()
            -- Remove from notifications table
            for i, n in ipairs(self.notifications) do
                if n == notification then
                    table.remove(self.notifications, i)
                    break
                end
            end
        end)
        
        fadeOut:Play()
        textFadeOut:Play()
    end)
end

return InteractionSystem
]]

-- Create emergency direct script for client execution
local emergencyScript = Instance.new("LocalScript")
emergencyScript.Name = "InteractionSystem_EmergencyFix"
emergencyScript.Parent = interactionFolder
emergencyScript.Source = [[
--[[
    InteractionSystem Emergency Fix Script
    
    This script will directly create the interaction system if module loading fails.
    It's a last resort to get interactions working in-game.
]]

local script = script
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function waitForLocalPlayer()
    local player = Players.LocalPlayer
    if not player then
        player = Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
        player = Players.LocalPlayer
    end
    return player
end

-- Run emergency diagnostics
local player = waitForLocalPlayer()
local client = script.Parent.Parent
local interaction = client:FindFirstChild("interaction")
local interactionSystemModule = interaction and interaction:FindFirstChild("InteractionSystemModule")

print("🚨 EMERGENCY INTERACTION SYSTEM FIXING SCRIPT RUNNING")
print("🚨 Player:", player and player.Name or "not found")
print("🚨 Client folder:", client and client:GetFullName() or "not found")
print("🚨 Interaction folder:", interaction and interaction:GetFullName() or "not found")
print("🚨 InteractionSystemModule:", interactionSystemModule and interactionSystemModule:GetFullName() or "not found")

local emergencySystem = {}
emergencySystem.__index = emergencySystem

function emergencySystem.new()
    local self = setmetatable({}, emergencySystem)
    self.player = player
    self.initialized = false
    
    -- Create a minimal UI for notifications
    local playerGui = self.player:FindFirstChild("PlayerGui")
    if playerGui then
        local notificationUI = Instance.new("ScreenGui")
        notificationUI.Name = "EmergencyNotifications"
        notificationUI.ResetOnSpawn = false
        notificationUI.Parent = playerGui
        
        local message = Instance.new("TextLabel")
        message.Size = UDim2.new(0, 400, 0, 60)
        message.Position = UDim2.new(0.5, -200, 0, 10)
        message.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
        message.BackgroundTransparency = 0.3
        message.TextColor3 = Color3.fromRGB(255, 255, 255)
        message.TextSize = 18
        message.Font = Enum.Font.GothamBold
        message.Text = "🚨 EMERGENCY INTERACTION SYSTEM ACTIVE 🚨\nLimited functionality available"
        message.TextWrapped = true
        message.Parent = notificationUI
        
        self.messageLabel = message
        
        -- Auto hide after 5 seconds
        task.delay(5, function()
            message.Visible = false
        end)
        
        -- Create E key indicator
        local eKeyIndicator = Instance.new("TextLabel")
        eKeyIndicator.Size = UDim2.new(0, 100, 0, 40)
        eKeyIndicator.Position = UDim2.new(0.5, -50, 0.7, 0)
        eKeyIndicator.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        eKeyIndicator.BackgroundTransparency = 0.5
        eKeyIndicator.TextColor3 = Color3.fromRGB(255, 255, 255)
        eKeyIndicator.TextSize = 24
        eKeyIndicator.Font = Enum.Font.GothamBold
        eKeyIndicator.Text = "[E]"
        eKeyIndicator.Visible = false
        eKeyIndicator.Parent = notificationUI
        
        self.eKeyIndicator = eKeyIndicator
    end
    
    return self
end

function emergencySystem:Initialize()
    print("🚨 Emergency system initialized")
    self.initialized = true
    
    local UserInputService = game:GetService("UserInputService")
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.E then
            self:ShowMessage("Interactions: Emergency mode active")
        end
    end)
    
    local RunService = game:GetService("RunService")
    RunService.Heartbeat:Connect(function()
        if self.player and self.player.Character then
            local nearestDistance = 10
            local nearestItem = nil
            
            -- Look for interactable items
            local humanoidRootPart = self.player.Character:FindFirstChild("HumanoidRootPart")
            if not humanoidRootPart then return end
            
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("Model") then
                    local primaryPart = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    if primaryPart then
                        local distance = (primaryPart.Position - humanoidRootPart.Position).Magnitude
                        if distance < nearestDistance then
                            nearestItem = obj
                            nearestDistance = distance
                        end
                    end
                end
            end
            
            if nearestItem and self.eKeyIndicator then
                self.eKeyIndicator.Visible = true
            else
                self.eKeyIndicator.Visible = false
            end
        end
    end)
    
    self:ShowMessage("Emergency interaction system initialized")
    return true
end

function emergencySystem:ShowMessage(message)
    if self.messageLabel then
        self.messageLabel.Text = message
        self.messageLabel.Visible = true
        
        task.delay(3, function()
            self.messageLabel.Visible = false
        end)
    end
end

-- Try to use the module first
local InteractionSystem
local success = pcall(function()
    if interactionSystemModule then
        InteractionSystem = require(interactionSystemModule)
    end
end)

-- If module failed, use emergency system
if not success or not InteractionSystem then
    print("🚨 MODULE LOAD FAILED! Using emergency backup system")
    InteractionSystem = emergencySystem
end

-- Create and initialize the interaction system
local interactionSystem = InteractionSystem.new()
interactionSystem:Initialize()
]]

-- Create RemoteEvents for interaction system in Remotes folder
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
    remotes = Instance.new("Folder")
    remotes.Name = "Remotes"
    remotes.Parent = ReplicatedStorage
    print("Created missing Remotes folder")
end

-- Create missing RemoteEvents/Functions if needed
local function ensureRemote(name, remoteType)
    local remote = remotes:FindFirstChild(name)
    if not remote then
        remote = Instance.new(remoteType)
        remote.Name = name
        remote.Parent = remotes
        print("Created missing " .. name .. " (" .. remoteType .. ")")
    end
    return remote
end

ensureRemote("GetAvailableInteractions", "RemoteFunction")
ensureRemote("CloneItem", "RemoteEvent")
ensureRemote("PickupItem", "RemoteEvent")
ensureRemote("AddToInventory", "RemoteEvent")
ensureRemote("GetItemData", "RemoteFunction")
ensureRemote("ApplyItemEffect", "RemoteEvent")
ensureRemote("InteractWithItem", "RemoteEvent")

-- Create server-side handler for GetAvailableInteractions
local getAvailableInteractionsRemote = remotes:FindFirstChild("GetAvailableInteractions")
if getAvailableInteractionsRemote then
    getAvailableInteractionsRemote.OnServerInvoke = function(player, itemData)
        return {"examine", "clone", "pickup"}
    end
end

print("🔧 Emergency setup completed successfully 🔧")
print("🔧 The InteractionSystem has been fixed 🔧")

-- Self-destruct this script to avoid running it multiple times
script:Destroy()
