--!strict
-- The front lawn on the server (F91, front-lawn.md section 5; the rules are shared/Lawn, the world LawnBuilder).
-- BuyLawn(id, spotId?) buys a lawn piece or a path or fence style with coins at the caller's tier (sink "lawn"). Since
-- #1537 (lawn-nursery.md section 7) only the Yard Sale sells them: the id must be in the global day's stock
-- (shared/YardSale), not bought by this player today, and the caller within reach of the Yard Sale (checked here,
-- never trusted). The Garden Nursery is retired.
-- Since #1283 (lawn-nursery.md section 6b) the server lays the lawn by itself: after a buy it lays Lawn.best, so the
-- new piece or style goes out when it beats one out (or fills an empty spot) and is stored otherwise; `spotId` is
-- still checked for shape but no longer chooses anything. SetLawnSpot and SetLawnStyle are retired and refuse with
-- RETIRED. Each needs the caller's own cafe and the lawn's art in (WorldBuilder.lawnLive), validates every argument,
-- toasts why when it refuses, and otherwise rebuilds the lawn and sends a ProfileSync. A buy logs lawn_placed (its id,
-- the tier), once per piece or style ever (review S119).
-- Lawn pieces and styles out add money (Economy.lawnBonus), so coins are settled before anything changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafeService = require(script.Parent.CafeService)
local CampExtraService = require(script.Parent.CampExtraService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Guard = require(script.Parent.Parent.Util.Guard)
local Lawn = require(ReplicatedStorage.Shared.Lawn)
local LawnBuilder = require(script.Parent.Parent.World.LawnBuilder)
local Net = require(script.Parent.Net)
local PlotService = require(script.Parent.PlotService)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)
local YardSale = require(ReplicatedStorage.Shared.YardSale)

type Profile = Types.PlayerProfile

local LawnService = {}

local KINDS = { "path", "fence" }

-- What SetLawnSpot and SetLawnStyle say now (section 6b); the abuse client matches it as a prefix.
LawnService.RETIRED = "The lawn sets itself now"

-- "+1%" or "+1.5%": a lawn bonus as the toasts show it.
function LawnService.percent(bonus: number): string
	local tenths = math.floor(bonus * 1000 + 0.5)
	if tenths % 10 == 0 then
		return string.format("+%d%%", tenths // 10)
	end
	return string.format("+%.1f%%", tenths / 10)
end

-- Whether piece or style `id` is out on the profile's lawn.
local function isOut(profile: Profile, id: string): boolean
	return Lawn.spotOf(profile, id) ~= nil
		or profile.lawnStyles.path == id
		or profile.lawnStyles.fence == id
end

-- The caller's profile and plot when the lawn can change, else nil (with a toast when the lawn is not in yet).
local function ready(player: Player): (Profile?, WorldBuilder.Plot?)
	local profile, plot = DataService.get(player), PlotService.get(player)
	if profile == nil or plot == nil then
		return nil, nil
	end
	if not WorldBuilder.lawnLive() then
		Net.toast(player, "The front lawn opens soon.", "info")
		return nil, nil
	end
	return profile, plot
end

-- An optional id argument: nil or "" is none (ok), a valid id is itself, anything else is refused (ok false).
local function optionalId(raw: unknown): (string?, boolean)
	if raw == nil or raw == "" then
		return nil, true
	end
	local id = Guard.id(raw)
	return id, id ~= nil
end

-- One per piece or style ever: a buy that went through (review S119).
local function bought(player: Player, profile: Profile, id: string)
	Telemetry.custom(player, "lawn_placed", 1, { id, tostring(Economy.tier(profile)) })
end

local function rebuild(player: Player, profile: Profile, plot: WorldBuilder.Plot)
	LawnBuilder.refresh(plot, profile)
	CafeService.sync(player)
end

local function refuse(player: Player, message: string)
	Net.toast(player, message, "warn")
	CafeService.sync(player) -- the tab shows the truth again
end

local function onBuyLawn(player: Player, rawId: unknown, rawSpotId: unknown)
	local id = Guard.id(rawId)
	local _spotId, spotOk = optionalId(rawSpotId)
	if id == nil or not spotOk then
		return
	end
	local piece, style = Catalog.getLawn(id), Catalog.getLawnStyle(id)
	if piece == nil and style == nil then
		return
	end
	local profile, plot = ready(player)
	if profile == nil or plot == nil then
		return
	end
	if not CampExtraService.atYardSale(player, Economy.tier(profile)) then
		refuse(player, "Walk up to the Yard Sale first")
		return
	end
	local day = YardSale.dayAt(os.time())
	YardSale.refresh(profile.yardDecor, day)
	local blocker = YardSale.buyBlocker(profile.yardDecor, day, id, Lawn.buyBlocker(profile, id))
	if blocker ~= nil then
		refuse(player, blocker)
		CampExtraService.resend(player)
		return
	end
	local price = if piece ~= nil then piece.price elseif style ~= nil then style.price else 0
	Economy.settle(profile, os.time(), ClockService.epoch())
	if not Economy.trySpend(profile, price) then
		refuse(player, "Not enough coins")
		return
	end
	Telemetry.sink(player, profile, price, "Shop", "lawn")
	profile.lawnOwned[id] = true
	profile.yardDecor.bought[id] = true -- the same save write as the coins and the piece
	bought(player, profile, id)
	Lawn.applyBest(profile)
	local name = if piece ~= nil then piece.name elseif style ~= nil then style.name else id
	local rarity: Types.LawnRarity? = if piece ~= nil
		then piece.rarity
		elseif style ~= nil then style.rarity
		else nil
	if isOut(profile, id) then
		Net.toast(
			player,
			string.format(
				"%s is out on your lawn (%s money)",
				name,
				LawnService.percent(Lawn.rarityBonus(rarity))
			),
			"good"
		)
	else
		Net.toast(
			player,
			string.format("%s bought. Your lawn's better pieces stay out.", name),
			"good"
		)
	end
	rebuild(player, profile, plot)
	CampExtraService.resend(player)
end

-- Section 6b: the lawn sets itself, so placing by hand is refused (an old client, or an exploit): arguments of the
-- old shape get RETIRED, anything else is dropped without a word, as before.
local function onSetLawnSpot(player: Player, rawSpotId: unknown, rawPieceId: unknown)
	local spotId = Guard.id(rawSpotId)
	local pieceId, pieceOk = optionalId(rawPieceId)
	if spotId == nil or not pieceOk or Lawn.getSpot(spotId) == nil then
		return
	end
	if pieceId ~= nil and Catalog.getLawn(pieceId) == nil then
		return
	end
	refuse(player, LawnService.RETIRED)
end

local function onSetLawnStyle(player: Player, rawKind: unknown, rawId: unknown)
	local kind = Guard.oneOf(rawKind, KINDS)
	local _id, idOk = optionalId(rawId)
	if kind == nil or not idOk or rawId == nil then
		return
	end
	refuse(player, LawnService.RETIRED)
end

function LawnService.start()
	Net.on("BuyLawn", onBuyLawn)
	Net.on("SetLawnSpot", onSetLawnSpot)
	Net.on("SetLawnStyle", onSetLawnStyle)
end

return LawnService
