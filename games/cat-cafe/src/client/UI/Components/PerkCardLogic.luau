--!strict
-- The station perk card's words (#2687 part 4, Derek2 2026-11-09: "make unlocking the stations inside new areas more
-- impactful so it feels like you are actually unlocking progress"). Screens/PerkCard draws them; shared/StationPerks
-- owns the perks and their numbers, so the card always says what the server does.
--   PerkCardLogic.unlocked(perk)   the "Unlocked!" card after a station's reveal: the station's picture and name, the
--                                  perk's name and its one line
--   PerkCardLogic.list(tier)       "Your perks": every owned perk, then the next one as a locked row ("Opens at Tier N")
--                                  with its name hidden
--   PerkCardLogic.teaser(tier)     the rank up window's line for the perk the next tier brings, or nil
-- Pure.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StationPerks =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StationPerks")) :: any
-- #3997: a perk of a tier behind the `tier8` switch is not teased until the switch is on
local LateTiers = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LateTiers")) :: any

local PerkCardLogic = {}

-- each station's picture, by perk id
PerkCardLogic.ICON = table.freeze({
	fresh_bait = "🧺",
	cocoa_break = "☕", -- #3997
	haggler = "🏷️",
	lucky_line = "🎣",
	homing_bell = "🔔",
	warm_paws = "🌴",
	curator = "🏺",
} :: { [string]: string })
PerkCardLogic.FALLBACK_ICON = "⭐"
PerkCardLogic.LOCK = "🔒"
PerkCardLogic.UNLOCKED_TITLE = "Unlocked!"
PerkCardLogic.LIST_TITLE = "Your perks"
PerkCardLogic.NONE = "Rank up to Tier 2 for your first station perk."
PerkCardLogic.OK = "Nice!"
PerkCardLogic.CLOSE = "Close"

export type Perk = {
	id: string,
	tier: number,
	station: string,
	name: string,
	text: string,
}

export type Row = {
	id: string,
	icon: string,
	title: string, -- "Haggler · Yard Sale", or "Lost and Found perk" when locked
	text: string, -- the perk's one line, or "Opens at Tier 5" when locked
	owned: boolean,
}

export type Unlocked = {
	icon: string,
	title: string,
	station: string,
	perk: string, -- "New perk: Haggler"
	text: string,
}

function PerkCardLogic.icon(id: string): string
	return PerkCardLogic.ICON[id] or PerkCardLogic.FALLBACK_ICON
end

-- #3585: while the `traits` switch is on the Mystic Pool stands on the Picnic Basket's spot and the basket is put
-- away, so with `pool` true the Park's card shows the pool, the station a player can find there. The perk is the same.
PerkCardLogic.POOL_PERK = "fresh_bait"
PerkCardLogic.POOL_ICON = "🔮"
PerkCardLogic.POOL_STATION = "Mystic Pool" -- Traits.NAME

-- Whether the pool stands there now: the `traits` live switch, as this client sees it (the one impure reader here).
function PerkCardLogic.poolStands(): boolean
	local LiveFlags =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags")) :: any
	return LiveFlags.shown(
		"traits",
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. "traits")
	) == true
end

function PerkCardLogic.unlocked(perk: Perk, pool: boolean?): Unlocked
	local swapped = pool == true and perk.id == PerkCardLogic.POOL_PERK
	return {
		icon = if swapped then PerkCardLogic.POOL_ICON else PerkCardLogic.icon(perk.id),
		title = PerkCardLogic.UNLOCKED_TITLE,
		station = if swapped then PerkCardLogic.POOL_STATION else perk.station,
		perk = "New perk: " .. perk.name,
		text = perk.text,
	}
end

-- `pool` as for `unlocked`: the Park's rows name the Mystic Pool while it stands on the basket's spot.
function PerkCardLogic.list(tier: number?, pool: boolean?): { Row }
	local function station(perk: Perk): string
		return if pool == true and perk.id == PerkCardLogic.POOL_PERK
			then PerkCardLogic.POOL_STATION
			else perk.station
	end
	local rows: { Row } = {}
	for _, perk in StationPerks.owned(tier) :: { Perk } do
		local swapped = pool == true and perk.id == PerkCardLogic.POOL_PERK
		table.insert(rows, {
			id = perk.id,
			icon = if swapped then PerkCardLogic.POOL_ICON else PerkCardLogic.icon(perk.id),
			title = perk.name .. " · " .. station(perk),
			text = perk.text,
			owned = true,
		})
	end
	local nextPerk: Perk? = StationPerks.nextAfter(tier)
	if nextPerk and LateTiers.tierOpen(nextPerk.tier) then
		table.insert(rows, {
			id = nextPerk.id,
			icon = PerkCardLogic.LOCK,
			title = station(nextPerk) .. " perk",
			text = ("Opens at Tier %d"):format(nextPerk.tier),
			owned = false,
		})
	end
	return rows
end

-- The rank up window's teaser for what the next tier's station brings, or nil when it brings none.
function PerkCardLogic.teaser(tier: number?, pool: boolean?): string?
	local perk: Perk? = StationPerks.at((tier or 1) + 1)
	if perk == nil or not LateTiers.tierOpen(perk.tier) then
		return nil
	end
	local swapped = pool == true and perk.id == PerkCardLogic.POOL_PERK
	-- short enough for one line in the tall window; "Your perks" and the Unlocked card carry the perk's own line
	return ("%s New station: %s (%s perk)"):format(
		if swapped then PerkCardLogic.POOL_ICON else PerkCardLogic.icon(perk.id),
		if swapped then PerkCardLogic.POOL_STATION else perk.station,
		perk.name
	)
end

return PerkCardLogic
