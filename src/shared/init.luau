--[[
    init.luau for shared folder
    This is a bridge module that loads the existing init.luau to maintain compatibility
    while fixing the "Module code did not return exactly one value" error
]]

-- This script loads the existing init.luau module and returns it
local script = script
local parent = script.Parent

-- Try multiple approaches to find init.luau
local initModule = nil

-- First check direct child
if parent:FindFirstChild("init") then
    initModule = parent:FindFirstChild("init")
end

-- Alternative paths based on naming conventions
if not initModule and parent:FindFirstChild("init.luau") then
    initModule = parent:FindFirstChild("init.luau")
end

if not initModule and parent:FindFirstChild("init.lua") then
    initModule = parent:FindFirstChild("init.lua")
end

-- If we found init, use it
if initModule then
    print("Found init module at " .. initModule:GetFullName() .. ", delegating to it")
    return require(initModule)
else
    -- If init.luau doesn't exist, create a minimal version
    print("WARNING: init.luau not found, creating minimal SharedModule")
    
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
            ITEM_PRICES = {
                BASIC = {
                    INGAME = 5,
                    ROBUX = 5
                },
                LEVEL_1 = {
                    INGAME = 10,
                    ROBUX = 10
                },
                LEVEL_2 = {
                    INGAME = 25,
                    ROBUX = 25
                },
                RARE = {
                    INGAME = 100,
                    ROBUX = 100
                },
                FREE_ITEMS = {
                    INGAME = 0,
                    ROBUX = 0
                }
            },
            TIER_PRODUCTS = {
                BASIC = {id = "tier_basic", assetId = 1472807192, robux = 5},
                LEVEL_1 = {id = "tier_level1", assetId = 1472807192, robux = 10},
                LEVEL_2 = {id = "tier_level2", assetId = 1472807192, robux = 25}
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
                Brick_Cube = { 
                    name = "Brick Cube", 
                    description = "A basic brick cube building block.",
                    tier = "BASIC",
                    price = {INGAME = 5, ROBUX = 5}
                },
                Wood_Cube = { 
                    name = "Wood Cube", 
                    description = "A basic wood cube building block.",
                    tier = "BASIC",
                    price = {INGAME = 5, ROBUX = 5}
                },
                Stone_Cube = { 
                    name = "Stone Block", 
                    description = "A basic stone cube building block.",
                    tier = "BASIC",
                    price = {INGAME = 5, ROBUX = 5}
                }
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