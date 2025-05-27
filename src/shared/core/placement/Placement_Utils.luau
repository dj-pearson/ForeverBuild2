local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local PlacementUtils = {}

-- Helper: Recursively search for a template in a folder and its subfolders
local function findTemplateRecursive(folder, itemId)
    for _, child in ipairs(folder:GetChildren()) do
        -- PRIMARY: Check for exact ItemId attribute match (preserves numeric IDs)
        local childItemId = child:GetAttribute("ItemId")
        if childItemId == itemId then
            return child
        end
        
        -- SECONDARY: Check lowercase itemId for compatibility  
        local childItemIdLower = child:GetAttribute("itemId")
        if childItemIdLower == itemId then
            return child
        end
        
        -- TERTIARY: Handle string/number conversion for cross-compatibility
        if type(itemId) == "number" and type(childItemId) == "string" then
            if tonumber(childItemId) == itemId then
                return child
            end
        elseif type(itemId) == "string" and type(childItemId) == "number" then
            if tostring(childItemId) == itemId then
                return child
            end
        end
        
        -- QUATERNARY: Same for lowercase itemId
        if type(itemId) == "number" and type(childItemIdLower) == "string" then
            if tonumber(childItemIdLower) == itemId then
                return child
            end
        elseif type(itemId) == "string" and type(childItemIdLower) == "number" then
            if tostring(childItemIdLower) == itemId then
                return child
            end
        end
        
        -- FALLBACK: Name matching for legacy compatibility
        if child.Name == tostring(itemId) then
            return child
        end
        
        -- Recursively search subfolders
        if child:IsA("Folder") then
            local found = findTemplateRecursive(child, itemId)
            if found then return found end
        end
    end
    return nil
end

-- Get an item template from ReplicatedStorage or other sources
function PlacementUtils.GetItemTemplate(pm_instance, itemId)
    print("PlacementUtils: Getting template for item:", itemId)
    
    if RunService:IsClient() then
        -- Client-side: Enhanced template search
        print("PlacementUtils (Client): Searching for template:", itemId)
        
        -- 1. First check ReplicatedStorage.ItemTemplates (for basic parts)
        local templatesFolder = ReplicatedStorage:FindFirstChild("ItemTemplates")
        if templatesFolder then
            local template = templatesFolder:FindFirstChild(itemId)
            if template then
                print("PlacementUtils (Client): Found template in ReplicatedStorage.ItemTemplates:", itemId)
                return template
            end
            -- Try normalized name on client too
            local normalizedItemIdClient = itemId:gsub(" ", "_")
            if normalizedItemIdClient ~= itemId then
                template = templatesFolder:FindFirstChild(normalizedItemIdClient)
                if template then
                    print("PlacementUtils (Client): Found normalized template in ReplicatedStorage.ItemTemplates:", normalizedItemIdClient)
                    return template
                end
            end
        end
        
        -- 2. Check Workspace.Items (for actual models like Torch)
        local workspaceItems = Workspace:FindFirstChild("Items")
        if workspaceItems then
            local wsTemplate = findTemplateRecursive(workspaceItems, itemId)
            if wsTemplate then
                print("PlacementUtils (Client): Found template in Workspace.Items (recursive):", itemId)
                return wsTemplate
            end
        end
        
        -- 3. Check ServerStorage.Items (for backup/duplicates)
        local serverItems = game:GetService("ServerStorage"):FindFirstChild("Items")
        if serverItems then
            local ssTemplate = findTemplateRecursive(serverItems, itemId)
            if ssTemplate then
                print("PlacementUtils (Client): Found template in ServerStorage.Items (recursive):", itemId)
                return ssTemplate
            end
        end
        
        -- 4. Try mapped numeric ID if nothing found
        if pm_instance.itemTemplateMap and pm_instance.itemTemplateMap[itemId] then
            local mappedTemplateName = pm_instance.itemTemplateMap[itemId]
            print("PlacementUtils (Client): Mapped numeric ID", itemId, "to template name:", mappedTemplateName)
            if templatesFolder then -- Re-check templatesFolder as it might have been nil
                local mappedTemplate = templatesFolder:FindFirstChild(mappedTemplateName)
                if mappedTemplate then
                     print("PlacementUtils (Client): Found mapped template in ReplicatedStorage.ItemTemplates:", mappedTemplateName)
                    return mappedTemplate
                end
            end
        end

        warn("PlacementUtils (Client): Template not found anywhere for:", itemId)
        return nil
    end

    -- Server-side logic (original broader search)
    -- 1. Check ServerStorage.Items (recursively)
    local serverItems = game:GetService("ServerStorage"):FindFirstChild("Items")
    if serverItems then
        local ssTemplate = findTemplateRecursive(serverItems, itemId)
        if ssTemplate then
            print("PlacementUtils: Found template in ServerStorage.Items (recursive):", itemId)
            return ssTemplate
        end
    end

    -- 2. Check Workspace.Items (recursively)
    local workspaceItems = game:GetService("Workspace"):FindFirstChild("Items")
    if workspaceItems then
        local wsTemplate = findTemplateRecursive(workspaceItems, itemId)
        if wsTemplate then
            print("PlacementUtils: Found template in Workspace.Items (recursive):", itemId)
            return wsTemplate
        end
    end

    -- 3. Fallback to ReplicatedStorage.ItemTemplates (initial check)
    local initialTemplatesFolder = ReplicatedStorage:FindFirstChild("ItemTemplates")
    if initialTemplatesFolder then
        local template = initialTemplatesFolder:FindFirstChild(itemId)
        if template then
            print("PlacementUtils: Found template in ReplicatedStorage.ItemTemplates (initial check):", itemId)
            return template
        end
    end
    
    -- Check if this is a numeric item ID that needs to be mapped to a template name
    if pm_instance.itemTemplateMap and pm_instance.itemTemplateMap[itemId] then
        local mappedTemplateName = pm_instance.itemTemplateMap[itemId]
        print("PlacementUtils: Mapped numeric ID", itemId, "to template name:", mappedTemplateName)
        itemId = mappedTemplateName -- Update itemId to the mapped name for further checks
    end
    
    -- Normalize the itemId (replace spaces with underscores)
    local normalizedItemId = itemId:gsub(" ", "_")
    
    local currentItemTemplates = ReplicatedStorage:FindFirstChild("ItemTemplates")
    if not currentItemTemplates then
        if RunService:IsServer() then
            print("PlacementUtils: ItemTemplates folder not found, creating it")
            currentItemTemplates = Instance.new("Folder")
            currentItemTemplates.Name = "ItemTemplates"
            currentItemTemplates.Parent = ReplicatedStorage
            
            local basicTemplates = {
                { name = "Grass_Cube", color = "Bright green", material = "Grass" },
                { name = "Stone_Cube", color = "Medium stone grey", material = "Slate" },
                { name = "Wood_Plank", color = "Brown", material = "Wood" },
                { name = "Wood_Cube", color = "Brown", material = "Wood" },
                { name = "Brick_Cube", color = "Brick red", material = "Brick" },
                { name = "Water_Cube", color = "Bright blue", material = "Water", transparency = 0.3 },
                { name = "Glass_Cube", color = "Toothpaste", material = "Glass", transparency = 0.5 }
            }
            
            for _, info in ipairs(basicTemplates) do
                local part = Instance.new("Part")
                part.Name = info.name
                part.Size = Vector3.new(2, 2, 2)
                part.Anchored = true
                part.CanCollide = true
                part.BrickColor = BrickColor.new(info.color)
                part.Material = Enum.Material[info.material]
                if info.transparency then
                    part.Transparency = info.transparency
                end
                part.Parent = currentItemTemplates
                print("PlacementUtils: Created template:", info.name)
            end
        else
            warn("PlacementUtils: ItemTemplates folder not found")
            return nil
        end
    end
    
    print("PlacementUtils: Available templates in ItemTemplates folder:")
    for _, templateInLoop in ipairs(currentItemTemplates:GetChildren()) do
        print("  -", templateInLoop.Name)
    end
    
    local template = currentItemTemplates:FindFirstChild(normalizedItemId)
    if template then
        print("PlacementUtils: Found exact template match:", normalizedItemId)
        return template
    end
    
    if normalizedItemId ~= itemId then
        template = currentItemTemplates:FindFirstChild(itemId)
        if template then
            print("PlacementUtils: Found template using original itemId:", itemId)
            return template
        end
    end
    
    if normalizedItemId == "Wood_Cube" then
        local woodPlank = currentItemTemplates:FindFirstChild("Wood_Plank")
        if woodPlank then
            print("PlacementUtils: Creating Wood_Cube from Wood_Plank")
            local woodCube = woodPlank:Clone()
            woodCube.Name = "Wood_Cube"
            woodCube.Parent = currentItemTemplates
            return woodCube
        end
    end
    
    local tryWithCube = normalizedItemId
    if not normalizedItemId:lower():find("_cube$") then
        tryWithCube = normalizedItemId .. "_Cube"
    end
    
    template = currentItemTemplates:FindFirstChild(tryWithCube)
    if template then
        print("PlacementUtils: Found template with _Cube suffix:", tryWithCube)
        return template
    end
    
    if normalizedItemId:lower():find("_cube$") then
        local tryWithoutCube = normalizedItemId:gsub("_Cube$", ""):gsub("_cube$", "")
        template = currentItemTemplates:FindFirstChild(tryWithoutCube)
        if template then
            print("PlacementUtils: Found template without _Cube suffix:", tryWithoutCube)
            return template
        end
    end
    
    for _, potentialTemplate in ipairs(currentItemTemplates:GetChildren()) do
        if potentialTemplate.Name:lower() == normalizedItemId:lower() or
           potentialTemplate.Name:lower() == itemId:lower() then
            print("PlacementUtils: Found template using case-insensitive match:", potentialTemplate.Name)
            return potentialTemplate
        end
    end
    
    for _, potentialTemplate in ipairs(currentItemTemplates:GetChildren()) do
        if potentialTemplate.Name:lower():find(normalizedItemId:lower(), 1, true) or
           normalizedItemId:lower():find(potentialTemplate.Name:lower(), 1, true) then
            print("PlacementUtils: Found template with similar name:", potentialTemplate.Name)
            return potentialTemplate
        end
    end
    
    print("PlacementUtils: No template found for " .. normalizedItemId .. " - creating basic preview")
    local numericIdMatch = normalizedItemId:match("^item_(%d+)$")
    if numericIdMatch then
        print("PlacementUtils: ⚠️ Item appears to be a numeric ID (item_" .. numericIdMatch .. "). Consider adding it to the itemTemplateMap.")
    end
    
    local newTemplate = Instance.new("Part")
    newTemplate.Name = normalizedItemId
    newTemplate.Size = Vector3.new(2, 2, 2)
    newTemplate.Anchored = true
    newTemplate.CanCollide = true
    
    if normalizedItemId:lower():find("wood") then
        newTemplate.BrickColor = BrickColor.new("Brown")
        newTemplate.Material = Enum.Material.Wood
    elseif normalizedItemId:lower():find("grass") then
        newTemplate.BrickColor = BrickColor.new("Bright green")
        newTemplate.Material = Enum.Material.Grass
    elseif normalizedItemId:lower():find("stone") then
        newTemplate.BrickColor = BrickColor.new("Medium stone grey")
        newTemplate.Material = Enum.Material.Slate
    elseif normalizedItemId:lower():find("water") then
        newTemplate.BrickColor = BrickColor.new("Bright blue")
        newTemplate.Material = Enum.Material.Water
        newTemplate.Transparency = 0.3
    elseif normalizedItemId:lower():find("glass") then
        newTemplate.BrickColor = BrickColor.new("Toothpaste")
        newTemplate.Material = Enum.Material.Glass
        newTemplate.Transparency = 0.5
    elseif normalizedItemId:lower():find("brick") then
        newTemplate.BrickColor = BrickColor.new("Reddish brown")
        newTemplate.Material = Enum.Material.Brick
    else
        newTemplate.BrickColor = BrickColor.new("Medium stone grey")
        newTemplate.Material = Enum.Material.Concrete
    end
    
    newTemplate.Parent = currentItemTemplates
    print("PlacementUtils: Created new template:", normalizedItemId)
    return newTemplate
end

-- Find an item by its instanceId
function PlacementUtils.FindItemByInstanceId(pm_instance, instanceId)
    if not instanceId then
        warn("PlacementUtils:FindItemByInstanceId called with nil instanceId")
        return nil
    end

    print(string.format("PlacementUtils:FindItemByInstanceId: Looking for item with instanceId '%s'", instanceId))

    local possibleFolders = {}
    local worldItems = Workspace:FindFirstChild("World_Items")
    if worldItems and worldItems:FindFirstChild("Placed") then
        table.insert(possibleFolders, worldItems.Placed)
    end
    
    if pm_instance.placedFolder then
        if not worldItems or pm_instance.placedFolder ~= worldItems.Placed then
            table.insert(possibleFolders, pm_instance.placedFolder)
        end
    end
    
    local legacyFolder = Workspace:FindFirstChild("PlacedItems")
    if legacyFolder then
        table.insert(possibleFolders, legacyFolder)
    end
    
    for _, folder in ipairs(possibleFolders) do
        local item = folder:FindFirstChild(instanceId)
        if item then
            print(string.format("PlacementUtils:FindItemByInstanceId: Found item by name: %s", item:GetFullName()))
            return item
        end
    end
    
    for _, folder in ipairs(possibleFolders) do
        for _, item in ipairs(folder:GetChildren()) do
            local itemInstanceId = item:GetAttribute("instanceId")
            if itemInstanceId and itemInstanceId == instanceId then
                print(string.format("PlacementUtils:FindItemByInstanceId: Found item by instanceId attribute: %s", item:GetFullName()))
                return item
            end
        end
    end
    
    for _, folder in ipairs(possibleFolders) do
        for _, item in ipairs(folder:GetChildren()) do
            local uniqueId = item:GetAttribute("UniqueItemId")
            if uniqueId and tostring(uniqueId) == instanceId then
                print(string.format("PlacementUtils:FindItemByInstanceId: Found item by UniqueItemId attribute: %s", item:GetFullName()))
                return item
            end
        end
    end
    
    warn(string.format("PlacementUtils:FindItemByInstanceId: Item with instanceId '%s' not found", instanceId))
    return nil
end

-- Server: Get player data from appropriate manager
function PlacementUtils.GetPlayerData(pm_instance, player)
    if RunService:IsClient() then return nil end
    
    local ItemPurchaseHandler
    local success1, errorMsg1 = pcall(function()
        return require(game:GetService("ServerScriptService"):WaitForChild("server").ItemPurchaseHandler)
    end)
    
    if success1 then
        ItemPurchaseHandler = errorMsg1 
    else
        local serverScript = game:GetService("ServerScriptService"):FindFirstChild("server")
        if serverScript then
            local handler = serverScript:FindFirstChild("ItemPurchaseHandler")
            if handler then
                local success2, result2 = pcall(function() return require(handler) end)
                if success2 then ItemPurchaseHandler = result2 end
            end
        end
    end
    
    if ItemPurchaseHandler then
        if ItemPurchaseHandler.GetPlayerDataForPlacement then
            local getSuccess, result = pcall(function() return ItemPurchaseHandler:GetPlayerDataForPlacement(player) end)
            if getSuccess and result then
                print("PlacementUtils: Got player data using GetPlayerDataForPlacement")
                return result
            end
        end
        if ItemPurchaseHandler.GetPlayerData then
            local getSuccess, result = pcall(function() return ItemPurchaseHandler:GetPlayerData(player) end)
            if getSuccess and result then
                print("PlacementUtils: Got player data from ItemPurchaseHandler directly")
                return result
            end
        end
    end
    
    if pm_instance.shared and pm_instance.shared.ItemPurchaseHandler then
        local success, result = pcall(function() return pm_instance.shared.ItemPurchaseHandler:GetPlayerData(player) end)
        if success and result then
            print("PlacementUtils: Got player data from SharedModule.ItemPurchaseHandler")
            return result
        end
    end
    
    local InventoryManager = pm_instance.shared and pm_instance.shared.InventoryManager
    if InventoryManager and InventoryManager.GetPlayerData then
        local success, result = pcall(function() return InventoryManager:GetPlayerData(player) end)
        if success and result then
            print("PlacementUtils: Got player data from InventoryManager")
            return result
        end
    end
    
    if player:FindFirstChild("PlayerData") and player.PlayerData:FindFirstChild("Inventory") then
        print("PlacementUtils: Using PlayerData.Inventory directly")
        return { inventory = player.PlayerData.Inventory.Value }
    end
    
    warn("PlacementUtils: Could not find a way to get player data - using mock data for testing")
    local mockInventory = {}
    local templates = ReplicatedStorage:FindFirstChild("ItemTemplates")
    if templates then
        for _, template in ipairs(templates:GetChildren()) do
            table.insert(mockInventory, { id = template.Name, name = template.Name, count = 10 })
        end
    end
    for _, itemName in ipairs({"Grass_Cube", "Stone_Cube", "Wood_Plank", "Brick_Cube"}) do
        table.insert(mockInventory, { id = itemName, name = itemName, count = 5 })
    end
    return { inventory = mockInventory, mock = true }
end

-- Server: Remove an item from the player's inventory
function PlacementUtils.RemoveFromInventory(pm_instance, player, itemId, quantity)
    if RunService:IsClient() then return false end
    
    quantity = quantity or 1
    print("PlacementUtils: Attempting to remove", quantity, "x", itemId, "from inventory of", player.Name)
    
    local ItemPurchaseHandler = nil
    local success1, result1 = pcall(function() return require(game:GetService("ServerScriptService").server.ItemPurchaseHandler) end)
    if success1 then ItemPurchaseHandler = result1
    else
        local serverFolder = game:GetService("ServerScriptService"):FindFirstChild("server")
        if serverFolder then
            local itemPurchaseModule = serverFolder:FindFirstChild("ItemPurchaseHandler")
            if itemPurchaseModule then
                local success2, result2 = pcall(function() return require(itemPurchaseModule) end)
                if success2 then ItemPurchaseHandler = result2 end
            end
        end
        if not ItemPurchaseHandler then
            local success3, result3 = pcall(function() return require(game:GetService("ServerScriptService").server.ItemPurchaseHandler) end)
            if success3 then ItemPurchaseHandler = result3 end
        end
    end
    
    if ItemPurchaseHandler and ItemPurchaseHandler.RemoveFromInventory then
        local success, result = pcall(function() return ItemPurchaseHandler:RemoveFromInventory(player, itemId, quantity) end)
        if success and result then
            print("PlacementUtils: Successfully removed", quantity, "x", itemId, "using ItemPurchaseHandler directly")
            return true
        end
    end
    
    if pm_instance.shared and pm_instance.shared.ItemPurchaseHandler and pm_instance.shared.ItemPurchaseHandler.RemoveFromInventory then
        local success, result = pcall(function() return pm_instance.shared.ItemPurchaseHandler:RemoveFromInventory(player, itemId, quantity) end)
        if success and result then
            print("PlacementUtils: Successfully removed", quantity, "x", itemId, "using SharedModule.ItemPurchaseHandler")
            return true
        end
    end
    
    local InventoryManager = pm_instance.shared and pm_instance.shared.InventoryManager
    if not InventoryManager then
        local success, result = pcall(function() return require(ReplicatedStorage.shared.core.inventory.InventoryManager) end)
        if success then InventoryManager = result
        else warn("PlacementUtils: Failed to require InventoryManager from ReplicatedStorage.shared.core.inventory:", result) end
    end
    
    if InventoryManager and InventoryManager.RemoveItem then
        local success, result = pcall(function() return InventoryManager:RemoveItem(player, itemId, quantity) end)
        if success and result then
            print("PlacementUtils: Successfully removed", quantity, "x", itemId, "using InventoryManager")
            return true
        end
    end
    
    local playerData = PlacementUtils.GetPlayerData(pm_instance, player) -- Use self.GetPlayerData
    if playerData and playerData.inventory then
        local normalizedItemId = itemId:gsub(" ", "_")
        local found = false
        for i, item_in_inv in ipairs(playerData.inventory) do -- renamed 'item' to 'item_in_inv'
            if (item_in_inv.id and (item_in_inv.id == itemId or item_in_inv.id == normalizedItemId)) or
               (item_in_inv.name and (item_in_inv.name == itemId or item_in_inv.name == normalizedItemId)) then
                local currentCount = item_in_inv.quantity or item_in_inv.count or 1
                if currentCount <= quantity then
                    table.remove(playerData.inventory, i)
                else
                    if item_in_inv.quantity ~= nil then item_in_inv.quantity = currentCount - quantity
                    elseif item_in_inv.count ~= nil then item_in_inv.count = currentCount - quantity
                    end
                end
                found = true
                if ItemPurchaseHandler and ItemPurchaseHandler.SavePlayerData then
                    ItemPurchaseHandler:SavePlayerData(player, playerData)
                end
                break
            end
        end
        if found then
            local remotes_folder = ReplicatedStorage:FindFirstChild("Remotes") -- renamed 'remotes' to 'remotes_folder'
            if remotes_folder and remotes_folder:FindFirstChild("RemoveFromInventory") then
                pcall(function() remotes_folder.RemoveFromInventory:FireClient(player, itemId, 1) end)
            end
            return true
        end
    end
    
    local remotes_folder_fallback = ReplicatedStorage:FindFirstChild("Remotes") -- renamed 'remotes' to 'remotes_folder_fallback'
    if remotes_folder_fallback and remotes_folder_fallback:FindFirstChild("RemoveFromInventory") then
        pcall(function() remotes_folder_fallback.RemoveFromInventory:FireClient(player, itemId, 1) end)
        print("PlacementUtils: Sent RemoveFromInventory event to client")
        return true
    end
    
    warn("PlacementUtils: Failed to remove item from inventory")
    return false
end


-- Server: Get item data from Constants
function PlacementUtils.GetItemData(pm_instance, itemId)
    if not pm_instance.Constants then
        warn("PlacementUtils: Constants not available, creating fallback")
        pm_instance.Constants = { ITEMS = {} }
    end
    if not pm_instance.Constants.ITEMS then
        warn("PlacementUtils: Constants.ITEMS not available, creating fallback")
        pm_instance.Constants.ITEMS = {}
        local basicItems = {"Grass_Cube", "Stone_Cube", "Brick_Cube", "Wood_Cube", "Glass_Cube", "Water_Cube"}
        for _, itemName in ipairs(basicItems) do
            pm_instance.Constants.ITEMS[itemName] = {
                name = itemName,
                price = {INGAME = 10, ROBUX = 10},
                description = "A basic building block",
                tier = "BASIC",
                category = "Building"
            }
        end
    end
    
    local normalizedItemId = itemId:gsub(" ", "_")
    
    if pm_instance.Constants.ITEMS[itemId] then return pm_instance.Constants.ITEMS[itemId] end
    if normalizedItemId ~= itemId and pm_instance.Constants.ITEMS[normalizedItemId] then
        print("PlacementUtils: Found item using normalized ID:", normalizedItemId)
        return pm_instance.Constants.ITEMS[normalizedItemId]
    end
    
    for key, data in pairs(pm_instance.Constants.ITEMS) do
        if key:lower() == itemId:lower() or key:lower() == normalizedItemId:lower() then
            print("PlacementUtils: Found item using case-insensitive match:", key)
            return data
        end
    end
    
    local tryWithCube = normalizedItemId
    if not normalizedItemId:lower():find("_cube$") then
        tryWithCube = normalizedItemId .. "_Cube"
    end
    
    if pm_instance.Constants.ITEMS[tryWithCube] then
        print("PlacementUtils: Found item by adding _Cube suffix:", tryWithCube)
        return pm_instance.Constants.ITEMS[tryWithCube]
    end
    
    for key, data in pairs(pm_instance.Constants.ITEMS) do
        if key:lower() == tryWithCube:lower() then
            print("PlacementUtils: Found item using case-insensitive match with _Cube suffix:", key)
            return data
        end
    end
    
    print("PlacementUtils: Creating fallback item data for:", normalizedItemId)
    local newItemData = {
        name = normalizedItemId,
        price = {INGAME = 10, ROBUX = 10},
        description = "A building item",
        tier = "BASIC",
        category = "Building"
    }
    pm_instance.Constants.ITEMS[normalizedItemId] = newItemData
    return newItemData
end

return PlacementUtils 