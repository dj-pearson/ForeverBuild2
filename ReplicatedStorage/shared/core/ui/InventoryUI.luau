local InventoryUI = {}

function InventoryUI.Initialize(container)
    print("[InventoryUI] Initialized with container", container)
end

function InventoryUI.Show()
    print("[InventoryUI] Show called")
end

function InventoryUI.UpdateInventory(inventory, currency)
    print("[InventoryUI] UpdateInventory called", inventory, currency)
end

return InventoryUI 