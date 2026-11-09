--!strict
-- The tackling lesson's words and timing (#2198; Derek2 2026-11-07: "add either to tutorial or some sort of context
-- tutorial that happens either after your first catch ... that explains tackling", then "maybe more then a tip a
-- forced cut scene after first catch or something because likely people will turn tips off with the X pretty fast").
-- It plays once, in place of the `tackle` context tip the server sends at the first check-in (the end of the newcomer
-- shield, easy-start.md section 3), on the intro's screen: one caption a shot, each held long enough to read, Next
-- from 1 s in and no Skip. Screens/TackleLesson plays it. #2474 (Derek2: play it "into the end of the tutorial
-- briefly"): BASE + PER_WORD a word (0.6 + 0.3 s, quicker than the intro's 1.0 + 0.4 s), never under MIN_HOLD, which
-- covers the slowest staged beat (shared/TackleStage: shot 3's pick-up done by about 2.1 s; shot 2's hit lands at
-- 1.35 s and shot 4's net is down at 1.05 s).
--   TIP                          the server's tip it plays for ("tackle_lesson" since #2409, its own id so an account
--                                that saw the old tackle card still gets it), whose seen flag it saves
--   lines(device) -> { string }  the captions; the third names the input the player last used (TipQueue.device)
--   hold(caption) -> number      seconds a caption holds when nobody presses Next (at least MIN_HOLD)
--   CUE_SHOT, cueKey(device)     #2469: the caption that shows the Tackle bar pressed as the lunge starts, and the
--                                key cap on it ("Q", "Y", or "" on touch, where the bar itself is the button)
--   contextDue(view) -> boolean  #2626: whether the lesson is due as a context tip: this session tackled the player,
--                                they are back on the safe street or in a cafe, the tutorial strip is done
--                                (TutorialHints.DONE) and the lesson was never seen
-- Pure, so the cloud spec runner checks it.
-- #2626 (Derek2: "make tackle lesson removed from tutorial for now so less people leave ... add tackle tutorial as a
-- context tutorial your first time your in the safe after being tackled"): no longer the intro's tail; UI's tip pump
-- plays it once contextDue says so, and its TipSeen saves it as seen for good.

export type Device = "keyboard" | "touch" | "gamepad"

local TackleLessonLogic = {}

TackleLessonLogic.TIP = "tackle_lesson" -- shared/Tips.LESSON

TackleLessonLogic.BASE = 0.6 -- #2474: seconds a caption holds, plus PER_WORD a word
TackleLessonLogic.PER_WORD = 0.3
TackleLessonLogic.MIN_HOLD = 2.4 -- shot 3's pick-up is done by about 2.1 s, and a beat to see the cat taken

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
	return math.max(
		TackleLessonLogic.BASE + TackleLessonLogic.PER_WORD * words,
		TackleLessonLogic.MIN_HOLD
	)
end

TackleLessonLogic.DONE_STEP = 5 -- TutorialHints.DONE: the tutorial strip's last step is behind the player

export type Context = {
	tackled: boolean, -- another player's tackle landed on this player this session
	safe: boolean, -- standing on the safe street or in a cafe (Wayfinding.isSafe)
	seen: boolean, -- the lesson's tip is on the save or played this session
	step: number?, -- the server's tutorialStep (nil on an older server: treated as done)
}

function TackleLessonLogic.contextDue(view: Context): boolean
	local step: number = if type(view.step) == "number" then view.step else math.huge
	return view.tackled == true
		and view.safe == true
		and view.seen ~= true
		and step >= TackleLessonLogic.DONE_STEP
end

return TackleLessonLogic
