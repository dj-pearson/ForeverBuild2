--[[
    INSTALL_FIXED_MODULE.lua
    
    This script will replace the standard InteractionSystemModule with the fixed version.
    Run this script in the Command Bar in Roblox Studio.
]]

print("Starting installation of fixed interaction module...")

-- Locate the fixed module file
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- Paths to look for the module
local possiblePaths = {
    game.Workspace,
    game.ServerScriptService,
    game.ReplicatedStorage,
    game.ServerStorage
}

-- First, look for the fixed module
local fixedModule = nil

for _, container in ipairs(possiblePaths) do
    -- Look for direct file
    fixedModule = container:FindFirstChild("InteractionSystemModule_fixed.lua")
    if fixedModule then
        print("Found fixed module at " .. container:GetFullName())
        break
    end
    
    -- Look in client/interaction subfolder
    local client = container:FindFirstChild("client")
    if client then
        local interaction = client:FindFirstChild("interaction")
        if interaction then
            fixedModule = interaction:FindFirstChild("InteractionSystemModule_fixed.lua")
            if fixedModule then
                print("Found fixed module at " .. interaction:GetFullName())
                break
            end
        end
    end
    
    -- Look in src/client/interaction subfolder
    local src = container:FindFirstChild("src")
    if src then
        local client = src:FindFirstChild("client")
        if client then
            local interaction = client:FindFirstChild("interaction")
            if interaction then
                fixedModule = interaction:FindFirstChild("InteractionSystemModule_fixed.lua")
                if fixedModule then
                    print("Found fixed module at " .. interaction:GetFullName())
                    break
                end
            end
        end
    end
end

if not fixedModule then
    warn("Could not find InteractionSystemModule_fixed.lua in workspace, ServerScriptService, ReplicatedStorage, or ServerStorage.")
    warn("Please make sure to place InteractionSystemModule_fixed.lua in one of these locations.")
    return
end

-- Now find all instances of the original module
local originalModules = {}

for _, container in ipairs(possiblePaths) do
    -- Look in client/interaction subfolder
    local client = container:FindFirstChild("client")
    if client then
        local interaction = client:FindFirstChild("interaction")
        if interaction then
            local original = interaction:FindFirstChild("InteractionSystemModule.lua")
            if original then
                table.insert(originalModules, original)
            end
        end
    end
    
    -- Look in src/client/interaction subfolder
    local src = container:FindFirstChild("src")
    if src then
        local client = src:FindFirstChild("client")
        if client then
            local interaction = client:FindFirstChild("interaction")
            if interaction then
                local original = interaction:FindFirstChild("InteractionSystemModule.lua")
                if original then
                    table.insert(originalModules, original)
                end
            end
        end
    end
end

if #originalModules == 0 then
    warn("Could not find any instances of InteractionSystemModule.lua to replace.")
    return
end

print("Found " .. #originalModules .. " instances of InteractionSystemModule.lua")

-- Replace each original module with the fixed version
for i, original in ipairs(originalModules) do
    print("Replacing " .. original:GetFullName())
    
    -- Backup the original
    local backup = original:Clone()
    backup.Name = "InteractionSystemModule_backup.lua"
    backup.Parent = original.Parent
    
    -- Replace the content of the original with the fixed version's content
    original.Source = fixedModule.Source
    
    print("Replaced and backed up " .. original:GetFullName())
end

print("Installation complete! " .. #originalModules .. " modules were updated.")
print("The original versions were backed up as InteractionSystemModule_backup.lua")
print("You may now test the interaction system.")
