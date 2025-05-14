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
    self.connections = {} -- Track connections for cleanup
    
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
    print("[InteractionSystem] Initialize() called")

    if not self.player then
        self.player = Players.LocalPlayer
        if not self.player then
            warn("[InteractionSystem] CRITICAL: LocalPlayer not available at Initialize.")
            return false -- Cannot proceed without player
        end
    end
    
    self.mouse = self.player:GetMouse() -- Initialize mouse here
    if not self.mouse then
        warn("[InteractionSystem] Warning: player:GetMouse() returned nil at Initialize.")
    end

    -- Create needed UI elements
    self:CreateUI()
    
    -- Ensure all needed remotes exist
    self:EnsureRemotesExist()
    
    -- Verify remotes are properly configured
    self:VerifyRemotes()
    
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
    
    -- Create a notification to inform the player the system is ready
    self:ShowLocalNotification("Interaction system ready - press E to interact with objects")
    
    print("[InteractionSystem] Initialization complete")
    return true
end

function InteractionSystem:CreateUI()
    -- Prepare BillboardGui template for proximity popup with improved visibility
    self.billboardTemplate = Instance.new("BillboardGui")
    self.billboardTemplate.Name = "ProximityInteractUI"
    self.billboardTemplate.Size = UDim2.new(0, 220, 0, 60)  -- Increased size
    self.billboardTemplate.StudsOffset = Vector3.new(0, 3, 0)
    self.billboardTemplate.AlwaysOnTop = true
    self.billboardTemplate.Enabled = false
    self.billboardTemplate.MaxDistance = 30  -- Increased visibility distance

    -- Add background frame with improved contrast
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(30, 30, 50)  -- Darker blue background
    bg.BackgroundTransparency = 0.2  -- More opaque
    bg.BorderSizePixel = 0
    bg.Parent = self.billboardTemplate
    
    -- Add rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = bg
    
    -- Add highlighting stroke
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 170, 255)  -- Blue outline
    stroke.Thickness = 2
    stroke.Parent = bg
    
    -- Main interaction text with improved styling
    local label = Instance.new("TextLabel")
    label.Name = "Title"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)  -- White text
    label.TextSize = 22  -- Larger text
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
    
    print("[InteractionSystem] UI elements created successfully")
end

function InteractionSystem:SetupInputHandling()
    -- Handle interaction input (E key)
    local inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.E then
            print("[InteractionSystem] E key pressed - attempting interaction")
            self:AttemptInteraction()
        elseif input.KeyCode == Enum.KeyCode.I then
            print("[InteractionSystem] I key pressed - toggling inventory")
            self:ToggleInventory()
        end
    end)
    
    -- Add keyboard hints UI
    local playerGui = self.player:FindFirstChild("PlayerGui")
    if playerGui then
        local hintsGui = playerGui:FindFirstChild("KeyboardHintsGui")
        if not hintsGui then
            hintsGui = Instance.new("ScreenGui")
            hintsGui.Name = "KeyboardHintsGui"
            hintsGui.ResetOnSpawn = false
            hintsGui.Parent = playerGui
            
            local hintsFrame = Instance.new("Frame")
            hintsFrame.Size = UDim2.new(0, 200, 0, 80)
            hintsFrame.Position = UDim2.new(0, 10, 1, -90)
            hintsFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
            hintsFrame.BackgroundTransparency = 0.3
            hintsFrame.BorderSizePixel = 0
            hintsFrame.Parent = hintsGui
            
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 6)
            corner.Parent = hintsFrame
            
            local title = Instance.new("TextLabel")
            title.Size = UDim2.new(1, 0, 0, 25)
            title.Position = UDim2.new(0, 0, 0, 0)
            title.BackgroundTransparency = 1
            title.TextColor3 = Color3.fromRGB(255, 255, 255)
            title.TextSize = 14
            title.Font = Enum.Font.GothamBold
            title.Text = "CONTROLS"
            title.Parent = hintsFrame
            
            local eKeyHint = Instance.new("TextLabel")
            eKeyHint.Size = UDim2.new(1, -20, 0, 20)
            eKeyHint.Position = UDim2.new(0, 10, 0, 30)
            eKeyHint.BackgroundTransparency = 1
            eKeyHint.TextColor3 = Color3.fromRGB(255, 255, 255)
            eKeyHint.TextSize = 14
            eKeyHint.Font = Enum.Font.Gotham
            eKeyHint.TextXAlignment = Enum.TextXAlignment.Left
            eKeyHint.Text = "E - Interact with objects"
            eKeyHint.Parent = hintsFrame
            
            local iKeyHint = Instance.new("TextLabel")
            iKeyHint.Size = UDim2.new(1, -20, 0, 20)
            iKeyHint.Position = UDim2.new(0, 10, 0, 50)
            iKeyHint.BackgroundTransparency = 1
            iKeyHint.TextColor3 = Color3.fromRGB(255, 255, 255)
            iKeyHint.TextSize = 14
            iKeyHint.Font = Enum.Font.Gotham
            iKeyHint.TextXAlignment = Enum.TextXAlignment.Left
            iKeyHint.Text = "I - Open inventory"
            iKeyHint.Parent = hintsFrame
            
            print("[InteractionSystem] Created keyboard hints UI")
        end
    end
    
    table.insert(self.connections, inputConnection)
    print("[InteractionSystem] Input handling setup complete")
end

function InteractionSystem:SetupAlternativeInteraction()
    -- For devices without a mouse, create a proximity-based interaction system
    local heartbeatConnection = game:GetService("RunService").Heartbeat:Connect(function()
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
    
    table.insert(self.connections, heartbeatConnection)
end

function InteractionSystem:SetupMouseHandling()
    -- Don't flood the output with UpdateCurrentTarget logs
    local RunService = game:GetService("RunService")
    local renderConnection = RunService.RenderStepped:Connect(function()
        self:UpdateCurrentTarget()
    end)
    
    table.insert(self.connections, renderConnection)
    
    -- Listen for mouse clicks on placed items
    local mouseConnection = self.mouse.Button1Down:Connect(function()
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
    
    table.insert(self.connections, mouseConnection)
end

function InteractionSystem:SetupEventHandlers()
    -- Handle player added event
    local playerAddedConnection = Players.PlayerAdded:Connect(function(player)
        if player == self.player then
            -- When character is added, update reference
            local characterAddedConnection = player.CharacterAdded:Connect(function(character)
                debugLog("Character added")
                -- Reset any ongoing interactions
                self:ClearCurrentTarget()
            end)
            table.insert(self.connections, characterAddedConnection)
        end
    end)
    
    table.insert(self.connections, playerAddedConnection)
    
    -- Handle player leaving
    local playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
        if player == self.player then
            self:Cleanup()
        end
    end)
    
    table.insert(self.connections, playerRemovingConnection)
    
    -- Note: We don't use BindToClose as it's only for server scripts
    -- For cleanup, we rely on PlayerRemoving and explicit Cleanup calls
end

function InteractionSystem:Cleanup()
    -- Clean up any resources when player leaves or game closes
    self:HideInteractionUI()
    self:ClearCurrentTarget()
    
    -- Disconnect all connections
    for _, connection in ipairs(self.connections) do
        if connection and connection.Connected then
            connection:Disconnect()
        end
    end
    self.connections = {}
    
    -- Clean up notifications
    if self.notificationUI then
        self.notificationUI:Destroy()
        self.notificationUI = nil
    end
    
    self.initialized = false
    print("[InteractionSystem] Cleanup completed")
end

function InteractionSystem:UpdateCurrentTarget()
    if not self.mouse then 
        return 
    end
    
    local target = self.mouse.Target
    if not target then
        -- No target under mouse, clear current target
        if self.currentTarget then
            print("[InteractionSystem] No target under mouse, clearing current target")
            self:ClearCurrentTarget()
        end
        return
    end
    
    -- Debug print target information
    local targetInfo = string.format("%s (class: %s)", target.Name, target.ClassName)
    if target.Parent then
        targetInfo = targetInfo .. string.format(" in %s", target.Parent:GetFullName())
    end
    print("[InteractionSystem] Mouse over:", targetInfo)
    
    -- Check items folder for purchasable items
    local itemsFolder = workspace:FindFirstChild("Items")
    if itemsFolder and target:IsDescendantOf(itemsFolder) then
        print("[InteractionSystem] Target is a world item:", target.Name)
        
        -- If this is already our current target, no need to update
        if self.currentTarget and self.currentTarget.id == target.Name and 
           self.currentTarget.model == target then
            return
        end
        
        -- Otherwise, update current target and show UI
        self.currentTarget = { id = target.Name, model = target }
        self:ShowPriceUI(self.currentTarget)
        print("[InteractionSystem] Updated current target to world item:", target.Name)
        return
    end
    
    -- Check for placed items
    local placedItem = self:GetPlacedItemFromPart(target)
    if not placedItem then
        if self.currentTarget then
            print("[InteractionSystem] Target is not a placeable item, clearing current target")
            self:ClearCurrentTarget()
        end
        return
    end
    
    -- If this is the same target we already have, no need to update
    if self.currentTarget and self.currentTarget.id == placedItem.id then
        return
    end
    
    -- Check if player is close enough to interact
    if self.player.Character and self.player.Character:FindFirstChild("HumanoidRootPart") then
        local distance = (target.Position - self.player.Character.HumanoidRootPart.Position).Magnitude
        if distance > self.interactionDistance then
            print("[InteractionSystem] Target too far away (" .. tostring(math.floor(distance)) .. " studs), max distance is " .. tostring(self.interactionDistance))
            self:ClearCurrentTarget()
            return
        end
    end
    
    -- Set current target and show interaction UI
    self.currentTarget = placedItem
    self:ShowInteractionUI(placedItem)
    print("[InteractionSystem] Updated current target to placed item:", placedItem.id)
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
    if not placedItem or not placedItem.model then 
        print("[InteractionSystem] Cannot show interaction UI: Invalid placedItem")
        return 
    end
    
    print("[InteractionSystem] Showing interaction UI for:", placedItem.id)
    
    -- Attach BillboardGui to the item model's PrimaryPart
    local primaryPart = placedItem.model.PrimaryPart
    if not primaryPart then
        -- Try to find a suitable part to use as PrimaryPart
        primaryPart = placedItem.model:FindFirstChildWhichIsA("BasePart")
        if primaryPart then
            -- Set it as primary part for future use
            placedItem.model.PrimaryPart = primaryPart
            print("[InteractionSystem] Set PrimaryPart for model:", primaryPart.Name)
        else
            print("[InteractionSystem] No suitable part found for UI attachment")
            return
        end
    end
    
    -- Remove any existing BillboardGui
    local existing = primaryPart:FindFirstChild("ProximityInteractUI")
    if existing then existing:Destroy() end

    -- Create a fresh billboard from our template
    local bb = self.billboardTemplate:Clone()
    bb.Enabled = true
    
    -- Add a pulsing animation to make it more noticeable
    local textLabel = bb:FindFirstChild("Title", true)
    if textLabel then
        -- Update text to include the item name
        textLabel.Text = "[E] Interact with " .. placedItem.id
        
        -- Add a pulsing effect using TweenService
        local tweenService = game:GetService("TweenService")
        local tweenInfo = TweenInfo.new(
            0.8,                    -- Time
            Enum.EasingStyle.Sine,  -- EasingStyle
            Enum.EasingDirection.InOut, -- EasingDirection
            -1,                     -- RepeatCount (-1 means infinite)
            true,                   -- Reverses
            0                       -- DelayTime
        )
        
        local goals = {
            TextSize = 24,  -- Slightly larger
            TextTransparency = 0.2  -- Slightly transparent
        }
        
        local tween = tweenService:Create(textLabel, tweenInfo, goals)
        tween:Play()
        
        -- Store the tween so we can cancel it later if needed
        bb:SetAttribute("activeTween", true)
    end
    
    -- Parent the billboard to the part
    bb.Parent = primaryPart
    print("[InteractionSystem] Interaction UI displayed successfully")
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
    if not worldItem or not worldItem.model then 
        print("[InteractionSystem] Cannot show price UI: Invalid worldItem")
        return 
    end
    
    print("[InteractionSystem] Showing price UI for:", worldItem.id)
    
    -- Check if world item model has a primary part
    local targetPart = worldItem.model
    if worldItem.model:IsA("Model") then
        targetPart = worldItem.model.PrimaryPart or worldItem.model:FindFirstChildWhichIsA("BasePart")
        if not targetPart then 
            print("[InteractionSystem] No suitable part found for price UI")
            return 
        end
    end
    
    -- Remove any existing price GUIs
    local existing = targetPart:FindFirstChild("PriceBillboard")
    if existing then existing:Destroy() end
    
    -- Get item data, with fallback
    local itemData = Constants.ITEMS and Constants.ITEMS[worldItem.id]
    if not itemData then
        itemData = { 
            price = { INGAME = 10 },
            name = worldItem.id,
            description = "A purchasable item"
        }
    end
    
    -- Create price UI with improved styling
    local priceGui = Instance.new("BillboardGui")
    priceGui.Name = "PriceBillboard"
    priceGui.Size = UDim2.new(0, 220, 0, 80) -- Larger size
    priceGui.StudsOffset = Vector3.new(0, 4, 0)
    priceGui.AlwaysOnTop = true
    priceGui.MaxDistance = 30 -- Increased visibility distance
    priceGui.Parent = targetPart
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(35, 35, 60) -- Darker blue background
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = priceGui
    
    -- Add rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame
    
    -- Add highlighting stroke
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 215, 0) -- Gold outline
    stroke.Thickness = 2
    stroke.Parent = frame
    
    -- Item name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.3, 0)
    nameLabel.Position = UDim2.new(0, 0, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextSize = 18
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Text = itemData.name or worldItem.id
    nameLabel.Parent = frame
    
    -- Price label
    local priceLabel = Instance.new("TextLabel")
    priceLabel.Size = UDim2.new(1, 0, 0.35, 0)
    priceLabel.Position = UDim2.new(0, 0, 0.3, 0)
    priceLabel.BackgroundTransparency = 1
    priceLabel.TextColor3 = Color3.fromRGB(255, 255, 0) -- Yellow/gold for price
    priceLabel.TextSize = 22
    priceLabel.Font = Enum.Font.GothamBold
    priceLabel.Text = "Price: " .. tostring(itemData.price and itemData.price.INGAME or "?")
    priceLabel.Parent = frame
    
    -- Interactive prompt
    local prompt = Instance.new("TextLabel")
    prompt.Size = UDim2.new(1, 0, 0.35, 0)
    prompt.Position = UDim2.new(0, 0, 0.65, 0)
    prompt.BackgroundTransparency = 1
    prompt.TextColor3 = Color3.fromRGB(255, 255, 255)
    prompt.TextSize = 18
    prompt.Font = Enum.Font.Gotham
    prompt.Text = "Press E to buy"
    prompt.Parent = frame
    
    -- Add pulsing effect to the prompt text
    local tweenService = game:GetService("TweenService")
    local tweenInfo = TweenInfo.new(
        0.8,                    -- Time
        Enum.EasingStyle.Sine,  -- EasingStyle
        Enum.EasingDirection.InOut, -- EasingDirection
        -1,                     -- RepeatCount (-1 means infinite)
        true,                   -- Reverses
        0                       -- DelayTime
    )
    
    local goals = {
        TextSize = 20,  -- Slightly larger
        TextTransparency = 0.2  -- Slightly transparent
    }
    
    local tween = tweenService:Create(prompt, tweenInfo, goals)
    tween:Play()
    
    print("[InteractionSystem] Price UI displayed successfully")
end

function InteractionSystem:AttemptInteraction()
    print("[InteractionSystem] AttemptInteraction called")
    if not self.currentTarget then 
        print("[InteractionSystem] No current target to interact with")
        return 
    end
    
    -- Check if we're interacting with a world item (in Items folder)
    local itemsFolder = workspace:FindFirstChild("Items")
    if itemsFolder and self.currentTarget.model and self.currentTarget.model:IsDescendantOf(itemsFolder) then
        print("[InteractionSystem] Attempting to interact with world item:", self.currentTarget.id)
        
        local pickupEvent = self.remoteEvents:FindFirstChild("PickupItem")
        if pickupEvent then
            print("[InteractionSystem] Sending PickupItem event to server for", self.currentTarget.id)
            pickupEvent:FireServer(self.currentTarget.id)
        else
            print("[InteractionSystem] PickupItem remote event not found")
            -- Display a local notification since we can't use the server
            self:ShowLocalNotification("Can't pick up item: Remote event missing")
        end
        return
    end
    
    -- Handle interaction with placed items
    print("[InteractionSystem] Attempting to interact with placed item:", self.currentTarget.id)
    local interactions = self:GetAvailableInteractions(self.currentTarget)
    if not interactions or #interactions == 0 then
        print("[InteractionSystem] No available interactions for target")
        return 
    end
    
    -- If we have exactly one interaction option, perform it directly
    if #interactions == 1 then
        print("[InteractionSystem] Single interaction available, performing:", interactions[1])
        self:PerformInteraction(self.currentTarget, interactions[1])
        return
    end
    
    -- Otherwise show the interaction menu
    print("[InteractionSystem] Multiple interactions available, showing menu:", table.concat(interactions, ", "))
    self:ShowInteractionMenu(interactions)
end

function InteractionSystem:GetAvailableInteractions(placedItem)
    print("[InteractionSystem] Getting available interactions for", placedItem.id)
    
    -- Check if the remote function exists
    local interactionRemote = self.remoteEvents:FindFirstChild("GetAvailableInteractions")
    if not interactionRemote then
        print("[InteractionSystem] GetAvailableInteractions remote function not found, using default interactions")
        -- Return default interactions
        return {"examine", "clone"}
    end
    
    -- Request available interactions from server
    local success, result = pcall(function()
        return interactionRemote:InvokeServer(placedItem.id)
    end)
    
    if not success or not result then
        print("[InteractionSystem] Error getting available interactions:", tostring(result))
        -- Ensure we return at least examine action as fallback
        return {"examine"}
    end
    
    print("[InteractionSystem] Server returned interactions:", result and table.concat(result, ", "))
    
    -- Always ensure examine is available
    if type(result) == "table" then
        local hasExamine = false
        for _, action in ipairs(result) do
            if action == "examine" then
                hasExamine = true
                break
            end
        end
        
        if not hasExamine then
            table.insert(result, "examine")
        end
    else
        -- If result is not a table, create a default array
        result = {"examine"}
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
    print("[InteractionSystem] Performing interaction", action, "on", item.id)
    
    -- Handle different interaction types
    if action == "examine" then
        print("[InteractionSystem] Examine action triggered")
        self:ExamineItem(item)
        return
    end
    
    if action == "clone" then
        print("[InteractionSystem] Clone action triggered")
        self:CloneItem(item)
        return
    end
    
    if action == "pickup" then
        print("[InteractionSystem] Pickup action triggered")
        self:PickupItem(item)
        return
    end
    
    -- For any other actions, send to server
    local interactEvent = self.remoteEvents:FindFirstChild("InteractWithItem")
    if interactEvent then
        print("[InteractionSystem] Sending InteractWithItem event to server for", item.id, "with action", action)
        interactEvent:FireServer(item.id, action)
    else
        print("[InteractionSystem] InteractWithItem remote event not found")
        self:ShowLocalNotification("Can't perform action: Remote event missing")
    end
end

function InteractionSystem:ExamineItem(item)
    print("[InteractionSystem] ExamineItem called for", item.id)
    -- Get item data from server if possible
    local getItemDataFunc = self.remoteEvents:FindFirstChild("GetItemData")
    local itemData
    
    if getItemDataFunc then
        local success, result = pcall(function()
            return getItemDataFunc:InvokeServer(item.id)
        end)
        
        if success and result then
            itemData = result
            print("[InteractionSystem] Got item data from server:", result)
        else
            print("[InteractionSystem] Failed to get item data from server:", tostring(result))
        end
    else
        print("[InteractionSystem] GetItemData remote function not found")
    end
    
    -- Fallback to Constants if server data not available
    if not itemData and Constants.ITEMS then
        itemData = Constants.ITEMS[item.id]
        print("[InteractionSystem] Using item data from Constants")
    end
    
    -- Default info if nothing else is available
    if not itemData then
        itemData = {
            name = item.id,
            description = "An item in your world. No additional information available.",
            price = { INGAME = "???" }
        }
        print("[InteractionSystem] Using default item data")
    end
    
    -- Show item info UI
    local playerGui = self.player:FindFirstChild("PlayerGui")
    if not playerGui then 
        print("[InteractionSystem] PlayerGui not found")
        return 
    end
    
    local existing = playerGui:FindFirstChild("ItemInfoUI")
    if existing then existing:Destroy() end
    
    local infoUI = Instance.new("ScreenGui")
    infoUI.Name = "ItemInfoUI"
    infoUI.ResetOnSpawn = false
    infoUI.Parent = playerGui
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 350, 0, 250)  -- Larger size
    frame.Position = UDim2.new(0.5, -175, 0.5, -125)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 50)  -- Slightly blue tint
    frame.BorderSizePixel = 0
    frame.Parent = infoUI
    
    -- Add corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    -- Add border
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 170, 255)  -- Blue border
    stroke.Thickness = 2
    stroke.Parent = frame
    
    -- Title with nicer formatting
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 40)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 22
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = itemData.name or item.id
    title.Parent = frame
    
    -- Item description
    local description = Instance.new("TextLabel")
    description.Size = UDim2.new(1, -40, 0, 100)
    description.Position = UDim2.new(0, 20, 0, 60)
    description.BackgroundTransparency = 1
    description.TextColor3 = Color3.fromRGB(220, 220, 220)
    description.TextSize = 16
    description.Font = Enum.Font.Gotham
    description.TextWrapped = true
    description.TextXAlignment = Enum.TextXAlignment.Left
    description.Text = itemData.description or "No description available."
    description.Parent = frame
    
    -- Price information
    local priceText = "Price: "
    if itemData.price and itemData.price.INGAME then
        priceText = priceText .. tostring(itemData.price.INGAME)
    else
        priceText = priceText .. "Unknown"
    end
    
    local priceLabel = Instance.new("TextLabel")
    priceLabel.Size = UDim2.new(1, -40, 0, 30)
    priceLabel.Position = UDim2.new(0, 20, 0, 170)
    priceLabel.BackgroundTransparency = 1
    priceLabel.TextColor3 = Color3.fromRGB(255, 215, 0)  -- Gold color for price
    priceLabel.TextSize = 18
    priceLabel.Font = Enum.Font.GothamBold
    priceLabel.TextXAlignment = Enum.TextXAlignment.Left
    priceLabel.Text = priceText
    priceLabel.Parent = frame
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 100, 0, 40)
    closeButton.Position = UDim2.new(0.5, -50, 1, -50)
    closeButton.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    closeButton.BorderSizePixel = 0
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextSize = 16
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Text = "Close"
    closeButton.Parent = frame
    
    -- Add corner radius to button
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 4)
    buttonCorner.Parent = closeButton
    
    -- Close on button click
    closeButton.MouseButton1Click:Connect(function()
        infoUI:Destroy()
    end)
    
    -- Auto-close after 10 seconds
    task.delay(10, function()
        if infoUI and infoUI.Parent then
            infoUI:Destroy()
        end
    end)
    
    print("[InteractionSystem] Item info UI displayed successfully")
end

function InteractionSystem:CloneItem(item)
    print("[InteractionSystem] Attempting to clone item:", item.id)
    
    -- Check if item is valid
    if not item or not item.id then
        print("[InteractionSystem] Cannot clone: Invalid item")
        self:ShowLocalNotification("Cannot clone: Invalid item")
        return
    end
    
    -- Get the clone event
    local cloneEvent = self.remoteEvents:FindFirstChild("CloneItem")
    if not cloneEvent then
        print("[InteractionSystem] Creating CloneItem RemoteEvent")
        cloneEvent = Instance.new("RemoteEvent")
        cloneEvent.Name = "CloneItem"
        cloneEvent.Parent = self.remoteEvents
    end
    
    -- Send the clone request to the server
    print("[InteractionSystem] Sending CloneItem event to server for:", item.id)
    cloneEvent:FireServer(item.id)
    
    -- Show a confirmation notification
    self:ShowLocalNotification("Cloning " .. item.id)
end

function InteractionSystem:PickupItem(item)
    print("[InteractionSystem] Attempting to pick up item:", item.id)
    
    -- Check if item is valid
    if not item or not item.id then
        print("[InteractionSystem] Cannot pick up: Invalid item")
        self:ShowLocalNotification("Cannot pick up: Invalid item")
        return
    end
    
    -- Get the pickup event
    local pickupEvent = self.remoteEvents:FindFirstChild("PickupItem")
    if not pickupEvent then
        print("[InteractionSystem] Creating PickupItem RemoteEvent")
        pickupEvent = Instance.new("RemoteEvent")
        pickupEvent.Name = "PickupItem"
        pickupEvent.Parent = self.remoteEvents
    end
    
    -- Send the pickup request to the server
    print("[InteractionSystem] Sending PickupItem event to server for:", item.id)
    pickupEvent:FireServer(item.id)
    
    -- Show a confirmation notification
    self:ShowLocalNotification("Picking up " .. item.id)
end

function InteractionSystem:ToggleInventory()
    -- Ensure InventoryUI is loaded
    local InventoryUI = LazyLoadModules.InventoryUI
    if InventoryUI and typeof(InventoryUI.ToggleUI) == "function" then
        InventoryUI.ToggleUI()
    else
        debugLog("InventoryUI.ToggleUI not available. InventoryUI module might not be loaded properly.")
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

function InteractionSystem:VerifyRemotes()
    print("[InteractionSystem] Verifying required remote events and functions")
    
    if not self.remoteEvents then
        warn("[InteractionSystem] Remotes folder not found")
        return false
    end
    
    -- Define required remotes and their types
    local requiredRemotes = {
        { name = "InteractWithItem", type = "RemoteEvent" },
        { name = "PickupItem", type = "RemoteEvent" },
        { name = "CloneItem", type = "RemoteEvent" },
        { name = "GetAvailableInteractions", type = "RemoteFunction" },
        { name = "GetItemData", type = "RemoteFunction" }
    }
    
    -- Check each required remote
    local allFound = true
    for _, remoteInfo in ipairs(requiredRemotes) do
        local remote = self.remoteEvents:FindFirstChild(remoteInfo.name)
        
        if not remote then
            warn("[InteractionSystem] Missing remote:", remoteInfo.name)
            allFound = false
        elseif remote.ClassName ~= remoteInfo.type then
            warn("[InteractionSystem] Remote", remoteInfo.name, "is of wrong type. Expected", remoteInfo.type, "but got", remote.ClassName)
            allFound = false
        else
            print("[InteractionSystem] Found remote:", remoteInfo.name)
        end
    end
    
    if not allFound then
        warn("[InteractionSystem] Some required remotes are missing - interaction functionality may be limited")
    else
        print("[InteractionSystem] All required remotes verified successfully")
    end
    
    return allFound
end

function InteractionSystem:EnsureRemotesExist()
    print("[InteractionSystem] Ensuring required remotes exist")
    
    if not self.remoteEvents then
        self.remoteEvents = Instance.new("Folder")
        self.remoteEvents.Name = "Remotes"
        self.remoteEvents.Parent = ReplicatedStorage
        print("[InteractionSystem] Created Remotes folder in ReplicatedStorage")
    end
    
    -- Define required remotes and their types
    local requiredRemotes = {
        { name = "InteractWithItem", type = "RemoteEvent" },
        { name = "PickupItem", type = "RemoteEvent" },
        { name = "CloneItem", type = "RemoteEvent" },
        { name = "GetAvailableInteractions", type = "RemoteFunction" },
        { name = "GetItemData", type = "RemoteFunction" }
    }
    
    -- Create any missing remotes
    for _, remoteInfo in ipairs(requiredRemotes) do
        local remote = self.remoteEvents:FindFirstChild(remoteInfo.name)
        
        if not remote then
            if remoteInfo.type == "RemoteEvent" then
                remote = Instance.new("RemoteEvent")
            else
                remote = Instance.new("RemoteFunction")
            end
            
            remote.Name = remoteInfo.name
            remote.Parent = self.remoteEvents
            print("[InteractionSystem] Created missing remote:", remoteInfo.name)
        end
    end
    
    print("[InteractionSystem] All required remotes now exist")
end

return InteractionSystem
