-- ClientInit.client.luau
-- Main client-side initialization script

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

print("ClientInit: Starting client-side initialization...")

-- Wait for essential services
wait(1)

-- Initialize the ItemInteractionClient with the new bottom purchase popup system
local success, errorMessage = pcall(function()
    local ItemInteractionClient = require(script.Parent.interaction.ItemInteractionClient)
    
    -- Create and initialize the client
    local interactionClient = ItemInteractionClient.new()
    local initSuccess = interactionClient:Initialize()
    
    if initSuccess then
        print("ClientInit: ItemInteractionClient initialized successfully with bottom purchase popup system")
        
        -- IMPORTANT: Disable proximity UI completely for this instance
        interactionClient.proximityEnabled = false
        print("ClientInit: Disabled proximity UI - only bottom popup system active")
        
        -- Store globally for other scripts to access if needed
        _G.ItemInteractionClient = interactionClient
    else
        warn("ClientInit: Failed to initialize ItemInteractionClient")
    end
    
    -- Clean up when player leaves
    player.AncestryChanged:Connect(function()
        if interactionClient then
            interactionClient:Cleanup()
        end
    end)
end)

if not success then
    warn("ClientInit: Error initializing ItemInteractionClient:", errorMessage)
end

print("ClientInit: Client initialization complete") 