-- InventoryItemHandler.client.luau
-- Handles recalling items from inventory and connecting with the placement system

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- Wait for shared module
local shared = ReplicatedStorage:WaitForChild("shared", 10)

-- TEST FLAG: Set to true to use the new modular PlacementCore system
local USE_NEW_PLACEMENT_CORE = false

print("InventoryItemHandler: Starting initialization")

-- Load required modules
local function initialize()
    local success, sharedModule = pcall(function()
        return require(shared)
    end)
    
    if not success then
        warn("InventoryItemHandler: Failed to load SharedModule:", sharedModule)
        return false
    end
    
    print("InventoryItemHandler: SharedModule loaded")
    
    -- Wait for InventoryUI to be available
    if not sharedModule.InventoryUI then
        print("InventoryItemHandler: Waiting for InventoryUI to be available")
        for i = 1, 10 do
            if sharedModule.InventoryUI then break end
            task.wait(0.5)
        end
    end
    
    if not sharedModule.InventoryUI then
        warn("InventoryItemHandler: InventoryUI not found in SharedModule after waiting")
        return false
    end
    
    print("InventoryItemHandler: InventoryUI module found")
    
    -- Choose which placement system to use
    local PlacementManagerModule
    if USE_NEW_PLACEMENT_CORE and sharedModule.PlacementCore then
        print("InventoryItemHandler: Using NEW PlacementCore system")
        PlacementManagerModule = sharedModule.PlacementCore
    elseif sharedModule.PlacementManager then
        print("InventoryItemHandler: Using LEGACY PlacementManager system")
        PlacementManagerModule = sharedModule.PlacementManager
    else
        warn("InventoryItemHandler: No placement system available!")
        return false
    end
    
    if PlacementManagerModule and type(PlacementManagerModule) == "table" and PlacementManagerModule.new then
        print("InventoryItemHandler: PlacementManager module found in SharedModule. Creating new client instance.")
        -- Create a new instance for this handler
        local pmInstance = PlacementManagerModule.new(sharedModule)
        
        -- It's crucial that the client calls CacheRemoteEvents on its instance
        -- SetupRemoteEvents is server-side, CacheRemoteEvents is for client
        if pmInstance.CacheRemoteEvents then 
            pmInstance:CacheRemoteEvents() 
            print("InventoryItemHandler: Called CacheRemoteEvents on new PlacementManager instance.")
        else
            warn("InventoryItemHandler: Newly created PlacementManager instance does NOT have CacheRemoteEvents method!")
        end

        -- Store this specific instance for use within InventoryItemHandler
        sharedModule.PlacementManagerClientInstance = pmInstance
        
        print("InventoryItemHandler: PlacementManager initialization logic executed.")
        
        -- Hook InventoryUI methods for debugging
        if sharedModule.InventoryUI and sharedModule.InventoryUI.OnItemSelected then
            local originalOnItemSelected = sharedModule.InventoryUI.OnItemSelected
            sharedModule.InventoryUI.OnItemSelected = function(...)
                print("InventoryItemHandler: InventoryUI.OnItemSelected called with args:")
                for i, arg in ipairs({...}) do
                    print("  Arg " .. i .. ":", tostring(arg))
                end
                if originalOnItemSelected then
                    return originalOnItemSelected(...)
                end
            end
            print("InventoryItemHandler: Hooked InventoryUI methods for debugging")
        end
        
        -- Set up item template creation
        checkItemTemplates()
        
        -- Set up inventory item interaction
        local setupSuccess = setupInventoryItemInteraction(sharedModule)
        if setupSuccess then
            print("InventoryItemHandler: Successfully initialized")
            
            -- Create inventory button backup connection
            task.wait(1) -- Wait a moment for UI to be ready
            
            -- Find inventory button and add additional backup connection
            local playerGui = player:WaitForChild("PlayerGui", 5)
            if playerGui then
                local inventoryGui = playerGui:FindFirstChild("InventoryScreenGui")
                if inventoryGui then
                    local button = inventoryGui:FindFirstChild("InventoryButton")
                    if button then
                        print("InventoryItemHandler: Found inventory button, adding additional backup connection")
                        button.MouseButton1Click:Connect(function()
                            print("InventoryItemHandler: Backup inventory button click detected")
                            if sharedModule.InventoryUI and sharedModule.InventoryUI.Toggle then
                                sharedModule.InventoryUI.Toggle()
                            end
                        end)
                    end
                end
            end
            
            return true
        else
            warn("InventoryItemHandler: Failed to set up inventory item interaction")
            return false
        end
    else
        warn("InventoryItemHandler: PlacementManager module not found or invalid in SharedModule")
        return false
    end
end

-- Function to fix player movement in case they get stuck
local function fixPlayerMovement(character)
    if not character then return end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.PlatformStand = false
        humanoid.Sit = false
    end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if humanoidRootPart then
        -- Remove any BodyPosition or BodyVelocity objects that might be affecting movement
        for _, child in pairs(humanoidRootPart:GetChildren()) do
            if child:IsA("BodyPosition") or child:IsA("BodyVelocity") or child:IsA("BodyAngularVelocity") then
                child:Destroy()
            end
        end
    end
end

-- Set up inventory item interaction
local function setupInventoryItemInteraction(sharedModule)
    local InventoryUI = sharedModule.InventoryUI
    local PlacementManager = sharedModule.PlacementManagerClientInstance
    
    -- Set up the OnItemSelected callback in InventoryUI
    InventoryUI.OnItemSelected = function(itemName, itemData)
        print("InventoryItemHandler: Item selected from inventory:", itemName)
        
        -- First ensure player can move if they got stuck
        fixPlayerMovement(player.Character)
        
        -- Get item count if available
        local itemCount = itemData and itemData.count or 1
        print("InventoryItemHandler: Item count:", itemCount)
        
        -- Normalize the item name (replace spaces with underscores)
        local normalizedItemName = itemName:gsub(" ", "_")
        
        -- Show item in hand using the placement manager
        if PlacementManager and PlacementManager.ShowItemInHand then
            PlacementManager:ShowItemInHand(normalizedItemName)
        else
            warn("InventoryItemHandler: PlacementManager.ShowItemInHand not available")
        end
    end
    
    print("InventoryItemHandler: Set up inventory item interaction with PlacementManager")
    return true
end

-- ItemTemplates are now managed centrally to prevent redundancy
local function checkItemTemplates()
    local templates = ReplicatedStorage:FindFirstChild("ItemTemplates")
    if templates then
        print("InventoryItemHandler: ItemTemplates folder exists with " .. #templates:GetChildren() .. " items")
    else
        print("InventoryItemHandler: ItemTemplates folder not found - will be created by server or fix_template_system.luau")
    end
end

-- Run initialization
local initSuccess = initialize()
if initSuccess then
    print("InventoryItemHandler: Initialization completed successfully")
else
    warn("InventoryItemHandler: Initialization failed")
end 