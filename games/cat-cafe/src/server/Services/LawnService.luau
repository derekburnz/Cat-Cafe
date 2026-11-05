--!strict
-- The front lawn on the server (F91, front-lawn.md section 5; the rules are shared/Lawn, the world LawnBuilder).
-- BuyLawn(id, spotId?) buys a lawn piece or a path or fence style with coins at the caller's tier (sink "lawn"), from
-- within LawnStallRange of the Garden Nursery (#1200, once its stall is in the world; checked here, never trusted).
-- Since #1283 (lawn-nursery.md section 6b) the server lays the lawn by itself: after a buy it lays Lawn.best, so the
-- new piece or style goes out when it beats one out (or fills an empty spot) and is stored otherwise; `spotId` is
-- still checked for shape but no longer chooses anything. SetLawnSpot and SetLawnStyle are retired and refuse with
-- RETIRED. Each needs the caller's own cafe and the lawn's art in (WorldBuilder.lawnLive), validates every argument,
-- toasts why when it refuses, and otherwise rebuilds the lawn and sends a ProfileSync. A buy logs lawn_placed (its id,
-- the tier), once per piece or style ever (review S119).
-- Lawn pieces and styles out add money (Economy.lawnBonus), so coins are settled before anything changes.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CafeService = require(script.Parent.CafeService)
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

local STALL_TAG = "LawnStall" -- lawn-nursery.md section 2: the Garden Nursery, CatCafe_Camp_Park_GardenNursery

-- #1200 (lawn-nursery.md section 4): true when the player stands within LawnStallRange of a Garden Nursery, measured
-- on the server from their character. Until the nursery is in the world (Model-Agent's art), there is no stall to
-- stand at, so buying stays where it was (the Decor screen's Front lawn tab) rather than closing.
local function atStall(player: Player): boolean
	local stalls: { Model } = {}
	for _, instance in CollectionService:GetTagged(STALL_TAG) do
		if instance:IsA("Model") and instance:IsDescendantOf(Workspace) then
			table.insert(stalls, instance :: Model)
		end
	end
	if #stalls == 0 then
		return true
	end
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local position = (root :: BasePart).Position
	for _, stall in stalls do
		if (stall:GetPivot().Position - position).Magnitude <= Config.LawnStallRange then
			return true
		end
	end
	return false
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
	if not atStall(player) then
		refuse(player, "Walk up to the Garden Nursery in the Park first")
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
