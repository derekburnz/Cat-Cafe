--!strict
-- What Roblox says about our game passes, for the Store window: each pass's price and whether it is on sale
-- (MarketplaceService:GetProductInfoAsync, read at runtime as the shop plan requires, so Plus discounts and launch
-- prices show right), which ones the player owns (UserOwnsGamePassAsync, then PromptGamePassPurchaseFinished for a
-- pass bought now), and the purchase prompt itself. Like Components/Invite with Roblox's invite window, the UI opens
-- Roblox's own purchase window directly; nothing goes through our remotes. The server's PassService hears the same
-- purchase finish and turns the pass on.
--
--   start(ids)       look up each pass once; `changed` fires as answers arrive
--   prompt(id)       Roblox's purchase window for a pass
--   preview(prices, owned)   the UI gate's and a Studio preview's answers, in place of Roblox's
--
-- Roblox terms: a game pass is a one-time purchase Roblox keeps track of, so no saved receipt is needed.

local Players = game:GetService("Players")

local Signal = require(script.Parent.Signal)
local StoreLogic = require(script.Parent.StoreLogic)

local PassShop = {}

PassShop.changed = Signal.new() -- prices or ownership changed

local prices: { [number]: StoreLogic.Price } = {}
local products: { [number]: boolean } = {} -- developer product ids (#1182): priced as products, bought each time
local owned: { [number]: boolean } = {}
local started = false
local finished: RBXScriptConnection? = nil

local function market(): MarketplaceService?
	local ok, service = pcall(function()
		return game:GetService("MarketplaceService")
	end)
	return if ok then service else nil
end

function PassShop.start(ids: { number }, productIds: { number }?)
	if started then
		return
	end
	started = true
	local service = market()
	local player = Players.LocalPlayer
	if service == nil or player == nil then
		return
	end
	local productList: { number } = productIds or {}
	for _, id in productList do
		products[id] = true
		task.spawn(function()
			local okInfo, info = pcall(function()
				return service:GetProductInfoAsync(id, Enum.InfoType.Product)
			end)
			if okInfo and type(info) == "table" and prices[id] == nil then
				local robux = info.PriceInRobux
				prices[id] = {
					robux = if type(robux) == "number" then robux else nil,
					forSale = info.IsForSale == true,
				}
				PassShop.changed:Fire()
			end
		end)
	end
	for _, id in ids do
		task.spawn(function()
			local okInfo, info = pcall(function()
				return service:GetProductInfoAsync(id, Enum.InfoType.GamePass)
			end)
			if okInfo and type(info) == "table" and prices[id] == nil then
				local robux = info.PriceInRobux
				prices[id] = {
					robux = if type(robux) == "number" then robux else nil,
					forSale = info.IsForSale == true,
				}
				PassShop.changed:Fire()
			end
			local okOwn, has = pcall(function()
				return service:UserOwnsGamePassAsync(player.UserId, id)
			end)
			if okOwn and has == true and not owned[id] then
				owned[id] = true
				PassShop.changed:Fire()
			end
		end)
	end
	local okSignal, connection = pcall(function()
		return service.PromptGamePassPurchaseFinished:Connect(
			function(who: Player, id: number, purchased: boolean)
				if who == player and purchased and not owned[id] then
					owned[id] = true
					PassShop.changed:Fire()
				end
			end
		)
	end)
	if okSignal then
		finished = connection
	end
end

function PassShop.prompt(id: number)
	local service = market()
	local player = Players.LocalPlayer
	if service == nil or player == nil then
		return
	end
	pcall(function()
		if products[id] then
			-- a product (#1182): the server's ProcessReceipt grants it (#1207)
			service:PromptProductPurchase(player, id)
		else
			service:PromptGamePassPurchase(player, id)
		end
	end)
end

function PassShop.prices(): { [number]: StoreLogic.Price }
	return prices
end

function PassShop.owned(): { [number]: boolean }
	return owned
end

-- Replaces every answer: pass id to { robux, forSale }, and pass id to true for the ones owned. preview({}, {})
-- clears them again.
function PassShop.preview(
	newPrices: { [number]: StoreLogic.Price },
	newOwned: { [number]: boolean }
)
	table.clear(prices)
	table.clear(owned)
	for id, price in newPrices do
		prices[id] = price
	end
	for id, has in newOwned do
		owned[id] = has
	end
	PassShop.changed:Fire()
end

-- UI.destroy: forget the answers, so a fresh UI.init looks again.
function PassShop.stop()
	if finished then
		finished:Disconnect()
		finished = nil
	end
	table.clear(prices)
	table.clear(owned)
	table.clear(products)
	started = false
end

return PassShop
