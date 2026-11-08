--!strict
-- The tackling lesson (#2198, Components/TackleLessonLogic): a short forced cutscene on the intro's screen in place of
-- the `tackle` tip's card, once per account. UI's tip pump starts it at a free moment (never during a catch, a rescue,
-- a carry, a flight or with a window up) and saves the tip as seen when it ends. It plays through UI.intro's calls, so
-- the HUD, toasts and popups step aside as they do for the intro and come back at the end:
--   the letterbox bars, one caption a shot with its dot and the gold read bar filling over its hold, Next (a tap,
--   Space, Enter or gamepad A) from 1 s into each, and no Skip. After the last caption it ends by itself.
--   play(api, device, done)   `api` is UI.intro's start, setShot, finish and playing; `done` runs once at the end
-- #2312 (Derek2: "the cut scene for explaining tackling doesn't actually take control of your camera like tutorial"):
-- api.stage(index) has IntroController stage each caption's shot (you carrying, a tackle knocking you, the cat
-- dropping, then a pull-up over the scene), and stage(0) at the end gives the camera back.
-- #2469 (Derek2): on the third caption ("Tap Tackle near a carrier", Q or Y) api.cue shows the Tackle bar over the
-- caption and presses it as the staged lunge starts, TackleStage.LUNGE_AT after the shot is staged; cue(nil) clears it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TackleLessonLogic = require(script.Parent.Parent.Components.TackleLessonLogic)
local Types = require(script.Parent.Parent.Types)

local TackleStage =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TackleStage")) :: any

export type Api = {
	start: (options: Types.IntroOptions?) -> (),
	setShot: (index: number, caption: string, titleCard: string?, hold: number?) -> (),
	finish: () -> (),
	playing: () -> boolean,
	-- #2312: the controller's camera for each caption (1 to 4), and 0 to give the camera back; nil leaves it alone
	stage: ((shot: number) -> ())?,
	-- #2469: the Tackle bar over the caption with this key cap ("" on touch), pressed `pressIn` seconds on; nil clears
	cue: ((key: string?, pressIn: number?) -> ())?,
}

local TackleLesson = {}

function TackleLesson.play(api: Api, device: TackleLessonLogic.Device, done: () -> ())
	local lines = TackleLessonLogic.lines(device)
	local shown = 0
	local ended = false
	local function finish()
		if ended then
			return
		end
		ended = true
		local cue = api.cue
		if cue then
			cue(nil)
		end
		local stage = api.stage
		if stage then
			stage(0)
		end
		if api.playing() then
			api.finish()
		end
		done()
	end
	local function show(index: number)
		if ended then
			return
		end
		-- the screen ended some other way: the lesson ends with it
		if index > #lines or not api.playing() then
			finish()
			return
		end
		shown = index
		local caption = lines[index]
		local hold = TackleLessonLogic.hold(caption)
		local stage = api.stage
		if stage then
			stage(index)
		end
		api.setShot(index, caption, nil, hold)
		local cue = api.cue
		if cue then
			local lunge = if type(TackleStage.LUNGE_AT) == "number"
				then TackleStage.LUNGE_AT
				else 0.9
			cue(
				if index == TackleLessonLogic.CUE_SHOT
					then TackleLessonLogic.cueKey(device)
					else nil,
				lunge
			)
		end
		task.delay(hold, function()
			if shown == index then
				show(index + 1)
			end
		end)
	end
	api.start({
		replay = true, -- no Tutorial tile glow afterwards
		skip = false,
		shots = #lines,
		onNext = function(shot: number)
			if shot == shown then
				show(shown + 1)
			end
		end,
	})
	show(1)
end

return TackleLesson
