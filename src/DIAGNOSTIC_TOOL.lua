--[[
    ForeverBuild2 Diagnostic Tool
    
    This script helps diagnose path resolution issues in the game.
    Place it in ServerScriptService and run it to see detailed information about the game structure.
]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")

-- Utility functions
local function printInstanceTree(instance, depth, maxDepth)
    depth = depth or 0
    maxDepth = maxDepth or 3
    
    if depth > maxDepth then
        print(string.rep("  ", depth) .. "... (max depth reached)")
        return
    end
    
    local className = instance.ClassName
    local fullName = instance:GetFullName()
    print(string.rep("  ", depth) .. instance.Name .. " (" .. className .. ") - " .. fullName)
    
    if className == "ModuleScript" then
        -- Try to require the module and print its contents
        local success, result = pcall(function()
            return require(instance)
        end)
        
        if success and type(result) == "table" then
            print(string.rep("  ", depth + 1) .. "Module contents:")
            for key, value in pairs(result) do
                local valueType = type(value)
                if valueType == "function" then
                    print(string.rep("  ", depth + 2) .. key .. " (function)")
                elseif valueType == "table" then
                    print(string.rep("  ", depth + 2) .. key .. " (table)")
                else
                    print(string.rep("  ", depth + 2) .. key .. " (" .. valueType .. "): " .. tostring(value))
                end
            end
        elseif success then
            print(string.rep("  ", depth + 1) .. "Module returned: " .. tostring(result) .. " (" .. type(result) .. ")")
        else
            print(string.rep("  ", depth + 1) .. "Failed to require module: " .. tostring(result))
        end
    end
    
    -- Recursively print children
    for _, child in ipairs(instance:GetChildren()) do
        printInstanceTree(child, depth + 1, maxDepth)
    end
end

-- Print header
print("\n=== FORVERBUILD2 DIAGNOSTIC TOOL ===\n")

-- Print ReplicatedStorage structure
print("\n--- REPLICATED STORAGE STRUCTURE ---\n")
local shared = ReplicatedStorage:FindFirstChild("shared")
if shared then
    printInstanceTree(shared, 0, 2)
else
    print("'shared' module not found in ReplicatedStorage")
end

-- Print ServerScriptService structure
print("\n--- SERVER SCRIPT SERVICE STRUCTURE ---\n")
local server = ServerScriptService:FindFirstChild("server")
if server then
    printInstanceTree(server, 0, 1)
else
    print("'server' folder not found in ServerScriptService")
end

-- Print StarterGui structure
print("\n--- STARTER GUI STRUCTURE ---\n")
printInstanceTree(StarterGui, 0, 1)

-- Print player structure if any players are in the game
print("\n--- PLAYER STRUCTURE ---\n")
local player = Players:GetPlayers()[1]
if player then
    print("Player: " .. player.Name)
    
    local playerScripts = player:FindFirstChild("PlayerScripts")
    if playerScripts then
        local client = playerScripts:FindFirstChild("client")
        if client then
            printInstanceTree(client, 1, 2)
        else
            print("  'client' script not found in PlayerScripts")
        end
    else
        print("  PlayerScripts not found for player")
    end
    
    local playerGui = player:FindFirstChild("PlayerGui")
    if playerGui then
        printInstanceTree(playerGui, 1, 1)
    else
        print("  PlayerGui not found for player")
    end
else
    print("No players in the game")
end

print("\n=== DIAGNOSTIC COMPLETE ===\n")

-- Try to require shared module and print detailed information
print("\n--- SHARED MODULE TEST ---\n")
local success, sharedModule = pcall(function()
    return require(ReplicatedStorage:WaitForChild("shared"))
end)

if success then
    print("Successfully required shared module")
    print("Shared module type: " .. type(sharedModule))
    
    if type(sharedModule) == "table" then
        print("Shared module contents:")
        for key, value in pairs(sharedModule) do
            print("  - " .. key .. " (" .. type(value) .. ")")
        end
        
        if sharedModule.Core then
            print("Core module contents:")
            for key, value in pairs(sharedModule.Core) do
                print("  - " .. key .. " (" .. type(value) .. ")")
            end
        else
            print("Core module not found in shared module")
        end
    end
else
    print("Failed to require shared module: " .. tostring(sharedModule))
end 