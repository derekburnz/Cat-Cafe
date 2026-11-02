--!strict
-- The cat hover card's words and numbers (F75, data-model section 4b v0.12): the name lines, the role line, the
-- level and XP line and the gamepad's nearest cat. Pure, so the cloud spec runner checks it. The level up toast went
-- on 2026-11-02 (Derek: "no need for that").
-- Levels and XP come from shared/CatStats and Config, so the card follows the engineer's CatMaxLevel (50 in v0.12).
-- No Theme or Format here (Theme builds Fonts, which the spec runner has not got), so the two text helpers are local.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatStats = require(Shared:WaitForChild("CatStats")) :: any
local Config = require(Shared:WaitForChild("Config")) :: any

local CatCardLogic = {}

CatCardLogic.GAMEPAD_STUDS = 8 -- on gamepad the card shows for the nearest own cat this close
CatCardLogic.TOUCH_SECONDS = 4 -- a tapped card closes by itself after this long

-- 1440 -> "1,440" (Format.commas, for whole numbers 0 and up)
local function commas(n: number): string
	local text = tostring(math.max(0, math.floor(n)))
	return (text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

-- "barista" -> "Barista" (Format.roleName)
local function roleName(role: string): string
	return role:sub(1, 1):upper() .. role:sub(2)
end

-- The big line and the small one under it: "Biscuit" over "Pirate Cat" for a named cat, else the catalog name alone.
function CatCardLogic.names(custom: string?, catalogName: string): (string, string?)
	if custom and custom ~= "" and custom ~= catalogName then
		return custom, catalogName
	end
	return catalogName, nil
end

function CatCardLogic.levelText(level: number): string
	return ("Level %d"):format(math.floor(level))
end

-- The XP line and the bar's share: "340 / 1,440 XP" and 340/1440, or "MAX" and a full bar at the top level.
-- `xpToNext` is the server's when ProfileSync sends it, else CatStats works it out from Config.
function CatCardLogic.xp(level: number, xp: number, xpToNext: number?): (string, number)
	if level >= Config.CatMaxLevel then
		return "MAX", 1
	end
	local need = if type(xpToNext) == "number" and xpToNext > 0
		then xpToNext
		else CatStats.xpToNext(level)
	if need <= 0 then
		return "MAX", 1
	end
	local have = math.clamp(math.floor(xp), 0, need)
	return ("%s / %s XP"):format(commas(have), commas(need)), have / need
end

-- The role line and whether it is the cat's favourite role (the card adds a heart): "Barista", or "Resting".
-- F79 bedtime: a working cat asleep on its spot at night reads "Barista · Asleep".
function CatCardLogic.role(
	role: string?,
	favoriteRole: string?,
	asleep: boolean?
): (string, boolean)
	if role == nil or role == "" then
		return "Resting", false
	end
	local name = roleName(role)
	return if asleep then name .. " · Asleep" else name, role == favoriteRole
end

-- The key of the point nearest `from` within `radius` studs, or nil.
function CatCardLogic.nearest<K>(from: Vector3, points: { [K]: Vector3 }, radius: number): K?
	local best: K? = nil
	local bestDistance = radius
	for key, point in points do
		local distance = (point - from).Magnitude
		if distance <= bestDistance then
			best = key
			bestDistance = distance
		end
	end
	return best
end

return CatCardLogic
