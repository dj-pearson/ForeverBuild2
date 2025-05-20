--[[
    init.luau for shared folder
    This is a bridge module that attempts to load the main shared module logic
    from 'inits.luau' (or 'inits' if it's a direct ModuleScript instance).
]]

local script = script
local parent = script.Parent

local loadedModule = nil
local loadedModuleName = ""

print("[Bridge Init] Attempting to load main SharedModule logic...")

-- Attempt 1: Try requiring parent.inits (if 'inits.luau' is treated as a ModuleScript named 'inits')
local success1, result1 = pcall(function()
    if script:FindFirstChild("inits") and script.inits:IsA("ModuleScript") then
        loadedModuleName = "inits (ModuleScript under shared)"
        return require(script.inits)
    end
    return nil
end)

if success1 and typeof(result1) == "table" then
    print("[Bridge Init] Successfully loaded SharedModule via: " .. loadedModuleName)
    return result1
elseif success1 and result1 == nil then
    print("[Bridge Init] 'inits' ModuleScript not found or not a ModuleScript under 'shared'.")
else
    warn("[Bridge Init] Error attempting to load 'inits' ModuleScript from 'shared': " .. tostring(result1))
end

-- Attempt 2: Try requiring parent["inits.luau"]
local success2, result2 = pcall(function()
    if script:FindFirstChild("inits.luau") and script["inits.luau"]:IsA("ModuleScript") then
        loadedModuleName = "inits.luau (File under shared)"
        return require(script["inits.luau"])
    end
    return nil
end)

if success2 and typeof(result2) == "table" then
    print("[Bridge Init] Successfully loaded SharedModule via: " .. loadedModuleName)
    return result2
elseif success2 and result2 == nil then
    print("[Bridge Init] 'inits.luau' file not found or not a ModuleScript under 'shared'.")
else
    warn("[Bridge Init] Error attempting to load 'inits.luau' file from 'shared': " .. tostring(result2))
end

-- Fallback to SharedModule.luau if inits.luau fails
local success3, result3 = pcall(function()
    if script:FindFirstChild("SharedModule.luau") and script["SharedModule.luau"]:IsA("ModuleScript") then
        loadedModuleName = "SharedModule.luau (File under shared)"
        return require(script["SharedModule.luau"])
    end
    return nil
end)

if success3 and typeof(result3) == "table" then
    print("[Bridge Init] Successfully loaded SharedModule via: " .. loadedModuleName .. " (fallback)")
    return result3
elseif success3 and result3 == nil then
    print("[Bridge Init] Fallback 'SharedModule.luau' file not found or not a ModuleScript under 'shared'.")
else
    warn("[Bridge Init] Error attempting to load fallback 'SharedModule.luau' file from 'shared': " .. tostring(result3))
end

print("WARNING: [Bridge Init] FAILED to load main SharedModule logic from 'inits' (ModuleScript), 'inits.luau' (File), or 'SharedModule.luau' (File) from within 'shared'. Creating MINIMAL FALLBACK SharedModule.")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MinimalSharedModule = {}

-- Try to load Constants from core subfolder for the minimal fallback
local Constants = nil
local coreFolder = script:FindFirstChild("core")

if coreFolder and coreFolder:FindFirstChild("Constants") then
    print("Minimal Fallback: Loading Constants from core subfolder")
    local constSuccess, constResult = pcall(function()
        return require(coreFolder:FindFirstChild("Constants"))
    end)
    if constSuccess then
        Constants = constResult
        print("Minimal Fallback: Successfully loaded Constants")
    else
        warn("Minimal Fallback: Failed to load Constants:", constResult)
    end
else
    warn("Minimal Fallback: Core folder or Constants module not found")
end

if Constants then
    MinimalSharedModule.Constants = Constants
    print("Minimal Fallback: Successfully set up Constants in MinimalSharedModule")
else
    warn("MinimalSharedModule: Constants not available. Creating very basic fallback Constants.")
    MinimalSharedModule.Constants = {
        UI = { Colors = { Background = Color3.fromRGB(30,30,30), Text = Color3.fromRGB(255,255,255) } },
        CURRENCY = { STARTING_COINS = 100, STARTING_CURRENCY = 100 },
        INTERACTION_DISTANCE = 10
    }
end

-- Add stub managers and UI modules for the minimal fallback
MinimalSharedModule.GameManager = { new = function() return { Initialize = function() print("Minimal GameManager: Initialize") end } end }
MinimalSharedModule.InventoryManager = { new = function() return { Initialize = function() print("Minimal InventoryManager: Initialize") end, GetPlayerInventory = function() return { inventory = {}, currency = 100 } end } end }
MinimalSharedModule.CurrencyManager = { new = function() return { Initialize = function() print("Minimal CurrencyManager: Initialize") end, GetBalance = function() return 100 end, GetPlayerBalance = function() return 100 end, LoadPlayerBalance = function() return 100 end } end }
MinimalSharedModule.InteractionManager = { new = function() return { Initialize = function() print("Minimal InteractionManager: Initialize") end } end }
MinimalSharedModule.LazyLoadModules = { register = function(name) print("Minimal LazyLoad: Register " .. name) end, require = function(name) print("Minimal LazyLoad: Require " .. name); return {} end }
MinimalSharedModule.PurchaseDialog = { Initialize = function() print("Minimal Stub Init: PurchaseDialog") end, Show = function() print("Minimal Stub Show: PurchaseDialog") end, Hide = function() print("Minimal Stub Hide: PurchaseDialog") end }
MinimalSharedModule.InventoryUI = { Initialize = function() print("Minimal Stub Init: InventoryUI") end, Show = function() print("Minimal Stub Show: InventoryUI") end, Hide = function() print("Minimal Stub Hide: InventoryUI") end, UpdateInventory = function() print("Minimal Stub UpdateInventory: InventoryUI") end }
MinimalSharedModule.PlacedItemDialog = { Initialize = function() print("Minimal Stub Init: PlacedItemDialog") end, Show = function() print("Minimal Stub Show: PlacedItemDialog") end, Hide = function() print("Minimal Stub Hide: PlacedItemDialog") end }
MinimalSharedModule.CurrencyUI = { Initialize = function() print("Minimal Stub Init: CurrencyUI") end, UpdateBalance = function() print("Minimal Stub UpdateBalance: CurrencyUI") end }

function MinimalSharedModule.Init()
    print("[MinimalSharedModule] Init called. Using MINIMAL FALLBACK structure.")
    return true
end

return MinimalSharedModule 