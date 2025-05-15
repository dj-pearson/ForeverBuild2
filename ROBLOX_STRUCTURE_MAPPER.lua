-- ROBLOX_STRUCTURE_MAPPER.lua
-- This script displays the current game structure in Roblox Studio
-- Run this script in the Command Bar of Roblox Studio

-- Define which services to map
local servicesToMap = {
    game.ReplicatedStorage,
    game.ServerScriptService,
    game.StarterGui,
    game.StarterPlayer,
    game.Workspace,
    game.Players.LocalPlayer and game.Players.LocalPlayer.PlayerScripts
}

-- Function to recursively print tree structure
local function printTree(instance, indent, maxDepth, currentDepth)
    if not instance then return end
    if currentDepth > maxDepth then return end
    
    local className = instance.ClassName
    local fullName = instance:GetFullName()
    
    -- Print the current instance with indentation
    print(string.rep("  ", indent) .. "├─ " .. instance.Name .. " [" .. className .. "]")
    
    -- Recursively print children
    for _, child in pairs(instance:GetChildren()) do
        printTree(child, indent + 1, maxDepth, currentDepth + 1)
    end
end

-- Print header
print("\n========== ROBLOX GAME STRUCTURE ==========")
print("Mapped from your ForeverBuild project")
print("Date: " .. os.date("%Y-%m-%d %H:%M:%S"))
print("==========================================\n")

-- Map each service with limited depth
for _, service in ipairs(servicesToMap) do
    if service then
        print("SERVICE: " .. service:GetFullName())
        for _, child in pairs(service:GetChildren()) do
            printTree(child, 1, 3, 1)
        end
        print("") -- Empty line between services
    end
end

-- Print player scripts specifically with more detail
if game.Players.LocalPlayer then
    local playerScripts = game.Players.LocalPlayer.PlayerScripts
    print("DETAILED PLAYER SCRIPTS STRUCTURE:")
    print("Player: " .. game.Players.LocalPlayer.Name)
    for _, child in pairs(playerScripts:GetChildren()) do
        printTree(child, 1, 5, 1) -- Show more depth for player scripts
    end
end

print("\nMapping complete! Use this structure for accurate pathing in your scripts.")
