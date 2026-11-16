--!strict
-- Which models only the server ever clones (#3743, #3790). Everything under ReplicatedStorage.Assets is sent to every
-- client as it joins and stays in its memory. The big world pieces (area kit sets, backdrop rings, camp sets, gates,
-- night fences, nooks, the Alleyway's buildings and blockers, the cafe shells, the Town Square's arches and paving)
-- are cloned into Workspace by the server alone, so their templates are moved to ServerStorage at start-up
-- (AssetRegistry.stowServerOnly) and no client downloads or keeps them.
--
-- A name belongs here only when no client script looks its template up, by a written name or a built one. The
-- client builds names from these stems, so nothing under them may ever match (but a cat's _Work body, which no
-- client names, #4601): CatCafe_Cat_, _Accessory_, _Decor_,
-- _Style_, _Menu_, _Door_, _CatFlap_, _Item_, _Prop_, _NPC_, _Lawn_, _Furniture_, CatCafe_Camp_<Area>_<Station>,
-- and CatCafe_Camp_<Area>_Growth. The spec pins both sides.

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
	-- #4601 (players leaving right after joining; every client downloads ReplicatedStorage.Assets before play): the
	-- world pieces WorldBuilder and the station services place and no client or shared script names, by a written
	-- name or a built stem (audited 2026-11-15 against every string in src/client and src/shared): the Town Square's
	-- and the street's stations and dressing, the old Alley, Park and Sewer props, the Index Boards and a plot's
	-- room dressing. About 8,000 instances less for every client. A station's _RingIcon_Decor stays (the ring art).
	CatCafe_Alley_CardboardBox = true,
	CatCafe_Alley_Crate = true,
	CatCafe_Alley_CrateStack = true,
	CatCafe_Alley_Dumpster = true,
	CatCafe_Alley_GarbageBags = true,
	CatCafe_Alley_IndexBoard = true,
	CatCafe_Alley_LaundryLine = true,
	CatCafe_Alley_Pallet = true,
	CatCafe_Alley_Puddle = true,
	CatCafe_Alley_ShopWindow = true,
	CatCafe_Alley_StreetLamp = true,
	CatCafe_Alley_StringLightsLong = true,
	CatCafe_Alley_StringLightsWide = true,
	CatCafe_Alley_TrashBin = true,
	CatCafe_Alley_TrashCan = true,
	CatCafe_Desert_IndexBoard = true,
	CatCafe_Neighbourhood_IndexBoard = true,
	CatCafe_Park_Bench = true,
	CatCafe_Park_Fountain = true,
	CatCafe_Park_IndexBoard = true,
	CatCafe_Park_RescueTree = true,
	CatCafe_Park_TrashCan = true,
	CatCafe_Park_Tree = true,
	CatCafe_Plot_ForRent = true,
	CatCafe_Plot_Interior = true,
	CatCafe_Plot_Tier1 = true,
	CatCafe_Plot_Tier2 = true,
	CatCafe_Plot_Tier3 = true,
	CatCafe_Plot_Tier4 = true,
	CatCafe_Plot_Tier5 = true,
	CatCafe_Plot_YardFence = true,
	CatCafe_Ruins_IndexBoard = true,
	CatCafe_Sewer_IndexBoard = true,
	CatCafe_Sewer_Manhole = true,
	CatCafe_Snowy_IndexBoard = true,
	CatCafe_Square_Bench = true,
	CatCafe_Square_Bunting = true,
	CatCafe_Square_BuntingShort = true,
	CatCafe_Square_BuntingSide = true,
	CatCafe_Square_DecorStand = true,
	CatCafe_Square_Fountain = true,
	CatCafe_Square_Garden = true,
	CatCafe_Square_GardenEnd = true,
	CatCafe_Square_GardenMid = true,
	CatCafe_Square_Lamp = true,
	CatCafe_Square_LandingPad = true,
	CatCafe_Square_MysteryCart = true,
	CatCafe_Square_MysterySign = true,
	CatCafe_Square_PitySign = true,
	CatCafe_Square_RallyBoard = true,
	CatCafe_Square_RallyBunting = true,
	CatCafe_Square_RallyBuntingShort = true,
	CatCafe_Square_RallyBuntingSide = true,
	CatCafe_Square_UpdatePoster = true,
	CatCafe_Street_BellhopStand = true,
	CatCafe_Street_CodesCat = true,
	CatCafe_Street_DealerCart = true,
	CatCafe_Street_FishMarket = true,
	CatCafe_Street_SpinWheel = true,
	CatCafe_Street_ThanksBoard = true,
	CatCafe_Town_DayCart = true,
	CatCafe_Town_LeaderboardRow = true,
	CatCafe_Woods_IndexBoard = true,
}

-- #4601 (Motion-FX audit of src/client and src/shared): the camp stations, 14 models and about 3,850 instances.
-- WorldBuilder places each one through AssetRegistry; every client script reads the placed model in Workspace by its
-- tag (WalkUpController, BinController, SpaPoolController, StationReveal, StationBuild, CampExtras) and none copies
-- a template. The Garden Nursery, Cocoa Stand and Hoard Chest are not placed at all yet. Left with the client: the
-- gold Fishing Hut (GoldHutController reads its looks from the template), the Spa towel (SpaPoolController clones
-- it) and every camp's Growth model (Effects/CampGrowth clones it).
local STATIONS: { [string]: boolean } = {
	CatCafe_Camp_Alley_RummageBin = true,
	CatCafe_Camp_Park_PicnicStation = true,
	CatCafe_Camp_Park_MysticPool = true,
	CatCafe_Camp_Park_GardenNursery = true,
	CatCafe_Camp_Neighbourhood_YardSaleStall = true,
	CatCafe_Camp_Woods_FishingHut = true,
	CatCafe_Camp_Sewer_LostFoundBooth = true,
	CatCafe_Camp_Desert_OasisSpa = true,
	CatCafe_Camp_Ruins_RelicMuseum = true,
	CatCafe_Camp_Snowy_CocoaStand = true,
	CatCafe_Camp_Snowy_FusionObservatory = true,
	CatCafe_Camp_WaterPark_TicketBooth = true,
	CatCafe_Camp_Castle_DragonKeep = true,
	CatCafe_Camp_Castle_HoardChest = true,
}

-- `name` is `stem` alone or `stem` plus a version tag.
local function tagged(name: string, stem: string): boolean
	return name == stem or string.match(name, "^" .. stem .. TAG .. "$") ~= nil
end

function ServerOnlyAssets.matches(name: string): boolean
	if EXACT[name] then
		return true
	end
	-- #4543: the cafe at its bigger room sizes (the shell, interior, For Rent and tier dressing and the yard fence,
	-- CatCafe_Plot_<model>_<W>x<D>). Only WorldBuilder places a plot's room, so no client looks these up, and
	-- there are 48 of them: none may ride along to every phone.
	if string.match(name, "^CatCafe_Plot_[%w_]+_%d+x%d+$") ~= nil then
		return true
	end
	-- #4601: the standing worker body of every cat (CatCafe_Cat_<Name>_Work and its _Gold_Work twin). Only the
	-- server dresses a working cat at its station (AssetRegistry.cloneCat "work"); every client copy of a cat is
	-- the walking body or the seated one (portraits, the Index, cafe walkers, the intro). 131 base models, about
	-- 16,000 instances, a fifth of what a client downloads once the gold twins are stowed.
	if
		string.match(name, "^CatCafe_Cat_%w+_Work$") ~= nil
		or string.match(name, "^CatCafe_Cat_%w+_Gold_Work$") ~= nil
	then
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
	if STATIONS[name] then
		return true
	end
	-- #4601: the Cat Cannons (the Town Square's and each camp's, 11 models and about 4,100 instances). WorldBuilder
	-- places them; the client's Effects/Cannon finds the placed model in Workspace by its name and never copies a
	-- template.
	if name == "CatCafe_Square_Cannon" then
		return true
	end
	for _, area in AREAS do
		if name == "CatCafe_Camp_Cannon_" .. area then
			return true
		end
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
