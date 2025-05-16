--[[
    init.luau for shared folder
    This is a bridge module that loads the existing inits.luau to maintain compatibility
    while fixing the "Module code did not return exactly one value" error
]]

-- This script loads the existing inits.luau module and returns it
local script = script
local parent = script.Parent

-- Try multiple approaches to find inits.luau
local initsModule = nil

-- First check direct child
if parent:FindFirstChild("inits") then
    initsModule = parent:FindFirstChild("inits")
end

-- Alternative paths based on naming conventions
if not initsModule and parent:FindFirstChild("inits.luau") then
    initsModule = parent:FindFirstChild("inits.luau")
end

if not initsModule and parent:FindFirstChild("inits.lua") then
    initsModule = parent:FindFirstChild("inits.lua")
end

-- If we found inits, use it
if initsModule then
    print("Found inits module at " .. initsModule:GetFullName() .. ", delegating to it")
    return require(initsModule)
else
    -- If inits.luau doesn't exist, create a minimal version
    print("WARNING: inits.luau not found, creating minimal SharedModule")
    
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local SharedModule = {}
    
    -- Try to load Constants from core subfolder
    local Constants = nil
    local coreFolder = parent:FindFirstChild("core")
    
    if coreFolder and coreFolder:FindFirstChild("Constants") then
        print("Loading Constants from core subfolder")
        local success, result = pcall(function()
            local constantsModule = coreFolder:FindFirstChild("Constants")
            if constantsModule then
                return require(constantsModule)
            else
                error("Constants module not found in core folder")
            end
        end)
        if success then
            Constants = result
        else
            warn("Failed to load Constants:", result)
        end
    end
    
    -- Set up Constants
    if Constants then
        SharedModule.Constants = Constants
    else
        print("Using fallback Constants")
        -- Fallback constants
        SharedModule.Constants = {
            ITEM_ACTIONS = {
                clone = { cost = 100 },
                move = { cost = 10 },
                rotate = { cost = 5 },
                destroy = { cost = 20 }
            },
            CURRENCY = {
                INGAME = "Coins",
                ROBUX = "Robux",
                REWARD_RATE = 1.67,
                REWARD_INTERVAL = 60,
                STARTING_CURRENCY = 100,
                STARTING_COINS = 100
            },
            UI_COLORS = {
                PRIMARY = Color3.fromRGB(0, 170, 255),
                SECONDARY = Color3.fromRGB(40, 40, 40),
                TEXT = Color3.fromRGB(255, 255, 255)
            },
            INTERACTION_DISTANCE = 10,
            -- Add missing item types structure
            ITEMS = {
                -- These are dummy items to avoid the nil indexing errors
                Brick_Cube = { name = "Brick Cube", price = 10 },
                Wood_Plank = { name = "Wood Plank", price = 5 },
                Stone_Block = { name = "Stone Block", price = 15 }
            }
        }
    end
    
    -- Add stub managers
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
        print("[SharedModule] Init called. Using minimal fallback SharedModule structure.")
        return true
    end
    
    return SharedModule
end 