--!strict
-- Purr Pot client effects (vfx-animator): cat motion, catch reactions, cafe and gate moments, ambient life and
-- shoves, all on this client only. Effects read replicated world state (tags and attributes) and this player's own
-- catch events; they never fire a remote, never change game state and never move a part the server moves for
-- gameplay. Rules: .claude/skills/animation-vfx/SKILL.md. Wiring and file map: README.md next to this file.

local Ambient = require(script.Ambient)
local Catch = require(script.Catch)
local Cats = require(script.Cats)
local Context = require(script.Context)
local Plots = require(script.Plots)
local Shove = require(script.Shove)

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
	Catch.start()
	Plots.start()
	Ambient.start()
	Shove.start()
end

-- "low" on a phone or tablet, "high" on a PC or console (Presets.budget).
function Effects.tier(): string
	return Context.tier
end

return Effects
