--!strict
-- The night food dealer (F32, data-model section 8b). A cart parks mid-street at night start and leaves at day
-- start. F94 (rewards-and-shops.md section 4): at dusk this server rolls one stock with its own Random (shared/Dealer)
-- that holds all night, and each player can buy up to that many of each food that night. The counts live in memory
-- by user id, so a rejoin to this server keeps them, and clear at sunrise; nothing is saved. BuyDealerFood(lureId,
-- night) refuses a buy sent for another night (reviewer S42: nobody buys stock they never saw). DealerStock goes to
-- each player whenever their stock or bought counts change (night start, a join), nil by day, and after every buy,
-- bought or not.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AssetRegistry = require(script.Parent.Parent.World.AssetRegistry)
local CafeService = require(script.Parent.CafeService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Dealer = require(ReplicatedStorage.Shared.Dealer)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Guard = require(script.Parent.Parent.Util.Guard)
local Layout = require(script.Parent.Parent.World.Layout)
local Net = require(script.Parent.Net)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local DealerService = {}

local CLOSED = "closed"

local cart: Model? = nil
local sentKey: { [Player]: string } = {} -- what this player was last sent, so an unchanged stock is not resent
local random = Random.new()
local night = 0 -- this server's night count, 1 from its first dusk; DealerStock and BuyDealerFood carry it
local stock: { Dealer.FoodAmount }? = nil -- tonight's stock, rolled at dusk; nil by day
local bought: { [number]: { [string]: number } } = {} -- tonight's buys by user id; cleared at sunrise

-- Puts a model's lowest point on the street, since the art and the stand-ins pivot at different heights.
local function standOnStreet(model: Model, at: CFrame)
	model:PivotTo(at)
	local box, size = model:GetBoundingBox()
	local bottom = box.Position.Y - size.Y / 2
	model:PivotTo(at + Vector3.new(0, at.Position.Y - bottom, 0))
end

-- The model's primary part, else its first part anywhere inside.
local function firstPart(model: Model): BasePart?
	if model.PrimaryPart ~= nil then
		return model.PrimaryPart
	end
	local found = model:FindFirstChildWhichIsA("BasePart", true)
	return if found ~= nil then found :: BasePart else nil
end

local function cartPart(): BasePart?
	local model = cart
	return if model ~= nil then firstPart(model) else nil
end

local function park()
	if cart ~= nil then
		return
	end
	local point = Layout.dealerCart
	local at = CFrame.new(point.x, point.y, point.z)
		* CFrame.Angles(0, math.rad(point.rotY or 0), 0)
	local model = AssetRegistry.clone("CatCafe_Street_DealerCart")
	model.Name = "DealerCart"
	standOnStreet(model, at)
	local npc = AssetRegistry.clone("CatCafe_NPC_Dealer")
	npc.Name = "Dealer"
	local spot = Layout.dealerNpc
	standOnStreet(npc, at * CFrame.new(spot.x, spot.y, spot.z))
	npc.Parent = model

	-- Custom: the UI draws it as its action pill (ui-contract), floating where the prompt's attachment sits, over
	-- the cart at head height.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DealerPrompt"
	prompt.ObjectText = "Night dealer"
	prompt.ActionText = "Shop"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.DealerRangeStuds - 2
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	local part = firstPart(model)
	if part ~= nil then
		local float = Instance.new("Attachment")
		float.Name = "PromptPoint"
		float.Parent = part
		float.WorldPosition = at.Position + Vector3.new(0, 4, 0)
		prompt.Parent = float
	end

	model:SetAttribute("Open", true)
	CollectionService:AddTag(model, "DealerCart")
	-- Persistent: a cart that streamed out and back in would read as leaving and arriving again on the client
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = Workspace:FindFirstChild("World") or Workspace
	cart = model
end

local function leave()
	local model = cart
	cart = nil
	if model ~= nil then
		model:Destroy()
	end
end

-- Tonight's amounts with this player's bought counts, priced at the player's tier (F97).
local function stockFor(player: Player, tonight: { Dealer.FoodAmount }): Types.DealerStock
	local mine = bought[player.UserId] or {}
	local profile = DataService.get(player)
	local tier = if profile ~= nil then Economy.tier(profile) else 1
	local rows: { Types.DealerFood } = {}
	for _, food in tonight do
		table.insert(rows, {
			lureId = food.lureId,
			cost = Economy.foodPrice(food.lureId, tier),
			amount = food.amount,
			bought = math.min(mine[food.lureId] or 0, food.amount),
		})
	end
	return { night = night, stock = rows }
end

local function stockKey(sent: Types.DealerStock): string
	local parts = { tostring(sent.night) }
	for _, food in sent.stock do
		table.insert(parts, string.format("%s=%d/%d", food.lureId, food.bought, food.amount))
	end
	return table.concat(parts, ":")
end

-- Sends the player's stock when it differs from what they have, or always with `force`.
local function sendStock(player: Player, force: boolean)
	if DataService.get(player) == nil then
		return
	end
	local tonight = stock
	if cart == nil or tonight == nil then
		if force or sentKey[player] ~= CLOSED then
			sentKey[player] = CLOSED
			Net.fire(player, "DealerStock", nil)
		end
		return
	end
	local sent = stockFor(player, tonight)
	local key = stockKey(sent)
	if force or sentKey[player] ~= key then
		sentKey[player] = key
		Net.fire(player, "DealerStock", sent)
	end
end

local function nearCart(player: Player): boolean
	local part = cartPart()
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if part == nil or root == nil or not root:IsA("BasePart") then
		return false
	end
	return ((root :: BasePart).Position - part.Position).Magnitude <= Config.DealerRangeStuds
end

local function onBuyDealerFood(player: Player, rawLureId: unknown, rawNight: unknown)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	local function refuse(text: string)
		Net.toast(player, text, "warn")
		sendStock(player, true)
	end
	local lureId = Guard.id(rawLureId)
	local seenNight = Guard.int(rawNight, 0, 2 ^ 40)
	if lureId == nil or seenNight == nil then
		sendStock(player, true)
		return
	end
	local tonight = stock
	if cart == nil or tonight == nil or not ClockService.isNight() then
		refuse("The dealer only comes out at night.")
		return
	end
	if not nearCart(player) then
		refuse("Walk back to the cart to buy.")
		return
	end
	if seenNight ~= night then
		-- a stock from another night: the player never saw tonight's amounts (S42)
		refuse("The cart has a new stock tonight. Take another look.")
		return
	end
	local def = Catalog.getLure(lureId)
	if def == nil or def.source ~= "dealer" then
		refuse("That food isn't on the cart.")
		return
	end
	local amount = Dealer.amountIn(tonight, lureId)
	local mine = bought[player.UserId] or {}
	local already = mine[lureId] or 0
	if amount <= 0 then
		refuse("None tonight.")
		return
	end
	if already >= amount then
		refuse(
			if amount == 1
				then "You bought the only one tonight."
				else "You bought them all tonight."
		)
		return
	end
	Economy.settle(profile, os.time(), ClockService.epoch())
	local price = Economy.foodPrice(lureId, Economy.tier(profile)) -- F97: grows with the tier
	if not Economy.trySpend(profile, price) then
		refuse("Not enough coins")
		return
	end
	Telemetry.sink(player, profile, price, "Shop", "dealer_" .. lureId)
	-- the third field was the slot number before F59; it is which of the stock's amount this buy was ("2/3")
	Telemetry.custom(
		player,
		"dealer_buy",
		price,
		{ lureId, tostring(Economy.tier(profile)), string.format("%d/%d", already + 1, amount) }
	)
	profile.lures[lureId] = (profile.lures[lureId] or 0) + 1
	mine[lureId] = already + 1
	bought[player.UserId] = mine
	Net.toast(player, string.format("Bought %s (%d)", def.name, profile.lures[lureId]), "good")
	CafeService.sync(player)
	sendStock(player, true)
end

local function onPhase(phase: Types.ClockPhase)
	if phase == "night" then
		if cart == nil then
			-- dusk: this server's stock for the night, held until sunrise
			night += 1
			stock = Dealer.roll(function()
				return random:NextNumber()
			end)
			bought = {}
		end
		park()
	else
		leave()
		stock = nil
		bought = {}
	end
	for _, player in DataService.loadedPlayers() do
		sendStock(player, false)
	end
end

function DealerService.start()
	Net.on("BuyDealerFood", onBuyDealerFood)
	ClockService.changed:Connect(onPhase)
	onPhase(ClockService.phase())
	Players.PlayerRemoving:Connect(function(player)
		sentKey[player] = nil
	end)
	-- A join changes someone's stock; one check a second catches them all.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in DataService.loadedPlayers() do
				sendStock(player, false)
			end
		end
	end)
end

return DealerService
