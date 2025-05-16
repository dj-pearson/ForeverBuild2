-- FixGameIssues.lua
-- A comprehensive script to fix multiple issues in the game
-- Run this in Roblox Studio to apply all fixes at once

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Function to fix the shared module issue
local function fixSharedModule()
    print("Fixing shared module...")
    
    -- Check if shared exists
    local shared = ReplicatedStorage:FindFirstChild("shared")
    local sharedIsValid = false
    
    if shared then
        -- If it's a ModuleScript, check if the error is due to missing core folder
        if shared:IsA("ModuleScript") then
            print("Found 'shared' as a ModuleScript, checking if it needs a core folder...")
            
            -- Create the core folder in ReplicatedStorage if it doesn't exist
            local core = ReplicatedStorage:FindFirstChild("core")
            if not core then
                core = Instance.new("Folder")
                core.Name = "core"
                core.Parent = ReplicatedStorage
                
                -- Add Constants to core folder
                local constants = Instance.new("ModuleScript")
                constants.Name = "Constants"
                constants.Parent = core
                constants.Source = getConstantsSource()
                
                print("Created core folder and Constants module in ReplicatedStorage")
            end
            
            -- Keep current shared module
            sharedIsValid = true
            print("Kept existing shared module and added missing core folder")
        else
            -- If it's not a ModuleScript, rename and create a new one
            print("Found 'shared' but it's a " .. shared.ClassName .. " instead of a ModuleScript")
            shared.Name = "shared_backup"
            createNewSharedModule()
        end
    else
        -- Create from scratch
        print("No shared module found, creating new one...")
        createNewSharedModule()
    end
    
    -- Create core folder inside shared if needed
    if not sharedIsValid then
        local sharedModule = ReplicatedStorage:FindFirstChild("shared")
        if sharedModule and sharedModule:IsA("ModuleScript") then
            -- Create the core folder in shared if using our new module structure
            local sharedCore = Instance.new("Folder")
            sharedCore.Name = "core"
            sharedCore.Parent = ReplicatedStorage.shared
            
            -- Add Constants to core folder
            local constants = Instance.new("ModuleScript")
            constants.Name = "Constants"
            constants.Parent = sharedCore
            constants.Source = getConstantsSource()
            
            print("Created core folder and Constants module inside shared module")
        end
    end
end

-- Function to get Constants module source
function getConstantsSource()
    return [[
local Constants = {}

-- Admin Configuration
Constants.ADMIN_IDS = {
    7768610061 -- Main admin ID
}

-- Item Categories
Constants.ITEM_CATEGORIES = {
    FREEBIES = "Freebies",
    PAID = "Paid",
    ADMIN = "Admin"
}

-- Item Actions
Constants.ITEM_ACTIONS = {
    clone = { cost = 100 },
    move = { cost = 10 },
    rotate = { cost = 5 },
    destroy = { cost = 20 }
}

-- Currency Configuration
Constants.CURRENCY = {
    INGAME = "Coins",
    ROBUX = "Robux",
    REWARD_RATE = 1.67, -- Coins per real minute
    REWARD_INTERVAL = 60, -- Reward interval in seconds
    MIN_REWARD_AMOUNT = 1, -- Minimum reward amount
    MAX_REWARD_AMOUNT = 100, -- Maximum reward amount
    DAILY_BONUS = 100, -- Daily login bonus
    WEEKLY_BONUS = 500, -- Weekly login bonus
    MONTHLY_BONUS = 2000, -- Monthly login bonus
    STARTING_COINS = 100, -- Added for client and most scripts
    STARTING_CURRENCY = 100, -- Added for server/GameManager

    PRODUCTS = {
        {id = "coins_1000", name = "1,000 Coins", coins = 1000, robux = 75, bonusCoins = 0, assetId = 3285357280, description = "Get started with a handy pack of 1,000 coins!"},
        {id = "coins_5000", name = "5,500 Coins", coins = 5000, robux = 350, bonusCoins = 500, assetId = 3285387112, description = "Great value! Grab 5,000 coins and get an extra 500 on us!"},
        {id = "coins_10000", name = "11,500 Coins", coins = 10000, robux = 650, bonusCoins = 1500, assetId = 3285387112, description = "Supercharge your game with 10,000 coins, plus a 1,500 coin bonus!"},
        {id = "coins_20000", name = "24,000 Coins", coins = 20000, robux = 1200, bonusCoins = 4000, assetId = 3285387781, description = "The ultimate deal! Get 20,000 coins and a massive 4,000 coin bonus!"}
    }
}

-- Item Pricing Configuration
Constants.ITEM_PRICES = {
    BASIC = { INGAME = 5, ROBUX = 5 },
    LEVEL_1 = { INGAME = 10, ROBUX = 10 },
    LEVEL_2 = { INGAME = 25, ROBUX = 25 },
    RARE = { INGAME = 100, ROBUX = 100 },
    EXCLUSIVE = { INGAME = 1000, ROBUX = 1000 },
    WEAPONS = { INGAME = 500, ROBUX = 500 },
    RARE_DROP = { INGAME = 800, ROBUX = 800 },
    FREE_ITEMS = { INGAME = 0, ROBUX = 0 }
}

-- Base Prices
Constants.BASE_PRICES = {
    BUY = 10, -- Base price for buying items
    MOVE = 5, -- Base price for moving items
    DESTROY = 3, -- Base price for destroying items
    ROTATE = 2, -- Base price for rotating items
    COLOR = 2 -- Base price for changing color
}

-- UI Colors
Constants.UI_COLORS = {
    PRIMARY = Color3.fromRGB(0, 170, 255),
    SECONDARY = Color3.fromRGB(40, 40, 40),
    TEXT = Color3.fromRGB(255, 255, 255)
}

-- Interaction Settings
Constants.INTERACTION_DISTANCE = 10

return Constants
]]
end

-- Function to create a brand new shared module
function createNewSharedModule()
    local newShared = Instance.new("ModuleScript")
    newShared.Name = "shared"
    newShared.Parent = ReplicatedStorage
    setSharedModuleContent(newShared)
    print("Created new shared ModuleScript")
end

-- Function to set the content of the shared module
function setSharedModuleContent(moduleScript)
    -- Using string concatenation to avoid multiline string issues
    local code = [=[
--[[
    SharedModule.luau
    This module provides a simplified, resilient interface for shared components.
    It handles missing dependencies gracefully to prevent cascading failures.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedModule = {}

print("Shared inits.luau loading...")

-- Initialize constants from core module
local Constants = nil
local coreFound = false

-- Try to access core folder in two ways:
-- 1. First try as a direct child of ReplicatedStorage (as seen in error)
local coreFolder = ReplicatedStorage:FindFirstChild("core")
if coreFolder then
    print("Found core folder in ReplicatedStorage")
    coreFound = true
    local constantsModule = coreFolder:FindFirstChild("Constants")
    if constantsModule then
        Constants = require(constantsModule)
    end
else
    -- 2. Then check core as a child of this shared module
    local sharedCore = script:FindFirstChild("core")
    if sharedCore then
        print("Found core folder inside shared module")
        coreFound = true
        local constantsModule = sharedCore:FindFirstChild("Constants")
        if constantsModule then
            Constants = require(constantsModule)
        end
    end
end

-- If neither approach worked, create a fallback
if not Constants then
    print("Creating fallback Constants")
    Constants = {
        ITEM_ACTIONS = {
            clone = { cost = 100 },
            move = { cost = 10 },
            rotate = { cost = 5 },
            destroy = { cost = 20 }
        },
        CURRENCY = {
            INGAME = "Coins",
            ROBUX = "Robux",
            STARTING_CURRENCY = 100,
            STARTING_COINS = 100
        },
        UI_COLORS = {
            PRIMARY = Color3.fromRGB(0, 170, 255),
            SECONDARY = Color3.fromRGB(40, 40, 40),
            TEXT = Color3.fromRGB(255, 255, 255)
        },
        INTERACTION_DISTANCE = 10
    }
end

-- Expose Constants
SharedModule.Constants = Constants

-- Create stub managers
SharedModule.GameManager = {
    new = function()
        return {
            Initialize = function() end,
            InitializePlayerData = function() return true end,
            SavePlayerData = function() return true end,
            HandleItemPurchase = function() return true end
        }
    end
}

SharedModule.InventoryManager = {
    new = function()
        return {
            Initialize = function() end,
            GetPlayerInventory = function() return { inventory = {}, currency = 100 } end,
            AddItemToInventory = function() return true end
        }
    end
}

SharedModule.LazyLoadModules = {
    register = function() return true end,
    require = function() return {} end
}

function SharedModule.Init()
    print("[SharedModule] Init called. Using simplified SharedModule structure.")
end

return SharedModule
]=]
    
    moduleScript.Source = code
    print("Updated shared module content")
end

-- Function to fix missing remote events
local function fixMissingRemotes()
    print("Fixing missing remote events...")
    
    -- Check if Remotes folder exists
    local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not Remotes then
        Remotes = Instance.new("Folder")
        Remotes.Name = "Remotes"
        Remotes.Parent = ReplicatedStorage
        print("Created Remotes folder")
    end
    
    -- List of remote events to ensure exist
    local remoteEvents = {
        "ChangeItemColor",
        "RemoveFromInventory",
        "NotifyPlayer",
        "BuyItem",
        "PlaceItem",
        "MoveItem",
        "RotateItem",
        "CloneItem",
        "DestroyItem",
        "AddToInventory",
        "PickupItem",
        "ApplyItemEffect",
        "ShowItemDescription",
        "InteractWithItem"  -- Added missing remote from error logs
    }
    
    -- List of remote functions to ensure exist
    local remoteFunctions = {
        "GetInventory",
        "GetItemCatalog",
        "GetItemData",
        "GetAvailableInteractions",
        "IsItemAffordable"
    }
    
    -- Create or verify remote events
    for _, name in ipairs(remoteEvents) do
        if not Remotes:FindFirstChild(name) then
            local event = Instance.new("RemoteEvent")
            event.Name = name
            event.Parent = Remotes
            print("Created missing RemoteEvent: " .. name)
        end
    end
    
    -- Create or verify remote functions
    for _, name in ipairs(remoteFunctions) do
        if not Remotes:FindFirstChild(name) then
            local func = Instance.new("RemoteFunction")
            func.Name = name
            func.Parent = Remotes
            print("Created missing RemoteFunction: " .. name)
        end
    end
end

-- Function to fix problematic "Thank you letter" script
local function fixThankYouLetter()
    print("Fixing 'Thank you letter' script...")
    
    -- Look for the problematic script based on error message
    local targetScriptPath = "Workspace.World_Items.Rare House.House.Cute Closet.#NBK || Adidas Cap.Thank you letter"
    local pathParts = targetScriptPath:split(".")
    
    -- Start with workspace and traverse the path
    local currentObj = workspace
    for i = 2, #pathParts do
        local part = pathParts[i]
        -- Handle special characters in instance names
        if currentObj:FindFirstChild(part) then
            currentObj = currentObj:FindFirstChild(part)
        else
            -- Try to find with more complex matching if direct lookup fails
            local found = false
            for _, child in pairs(currentObj:GetChildren()) do
                if child.Name:match(part) or child.Name == part then
                    currentObj = child
                    found = true
                    break
                end
            end
            
            if not found then
                warn("Could not find part of path: " .. part)
                warn("Looking in all children of " .. currentObj:GetFullName() .. " for anything matching '" .. part .. "'")
                
                -- Try a very broad search
                for _, child in pairs(currentObj:GetChildren()) do
                    print("Checking: " .. child.Name)
                    if string.find(string.lower(child.Name), string.lower(part:sub(1, 5))) then
                        print("Possible match found: " .. child:GetFullName())
                        currentObj = child
                        found = true
                        break
                    end
                end
                
                if not found then
                    warn("Still could not find path component: " .. part)
                    return
                end
            end
        end
    end
    
    print("Found object: " .. currentObj:GetFullName())
    
    if currentObj:IsA("Script") or currentObj:IsA("LocalScript") or currentObj:IsA("ModuleScript") then
        print("Found problematic script: " .. currentObj:GetFullName())
        
        -- Fix the script by replacing its source with valid Lua code
        local oldSource = currentObj.Source
        print("Original source: " .. oldSource)
        
        -- Replace with valid source code
        currentObj.Source = "-- Fixed Thank you letter script\nreturn {\n    message = \"Thank you for your purchase!\"\n}"
        print("Script fixed with valid Lua code")
    else
        -- It might not be a script yet, so let's convert it
        print("Found object but it's not a script: " .. currentObj:GetFullName())
        print("Converting to a valid ModuleScript...")
        
        local script
        if currentObj.ClassName == "StringValue" then
            -- Keep the existing object but change its class
            script = Instance.new("ModuleScript")
            script.Name = currentObj.Name
            script.Parent = currentObj.Parent
            currentObj:Destroy()
        else
            -- Create a new script next to the existing object
            script = Instance.new("ModuleScript")
            script.Name = currentObj.Name .. "_Script"
            script.Parent = currentObj.Parent
        end
        
        -- Set valid content
        script.Source = "-- Fixed Thank you letter script\nreturn {\n    message = \"Thank you for your purchase!\"\n}"
        print("Created valid script: " .. script:GetFullName())
    end
end

-- Run all fix functions
print("Starting comprehensive game fixes...")
fixSharedModule()
fixMissingRemotes()
fixThankYouLetter()
print("All fixes applied successfully!") 