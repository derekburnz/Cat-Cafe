--!strict
-- Cat Cafe client effects (vfx-animator): cat motion, the Legendary and Mythical cats' signature effects, catch
-- reactions, the getaway and the startled stars, cafe and gate moments, dusk and sunrise, ambient life, shoves, the
-- players' tackle poses, the spin wheel, the Codes Cat's circle, crate openings, golden fish, the Mythical cafe
-- styles, potion glows, the Mystery Visitor, cat level ups and the red "!" over stuck cats, all on this client only.
-- Effects read replicated world state (tags and attributes) and this player's own events; they never fire a remote,
-- never change game state and never move a part the server moves for gameplay. Rules:
-- .claude/skills/animation-vfx/SKILL.md.
-- Wiring and file map: README.md next to this file.

local Ambient = require(script.Ambient)
local Catch = require(script.Catch)
local Cats = require(script.Cats)
local Chase = require(script.Chase)
local Codes = require(script.Codes)
local Context = require(script.Context)
local Decor = require(script.Decor)
local Fish = require(script.Fish)
local Levels = require(script.Levels)
local Market = require(script.Market)
local Mystery = require(script.Mystery)
local Plots = require(script.Plots)
local Potions = require(script.Potions)
local Rescue = require(script.Rescue)
local Shove = require(script.Shove)
local Signature = require(script.Signature)
local Tackle = require(script.Tackle)
local Wheel = require(script.Wheel)

local Effects = {}

local started = false

-- Starts every effect. Safe to call more than once; later calls do nothing.
function Effects.start()
	if started then
		return
	end
	started = true
	Context.init()
	Cats.start()
	Signature.start()
	Catch.start()
	Chase.start()
	Plots.start()
	Ambient.start()
	Shove.start()
	Tackle.start()
	Wheel.start()
	Codes.start()
	Market.start()
	Fish.start()
	Decor.start()
	Potions.start()
	Mystery.start()
	Levels.start()
	Rescue.start()
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
end

return Effects
