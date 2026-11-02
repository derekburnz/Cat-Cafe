--!strict
-- Sound beats from animations (sound list section 6). Effects fires Beats.hit(beat, at) on the frame a bell swings,
-- a fish jumps or a lid rattles, and Audio plays that beat's sound there (Logic.beatCue: bellRing, fishJump,
-- rodCast, basketOpen, lidRattle). It lives beside Audio so Effects can require it without requiring Audio itself.
-- at: the part, attachment or Model the sound comes from (a Model plays from its PrimaryPart or first part, like the
-- Bellhop Cat's <cat>_Bell), or a point in the world.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signal"))

local Beats = {
	hit = Signal.new() :: Signal.Signal<string, any>,
}

return Beats
