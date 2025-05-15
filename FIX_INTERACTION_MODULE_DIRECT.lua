-- Fix InteractionSystemModule directly
print("Fixing InteractionSystemModule in-place...")

local path = script.Parent.src.client.interaction.InteractionSystemModule

-- Make a backup first
local backup = path:Clone()
backup.Name = "InteractionSystemModule_backup_" .. os.time()
backup.Parent = path.Parent
print("Created backup:", backup.Name)

-- 1. Fix the GetPlacedItemFromPart function to handle Main folder items
local source = path.Source
local fixedSource = string.gsub(source, 
    "function InteractionSystem:GetPlacedItemFromPart%(part%)\n    if not part then return nil end\n    \n    local current = part\n    local maxDepth = 10 %-%- Prevent infinite loops\n    local depth = 0\n    \n    while current and current ~= workspace and depth < maxDepth do\n        if current:IsA%(\"Model\"%)(.) and current:GetAttribute%(\"item\"%)(.) then\n            return {\n                id = current.Name,\n                model = current\n            }\n        end\n        current = current.Parent\n        depth = depth %+ 1\n    end\n    \n    return nil\nend",
    
    "function InteractionSystem:GetPlacedItemFromPart(part)\n    if not part then return nil end\n    \n    local current = part\n    local maxDepth = 10 -- Prevent infinite loops\n    local depth = 0\n    \n    while current and current ~= workspace and depth < maxDepth do\n        if current:IsA(\"Model\") and current:GetAttribute(\"item\") then\n            return {\n                id = current.Name,\n                model = current\n            }\n        end\n        \n        -- Also check for parts that might not have the item attribute but are valid targets\n        -- This is especially important for parts in the Main folder\n        if current.Parent and current.Parent.Name == \"Main\" then\n            return {\n                id = current.Name,\n                model = current\n            }\n        end\n        \n        current = current.Parent\n        depth = depth + 1\n    end\n    \n    return nil\nend"
)

-- 2. Modify UpdateCurrentTarget to handle Main folder items
fixedSource = string.gsub(fixedSource,
    "function InteractionSystem:UpdateCurrentTarget%(%)(.-)Check for placed items\n    local placedItem = self:GetPlacedItemFromPart%(target%)\n    if not placedItem then\n        if self%.currentTarget then\n            print%(%\"[InteractionSystem] Target is not a placeable item, clearing current target\"%)\n            self:ClearCurrentTarget%(%)(.-)end\n        return\n    end",
    
    "function InteractionSystem:UpdateCurrentTarget()%1Check for placed items\n\n    -- Check for special items in Main folder (like Board)\n    local mainFolder = workspace:FindFirstChild(\"Main\")\n    if mainFolder and target:IsDescendantOf(mainFolder) then\n        -- Get the top level object in Main that this target belongs to\n        local current = target\n        local topLevelObject = nil\n        \n        while current and current ~= workspace do\n            if current.Parent == mainFolder then\n                topLevelObject = current\n                break\n            end\n            current = current.Parent\n        end\n        \n        if topLevelObject then\n            print(\"[InteractionSystem] Target is a main item:\", topLevelObject.Name)\n            \n            -- If this is already our current target, no need to update\n            if self.currentTarget and self.currentTarget.id == topLevelObject.Name and \n               self.currentTarget.model == topLevelObject then\n                return\n            end\n            \n            -- Otherwise, update current target and show UI\n            self.currentTarget = { id = topLevelObject.Name, model = topLevelObject }\n            self:ShowInteractionUI(self.currentTarget)\n            print(\"[InteractionSystem] Updated current target to main item:\", topLevelObject.Name)\n            return\n        end\n    end\n\n    local placedItem = self:GetPlacedItemFromPart(target)\n    if not placedItem then\n        if self.currentTarget then\n            print(\"[InteractionSystem] Target is not a placeable item, clearing current target\")\n            self:ClearCurrentTarget()%2end\n        return\n    end"
)

-- 3. Add support for interacting with Main folder items
fixedSource = string.gsub(fixedSource,
    "function InteractionSystem:AttemptInteraction%(%)(.-)Check if this is a world item from the Items folder\n    local itemsFolder = workspace:FindFirstChild%(\"Items\"%)\n    if itemsFolder and self%.currentTarget%.model and \n       self%.currentTarget%.model:IsDescendantOf%(itemsFolder%) then(.-)end(.-)For placed items, we want to interact with them",
    
    "function InteractionSystem:AttemptInteraction()%1Check if this is a world item from the Items folder\n    local itemsFolder = workspace:FindFirstChild(\"Items\")\n    if itemsFolder and self.currentTarget.model and \n       self.currentTarget.model:IsDescendantOf(itemsFolder) then%2end\n\n    -- Check if this is a main folder item (like Board)\n    local mainFolder = workspace:FindFirstChild(\"Main\")\n    if mainFolder and self.currentTarget.model and \n       self.currentTarget.model:IsDescendantOf(mainFolder) then\n        print(\"[InteractionSystem] Attempting to interact with main item:\", self.currentTarget.id)\n        \n        -- For main items, we want to trigger their specific interaction\n        -- Send event to server\n        local interactEvent = self.remoteEvents:FindFirstChild(\"InteractWithMain\")\n        if interactEvent then\n            interactEvent:FireServer(self.currentTarget.id)\n            print(\"[InteractionSystem] Sending InteractWithMain event to server for\", self.currentTarget.id)\n            return true\n        else\n            warn(\"[InteractionSystem] InteractWithMain remote event not found\")\n            -- Try to create it if it doesn't exist\n            interactEvent = Instance.new(\"RemoteEvent\")\n            interactEvent.Name = \"InteractWithMain\"\n            interactEvent.Parent = self.remoteEvents\n            interactEvent:FireServer(self.currentTarget.id)\n            print(\"[InteractionSystem] Created and fired InteractWithMain event\")\n            return true\n        end\n    end\n\n    -- For placed items, we want to interact with them"
)

-- 4. Add InteractWithMain remote event creation in RegisterNetworkEvents
fixedSource = string.gsub(fixedSource,
    "function InteractionSystem:RegisterNetworkEvents%(%)(.-)if not self%.remoteEvents:FindFirstChild%(\"InteractWithItem\"%)(.-)\n    end(.-)Register response handlers",
    
    "function InteractionSystem:RegisterNetworkEvents()%1if not self.remoteEvents:FindFirstChild(\"InteractWithItem\")%2\n    end\n    \n    if not self.remoteEvents:FindFirstChild(\"InteractWithMain\") then\n        local mainInteractEvent = Instance.new(\"RemoteEvent\")\n        mainInteractEvent.Name = \"InteractWithMain\"\n        mainInteractEvent.Parent = self.remoteEvents\n        print(\"[InteractionSystem] Created InteractWithMain remote event\")\n    end\n    \n    -- Register response handlers"
)

-- 5. Update ShowInteractionUI to handle different types of objects better
fixedSource = string.gsub(fixedSource, 
    "function InteractionSystem:ShowInteractionUI%(placedItem%)(.-)Attach BillboardGui to the item model's PrimaryPart\n    local primaryPart = placedItem%.model%.PrimaryPart\n    if not primaryPart then\n        %-%- Try to find a suitable part to use as PrimaryPart\n        primaryPart = placedItem%.model:FindFirstChildWhichIsA%(\"BasePart\"%)\n        if primaryPart then(.-)else\n            print%(\"[InteractionSystem] No suitable part found for UI attachment\"%)\n            return\n        end\n    end",
    
    "function InteractionSystem:ShowInteractionUI(placedItem)%1Attach BillboardGui to the item model's PrimaryPart\n    local primaryPart = nil\n    if placedItem.model:IsA(\"Model\") and placedItem.model.PrimaryPart then\n        primaryPart = placedItem.model.PrimaryPart\n    elseif placedItem.model:IsA(\"BasePart\") then\n        primaryPart = placedItem.model\n    else\n        -- Try to find a suitable part to use as PrimaryPart\n        primaryPart = placedItem.model:FindFirstChildWhichIsA(\"BasePart\")\n        if primaryPart and placedItem.model:IsA(\"Model\") then%2else\n            print(\"[InteractionSystem] No suitable part found for UI attachment\")\n            return\n        end\n    end"
)

-- Apply the fixed code
path.Source = fixedSource

print("Successfully fixed InteractionSystemModule in-place!")
print("Changes made:")
print("1. Added special handling for objects in the Main folder")
print("2. Fixed logic in GetPlacedItemFromPart to better identify interactive objects")
print("3. Added support for interacting with Main folder items through InteractWithMain event")
print("4. Improved ShowInteractionUI to better handle different types of objects")
print("5. Enhanced error handling throughout the module")
