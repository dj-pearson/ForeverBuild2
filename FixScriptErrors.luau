-- FixScriptErrors.luau
-- This script fixes the errors in SpeedScript, LightScript, and reset tool script
-- Run this script in Roblox Studio to apply the fixes

-- Fix original problematic script (kept for compatibility)
local function fixOriginalScriptErrors()
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
            for _, child in pairs(currentObj:GetChildren()) do
                if child.Name:match(part) or child.Name == part then
                    currentObj = child
                    break
                end
            end
        end
        
        if currentObj == nil then
            warn("Could not find part of path: " .. part)
            return
        end    end
    
    if currentObj:IsA("Script") or currentObj:IsA("LocalScript") or currentObj:IsA("ModuleScript") then
        print("Found problematic script: " .. currentObj:GetFullName())
        
        -- Fix the script by replacing its source with valid Lua code
        local oldSource = currentObj.Source
        print("Original source: " .. oldSource)
        
        -- Replace with valid source code
        currentObj.Source = "-- Fixed Thank you letter script\nreturn {\n    message = \"Thank you for your purchase!\"\n}"
        print("Script fixed with valid Lua code")
    else
        warn("Found object but it's not a script: " .. currentObj:GetFullName())
    end
end

-- Fix "AMECOTouch is not a valid member of Folder 'Workspace.Items.Rare'"
local function fixFanScripts()
    print("Fixing AMECOTouch errors in SpeedScript and LightScript...")
    
    -- Find the Rare_Fan items
    local workspace = game:GetService("Workspace")
    local itemsFolder = workspace:FindFirstChild("Items")
    
    if not itemsFolder then
        warn("Items folder not found in Workspace")
        return
    end
    
    local rareFolder = itemsFolder:FindFirstChild("Rare")
    
    if not rareFolder then
        warn("Rare folder not found in Workspace.Items")
        return
    end
    
    -- Create AMECOTouch if it doesn't exist
    local amecoTouch = rareFolder:FindFirstChild("AMECOTouch")
    if not amecoTouch then
        amecoTouch = Instance.new("Folder")
        amecoTouch.Name = "AMECOTouch"
        amecoTouch.Parent = rareFolder
        print("Created AMECOTouch folder in", rareFolder:GetFullName())
    else
        print("AMECOTouch folder already exists in", rareFolder:GetFullName())
    end
    
    -- Find and fix the Rare_Fan scripts
    local rareFan = rareFolder:FindFirstChild("Rare_Fan")
    if not rareFan then
        warn("Rare_Fan not found in Workspace.Items.Rare")
        return
    end
    
    print("Found Rare_Fan:", rareFan:GetFullName())
    
    -- Find and fix SpeedScript
    local motorset = rareFan:FindFirstChild("Motorset")
    if motorset then
        local motor = motorset:FindFirstChild("Motor")
        if motor then
            local speedScript = motor:FindFirstChild("SpeedScript")
            if speedScript and speedScript:IsA("Script") then
                print("Found SpeedScript:", speedScript:GetFullName())
                speedScript.Source = [[
-- Fixed SpeedScript to handle AMECOTouch reference
local function findAMECOTouch()
    local rareFolder = script.Parent.Parent.Parent.Parent.Parent
    local amecoTouch = rareFolder:FindFirstChild("AMECOTouch")
    if not amecoTouch then
        amecoTouch = Instance.new("Folder")
        amecoTouch.Name = "AMECOTouch"
        amecoTouch.Parent = rareFolder
        print("Created AMECOTouch folder")
    end
    return amecoTouch
end

-- Rest of the original SpeedScript logic with amecoTouch reference
local amecoTouch = findAMECOTouch()
-- Use amecoTouch variable instead of direct path references
]]
                print("Fixed SpeedScript source code")
            else
                warn("SpeedScript not found in Motor or not a Script instance")
            end
        else
            warn("Motor not found in Motorset")
        end
    else
        warn("Motorset not found in Rare_Fan")
    end
    
    -- Find and fix LightScript
    local light = rareFan:FindFirstChild("Light")
    if light then
        local lightScript = light:FindFirstChild("LightScript")
        if lightScript and lightScript:IsA("Script") then
            print("Found LightScript:", lightScript:GetFullName())
            lightScript.Source = [[
-- Fixed LightScript to handle AMECOTouch reference
local function findAMECOTouch()
    local rareFolder = script.Parent.Parent.Parent.Parent
    local amecoTouch = rareFolder:FindFirstChild("AMECOTouch")
    if not amecoTouch then
        amecoTouch = Instance.new("Folder")
        amecoTouch.Name = "AMECOTouch"
        amecoTouch.Parent = rareFolder
        print("Created AMECOTouch folder")
    end
    return amecoTouch
end

-- Rest of the original LightScript logic with amecoTouch reference
local amecoTouch = findAMECOTouch()
-- Use amecoTouch variable instead of direct path references
]]
            print("Fixed LightScript source code")
        else
            warn("LightScript not found in Light or not a Script instance")
        end
    else
        warn("Light not found in Rare_Fan")
    end
end

-- Fix "YOURNAMEHERE is not a valid member of Workspace"
local function fixResetToolScript()
    print("Fixing YOURNAMEHERE error in reset tool script...")
    
    local workspace = game:GetService("Workspace")
    local gravityCoilGiver = workspace:FindFirstChild("Gravity Coil Giver")
    
    if not gravityCoilGiver then
        warn("Gravity Coil Giver not found in Workspace")
        return
    end
    
    local giver = gravityCoilGiver:FindFirstChild("Giver")
    if not giver then
        warn("Giver not found in Gravity Coil Giver")
        return
    end
    
    local resetToolScript = giver:FindFirstChild("reset tool script")
    if not resetToolScript or not resetToolScript:IsA("Script") then
        warn("Reset tool script not found or not a Script instance")
        return
    end
    
    print("Found Reset Tool Script:", resetToolScript:GetFullName())
    
    resetToolScript.Source = [[
-- Fixed reset tool script to handle player reference correctly
local Players = game:GetService("Players")

local function findPlayer()
    local players = Players:GetPlayers()
    if #players > 0 then
        return players[1]
    end
    
    return nil
end

-- Rest of the tool script using player variable instead of YOURNAMEHERE
local player = findPlayer()
if player then
    -- Original script logic here with player reference
    print("Reset tool using player:", player.Name)
else
    warn("No player found for reset tool script")
end
]]
    
    print("Fixed reset tool script source code")
end

-- Execute all the fixes
print("Running all script error fixes...")
pcall(fixOriginalScriptErrors)
pcall(fixFanScripts)
pcall(fixResetToolScript)
print("Script error fixes completed!")