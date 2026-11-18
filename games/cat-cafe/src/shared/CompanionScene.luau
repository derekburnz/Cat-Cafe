--!strict
-- #5284 (Derek 2026-11-18: "make the cat companion ... to unlock at tier 2 with a scene make sure it doesn't overlap
-- other cutscenes"; Design-Agent's companion-scene-5284 spec): once per account, after the rank up to
-- Follower.OPEN_TIER, the best cat the player owns becomes their Cat Companion (the follower, #5172) in a short scene
-- (client/Controllers/CompanionSceneController and Motion-FX's Effects/CompanionUnlockCut), then a card and a soft
-- arrow on Cats. The scene waits until nothing else holds the screen. The key goes into tipsSeen (TipSeen), so it
-- plays once. `companionScene` (LiveFlags, off by default) false plays nothing. Pure.

local Catalog = require(script.Parent.Catalog)
local Follower = require(script.Parent.Follower)
local Types = require(script.Parent.Types)

local CompanionScene = {}

CompanionScene.FLAG = "companionScene"
CompanionScene.KEY = "companion_unlock" -- the tipsSeen key
CompanionScene.NAME = "Cat Companion" -- the noun players read (Design-Agent); code keeps `follower`

-- Whether the rank up to `tier` should play the scene: the switch and the follower's own switch on, the tier the one
-- that opens followers, and the account has not seen it (`seen` is tipsSeen).
function CompanionScene.due(
	tier: unknown,
	seen: { [string]: boolean }?,
	on: boolean,
	followerOn: boolean
): boolean
	if not on or not followerOn or tier ~= Follower.OPEN_TIER then
		return false
	end
	return not (seen ~= nil and seen[CompanionScene.KEY] == true)
end

local COATS = { rainbow = 3, gold = 2 } :: { [string]: number }

-- The cat to make the companion (Design-Agent): the highest rarity, then the better coat, then the higher level, then
-- the newest caught; ties by uid so the pick is the same every time. Nil with no cats.
function CompanionScene.pick(cats: { [string]: Types.CatInstance }?): string?
	if cats == nil then
		return nil
	end
	local best: Types.CatInstance? = nil
	local function score(cat: Types.CatInstance): { number }
		local def = Catalog.getCat(cat.catId)
		local rank = if def ~= nil then Catalog.rarityRank[def.rarity] or 0 else 0
		return { rank, COATS[cat.variant] or 1, cat.level or 1, cat.caughtAt or 0 }
	end
	local bestScore: { number } = {}
	for uid, cat in cats do
		if type(uid) == "string" and type(cat) == "table" and Catalog.getCat(cat.catId) ~= nil then
			local s = score(cat)
			local better = best == nil
			if not better then
				for i = 1, #s do
					if s[i] ~= bestScore[i] then
						better = s[i] > bestScore[i]
						break
					end
					if i == #s then
						better = uid < (best :: Types.CatInstance).uid
					end
				end
			end
			if better then
				best = cat
				bestScore = s
			end
		end
	end
	return if best ~= nil then best.uid else nil
end

-- The card's line under the title: "Mittens walks with you everywhere. +5% money"
function CompanionScene.line(name: string, perk: string?): string
	local text = name .. " walks with you everywhere."
	if perk ~= nil and perk ~= "" then
		text ..= " " .. perk
	end
	return text
end

return CompanionScene
