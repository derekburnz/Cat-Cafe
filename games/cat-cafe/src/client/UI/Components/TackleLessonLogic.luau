--!strict
-- The tackling lesson's words and timing (#2198; Derek2 2026-11-07: "add either to tutorial or some sort of context
-- tutorial that happens either after your first catch ... that explains tackling", then "maybe more then a tip a
-- forced cut scene after first catch or something because likely people will turn tips off with the X pretty fast").
-- It plays once, in place of the `tackle` context tip the server sends at the first check-in (the end of the newcomer
-- shield, easy-start.md section 3), on the intro's screen: one caption a shot, each held long enough to read (the
-- intro's 1.0 + 0.4 s a word, shared/Intro), Next from 1 s in and no Skip. Screens/TackleLesson plays it.
--   TIP                          the server's tip it plays for ("tackle_lesson" since #2409, its own id so an account
--                                that saw the old tackle card still gets it), whose seen flag it saves
--   lines(device) -> { string }  the captions; the third names the input the player last used (TipQueue.device)
--   hold(caption) -> number      seconds a caption holds when nobody presses Next
--   CUE_SHOT, cueKey(device)     #2469: the caption that shows the Tackle bar pressed as the lunge starts, and the
--                                key cap on it ("Q", "Y", or "" on touch, where the bar itself is the button)
-- Pure, so the cloud spec runner checks it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Intro = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Intro")) :: any

export type Device = "keyboard" | "touch" | "gamepad"

local TackleLessonLogic = {}

TackleLessonLogic.TIP = "tackle_lesson" -- shared/Tips.LESSON

local BASE = if type(Intro.CAPTION_BASE) == "number" then Intro.CAPTION_BASE else 1.0
local PER_WORD = if type(Intro.CAPTION_PER_WORD) == "number" then Intro.CAPTION_PER_WORD else 0.4

-- The keys are TackleBar's (Q, gamepad Y); on touch the Tackle bar itself is the button.
local HOW: { keyboard: string, touch: string, gamepad: string } = {
	keyboard = "Press Q near a carrier to tackle them",
	touch = "Tap Tackle near a carrier to tackle them",
	gamepad = "Press Y near a carrier to tackle them",
}

function TackleLessonLogic.lines(device: Device): { string }
	return {
		"Other players can tackle you while you carry!",
		"Get tackled and you drop your cat!",
		(HOW :: any)[device] or HOW.keyboard,
		"You're safe while catching a cat", -- #2312: since #2284 only the catch minigame is safe, not the camps
	}
end

TackleLessonLogic.CUE_SHOT = 3

local KEYS: { keyboard: string, touch: string, gamepad: string } =
	{ keyboard = "Q", touch = "", gamepad = "Y" }

function TackleLessonLogic.cueKey(device: Device): string
	return (KEYS :: any)[device] or KEYS.keyboard
end

function TackleLessonLogic.hold(caption: string): number
	local words = 0
	for _ in string.gmatch(caption, "%S+") do
		words += 1
	end
	return BASE + PER_WORD * words
end

return TackleLessonLogic
