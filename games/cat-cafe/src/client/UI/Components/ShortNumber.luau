--!strict
-- Big numbers made short for the HUD counters and every price (golden-fish.md section 1, Derek 2026-10-27: "changing
-- to K/M/B/T or whatever currency so it doesn't flow off screen"). Exact with commas below 100,000, then K, M, B,
-- T, Qa and Qi with up to three digits. The number is cut down, never rounded up (1,999,999 shows 1.99M, not 2M),
-- so a counter never shows more than the player has. Pure: no Theme, so the cloud spec runner can load it.

local ShortNumber = {}

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi" }
local EXACT_BELOW = 100000

-- 1234567 -> "1,234,567". Whole numbers only: a fraction is cut off.
function ShortNumber.commas(n: number): string
	local whole = tostring(math.floor(math.abs(n)))
	local out = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return if n <= -1 then "-" .. out else out
end

-- 8420 -> "8,420", 1240000 -> "1.24M", 1999999 -> "1.99M", 12345678 -> "12.3M", 123456789 -> "123M".
function ShortNumber.format(n: number): string
	if n ~= n then
		return "0" -- NaN never reaches a counter as "nan"
	end
	local sign = if n <= -1 then "-" else ""
	local whole = math.floor(math.abs(n))
	if whole < EXACT_BELOW or whole == math.huge then
		return if whole == math.huge then sign .. "∞" else sign .. ShortNumber.commas(whole)
	end
	local index = 1
	while index < #SUFFIXES and whole >= 1000 ^ (index + 1) do
		index += 1
	end
	local unit = 1000 ^ index
	local head = (whole - whole % unit) / unit -- the digits before the point
	if head >= 1000 then
		return sign .. ShortNumber.commas(head) .. SUFFIXES[index] -- past Qi the digits keep their commas
	end
	local decimals = if head < 10 then 2 elseif head < 100 then 1 else 0
	local step = unit / 10 ^ decimals
	-- whole - whole % step is exact, so the cut never rounds up through floating point
	local scaled = (whole - whole % step) / step
	local text = tostring(math.floor(scaled))
	if decimals > 0 then
		local point = #text - decimals
		local fraction = text:sub(point + 1):gsub("0+$", "")
		text = text:sub(1, point) .. (if fraction ~= "" then "." .. fraction else "")
	end
	return sign .. text .. SUFFIXES[index]
end

return ShortNumber
