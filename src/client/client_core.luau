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
    print("client_core.luau: Creating minimal SharedModule fallback")
    SharedModule = {
        Constants = {
            INTERACTION_DISTANCE = 10,
            CURRENCY_TYPES = {"Coins", "Gems"},
            DEFAULT_CURRENCY = "Coins"
        },
        GameManager = nil,
        LazyLoadModules = {
            register = function() return true end,
            require = function() return nil end
        },
        Init = function() return true end
    }
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

-- Add a function to notify players about interaction system status
local function notifyPlayer(message, isError)
    if not Players or not Players.LocalPlayer or not Players.LocalPlayer:FindFirstChild("PlayerGui") then
        warn("[InteractionSystem] Cannot show notification:", message)
        return
    end
    
    local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
    local notifGui = playerGui:FindFirstChild("SystemNotifications")
    
    if not notifGui then
        notifGui = Instance.new("ScreenGui")
        notifGui.Name = "SystemNotifications"
        notifGui.ResetOnSpawn = false
        notifGui.Parent = playerGui
    end
    
    local notification = Instance.new("Frame")
    notification.Name = "Notification"
    notification.Size = UDim2.new(0, 300, 0, 60)
    notification.Position = UDim2.new(0.5, -150, 0.1, 0)
    notification.BackgroundColor3 = isError and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(50, 150, 50)
    notification.BackgroundTransparency = 0.2
    notification.Parent = notifGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = notification
    
    local text = Instance.new("TextLabel")
    text.Name = "Message"
    text.Size = UDim2.new(1, -20, 1, -20)
    text.Position = UDim2.new(0, 10, 0, 10)
    text.BackgroundTransparency = 1
    text.TextColor3 = Color3.new(1, 1, 1)
    text.TextSize = 14
    text.Font = Enum.Font.GothamBold
    text.TextWrapped = true
    text.Text = message
    text.Parent = notification
    
    -- Animate and remove after delay
    spawn(function()
        for i = 0, 10 do
            notification.BackgroundTransparency = 0.2 + (i * 0.08)
            text.TextTransparency = i * 0.1
            wait(0.3)
        end
        notification:Destroy()
    end)
end

-- Get the interaction folder directly from script.Parent (the LocalScript)
local localScriptInstance = script.Parent -- This should be the 'client' LocalScript
local interactionFolder = nil

if localScriptInstance then
    print("[InteractionSystem] Looking for interaction folder in: " .. localScriptInstance:GetFullName())
    interactionFolder = localScriptInstance:WaitForChild("interaction", 10)
    
    if interactionFolder then
        print("[InteractionSystem] Found interaction folder: " .. interactionFolder:GetFullName())
          -- Try loading the main interaction module first, then fallbacks if needed
        local moduleScripts = {
            {name = "ItemInteractionClient", isEmergency = false}, -- Use our new interaction client
            {name = "InteractionSystemModule", isEmergency = false}, -- Fallback to original module
            {name = "InteractionSystemModule_enhanced", isEmergency = false}, -- Enhanced as backup
            {name = "InteractionSystemModule_emergency", isEmergency = true} -- Last resort
        }
        
        local loadedModule = nil
        local moduleLoaded = false
        
        for _, moduleInfo in ipairs(moduleScripts) do
            local moduleScript = interactionFolder:FindFirstChild(moduleInfo.name)
            if moduleScript then
                print("[InteractionSystem] Trying to load " .. moduleInfo.name)
                local success, result = pcall(require, moduleScript)
                if success then
                    InteractionSystem = result
                    loadedModule = moduleInfo.name
                    moduleLoaded = true
                    print("[InteractionSystem] Successfully loaded " .. moduleInfo.name)
                    
                    if moduleInfo.isEmergency then
                        notifyPlayer("Emergency interaction system activated.", false)
                    end
                    
                    break
                else
                    warn("[InteractionSystem] Failed to require " .. moduleInfo.name .. ": " .. tostring(result))
                end
            end
        end
        
        if not moduleLoaded then
            warn("[InteractionSystem] CRITICAL: All module loading attempts failed")
            notifyPlayer("Interaction system failed to load. Some features may not work.", true)
            
            -- Create a minimal fallback directly in the client code
            InteractionSystem = {
                new = function()
                    return {
                        Initialize = function() 
                            print("[InteractionSystem] Using minimal fallback")
                        end,
                        Update = function() end,
                        ShowInteraction = function() 
                            notifyPlayer("Interaction system is not available", true)
                        end
                    }
                end
            }
        end
    else
        warn("[InteractionSystem] Interaction folder not found in " .. localScriptInstance:GetFullName())
        notifyPlayer("Interaction system components missing", true)
    end
else
    warn("[InteractionSystem] LocalScript instance (script.Parent) is nil")
    notifyPlayer("Critical client error: LocalScript reference missing", true)
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
    
    -- Handle different response formats for better compatibility
    if type(resultOrError) == "table" then
        -- The server returned a properly formatted response table
        if resultOrError.success ~= nil then
            -- Standard format with success field
            if not resultOrError.success then
                lastError = resultOrError.message or "Unknown error."
                return { success = false, message = lastError }
            end
            return resultOrError
        else
            -- Server returned a table but without explicit success field
            -- Treat it as a successful response
            lastError = nil
            return { 
                success = true, 
                message = "Data received", 
                inventory = resultOrError.inventory or {}, 
                currency = resultOrError.currency or 0
            }
        end
    elseif resultOrError == nil then
        -- Handle nil response
        lastError = "No data received from server."
        return { success = false, message = lastError }
    else
        -- Handle other response types
        lastError = "Unexpected response format."
        warn("Unexpected result format in client_core.luau:", type(resultOrError))
        return { success = false, message = lastError }
    end
    
    lastError = nil
    return { success = true, message = "Success", data = resultOrError }
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
        
        -- Improved error handling for inventory retrieval
        local success, response = pcall(function()
            return GetInventoryFunc:InvokeServer()
        end)
        
        if not success then
            warn("GetInventory invocation failed with error:", response)
            return
        end
        
        -- Process the response, being tolerant of different formats
        if response == nil then
            warn("GetInventory returned nil")
            return
        end
        
        local inventoryData = {}
        local currencyAmount = 0
        
        if type(response) == "table" then
            -- Extract inventory and currency regardless of exact structure
            if response.inventory then
                inventoryData = response.inventory
            end
            
            if response.currency then
                currencyAmount = response.currency
            end
            
            -- Update local cache
            currentInventory = inventoryData
            currentCurrency = currencyAmount
            
            -- Try to update UI if the module is available
            if InventoryUIModule and InventoryUIModule.UpdateInventory and InventoryUIModule.Show then
                InventoryUIModule.UpdateInventory(inventoryData, currencyAmount)
                InventoryUIModule.Show()
            else
                print("InventoryUIModule not available, but data was retrieved successfully")
                print("Retrieved " .. #inventoryData .. " inventory items and " .. currencyAmount .. " currency")
            end
        else
            warn("Unexpected response format from GetInventory:", type(response))
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
    -- Use a more robust approach to find the PlacedItemDialog module
    local shared = ReplicatedStorage:FindFirstChild("shared")
    if not shared then
        error("shared folder not found")
    end
    
    -- First try using the core path (with a timeout)
    local core = shared:FindFirstChild("core")
    if core then
        local ui = core:FindFirstChild("ui")
        if ui then
            local placedItemDialog = ui:FindFirstChild("PlacedItemDialog")
            if placedItemDialog then
                return require(placedItemDialog)
            end
        end
    end
    
    -- If that fails, try looking for PlacedItemDialog directly in multiple locations
    -- Try in shared folder first
    local directModule = shared:FindFirstChild("PlacedItemDialog")
    if directModule then
        return require(directModule)
    end
    
    -- Try in client's interaction folder
    local interaction = script.Parent:FindFirstChild("interaction")
    if interaction then
        local dialogModule = interaction:FindFirstChild("PlacedItemDialog") or interaction:FindFirstChild("WorldItemUI")
        if dialogModule then
            return require(dialogModule)
        end
    end
    
    error("Could not find PlacedItemDialog module in any expected location")
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
local clientModule = {
    GetGameManager = function() return GameManager end,
    ShowInventory = function()
        -- Check if InventoryUI is available in SharedModule
        if SharedModule and SharedModule.InventoryUI and SharedModule.InventoryUI.Toggle then
            print("Using SharedModule.InventoryUI.Toggle")
            SharedModule.InventoryUI.Toggle()
        -- Fall back to the old module reference if it exists
        elseif InventoryUIModule and InventoryUIModule.Show then
            print("Using InventoryUIModule.Show")
            InventoryUIModule.Show()
        else
            -- Try to fetch inventory data even if UI module is missing
            if GetInventoryFunc then
                local success, result = pcall(function()
                    return GetInventoryFunc:InvokeServer()
                end)
                
                if success and result then
                    print("InventoryUIModule not available, but data was retrieved successfully")
                    print("Retrieved " .. (result.inventory and #result.inventory or 0) .. " inventory items and " .. (result.currency or 0) .. " currency")
                else
                    warn("InventoryUIModule not ready and failed to get inventory data:", result)
                end
            else
                warn("InventoryUIModule not ready or Show method missing for ShowInventory API call in client_core.luau.")
            end
        end
    end
}

-- Function to reload the interaction system
function clientModule.reloadInteractionSystem()
    print("Reloading interaction system...")
    
    -- Clean up existing interaction system if needed
    if InteractionSystem and typeof(InteractionSystem) == "table" and InteractionSystem.cleanup then
        print("Cleaning up existing interaction system...")
        InteractionSystem.cleanup()
    end
    
    -- Reset the InteractionSystem variable
    InteractionSystem = nil
    
    -- Re-attempt to load an interaction module
    local interactionFolder = script.Parent:FindFirstChild("interaction")
    if interactionFolder then
        -- Try loading modules in order of preference
        local moduleScripts = {
            {name = "ItemInteractionClient", isEmergency = false},
            {name = "InteractionSystemModule", isEmergency = false},
            {name = "InteractionSystemModule_enhanced", isEmergency = false},
            {name = "InteractionSystemModule_emergency", isEmergency = true}
        }
        
        local moduleLoaded = false
        
        for _, moduleInfo in ipairs(moduleScripts) do
            local moduleScript = interactionFolder:FindFirstChild(moduleInfo.name)
            if moduleScript then
                print("[InteractionSystem] Trying to load " .. moduleInfo.name)
                local success, result = pcall(require, moduleScript)
                if success then
                    InteractionSystem = result
                    print("[InteractionSystem] Successfully loaded " .. moduleInfo.name)
                    moduleLoaded = true
                    break
                else
                    warn("[InteractionSystem] Failed to require " .. moduleInfo.name .. ": " .. tostring(result))
                end
            end
        end
        
        if not moduleLoaded then
            warn("[InteractionSystem] Failed to load any interaction module")
        end
    else
        warn("[InteractionSystem] Interaction folder not found")
    end
    
    return InteractionSystem ~= nil
end

return clientModule
