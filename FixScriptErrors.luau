-- FixScriptErrors.luau
-- Run this script in Roblox Studio to fix problematic scripts with syntax errors

local function fixScriptErrors()
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
        end
    end
    
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

-- Run the fix function
fixScriptErrors() 