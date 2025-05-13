local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Safe initialization of variables
local player = nil
local character = nil
local SharedModule = nil
local GameManagerModule = nil
local Constants = nil
local GameManager = nil
local PurchaseDialogModule = nil
local InventoryUIModule = nil
local PlacedItemDialogModule = nil
local Remotes = nil
local BuyItemEvent = nil
local GetInventoryFunc = nil
local PlaceItemEvent = nil
local InteractWithItemEvent = nil
local purchaseDialog = nil
local inventoryUI = nil
local placedItemDialog = nil

-- State variables
local currentInventory = {}
local currentCurrency = 0
local isPlacingItem = false
local selectedItem = nil
local placementPreview = nil
local lastError = nil

-- Require InteractionSystem module
local InteractionSystem
local success, result = pcall(function()
    return require(ReplicatedStorage.shared.interaction.InteractionSystem)
end)
if success then
    InteractionSystem = result
else
    warn("Failed to require InteractionSystem module:", result)
    InteractionSystem = nil
end

-- Safe initialization function
local function initializeClient()
    if Players then
        player = Players.LocalPlayer
        if player then
            character = player.Character or player.CharacterAdded:Wait()
        end
    end

    if ReplicatedStorage then
        SharedModule = require(ReplicatedStorage.shared)
        if SharedModule then
            GameManagerModule = SharedModule.GameManager
            Constants = SharedModule.Constants

            if GameManagerModule then
                GameManager = GameManagerModule.new()
            end

            if SharedModule.UI then
                PurchaseDialogModule = SharedModule.UI.PurchaseDialog
                InventoryUIModule = SharedModule.UI.InventoryUI
                PlacedItemDialogModule = SharedModule.UI.PlacedItemDialog
            end
        end

        Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
        if Remotes then
            BuyItemEvent = Remotes:WaitForChild("BuyItem", 5)
            GetInventoryFunc = Remotes:WaitForChild("GetInventory", 5)
            PlaceItemEvent = Remotes:WaitForChild("PlaceItem", 5)
            InteractWithItemEvent = Remotes:WaitForChild("InteractWithItem", 5)
        end
    end
end

-- Safe helper function to call remote functions
local function safeInvoke(remote, ...)
    if not remote then return { success = false, message = "Remote function not found" } end
    
    local ok, result = pcall(function(...)
        return remote:InvokeServer(...)
    end, ...)
    
    if not ok then
        lastError = "A network error occurred. Please try again."
        warn("RemoteFunction error:", result)
        return { success = false, message = lastError }
    end
    
    if not result or not result.success then
        lastError = (result and result.message) or "Unknown error."
        return { success = false, message = lastError }
    end
    
    lastError = nil
    return result
end

-- Create inventory button with proper error handling
local function createInventoryButton()
    local playerGui = player.PlayerGui
    local inventoryButtonGui = Instance.new("ScreenGui")
    inventoryButtonGui.Name = "InventoryButtonUI"
    inventoryButtonGui.ResetOnSpawn = false
    inventoryButtonGui.Parent = playerGui

    local button = Instance.new("TextButton")
    button.Name = "InventoryButton"
    button.Size = UDim2.new(0, 120, 0, 40)
    button.Position = UDim2.new(0.5, -60, 1, -60) -- Bottom center
    button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    button.Font = Enum.Font.GothamBold
    button.Text = "Inventory"
    button.TextSize = 18
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Parent = inventoryButtonGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = button

    button.MouseButton1Click:Connect(function()
        if not GetInventoryFunc then
            warn("GetInventoryFunc not initialized")
            return
        end
        local result = safeInvoke(GetInventoryFunc)
        if result.success then
            currentInventory = result.inventory or {}
            currentCurrency = result.currency or 0
            if InventoryUIModule and InventoryUIModule.UpdateInventory and InventoryUIModule.Show then
                InventoryUIModule.UpdateInventory(currentInventory, currentCurrency)
                InventoryUIModule.Show()
            else
                warn("InventoryUIModule not initialized")
            end
        else
            warn("Failed to get inventory:", result.message)
        end
    end)
end

-- Initialize UI components
local function initializeUI()
    if not player then
        warn("Cannot initialize UI: player not found")
        return
    end
    createInventoryButton()
    if PurchaseDialogModule and PurchaseDialogModule.new then
        purchaseDialog = PurchaseDialogModule.new()
        if purchaseDialog.Initialize then
            purchaseDialog:Initialize() -- Let module handle its own ScreenGui
        end
    end
    if InventoryUIModule and InventoryUIModule.Initialize then
        InventoryUIModule.Initialize()
    end
    if PlacedItemDialogModule and PlacedItemDialogModule.new then
        placedItemDialog = PlacedItemDialogModule.new()
        if placedItemDialog.Initialize then
            placedItemDialog:Initialize() -- Let module handle its own ScreenGui
        end
    end
end

-- Run initialization with error handling
local success, error = pcall(initializeClient)
if not success then
    warn("Failed to initialize client:", error)
end

-- Safe initialization of UI
if player then
    local uiSuccess, uiError = pcall(initializeUI)
    if not uiSuccess then
        warn("Failed to initialize UI:", uiError)
    end
end

-- Initialize InteractionSystem if available
if InteractionSystem then
    local interactionSystem = InteractionSystem.new()
    interactionSystem:Initialize()
else
    warn("InteractionSystem module is missing or invalid")
end

-- Initialize PlacedItemDialog if available
local PlacedItemDialog
local success, result = pcall(function()
    return require(ReplicatedStorage.shared.core.ui.PlacedItemDialog)
end)
if success then
    PlacedItemDialog = result
    if PlacedItemDialog.Initialize then
        PlacedItemDialog:Initialize()
    else
        warn("PlacedItemDialog module doesn't have proper initialization method")
    end
else
    warn("Failed to initialize PlacedItemDialog:", result)
end

-- Return API for other scripts
return {
    GetGameManager = function() return GameManager end,
    ShowInventory = function()
        if inventoryUI then
            inventoryUI:Show()
        else
            warn("InventoryUI not initialized")
        end
    end
}
