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

local Ambient = require(script.Ambient)
local ArcadeGlow = require(script.ArcadeGlow)
local AreaFx = require(script.AreaFx)
local BaitCrumbs = require(script.BaitCrumbs)
local BedWalk = require(script.BedWalk)
local Bellhop = require(script.Bellhop)
local CafeWalk = require(script.CafeWalk)
local CampCollect = require(script.CampCollect)
local CampExtras = require(script.CampExtras)
local CampGlow = require(script.CampGlow)
local CampGrowth = require(script.CampGrowth)
local CampWater = require(script.CampWater)
local Campfire = require(script.Campfire)
local Cannon = require(script.Cannon)
local CannonGlide = require(script.CannonGlide)
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
local Equip = require(script.Equip)
local FirstBaitCut = require(script.FirstBaitCut)
local Fish = require(script.Fish)
local GoldenFind = require(script.GoldenFind)
local GrandOpening = require(script.GrandOpening)
local HoldPulse = require(script.HoldPulse)
local Intro = require(script.Intro)
local IntroCut = require(script.IntroCut)
local LateStationFx = require(script.LateStationFx)
local Lawn = require(script.Lawn)
local Levels = require(script.Levels)
local LuckyCat = require(script.LuckyCat)
local LuckyPaw = require(script.LuckyPaw)
local Market = require(script.Market)
local Motion = require(script.Motion)
local MuseumPlaques = require(script.MuseumPlaques)
local Mystery = require(script.Mystery)
local NetPin = require(script.NetPin)
local NetTrail = require(script.NetTrail)
local Orders = require(script.Orders)
local PalWave = require(script.PalWave)
local PassThanks = require(script.PassThanks)
local Pity = require(script.Pity)
local Plots = require(script.Plots)
local Potions = require(script.Potions)
local Pull = require(script.Pull)
local PullHop = require(script.PullHop)
local Rainbow = require(script.Rainbow)
local Rally = require(script.Rally)
local Rarity = require(script.Rarity)
local Rescue = require(script.Rescue)
local ShopCats = require(script.ShopCats)
local Shove = require(script.Shove)
local Signature = require(script.Signature)
local Sky = require(script.Sky)
local SlotWalk = require(script.SlotWalk)
local Splash = require(script.Splash)
local StationBuild = require(script.StationBuild)
local StationMotion = require(script.StationMotion)
local StationReveal = require(script.StationReveal)
local Tackle = require(script.Tackle)
local Themes = require(script.Themes)
local Townsfolk = require(script.Townsfolk)
local Trade = require(script.Trade)
local WaitingCat = require(script.WaitingCat)
local Wheel = require(script.Wheel)

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
	local starts: { () -> () } = {
		Cats.start,
		CafeWalk.start,
		BedWalk.start,
		Bellhop.start,
		LuckyPaw.start,
		PullHop.start,
		CampExtras.start,
		PalWave.start,
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
		Pull.start,
		Mystery.start,
		Levels.start,
		Rarity.start,
		Splash.start,
		Rescue.start,
		Intro.start,
		IntroCut.start,
		function()
			Cannon.setGlide(CannonGlide)
			Cannon.start()
		end,
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
		MuseumPlaques.start,
		StationMotion.start,
		HoldPulse.start,
		BaitCrumbs.start,
		WaitingCat.start,
		ArcadeGlow.start,
		GoldenFind.start,
		StationBuild.start,
		StationReveal.start,
		CampGrowth.start,
		Townsfolk.start,
	}
	task.spawn(function()
		local slice = os.clock()
		for _, start in starts do
			start()
			if os.clock() - slice > START_SLICE then
				task.wait()
				slice = os.clock()
			end
		end
		-- the context tips' camera cuts (#976): the UI calls them once they are handed over
		ContextCut.start(require(script.Parent.UI) :: any)
		-- #2946: the first bait's cutscene; the UI's bait cards wait for it
		FirstBaitCut.start(require(script.Parent.UI) :: any)
	end)
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
end

return Effects
