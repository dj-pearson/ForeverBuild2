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
    -- self.mouse = self.player:GetMouse() -- MOVED to Initialize
    self.currentTarget = nil
    self.interactionDistance = 10 -- Maximum distance for interaction
    self.ui = nil
    self.remoteEvents = ReplicatedStorage.Remotes
    return self
end

function InteractionSystem:Initialize()
    print("[DEBUG] InteractionSystem:Initialize() called")

    if not self.player then
        self.player = Players.LocalPlayer
        if not self.player then
            warn("[InteractionSystemModule] Critical: LocalPlayer not available at Initialize.")
            return -- Cannot proceed without player
        end
    end
    
    self.mouse = self.player:GetMouse() -- Initialize mouse here
    if not self.mouse then
        warn("[InteractionSystemModule] Warning: player:GetMouse() returned nil at Initialize. Mouse-dependent interactions (clicks, target highlighting) will be disabled.")
    end

    self:CreateUI()
    self:SetupInputHandling() -- Handles E key, does not depend on self.mouse

    if self.mouse then -- Only setup mouse handling if mouse is available
        self:SetupMouseHandling()
    else
        print("[DEBUG] InteractionSystem:Initialize() - Mouse not available, skipping SetupMouseHandling.")
    end

    self:SetupEventHandlers()
    self:SetupInventoryKey() -- Handles I key, does not depend on self.mouse
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

function InteractionSystem:SetupInventoryKey()
    -- Handle inventory toggle (I key)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.I then
            print("[DEBUG] Inventory key pressed")
            self:ToggleInventory()
        end
    end)
end

function InteractionSystem:ToggleInventory()
    -- Ensure InventoryUI is loaded
    local InventoryUI = LazyLoadModules.InventoryUI
    if InventoryUI and typeof(InventoryUI.ToggleUI) == "function" then
        InventoryUI.ToggleUI()
    else
        print("[DEBUG] InventoryUI.ToggleUI not available. InventoryUI module might not be loaded properly.")
    end
end

function InteractionSystem:SetupMouseHandling()
    print("[DEBUG] SetupMouseHandling called")
    game:GetService("RunService").RenderStepped:Connect(function()
        self:UpdateCurrentTarget()
    end)
    -- Listen for mouse clicks on placed items
    self.mouse.Button1Down:Connect(function()
        local target = self.mouse.Target
        local placedItem = self:GetPlacedItemFromPart(target)
        if placedItem then
            print("[DEBUG] Clicked placed item:", placedItem.id)
            self.currentTarget = placedItem
            local interactions = self:GetAvailableInteractions(placedItem)
            self:ShowInteractionMenu(interactions)
        end
    end)
end

function InteractionSystem:UpdateCurrentTarget()
    print("[DEBUG] UpdateCurrentTarget called")
    local target = self.mouse.Target
    print("[DEBUG] Mouse target:", target and target.Name or "nil")
    if not target then
        self:ClearCurrentTarget()
        return
    end
    local itemsFolder = workspace:FindFirstChild("Items")
    if itemsFolder and target:IsDescendantOf(itemsFolder) then
        print("[DEBUG] Target is a world item:", target.Name)
        self.currentTarget = { id = target.Name, model = target }
        self:ShowPriceUI(self.currentTarget)
        return
    end
    local placedItem = self:GetPlacedItemFromPart(target)
    if not placedItem then
        self:ClearCurrentTarget()
        return
    end
    local distance = (target.Position - self.player.Character.HumanoidRootPart.Position).Magnitude
    if distance > self.interactionDistance then
        self:ClearCurrentTarget()
        return
    end
    print("[DEBUG] Target is a placed item:", placedItem.id)
    self.currentTarget = placedItem
    -- No proximity UI for placed items
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

function InteractionSystem:ShowPriceUI(worldItem)
    print("[DEBUG] ShowPriceUI for:", worldItem.id)
    -- Remove any existing price GUIs
    for _, model in ipairs(workspace.Items:GetChildren()) do
        if model:IsA("Model") and model.PrimaryPart then
            local bb = model.PrimaryPart:FindFirstChild("PriceBillboard")
            if bb then bb:Destroy() end
        end
    end
    local itemData = Constants.ITEMS[worldItem.id]
    if not itemData then return end
    local priceGui = Instance.new("BillboardGui")
    priceGui.Name = "PriceBillboard"
    priceGui.Size = UDim2.new(0, 200, 0, 60)
    priceGui.StudsOffset = Vector3.new(0, 4, 0)
    priceGui.AlwaysOnTop = true
    priceGui.Parent = worldItem.model.PrimaryPart
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
    print("[DEBUG] AttemptInteraction called")
    if not self.currentTarget then return end
    local itemsFolder = workspace:FindFirstChild("Items")
    if itemsFolder and self.currentTarget.model and self.currentTarget.model:IsDescendantOf(itemsFolder) then
        print("[DEBUG] Attempting to interact with world item:", self.currentTarget.id)
        if self.remoteEvents:FindFirstChild("PickupItem") then
            self.remoteEvents.PickupItem:FireServer(self.currentTarget.id)
        else
            print("[DEBUG] PickupItem remote event not found")
            -- Display a local notification since we can't use the server
            self:ShowLocalNotification("Can't pick up item: Remote event missing")
        end
        return
    end
    print("[DEBUG] Attempting to interact with placed item:", self.currentTarget.id)
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
        print("[DEBUG] GetAvailableInteractions remote function not found, using default interactions")
        -- Return default interactions
        return {"examine", "clone"}
    end
    
    -- Request available interactions from server
    local success, result = pcall(function()
        return self.remoteEvents.GetAvailableInteractions:InvokeServer(placedItem)
    end)
    
    if not success or not result then
        print("[DEBUG] Error getting available interactions:", result)
        result = {"examine"}
    end
    
    -- Always add 'clone' for placed items
    table.insert(result, "clone")
    return result
end

function InteractionSystem:PerformInteraction(placedItem, interactionType)
    print("[DEBUG] PerformInteraction called for", placedItem.id, interactionType)
    if interactionType == "clone" then
        if self.remoteEvents:FindFirstChild("CloneItem") then
            self.remoteEvents.CloneItem:FireServer(placedItem.id)
        else
            print("[DEBUG] CloneItem remote event not found")
            self:ShowLocalNotification("Can't clone item: Remote event missing")
        end
        return
    end
    
    if self.remoteEvents:FindFirstChild("InteractWithItem") then
        self.remoteEvents.InteractWithItem:FireServer(placedItem, interactionType)
    else
        print("[DEBUG] InteractWithItem remote event not found")
        self:ShowLocalNotification("Can't " .. interactionType .. " item: Remote event missing")
    end
end

function InteractionSystem:ShowInteractionMenu(interactions)
    local itemForInteraction = self.currentTarget -- Capture the item at the moment the menu is to be shown
    if not itemForInteraction then
        print("[DEBUG] ShowInteractionMenu called with no currentTarget.")
        return
    end

    -- Ensure LazyLoadModules.PlacedItemDialog is loaded and has ShowInteractionOptions
    local PlacedItemDialog = LazyLoadModules.PlacedItemDialog 
    if PlacedItemDialog and typeof(PlacedItemDialog.ShowInteractionOptions) == "function" then
        PlacedItemDialog.ShowInteractionOptions(itemForInteraction, interactions, function(interaction)
            self:PerformInteraction(itemForInteraction, interaction) -- Use captured item
        end)
    else
        print("[DEBUG] PlacedItemDialog.ShowInteractionOptions not available or PlacedItemDialog module is nil. Using fallback for item:", itemForInteraction.id)
        if interactions and #interactions > 0 then
            self:PerformInteraction(itemForInteraction, interactions[1]) -- Use captured item
        else
            print("[DEBUG] No interactions available for fallback in ShowInteractionMenu for item:", itemForInteraction.id)
        end
    end
end

function InteractionSystem:SetupEventHandlers()
    -- Handle interaction responses
    if self.remoteEvents:FindFirstChild("NotifyPlayer") then
        self.remoteEvents.NotifyPlayer.OnClientEvent:Connect(function(message)
            self:ShowNotification(message)
        end)
    else
        print("[DEBUG] NotifyPlayer remote event not found")
    end
end

function InteractionSystem:ShowNotification(message)
    -- Implementation depends on your game's UI system
    print("[NOTIFICATION]", message)
    -- You could show this in a UI element
end

function InteractionSystem:ShowLocalNotification(message)
    -- For local notifications when server communication fails
    print("[LOCAL NOTIFICATION]", message)
    -- Show in UI similar to ShowNotification
end

return InteractionSystem
