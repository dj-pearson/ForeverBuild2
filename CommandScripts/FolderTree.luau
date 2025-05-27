local function printTree(obj, indent)
    indent = indent or ""
    
    -- Check if current object is a Folder or Model
    if obj.ClassName == "Folder" then
        print(indent .. obj.Name .. " (" .. obj.ClassName .. ")")
        -- Continue traversing children of folders
        for _, child in ipairs(obj:GetChildren()) do
            printTree(child, indent .. "  ")
        end
    elseif obj.ClassName == "Model" then
        print(indent .. obj.Name .. " (" .. obj.ClassName .. ")")
        -- Don't traverse children of models (stop here)
    else
        -- For other objects, don't print but continue searching for folders/models
        for _, child in ipairs(obj:GetChildren()) do
            printTree(child, indent)
        end
    end
end

-- Print structure for all major services
local services = {
    game:GetService("Workspace"),
    game:GetService("ReplicatedStorage"),
    game:GetService("ServerScriptService"),
    game:GetService("StarterGui"),
    game:GetService("StarterPlayer"),
    game:GetService("ServerStorage"),
    game:GetService("Lighting"),
    game:GetService("SoundService"),
    game:GetService("ReplicatedFirst")
}

for _, service in ipairs(services) do
    print("\n=== " .. service.Name .. " ===")
    printTree(service)
end