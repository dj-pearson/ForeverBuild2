local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

print("Client initialization script starting...")

-- Wait for remotes to exist before initializing shared module
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
if not Remotes then
    warn("Failed to find Remotes folder in ReplicatedStorage. Server may not be initialized yet.")
    Remotes = Instance.new("Folder")
    Remotes.Name = "Remotes"
    Remotes.Parent = ReplicatedStorage
end

-- Initialize shared module
local success, SharedModule = pcall(function()
    return require(ReplicatedStorage:WaitForChild("shared", 10))
end)

if not success then
    warn("Failed to require SharedModule: ", SharedModule)
    SharedModule = {}
else
    print("Successfully required SharedModule")
    
    if SharedModule.Init then
        local initSuccess, errorMsg = pcall(function()
            SharedModule.Init() -- Ensure all shared systems are initialized
        end)
    
        if not initSuccess then
            warn("Failed to initialize SharedModule: ", errorMsg)
        end
    end
end

-- Load client_core module which contains the main client logic
local clientCoreModuleScript = script.Parent:WaitForChild("client_core", 10)
if not clientCoreModuleScript then
    warn("Could not find the 'client_core' ModuleScript after 10 seconds.")
    return
end

print("Found client_core ModuleScript: " .. clientCoreModuleScript:GetFullName())

-- Require the ModuleScript
local success, clientCoreAPI = pcall(require, clientCoreModuleScript)
if not success then
    warn("Failed to load client_core ModuleScript. Error: ", tostring(clientCoreAPI))
    return
end

print("client_core ModuleScript loaded successfully")

-- Initialize UI components with error handling
local function safeInitialize(module, name)
    if not module then
        warn("Module " .. name .. " is nil")
        return nil
    end
    
    local success, result = pcall(function()
        if typeof(module) == "table" and module.new then
            -- OOP style initialization
            local instance = module.new()
            instance:Initialize()
            return instance
        elseif typeof(module) == "table" and module.Initialize then
            -- Functional style initialization
            module.Initialize(Players.LocalPlayer.PlayerGui)
            return module
        else
            warn("Module " .. name .. " doesn't have proper initialization method")
            return nil
        end
    end)

    if not success then
        warn("Failed to initialize " .. name .. ": ", result)
        return nil
    end

    return result
end

-- Initialize CurrencyUI only (other UIs are handled by client_core)
local currencyUI = safeInitialize(SharedModule.CurrencyUI, "CurrencyUI")

print("Client initialization completed successfully") 