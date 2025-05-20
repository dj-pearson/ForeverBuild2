-- FixScriptErrors.lua
-- This script fixes the errors in SpeedScript, LightScript, and reset tool script
-- Run this script in Roblox Studio to apply the fixes

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
    
    local rareFan = rareFolder:FindFirstChild("Rare_Fan")
    
    if not rareFan then
        warn("Rare_Fan not found in Workspace.Items.Rare")
        return
    end
    
    print("Found Rare_Fan:", rareFan:GetFullName())
    
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
    
    -- Fix SpeedScript in Motor
    local motorset = rareFan:FindFirstChild("Motorset")
    if motorset then
        local motor = motorset:FindFirstChild("Motor")
        if motor then
            local speedScript = motor:FindFirstChild("SpeedScript")
            if speedScript and speedScript:IsA("Script") then
                print("Found SpeedScript:", speedScript:GetFullName())
                
                local success, currentSource = pcall(function()
                    return speedScript.Source
                end)
                
                if success then
                    -- Replace references to AMECOTouch with corrected path
                    local fixedSource = currentSource:gsub(
                        "script%.Parent%.Parent%.Parent%.Parent%.AMECOTouch",
                        "script.Parent.Parent.Parent.Parent.Parent.AMECOTouch"
                    )
                    
                    if fixedSource ~= currentSource then
                        speedScript.Source = fixedSource
                        print("Fixed SpeedScript source code")
                    else
                        print("SpeedScript source did not need path fixes")
                        
                        -- Try alternative fixes
                        if not currentSource:find("pcall") then
                            local safeSource = [[
local success, amecoTouch = pcall(function()
    return script.Parent.Parent.Parent.Parent.Parent.AMECOTouch
end)

if not success then
    amecoTouch = script.Parent.Parent.Parent.Parent.AMECOTouch
    if not amecoTouch then
        warn("AMECOTouch not found, creating it")
        amecoTouch = Instance.new("Folder")
        amecoTouch.Name = "AMECOTouch"
        amecoTouch.Parent = script.Parent.Parent.Parent.Parent.Parent
    end
end

-- Rest of script continues with amecoTouch instead of direct references
]] .. currentSource:gsub("script%.Parent%.Parent%.Parent%.Parent%.AMECOTouch", "amecoTouch")
                            
                            speedScript.Source = safeSource
                            print("Applied safe access pattern to SpeedScript")
                        end
                    end
                else
                    warn("Couldn't read SpeedScript source:", currentSource)
                end
            else
                warn("SpeedScript not found in Motor or not a Script instance")
            end
        else
            warn("Motor not found in Motorset")
        end
    else
        warn("Motorset not found in Rare_Fan")
    end
    
    -- Fix LightScript
    local light = rareFan:FindFirstChild("Light")
    if light then
        local lightScript = light:FindFirstChild("LightScript")
        if lightScript and lightScript:IsA("Script") then
            print("Found LightScript:", lightScript:GetFullName())
            
            local success, currentSource = pcall(function()
                return lightScript.Source
            end)
            
            if success then
                -- Replace references to AMECOTouch with corrected path
                local fixedSource = currentSource:gsub(
                    "script%.Parent%.Parent%.Parent%.AMECOTouch",
                    "script.Parent.Parent.Parent.Parent.AMECOTouch"
                )
                
                if fixedSource ~= currentSource then
                    lightScript.Source = fixedSource
                    print("Fixed LightScript source code")
                else
                    print("LightScript source did not need path fixes")
                    
                    -- Try alternative fixes
                    if not currentSource:find("pcall") then
                        local safeSource = [[
local success, amecoTouch = pcall(function()
    return script.Parent.Parent.Parent.Parent.AMECOTouch
end)

if not success then
    amecoTouch = script.Parent.Parent.Parent.AMECOTouch
    if not amecoTouch then
        warn("AMECOTouch not found, creating it")
        amecoTouch = Instance.new("Folder")
        amecoTouch.Name = "AMECOTouch"
        amecoTouch.Parent = script.Parent.Parent.Parent.Parent
    end
end

-- Rest of script continues with amecoTouch instead of direct references
]] .. currentSource:gsub("script%.Parent%.Parent%.Parent%.AMECOTouch", "amecoTouch")
                        
                        lightScript.Source = safeSource
                        print("Applied safe access pattern to LightScript")
                    end
                end
            else
                warn("Couldn't read LightScript source:", currentSource)
            end
        else
            warn("LightScript not found in Light or not a Script instance")
        end
    else
        warn("Light not found in Rare_Fan")
    end
end

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
    
    local success, currentSource = pcall(function()
        return resetToolScript.Source
    end)
    
    if not success then
        warn("Couldn't read reset tool script source:", currentSource)
        return
    end
    
    -- Replace YOURNAMEHERE with the current player's name
    local playerName = "Player" -- Default value
    
    local players = game:GetService("Players"):GetPlayers()
    if #players > 0 then
        playerName = players[1].Name
    end
    
    local fixedSource = currentSource:gsub("YOURNAMEHERE", playerName)
    
    -- If that doesn't work, add a safer implementation
    if fixedSource == currentSource then
        fixedSource = [[
-- Safe reset tool script
local Players = game:GetService("Players")

local function findPlayer()
    local localPlayer = nil
    pcall(function()
        localPlayer = Players.LocalPlayer
    end)
    
    if localPlayer then
        return localPlayer
    end
    
    local players = Players:GetPlayers()
    if #players > 0 then
        return players[1]
    end
    
    return nil
end

local player = findPlayer()
if player then
    -- Original script logic with player variable instead of hardcoded name
]] .. currentSource:gsub("YOURNAMEHERE", "player") .. [[
else
    warn("No player found for reset tool script")
end
]]
    end
    
    resetToolScript.Source = fixedSource
    print("Fixed reset tool script source code")
end

-- Execute the fixes
print("Running script error fixes...")
pcall(fixFanScripts)
pcall(fixResetToolScript)
print("Script error fixes completed!")
