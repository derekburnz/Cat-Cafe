--!strict
-- Which models only the server ever clones (#3743, #3790). Everything under ReplicatedStorage.Assets is sent to every
-- client as it joins and stays in its memory. The big world pieces (area kit sets, backdrop rings, camp sets, gates,
-- night fences, nooks, the Alleyway's buildings and blockers, the cafe shells, the Town Square's arches and paving)
-- are cloned into Workspace by the server alone, so their templates are moved to ServerStorage at start-up
-- (AssetRegistry.stowServerOnly) and no client downloads or keeps them.
--
-- A name belongs here only when no client script looks its template up, by a written name or a built one. The
-- client builds names from these stems, so nothing under them may ever match: CatCafe_Cat_, _Accessory_, _Decor_,
-- _Style_, _Menu_, _Door_, _CatFlap_, _Item_, _Prop_, _NPC_, _Lawn_, _Furniture_, CatCafe_Camp_<Area>_<Station>,
-- CatCafe_Camp_<Area>_Growth and CatCafe_Camp_Cannon. The spec pins both sides.

local ServerOnlyAssets = {}

-- an optional version tag: one capital and digits (F85, V32)
local TAG = "%u%d+"

-- #4070: the Snowy Mountain's and the Water Park's too (their camps, nooks, gates and night fences; no client script
-- looks those templates up)
local AREAS = {
	"Alleyway",
	"Park",
	"Neighbourhood",
	"Woods",
	"Sewer",
	"Desert",
	"Ruins",
	"Snowy",
	"WaterPark",
	"Castle", -- #4184
}

-- CatCafe_<word>_<kind>, alone or with a version tag, for any one word (an area, Town)
local ANY_AREA_KINDS = { "Set", "Backdrop" }
-- CatCafe_<Area>_<kind>, alone or with a version tag, for the areas and the Alleyway's short name
local AREA_KINDS = { "Gate", "NightFence" }
-- families where every model is a world piece: CatCafe_<stem><one word>
local FAMILIES = { "Alley_Blocker_", "Alley_Building_" }

local EXACT: { [string]: boolean } = {
	CatCafe_Alley_NightFence = true,
	CatCafe_Alley_NightFenceSegment = true,
	CatCafe_Alley_Arch = true,
	CatCafe_Alley_ArchStreet = true,
	CatCafe_Alley_Mural = true,
	CatCafe_Alley_FireEscape = true,
	CatCafe_Alley_WallDoor = true,
	CatCafe_Alley_WallWindows = true,
	CatCafe_Square_Paving = true,
	CatCafe_Square_SignArch = true,
	CatCafe_Square_ArchAlley = true,
	CatCafe_Town_WelcomeArch = true,
	CatCafe_Plot_Cafe_Mint = true,
	CatCafe_Plot_Cafe_Lilac = true,
	CatCafe_Plot_Cafe_Butter = true,
	CatCafe_Plot_Cafe_Blush = true,
}

-- `name` is `stem` alone or `stem` plus a version tag.
local function tagged(name: string, stem: string): boolean
	return name == stem or string.match(name, "^" .. stem .. TAG .. "$") ~= nil
end

function ServerOnlyAssets.matches(name: string): boolean
	if EXACT[name] then
		return true
	end
	for _, kind in ANY_AREA_KINDS do
		local stem = "^CatCafe_%a+_" .. kind
		if
			string.match(name, stem .. "$") ~= nil
			or string.match(name, stem .. TAG .. "$") ~= nil
		then
			return true
		end
	end
	for _, family in FAMILIES do
		if string.match(name, "^CatCafe_" .. family .. "%w+$") ~= nil then
			return true
		end
	end
	for _, area in AREAS do
		-- the camp set (CatCafe_Camp_Park, CatCafe_Camp_ParkF85), never a camp's station or growth model
		if tagged(name, "CatCafe_Camp_" .. area) or name == "CatCafe_Nook_" .. area then
			return true
		end
		for _, kind in AREA_KINDS do
			if tagged(name, "CatCafe_" .. area .. "_" .. kind) then
				return true
			end
		end
	end
	return false
end

return ServerOnlyAssets
