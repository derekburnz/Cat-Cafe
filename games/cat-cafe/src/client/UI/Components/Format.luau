--!strict
-- Number and text formatting shared by all screens.

local Theme = require(script.Parent.Parent.Theme)

local Format = {}

local function commas(n: number): string
	local whole = tostring(math.floor(math.abs(n) + 0.5))
	local out = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	if n < 0 then
		return "-" .. out
	end
	return out
end
Format.commas = commas

-- 8420 -> "8,420", 1_240_000 -> "1.24M", 2_500_000_000 -> "2.5B"
function Format.short(n: number): string
	local abs = math.abs(n)
	local sign = if n < 0 then "-" else ""
	if abs < 100000 then
		return sign .. commas(abs)
	end
	local suffixes = { "K", "M", "B", "T" }
	local value = abs
	local index = 0
	while value >= 1000 and index < #suffixes do
		value /= 1000
		index += 1
	end
	local text = string.format(if value >= 100 then "%.0f" else "%.1f", value)
	text = text:gsub("%.0$", "")
	return sign .. text .. suffixes[index]
end

function Format.money(n: number): string
	return Theme.currencySymbol .. Format.short(n)
end

function Format.rate(perSecond: number): string
	local value = if perSecond >= 10
		then string.format("%.0f", perSecond)
		else string.format("%.1f", perSecond)
	value = value:gsub("%.0$", "")
	return "+" .. Theme.currencySymbol .. value .. "/s"
end

-- 3725 -> "1h 2m", 95 -> "1m 35s", 12 -> "12s"
function Format.duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	local secs = seconds % 60
	if hours > 0 then
		return string.format("%dh %dm", hours, minutes)
	elseif minutes > 0 then
		return string.format("%dm %ds", minutes, secs)
	end
	return string.format("%ds", secs)
end

function Format.level(level: number): string
	return "Lv " .. tostring(level)
end

local AREA_NAMES: { [string]: string } = {
	alley = "Alleyway",
	park = "Park",
	neighbourhood = "Neighbourhood",
	woods = "Woods",
	sewer = "Sewer",
}

-- "park" -> "Park" (data-model section 9 names), unknown ids are capitalised
function Format.areaName(areaId: string): string
	return AREA_NAMES[areaId] or (areaId:sub(1, 1):upper() .. areaId:sub(2))
end

-- 2 -> "Tier 2", or "Tier 2 · Cozy Cafe" when the catalog's tiers are given (data-model section 5b)
function Format.tier(tier: number, tiers: { any }?): string
	local text = "Tier " .. tostring(tier)
	if tiers then
		for _, def in tiers :: { any } do
			if def.tier == tier and type(def.name) == "string" then
				return text .. " · " .. def.name
			end
		end
	end
	return text
end

-- "barista" -> "Barista" (role display names are the ids capitalised for now)
function Format.roleName(role: string): string
	return role:sub(1, 1):upper() .. role:sub(2)
end

-- 3 -> "★★★☆☆" (always five glyphs so rows line up)
function Format.stars(stars: number, max: number?): string
	local total = max or 5
	local filled = math.clamp(math.floor(stars + 0.5), 0, total)
	return string.rep("★", filled) .. string.rep("☆", total - filled)
end

return Format
