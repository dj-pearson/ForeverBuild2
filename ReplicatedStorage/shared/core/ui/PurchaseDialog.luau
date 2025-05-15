local PurchaseDialog = {}

function PurchaseDialog.Initialize(container)
    -- Minimal stub: just print
    print("[PurchaseDialog] Initialized with container", container)
end

function PurchaseDialog.Show(itemId, callback)
    print("[PurchaseDialog] Show called for item:", itemId)
    if callback then callback(1) end -- Always return quantity 1
end

return PurchaseDialog 