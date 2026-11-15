--!strict
-- #4061 (shared/TicketBooth): BuyTicketPrize(prizeId) buys one of the booth's fixed prizes with tickets. Refused while
-- the ticketBooth switch is off, below TicketBoothTier, for an unknown prize, at its day, week or once limit, or with
-- too few tickets. Payout pays the fish, crate or potions; a Trait Token goes into the Mystic Pool's tokens. From
-- anywhere for now (the Water Park and its booth are not placed yet), 1 a second (Net's limiter). The tickets
-- themselves come from CafeService's catch path. The Booth Plush Cat prize is given as a gift cat (once), and the
-- buy that takes the save past TicketBooth.REGULAR_SPENT shows the Park Regular title at once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CatStats = require(ReplicatedStorage.Shared.CatStats)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Economy = require(ReplicatedStorage.Shared.Economy)
local TicketBooth = require(ReplicatedStorage.Shared.TicketBooth)
local Traits = require(ReplicatedStorage.Shared.Traits)

local CafePassService = require(script.Parent.CafePassService)
local CafeService = require(script.Parent.CafeService)
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

function TicketBoothService.start()
	Net.on("BuyTicketPrize", onBuy)
end

return TicketBoothService
