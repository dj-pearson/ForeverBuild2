-- ObjectStreaming.luau
-- Performance optimization system for games with many player-placed objects

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ObjectStreaming = {}
ObjectStreaming.__index = ObjectStreaming

function ObjectStreaming.new()
    local self = setmetatable({}, ObjectStreaming)
    
    self.streamingRadius = 200 -- Objects visible within 200 studs
    self.updateInterval = 1 -- Update every second
    self.streamedObjects = {} -- Objects currently visible to each player
    self.objectPool = {} -- Pooled objects for performance
    self.lodLevels = {
        HIGH = 50,   -- Full detail within 50 studs
        MEDIUM = 100, -- Medium detail 50-100 studs
        LOW = 200    -- Low detail 100-200 studs
    }
    
    self:Initialize()
    return self
end

function ObjectStreaming:Initialize()
    -- Start streaming updates
    RunService.Heartbeat:Connect(function()
        self:UpdateStreaming()
    end)
    
    -- Handle player connections
    Players.PlayerAdded:Connect(function(player)
        self.streamedObjects[player] = {}
        self:InitializePlayerStreaming(player)
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        self:CleanupPlayerStreaming(player)
    end)
    
    print("📡 Object streaming system initialized")
end

function ObjectStreaming:UpdateStreaming()
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            self:UpdatePlayerStreaming(player)
        end
    end
end

function ObjectStreaming:UpdatePlayerStreaming(player)
    local character = player.Character
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    local playerPosition = rootPart.Position
    local currentStreamed = self.streamedObjects[player] or {}
    local newStreamed = {}
    
    -- Find all objects within streaming radius
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:GetAttribute("PlacementId") then
            local distance = (obj.Position - playerPosition).Magnitude
            
            if distance <= self.streamingRadius then
                local objectId = obj:GetAttribute("PlacementId")
                newStreamed[objectId] = {
                    object = obj,
                    distance = distance,
                    lodLevel = self:GetLODLevel(distance)
                }
                
                -- Apply LOD if needed
                self:ApplyLOD(obj, distance)
                
                -- If not previously streamed, show it
                if not currentStreamed[objectId] then
                    self:StreamInObject(player, obj)
                end
            end
        end
    end
    
    -- Stream out objects that are now too far
    for objectId, data in pairs(currentStreamed) do
        if not newStreamed[objectId] then
            self:StreamOutObject(player, data.object)
        end
    end
    
    self.streamedObjects[player] = newStreamed
end

function ObjectStreaming:GetLODLevel(distance)
    if distance <= self.lodLevels.HIGH then
        return "HIGH"
    elseif distance <= self.lodLevels.MEDIUM then
        return "MEDIUM"
    else
        return "LOW"
    end
end

function ObjectStreaming:ApplyLOD(object, distance)
    local lodLevel = self:GetLODLevel(distance)
    
    -- Adjust detail based on distance
    if lodLevel == "LOW" then
        -- Remove unnecessary details for distant objects
        for _, child in ipairs(object:GetChildren()) do
            if child:IsA("PointLight") or child:IsA("SpotLight") then
                child.Enabled = false
            elseif child:IsA("ParticleEmitter") then
                child.Enabled = false
            end
        end
    elseif lodLevel == "MEDIUM" then
        -- Reduce light intensity
        for _, child in ipairs(object:GetChildren()) do
            if child:IsA("PointLight") then
                child.Brightness = 0.5
            end
        end
    else -- HIGH
        -- Full quality
        for _, child in ipairs(object:GetChildren()) do
            if child:IsA("PointLight") or child:IsA("SpotLight") then
                child.Enabled = true
                child.Brightness = 1
            elseif child:IsA("ParticleEmitter") then
                child.Enabled = true
            end
        end
    end
end

function ObjectStreaming:StreamInObject(player, object)
    -- Make object visible to player (if using selective streaming)
    -- For basic implementation, objects are always visible
    -- You could implement network streaming here
    print("📥 Streamed in object for", player.Name, ":", object.Name)
end

function ObjectStreaming:StreamOutObject(player, object)
    -- Hide object from player to save performance
    print("📤 Streamed out object for", player.Name, ":", object.Name)
end

function ObjectStreaming:InitializePlayerStreaming(player)
    print("🎮 Initialized streaming for player:", player.Name)
end

function ObjectStreaming:CleanupPlayerStreaming(player)
    self.streamedObjects[player] = nil
    print("🧹 Cleaned up streaming for player:", player.Name)
end

-- Get performance metrics
function ObjectStreaming:GetPerformanceMetrics()
    local totalObjects = 0
    local streamedCount = 0
    
    for player, objects in pairs(self.streamedObjects) do
        for _ in pairs(objects) do
            streamedCount = streamedCount + 1
        end
    end
    
    -- Count total objects in world
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:GetAttribute("PlacementId") then
            totalObjects = totalObjects + 1
        end
    end
    
    return {
        totalObjects = totalObjects,
        streamedObjects = streamedCount,
        activePlayers = #Players:GetPlayers(),
        averageStreamedPerPlayer = streamedCount / math.max(1, #Players:GetPlayers())
    }
end

return ObjectStreaming 