local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

-- Add debug print to confirm module is loading
print("InteractionSystem module loading...")

-- Use our new LazyLoadModules helper
local LazyLoadModules = require(ReplicatedStorage.shared.core.LazyLoadModules)
local Constants = require(ReplicatedStorage.shared.core.Constants)

-- Register UI modules for lazy loading
LazyLoadModules.register("PurchaseDialog", ReplicatedStorage.shared.core.ui.PurchaseDialog)
LazyLoadModules.register("InventoryUI", ReplicatedStorage.shared.core.ui.InventoryUI)
LazyLoadModules.register("PlacedItemDialog", ReplicatedStorage.shared.core.ui.PlacedItemDialog)

local InteractionSystem = {}
InteractionSystem.__index = InteractionSystem

function InteractionSystem.new()
    local self = setmetatable({}, InteractionSystem)
    self.player = Players.LocalPlayer
    self.mouse = self.player:GetMouse()
    self.currentTarget = nil
    self.interactionDistance = 10 -- Maximum distance for interaction
    self.ui = nil
    self.remoteEvents = ReplicatedStorage.Remotes
    return self
end

function InteractionSystem:Initialize()
    print("InteractionSystem initialized")
    
    -- Create UI
    self:CreateUI()
    
    -- Set up input handling
    self:SetupInputHandling()
    
    -- Set up mouse movement
    self:SetupMouseHandling()
    
    -- Set up event handlers
    self:SetupEventHandlers()
    
    -- Set up inventory key
    self:SetupInventoryKey()
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
end

function InteractionSystem:SetupInputHandling()
    -- Handle interaction input (E key)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.E then
            self:AttemptInteraction()
        end
    end)
end

function InteractionSystem:SetupMouseHandling()
    -- Update current target on mouse movement
    game:GetService("RunService").RenderStepped:Connect(function()
        self:UpdateCurrentTarget()
    end)
end

function InteractionSystem:UpdateCurrentTarget()
    local target = self.mouse.Target
    if not target then
        self:ClearCurrentTarget()
        return
    end
    
    -- Check if target is a placed item
    local placedItem = self:GetPlacedItemFromPart(target)
    if not placedItem then
        self:ClearCurrentTarget()
        return
    end
    
    -- Check distance
    local distance = (target.Position - self.player.Character.HumanoidRootPart.Position).Magnitude
    if distance > self.interactionDistance then
        self:ClearCurrentTarget()
        return
    end
    
    -- Update current target
    self.currentTarget = placedItem
    
    -- Show interaction UI
    self:ShowInteractionUI(placedItem)
end

function InteractionSystem:ClearCurrentTarget()
    if self.currentTarget then
        self:HideInteractionUI()
        self.currentTarget = nil
    end
end

function InteractionSystem:GetPlacedItemFromPart(part)
    local current = part
    while current and current ~= workspace do
        if current:IsA("Model") and current:GetAttribute("item") then
            return {
                id = current.Name,
                model = current
            }
        end
        current = current.Parent
    end
    return nil
end

function InteractionSystem:ShowInteractionUI(placedItem)
    -- Attach BillboardGui to the item model's PrimaryPart
    if not placedItem.model.PrimaryPart then
        placedItem.model.PrimaryPart = placedItem.model:FindFirstChildWhichIsA("BasePart")
    end
    if not placedItem.model.PrimaryPart then return end

    -- Remove any existing BillboardGui
    local existing = placedItem.model.PrimaryPart:FindFirstChild("ProximityInteractUI")
    if existing then existing:Destroy() end

    local bb = self.billboardTemplate:Clone()
    bb.Enabled = true
    bb.Parent = placedItem.model.PrimaryPart
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

function InteractionSystem:AttemptInteraction()
    if not self.currentTarget then return end
    
    -- Get available interactions
    local interactions = self:GetAvailableInteractions(self.currentTarget)
    if not interactions or #interactions == 0 then return end
    
    -- If only one interaction is available, use it
    if #interactions == 1 then
        self:PerformInteraction(self.currentTarget, interactions[1])
        return
    end
    
    -- Show interaction menu
    self:ShowInteractionMenu(interactions)
end

function InteractionSystem:GetAvailableInteractions(placedItem)
    -- Request available interactions from server
    local result = self.remoteEvents.GetAvailableInteractions:InvokeServer(placedItem)
    return result or {"examine"}
end

function InteractionSystem:PerformInteraction(placedItem, interactionType)
    -- Send interaction request to server
    self.remoteEvents.InteractWithItem:FireServer(placedItem, interactionType)
end

function InteractionSystem:ShowInteractionMenu(interactions)
    -- Use the lazily loaded PlacedItemDialog to show interaction options
    -- The module will only be required when this function is called
    if LazyLoadModules.PlacedItemDialog.ShowInteractionOptions then
        LazyLoadModules.PlacedItemDialog.ShowInteractionOptions(self.currentTarget, interactions, function(interaction)
            self:PerformInteraction(self.currentTarget, interaction)
        end)
    else
        -- Fallback: just use the first interaction
        self:PerformInteraction(self.currentTarget, interactions[1])
    end
end

function InteractionSystem:SetupEventHandlers()
    -- Handle interaction responses
    self.remoteEvents.NotifyPlayer.OnClientEvent:Connect(function(message)
        self:ShowNotification(message)
    end)
end

function InteractionSystem:ShowNotification(message)
    -- Create notification UI
    local notification = Instance.new("ScreenGui")
    notification.Name = "Notification"
    notification.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    
    local frame = Instance.new("Frame")
    frame.Name = "NotificationFrame"
    frame.Size = UDim2.new(0, 300, 0, 50)
    frame.Position = UDim2.new(0.5, -150, 0.1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    frame.BorderSizePixel = 0
    frame.Parent = notification
    
    local label = Instance.new("TextLabel")
    label.Name = "MessageLabel"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 18
    label.Font = Enum.Font.GothamBold
    label.Text = message
    label.Parent = frame
    
    -- Animate and destroy
    game:GetService("Debris"):AddItem(notification, 3)
end

function InteractionSystem:SetupInventoryKey()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.I then
            self:OpenInventory()
        end
    end)
end

function InteractionSystem:OpenInventory()
    -- Fetch inventory from server
    local inventory = self.remoteEvents.GetInventory:InvokeServer()
    if not inventory or not inventory.success then
        self:ShowNotification("Could not load inventory")
        return
    end
    
    -- Use the lazily loaded InventoryUI module to display inventory
    if LazyLoadModules.InventoryUI.Show then
        LazyLoadModules.InventoryUI.Show(inventory.inventory, inventory.currency)
    else
        self:ShowNotification("Inventory system is not available")
    end
end

return InteractionSystem
