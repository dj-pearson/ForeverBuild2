-- This script will print the current place ID
if game:IsLoaded() then
    print("Current Place ID:", game.PlaceId)
else
    game.Loaded:Wait()
    print("Current Place ID:", game.PlaceId)
end
