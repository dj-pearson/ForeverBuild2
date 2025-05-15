-- InteractionSystemModule - ForeverBuild2
-- Enhanced version with better error handling and debug control
-- This module handles all player interactions with placed items in the game.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

-- Add debug print to confirm module is loading
print("InteractionSystem module loading...")

-- Import the SharedModule to access all the shared resources
local SharedModule = require(ReplicatedStorage:WaitForChild("shared"))
local LazyLoadModules = SharedModule.LazyLoadModules
local Constants = SharedModule.Constants

-- Limit debug logging with a toggle
local DEBUG_VERBOSE = false -- Set to true for detailed logging
local function debugLog(...)
    if DEBUG_VERBOSE then
        print("[DEBUG]", ...)
    end
end

-- Verify that our dependencies are loaded
if not LazyLoadModules then
    warn("[InteractionSystem] LazyLoadModules not available from SharedModule, creating fallback")
    LazyLoadModules = {
        register = function() end,
        require = function() return {} end
    }
else
    print("[InteractionSystem] Successfully got LazyLoadModules from SharedModule")
end

if not Constants then
    warn("[InteractionSystem] Constants not available from SharedModule, creating fallback")
    Constants = {
        UI_COLORS = {
            PRIMARY = Color3.fromRGB(0, 170, 255),
            SECONDARY = Color3.fromRGB(40, 40, 40),
            TEXT = Color3.fromRGB(255, 255, 255)
        },
        ITEMS = {} -- Empty items table as fallback
    }
else
    print("[InteractionSystem] Successfully got Constants from SharedModule")
end

-- Register UI modules for lazy loading if LazyLoadModules is available
if typeof(LazyLoadModules.register) == "function" then
    pcall(function()
        -- Use SharedModule's references to UI modules to avoid path issues
        LazyLoadModules.register("PurchaseDialog", SharedModule.PurchaseDialog)
        LazyLoadModules.register("InventoryUI", SharedModule.InventoryUI)
        LazyLoadModules.register("PlacedItemDialog", SharedModule.PlacedItemDialog)
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
end

function InteractionSystem:SetupInputHandling()
    -- Set up input handling for "E" key to trigger interaction
    local connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        -- Check for E key press
        if input.KeyCode == Enum.KeyCode.E then
            self:AttemptInteraction()
        end
    end)
    
    -- Store connection for cleanup
    table.insert(self.connections, connection)
    
    -- Also track mouse movement for targeting
    local moveConnection = UserInputService.InputChanged:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            self:UpdateCurrentTarget()
        end
    end)
    
    table.insert(self.connections, moveConnection)
    
    -- Handle touch input for mobile devices
    local touchConnection = UserInputService.TouchTap:Connect(function(touchPositions, gameProcessed)
        if gameProcessed then return end
        
        -- If we have a current target and user taps, trigger interaction
        if self.currentTarget then
            self:AttemptInteraction()
        else
            -- Try to find a new target based on touch position
            local touchPosition = touchPositions[1]
            if touchPosition then
                local ray = workspace.CurrentCamera:ScreenPointToRay(
                    touchPosition.X, 
                    touchPosition.Y
                )
                
                local raycastParams = RaycastParams.new()
                raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                raycastParams.FilterDescendantsInstances = {self.player.Character}
                
                local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * 50, raycastParams)
                if raycastResult and raycastResult.Instance then
                    local placedItem = self:GetPlacedItemFromPart(raycastResult.Instance)
                    if placedItem then
                        self.currentTarget = placedItem
                        self:ShowInteractionUI(placedItem)
                        self:AttemptInteraction()
                    end
                end
            end
        end
    end)
    
    table.insert(self.connections, touchConnection)
end

function InteractionSystem:SetupAlternativeInteraction()
    -- This is called when mouse is not available
    -- We'll implement additional methods for targeting
    
    -- Use camera movement to help with targeting
    local camera = workspace.CurrentCamera
    local cameraChangedConnection = camera:GetPropertyChangedSignal("CFrame"):Connect(function()
        -- Refresh targeting when camera moves
        self:UpdateCurrentTarget()
    end)
    
    table.insert(self.connections, cameraChangedConnection)
    
    -- Add character movement detection for targeting
    local character = self.player.Character or self.player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    
    local movementConnection = humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
        -- Refresh targeting when character moves
        self:UpdateCurrentTarget()
    end)
    
    table.insert(self.connections, movementConnection)
    
    -- Set up periodic targeting refresh as a fallback
    spawn(function()
        while true do
            wait(0.5) -- Check every half second
            if self.connections[1] == nil then
                -- Our connections table is emptied on cleanup, so break the loop
                break
            end
            self:UpdateCurrentTarget()
        end
    end)
end

function InteractionSystem:SetupMouseHandling()
    -- We have mouse access, set up hover effects and targeting
    local mouseMove = self.mouse.Move:Connect(function()
        self:UpdateCurrentTarget()
    end)
    
    table.insert(self.connections, mouseMove)
    
    -- Set up mouse click as an alternative to E key
    local mouseClick = self.mouse.Button1Down:Connect(function()
        -- Only trigger if we're clicking on the current target
        if self.currentTarget and self.currentTarget.instance then
            local target = self.mouse.Target
            while target do
                if target == self.currentTarget.instance then
                    self:AttemptInteraction()
                    break
                end
                target = target.Parent
            end
        end
    end)
    
    table.insert(self.connections, mouseClick)
end

function InteractionSystem:SetupEventHandlers()
    -- Set up handlers for events from the server
    
    -- Handle item placed by server
    local itemPlacedEvent = self.remoteEvents:FindFirstChild("ItemPlaced")
    if itemPlacedEvent and itemPlacedEvent:IsA("RemoteEvent") then
        local connection = itemPlacedEvent.OnClientEvent:Connect(function(itemData)
            print("[InteractionSystem] Item placed:", itemData.id)
            self:UpdateCurrentTarget() -- Refresh target in case the new item is closer
            
            -- Show a notification
            self:ShowLocalNotification("New item placed: " .. itemData.id)
        end)
        
        table.insert(self.connections, connection)
    end
    
    -- Handle item removed by server
    local itemRemovedEvent = self.remoteEvents:FindFirstChild("ItemRemoved")
    if itemRemovedEvent and itemRemovedEvent:IsA("RemoteEvent") then
        local connection = itemRemovedEvent.OnClientEvent:Connect(function(itemId)
            print("[InteractionSystem] Item removed:", itemId)
            
            -- If this was our current target, clear it
            if self.currentTarget and self.currentTarget.id == itemId then
                self:ClearCurrentTarget()
            end
            
            -- Update targeting in case something else is now the best target
            self:UpdateCurrentTarget()
        end)
        
        table.insert(self.connections, connection)
    end
end

function InteractionSystem:Cleanup()
    -- Disconnect all event connections
    for _, connection in ipairs(self.connections) do
        connection:Disconnect()
    end
    
    -- Clear connections table
    self.connections = {}
    
    -- Remove UI elements
    if self.notificationUI then
        self.notificationUI:Destroy()
        self.notificationUI = nil
    end
    
    -- Clean up any active interaction UI
    self:HideInteractionUI()
    
    print("[InteractionSystem] Cleaned up all resources")
end

function InteractionSystem:UpdateCurrentTarget()
    -- Find the closest interactable item in range
    -- This is called frequently as the player moves/looks around
    
    local character = self.player.Character
    if not character then return end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    local playerPosition = rootPart.Position
    local camera = workspace.CurrentCamera
    local cameraLookVector = camera.CFrame.LookVector
    
    -- Check if we're using the mouse for targeting
    local useMouse = self.mouse ~= nil
    local mouseRay
    
    if useMouse then
        mouseRay = workspace.CurrentCamera:ScreenPointToRay(
            self.mouse.X, 
            self.mouse.Y
        )
    end
    
    -- Find all placed items in the workspace that we can interact with
    local potentialTargets = {}
    
    -- We're expecting placed items to be in a specific folder or have specific tags
    -- This is just an example - modify this to match your actual game setup
    local placedItems = workspace:FindFirstChild("PlacedItems")
    
    if placedItems then
        for _, item in ipairs(placedItems:GetChildren()) do
            -- Check if the item has the necessary attributes
            if item:GetAttribute("Interactable") then
                local itemPosition = item:GetPivot().Position
                local distance = (itemPosition - playerPosition).Magnitude
                
                -- Check if it's within interaction range
                if distance <= self.interactionDistance then
                    local directionToItem = (itemPosition - playerPosition).Unit
                    local dotProduct = directionToItem:Dot(cameraLookVector)
                    
                    -- Higher dot product means more in front of the player
                    -- Store both the dot product and distance for scoring
                    table.insert(potentialTargets, {
                        instance = item,
                        distance = distance,
                        dotProduct = dotProduct,
                        id = item:GetAttribute("ItemID") or item.Name
                    })
                end
            end
        end
    end
    
    -- If we have no potential targets, clear the current one
    if #potentialTargets == 0 then
        if self.currentTarget then
            self:ClearCurrentTarget()
        end
        return
    end
    
    -- Choose the best target based on a combination of factors
    -- If using mouse, prioritize what the mouse is pointing at
    local bestTarget = nil
    local bestScore = -1
    
    for _, target in ipairs(potentialTargets) do
        local score = 0
        
        if useMouse then
            -- Check if mouse is pointing at this item
            local raycastParams = RaycastParams.new()
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            raycastParams.FilterDescendantsInstances = {character}
            
            local raycastResult = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 100, raycastParams)
            if raycastResult and (raycastResult.Instance == target.instance or raycastResult.Instance:IsDescendantOf(target.instance)) then
                -- Mouse is pointing directly at this item, give it a high score
                score = 100
            else
                -- Mouse isn't pointing at it, use distance and direction as fallbacks
                score = (1 - target.distance / self.interactionDistance) * 10 + target.dotProduct * 5
            end
        else
            -- No mouse, use distance and whether it's in front of the player
            score = (1 - target.distance / self.interactionDistance) * 10 + target.dotProduct * 5
        end
        
        if score > bestScore then
            bestScore = score
            bestTarget = target
        end
    end
    
    -- If we found a target
    if bestTarget then
        -- If it's different from the current target, update
        if not self.currentTarget or self.currentTarget.id ~= bestTarget.id then
            -- Clear old UI
            self:HideInteractionUI()
            
            -- Set new target and show UI
            self.currentTarget = bestTarget
            self:ShowInteractionUI(bestTarget)
        end
    elseif self.currentTarget then
        -- No good targets found, clear current
        self:ClearCurrentTarget()
    end
end

function InteractionSystem:ClearCurrentTarget()
    self:HideInteractionUI()
    self.currentTarget = nil
end

function InteractionSystem:GetPlacedItemFromPart(part)
    -- Convert a part into a placed item data structure
    -- This helps us work with consistent data regardless of how items are stored
    
    -- Check if the part itself has the data
    if part:GetAttribute("Interactable") and part:GetAttribute("ItemID") then
        return {
            instance = part,
            id = part:GetAttribute("ItemID"),
            distance = (part:GetPivot().Position - self.player.Character.HumanoidRootPart.Position).Magnitude
        }
    end
    
    -- Check if any parent has the data
    local current = part.Parent
    while current and current ~= workspace do
        if current:GetAttribute("Interactable") and current:GetAttribute("ItemID") then
            return {
                instance = current,
                id = current:GetAttribute("ItemID"),
                distance = (current:GetPivot().Position - self.player.Character.HumanoidRootPart.Position).Magnitude
            }
        end
        current = current.Parent
    end
    
    -- No valid placed item found
    return nil
end

function InteractionSystem:ShowInteractionUI(placedItem)
    -- Show the hover UI for an interactable item
    if not placedItem or not placedItem.instance then return end
    
    -- Create a clone of our billboard template
    local billboardGui = self.billboardTemplate:Clone()
    billboardGui.Adornee = placedItem.instance
    billboardGui.Enabled = true
    
    -- Set up the name of the item in the UI
    local title = billboardGui:FindFirstChild("Title", true)
    if title then
        title.Text = "[E] Interact with " .. placedItem.id
    end
    
    -- Parent to player's GUI
    billboardGui.Parent = self.player:FindFirstChild("PlayerGui")
    
    -- Store reference to active UI
    self.currentInteractionUI = billboardGui
    
    -- Add a highlight to the object
    local highlight = Instance.new("Highlight")
    highlight.FillColor = Color3.fromRGB(0, 170, 255)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Parent = placedItem.instance
    
    -- Store reference to highlight
    self.currentHighlight = highlight
    
    -- Add subtle pulse animation to the highlight
    spawn(function()
        local startTime = tick()
        while self.currentHighlight == highlight do
            local alpha = (math.sin(tick() - startTime) + 1) / 2 -- Value between 0 and 1
            highlight.FillTransparency = 0.5 + 0.3 * alpha
            wait(0.03) -- Update at about 30fps
            
            -- Break the loop if the highlight is no longer our current one
            if self.currentHighlight ~= highlight then
                break
            end
        end
    end)
    
    -- Add a contextual hint based on the item type
    -- This is just an example - you would customize this based on your items
    local itemType = placedItem.instance:GetAttribute("ItemType") or "default"
    
    if itemType == "container" then
        self:ShowLocalNotification("This looks like a container - maybe it has something inside?")
    elseif itemType == "door" then
        self:ShowLocalNotification("Press E to toggle the door")
    elseif itemType == "npc" then
        self:ShowLocalNotification("This character might have something to say")
    end
end

function InteractionSystem:HideInteractionUI()
    -- Clean up any currently displayed interaction UI
    if self.currentInteractionUI then
        self.currentInteractionUI:Destroy()
        self.currentInteractionUI = nil
    end
    
    if self.currentHighlight then
        self.currentHighlight:Destroy()
        self.currentHighlight = nil
    end
end

function InteractionSystem:ShowPriceUI(worldItem)
    debugLog("Showing price UI for", worldItem.id)
    
    -- Get the item's price and details from game data
    local itemData = Constants.ITEMS[worldItem.id]
    if not itemData then
        debugLog("No item data found for", worldItem.id)
        return
    end
    
    local price = itemData.price or 0
    local currency = itemData.currency or "coins"
    
    -- Use lazy loaded PurchaseDialog
    local PurchaseDialog = LazyLoadModules.require("PurchaseDialog")
    if not PurchaseDialog or typeof(PurchaseDialog.Show) ~= "function" then
        -- Try the SharedModule reference as a fallback
        PurchaseDialog = SharedModule.PurchaseDialog
    end
    
    if not PurchaseDialog then
        warn("[InteractionSystem] Failed to load PurchaseDialog module")
        return
    end
    
    -- Show the purchase dialog
    PurchaseDialog.Show({
        itemId = worldItem.id,
        itemName = itemData.displayName or worldItem.id,
        price = price,
        currency = currency,
        onPurchase = function()
            -- Attempt to purchase the item
            local success = self:AttemptPurchase(worldItem, price, currency)
            if success then
                -- Purchase successful! Show a nice message.
                self:ShowLocalNotification("Successfully purchased " .. (itemData.displayName or worldItem.id))
                
                -- Hide the UI now that purchase is complete
                PurchaseDialog.Hide()
                
                -- Refresh the item's state
                self:RefreshItem(worldItem)
            else
                -- Purchase failed. Dialog stays open.
                self:ShowLocalNotification("Not enough " .. currency .. " to purchase this item")
            end
        end,
        onCancel = function()
            -- User cancelled, just hide the dialog
            PurchaseDialog.Hide()
        end
    })
end

function InteractionSystem:AttemptInteraction()
    -- Main function that gets called when player presses E or clicks
    if not self.currentTarget then return end
    
    debugLog("Attempting interaction with", self.currentTarget.id)
    
    -- See if we're too far away (double-check distance)
    local character = self.player.Character
    if not character then return end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    local distance = (self.currentTarget.instance:GetPivot().Position - rootPart.Position).Magnitude
    if distance > self.interactionDistance then
        debugLog("Too far for interaction:", distance, "vs max", self.interactionDistance)
        self:ShowLocalNotification("Too far away to interact!")
        return
    end
    
    -- Get available interactions for this item
    local interactions = self:GetAvailableInteractions(self.currentTarget)
    
    -- If we have multiple interactions available, show a menu
    if #interactions > 1 then
        debugLog("Multiple interactions available:", table.concat(interactions, ", "))
        self:ShowSimpleInteractionMenu(interactions)
        return
    elseif #interactions == 1 then
        -- Just one interaction, perform it directly
        debugLog("Single interaction available:", interactions[1])
        self:PerformInteraction(self.currentTarget, interactions[1])
    else
        -- No interactions available
        debugLog("No interactions available for", self.currentTarget.id)
        self:ShowLocalNotification("Nothing to do with this object")
    end
end

function InteractionSystem:GetAvailableInteractions(placedItem)
    -- Determine what interactions are available for this item
    -- This would typically depend on the item type and state
    local interactions = {}
    
    -- Always allow examination
    table.insert(interactions, "examine")
    
    -- Check item type for specialized interactions
    local itemType = placedItem.instance:GetAttribute("ItemType") or "default"
    
    if itemType == "container" then
        table.insert(interactions, "open")
        table.insert(interactions, "search")
    elseif itemType == "door" then
        local isOpen = placedItem.instance:GetAttribute("IsOpen") or false
        local doorAction = isOpen and "close" or "open"
        table.insert(interactions, doorAction)
    elseif itemType == "usable" then
        table.insert(interactions, "use")
    elseif itemType == "collectable" then
        table.insert(interactions, "collect")
    elseif itemType == "npc" then
        table.insert(interactions, "talk")
        
        -- Check if this NPC offers trades
        if placedItem.instance:GetAttribute("OffersTrading") then
            table.insert(interactions, "trade")
        end
    end
    
    -- Add development tools in testing environments
    if game:GetService("RunService"):IsStudio() then
        table.insert(interactions, "clone")
        table.insert(interactions, "debug")
    end
    
    return interactions
end

function InteractionSystem:ShowInteractionMenu(interactions)
    -- Show a more complex menu of interactions
    -- We'll use the simple menu for now and may expand this later
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
    
    if action == "open" or action == "close" then
        print("[InteractionSystem] Toggle action triggered:", action)
        self:ToggleItemState(item, action)
        return
    end
    
    if action == "collect" then
        print("[InteractionSystem] Collect action triggered")
        self:CollectItem(item)
        return
    end
    
    if action == "use" then
        print("[InteractionSystem] Use action triggered")
        self:UseItem(item)
        return
    end
    
    if action == "talk" or action == "trade" then
        print("[InteractionSystem] NPC interaction triggered:", action)
        self:InteractWithNPC(item, action)
        return
    end
    
    if action == "search" then
        print("[InteractionSystem] Search action triggered")
        self:SearchContainer(item)
        return
    end
    
    if action == "debug" then
        print("[InteractionSystem] Debug action triggered")
        self:DebugItem(item)
        return
    end
    
    -- If we get here, we didn't handle the action
    warn("[InteractionSystem] Unhandled interaction:", action)
    self:ShowLocalNotification("This interaction isn't implemented yet!")
end

function InteractionSystem:ExamineItem(item)
    -- Show detailed information about the item
    debugLog("Examining item:", item.id)
    
    -- Get item data from your game's item database
    local itemData = Constants.ITEMS[item.id]
    if not itemData then
        debugLog("No item data found for:", item.id)
        itemData = {
            displayName = item.id,
            description = "No information available for this item."
        }
    end
    
    -- Use PlacedItemDialog for detailed view
    local PlacedItemDialog = LazyLoadModules.require("PlacedItemDialog")
    if not PlacedItemDialog or typeof(PlacedItemDialog.Show) ~= "function" then
        -- Try the SharedModule reference as a fallback
        PlacedItemDialog = SharedModule.PlacedItemDialog
    end
    
    if not PlacedItemDialog then
        warn("[InteractionSystem] Failed to load PlacedItemDialog module")
        return
    end
    
    -- Show the dialog with item information
    PlacedItemDialog.Show({
        title = itemData.displayName or item.id,
        description = itemData.description or "No description available.",
        imageId = itemData.imageId,
        stats = itemData.stats or {},
        onClose = function()
            PlacedItemDialog.Hide()
        end
    })
    
    -- Trigger any examination effects on the item
    if typeof(item.instance.OnExamined) == "function" then
        item.instance:OnExamined()
    elseif item.instance:FindFirstChild("OnExamined") and item.instance.OnExamined:IsA("RemoteEvent") then
        item.instance.OnExamined:FireServer()
    end
end

function InteractionSystem:ToggleItemState(item, action)
    -- Toggle item between open/closed, on/off, etc.
    debugLog("Toggling item state:", item.id, "to", action)
    
    -- Find the appropriate remote event
    local toggleEvent = self.remoteEvents:FindFirstChild("ToggleItemState")
    if not toggleEvent then
        warn("[InteractionSystem] ToggleItemState remote event not found")
        return
    end
    
    -- Fire the remote event to the server
    toggleEvent:FireServer(item.id, action)
    
    -- Optimistically update the local state for immediate feedback
    -- The server will correct this if needed
    if action == "open" then
        item.instance:SetAttribute("IsOpen", true)
    elseif action == "close" then
        item.instance:SetAttribute("IsOpen", false)
    end
    
    -- Play appropriate sound effect
    local sound = Instance.new("Sound")
    sound.Volume = 0.5
    
    if action == "open" then
        sound.SoundId = "rbxassetid://5710236543" -- Replace with actual sound ID
        self:ShowLocalNotification("Opened " .. item.id)
    elseif action == "close" then
        sound.SoundId = "rbxassetid://5710236543" -- Replace with actual sound ID
        self:ShowLocalNotification("Closed " .. item.id)
    end
    
    sound.Parent = item.instance
    sound:Play()
    
    -- Clean up the sound after it plays
    spawn(function()
        sound.Ended:Wait()
        sound:Destroy()
    end)
    
    -- Update our interaction UI to reflect the new state
    self:UpdateCurrentTarget()
end

function InteractionSystem:CollectItem(item)
    -- Add the item to the player's inventory
    debugLog("Collecting item:", item.id)
    
    -- Find the appropriate remote event
    local collectEvent = self.remoteEvents:FindFirstChild("CollectItem")
    if not collectEvent then
        warn("[InteractionSystem] CollectItem remote event not found")
        return
    end
    
    -- Fire the event to the server
    local success = collectEvent:InvokeServer(item.id)
    
    if success then
        -- Play collect animation and sound
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://5710236543" -- Replace with actual sound ID
        sound.Volume = 0.7
        sound.Parent = self.player.Character.HumanoidRootPart
        sound:Play()
        
        -- Show notification
        self:ShowLocalNotification("Added " .. item.id .. " to inventory")
        
        -- Clean up the sound after it plays
        spawn(function()
            sound.Ended:Wait()
            sound:Destroy()
        end)
        
        -- Clear our target as the item will likely be removed
        self:ClearCurrentTarget()
    else
        -- Collection failed
        self:ShowLocalNotification("Could not collect item. Inventory might be full.")
    end
end

function InteractionSystem:CloneItem(item)
    -- Development function to duplicate an item (Studio only)
    if not game:GetService("RunService"):IsStudio() then
        warn("[InteractionSystem] Clone function only available in Studio")
        return
    end
    
    debugLog("Cloning item:", item.id)
    
    -- Find the appropriate remote event
    local cloneEvent = self.remoteEvents:FindFirstChild("DevCloneItem")
    if not cloneEvent then
        warn("[InteractionSystem] DevCloneItem remote event not found")
        return
    end
    
    -- Fire the event to the server
    local success = cloneEvent:InvokeServer(item.id)
    
    if success then
        self:ShowLocalNotification("Cloned " .. item.id)
    else
        self:ShowLocalNotification("Failed to clone item")
    end
end

function InteractionSystem:UseItem(item)
    -- Use the item's functionality
    debugLog("Using item:", item.id)
    
    -- Find the appropriate remote event
    local useEvent = self.remoteEvents:FindFirstChild("UseItem")
    if not useEvent then
        warn("[InteractionSystem] UseItem remote event not found")
        return
    end
    
    -- Fire the event to the server
    local success, message = useEvent:InvokeServer(item.id)
    
    if success then
        self:ShowLocalNotification(message or "Used " .. item.id)
        
        -- Play use animation and sound
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://5710236543" -- Replace with actual sound ID
        sound.Volume = 0.5
        sound.Parent = self.player.Character.HumanoidRootPart
        sound:Play()
        
        -- Clean up the sound after it plays
        spawn(function()
            sound.Ended:Wait()
            sound:Destroy()
        end)
    else
        self:ShowLocalNotification(message or "Cannot use this item right now")
    end
end

function InteractionSystem:InteractWithNPC(item, action)
    -- Interact with an NPC character
    debugLog("Interacting with NPC:", item.id, "action:", action)
    
    -- Find the appropriate remote event
    local npcEvent = self.remoteEvents:FindFirstChild("NPCInteraction")
    if not npcEvent then
        warn("[InteractionSystem] NPCInteraction remote event not found")
        return
    end
    
    -- Fire the event to the server
    npcEvent:FireServer(item.id, action)
    
    -- The server should trigger the appropriate dialog/trade UI from its end
    -- We'll just show a notification that we're interacting
    if action == "talk" then
        self:ShowLocalNotification("Talking to " .. (item.instance:GetAttribute("NPCName") or item.id))
    elseif action == "trade" then
        self:ShowLocalNotification("Trading with " .. (item.instance:GetAttribute("NPCName") or item.id))
    end
end

function InteractionSystem:SearchContainer(item)
    -- Search a container for items
    debugLog("Searching container:", item.id)
    
    -- Find the appropriate remote event
    local searchEvent = self.remoteEvents:FindFirstChild("SearchContainer")
    if not searchEvent then
        warn("[InteractionSystem] SearchContainer remote event not found")
        return
    end
    
    -- Fire the event to the server
    local contents, message = searchEvent:InvokeServer(item.id)
    
    if contents and #contents > 0 then
        -- Show the container contents UI
        local InventoryUI = LazyLoadModules.require("InventoryUI")
        if not InventoryUI then
            warn("[InteractionSystem] InventoryUI module not found")
            return
        end
        
        InventoryUI.ShowContainerContents({
            title = "Container Contents",
            items = contents,
            onTake = function(itemId)
                -- Tell the server we want to take this item
                local takeEvent = self.remoteEvents:FindFirstChild("TakeFromContainer")
                if not takeEvent then
                    warn("[InteractionSystem] TakeFromContainer remote event not found")
                    return false
                end
                
                local success = takeEvent:InvokeServer(item.id, itemId)
                return success
            end,
            onClose = function()
                InventoryUI.HideContainerContents()
            end
        })
    else
        -- No items found
        self:ShowLocalNotification(message or "Container is empty")
    end
end

function InteractionSystem:DebugItem(item)
    -- Development function to show detailed debug info
    if not game:GetService("RunService"):IsStudio() then
        warn("[InteractionSystem] Debug function only available in Studio")
        return
    end
    
    debugLog("Debugging item:", item.id)
    
    -- Show a debug output with all available information
    print("=== ITEM DEBUG INFO ===")
    print("ID:", item.id)
    print("Instance:", item.instance:GetFullName())
    
    -- Show all attributes
    print("Attributes:")
    for _, attrName in ipairs(item.instance:GetAttributeNames()) do
        print("  " .. attrName .. ":", item.instance:GetAttribute(attrName))
    end
    
    -- Show hierarchy
    print("Children:")
    for _, child in ipairs(item.instance:GetChildren()) do
        print("  " .. child.Name .. " (" .. child.ClassName .. ")")
    end
    
    print("=== END DEBUG INFO ===")
    
    -- Also show this info in the game
    self:ShowLocalNotification("Debug info printed to output")
end

function InteractionSystem:ShowLocalNotification(message, duration)
    -- Show a temporary notification to the player
    duration = duration or 4 -- Default 4 seconds
    
    local playerGui = self.player:FindFirstChild("PlayerGui")
    if not playerGui or not self.notificationUI then return end
    
    local container = self.notificationUI:FindFirstChild("NotificationContainer")
    if not container then return end
    
    -- Create notification
    local notification = Instance.new("Frame")
    notification.Size = UDim2.new(1, 0, 0, 40)
    notification.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    notification.BackgroundTransparency = 0.2
    notification.BorderSizePixel = 0
    
    -- Add corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = notification
    
    -- Add message text
    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, -20, 1, 0)
    text.Position = UDim2.new(0, 10, 0, 0)
    text.BackgroundTransparency = 1
    text.TextColor3 = Color3.fromRGB(255, 255, 255)
    text.TextSize = 16
    text.Font = Enum.Font.Gotham
    text.Text = message
    text.TextWrapped = true
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.Parent = notification
    
    -- Add to container
    notification.Parent = container
    
    -- Animate in
    notification.Position = UDim2.new(1, 20, 0, 0)
    notification:TweenPosition(UDim2.new(0, 0, 0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.3, true)
    
    -- Set up auto-removal
    spawn(function()
        wait(duration - 0.3) -- Subtract animation time
        
        -- Animate out
        notification:TweenPosition(UDim2.new(1, 20, 0, 0), Enum.EasingDirection.In, Enum.EasingStyle.Quart, 0.3, true)
        wait(0.3)
        
        -- Remove if it still exists
        if notification and notification.Parent then
            notification:Destroy()
        end
    end)
    
    -- Store reference to active notifications
    table.insert(self.notifications, notification)
    
    -- Limit the number of notifications
    if #self.notifications > 5 then
        local oldest = table.remove(self.notifications, 1)
        if oldest and oldest.Parent then
            oldest:Destroy()
        end
    end
    
    return notification
end

function InteractionSystem:RefreshItem(item)
    -- Refresh the state of an item after interaction
    debugLog("Refreshing item state:", item.id)
    
    -- Request updated data from server
    local refreshEvent = self.remoteEvents:FindFirstChild("RefreshItemState")
    if not refreshEvent then
        warn("[InteractionSystem] RefreshItemState remote event not found")
        return
    end
    
    local success = refreshEvent:InvokeServer(item.id)
    if success then
        -- Update our current target
        self:UpdateCurrentTarget()
    end
end

function InteractionSystem:AttemptPurchase(item, price, currency)
    -- Try to purchase an item
    debugLog("Attempting purchase of", item.id, "for", price, currency)
    
    -- Find the appropriate remote event
    local purchaseEvent = self.remoteEvents:FindFirstChild("PurchaseItem")
    if not purchaseEvent then
        warn("[InteractionSystem] PurchaseItem remote event not found")
        return false
    end
    
    -- Fire the event to the server
    local success = purchaseEvent:InvokeServer(item.id)
    return success
end

function InteractionSystem:EnsureRemotesExist()
    -- Make sure all required remote events/functions exist
    debugLog("Ensuring remote events exist")
    
    -- List of remote events needed
    local requiredRemotes = {
        { name = "ItemPlaced", type = "RemoteEvent" },
        { name = "ItemRemoved", type = "RemoteEvent" },
        { name = "ToggleItemState", type = "RemoteEvent" },
        { name = "CollectItem", type = "RemoteFunction" },
        { name = "UseItem", type = "RemoteFunction" },
        { name = "NPCInteraction", type = "RemoteEvent" },
        { name = "SearchContainer", type = "RemoteFunction" },
        { name = "TakeFromContainer", type = "RemoteFunction" },
        { name = "RefreshItemState", type = "RemoteFunction" },
        { name = "PurchaseItem", type = "RemoteFunction" }
    }
    
    -- In studio, add developer functionality
    if game:GetService("RunService"):IsStudio() then
        table.insert(requiredRemotes, { name = "DevCloneItem", type = "RemoteFunction" })
    end
    
    -- Create any missing remotes
    for _, remoteInfo in ipairs(requiredRemotes) do
        local remote = self.remoteEvents:FindFirstChild(remoteInfo.name)
        
        if not remote then
            -- Create the missing remote
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

function InteractionSystem:VerifyRemotes()
    -- Verify that we can communicate with the server
    debugLog("Verifying remote communication")
    
    -- This would normally ping the server to make sure communications are working
    -- For example, the server might provide a simple ping remote function
    local pingRemote = self.remoteEvents:FindFirstChild("Ping")
    if pingRemote and pingRemote:IsA("RemoteFunction") then
        local success, response = pcall(function()
            return pingRemote:InvokeServer("ping")
        end)
        
        if success and response == "pong" then
            print("[InteractionSystem] Server communication verified")
        else
            warn("[InteractionSystem] Server communication test failed")
        end
    end
end

return InteractionSystem
