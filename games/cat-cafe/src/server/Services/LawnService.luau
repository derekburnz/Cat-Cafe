--!strict
-- The front lawn on the server (F91, front-lawn.md section 5; the rules are shared/Lawn, the world LawnBuilder).
-- BuyLawn(id, spotId?) buys a lawn piece or a path or fence style with coins at the caller's tier (sink "lawn"): a
-- style goes in use at once, a piece onto the spot asked for when it may stand there, else the first empty open spot
-- of its size. SetLawnSpot(spotId, pieceId?) puts an owned piece on an open spot of its size, moving it from any other,
-- or clears the spot; SetLawnStyle(kind, id) lays an owned path or puts up an owned fence. Each needs the caller's own
-- cafe and the lawn's art in (WorldBuilder.lawnLive), validates every argument, toasts why when it refuses, and
-- otherwise rebuilds the lawn and sends a ProfileSync. A buy logs lawn_placed (its id, the tier), once per piece or
-- style ever: moves and style swaps log nothing, so 4 SetLawnSpot calls a second cannot eat the server's custom event
-- budget (review S119; Telemetry's note on the budget, as with net swings in S99).
-- Lawn pieces pay no tip bonus, so nothing here changes the income; coins are settled before a price comes off.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafeService = require(script.Parent.CafeService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ClockService = require(script.Parent.ClockService)
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

type Profile = Types.PlayerProfile

local LawnService = {}

local KINDS = { "path", "fence" }

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
	local spotId, spotOk = optionalId(rawSpotId)
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
	local blocker = Lawn.buyBlocker(profile, id)
	if blocker ~= nil then
		refuse(player, blocker)
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
	bought(player, profile, id)
	if style ~= nil then
		Lawn.setStyle(profile, style.kind, id)
		Net.toast(
			player,
			string.format(
				if style.kind == "path" then "%s path laid" else "%s fence put up",
				style.name
			),
			"good"
		)
	elseif piece ~= nil then
		local target: string? = Lawn.firstFreeSpot(profile, piece.spot)
		if spotId ~= nil and Lawn.placeBlocker(profile, spotId, id) == nil then
			target = spotId
		end
		if target ~= nil then
			Lawn.place(profile, target, id)
			Net.toast(player, string.format("%s placed on your lawn", piece.name), "good")
		else
			Net.toast(
				player,
				string.format("%s bought. Clear a %s spot to put it out.", piece.name, piece.spot),
				"good"
			)
		end
	end
	rebuild(player, profile, plot)
end

local function onSetLawnSpot(player: Player, rawSpotId: unknown, rawPieceId: unknown)
	local spotId = Guard.id(rawSpotId)
	local pieceId, pieceOk = optionalId(rawPieceId)
	if spotId == nil or not pieceOk or Lawn.getSpot(spotId) == nil then
		return
	end
	if pieceId ~= nil and Catalog.getLawn(pieceId) == nil then
		return
	end
	local profile, plot = ready(player)
	if profile == nil or plot == nil then
		return
	end
	local blocker = Lawn.placeBlocker(profile, spotId, pieceId)
	if blocker ~= nil then
		refuse(player, blocker)
		return
	end
	if profile.lawn[spotId] == pieceId then
		return -- nothing changes
	end
	Lawn.place(profile, spotId, pieceId)
	rebuild(player, profile, plot)
end

local function onSetLawnStyle(player: Player, rawKind: unknown, rawId: unknown)
	local kind = Guard.oneOf(rawKind, KINDS)
	local id, idOk = optionalId(rawId)
	if kind == nil or not idOk or (rawId == nil) then
		return
	end
	local styleKind: Types.LawnStyleKind = if kind == "path" then "path" else "fence"
	local profile, plot = ready(player)
	if profile == nil or plot == nil then
		return
	end
	local blocker = Lawn.styleBlocker(profile, styleKind, id)
	if blocker ~= nil then
		refuse(player, blocker)
		return
	end
	local current = if styleKind == "path"
		then profile.lawnStyles.path
		else profile.lawnStyles.fence
	if current == (id or (if styleKind == "path" then Lawn.DEFAULT_PATH else nil)) then
		return -- already in use
	end
	Lawn.setStyle(profile, styleKind, id)
	rebuild(player, profile, plot)
end

function LawnService.start()
	Net.on("BuyLawn", onBuyLawn)
	Net.on("SetLawnSpot", onSetLawnSpot)
	Net.on("SetLawnStyle", onSetLawnStyle)
end

return LawnService
