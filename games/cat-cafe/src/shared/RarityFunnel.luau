--!strict
-- #3876 (Derek 2026-11-13: "create a funnel for top rarity of cats found ex: Found a common or better, found a rare or
-- better, found a epic,legendary,mythic,secret and put this out with the secret update"): rarity_v1, one run per
-- player (the user id is its funnel session). Step n is "the best cat in the save's Index is this rarity or better",
-- so a player whose best is Epic has steps 1 to 3 and the report reads straight down. It is read off the lifetime
-- Index (`collection`, which never loses an entry), so a save from before the funnel logs its steps on its next join.
-- Telemetry logs it only while the `secretCats` switch (Catching.SECRET_FLAG) is on, so it starts with that update.
-- Pure: Telemetry keeps the step logged this session and logs what `due` returns.

local Catalog = require(script.Parent.Catalog)

local RarityFunnel = {}

RarityFunnel.NAME = "rarity_v1"
RarityFunnel.STEPS = table.freeze({
	"found_common",
	"found_rare_plus",
	"found_epic_plus",
	"found_legendary_plus",
	"found_mythical_plus",
	"found_secret",
})

-- The best rarity rank (Catalog.rarityRank: Common 1 up to Secret 6) of the cats in `collection`, 0 with none.
function RarityFunnel.best(collection: { [string]: number }): number
	local best = 0
	for catId in collection do
		local def = Catalog.getCat(catId)
		local rank = if def ~= nil then Catalog.rarityRank[def.rarity] or 0 else 0
		if rank > best then
			best = rank
		end
	end
	return math.min(best, #RarityFunnel.STEPS)
end

-- The steps to log, in order, when `logged` steps are already out and the best rank is `best`.
function RarityFunnel.due(logged: number, best: number): { number }
	local out = {}
	for step = logged + 1, math.min(best, #RarityFunnel.STEPS) do
		table.insert(out, step)
	end
	return out
end

return RarityFunnel
