--!strict
-- The "Keeps up" tag (F86, data-model v0.13.16 section 4b; Derek 2026-10-28 13:55: "make it so legendarys / mythics
-- in the previous areas still hold decent value across areas and don't instantly become useless next area"): a
-- Legendary or Mythical from an older area earns as if it came from the area one step behind the owner's newest.
--   keepsUp(def, tier)  whether that lifts the cat above its own area's pay (CatStats.areaMultiplier with and
--                       without the tier), so the tag shows
--   tip(tier)           "Earns like a Woods cat now that you have reached the Sewer."
-- The kept-up income itself is the server's CatView rating. Pure, so the cloud spec runner checks it.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CatStats = require(Shared:WaitForChild("CatStats"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local Types = require(script.Parent.Parent.Types)

local KeepUp = {}

KeepUp.TAG = "Keeps up"

function KeepUp.keepsUp(def: Types.CatDef?, tier: number?): boolean
	if def == nil or tier == nil then
		return false
	end
	return CatStats.areaMultiplier(def, tier) > CatStats.areaMultiplier(def) + 1e-9
end

-- The area a tier opens, as CatStats.areaMultiplier looks it up.
local function opensAt(tier: number): Types.AreaDef?
	for _, area in Catalog.areas do
		if area.tier == tier then
			return area
		end
	end
	return nil
end

-- The newest area the tier has opened.
local function newest(tier: number): Types.AreaDef?
	local best: Types.AreaDef? = nil
	for _, area in Catalog.areas do
		if area.tier <= tier and (best == nil or area.tier > best.tier) then
			best = area
		end
	end
	return best
end

function KeepUp.tip(tier: number): string?
	local whole = math.floor(tier)
	local like = opensAt(math.max(whole - Config.KeepUpStepsBehind, 1))
	local reached = newest(whole)
	if like == nil or reached == nil then
		return nil
	end
	local article = if like.name:match("^[AEIOUaeiou]") then "an" else "a"
	return ("Earns like %s %s cat now that you have reached the %s."):format(
		article,
		like.name,
		reached.name
	)
end

return KeepUp
