--!strict
-- #2681: where a player is when they answer the feedback faces, so a "Not for me" can be lined up with the
-- onboarding step and the minute they gave up (Roblox shows no one's like or dislike vote). The feedback_v1 funnel's
-- steps, the minutes-played buckets and the fixed values the feedback_ctx, feedback_env and like_ask_shown events
-- carry. Pure; Telemetry sends them.

local FeedbackFunnel = {}

FeedbackFunnel.NAME = "feedback_v1"
-- one run per slide-in faces ask shown: the ask, then a face, then a chip when one was picked
FeedbackFunnel.STEPS = table.freeze({ "ask_shown", "face_picked", "chip_picked" })
-- slide-in asks logged a session at most (the earlier ask for new players and the 12-minute one)
FeedbackFunnel.ASKS_PER_SESSION = 2

local indexOf: { [string]: number } = {}
for i, name in FeedbackFunnel.STEPS do
	indexOf[name] = i
end

-- The step's number, 0 for a name that is not a step.
function FeedbackFunnel.index(name: string): number
	return indexOf[name] or 0
end

-- Minutes played as the issue's buckets: "0-2", "2-5", "5-10", "10-20" or "20+". An edge goes to the lower bucket.
function FeedbackFunnel.minutesBucket(seconds: number): string
	local minutes = math.max(0, seconds) / 60
	if minutes <= 2 then
		return "0-2"
	elseif minutes <= 5 then
		return "2-5"
	elseif minutes <= 10 then
		return "5-10"
	elseif minutes <= 20 then
		return "10-20"
	end
	return "20+"
end

-- feedback_env's third field: the place version and whether this session's client logged an error, as "812:err" or
-- "812:ok". A few dozen distinct values over the game's life, well under analytics' 8,000.
function FeedbackFunnel.build(placeVersion: number, clientError: boolean): string
	return string.format(
		"%d:%s",
		math.max(0, math.floor(placeVersion)),
		if clientError then "err" else "ok"
	)
end

-- #2694: how a slide-in ask ended, as the client reports it (TelemetryReport feedback_outcome,
-- "<outcome>:<kind>"): answered (a face sent), closed (the X) or ignored (its timer ran out), and early (the new
-- player's first ask) or late (the 12-minute one).
FeedbackFunnel.OUTCOMES = table.freeze({ "answered", "closed", "ignored" })
FeedbackFunnel.KINDS = table.freeze({ "early", "late" })

-- The outcome and kind in a feedback_outcome report, or nil for anything else.
function FeedbackFunnel.outcome(raw: unknown): (string?, string?)
	if type(raw) ~= "string" or #raw > 16 then
		return nil, nil
	end
	local outcome, kind = string.match(raw, "^(%l+):(%l+)$")
	if
		outcome == nil
		or kind == nil
		or table.find(FeedbackFunnel.OUTCOMES, outcome) == nil
		or table.find(FeedbackFunnel.KINDS, kind) == nil
	then
		return nil, nil
	end
	return outcome, kind
end

return FeedbackFunnel
