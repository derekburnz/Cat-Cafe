--!strict
-- #4626 (Design-Agent's spec): the early return hook. Most new players leave near minute 10 and the session recap
-- card only comes after 40 minutes, so at minute 6 a player before Tier 3 gets one quiet line in the toast stack with
-- tomorrow's reason to come back, in the recap card's own words. Once a session, no button, no countdown, nothing to
-- buy. The server picks the reason (PlayerState.tomorrowHook, shared/ReturnHook.early, behind returnHookEarly); the
-- client times it. Pure, so the specs load it.
--   due(played, tier, tutorialDone, shown) -> boolean   whether the line's time has come
--   words(raw) -> string?                               the line for PlayerState.tomorrowHook, nil with none to say
--   kind(raw) -> string?                                its kind for the return_hook_early report

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RecapLogic = require(script.Parent.RecapLogic)
local ReturnHook = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ReturnHook"))

local ReturnHookLine = {}

ReturnHookLine.AT_SECONDS = 360 -- minute 6 of the session
ReturnHookLine.SHOW_SECONDS = 6
ReturnHookLine.MAX_TIER = ReturnHook.EARLY_MAX_TIER
ReturnHookLine.PREFIX = "\u{1F381} " -- the wrapped gift

-- Whether the line may show now: `played` seconds into the session, past the tutorial, before Tier 3 and not shown
-- yet this session. The caller also waits for a calm screen (no menu, catch or cutscene).
function ReturnHookLine.due(
	played: number,
	tier: number?,
	tutorialDone: boolean,
	shown: boolean
): boolean
	return not shown
		and tutorialDone
		and type(tier) == "number"
		and tier <= ReturnHookLine.MAX_TIER
		and played >= ReturnHookLine.AT_SECONDS
end

-- The hook's kind when it is one the early line names ("gift" or "treat"), else nil.
function ReturnHookLine.kind(raw: any): string?
	local hook = RecapLogic.hook(raw)
	if hook == nil or table.find(ReturnHook.EARLY_KINDS, hook.kind) == nil then
		return nil
	end
	return hook.kind
end

function ReturnHookLine.words(raw: any): string?
	if ReturnHookLine.kind(raw) == nil then
		return nil
	end
	return ReturnHookLine.PREFIX .. RecapLogic.tomorrow(RecapLogic.hook(raw) :: any)
end

return ReturnHookLine
