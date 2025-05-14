local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Safe initialization of variables
local player = nil
local character = nil
local SharedModule = require(ReplicatedStorage.shared)
-- Initialize the shared module
SharedModule.Init()

local GameManagerModule = SharedModule.GameManager
print("[DEBUG] GameManagerModule obtained from SharedModule. Type:", type(GameManagerModule)) -- <-- ADDED DEBUG
if GameManagerModule then
    print("[DEBUG] GameManagerModule.new type after obtaining from SharedModule:", type(GameManagerModule.new)) -- <-- ADDED DEBUG
end

local Constants = SharedModule.Constants
local GameManager = nil
local PurchaseDialogModule = SharedModule.PurchaseDialog
local InventoryUIModule = SharedModule.InventoryUI
local PlacedItemDialogModule = SharedModule.PlacedItemDialog -- Keep module reference
local Remotes = nil
local BuyItemEvent = nil
local GetInventoryFunc = nil
local PlaceItemEvent = nil
local InteractWithItemEvent = nil

local CurrencyUIModule = SharedModule.CurrencyUI

-- Directly require InteractionSystem
local InteractionSystem -- Module table
local interactionSystemInstance -- Instance of the class
local successIS, interactionSystemOrError

-- Corrected path: script.Parent should be the 'client' folder in StarterPlayerScripts
print("[InteractionSystem Debug] script: " .. script:GetFullName())
print("[InteractionSystem Debug] script.Parent (clientScriptsFolder): " .. (script.Parent and script.Parent:GetFullName() or "nil"))

local clientScriptsFolder = script.Parent 
local interactionFolder = nil
if clientScriptsFolder then
    print("[InteractionSystem Debug] Attempting to find 'interaction' folder in: " .. clientScriptsFolder:GetFullName())
    interactionFolder = clientScriptsFolder:WaitForChild("interaction", 10)
else
    warn("[InteractionSystem Debug] clientScriptsFolder (script.Parent) is nil.")
end

if interactionFolder then
    print("[InteractionSystem Debug] Found 'interaction' folder: " .. interactionFolder:GetFullName())
    print("[InteractionSystem Debug] Children of interaction folder:")
    for _, child in ipairs(interactionFolder:GetChildren()) do
        print("  - " .. child.Name .. " (" .. child.ClassName .. ")")
    end

    local interactionSystemModuleScript = interactionFolder:WaitForChild("InteractionSystemModule", 5) -- <-- Changed to InteractionSystemModule
    if interactionSystemModuleScript then
        print("[InteractionSystem Debug] Found 'InteractionSystemModule' ModuleScript: " .. interactionSystemModuleScript:GetFullName()) -- <-- Updated print
        successIS, interactionSystemOrError = pcall(require, interactionSystemModuleScript)
        if not successIS then
            warn("pcall(require, InteractionSystem) failed: ", tostring(interactionSystemOrError))
        elseif type(interactionSystemOrError) ~= "table" then
            warn("InteractionSystem loaded but is not a table: ", tostring(type(interactionSystemOrError)))
            InteractionSystem = nil
            successIS = false
        else
            InteractionSystem = interactionSystemOrError
        end
    else
        warn("InteractionSystem ModuleScript not found within interaction folder (Path: ", interactionFolder:GetFullName(), "). WaitForChild timed out or it does not exist.")
        successIS = false
        interactionSystemOrError = "InteractionSystem ModuleScript not found (WaitForChild failed)"
    end
else
    warn("Interaction folder not found as child of client scripts folder (Path: ", (clientScriptsFolder and clientScriptsFolder:GetFullName() or "script.Parent was nil"), ")")
    successIS = false
    interactionSystemOrError = "Interaction folder not found"
end


if InteractionSystem then
    print("InteractionSystem loaded successfully by client.client.luau")
    if not InteractionSystem.new or not InteractionSystem.Initialize then
        warn("InteractionSystem loaded but seems to be missing new() or Initialize() methods.")
    end
else
    warn("Failed to load InteractionSystem in client.client.luau. Final status - Success: ", tostring(successIS), "Error/Module: ", tostring(interactionSystemOrError))
end

-- State variables
local currentInventory = {}
local currentCurrency = 0
local isPlacingItem = false
local selectedItem = nil
local placementPreview = nil
local lastError = nil

-- Safe initialization function
local function initializeClient()
    print("[DEBUG] Top of initializeClient()") -- <-- ADDED DEBUG
    if Players then
        player = Players.LocalPlayer
        if player then
            character = player.Character or player.CharacterAdded:Wait()
        end
    end

    if ReplicatedStorage then
        print("[DEBUG] SharedModule:", SharedModule)
        print("[DEBUG] SharedModule.GameManager:", SharedModule and SharedModule.GameManager)
        if GameManagerModule then
            print("[DEBUG] GameManagerModule type:", type(GameManagerModule))
            print("[DEBUG] About to check typeof(GameManagerModule.new) at line 109ish. script.Parent.Parent is: ", script.Parent.Parent and script.Parent.Parent.Name or "nil") -- <-- ADDED DEBUG
            if typeof(GameManagerModule.new) == "function" then
                -- GameManager = GameManagerModule.new()
                local successGM, resultGM = pcall(GameManagerModule.new)
                if successGM then
                    GameManager = resultGM
                    print("[DEBUG] GameManager instance created successfully.")
                else
                    warn("Error creating GameManager instance:", resultGM)
                    GameManager = nil -- Ensure it's nil if creation failed
                end
            else
                warn("GameManagerModule.new is not a function. GameManagerModule is:", GameManagerModule)
            end
        else
            warn("GameManagerModule is nil in initializeClient. SharedModule.GameManager was:", SharedModule and SharedModule.GameManager)
        end

        if InventoryUIModule then
            print("InventoryUIModule appears to be loaded in initializeClient.")
        else
            warn("InventoryUIModule is nil in initializeClient")
        end
    end

    Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
    if Remotes then
        print("[DEBUG] Remotes folder found: " .. Remotes:GetFullName())
        BuyItemEvent = Remotes:WaitForChild("BuyItem", 5)
        GetInventoryFunc = Remotes:WaitForChild("GetInventory", 5)
        PlaceItemEvent = Remotes:WaitForChild("PlaceItem", 5)
        InteractWithItemEvent = Remotes:WaitForChild("InteractWithItem", 5)

        if GetInventoryFunc then
            print("[DEBUG] GetInventory RemoteFunction found: " .. GetInventoryFunc:GetFullName())
        else
            warn("[DEBUG] GetInventory RemoteFunction NOT found in Remotes folder after 5s wait.")
        end
        if BuyItemEvent then print("[DEBUG] BuyItem RemoteEvent found.") else warn("[DEBUG] BuyItem RemoteEvent NOT found.") end
        if PlaceItemEvent then print("[DEBUG] PlaceItem RemoteEvent found.") else warn("[DEBUG] PlaceItem RemoteEvent NOT found.") end
        if InteractWithItemEvent then print("[DEBUG] InteractWithItem RemoteEvent found.") else warn("[DEBUG] InteractWithItem RemoteEvent NOT found.") end

    else
        warn("[DEBUG] Remotes folder NOT found in ReplicatedStorage during initializeClient after 10s wait.")
    end
end

-- Safe helper function to call remote functions
local function safeInvoke(remote, ...)
    local args = {...}
    if not remote then return { success = false, message = "Remote function not found" } end
    
    local ok, resultOrError = pcall(function()
        return remote:InvokeServer(table.unpack(args))
    end)
    
    if not ok then
        lastError = "A network error occurred. Please try again."
        warn("RemoteFunction error:", resultOrError)
        return { success = false, message = lastError }
    end
    
    if type(resultOrError) ~= "table" or not resultOrError.success then
        lastError = (type(resultOrError) == "table" and resultOrError.message) or "Unknown error."
        return { success = false, message = lastError }
    end
    
    lastError = nil
    return resultOrError
end

-- Create inventory button with proper error handling
local function createInventoryButton()
    if not player or not player.PlayerGui then
        warn("Player or PlayerGui not available for createInventoryButton")
        return
    end
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
            warn("GetInventoryFunc not initialized for inventory button click")
            return
        end
        local result = safeInvoke(GetInventoryFunc)
        if result and result.success then
            currentInventory = result.inventory or {}
            currentCurrency = result.currency or 0
            if InventoryUIModule and InventoryUIModule.UpdateInventory and InventoryUIModule.Show then
                InventoryUIModule.UpdateInventory(currentInventory, currentCurrency)
                InventoryUIModule.Show()
            else
                warn("InventoryUIModule not properly initialized or missing methods for inventory button click. UpdateInventory exists: ", tostring(InventoryUIModule and InventoryUIModule.UpdateInventory), "Show exists: ", tostring(InventoryUIModule and InventoryUIModule.Show))
            end
        elseif result then
            warn("Failed to get inventory:", result.message)
        else
            warn("Failed to get inventory: safeInvoke returned nil")
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

    if PurchaseDialogModule and typeof(PurchaseDialogModule.Initialize) == "function" then
        local playerGui = player:WaitForChild("PlayerGui")
        if playerGui then
            local pdScreenGui = playerGui:FindFirstChild("PurchaseDialogScreenGui")
            if not pdScreenGui then
                pdScreenGui = Instance.new("ScreenGui")
                pdScreenGui.Name = "PurchaseDialogScreenGui"
                pdScreenGui.ResetOnSpawn = false
                pdScreenGui.Parent = playerGui
            end
            PurchaseDialogModule.Initialize(pdScreenGui)
            print("PurchaseDialogModule.Initialize() called in initializeUI.")
        else
            warn("PlayerGui not available for PurchaseDialogModule.Initialize in initializeUI")
        end
    else
        warn("PurchaseDialogModule or PurchaseDialogModule.Initialize is nil or not a function in initializeUI. Type of Initialize:", type(PurchaseDialogModule and PurchaseDialogModule.Initialize))
    end

    if InventoryUIModule and InventoryUIModule.Initialize then
        InventoryUIModule.Initialize() 
        print("InventoryUIModule.Initialize() called.")
    else
        warn("InventoryUIModule or InventoryUIModule.Initialize is nil.")
    end
end

-- Run initialization with error handling
local success, errorMsg = pcall(initializeClient) 
if not success then
    warn("Failed to initialize client:", errorMsg)
end

-- Safe initialization of UI
if player then
    local uiSuccess, uiError = pcall(initializeUI)
    if not uiSuccess then
        warn("Failed to initialize UI:", uiError)
    end
end

-- Initialize InteractionSystem instance if the module was loaded
if InteractionSystem and typeof(InteractionSystem.new) == "function" then
    print("[DEBUG] Attempting to create InteractionSystem instance...")
    local successNew, instanceOrError = pcall(InteractionSystem.new)
    if successNew and instanceOrError and typeof(instanceOrError) == "table" then
        interactionSystemInstance = instanceOrError -- Assign to the previously declared variable
        print("[DEBUG] InteractionSystem instance created:", interactionSystemInstance)
        if typeof(interactionSystemInstance.Initialize) == "function" then
            print("[DEBUG] Attempting to call Initialize on InteractionSystem instance...")
            local successInit, initError = pcall(function()
                interactionSystemInstance:Initialize()
            end)
            if successInit then
                print("InteractionSystem instance initialized successfully by client.client.luau")
            else
                warn("Error calling Initialize on InteractionSystem instance:", initError)
            end
        else
            warn("InteractionSystem instance is missing Initialize method. Type of Initialize:", type(interactionSystemInstance and interactionSystemInstance.Initialize), "Instance methods:", interactionSystemInstance)
        end
    elseif successNew and not (instanceOrError and typeof(instanceOrError) == "table") then
        warn("InteractionSystem.new() succeeded but did not return a table instance. Returned:", instanceOrError)
    else
        warn("Failed to create InteractionSystem instance. pcall success:", successNew, "Error/Result:", instanceOrError)
    end
else
    warn("InteractionSystem module is missing, invalid, or .new method not found after loading attempts. Type of InteractionSystem:", type(InteractionSystem), ".new type:", type(InteractionSystem and InteractionSystem.new))
end

-- Initialize PlacedItemDialog if available and parent to a valid ScreenGui
local PlacedItemDialog -- Local scope for this specific initialization
local successPID, resultPID = pcall(function() 
    return require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("core"):WaitForChild("ui"):WaitForChild("PlacedItemDialog"))
end)
if successPID then
    PlacedItemDialog = resultPID
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local screenGui = playerGui:FindFirstChild("PlacedItemDialogUI") 
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "PlacedItemDialogUI" 
        screenGui.Parent = playerGui
    end
    if PlacedItemDialog.Initialize then
        PlacedItemDialog.Initialize(screenGui) 
    else
        warn("PlacedItemDialog module (late init) doesn't have proper Initialize method")
    end
else
    warn("Failed to initialize PlacedItemDialog (late init):", resultPID)
end

-- Return API for other scripts
return {
    GetGameManager = function() return GameManager end,
    ShowInventory = function()
        if InventoryUIModule and InventoryUIModule.Show then
            InventoryUIModule.Show()
        else
            warn("InventoryUIModule not ready or Show method missing for ShowInventory API call.")
        end
    end
}
