-- InventoryUILoader.client.luau
-- This script is responsible for ensuring the InventoryUI module is properly loaded and connected

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Wait for player
local player = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()

-- Wait for shared module to be available
local shared = ReplicatedStorage:WaitForChild("shared", 10)

-- Track button connection
local buttonConnection = nil

print("InventoryUILoader: Starting initialization")

local function initializeInventoryUI()
    local success, sharedModule = pcall(function()
        return require(shared)
    end)
    
    if not success then
        warn("InventoryUILoader: Failed to load SharedModule:", sharedModule)
        return false
    end
    
    -- Check if InventoryUI is already available in SharedModule
    if sharedModule.InventoryUI then
        print("InventoryUILoader: InventoryUI is already registered in SharedModule")
        
        -- If it hasn't been initialized yet, do so now
        if not sharedModule.InventoryUI._inventory then
            print("InventoryUILoader: Initializing InventoryUI module")
            sharedModule.InventoryUI.Initialize()
        else
            print("InventoryUILoader: InventoryUI is already initialized")
        end
        
        return true
    end
    
    -- If not available, try to require it directly
    print("InventoryUILoader: InventoryUI not in SharedModule, requiring it directly")
    local core = shared:FindFirstChild("core")
    if not core then
        warn("InventoryUILoader: core folder not found in shared")
        return false
    end
    
    local ui = core:FindFirstChild("ui")
    if not ui then
        warn("InventoryUILoader: ui folder not found in core")
        return false
    end
    
    local inventoryUIModule = ui:FindFirstChild("InventoryUI")
    if not inventoryUIModule then
        warn("InventoryUILoader: InventoryUI module not found in ui folder")
        return false
    end
    
    local inventoryUI
    success, inventoryUI = pcall(function()
        return require(inventoryUIModule)
    end)
    
    if not success then
        warn("InventoryUILoader: Failed to require InventoryUI module:", inventoryUI)
        return false
    end
    
    -- Initialize the InventoryUI module
    if inventoryUI and typeof(inventoryUI.Initialize) == "function" then
        print("InventoryUILoader: Initializing InventoryUI module")
        inventoryUI.Initialize()
        
        -- Register it with SharedModule for other scripts to use
        sharedModule.InventoryUI = inventoryUI
        
        return true
    else
        warn("InventoryUILoader: InventoryUI module does not have an Initialize function")
        return false
    end
end

-- Wait a bit for other scripts to initialize first
wait(1)

-- Try to initialize InventoryUI
local success = initializeInventoryUI()

if success then
    print("InventoryUILoader: Successfully initialized InventoryUI")
    
    -- Connect the inventory button in client_core to our UI if needed
    wait(1) -- Give other scripts time to create their button
    
    local playerGui = player:WaitForChild("PlayerGui")
    local inventoryButtonUI = playerGui:FindFirstChild("InventoryButtonUI")
    
    if inventoryButtonUI then
        local button = inventoryButtonUI:FindFirstChild("InventoryButton")
        if button then
            print("InventoryUILoader: Found inventory button, updating click handler")
            
            -- Get the InventoryUI module again
            local sharedModule = require(shared)
            if sharedModule.InventoryUI then
                -- Clean up existing connection if we have one
                if buttonConnection then
                    buttonConnection:Disconnect()
                    buttonConnection = nil
                end
                
                -- Clear any other existing connections on the button
                local oldConnections = getconnections(button.MouseButton1Click)
                for _, connection in ipairs(oldConnections) do
                    connection:Disconnect()
                end
                
                -- Add a direct test button
                local testButton = Instance.new("TextButton")
                testButton.Name = "TestInventoryButton"
                testButton.Size = UDim2.new(0, 120, 0, 40)
                testButton.Position = UDim2.new(0.5, -60, 1, -110) -- Above the main button
                testButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
                testButton.Font = Enum.Font.GothamBold
                testButton.Text = "Test Inventory"
                testButton.TextSize = 18
                testButton.TextColor3 = Color3.new(1, 1, 1)
                testButton.Parent = inventoryButtonUI
                
                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(0, 8)
                corner.Parent = testButton
                
                -- Connect test button directly to Show function, bypassing Toggle
                testButton.MouseButton1Click:Connect(function()
                    print("TEST BUTTON CLICKED - Directly calling InventoryUI.Show()")
                    sharedModule.InventoryUI.Show()
                end)
                
                -- Create a new connection for the main button - directly use SHOW for consistency
                buttonConnection = button.MouseButton1Click:Connect(function()
                    print("MAIN INVENTORY BUTTON CLICKED - Directly calling Show()")
                    sharedModule.InventoryUI.Show()
                end)
                
                print("InventoryUILoader: Successfully updated inventory button click handler")
            end
        end
    end
else
    warn("InventoryUILoader: Failed to initialize InventoryUI")
end 