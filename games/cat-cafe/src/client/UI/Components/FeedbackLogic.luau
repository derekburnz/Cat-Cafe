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

local FACE_LOOKS: { [string]: { label: string, glyph: string } } = {
	love = { label = "Love it", glyph = "😍" },
	ok = { label = "It's OK", glyph = "🙂" },
	no = { label = "Not for me", glyph = "🙁" },
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

function FeedbackLogic.askDue(asked: boolean?, played: number, free: boolean): boolean
	return asked == false and played >= FeedbackLogic.ASK_MINUTES * 60 and free
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

-- A face tapped: a new answer, unless this one was sent already with a chip.
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
