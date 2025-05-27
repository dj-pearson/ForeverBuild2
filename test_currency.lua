-- Quick Currency System Test
local CurrencySystemWrapper = require(game.ReplicatedStorage.src.client.Currency.CurrencySystemWrapper)
local CurrencyIntegrationTest = require(game.ReplicatedStorage.src.client.Currency.CurrencyIntegrationTest)

print('🧪 Testing Currency System...')
local results = CurrencyIntegrationTest.QuickTest()
print('✅ Test completed!') 