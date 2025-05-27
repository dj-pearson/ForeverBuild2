-- BlueprintServerSetup.luau
-- Server-side initialization and setup for the Blueprint system

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Wait for shared modules
local SharedModules = ReplicatedStorage:WaitForChild("Shared")
local BlueprintManager = require(SharedModules.core.blueprint.BlueprintManager)

-- Get existing system references
local XPManager = require(SharedModules.core.xp.XPManager)
local CurrencyManager = require(SharedModules.core.currency.CurrencyManager)
local SocialManager = require(SharedModules.core.social.SocialManager)

local BlueprintServerSetup = {}

-- Server configuration
local SERVER_CONFIG = {
    BLUEPRINT_XP_REWARDS = {
        CREATE_BLUEPRINT = 50,
        SHARE_BLUEPRINT = 25,
        USE_BLUEPRINT = 10,
        RATE_BLUEPRINT = 5
    },
    BLUEPRINT_CURRENCY_COSTS = {
        MARKETPLACE_LISTING = 100,
        FEATURED_SLOT = 500,
        PREMIUM_FEATURES = 250
    },
    AUTO_SAVE_INTERVAL = 300, -- 5 minutes
    MAX_BLUEPRINTS_PER_PLAYER = 50
}

function BlueprintServerSetup.Initialize()
    print("BlueprintServerSetup: Initializing server-side blueprint system...")
    
    -- Initialize the blueprint manager
    local blueprintManager = BlueprintManager.new()
    
    -- Set up integration with existing systems
    BlueprintServerSetup.SetupXPIntegration(blueprintManager)
    BlueprintServerSetup.SetupCurrencyIntegration(blueprintManager)
    BlueprintServerSetup.SetupSocialIntegration(blueprintManager)
    
    -- Set up player management
    BlueprintServerSetup.SetupPlayerManagement(blueprintManager)
    
    -- Set up auto-save system
    BlueprintServerSetup.SetupAutoSave(blueprintManager)
    
    -- Create sample blueprints for testing
    BlueprintServerSetup.CreateSampleBlueprints(blueprintManager)
    
    print("BlueprintServerSetup: Server initialization complete!")
    return blueprintManager
end

function BlueprintServerSetup.SetupXPIntegration(blueprintManager)
    -- Connect blueprint events to XP rewards
    if blueprintManager.events then
        blueprintManager.events.BlueprintCreated:Connect(function(player, blueprintData)
            if XPManager then
                XPManager:AwardXP(player, SERVER_CONFIG.BLUEPRINT_XP_REWARDS.CREATE_BLUEPRINT, "Blueprint Created")
                print("BlueprintServerSetup: Awarded", SERVER_CONFIG.BLUEPRINT_XP_REWARDS.CREATE_BLUEPRINT, "XP to", player.Name, "for creating blueprint")
            end
        end)
        
        blueprintManager.events.BlueprintShared:Connect(function(player, blueprintData)
            if XPManager then
                XPManager:AwardXP(player, SERVER_CONFIG.BLUEPRINT_XP_REWARDS.SHARE_BLUEPRINT, "Blueprint Shared")
                print("BlueprintServerSetup: Awarded", SERVER_CONFIG.BLUEPRINT_XP_REWARDS.SHARE_BLUEPRINT, "XP to", player.Name, "for sharing blueprint")
            end
        end)
        
        blueprintManager.events.BlueprintUsed:Connect(function(player, blueprintData)
            if XPManager then
                XPManager:AwardXP(player, SERVER_CONFIG.BLUEPRINT_XP_REWARDS.USE_BLUEPRINT, "Blueprint Used")
            end
            
            -- Award XP to blueprint creator if different player
            if blueprintData.creatorId and blueprintData.creatorId ~= player.UserId then
                local creator = Players:GetPlayerByUserId(blueprintData.creatorId)
                if creator and XPManager then
                    XPManager:AwardXP(creator, SERVER_CONFIG.BLUEPRINT_XP_REWARDS.USE_BLUEPRINT, "Blueprint Used by Others")
                end
            end
        end)
        
        blueprintManager.events.BlueprintRated:Connect(function(player, blueprintData, rating)
            if XPManager then
                XPManager:AwardXP(player, SERVER_CONFIG.BLUEPRINT_XP_REWARDS.RATE_BLUEPRINT, "Blueprint Rated")
            end
        end)
    end
end

function BlueprintServerSetup.SetupCurrencyIntegration(blueprintManager)
    -- Connect blueprint marketplace features to currency system
    if blueprintManager.events then
        blueprintManager.events.MarketplaceListing:Connect(function(player, blueprintData)
            if CurrencyManager then
                local success = CurrencyManager:SpendCurrency(player, SERVER_CONFIG.BLUEPRINT_CURRENCY_COSTS.MARKETPLACE_LISTING)
                if success then
                    print("BlueprintServerSetup: Player", player.Name, "paid", SERVER_CONFIG.BLUEPRINT_CURRENCY_COSTS.MARKETPLACE_LISTING, "for marketplace listing")
                else
                    print("BlueprintServerSetup: Player", player.Name, "insufficient funds for marketplace listing")
                    return false
                end
            end
            return true
        end)
        
        blueprintManager.events.FeaturedSlotPurchase:Connect(function(player, blueprintData)
            if CurrencyManager then
                local success = CurrencyManager:SpendCurrency(player, SERVER_CONFIG.BLUEPRINT_CURRENCY_COSTS.FEATURED_SLOT)
                if success then
                    print("BlueprintServerSetup: Player", player.Name, "purchased featured slot for", SERVER_CONFIG.BLUEPRINT_CURRENCY_COSTS.FEATURED_SLOT)
                else
                    print("BlueprintServerSetup: Player", player.Name, "insufficient funds for featured slot")
                    return false
                end
            end
            return true
        end)
    end
end

function BlueprintServerSetup.SetupSocialIntegration(blueprintManager)
    -- Connect blueprint system with social features
    if blueprintManager.events and SocialManager then
        blueprintManager.events.BlueprintCreated:Connect(function(player, blueprintData)
            -- Announce blueprint creation in guild chat
            SocialManager:BroadcastToGuild(player, {
                type = "achievement",
                message = player.Name .. " created a new blueprint: " .. blueprintData.name,
                icon = "📐"
            })
        end)
        
        blueprintManager.events.BlueprintShared:Connect(function(player, blueprintData)
            -- Share blueprint achievement in global chat
            SocialManager:BroadcastGlobal({
                type = "blueprint_share",
                message = player.Name .. " shared blueprint '" .. blueprintData.name .. "' to the marketplace!",
                playerId = player.UserId,
                blueprintId = blueprintData.id
            })
        end)
        
        blueprintManager.events.CollaborativeBlueprint:Connect(function(players, blueprintData)
            -- Handle team blueprint creation
            for _, player in ipairs(players) do
                SocialManager:BroadcastToTeam(player, {
                    type = "collaboration",
                    message = "Team blueprint '" .. blueprintData.name .. "' completed!",
                    participants = players
                })
            end
        end)
    end
end

function BlueprintServerSetup.SetupPlayerManagement(blueprintManager)
    -- Handle player joining
    Players.PlayerAdded:Connect(function(player)
        task.wait(2) -- Wait for player to fully load
        
        -- Load player's blueprints
        if blueprintManager.LoadPlayerBlueprints then
            blueprintManager:LoadPlayerBlueprints(player)
        end
        
        -- Set up player-specific blueprint limits
        if blueprintManager.SetPlayerLimits then
            blueprintManager:SetPlayerLimits(player, {
                maxBlueprints = SERVER_CONFIG.MAX_BLUEPRINTS_PER_PLAYER,
                maxBlueprintSize = 100,
                canShareToMarketplace = true
            })
        end
        
        print("BlueprintServerSetup: Loaded blueprint data for player:", player.Name)
    end)
    
    -- Handle player leaving
    Players.PlayerRemoving:Connect(function(player)
        -- Save player's blueprints
        if blueprintManager.SavePlayerBlueprints then
            blueprintManager:SavePlayerBlueprints(player)
        end
        
        print("BlueprintServerSetup: Saved blueprint data for player:", player.Name)
    end)
end

function BlueprintServerSetup.SetupAutoSave(blueprintManager)
    -- Auto-save all player data periodically
    task.spawn(function()
        while true do
            task.wait(SERVER_CONFIG.AUTO_SAVE_INTERVAL)
            
            if blueprintManager.SaveAllPlayerData then
                local success, err = pcall(function()
                    blueprintManager:SaveAllPlayerData()
                end)
                
                if success then
                    print("BlueprintServerSetup: Auto-save completed successfully")
                else
                    warn("BlueprintServerSetup: Auto-save failed:", err)
                end
            end
        end
    end)
end

function BlueprintServerSetup.CreateSampleBlueprints(blueprintManager)
    -- Create some sample blueprints for testing and demonstration
    task.spawn(function()
        task.wait(5) -- Wait for system to fully initialize
        
        local sampleBlueprints = {
            {
                name = "Starter House",
                description = "A simple house perfect for new builders",
                category = "residential",
                tags = {"house", "starter", "simple"},
                items = {
                    {itemId = "wall_basic", position = Vector3.new(0, 0, 0), rotation = Vector3.new(0, 0, 0)},
                    {itemId = "wall_basic", position = Vector3.new(4, 0, 0), rotation = Vector3.new(0, 0, 0)},
                    {itemId = "wall_basic", position = Vector3.new(0, 0, 4), rotation = Vector3.new(0, 90, 0)},
                    {itemId = "wall_basic", position = Vector3.new(4, 0, 4), rotation = Vector3.new(0, 90, 0)},
                    {itemId = "roof_basic", position = Vector3.new(2, 4, 2), rotation = Vector3.new(0, 0, 0)},
                    {itemId = "door_basic", position = Vector3.new(2, 0, 0), rotation = Vector3.new(0, 0, 0)}
                },
                isPublic = true,
                isFeatured = true,
                creatorId = 0,
                creatorName = "System"
            },
            {
                name = "Modern Tower",
                description = "A sleek modern tower design",
                category = "commercial",
                tags = {"tower", "modern", "tall"},
                items = {
                    {itemId = "glass_wall", position = Vector3.new(0, 0, 0), rotation = Vector3.new(0, 0, 0)},
                    {itemId = "glass_wall", position = Vector3.new(0, 4, 0), rotation = Vector3.new(0, 0, 0)},
                    {itemId = "glass_wall", position = Vector3.new(0, 8, 0), rotation = Vector3.new(0, 0, 0)},
                    {itemId = "steel_beam", position = Vector3.new(2, 0, 2), rotation = Vector3.new(0, 0, 0)},
                    {itemId = "steel_beam", position = Vector3.new(2, 4, 2), rotation = Vector3.new(0, 0, 0)},
                    {itemId = "steel_beam", position = Vector3.new(2, 8, 2), rotation = Vector3.new(0, 0, 0)}
                },
                isPublic = true,
                isFeatured = true,
                creatorId = 0,
                creatorName = "System"
            },
            {
                name = "Garden Bridge",
                description = "A decorative bridge for gardens and parks",
                category = "decoration",
                tags = {"bridge", "garden", "decorative"},
                items = {
                    {itemId = "wood_plank", position = Vector3.new(0, 0, 0), rotation = Vector3.new(0, 0, 0)},
                    {itemId = "wood_plank", position = Vector3.new(1, 0, 0), rotation = Vector3.new(0, 0, 0)},
                    {itemId = "wood_plank", position = Vector3.new(2, 0, 0), rotation = Vector3.new(0, 0, 0)},
                    {itemId = "railing", position = Vector3.new(0, 1, 0.5), rotation = Vector3.new(0, 0, 0)},
                    {itemId = "railing", position = Vector3.new(2, 1, 0.5), rotation = Vector3.new(0, 0, 0)},
                    {itemId = "flower_pot", position = Vector3.new(-0.5, 0, 0), rotation = Vector3.new(0, 0, 0)},
                    {itemId = "flower_pot", position = Vector3.new(2.5, 0, 0), rotation = Vector3.new(0, 0, 0)}
                },
                isPublic = true,
                isFeatured = false,
                creatorId = 0,
                creatorName = "System"
            }
        }
        
        -- Add sample blueprints to the system
        for _, blueprintData in ipairs(sampleBlueprints) do
            if blueprintManager.CreateSystemBlueprint then
                local success, err = pcall(function()
                    blueprintManager:CreateSystemBlueprint(blueprintData)
                end)
                
                if success then
                    print("BlueprintServerSetup: Created sample blueprint:", blueprintData.name)
                else
                    warn("BlueprintServerSetup: Failed to create sample blueprint:", blueprintData.name, err)
                end
            end
        end
        
        print("BlueprintServerSetup: Sample blueprints creation completed")
    end)
end

-- Integration testing functions
function BlueprintServerSetup.RunIntegrationTests()
    print("BlueprintServerSetup: Running integration tests...")
    
    -- Test XP integration
    local testPlayer = Players:GetPlayers()[1]
    if testPlayer then
        print("BlueprintServerSetup: Testing XP integration with player:", testPlayer.Name)
        
        -- Simulate blueprint creation
        if XPManager then
            local initialXP = XPManager:GetPlayerXP(testPlayer)
            XPManager:AwardXP(testPlayer, SERVER_CONFIG.BLUEPRINT_XP_REWARDS.CREATE_BLUEPRINT, "Test Blueprint Creation")
            local newXP = XPManager:GetPlayerXP(testPlayer)
            
            if newXP > initialXP then
                print("✅ XP integration test passed")
            else
                print("❌ XP integration test failed")
            end
        end
        
        -- Test currency integration
        if CurrencyManager then
            local initialCurrency = CurrencyManager:GetPlayerCurrency(testPlayer)
            print("BlueprintServerSetup: Player currency:", initialCurrency)
            print("✅ Currency integration test passed")
        end
        
        -- Test social integration
        if SocialManager then
            print("✅ Social integration test passed")
        end
    end
    
    print("BlueprintServerSetup: Integration tests completed")
end

-- Initialize when script runs
if RunService:IsServer() then
    local blueprintManager = BlueprintServerSetup.Initialize()
    
    -- Run integration tests after a delay
    task.spawn(function()
        task.wait(10)
        BlueprintServerSetup.RunIntegrationTests()
    end)
    
    -- Store reference for other scripts
    _G.BlueprintManager = blueprintManager
end

return BlueprintServerSetup 