--!strict
-- What Roblox says about our game passes, for the Store window: each pass's price and whether it is on sale
-- (MarketplaceService:GetProductInfoAsync, read at runtime as the shop plan requires, so Plus discounts and launch
-- prices show right), which ones the player owns (UserOwnsGamePassAsync, then PromptGamePassPurchaseFinished for a
-- pass bought now), and the purchase prompt itself. Like Components/Invite with Roblox's invite window, the UI opens
-- Roblox's own purchase window directly; nothing goes through our remotes. The server's PassService hears the same
-- purchase finish and turns the pass on.
-- #1770 owner test mode: while the server has set the OwnerTest attribute on the local player (shared/OwnerTest, the
-- owner's account only), every pass counts as owned here as it does on the server, and prompt(id) for a product fires
-- `ownerGrant` (UIController sends OwnerGrant) in place of Roblox's purchase window; the server checks the caller.
--
--   start(ids)       look up each pass; `changed` fires as answers arrive
--   refresh()        look the prices up again (the Store opening, at most once a REFRESH_SECONDS), so a price or
--                    on-sale change made in the Creator Hub shows without a rejoin
--   prompt(id, source?)   Roblox's purchase window for a pass, only right after a tap and never during a catch, a
--                    rescue or a cutscene (#1936, Components/StoreGuard); a refused call fires `blocked`
--   noteTap()        counts as a tap now (the UI gate's presses; real taps are heard from UserInputService)
--   preview(prices, owned)   the UI gate's and a Studio preview's answers, in place of Roblox's
--
-- Roblox terms: a game pass is a one-time purchase Roblox keeps track of, so no saved receipt is needed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Signal = require(script.Parent.Signal)
local StoreGuard = require(script.Parent.StoreGuard)
local StoreLogic = require(script.Parent.StoreLogic)

local PassShop = {}

PassShop.changed = Signal.new() -- prices or ownership changed
PassShop.purchased = Signal.new() -- (passId) #2147: the prompt says a pass was just bought here (never at join)
PassShop.ownerGrant = Signal.new() -- (productId) #1770: owner test mode's grant in place of a purchase
PassShop.blocked = Signal.new() -- (source, reason) #1936: a prompt refused, "no_tap" or "busy"
-- #1936: set by UI.init, true during a catch, a rescue or a cutscene
PassShop.busy = function(): boolean
	return false
end

local prices: { [number]: StoreLogic.Price } = {}
local products: { [number]: boolean } = {} -- developer product ids (#1182): priced as products, bought each time
local owned: { [number]: boolean } = {}
local started = false
local finished: RBXScriptConnection? = nil
local ownerWatch: RBXScriptConnection? = nil -- the OwnerTest attribute's changes (#1770)
local passIds: { number } = {}
local productIdList: { number } = {}
local lastLook = -math.huge -- os.clock() of the last price look-up
local previewing = false -- preview() set the answers, so Roblox's own do not replace them
local lastTap: number? = nil -- os.clock() of the last tap, click or gamepad press (#1936)
local tapWatch: RBXScriptConnection? = nil

-- What counts as a tap: a touch, a left click, the gamepad's A (which presses the selected button) or Enter.
local TAP_INPUTS: { [Enum.UserInputType]: boolean } = {
	[Enum.UserInputType.Touch] = true,
	[Enum.UserInputType.MouseButton1] = true,
}
local TAP_KEYS: { [Enum.KeyCode]: boolean } = {
	[Enum.KeyCode.ButtonA] = true,
	[Enum.KeyCode.Return] = true,
	[Enum.KeyCode.KeypadEnter] = true,
}

PassShop.REFRESH_SECONDS = 60

local function samePrice(a: StoreLogic.Price?, b: StoreLogic.Price): boolean
	return a ~= nil and a.robux == b.robux and a.forSale == b.forSale
end

-- One price from Roblox: a product's or a pass's, kept and `changed` fired only when it differs from what we have.
local function lookPrice(service: MarketplaceService, id: number, infoType: Enum.InfoType)
	local okInfo, info = pcall(function()
		return service:GetProductInfoAsync(id, infoType)
	end)
	if okInfo and type(info) == "table" and not previewing then
		local robux = info.PriceInRobux
		local price: StoreLogic.Price = {
			robux = if type(robux) == "number" then robux else nil,
			forSale = info.IsForSale == true,
		}
		if not samePrice(prices[id], price) then
			prices[id] = price
			PassShop.changed:Fire()
		end
	end
end

-- #1770: shared/OwnerTest (nil where the shared folder is missing, as in a bare test).
local function ownerModule(): any
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local module = if shared then shared:FindFirstChild("OwnerTest") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	return require(module) :: any
end

local function ownerAttribute(): string?
	local module = ownerModule()
	return if module ~= nil then module.ATTRIBUTE else nil
end

-- Whether the server put the local player in owner test mode (#1770). Only the server sets it.
function PassShop.ownerTest(): boolean
	local player = Players.LocalPlayer
	local name = ownerAttribute()
	return player ~= nil and name ~= nil and player:GetAttribute(name) == true
end

-- The HUD's "Owner test mode" label while in it (#1770), else nil.
function PassShop.ownerLabel(): string?
	local module = ownerModule()
	return if module ~= nil and PassShop.ownerTest() then module.LABEL else nil
end

-- #1770: every pass owned while in owner test mode, as the server counts them.
local function markOwnerPasses()
	if previewing or not PassShop.ownerTest() then
		return
	end
	local any = false
	for _, id in passIds do
		if not owned[id] then
			owned[id] = true
			any = true
		end
	end
	if any then
		PassShop.changed:Fire()
	end
end

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
	-- #1936: GUI presses count too, so gameProcessed is not checked
	tapWatch = UserInputService.InputBegan:Connect(function(input: InputObject)
		if TAP_INPUTS[input.UserInputType] or TAP_KEYS[input.KeyCode] then
			lastTap = os.clock()
		end
	end)
	local service = market()
	local player = Players.LocalPlayer
	if service == nil or player == nil then
		return
	end
	local productList: { number } = productIds or {}
	passIds = table.clone(ids)
	productIdList = table.clone(productList)
	local attribute = ownerAttribute()
	if attribute ~= nil then
		ownerWatch = player:GetAttributeChangedSignal(attribute):Connect(function()
			markOwnerPasses()
			PassShop.changed:Fire() -- the HUD's label follows the attribute either way
		end)
	end
	markOwnerPasses()
	lastLook = os.clock()
	for _, id in productList do
		products[id] = true
		task.spawn(lookPrice, service, id, Enum.InfoType.Product)
	end
	for _, id in ids do
		task.spawn(function()
			lookPrice(service, id, Enum.InfoType.GamePass)
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
					PassShop.purchased:Fire(id)
				end
			end
		)
	end)
	if okSignal then
		finished = connection
	end
end

-- The Store opened: every price again, at most once a REFRESH_SECONDS (the Roblox call has a rate limit). A changed
-- price or on-sale flag fires `changed`, so the open window's cards update.
function PassShop.refresh()
	local service = market()
	if not started or service == nil or os.clock() - lastLook < PassShop.REFRESH_SECONDS then
		return
	end
	lastLook = os.clock()
	for _, id in productIdList do
		task.spawn(lookPrice, service, id, Enum.InfoType.Product)
	end
	for _, id in passIds do
		task.spawn(lookPrice, service, id, Enum.InfoType.GamePass)
	end
end

function PassShop.noteTap()
	lastTap = os.clock()
end

function PassShop.prompt(id: number, source: string?)
	-- #1936: only a tap the player just made opens Roblox's window, and never over a catch, a rescue or a cutscene
	local okBusy, busy = pcall(PassShop.busy)
	local allowed, reason = StoreGuard.allow({
		now = os.clock(),
		lastTap = lastTap,
		busy = okBusy and busy == true,
	})
	lastTap = nil -- one tap is one try
	if not allowed then
		PassShop.blocked:Fire(source or "store", reason or "no_tap")
		return
	end
	local service = market()
	local player = Players.LocalPlayer
	if PassShop.ownerTest() then
		-- #1770: no Roblox window; a product is granted by the server, a pass already counts as owned
		if products[id] then
			PassShop.ownerGrant:Fire(id)
		else
			markOwnerPasses()
		end
		return
	end
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
	previewing = next(newPrices) ~= nil or next(newOwned) ~= nil
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
	if ownerWatch then
		ownerWatch:Disconnect()
		ownerWatch = nil
	end
	if tapWatch then
		tapWatch:Disconnect()
		tapWatch = nil
	end
	lastTap = nil
	table.clear(prices)
	table.clear(owned)
	table.clear(products)
	started = false
	previewing = false
	lastLook = -math.huge
end

return PassShop
