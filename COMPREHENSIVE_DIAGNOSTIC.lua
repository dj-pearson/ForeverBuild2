-- COMPREHENSIVE_DIAGNOSTIC.lua
-- Run this script in the command bar in Roblox Studio to diagnose module loading issues

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")

-- Configuration
local VERBOSE = true  -- Set to true for detailed output

-- Print with timestamp
local function tprint(...)
    local timestamp = os.date("[%H:%M:%S]")
    print(timestamp, ...)
end

-- Create rich text colored output
local function colored(text, color)
    if not VERBOSE then return text end
    
    local colors = {
        green = "rgb(0, 255, 0)",
        red = "rgb(255, 0, 0)",
        yellow = "rgb(255, 255, 0)",
        blue = "rgb(100, 100, 255)",
        magenta = "rgb(255, 0, 255)",
        cyan = "rgb(0, 255, 255)",
        white = "rgb(255, 255, 255)"
    }
    
    local colorCode = colors[color] or colors.white
    return string.format('<font color="%s">%s</font>', colorCode, text)
end

local SUCCESS = colored("✓", "green")
local FAILURE = colored("✗", "red")
local WARNING = colored("⚠", "yellow")
local INFO = colored("ℹ", "blue")

-- Header
tprint(colored("========================================", "cyan"))
tprint(colored("    COMPREHENSIVE MODULE DIAGNOSTICS    ", "cyan"))
tprint(colored("========================================", "cyan"))

-- Perform diagnostic on a module
local function diagnoseModule(moduleScript, depth)
    depth = depth or 0
    local indent = string.rep("  ", depth)
    local name = moduleScript:GetFullName()
    
    -- Try to require the module
    local success, result = pcall(function()
        return require(moduleScript)
    end)
    
    if success then
        tprint(indent .. SUCCESS .. " " .. name)
        
        -- Check if it's an empty module
        if moduleScript.Source == "" then
            tprint(indent .. WARNING .. " Module has empty source")
        end
        
        -- Check if it returns a table
        if type(result) == "table" then
            -- Analyze module properties
            local props = {}
            for k, v in pairs(result) do
                table.insert(props, k .. " (" .. type(v) .. ")")
            end
            
            if #props > 0 then
                tprint(indent .. INFO .. " Properties: " .. table.concat(props, ", "))
            else
                tprint(indent .. WARNING .. " Module returns empty table")
            end
            
            -- Check for Init/Initialize function
            if type(result.Init) == "function" or type(result.Initialize) == "function" then
                local initFn = result.Init or result.Initialize
                local initSuccess, initResult = pcall(initFn)
                
                if initSuccess then
                    tprint(indent .. SUCCESS .. " Initialization function succeeded")
                else
                    tprint(indent .. FAILURE .. " Initialization failed: " .. tostring(initResult))
                end
            end
        else
            tprint(indent .. INFO .. " Module returns " .. type(result))
        end
    else
        tprint(indent .. FAILURE .. " " .. name .. ": " .. tostring(result))
    end
end

-- Recursively diagnose a folder structure
local function diagnoseFolderStructure(folder, depth)
    depth = depth or 0
    local indent = string.rep("  ", depth)
    
    tprint(indent .. colored("Folder: " .. folder:GetFullName(), "magenta"))
    
    -- Check children
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("ModuleScript") then
            diagnoseModule(child, depth + 1)
        elseif child:IsA("Folder") or child:IsA("Script") or child:IsA("LocalScript") then
            diagnoseFolderStructure(child, depth + 1)
        else
            tprint(indent .. "  " .. INFO .. " " .. child.Name .. " (" .. child.ClassName .. ")")
        end
    end
end

-- Diagnose shared module
tprint("\n" .. colored("DIAGNOSING SHARED MODULE", "cyan"))
local shared = ReplicatedStorage:FindFirstChild("shared")
if shared then
    -- Try to require the shared module directly
    tprint(INFO .. " Attempting to require shared module...")
    local success, result = pcall(function()
        return require(shared)
    end)
    
    if success then
        tprint(SUCCESS .. " Successfully required shared module")
        
        -- Test initialization
        if type(result.Init) == "function" then
            local initSuccess, initResult = pcall(result.Init)
            if initSuccess then
                tprint(SUCCESS .. " SharedModule.Init succeeded")
            else
                tprint(FAILURE .. " SharedModule.Init failed: " .. tostring(initResult))
            end
        else
            tprint(WARNING .. " SharedModule has no Init function")
        end
        
        -- Check for key modules
        local expectedModules = {
            "Constants", "GameManager", "LazyLoadModules", 
            "CurrencyUI", "InventoryUI", "PlacedItemDialog", "PurchaseDialog",
            "InteractionManager"
        }
        
        for _, modName in ipairs(expectedModules) do
            if result[modName] then
                tprint(SUCCESS .. " Found " .. modName .. " module")
            else
                tprint(FAILURE .. " Missing " .. modName .. " module")
            end
        end
    else
        tprint(FAILURE .. " Failed to require shared module: " .. tostring(result))
    end
    
    -- Analyze the structure regardless
    diagnoseFolderStructure(shared)
else
    tprint(FAILURE .. " Shared module not found in ReplicatedStorage")
end

-- Diagnose client interaction system
tprint("\n" .. colored("DIAGNOSING CLIENT INTERACTION SYSTEM", "cyan"))
local function diagnoseInteractionSystem()
    local foundInteractionModule = false
    
    -- Check for local players
    for _, player in ipairs(Players:GetPlayers()) do
        tprint(INFO .. " Checking player: " .. player.Name)
        
        local playerScripts = player:FindFirstChild("PlayerScripts")
        if playerScripts then
            local clientScript = playerScripts:FindFirstChild("client")
            if clientScript then
                tprint(SUCCESS .. " Found client script at: " .. clientScript:GetFullName())
                
                local interactionFolder = clientScript:FindFirstChild("interaction")
                if interactionFolder then
                    tprint(SUCCESS .. " Found interaction folder at: " .. interactionFolder:GetFullName())
                    
                    -- Check for interaction modules in priority order
                    local moduleNames = {
                        "InteractionSystemModule", 
                        "InteractionSystemModule_enhanced", 
                        "InteractionSystemModule_emergency"
                    }
                    
                    for _, name in ipairs(moduleNames) do
                        local module = interactionFolder:FindFirstChild(name)
                        if module then
                            tprint(SUCCESS .. " Found " .. name)
                            foundInteractionModule = true
                            
                            -- Try to require it
                            local success, result = pcall(function()
                                return require(module)
                            end)
                            
                            if success then
                                tprint(SUCCESS .. " Successfully required " .. name)
                                
                                -- Check if it can be instantiated
                                if type(result.new) == "function" then
                                    local instSuccess, instance = pcall(result.new)
                                    if instSuccess then
                                        tprint(SUCCESS .. " Successfully created interaction system instance")
                                        
                                        -- Check if it can be initialized
                                        if type(instance.Initialize) == "function" then
                                            tprint(INFO .. " Instance has Initialize method")
                                        else
                                            tprint(FAILURE .. " Instance missing Initialize method")
                                        end
                                    else
                                        tprint(FAILURE .. " Failed to create instance: " .. tostring(instance))
                                    end
                                else
                                    tprint(FAILURE .. " Module doesn't have new function")
                                end
                            else
                                tprint(FAILURE .. " Failed to require " .. name .. ": " .. tostring(result))
                            end
                        else
                            tprint(WARNING .. " " .. name .. " not found")
                        end
                    end
                else
                    tprint(FAILURE .. " Interaction folder not found in client script")
                end
            else
                tprint(FAILURE .. " Client script not found in PlayerScripts")
            end
        else
            tprint(FAILURE .. " PlayerScripts not found for player")
        end
    end
      if not foundInteractionModule then
        tprint(WARNING .. " No interaction module found for any player")
    end
end

diagnoseInteractionSystem()

-- Diagnose remotes
tprint("\n" .. colored("DIAGNOSING REMOTES", "cyan"))
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if remotes then
    tprint(SUCCESS .. " Found Remotes folder")
    
    -- Critical remotes for interaction system
    local criticalRemotes = {
        "GetAvailableInteractions", "CloneItem", "PickupItem", 
        "AddToInventory", "GetItemData", "ApplyItemEffect",
        "BuyItem", "GetInventory", "PlaceItem", "InteractWithItem"
    }
    
    for _, name in ipairs(criticalRemotes) do
        local remote = remotes:FindFirstChild(name)
        if remote then
            tprint(SUCCESS .. " Found " .. name .. " (" .. remote.ClassName .. ")")
        else
            tprint(FAILURE .. " Missing " .. name .. " remote")
        end
    end
else
    tprint(FAILURE .. " Remotes folder not found in ReplicatedStorage")
end

-- Summary
tprint("\n" .. colored("DIAGNOSTIC SUMMARY", "cyan"))
tprint(colored("This diagnostic tool has analyzed the module structure of ForeverBuild.", "white"))
tprint(colored("Check the logs above for issues that need to be addressed.", "white"))
tprint(colored("Run the SHARED_MODULE_FIX.lua and CLIENT_SHARED_MODULE_FIX.lua scripts to automatically fix common issues.", "white"))
tprint(colored("========================================", "cyan"))
