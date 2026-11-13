--!strict
-- The feedback faces (F87, easy-start.md section 4): the three faces and the six chips with their words, when the
-- one slide-in ask may show, and when an answer is sent.
--
-- One answer is one SendFeedback, so the analytics count each player's face once. A face tap is enough: the face
-- is sent with the first chip tapped after it, or alone once the window closes, "Tell us more" is pressed or
-- WAIT_SECONDS pass, whichever comes first. The values are shared/Tips' FACES and CHIPS, the short fixed values
-- the server checks.
--   FACES, CHIPS                      { id, label, glyph } in the server's order
--   askDue(asked, played, free) -> boolean   the one ask: the save says not asked yet (false, not nil), the session
--                                     has run ASK_MINUTES and nothing else is going on
--   earlyDue(asked, played, working, free) -> boolean   #2681: the same ask once earlier for a player never asked,
--                                     at EARLY_MINUTES (#2880: 8, and no longer sooner once a cat has served; `working`
--                                     is kept for the callers but no longer read)
--   reasons(face) -> { Choice }       #3657: the reasons the slide-in ask offers after a face (none: send it at once)
--   reasonChip(answer) -> string?     the chip in that ask's answer, nil for Skip or none
--   answer() -> Answer                :pick(face, now), :chip(id) -> (face, chip)?, :due(now) -> (face, nil)?,
--                                     :flush() -> (face, nil)?, :face(), :sent(), :reset()
-- Pure, so the cloud spec runner checks it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any
local Tips = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tips")) :: any

local FeedbackLogic = {}

export type Choice = { id: string, label: string, glyph: string }

FeedbackLogic.WAIT_SECONDS = 20 -- a face with no chip is sent alone after this
FeedbackLogic.ASK_SECONDS = 10 -- the slide-in ask stays this long
FeedbackLogic.ASK_MINUTES = (Config.FeedbackAskMinutes or 12) :: number
-- #2681: about 70% of new players leave before 10 minutes, so a player never asked gets the faces early. #2880 (Derek2:
-- "too early and too often"): at 8 minutes, not at 4 or 45 s after a first cat served, and once a session: an early
-- ask left unanswered no longer comes back at ASK_MINUTES (init); AskPacing spaces it from the other asks
FeedbackLogic.EARLY_MINUTES = 8

-- #3272 (Derek2 11-11: "a thumb up or down or neutral face very simple"): thumbs up, a plain face, thumbs down. The
-- ids stay love, ok and no, the values the server and the analytics already take.
local FACE_LOOKS: { [string]: { label: string, glyph: string } } = {
	love = { label = "Good", glyph = "👍" },
	ok = { label = "OK", glyph = "😐" },
	no = { label = "Not good", glyph = "👎" },
}
local CHIP_LOOKS: { [string]: { label: string, glyph: string } } = {
	too_hard = { label = "Too hard", glyph = "😣" },
	confusing = { label = "Confusing", glyph = "❓" },
	boring = { label = "Boring", glyph = "😴" },
	laggy = { label = "Laggy", glyph = "🐌" },
	more_cats = { label = "Want more cats", glyph = "🐱" },
	other = { label = "Something else", glyph = "💬" },
}

local function choices(
	ids: { string },
	looks: { [string]: { label: string, glyph: string } }
): { Choice }
	local out: { Choice } = {}
	for _, id in ids do
		local look = looks[id]
		table.insert(out, {
			id = id,
			label = if look then look.label else id,
			glyph = if look then look.glyph else "💬",
		})
	end
	return out
end

FeedbackLogic.FACES = choices(Tips.FACES, FACE_LOOKS)
FeedbackLogic.CHIPS = choices(Tips.CHIPS, CHIP_LOOKS)

-- #3657: the slide-in ask sent its face at once and never showed a chip, so one reason came with 106 faces. After a
-- plain face or a thumbs down the same card now asks why: REASONS and Skip, for REASON_SECONDS; the face goes with
-- the chip tapped, or alone on Skip, the X or when the time runs out. A thumbs up is sent at once (no reason here
-- fits it).
FeedbackLogic.REASON_TITLE = "What is the main reason?"
FeedbackLogic.REASON_SECONDS = 8
FeedbackLogic.SKIP = "skip"
FeedbackLogic.REASON_FACES = table.freeze({ "ok", "no" })
FeedbackLogic.REASONS = choices({ "too_hard", "confusing", "boring", "laggy" }, CHIP_LOOKS)

-- The reasons the slide-in ask offers after `face`: none for a face that is sent at once.
function FeedbackLogic.reasons(face: string): { Choice }
	return if table.find(FeedbackLogic.REASON_FACES, face) ~= nil then FeedbackLogic.REASONS else {}
end

-- The chip to send for the reasons ask's answer: nil for Skip, no answer or anything that is not one of REASONS.
function FeedbackLogic.reasonChip(answer: string?): string?
	for _, chip in FeedbackLogic.REASONS do
		if chip.id == answer then
			return chip.id
		end
	end
	return nil
end

function FeedbackLogic.askDue(asked: boolean?, played: number, free: boolean): boolean
	return asked == false and played >= FeedbackLogic.ASK_MINUTES * 60 and free
end

-- `working`: seconds a cat has held a role this session (0 when none has).
function FeedbackLogic.earlyDue(
	asked: boolean?,
	played: number,
	_working: number,
	free: boolean
): boolean
	return asked == false and free and played >= FeedbackLogic.EARLY_MINUTES * 60
end

export type Answer = {
	pick: (self: Answer, face: string, now: number) -> (),
	chip: (self: Answer, chip: string) -> (string?, string?),
	due: (self: Answer, now: number) -> (string?, string?),
	flush: (self: Answer) -> (string?, string?),
	face: (self: Answer) -> string?,
	sent: (self: Answer) -> boolean,
	reset: (self: Answer) -> (),
}

local Answer = {}
Answer.__index = Answer

function FeedbackLogic.answer(): Answer
	local self = setmetatable({}, Answer) :: any
	self:reset()
	return self :: Answer
end

function Answer.reset(self: any)
	self._face = nil :: string?
	self._at = 0
	self._sent = false
end

-- A face tapped: a new answer, sent again even after a chip went with the last one (the server's 1 per 10 s and 5 a
-- session hold a player who keeps changing their mind, review N310).
function Answer.pick(self: any, face: string, now: number)
	self._face = face
	self._at = now
	self._sent = false
end

-- A chip tapped: the face and the chip to send, once.
function Answer.chip(self: any, chip: string): (string?, string?)
	if self._face == nil or self._sent then
		return nil, nil
	end
	self._sent = true
	return self._face, chip
end

-- The face alone, once WAIT_SECONDS have passed with no chip.
function Answer.due(self: any, now: number): (string?, string?)
	if self._face == nil or self._sent or now - self._at < FeedbackLogic.WAIT_SECONDS then
		return nil, nil
	end
	self._sent = true
	return self._face, nil
end

-- The face alone, now (the window closed, or "Tell us more").
function Answer.flush(self: any): (string?, string?)
	if self._face == nil or self._sent then
		return nil, nil
	end
	self._sent = true
	return self._face, nil
end

function Answer.face(self: any): string?
	return self._face
end

function Answer.sent(self: any): boolean
	return self._sent
end

return FeedbackLogic
