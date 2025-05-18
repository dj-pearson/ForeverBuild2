-- Add a function to explicitly add an item to a player's inventory
function ItemPurchaseHandler:AddToInventory(player, itemId, amount)
    if not player or typeof(player) ~= "Instance" or not player:IsA("Player") then
        warn("[ItemPurchaseHandler] AddToInventory - Invalid player")
        return false
    end
    
    if not itemId or typeof(itemId) ~= "string" then
        warn("[ItemPurchaseHandler] AddToInventory - Invalid itemId")
        return false
    end
    
    amount = amount or 1
    
    -- Get player data
    local playerData = self:GetPlayerData(player)
    if not playerData then
        warn("[ItemPurchaseHandler] AddToInventory - No player data for", player.Name)
        return false
    end
    
    -- Add item to inventory
    if not playerData.inventory then
        playerData.inventory = {}
    end
    
    -- Check if item exists in inventory, if so increment quantity
    local itemExists = false
    for _, item in pairs(playerData.inventory) do
        if item.name == itemId or item.id == itemId then
            -- If dictionary-style has quantity
            if item.quantity then
                item.quantity = item.quantity + amount
            end
            itemExists = true
            break
        end
    end
    
    -- If item doesn't exist, add it
    if not itemExists then
        -- Create a new item
        local newItem = {
            id = itemId,
            name = itemId,
            quantity = amount
        }
        
        -- Add to inventory
        table.insert(playerData.inventory, newItem)
    end
    
    -- Save player data
    self:SavePlayerData(player)
    
    -- Notify client of item added
    local remotes = self.remotes or ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local addToInventoryEvent = remotes:FindFirstChild("AddToInventory")
        if addToInventoryEvent then
            addToInventoryEvent:FireClient(player, {
                name = itemId,
                quantity = amount
            })
        end
    end
    
    print("[ItemPurchaseHandler] Added", amount, "x", itemId, "to", player.Name, "'s inventory")
    return true
end

-- Add a function to explicitly remove an item from a player's inventory
function ItemPurchaseHandler:RemoveFromInventory(player, itemId, amount)
    if not player or typeof(player) ~= "Instance" or not player:IsA("Player") then
        warn("[ItemPurchaseHandler] RemoveFromInventory - Invalid player")
        return false
    end
    
    if not itemId or typeof(itemId) ~= "string" then
        warn("[ItemPurchaseHandler] RemoveFromInventory - Invalid itemId")
        return false
    end
    
    amount = amount or 1
    
    -- Get player data
    local playerData = self:GetPlayerData(player)
    if not playerData then
        warn("[ItemPurchaseHandler] RemoveFromInventory - No player data for", player.Name)
        return false
    end
    
    -- Check if inventory exists
    if not playerData.inventory then
        warn("[ItemPurchaseHandler] RemoveFromInventory - Player has no inventory")
        return false
    end
    
    -- Find the item to remove
    local itemIndex = nil
    local foundItem = nil
    
    for i, item in pairs(playerData.inventory) do
        if item.name == itemId or item.id == itemId then
            itemIndex = i
            foundItem = item
            break
        end
    end
    
    if not foundItem then
        warn("[ItemPurchaseHandler] RemoveFromInventory - Item", itemId, "not found in inventory")
        return false
    end
    
    -- Handle quantity if dictionary style inventory
    if foundItem.quantity then
        if foundItem.quantity <= amount then
            -- Remove the entire item
            table.remove(playerData.inventory, itemIndex)
        else
            -- Reduce quantity
            foundItem.quantity = foundItem.quantity - amount
        end
    else
        -- Array-style inventory, just remove the item
        table.remove(playerData.inventory, itemIndex)
    end
    
    -- Save player data
    self:SavePlayerData(player)
    
    print("[ItemPurchaseHandler] Removed", amount, "x", itemId, "from", player.Name, "'s inventory")
    return true
end 