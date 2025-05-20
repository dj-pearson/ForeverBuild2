print("--- THIS IS THE VERY LATEST VERSION OF DirectInventoryUI.client.luau, TIMESTAMP: " .. os.time() .. " ---")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SharedModule = nil
local InventoryUIModule = nil

local MAX_WAIT_TIME = 10 -- seconds
local waitInterval = 0.1
local timeWaited = 0

-- Wait for SharedModule and InventoryUI to be ready
repeat
    SharedModule = ReplicatedStorage:FindFirstChild("shared")
    if SharedModule then
        local success, module = pcall(function()
            return require(SharedModule)
        end)
        if success and module and module.InventoryUI and typeof(module.InventoryUI.Toggle) == "function" then
            InventoryUIModule = module.InventoryUI
            break
        end
    end
    task.wait(waitInterval)
    timeWaited = timeWaited + waitInterval
until InventoryUIModule or timeWaited > MAX_WAIT_TIME

if not InventoryUIModule then
    warn("DirectInventoryUI: Timed out waiting for SharedModule.InventoryUI with a Toggle function.")
    return
end

print("DirectInventoryUI: Shared InventoryUI module found and ready.")

-- Find or create the inventory button
local inventoryButtonUI = playerGui:FindFirstChild("InventoryButtonUI")
local inventoryButton

if inventoryButtonUI and inventoryButtonUI:FindFirstChild("InventoryButton") then
    inventoryButton = inventoryButtonUI:FindFirstChild("InventoryButton")
    print("DirectInventoryUI: Found existing inventory button provided by SharedModule.InventoryUI")
else
    -- Fallback: If SharedModule.InventoryUI didn't create one, or if we need a dedicated button.
    -- This part might be redundant if SharedModule.InventoryUI.CreateButton() always runs.
    print("DirectInventoryUI: SharedModule.InventoryUI did not create a button, or it's not found. Creating a simple one.")
    inventoryButtonUI = Instance.new("ScreenGui")
    inventoryButtonUI.Name = "DirectInventoryButtonUI" -- Different name to avoid conflict
    inventoryButtonUI.ResetOnSpawn = false
    inventoryButtonUI.Parent = playerGui

    inventoryButton = Instance.new("TextButton")
    inventoryButton.Name = "InventoryButton"
    inventoryButton.Size = UDim2.new(0, 150, 0, 50)
    inventoryButton.Position = UDim2.new(0.5, -75, 1, -70) -- Bottom center
    inventoryButton.Text = "Inventory (D)"
    inventoryButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    inventoryButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    inventoryButton.Font = Enum.Font.SourceSansBold
    inventoryButton.TextSize = 18
    inventoryButton.Parent = inventoryButtonUI
    print("DirectInventoryUI: Created a fallback inventory button.")
end

if inventoryButton then
    print("DirectInventoryUI: Connecting button to SharedModule.InventoryUI.Toggle")
    inventoryButton.MouseButton1Click:Connect(function()
        print("DirectInventoryUI: Inventory button clicked, calling SharedModule.InventoryUI.Toggle()")
        InventoryUIModule.Toggle()
    end)
else
    warn("DirectInventoryUI: Could not find or create an inventory button.")
end

-- Optional: Keep the I key toggle if desired, directly calling the shared toggle
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.I and not gameProcessedEvent then
            print("DirectInventoryUI: 'I' key pressed, calling SharedModule.InventoryUI.Toggle()")
            InventoryUIModule.Toggle()
        end
    end
end)

print("DirectInventoryUI: Setup complete.") 