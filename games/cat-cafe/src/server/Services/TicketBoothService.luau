--!strict
-- #4061 (shared/TicketBooth): BuyTicketPrize(prizeId) buys one of the booth's fixed prizes with tickets. Refused while
-- the ticketBooth switch is off, below TicketBoothTier, for an unknown prize, at its day, week or once limit, or with
-- too few tickets. Payout pays the fish, crate or potions; a Trait Token goes into the Mystic Pool's tokens. From
-- anywhere for now (the Water Park and its booth are not placed yet), 1 a second (Net's limiter). The tickets
-- themselves come from CafeService's catch path. The Booth Plush Cat prize is given as a gift cat (once), and the
-- buy that takes the save past TicketBooth.REGULAR_SPENT shows the Park Regular title at once. The weekly Water Park
-- shelf's cards (TicketBooth.weekShelf) are bought the same way: a decor piece goes into decorOwned, a wearable is owned
-- by its used once-limit.
-- The two toys (shared/Toys, spec 1.3): HoldToy(toyId?) takes an owned toy in hand or puts it away, as the character
-- attribute Toys.ATTRIBUTE (a respawn starts with none); UseToy() uses it, at most once every Toys.COOLDOWN seconds and
-- never in a catch, a rescue or a flight or with a cat in the arms, and tells the players within Toys.RANGE with ToyUsed. Fun only: a use
-- changes nothing on the server and touches no other player. The client clones the model and plays the effect.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CatStats = require(ReplicatedStorage.Shared.CatStats)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local TicketBooth = require(ReplicatedStorage.Shared.TicketBooth)
local Toys = require(ReplicatedStorage.Shared.Toys)
local Traits = require(ReplicatedStorage.Shared.Traits)

local CafePassService = require(script.Parent.CafePassService)
local CafeService = require(script.Parent.CafeService)
local CatService = require(script.Parent.CatService)
local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Parent.Util.Guard)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Net = require(script.Parent.Net)
local Payout = require(script.Parent.Payout)
local Telemetry = require(script.Parent.Telemetry)

local TicketBoothService = {}

local function onBuy(player: Player, rawId: unknown)
	local id = Guard.id(rawId)
	local profile = DataService.get(player)
	if
		id == nil
		or profile == nil
		or not LiveFlagService.on(TicketBooth.FLAG)
		or not TicketBooth.open(Economy.tier(profile))
	then
		return
	end
	local prize = TicketBooth.prize(id)
	if prize == nil then
		return
	end
	if prize.weekly ~= nil and prize.weekly.kind == "decor" then
		local item = prize.weekly.item
		if Catalog.getDecor(item) == nil then
			return -- a shelf piece the Catalog does not name: never spend tickets on it
		end
		if profile.decorOwned[item] == true then
			Net.toast(player, "You have this already", "warn") -- owned another way (a trade): keep the tickets
			CafeService.sync(player)
			return
		end
	end
	local now = os.time()
	local save = profile.tickets
	local reason = TicketBooth.blocker(save, prize, now)
	if
		reason == nil
		and prize.tokens ~= nil
		and profile.traits.tokens + prize.tokens > Traits.TOKEN_MAX
	then
		reason = "Your token bank is full" -- Review-QA on #4088: never spend tickets on tokens that do not fit
	end
	local spins = if prize.prize ~= nil then prize.prize.spins else nil
	if reason == nil and spins ~= nil and profile.spin.banked + spins > Config.SpinBankCap then
		reason = "Your spins are full, spin a few first" -- #4596: the same for banked spins (Config.SpinBankCap)
	end
	if reason ~= nil then
		Net.toast(player, reason, "warn")
		CafeService.sync(player)
		return
	end
	local def = if prize.cat ~= nil then Catalog.getCat(prize.cat) else nil
	if prize.cat ~= nil and def == nil then
		return -- a prize cat the Catalog does not name: never spend tickets on it
	end
	local before = save.have
	local wasRegular = TicketBooth.regular(save)
	TicketBooth.spend(save, prize, now)
	if prize.tokens ~= nil then
		Traits.give(profile.traits, prize.tokens)
	end
	if prize.prize ~= nil then
		Payout.pay(player, profile, prize.prize, "ticket_booth")
	end
	if def ~= nil then
		CafeService.addGiftCat(player, profile, def, CatStats.DEFAULT_CHARM) -- the Booth Plush Cat
	end
	local weekly = prize.weekly
	if weekly ~= nil and weekly.kind == "decor" then
		-- a weekly shelf piece: owned for good, and with Auto Equip on it takes a spot when it earns more (#2068)
		profile.decorOwned[weekly.item] = true
		if CafeService.autoEquipNewDecor(player, profile, weekly.item) then
			CafeService.refreshPlot(player)
		end
	end
	-- a weekly wearable needs nothing more: its once-limit, now used, is what owns it (TicketBooth.lookItems)
	if not wasRegular and TicketBooth.regular(save) then
		CafePassService.refreshTag(player, profile) -- #4061: Park Regular joins the tag choices now
		Net.toast(player, "New chat title: Park Regular", "good")
	end
	Telemetry.custom(
		player,
		"ticket_buy",
		before,
		{ prize.id, "T" .. tostring(Economy.tier(profile)) }
	)
	Net.toast(player, string.format("%s, enjoy!", prize.name), "good")
	CafeService.sync(player)
end

local lastUse: { [Player]: number } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root ~= nil and root:IsA("BasePart") then
		return root :: BasePart
	end
	return nil
end

-- HoldToy: nil (or anything that is not an owned toy's id) puts the toy away.
local function onHold(player: Player, rawId: unknown)
	local character = player.Character
	if character == nil then
		return
	end
	local profile = DataService.get(player)
	local toy = Toys.get(Guard.id(rawId))
	if
		toy == nil
		or profile == nil
		or not LiveFlagService.on(TicketBooth.FLAG)
		or not Toys.owns(profile.tickets, toy)
	then
		character:SetAttribute(Toys.ATTRIBUTE, nil)
		return
	end
	character:SetAttribute(Toys.ATTRIBUTE, toy.id)
end

local function onUse(player: Player)
	local character = player.Character
	local root = rootOf(player)
	local profile = DataService.get(player)
	if character == nil or root == nil or profile == nil then
		return
	end
	local raw = character:GetAttribute(Toys.ATTRIBUTE)
	local toy = Toys.get(if typeof(raw) == "string" then raw else nil)
	if
		toy == nil
		or not LiveFlagService.on(TicketBooth.FLAG)
		or not Toys.owns(profile.tickets, toy)
	then
		character:SetAttribute(Toys.ATTRIBUTE, nil) -- the switch went off, or nothing owned is in hand
		return
	end
	local now = os.clock()
	local last = lastUse[player]
	-- a carried or packed cat keeps the hand busy too (Motion-FX on #4755: nothing would show)
	local busy = CatService.inMinigame(player)
		or CatService.inFlight(player)
		or CatService.isLoaded(player)
	if Toys.useBlocker(toy.id, if last ~= nil then now - last else nil, busy) ~= nil then
		return
	end
	lastUse[player] = now
	local origin = root.Position
	local near: { Player } = { player }
	local others: { Vector3 } = {}
	for _, other in Players:GetPlayers() do
		local otherRoot = if other ~= player then rootOf(other) else nil
		if otherRoot ~= nil and (otherRoot.Position - origin).Magnitude <= Toys.RANGE then
			table.insert(near, other)
			table.insert(others, otherRoot.Position)
		end
	end
	local target = if toy.aimed then Toys.target(origin, root.CFrame.LookVector, others) else nil
	for _, other in near do
		Net.fire(other, "ToyUsed", player.UserId, toy.id, target)
	end
end

function TicketBoothService.start()
	Net.on("BuyTicketPrize", onBuy)
	Net.on("HoldToy", onHold)
	Net.on("UseToy", onUse)
	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
	end)
end

return TicketBoothService
