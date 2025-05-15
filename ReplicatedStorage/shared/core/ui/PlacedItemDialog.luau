local PlacedItemDialog = {}

function PlacedItemDialog.Initialize(container)
    print("[PlacedItemDialog] Initialized with container", container)
end

function PlacedItemDialog.Show(itemId, callback)
    print("[PlacedItemDialog] Show called for item:", itemId)
    if callback then callback("move") end -- Always return 'move' as action
end

return PlacedItemDialog 