--[[
    DIAGNOSTIC_INTERACTION_FIX.lua
    
    This script helps diagnose and fix interaction system issues in ForeverBuild2.
    To use:
    1. Run this script in Roblox Studio while testing the game
    2. Check the output for diagnostic information
    3. If needed, the script will attempt to fix common issues
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

-- Status tracking
local fixes = {}
local warnings = {}
local errors = {}

local function log(message, type)
    type = type or "INFO"
    local prefix = "[DIAGNOSTIC]"
    
    if type == "INFO" then
        print(prefix, message)
    elseif type == "WARNING" then
        warn(prefix, message)
        table.insert(warnings, message)
    elseif type == "ERROR" then
        warn(prefix, "ERROR:", message)
        table.insert(errors, message)
    elseif type == "FIX" then
        print(prefix, "FIXED:", message)
        table.insert(fixes, message)
    end
end

local function checkStructure()
    log("Checking game structure...")
    
    -- Check ReplicatedStorage/shared
    local shared = ReplicatedStorage:FindFirstChild("shared")
    if not shared then
        log("Missing 'shared' folder in ReplicatedStorage", "ERROR")
        
        -- Try to fix
        shared = Instance.new("Folder")
        shared.Name = "shared"
        shared.Parent = ReplicatedStorage
        log("Created missing 'shared' folder in ReplicatedStorage", "FIX")
    end
    
    -- Check ReplicatedStorage/Remotes
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then
        log("Missing 'Remotes' folder in ReplicatedStorage", "ERROR")
        
        -- Try to fix
        remotes = Instance.new("Folder")
        remotes.Name = "Remotes"
        remotes.Parent = ReplicatedStorage
        log("Created missing 'Remotes' folder in ReplicatedStorage", "FIX")
    end
    
    -- Check client scripts in StarterPlayerScripts
    local starterScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
    if not starterScripts then
        log("Missing 'StarterPlayerScripts' in StarterPlayer", "ERROR")
        return
    end
    
    local clientFolder = starterScripts:FindFirstChild("client")
    if not clientFolder then
        log("Missing 'client' folder in StarterPlayerScripts", "ERROR")
        return
    end
    
    local interactionFolder = clientFolder:FindFirstChild("interaction")
    if not interactionFolder then
        log("Missing 'interaction' folder in client scripts", "ERROR")
        
        -- Try to fix
        interactionFolder = Instance.new("Folder")
        interactionFolder.Name = "interaction"
        interactionFolder.Parent = clientFolder
        log("Created missing 'interaction' folder in client scripts", "FIX")
    end
    
    -- Check interaction system module
    local interactionModule = interactionFolder:FindFirstChild("InteractionSystemModule")
    if not interactionModule then
        log("Missing 'InteractionSystemModule' in interaction folder", "ERROR")
    else
        log("Found InteractionSystemModule: " .. interactionModule:GetFullName(), "INFO")
    end
end

local function checkRemotes()
    log("Checking remote events and functions...")
    
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then
        log("Remotes folder not found, cannot check remotes", "ERROR")
        return
    end
    
    -- Required remotes for interaction system
    local requiredRemotes = {
        ["GetAvailableInteractions"] = "RemoteFunction",
        ["CloneItem"] = "RemoteEvent",
        ["PickupItem"] = "RemoteEvent",
        ["InteractWithItem"] = "RemoteEvent",
        ["GetItemData"] = "RemoteFunction"
    }
    
    for name, remoteType in pairs(requiredRemotes) do
        local remote = remotes:FindFirstChild(name)
        if not remote then
            log("Missing remote " .. name .. " (" .. remoteType .. ")", "ERROR")
            
            -- Try to fix
            remote = Instance.new(remoteType)
            remote.Name = name
            remote.Parent = remotes
            log("Created missing remote " .. name, "FIX")
        else
            log("Found remote: " .. name, "INFO")
        end
    end
end

local function repairInteractionSystem()
    log("Attempting to repair interaction system...")
    
    -- Check for client in active players
    for _, player in pairs(Players:GetPlayers()) do
        local playerScripts = player:FindFirstChild("PlayerScripts")
        if playerScripts then
            local clientFolder = playerScripts:FindFirstChild("client")
            if clientFolder then
                local interactionFolder = clientFolder:FindFirstChild("interaction")
                if not interactionFolder then
                    interactionFolder = Instance.new("Folder")
                    interactionFolder.Name = "interaction"
                    interactionFolder.Parent = clientFolder
                    log("Created missing interaction folder for player: " .. player.Name, "FIX")
                end
                
                -- Check for InteractionSystemModule
                local interactionModule = interactionFolder:FindFirstChild("InteractionSystemModule")
                if not interactionModule then
                    log("InteractionSystemModule missing for player: " .. player.Name, "ERROR")
                    
                    -- Try to get it from StarterPlayer
                    local starterScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
                    if starterScripts then
                        local starterClientFolder = starterScripts:FindFirstChild("client")
                        if starterClientFolder then
                            local starterInteractionFolder = starterClientFolder:FindFirstChild("interaction")
                            if starterInteractionFolder then
                                local starterModule = starterInteractionFolder:FindFirstChild("InteractionSystemModule")
                                if starterModule then
                                    log("Found module in StarterPlayerScripts, will clone to player", "INFO")
                                    local clonedModule = starterModule:Clone()
                                    clonedModule.Parent = interactionFolder
                                    log("Cloned InteractionSystemModule to player: " .. player.Name, "FIX")
                                end
                            end
                        end
                    end
                    
                    -- If still missing, recreate emergency version
                    if not interactionFolder:FindFirstChild("InteractionSystemModule") and 
                       not interactionFolder:FindFirstChild("InteractionSystemModule_emergency") then
                        log("Creating emergency interaction module for player: " .. player.Name, "FIX")
                        
                        -- Create an emergency module script
                        local emergencyModule = Instance.new("ModuleScript")
                        emergencyModule.Name = "InteractionSystemModule_emergency"
                        emergencyModule.Source = [[
--[[
    EMERGENCY InteractionSystemModule
    Auto-generated by diagnostic script
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

print("🚨 EMERGENCY InteractionSystem module loading...")

local InteractionSystem = {}
InteractionSystem.__index = InteractionSystem

function InteractionSystem.new()
    local self = setmetatable({}, InteractionSystem)
    self.player = Players.LocalPlayer
    self.remoteEvents = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
    if not self.remoteEvents.Parent then
        self.remoteEvents.Name = "Remotes"
        self.remoteEvents.Parent = ReplicatedStorage
    end
    return self
end

function InteractionSystem:Initialize()
    print("🚨 EMERGENCY InteractionSystem:Initialize() called")
    
    -- Create emergency notification
    local playerGui = self.player:FindFirstChild("PlayerGui")
    if playerGui then
        local notificationUI = Instance.new("ScreenGui")
        notificationUI.Name = "EmergencyNotification"
        notificationUI.ResetOnSpawn = false
        notificationUI.Parent = playerGui
        
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 300, 0, 60)
        frame.Position = UDim2.new(0.5, -150, 0, 10)
        frame.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        frame.BackgroundTransparency = 0.2
        frame.Parent = notificationUI
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -20, 1, -20)
        label.Position = UDim2.new(0, 10, 0, 10)
        label.Text = "EMERGENCY INTERACTION SYSTEM ACTIVE"
        label.TextColor3 = Color3.new(1, 1, 1)
        label.BackgroundTransparency = 1
        label.TextSize = 14
        label.TextWrapped = true
        label.Parent = frame
        
        -- Clean up after 5 seconds
        task.delay(5, function()
            notificationUI:Destroy()
        end)
    end
    
    return true
end

-- Basic method stubs that won't error
function InteractionSystem:SetupMouseHandling() end
function InteractionSystem:SetupEventHandlers() end
function InteractionSystem:UpdateCurrentTarget() end
function InteractionSystem:ShowInteractionUI() end
function InteractionSystem:HideInteractionUI() end
function InteractionSystem:AttemptInteraction() end
function InteractionSystem:GetAvailableInteractions() return {"examine"} end
function InteractionSystem:ShowInteractionMenu() end
function InteractionSystem:PerformInteraction() end
function InteractionSystem:CreateUI() end

return InteractionSystem
]]
                        emergencyModule.Parent = interactionFolder
                    end
                end
            end
        end
    end
end

local function checkClientCore()
    log("Checking client_core module...")
    
    for _, player in pairs(Players:GetPlayers()) do
        local playerScripts = player:FindFirstChild("PlayerScripts")
        if playerScripts then
            local clientFolder = playerScripts:FindFirstChild("client")
            if clientFolder then
                local clientCore = clientFolder:FindFirstChild("client_core")
                if clientCore then
                    log("Found client_core for player: " .. player.Name, "INFO")
                    
                    -- Run diagnostic check
                    local success, result = pcall(function()
                        return require(clientCore)
                    end)
                    
                    if success then
                        log("client_core module loaded successfully for player: " .. player.Name, "INFO")
                    else
                        log("Error loading client_core module: " .. tostring(result), "ERROR")
                    end
                else
                    log("client_core module not found for player: " .. player.Name, "ERROR")
                end
            end
        end
    end
end

-- Main diagnostics execution
local function runDiagnostics()
    log("=== STARTING INTERACTION SYSTEM DIAGNOSTICS ===")
    
    -- Run all diagnostic checks
    checkStructure()
    checkRemotes()
    repairInteractionSystem()
    checkClientCore()
    
    -- Print summary
    log("=== DIAGNOSTIC SUMMARY ===")
    log("Fixes applied: " .. #fixes)
    log("Warnings: " .. #warnings)
    log("Errors: " .. #errors)
    
    if #fixes > 0 then
        log("Applied fixes:", "INFO")
        for i, fix in ipairs(fixes) do
            log(i .. ". " .. fix, "INFO")
        end
    end
    
    if #errors > 0 then
        log("Errors found:", "ERROR")
        for i, err in ipairs(errors) do
            log(i .. ". " .. err, "ERROR")
        end
    end
    
    log("=== DIAGNOSTIC COMPLETE ===")
    log("Please check if the interaction system works now. If not, try rejoining the game or restarting Roblox Studio.")
end

-- Run the diagnostics
runDiagnostics()
