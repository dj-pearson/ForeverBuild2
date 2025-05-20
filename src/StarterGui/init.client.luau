--[[
    StarterGui Module - ForeverBuild2
    
    This is the main initialization script for the StarterGui.
    It handles loading and setting up all UI components.
]]

-- Add debug print to confirm script is running
print("StarterGui script starting...")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Get shared module with error handling
print("StarterGui.init: Attempting to require shared module")
local SharedModule
local success, errorMessage = pcall(function()
    local shared = ReplicatedStorage:WaitForChild("shared", 10)
    print("StarterGui.init: Found shared module at " .. shared:GetFullName())
    SharedModule = require(shared)
    return true
end)

if not success then
    warn("StarterGui.init: Failed to require SharedModule:", errorMessage)
    SharedModule = {}
    print("StarterGui will not function properly without SharedModule")
    return
else
    print("StarterGui.init: Successfully required SharedModule")
    
    -- Initialize the shared module
    if SharedModule.Init then
        local initSuccess, initError = pcall(function()
            SharedModule.Init()
        end)
        
        if not initSuccess then
            warn("StarterGui.init: Failed to initialize SharedModule:", initError)
        else
            print("StarterGui.init: SharedModule initialized successfully")
        end
    end
end

-- Local references to commonly used modules with error handling
local Constants = SharedModule.Constants
local GameManagerModule = SharedModule.GameManager
local CurrencyManagerModule = SharedModule.CurrencyManager

-- Create manager instances with error handling
local gameManager, currencyManager

if GameManagerModule and GameManagerModule.new then
    local gmSuccess, gmResult = pcall(function()
        return GameManagerModule.new()
    end)
    
    if gmSuccess then
        gameManager = gmResult
        print("Successfully created GameManager instance")
    else
        warn("Failed to create GameManager instance:", gmResult)
        gameManager = {}
    end
else
    warn("GameManagerModule or GameManagerModule.new is not available")
    gameManager = {}
end

if CurrencyManagerModule and CurrencyManagerModule.new then
    local cmSuccess, cmResult = pcall(function()
        return CurrencyManagerModule.new()
    end)
    
    if cmSuccess then
        currencyManager = cmResult
        print("Successfully created CurrencyManager instance")
    else
        warn("Failed to create CurrencyManager instance:", cmResult)
        currencyManager = {}
    end
else
    warn("CurrencyManagerModule or CurrencyManagerModule.new is not available")
    currencyManager = {}
end

-- Initialize managers with error handling
if gameManager and gameManager.Initialize then
    local success, error = pcall(function()
        gameManager:Initialize()
    end)
    
    if not success then
        warn("Failed to initialize GameManager:", error)
    end
end

if currencyManager and currencyManager.Initialize then
    local success, error = pcall(function()
        currencyManager:Initialize()
    end)
    
    if not success then
        warn("Failed to initialize CurrencyManager:", error)
    end
end 