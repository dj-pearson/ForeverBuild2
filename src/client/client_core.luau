local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Safe initialization of variables
local player = nil
local character = nil

-- Safely require the shared module
print("client_core.luau: Attempting to require shared module")
local SharedModule
local success, errorMessage = pcall(function()
    local shared = ReplicatedStorage:WaitForChild("shared", 10)
    print("client_core.luau: Found shared module at " .. shared:GetFullName())
    SharedModule = require(shared)
    return true
end)

if not success then
    warn("client_core.luau: Failed to require SharedModule:", errorMessage)
    SharedModule = {}
else
    print("client_core.luau: Successfully required SharedModule")
    -- Initialize the shared module
    if SharedModule.Init then
        local initSuccess, initError = pcall(function()
            SharedModule.Init()
        end)
        
        if not initSuccess then
            warn("client_core.luau: Failed to initialize SharedModule:", initError)
        else
            print("client_core.luau: SharedModule initialized successfully")
        end
    end
end

-- Get references to needed modules
print("client_core.luau: Getting references to modules")
local GameManagerModule = SharedModule.GameManager
local Constants = SharedModule.Constants
local PurchaseDialogModule = SharedModule.PurchaseDialog
local InventoryUIModule = SharedModule.InventoryUI
local PlacedItemDialogModule = SharedModule.PlacedItemDialog
local CurrencyUIModule = SharedModule.CurrencyUI

-- Print debug info about loaded modules
print("client_core.luau: Module references:")
print("  - GameManagerModule: " .. (GameManagerModule ~= nil and "loaded" or "nil"))
print("  - Constants: " .. (Constants ~= nil and "loaded" or "nil"))
print("  - PurchaseDialogModule: " .. (PurchaseDialogModule ~= nil and "loaded" or "nil"))
print("  - InventoryUIModule: " .. (InventoryUIModule ~= nil and "loaded" or "nil"))
print("  - PlacedItemDialogModule: " .. (PlacedItemDialogModule ~= nil and "loaded" or "nil"))
print("  - CurrencyUIModule: " .. (CurrencyUIModule ~= nil and "loaded" or "nil"))

local GameManager = nil
local Remotes = nil
local BuyItemEvent = nil
local GetInventoryFunc = nil
local PlaceItemEvent = nil
local InteractWithItemEvent = nil

-- Directly require InteractionSystem with improved path resolution
local InteractionSystem -- Module table
local interactionSystemInstance -- Instance of the class

-- Get the interaction folder directly from script.Parent (the LocalScript)
local localScriptInstance = script.Parent -- This should be the 'client' LocalScript
local interactionFolder = nil

if localScriptInstance then
    print("[InteractionSystem] Looking for interaction folder in: " .. localScriptInstance:GetFullName())
    interactionFolder = localScriptInstance:WaitForChild("interaction", 10)
    
    if interactionFolder then
        print("[InteractionSystem] Found interaction folder: " .. interactionFolder:GetFullName())
        
        -- Look for InteractionSystemModule
        local interactionSystemModuleScript = interactionFolder:WaitForChild("InteractionSystemModule_enhanced", 5)
        if interactionSystemModuleScript then
            print("[InteractionSystem] Found InteractionSystemModule_enhanced: " .. interactionSystemModuleScript:GetFullName())
            
            local success, result = pcall(require, interactionSystemModuleScript)
            if success then
                InteractionSystem = result
                print("[InteractionSystem] Successfully loaded enhanced InteractionSystemModule")
            else
                warn("[InteractionSystem] Failed to require enhanced InteractionSystemModule: " .. tostring(result))
                
                -- Fall back to the original module
                local originalModule = interactionFolder:WaitForChild("InteractionSystemModule", 5)
                if originalModule then
                    local origSuccess, origResult = pcall(require, originalModule)
                    if origSuccess then
                        InteractionSystem = origResult
                        print("[InteractionSystem] Successfully loaded fallback InteractionSystemModule")
                    else
                        warn("[InteractionSystem] Failed to require fallback InteractionSystemModule: " .. tostring(origResult))
                    end
                end
            end
        else
            warn("[InteractionSystem] InteractionSystemModule not found in interaction folder")
        end
    else
        warn("[InteractionSystem] Interaction folder not found in " .. localScriptInstance:GetFullName())
    end
else
    warn("[InteractionSystem] LocalScript instance (script.Parent) is nil")
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

    -- Initialize UI components only once
    if InventoryUIModule then
        local inventoryUI = nil
        if typeof(InventoryUIModule) == "table" and InventoryUIModule.new then
            inventoryUI = InventoryUIModule.new()
            if inventoryUI and inventoryUI.Initialize then
                inventoryUI:Initialize()
                print("[UI] InventoryUI initialized successfully")
            end
        elseif typeof(InventoryUIModule) == "table" and InventoryUIModule.Initialize then
            InventoryUIModule.Initialize(player.PlayerGui)
            print("[UI] InventoryUI initialized successfully (functional style)")
        end
    else
        warn("[UI] InventoryUIModule is nil")
    end
    
    if PlacedItemDialogModule then
        local placedItemDialog = nil
        if typeof(PlacedItemDialogModule) == "table" and PlacedItemDialogModule.new then
            placedItemDialog = PlacedItemDialogModule.new()
            if placedItemDialog and placedItemDialog.Initialize then
                placedItemDialog:Initialize()
                print("[UI] PlacedItemDialog initialized successfully")
            end
        elseif typeof(PlacedItemDialogModule) == "table" and PlacedItemDialogModule.Initialize then
            PlacedItemDialogModule.Initialize(player.PlayerGui)
            print("[UI] PlacedItemDialog initialized successfully (functional style)")
        end
    else
        warn("[UI] PlacedItemDialogModule is nil")
    end
    
    if PurchaseDialogModule then
        local purchaseDialog = nil
        if typeof(PurchaseDialogModule) == "table" and PurchaseDialogModule.new then
            purchaseDialog = PurchaseDialogModule.new()
            if purchaseDialog and purchaseDialog.Initialize then
                purchaseDialog:Initialize()
                print("[UI] PurchaseDialog initialized successfully")
            end
        elseif typeof(PurchaseDialogModule) == "table" and PurchaseDialogModule.Initialize then
            PurchaseDialogModule.Initialize(player.PlayerGui)
            print("[UI] PurchaseDialog initialized successfully (functional style)")
        end
    else
        warn("[UI] PurchaseDialogModule is nil")
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
