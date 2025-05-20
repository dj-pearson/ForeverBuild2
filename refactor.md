Here's the plan:
Refactor Constants.lua:
We'll modify Constants.ITEM_ACTIONS to store cost multipliers rather than fixed costs. For example, Clone will have a multiplier of 1.0 (100%), Move will be 0.6 (60%), Recall will be 0.2 (20%), and Destroy will be 0.8 (80%).
We need to ensure that all items intended to be placed and interacted with in Constants.ITEMS have a priceIngame attribute.
Update PlacedItemDialog.luau (Client-side UI):
When an item is selected and the dialog appears, it will need to:
Retrieve the priceIngame attribute from the selected world item.
For each action button (Clone, Move, Recall, Destroy), calculate the actual cost by multiplying the item's priceIngame with the corresponding multiplier from Constants.ITEM_ACTIONS.
Display this calculated cost on or next to each button (e.g., "Recall (Cost: 2)").
Update Server-Side Logic (PlacementManager.luau and potentially ItemPurchaseHandler.luau or CurrencyManager.luau):
RecallItem:
When a recall request is received, the server will look up the item, get its priceIngame.
Calculate the recall cost (20% of priceIngame).
Attempt to deduct this amount from the player's currency.
Only if the player can afford it, the item will be recalled to their inventory, and the world data updated.
DeleteItem:
Similar to recall: get priceIngame, calculate destroy cost (80%).
Deduct currency. If successful, destroy the item and update world data.
CloneItem (New Functionality):
We'll need a new RemoteEvent (e.g., "CloneItemRequest").
Client: When "Clone" is clicked, it sends the instanceId of the item to clone.
Server:
Gets the original item's data (especially itemId and priceIngame).
Calculates the clone cost (100% of priceIngame).
Deducts currency.
If successful, it effectively calls PlaceItem with the original itemId (to create a new instance), at a new position (this will likely require the client to also send target placement info or the server to place it offset from the original), and attributes the new item to the player.
MoveItem (New Functionality):
New RemoteEvent (e.g., "MoveItemRequest").
Client: When "Move" is clicked, it would likely enter a "move mode" for that item, allowing the player to select a new position. On confirmation, it sends instanceId and the newPosition (and newRotation).
Server:
Gets the original item's priceIngame.
Calculates move cost (60%).
Deducts currency.
If successful, it updates the CFrame of the existing instanceId in the World_Items.Placed folder and saves its new state to the DataStore. No inventory change.
This is a multi-step process. Let's begin by examining and modifying Constants.luau.
I'll read the Constants.luau file to understand the current structure of ITEM_ACTIONS and an example item definition.