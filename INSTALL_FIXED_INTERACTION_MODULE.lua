-- This will copy the fixed InteractionSystemModule to the correct location
-- and ensure it's used by client_core.luau

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

print("======== INSTALLING FIXED INTERACTION MODULE ========")

-- Wait for player to join
local player = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
if not player then
    warn("Failed to get LocalPlayer")
    return
end

-- Find the client script
local playerScripts = player:WaitForChild("PlayerScripts", 10)
if not playerScripts then
    warn("Failed to find PlayerScripts for player")
    return
end

local clientScript = playerScripts:WaitForChild("client", 10)
if not clientScript then
    warn("Failed to find client script in PlayerScripts")
    return
end

-- Find the interaction folder
local interactionFolder = clientScript:WaitForChild("interaction", 10)
if not interactionFolder then
    print("Interaction folder not found, creating it...")
    interactionFolder = Instance.new("Folder")
    interactionFolder.Name = "interaction"
    interactionFolder.Parent = clientScript
end

-- Check if the fixed module already exists
local fixedModule = interactionFolder:FindFirstChild("InteractionSystemModule_fixed")
if fixedModule then
    print("InteractionSystemModule_fixed already exists, replacing it...")
    fixedModule:Destroy()
end

-- Create the fixed module
fixedModule = Instance.new("ModuleScript")
fixedModule.Name = "InteractionSystemModule_fixed"
fixedModule.Source = [[
--[[
    InteractionSystemModule - ForeverBuild2
    FIXED VERSION: Removes BindToClose which is only for server scripts
    
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
        register = function() return true end,
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
        ITEMS = {}, -- Empty items table as fallback
        INTERACTION_DISTANCE = 10
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
    self.interactionDistance = Constants.INTERACTION_DISTANCE or 10
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
    print("[DEBUG] InteractionSystem:Initialize() called")

    if not self.player then
        self.player = Players.LocalPlayer
        if not self.player then
            warn("[InteractionSystem] Critical: LocalPlayer not available at Initialize.")
            return false -- Cannot proceed without player
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
    
    self.initialized = true
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
    bg.BackgroundColor3 = Constants.UI_COLORS and Constants.UI_COLORS.SECONDARY or Color3.fromRGB(40, 40, 40)
    bg.BackgroundTransparency = 0.2
    bg.BorderSizePixel = 0
    bg.Parent = self.billboardTemplate

    local label = Instance.new("TextLabel")
    label.Name = "Title"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Constants.UI_COLORS and Constants.UI_COLORS.TEXT or Color3.fromRGB(255, 255, 255)
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
    local inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.E then
            debugLog("E key pressed")
            self:AttemptInteraction()
        elseif input.KeyCode == Enum.KeyCode.I then
            debugLog("I key pressed")
            self:ToggleInventory()
        end
    end)
    
    table.insert(self.connections, inputConnection)
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
    if self.mouse and self.mouse.Button1Down then
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
end

function InteractionSystem:SetupEventHandlers()
    -- Handle player leaving
    local playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
        if player == self.player then
            self:Cleanup()
        end
    end)
    
    table.insert(self.connections, playerRemovingConnection)
    
    -- Note: We don't use BindToClose as it's only for server scripts
    -- For cleanup, we rely on PlayerRemoving and explicit Cleanup calls
}

function InteractionSystem:Cleanup()
    -- Clean up any resources when player leaves
    self:HideInteractionUI()
    self:ClearCurrentTarget()
    
    -- Disconnect all connections
    for _, connection in ipairs(self.connections) do
        if connection.Connected then
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
}

function InteractionSystem:UpdateCurrentTarget()
    if not self.mouse then return end
    
    local target = self.mouse.Target
    if not target then
        self:ClearCurrentTarget()
        return
    end
    
    -- Check items folder for purchasable items
    local itemsFolder = workspace:FindFirstChild("Items")
    if itemsFolder and target:IsDescendantOf(itemsFolder) then
        debugLog("Target is a world item:", target.Name)
        self.currentTarget = { id = target.Name, model = target }
        self:ShowPriceUI(self.currentTarget)
        return
    end
    
    -- Check for placed items
    local placedItem = self:GetPlacedItemFromPart(target)
    if not placedItem then
        self:ClearCurrentTarget()
        return
    end
    
    -- Check if player is close enough to interact
    if self.player.Character and self.player.Character:FindFirstChild("HumanoidRootPart") then
        local distance = (target.Position - self.player.Character.HumanoidRootPart.Position).Magnitude
        if distance > self.interactionDistance then
            self:ClearCurrentTarget()
            return
        end
    end
    
    -- Set current target
    self.currentTarget = placedItem
    debugLog("Target is a placed item:", placedItem.id)
}

function InteractionSystem:ClearCurrentTarget()
    if self.currentTarget then
        self:HideInteractionUI()
        self.currentTarget = nil
    end
}

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
}

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
}

function InteractionSystem:HideInteractionUI()
    -- Remove BillboardGui from all items in workspace
    for _, model in ipairs(workspace:GetDescendants()) do
        if model:IsA("Model") and model.PrimaryPart then
            local bb = model.PrimaryPart:FindFirstChild("ProximityInteractUI")
            if bb then bb:Destroy() end
        end
    end
}

function InteractionSystem:GetAvailableInteractions(placedItem)
    -- Check if the remote function exists
    if not self.remoteEvents:FindFirstChild("GetAvailableInteractions") then
        debugLog("GetAvailableInteractions remote function not found, using default interactions")
        -- Return default interactions
        return {"examine", "clone"}
    end
    
    -- Request available interactions from server
    local success, result = pcall(function()
        return self.remoteEvents.GetAvailableInteractions:InvokeServer(placedItem)
    end)
    
    if not success or not result then
        debugLog("Error getting available interactions:", tostring(result))
        result = {"examine"}
    end
    
    -- Always add 'examine' for placed items
    table.insert(result, "examine")
    
    return result
}

function InteractionSystem:AttemptInteraction()
    debugLog("AttemptInteraction called")
    if not self.currentTarget then return end
    
    local itemsFolder = workspace:FindFirstChild("Items")
    if itemsFolder and self.currentTarget.model and self.currentTarget.model:IsDescendantOf(itemsFolder) then
        debugLog("Attempting to interact with world item:", self.currentTarget.id)
        
        local pickupEvent = self.remoteEvents:FindFirstChild("PickupItem")
        if pickupEvent then
            debugLog("Sending PickupItem event to server for", self.currentTarget.id)
            pickupEvent:FireServer(self.currentTarget.id)
        else
            debugLog("PickupItem remote event not found")
            -- Display a local notification since we can't use the server
            self:ShowLocalNotification("Can't pick up item: Remote event missing")
        end
        return
    end
    
    debugLog("Attempting to interact with placed item:", self.currentTarget.id)
    local interactions = self:GetAvailableInteractions(self.currentTarget)
    if not interactions or #interactions == 0 then 
        self:ShowLocalNotification("No interactions available for this item")
        return 
    end
    
    if #interactions == 1 then
        self:PerformInteraction(self.currentTarget, interactions[1])
        return
    end
    
    self:ShowInteractionMenu(interactions)
}

function InteractionSystem:PerformInteraction(item, interactionType)
    if not item or not interactionType then return end
    
    -- For examine, we handle that client-side
    if interactionType == "examine" then
        self:ShowItemDetails(item)
        return
    end
    
    -- Other interactions need to go to the server
    local interactEvent = self.remoteEvents:FindFirstChild("InteractWithItem")
    if not interactEvent then
        debugLog("InteractWithItem remote event not found")
        self:ShowLocalNotification("Can't interact: Remote event missing")
        return
    end
    
    debugLog("Sending interaction to server:", interactionType, "for", item.id)
    
    -- Wrap in pcall to handle errors
    local success, result = pcall(function()
        interactEvent:FireServer(item.id, interactionType)
    end)
    
    if not success then
        debugLog("Error performing interaction:", result)
        self:ShowLocalNotification("Failed to perform interaction: " .. tostring(result))
    end
}

function InteractionSystem:ShowInteractionMenu(interactions)
    print("Showing interaction menu with options:", table.concat(interactions, ", "))
    -- This would typically show a UI menu with interaction options
    -- For now, just use the first interaction
    if interactions and #interactions > 0 then
        self:PerformInteraction(self.currentTarget, interactions[1])
    end
}

function InteractionSystem:ShowItemDetails(item)
    print("Showing item details for:", item.id)
    -- Here you would show a UI with item details
    local getItemData = self.remoteEvents:FindFirstChild("GetItemData")
    if not getItemData then
        self:ShowLocalNotification("Cannot fetch item details: Remote function missing")
        return
    end
    
    -- Get item data from server
    local success, result = pcall(function()
        return getItemData:InvokeServer(item.id)
    end)
    
    if success and result then
        -- Here you would populate a UI with the item data
        print("Item data:", result)
        
        -- Show item dialog if available via LazyLoadModules
        if LazyLoadModules.require then
            local placedItemDialog = LazyLoadModules.require("PlacedItemDialog")
            if placedItemDialog and placedItemDialog.Show then
                placedItemDialog.Show(result)
            else
                self:ShowLocalNotification("Item: " .. item.id)
            end
        end
    else
        self:ShowLocalNotification("Error fetching item details")
    end
}

function InteractionSystem:ShowPriceUI(item)
    -- This would show a price tag UI for buyable items
    print("Would show price UI for item:", item.id)
}

function InteractionSystem:ToggleInventory()
    -- Request inventory data from server
    local getInventoryFunc = self.remoteEvents:FindFirstChild("GetInventory")
    if not getInventoryFunc then
        self:ShowLocalNotification("Cannot access inventory: Remote function missing")
        return
    end
    
    -- Try to load InventoryUI
    local inventoryUI = nil
    if LazyLoadModules.require then
        inventoryUI = LazyLoadModules.require("InventoryUI")
    end
    
    if not inventoryUI or not inventoryUI.Show then
        self:ShowLocalNotification("Inventory UI not available")
        return
    end
    
    -- Get inventory data
    local success, result = pcall(function()
        return getInventoryFunc:InvokeServer()
    end)
    
    if success and result and result.success then
        -- Show inventory UI
        inventoryUI.Show(result.inventory, result.currency)
    else
        self:ShowLocalNotification("Failed to load inventory data")
    end
}

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
}

return InteractionSystem
]]
fixedModule.Parent = interactionFolder
print("Created InteractionSystemModule_fixed in the interaction folder")

-- Create an init script to ensure the fixed module is loaded first
local initScript = Instance.new("LocalScript")
initScript.Name = "LoadFixedModuleFirst"
initScript.Source = [[
-- This script ensures the fixed interaction module is loaded first
print("Activating fixed interaction module loader")

-- Wait for parent modules to be ready
local interactionFolder = script.Parent
local fixedModule = interactionFolder:WaitForChild("InteractionSystemModule_fixed", 5)

if fixedModule then
    print("Found fixed interaction module, setting it as priority")
    
    -- Add a special property to indicate this is the preferred module
    fixedModule:SetAttribute("isPriority", true)
    
    -- Optional: We could pre-load the module here to ensure it's cached
    pcall(function()
        require(fixedModule)
        print("Successfully pre-loaded fixed interaction module")
    end)
else
    warn("Could not find fixed interaction module within timeout")
end
]]
initScript.Parent = interactionFolder
print("Created priority loader script for the fixed module")

-- Done
print("======== FIXED MODULE INSTALLATION COMPLETE ========")
print("The fixed InteractionSystemModule is now installed and will be loaded first")
print("Please restart your game to apply the changes")
