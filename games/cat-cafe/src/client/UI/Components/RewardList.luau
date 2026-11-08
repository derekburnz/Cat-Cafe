--!strict
-- #2479 (Derek2 2026-11-08: "rewards bubbles when claiming index or quests with a lot of claims from the claim all make
-- it look so cluttered"): a reward toast the server writes as "<title>: <reward>, <reward>, ..." (ClaimAll.merge's
-- lines, money already totalled into one since #2481) shows its title on one line and the rewards as a wrapped row
-- of little chips, each with a picture, instead of one long sentence. Screens/Toasts draws it.
--   split(text) -> (title, items)?   the title and the rewards when there are at least MIN_ITEMS, else nil
--   icon(item) -> string             the chip's picture: 💰 money, 🐟 golden fish, 📦 a crate, 🎡 spins, ...
--   lifetime(count, base) -> number  seconds the toast stays: base, a little more a reward past MIN_ITEMS, at most MAX
-- Pure, so the cloud spec runner checks it.

local RewardList = {}

RewardList.MIN_ITEMS = 3 -- fewer fit one line as they are
RewardList.PER_ITEM = 0.3 -- seconds more a reward past MIN_ITEMS
RewardList.MAX_LIFETIME = 5
RewardList.DEFAULT_ICON = "🎁"

-- First match wins; each is a plain substring of the reward's words (lowercased) or its leading money sign.
local ICONS: { { string } } = {
	{ "golden fish", "🐟" },
	{ "crate", "📦" },
	{ "spin", "🎡" },
	{ "luck", "🍀" },
	{ "faster", "⚡" },
	{ "potion", "🧪" },
	{ "xp", "⭐" },
	{ "decor", "🌿" }, -- not 🪴 (Unicode 13), drawn blank (#2015)
	{ "cat", "🐱" },
}

function RewardList.split(text: string): (string?, { string }?)
	local title, rest = string.match(text, "^([^:]+): (.+)$")
	if title == nil or rest == nil then
		return nil, nil
	end
	local items: { string } = {}
	-- ", " (a comma and a space) splits; "+$1,234" keeps its comma as no space follows it
	for item in string.gmatch(rest .. ", ", "(.-), ") do
		if item ~= "" then
			table.insert(items, item)
		end
	end
	if #items < RewardList.MIN_ITEMS then
		return nil, nil
	end
	return title, items
end

function RewardList.icon(item: string): string
	if string.match(item, "^%+?%$") then
		return "💰"
	end
	local lower = string.lower(item)
	for _, pair in ICONS do
		if string.find(lower, pair[1], 1, true) then
			return pair[2]
		end
	end
	return RewardList.DEFAULT_ICON
end

function RewardList.lifetime(count: number, base: number): number
	local extra = math.max(0, count - RewardList.MIN_ITEMS) * RewardList.PER_ITEM
	return math.min(base + extra, math.max(base, RewardList.MAX_LIFETIME))
end

return RewardList
