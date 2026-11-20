--!strict
-- Cat Cafe client effects (vfx-animator): cat motion, the Legendary and Mythical cats' signature effects, catch
-- reactions, the getaway and the startled stars, cafe and gate moments, dusk and sunrise, ambient life, shoves, the
-- players' tackle poses, the spin wheel, the Codes Cat's circle, crate openings, golden fish, the Mythical cafe styles,
-- potion glows, the Mystery Visitor, cat level ups, the red "!" over stuck cats, the green flash on decor you put out,
-- the rarity gems over strays, splashes in water, the intro's puff, the Cat Cannon's flight, clouds and camp
-- check-in, the campfires' moving flames, the big confetti pull for a Legendary or Mythical, the clouds in the sky,
-- the rainbow coats, the Rescue Rally's pops and bunting, Trade done's flight, rare decor's moving parts, the net
-- swing's whoosh, the catch's result word, the rescue trap's shake, the Bellhop Cat's bell, cap and hop, the Lucky
-- Cat statue and its beckoning paw, the Lucky Day's gold tint, the big pull's happy hop, the camp extras' rod and
-- lid, the camp pipe's drips, the pond's jumping fish, the camp extras' collect bursts, the pal wave at a front door,
-- the cafe orders' steam, flour, oven glow and ding, the leaderboard crown's glint, the shop cats' own effects, the door
-- sign's OPEN by day and CLOSED at night and the camp stations' ready glows, all on this client only.
-- Effects read replicated world state (tags and attributes) and this player's own events; they never fire a remote,
-- never change game state and never move a part the server moves for gameplay. Rules:
-- .claude/skills/animation-vfx/SKILL.md.
-- Wiring and file map: README.md next to this file.

local AdminAir = require(script.AdminAir)
local AdminDrops = require(script.AdminDrops)
local AdminFlash = require(script.AdminFlash)
local AdventFx = require(script.AdventFx)
local Ambient = require(script.Ambient)
local ArcadeGlow = require(script.ArcadeGlow)
local ArcadeScreen = require(script.ArcadeScreen)
local AreaFx = require(script.AreaFx)
local AreaWater = require(script.AreaWater)
local BaitCrumbs = require(script.BaitCrumbs)
local BedWalk = require(script.BedWalk)
local Bellhop = require(script.Bellhop)
local BigTraitCut = require(script.BigTraitCut)
local BoothFx = require(script.BoothFx)
local BowlFrenzyFx = require(script.BowlFrenzyFx)
local BulbChase = require(script.BulbChase)
local CafeWalk = require(script.CafeWalk)
local CampCoinFly = require(script.CampCoinFly)
local CampCollect = require(script.CampCollect)
local CampExtras = require(script.CampExtras)
local CampGlow = require(script.CampGlow)
local CampGrowth = require(script.CampGrowth)
local CampWater = require(script.CampWater)
local Campfire = require(script.Campfire)
local Cannon = require(script.Cannon)
local CannonCue = require(script.CannonCue)
local CannonGlide = require(script.CannonGlide)
local CatNames = require(script.CatNames) -- #5586
local Catch = require(script.Catch)
local CatchReact = require(script.CatchReact)
local Cats = require(script.Cats)
local Chase = require(script.Chase)
local Codes = require(script.Codes)
local Context = require(script.Context)
local ContextCut = require(script.ContextCut)
local Crown = require(script.Crown)
local Decor = require(script.Decor)
local DoorSign = require(script.DoorSign)
local DragonStageCut = require(script.DragonStageCut)
local Equip = require(script.Equip)
local FireTrail = require(script.FireTrail)
local FirstBaitCut = require(script.FirstBaitCut)
local FirstMinuteFx = require(script.FirstMinuteFx)
local Fish = require(script.Fish)
local Follower = require(script.Follower)
local FusionFx = require(script.FusionFx)
local GoldenFind = require(script.GoldenFind)
local GrandOpening = require(script.GrandOpening)
local GuideArrow = require(script.GuideArrow)
local HarvestFx = require(script.HarvestFx)
local HoldPulse = require(script.HoldPulse)
local Intro = require(script.Intro)
local IntroCut = require(script.IntroCut)
local KeepDragon = require(script.KeepDragon)
local KeepSets = require(script.KeepSets)
local LateStationFx = require(script.LateStationFx)
local Lawn = require(script.Lawn)
local Levels = require(script.Levels)
local LoadGate = require(script.LoadGate)
local LuckyCat = require(script.LuckyCat)
local LuckyPaw = require(script.LuckyPaw)
local Market = require(script.Market)
local MoneyBag = require(script.MoneyBag)
local Motion = require(script.Motion)
local MuseumPlaques = require(script.MuseumPlaques)
local Mystery = require(script.Mystery)
local NetPin = require(script.NetPin)
local NetTrail = require(script.NetTrail)
local Orders = require(script.Orders)
local PalDayFx = require(script.PalDayFx)
local PalWave = require(script.PalWave)
local PassThanks = require(script.PassThanks)
local PawTrail = require(script.PawTrail)
local PetCat = require(script.PetCat)
local PicnicParty = require(script.PicnicParty)
local Pity = require(script.Pity)
local Plots = require(script.Plots)
local PoolBeacon = require(script.PoolBeacon)
local Potions = require(script.Potions)
local Pull = require(script.Pull)
local PullHop = require(script.PullHop)
local Rainbow = require(script.Rainbow)
local Rally = require(script.Rally)
local RankUpPulse = require(script.RankUpPulse)
local Rarity = require(script.Rarity)
local Rescue = require(script.Rescue)
local Rides = require(script.Rides)
local RuinsWater = require(script.RuinsWater)
local SecretGlow = require(script.SecretGlow)
local SecretStray = require(script.SecretStray)
local ShopCats = require(script.ShopCats)
local Shove = require(script.Shove)
local Signature = require(script.Signature)
local Sky = require(script.Sky)
local SlotWalk = require(script.SlotWalk)
local SnowglobeFlakes = require(script.SnowglobeFlakes)
local SnowglobeFx = require(script.SnowglobeFx)
local SpeedShoes = require(script.SpeedShoes)
local Splash = require(script.Splash)
local StationBuild = require(script.StationBuild)
local StationCircles = require(script.StationCircles)
local StationMotion = require(script.StationMotion)
local StationReveal = require(script.StationReveal)
local StormFall = require(script.StormFall)
local StrayCall = require(script.StrayCall)
local StuckCall = require(script.StuckCall)
local Tackle = require(script.Tackle)
local Themes = require(script.Themes)
local Townsfolk = require(script.Townsfolk)
local Trade = require(script.Trade)
local TrailSparkle = require(script.TrailSparkle)
local Trampoline = require(script.Trampoline)
local WaitingCat = require(script.WaitingCat)
local Wheel = require(script.Wheel)
local WorldGlow = require(script.WorldGlow)
local WowBaitGlow = require(script.WowBaitGlow)

local Effects = {}

local started = false

-- seconds of starts to run before yielding a frame (#2632)
local START_SLICE = 0.008

-- Starts every effect. Safe to call more than once; later calls do nothing. Returns at once: the starts run over
-- the next frames (#2632).
function Effects.start()
	if started then
		return
	end
	started = true
	Context.init()
	-- #2632 (live "Script has run for over 15 seconds"): about 55 starts, many scanning the whole map, ran back to
	-- back with no yield; they now run a few at a time, yielding a frame whenever one slice passes START_SLICE
	local function cannonStart()
		Cannon.setGlide(CannonGlide)
		Cannon.start()
	end
	local starts: { () -> () } = {
		Cats.start,
		CafeWalk.start,
		BedWalk.start,
		Follower.start, -- #5172: the cat follower's walk, hop, loaf and groom, and its puff
		Bellhop.start,
		LuckyPaw.start,
		PullHop.start,
		CampExtras.start,
		PalWave.start,
		PalDayFx.start, -- #4913: the Pal Day gift's waves and hearts
		PetCat.start,
		Signature.start,
		Catch.start,
		CatchReact.start,
		Chase.start,
		Plots.start,
		Ambient.start,
		Shove.start,
		Tackle.start,
		Wheel.start,
		Codes.start,
		Market.start,
		Fish.start,
		Decor.start,
		Equip.start,
		Potions.start,
		SpeedShoes.start,
		FireTrail.start, -- #4558: the Dragon Keep's Fire Trail card, embers at the heels
		Pull.start,
		Mystery.start,
		Levels.start,
		Rarity.start,
		CatNames.start, -- #5586: names over the nearest strays
		SecretStray.start,
		SecretGlow.start,
		BigTraitCut.watchPool, -- #3942: other players' big trait rolls, seen from nearby
		Splash.start,
		Rescue.start,
		StuckCall.start,
		Intro.start,
		IntroCut.start,
		cannonStart,
		Campfire.start,
		Sky.start,
		Rainbow.start,
		Rally.start,
		Trade.start,
		Motion.start,
		Lawn.start,
		NetPin.start,
		NetTrail.start,
		LuckyCat.start,
		CampWater.start,
		CampCollect.start,
		Orders.start,
		Crown.start,
		ShopCats.start,
		PassThanks.start,
		SlotWalk.start,
		Pity.start,
		GrandOpening.start,
		Themes.start,
		DoorSign.start,
		CampGlow.start,
		AreaFx.start,
		LateStationFx.start,
		BoothFx.start, -- #4061: the Ticket Booth's buy moment
		CampCoinFly.start, -- #5533 v2: coins to the counter at the new start's first camp check-ins
		PicnicParty.start, -- #5572: the Picnic Party's ready look, pop, blanket and pack away (picnicParty)
		WorldGlow.start, -- #5533 v2: the new start's world glows (stall, cannon, door)
		AdventFx.start, -- #5502: the advent calendar board's doors, glow and bursts
		DragonStageCut.start, -- #4062: the Dragon Keep stage-up cutscene on each DragonStage
		FusionFx.start, -- #4104: the Fusion Observatory dome's glow and paw lights
		KeepDragon.start, -- #4567: your own stage's dragon stands in the Dragon Keep
		MuseumPlaques.start,
		StationMotion.start,
		Rides.start,
		HoldPulse.start,
		RankUpPulse.start, -- #4920: RANK UP glows when ready, the tutorial strip's count tick
		CannonCue.start, -- the Cannon button's glow while Tier 2 is short of cats (switch cannonCue, off)
		FirstMinuteFx.start, -- first minute: the first bowl cat card's sparkle and jingle, the first net catch's cheer
		BaitCrumbs.start,
		WaitingCat.start,
		ArcadeGlow.start,
		ArcadeScreen.start, -- Derek 2026-11-18: the cabinet's screen plays a little Mouse Dash
		PoolBeacon.start,
		RuinsWater.start,
		AreaWater.start, -- #4070, #4071: the Water Park's pools and river, the Castle's moat and well
		BulbChase.start, -- #4070: the fairground's bulbs chase at night
		StormFall.start, -- #4197: a Cat Storm's strays fall out of the sky
		BowlFrenzyFx.start, -- #4195: a Bowl Frenzy's gold sparkles off the food in your bait bowls
		WowBaitGlow.start, -- #4822: the first wow bowl cat's rarity outline, sparkle and tag
		AdminAir.start, -- #4197: Golden Hour's gold motes and Money Storm's coin glints round you
		AdminDrops.start, -- #4197: Fish Fountain's fish arc out, Crate Drop's crates come down by parachute
		KeepSets.start, -- Dragon Keep set looks from the DragonSets attribute
		StationCircles.start, -- #4668: the walk-up rings hidden unless Station circles is on
		HarvestFx.start, -- #4251: Harvest Hollow's falling leaves and the pumpkin patch's pops
		SnowglobeFx.start, -- Christmas Event: Snowglobe Village's snow and the Town Square globe's swirl (idle until tagged)
		SnowglobeFlakes.start, -- Christmas Event: the Snowflake patch's bob, pick sparkle and "+N Snowflakes" pop
		AdminFlash.start, -- #4325: an admin event's 3, 2, 1, name splash, world tint, strip and end card
		TrailSparkle.start,
		PawTrail.start,
		GuideArrow.start, -- #5465: one arrow by the player in place of the trail, with guideArrow on
		GoldenFind.start,
		MoneyBag.start,
		StationBuild.start,
		StationReveal.start,
		StrayCall.start,
		CampGrowth.start,
		Townsfolk.start,
		Trampoline.start,
	}
	-- #5068 (fxAfterLoad): the few starts the loading screen hands over to (the intro's shots, the cannon, the sky)
	-- run now; the rest wait until the loading screen has gone, so a phone's start-up and the parts streaming in under
	-- the screen do not share frames with ~95 map scans nobody sees yet. Switch off: one list, in this order, as before.
	local early: { [() -> ()]: true } = {
		[Intro.start] = true,
		[IntroCut.start] = true,
		[cannonStart] = true,
		[Sky.start] = true,
	}
	local function run(list: { () -> () })
		local slice = os.clock()
		for _, start in list do
			start()
			if os.clock() - slice > START_SLICE then
				task.wait()
				slice = os.clock()
			end
		end
	end
	local function cuts()
		-- the context tips' camera cuts (#976): the UI calls them once they are handed over
		ContextCut.start(require(script.Parent.UI) :: any)
		-- #2946: the first bait's cutscene; the UI's bait cards wait for it
		FirstBaitCut.start(require(script.Parent.UI) :: any)
	end
	task.spawn(function()
		if not LoadGate.holds() then
			run(starts)
			cuts()
			return
		end
		local now: { () -> () }, later: { () -> () } = {}, {}
		for _, start in starts do
			table.insert(if early[start] then now else later, start)
		end
		run(now)
		LoadGate.whenLoaded(function()
			run(later)
			cuts()
		end)
	end)
end

-- #4311: whether this phone or tablet's frame rate has stayed low this session (under Presets.slow.fps for
-- Presets.slow.windows windows in a row); once true it stays true. The Low performance suggestion can read it.
function Effects.struggling(): boolean
	return Context.struggling
end

-- "low" on a phone or tablet or in Low performance mode, "high" on a PC or console (Presets.budget).
function Effects.tier(): string
	return Context.tier
end

-- Whether a resting cafe cat is sat up in a loaf right now (a Napping cat with no station, by day, now and then).
-- Every client agrees without a remote, so Audio can purr from loafing cats.
function Effects.isLoafing(model: Model): boolean
	return Cats.isLoafing(model)
end

-- Follows the player's Settings switches (ProfileSync `settings`): `screenShake = false` turns off every camera
-- shake and bump, `lowPerformance = true` runs every effect on the Low performance budget on any device (fewer
-- moving cats, particles and butterflies) and makes tier() say "low". A missing key keeps its default, shake on
-- and Low performance off. Call it with the first settings and whenever a switch changes; it is safe before start(),
-- and a call with unchanged settings changes nothing.
function Effects.applySettings(settings: { [string]: unknown }?)
	Context.applySettings(settings)
	Sky.refresh()
	StationCircles.set(if settings ~= nil then settings.stationCircles else nil) -- #4668
	CatNames.set(if settings ~= nil then settings.catNames else nil) -- #5586
end

return Effects
