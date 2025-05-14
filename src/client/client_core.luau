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
print("[DEBUG in client_core.luau] GameManagerModule obtained from SharedModule. Type:", type(GameManagerModule)) -- <-- ADDED DEBUG
if GameManagerModule then
    print("[DEBUG in client_core.luau] GameManagerModule.new type after obtaining from SharedModule:", type(GameManagerModule.new)) -- <-- ADDED DEBUG
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

-- Corrected path: In a ModuleScript child of a LocalScript,
-- 'script' is the ModuleScript, 'script.Parent' is the LocalScript.
-- The 'interaction' folder is a child of the LocalScript.
print("[InteractionSystem Debug in client_core.luau] script (ModuleScript): " .. script:GetFullName())
print("[InteractionSystem Debug in client_core.luau] script.Parent (LocalScript 'client'): " .. (script.Parent and script.Parent:GetFullName() or "nil"))

local localScriptInstance = script.Parent -- This should be the 'client' LocalScript
local interactionFolder = nil

if localScriptInstance then
    print("[InteractionSystem Debug in client_core.luau] Attempting to find 'interaction' folder in: " .. localScriptInstance:GetFullName())
    interactionFolder = localScriptInstance:WaitForChild("interaction", 10) -- Correct path: localScriptInstance.interaction
else
    warn("[InteractionSystem Debug in client_core.luau] localScriptInstance (script.Parent) is nil. This means client_core.luau is not a child of the expected LocalScript.")
end

if interactionFolder then
    print("[InteractionSystem Debug in client_core.luau] Found 'interaction' folder: " .. interactionFolder:GetFullName())
    print("[InteractionSystem Debug in client_core.luau] Children of interaction folder:")
    for _, child in ipairs(interactionFolder:GetChildren()) do
        print("  - " .. child.Name .. " (" .. child.ClassName .. ")")
    end

    local interactionSystemModuleScript = interactionFolder:WaitForChild("InteractionSystemModule", 5) -- <-- Changed to InteractionSystemModule
    if interactionSystemModuleScript then
        print("[InteractionSystem Debug in client_core.luau] Found 'InteractionSystemModule' ModuleScript: " .. interactionSystemModuleScript:GetFullName()) -- <-- Updated print
        successIS, interactionSystemOrError = pcall(require, interactionSystemModuleScript)
        if not successIS then
            warn("pcall(require, InteractionSystem) failed in client_core.luau: ", tostring(interactionSystemOrError))
        elseif type(interactionSystemOrError) ~= "table" then
            warn("InteractionSystem loaded in client_core.luau but is not a table: ", tostring(type(interactionSystemOrError)))
            InteractionSystem = nil
            successIS = false
        else
            InteractionSystem = interactionSystemOrError
        end
    else
        warn("InteractionSystem ModuleScript not found within interaction folder (Path in client_core.luau: ", interactionFolder:GetFullName(), "). WaitForChild timed out or it does not exist.")
        successIS = false
        interactionSystemOrError = "InteractionSystem ModuleScript not found (WaitForChild failed)"
    end
else
    warn("Interaction folder not found as child of client script (Path in client_core.luau: ", (localScriptInstance and localScriptInstance:GetFullName() or "script.Parent was nil"), ")")
    successIS = false
    interactionSystemOrError = "Interaction folder not found"
end


if InteractionSystem then
    print("InteractionSystem loaded successfully by client_core.luau")
    if not InteractionSystem.new or not InteractionSystem.Initialize then
        warn("InteractionSystem loaded by client_core.luau but seems to be missing new() or Initialize() methods.")
    end
else
    warn("Failed to load InteractionSystem in client_core.luau. Final status - Success: ", tostring(successIS), "Error/Module: ", tostring(interactionSystemOrError))
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
    print("[DEBUG in client_core.luau] Top of initializeClient()") -- <-- ADDED DEBUG
    if Players then
        player = Players.LocalPlayer
        if player then
            character = player.Character or player.CharacterAdded:Wait()
        end
    end

    if ReplicatedStorage then
        print("[DEBUG in client_core.luau] SharedModule:", SharedModule)
        print("[DEBUG in client_core.luau] SharedModule.GameManager:", SharedModule and SharedModule.GameManager)
        if GameManagerModule then
            print("[DEBUG in client_core.luau] GameManagerModule type:", type(GameManagerModule))
            print("[DEBUG in client_core.luau] Original line 108 print - script.Parent.Parent (of ModuleScript) is: ", script.Parent.Parent and script.Parent.Parent:GetFullName() or "nil")

            print("[LINE 108 PRE-CHECK in client_core.luau] --- Detailed Debug for Line 109 --- ")
            print("[LINE 108 PRE-CHECK in client_core.luau] script (ModuleScript):GetFullName() = ", script:GetFullName())
            print("[LINE 108 PRE-CHECK in client_core.luau] script.Parent (LocalScript):GetFullName() = ", script.Parent:GetFullName())
            -- This check might be misleading now as 'interaction' is a child of script.Parent (the LocalScript)
            -- print("[LINE 108 PRE-CHECK in client_core.luau] Does script.Parent.interaction exist? Answer:", tostring(script.Parent:FindFirstChild("interaction") ~= nil))

            local gmm_new_prop_access_success, gmm_new_prop_or_error = pcall(function() return GameManagerModule.new end)
            local gmm_new_prop

            if gmm_new_prop_access_success then
                gmm_new_prop = gmm_new_prop_or_error
                print("[LINE 108 PRE-CHECK in client_core.luau] Successfully accessed GameManagerModule.new. Its type is:", type(gmm_new_prop))
            else
                gmm_new_prop = nil -- Ensure it's nil if access failed
                print("[LINE 108 PRE-CHECK in client_core.luau] ERROR accessing GameManagerModule.new:", tostring(gmm_new_prop_or_error))
                -- This is a critical point; if the error happens here, it's during property access.
            end

            print("[LINE 108 PRE-CHECK in client_core.luau] About to evaluate: typeof(gmm_new_prop) == 'function'")
            if typeof(gmm_new_prop) == "function" then -- This is the new line 109 equivalent
                print("[LINE 109 SUCCESS in client_core.luau] typeof(GameManagerModule.new) is 'function'")
                local successGM, resultGM = pcall(GameManagerModule.new)
                if successGM then
                    GameManager = resultGM
                    print("[DEBUG in client_core.luau] GameManager instance created successfully.")
                else
                    warn("Error creating GameManager instance in client_core.luau:", resultGM)
                    GameManager = nil -- Ensure it's nil if creation failed
                end
            else
                print("[LINE 109 FAIL in client_core.luau] typeof(GameManagerModule.new) is NOT 'function'. Actual type of gmm_new_prop:", typeof(gmm_new_prop))
                warn("GameManagerModule.new is not a function in client_core.luau. GameManagerModule is:", GameManagerModule, ". GameManagerModule.new was (type " .. type(gmm_new_prop) .. "):", gmm_new_prop)
            end
            print("[LINE 109 POST-CHECK in client_core.luau] --- End Detailed Debug ---")
        else
            warn("GameManagerModule is nil in initializeClient (client_core.luau). SharedModule.GameManager was:", SharedModule and SharedModule.GameManager)
        end

        if InventoryUIModule then
            print("InventoryUIModule appears to be loaded in initializeClient (client_core.luau).")
        else
            warn("InventoryUIModule is nil in initializeClient (client_core.luau)")
        end
    end

    Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
    if Remotes then
        print("[DEBUG in client_core.luau] Remotes folder found: " .. Remotes:GetFullName())
        BuyItemEvent = Remotes:WaitForChild("BuyItem", 5)
        GetInventoryFunc = Remotes:WaitForChild("GetInventory", 5)
        PlaceItemEvent = Remotes:WaitForChild("PlaceItem", 5)
        InteractWithItemEvent = Remotes:WaitForChild("InteractWithItem", 5)

        if GetInventoryFunc then
            print("[DEBUG in client_core.luau] GetInventory RemoteFunction found: " .. GetInventoryFunc:GetFullName())
        else
            warn("[DEBUG in client_core.luau] GetInventory RemoteFunction NOT found in Remotes folder after 5s wait.")
        end
        if BuyItemEvent then print("[DEBUG in client_core.luau] BuyItem RemoteEvent found.") else warn("[DEBUG in client_core.luau] BuyItem RemoteEvent NOT found.") end
        if PlaceItemEvent then print("[DEBUG in client_core.luau] PlaceItem RemoteEvent found.") else warn("[DEBUG in client_core.luau] PlaceItem RemoteEvent NOT found.") end
        if InteractWithItemEvent then print("[DEBUG in client_core.luau] InteractWithItem RemoteEvent found.") else warn("[DEBUG in client_core.luau] InteractWithItem RemoteEvent NOT found.") end

    else
        warn("[DEBUG in client_core.luau] Remotes folder NOT found in ReplicatedStorage during initializeClient after 10s wait.")
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
        warn("RemoteFunction error in client_core.luau:", resultOrError)
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
        warn("Player or PlayerGui not available for createInventoryButton in client_core.luau")
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
            warn("GetInventoryFunc not initialized for inventory button click in client_core.luau")
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
                warn("InventoryUIModule not properly initialized or missing methods for inventory button click in client_core.luau. UpdateInventory exists: ", tostring(InventoryUIModule and InventoryUIModule.UpdateInventory), "Show exists: ", tostring(InventoryUIModule and InventoryUIModule.Show))
            end
        elseif result then
            warn("Failed to get inventory in client_core.luau:", result.message)
        else
            warn("Failed to get inventory in client_core.luau: safeInvoke returned nil")
        end
    end)
end

-- Initialize UI components
local function initializeUI()
    if not player then
        warn("Cannot initialize UI in client_core.luau: player not found")
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
            print("PurchaseDialogModule.Initialize() called in initializeUI (client_core.luau).")
        else
            warn("PlayerGui not available for PurchaseDialogModule.Initialize in initializeUI (client_core.luau)")
        end
    else
        warn("PurchaseDialogModule or PurchaseDialogModule.Initialize is nil or not a function in initializeUI (client_core.luau). Type of Initialize:", type(PurchaseDialogModule and PurchaseDialogModule.Initialize))
    end

    if InventoryUIModule and InventoryUIModule.Initialize then
        InventoryUIModule.Initialize() 
        print("InventoryUIModule.Initialize() called in client_core.luau.")
    else
        warn("InventoryUIModule or InventoryUIModule.Initialize is nil in client_core.luau.")
    end
end

-- Run initialization with error handling
local success, errorMsg = pcall(initializeClient) 
if not success then
    warn("Failed to initialize client in client_core.luau:", errorMsg)
end

-- Safe initialization of UI
if player then
    local uiSuccess, uiError = pcall(initializeUI)
    if not uiSuccess then
        warn("Failed to initialize UI in client_core.luau:", uiError)
    end
end

-- Initialize InteractionSystem instance if the module was loaded
if InteractionSystem and typeof(InteractionSystem.new) == "function" then
    print("[DEBUG in client_core.luau] Attempting to create InteractionSystem instance...")
    local successNew, instanceOrError = pcall(InteractionSystem.new)
    if successNew and instanceOrError and typeof(instanceOrError) == "table" then
        interactionSystemInstance = instanceOrError -- Assign to the previously declared variable
        print("[DEBUG in client_core.luau] InteractionSystem instance created:", interactionSystemInstance)
        if typeof(interactionSystemInstance.Initialize) == "function" then
            print("[DEBUG in client_core.luau] Attempting to call Initialize on InteractionSystem instance...")
            local successInit, initError = pcall(function()
                interactionSystemInstance:Initialize()
            end)
            if successInit then
                print("InteractionSystem instance initialized successfully by client_core.luau")
            else
                warn("Error calling Initialize on InteractionSystem instance in client_core.luau:", initError)
            end
        else
            warn("InteractionSystem instance is missing Initialize method in client_core.luau. Type of Initialize:", type(interactionSystemInstance and interactionSystemInstance.Initialize), "Instance methods:", interactionSystemInstance)
        end
    elseif successNew and not (instanceOrError and typeof(instanceOrError) == "table") then
        warn("InteractionSystem.new() succeeded in client_core.luau but did not return a table instance. Returned:", instanceOrError)
    else
        warn("Failed to create InteractionSystem instance in client_core.luau. pcall success:", successNew, "Error/Result:", instanceOrError)
    end
else
    warn("InteractionSystem module is missing, invalid, or .new method not found after loading attempts in client_core.luau. Type of InteractionSystem:", type(InteractionSystem), ".new type:", type(InteractionSystem and InteractionSystem.new))
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
        warn("PlacedItemDialog module (late init in client_core.luau) doesn't have proper Initialize method")
    end
else
    warn("Failed to initialize PlacedItemDialog (late init in client_core.luau):", resultPID)
end

-- Return API for other scripts
return {
    GetGameManager = function() return GameManager end,
    ShowInventory = function()
        if InventoryUIModule and InventoryUIModule.Show then
            InventoryUIModule.Show()
        else
            warn("InventoryUIModule not ready or Show method missing for ShowInventory API call in client_core.luau.")
        end
    end
}
