--!strict
-- #2792 (retention-ideas.md section 2, Derek2 2026-11-09: "maybe an early rich tip and a mystery gift then cat
-- collector a little but after each-other ... make it obvious when he visits"): a new account meets the rich customer,
-- the Mystery Visitor and the Cat Collector once each on a fixed schedule in its first minutes of play
-- (Config.FirstVisitAt, seconds of play on the account), instead of waiting on their random timers. A first visit stays
-- Config.FirstVisitStaySeconds (dusk still sends it home), the Mystery Visitor's first gift is Rare or better and the
-- Collector's first offer uses the top of his roll. A kind counts as met at its first arrival, scheduled or not, and
-- an account past Config.FirstVisitWindowSeconds of play gets the normal timers only, so older saves never see the
-- schedule. Pure: the services call these with the save's `firstVisits` and PlayTime.

local Config = require(script.Parent.Config)

local FirstVisits = {}

export type Kind = "rich" | "mystery" | "collector"
export type Save = { [string]: boolean } -- kind -> true once that visitor has come

FirstVisits.KINDS = { "rich", "mystery", "collector" } :: { Kind }

-- A save's firstVisits from anything: only the known kinds, only `true` kept.
function FirstVisits.sanitize(raw: unknown): Save
	local out: Save = {}
	if type(raw) == "table" then
		for _, kind in FirstVisits.KINDS do
			if (raw :: any)[kind] == true then
				out[kind] = true
			end
		end
	end
	return out
end

-- Whether `kind`'s first visit is still ahead for an account with `played` seconds of play: not met yet, and inside
-- the window. A pending kind's random timer still runs, so a visitor that comes early by chance counts.
function FirstVisits.pending(save: Save, kind: Kind, played: number): boolean
	return save[kind] ~= true and played <= Config.FirstVisitWindowSeconds
end

-- Whether `kind`'s scheduled first visit is due now, at `played` seconds of play on the account.
function FirstVisits.due(save: Save, kind: Kind, played: number): boolean
	local at = (Config.FirstVisitAt :: { [string]: number })[kind]
	return at ~= nil and FirstVisits.pending(save, kind, played) and played >= at
end

-- How long a visitor of `kind` stays: FirstVisitStaySeconds on its first visit (`first`), else `normal`.
function FirstVisits.stay(first: boolean, normal: number): number
	return if first then math.max(normal, Config.FirstVisitStaySeconds) else normal
end

-- Marks `kind` met. Returns whether this was its first visit (it was not met before).
function FirstVisits.mark(save: Save, kind: Kind): boolean
	if save[kind] == true then
		return false
	end
	save[kind] = true
	return true
end

return FirstVisits
