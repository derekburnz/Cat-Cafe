--!strict
-- #2792 (shared/FirstVisits): the server side of a new account's first special visitors, shared by RichTipService,
-- MysteryService and CollectorService. While a first visit is at the cafe the plot's FirstVisit attribute names its
-- kind ("rich", "mystery", "collector") for the client's big arrival toast and its "Go to my cafe" button; it is
-- cleared when that visit ends.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FirstVisits = require(ReplicatedStorage.Shared.FirstVisits)
local PlayTime = require(script.Parent.PlayTime)
local Telemetry = require(script.Parent.Parent.Services.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local FirstVisit = {}

-- Whether `kind`'s scheduled first visit is due for `player` now.
function FirstVisit.due(
	player: Player,
	profile: Types.PlayerProfile,
	kind: FirstVisits.Kind
): boolean
	return FirstVisits.due(profile.firstVisits, kind, PlayTime.seconds(player, profile))
end

-- A visitor of `kind` has come to `player`'s cafe (`model` its plot's model): marks the kind met and returns whether
-- this is the account's first visit of that kind inside the window (then the attribute is set and it is logged).
function FirstVisit.arrive(
	player: Player,
	profile: Types.PlayerProfile,
	model: Instance,
	kind: FirstVisits.Kind
): boolean
	local played = PlayTime.seconds(player, profile)
	local first = FirstVisits.pending(profile.firstVisits, kind, played)
	FirstVisits.mark(profile.firstVisits, kind)
	if first then
		model:SetAttribute("FirstVisit", kind)
		Telemetry.custom(player, "first_visit", math.floor(played), { kind :: string, "arrived" })
	end
	return first
end

-- Clears the plot's FirstVisit attribute if it names `kind`.
function FirstVisit.clear(model: Instance, kind: FirstVisits.Kind)
	if model:GetAttribute("FirstVisit") == kind then
		model:SetAttribute("FirstVisit", nil)
	end
end

-- A first visit of `kind` has ended with `outcome` ("claimed", "missed", or the Collector's own "declined",
-- "timeout", "withdrawn") after `seconds` at the cafe: clears the attribute and logs it. `player` is nil when the
-- owner has left.
function FirstVisit.ended(
	player: Player?,
	model: Instance,
	kind: FirstVisits.Kind,
	outcome: string,
	seconds: number
)
	FirstVisit.clear(model, kind)
	if player ~= nil then
		Telemetry.custom(
			player,
			"first_visit",
			math.max(0, math.floor(seconds)),
			{ kind :: string, outcome }
		)
	end
end

return FirstVisit
