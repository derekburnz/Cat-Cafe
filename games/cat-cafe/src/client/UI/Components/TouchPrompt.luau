--!strict
-- #2315 (Derek2: "make sure mobile players have a way of doing rescue instead of holding e since they cant"): whether
-- the catch card offers its big press-and-hold button (CATCH, RESCUE or PICK UP) in place of the key cap. The cat
-- prompts are Custom style, so Roblox draws nothing a finger can press; the button is the only way in on a phone.
-- It used to show only on a device with touch and no keyboard or mouse (Scale.isTouch), so a phone or tablet that
-- reports a keyboard (a paired one, some Android phones, Studio's emulator) showed "[E] HOLD" and nothing to press.
-- Now any sign of touch shows it: Roblox's own input type for the prompt (PromptShown's ProximityPromptInputType),
-- the last input this player used, or a touch-only device. Pure, so the cloud specs check it.
--   wants(promptTouch, lastInput, touchDevice) -> boolean
--     promptTouch   PromptShown said Touch (nil when not known)
--     lastInput     UserInputService:GetLastInputType().Name
--     touchDevice   Scale.isTouch()

local TouchPrompt = {}

function TouchPrompt.wants(promptTouch: boolean?, lastInput: string, touchDevice: boolean): boolean
	return promptTouch == true or lastInput == "Touch" or touchDevice
end

return TouchPrompt
