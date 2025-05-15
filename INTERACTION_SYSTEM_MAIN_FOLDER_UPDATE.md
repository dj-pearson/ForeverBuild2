# InteractionSystemModule Updates (May 14, 2025)

## Overview
The InteractionSystemModule has been updated to properly handle interactions with objects in the Main folder, specifically the Board object. This enhancement allows players to interact with special objects that aren't in the regular placed items system.

## Changes Made

### 1. Added Main Folder Detection
The `GetPlacedItemFromPart` function now includes logic to recognize objects in the Main folder:

```lua
-- Also check for parts that might not have the item attribute but are valid targets
-- This is especially important for parts in the Main folder
if current.Parent and current.Parent.Name == "Main" then
    return {
        id = current.Name,
        model = current
    }
end
```

### 2. Enhanced UpdateCurrentTarget Function
The function now specifically checks for objects in the Main folder and properly handles them for interaction:

```lua
-- Check for special items in Main folder (like Board)
local mainFolder = workspace:FindFirstChild("Main")
if mainFolder and target:IsDescendantOf(mainFolder) then
    -- Get the top level object in Main that this target belongs to
    local current = target
    local topLevelObject = nil
    
    while current and current ~= workspace do
        if current.Parent == mainFolder then
            topLevelObject = current
            break
        end
        current = current.Parent
    end
    
    if topLevelObject then
        -- Update current target and show UI
        self.currentTarget = { id = topLevelObject.Name, model = topLevelObject }
        self:ShowInteractionUI(self.currentTarget)
    end
end
```

### 3. Added InteractWithMain Remote Event
A new remote event was added for interacting with objects in the Main folder:

```lua
if not self.remoteEvents:FindFirstChild("InteractWithMain") then
    local mainInteractEvent = Instance.new("RemoteEvent")
    mainInteractEvent.Name = "InteractWithMain"
    mainInteractEvent.Parent = self.remoteEvents
end
```

### 4. Updated AttemptInteraction Function
The function now handles interactions with Main folder objects:

```lua
-- Check if this is a main folder item (like Board)
local mainFolder = workspace:FindFirstChild("Main")
if mainFolder and self.currentTarget.model and 
   self.currentTarget.model:IsDescendantOf(mainFolder) then
    -- Send event to server
    local interactEvent = self.remoteEvents:FindFirstChild("InteractWithMain")
    if interactEvent then
        interactEvent:FireServer(self.currentTarget.id)
    else
        -- Create it if it doesn't exist
        interactEvent = Instance.new("RemoteEvent")
        interactEvent.Name = "InteractWithMain"
        interactEvent.Parent = self.remoteEvents
        interactEvent:FireServer(self.currentTarget.id)
    end
    return true
end
```

### 5. Improved ShowInteractionUI Function
The function now better handles different types of objects:

```lua
local primaryPart = nil
if placedItem.model:IsA("Model") and placedItem.model.PrimaryPart then
    primaryPart = placedItem.model.PrimaryPart
elseif placedItem.model:IsA("BasePart") then
    primaryPart = placedItem.model
else
    -- Try to find a suitable part
    primaryPart = placedItem.model:FindFirstChildWhichIsA("BasePart")
    -- ...
end
```

## Testing Your Changes
A validation script has been created to test the functionality:
- `VALIDATE_INTERACTION_SYSTEM.lua` - Tests the updated functions

## Server-Side Implementation
To fully support the new interaction with Main folder objects, you'll need to set up server-side handling of the `InteractWithMain` remote event. Here's a basic example:

```lua
-- In your server script
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local interactWithMainEvent = Remotes:WaitForChild("InteractWithMain")
interactWithMainEvent.OnServerEvent:Connect(function(player, objectId)
    print(player.Name .. " is interacting with: " .. objectId)
    
    -- Handle Board interaction
    if objectId == "Board" then
        -- Implement board-specific behavior here
        print("Player interacted with the Board!")
    end
    
    -- Handle other Main folder objects
    -- ...
end)
```
