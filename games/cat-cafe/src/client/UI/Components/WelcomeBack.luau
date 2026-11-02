--!strict
-- The welcome back card's words (F95, economy-ladder.md section 5; Derek 2026-11-01 22:32: "do 50% offline and pass
-- makes it 100% and up to 16h"). The offline card (Screens/Popups) is titled "Welcome back!" and says what the
-- cats earned, with one line on what time away pays, read from Config so it follows the numbers:
--   note(longNap?) -> string   "Half pay while away, up to 8 hours", or "Full pay, up to 16 hours" with the Long
--                              Nap pass
-- `longNap` is PlayerState.longNap once ProfileSync carries it; nil is the free line. The pass is offered elsewhere
-- (Monetization-Agent's plan), never on this card. Pure, so the cloud spec runner checks it.

local Config = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config")
) :: any

local WelcomeBack = {}

WelcomeBack.TITLE = "Welcome back!"

-- 0.5 -> "Half pay", 1 -> "Full pay", 0.25 -> "Quarter pay", else "40% pay".
function WelcomeBack.payWord(rate: number): string
	if rate >= 1 then
		return "Full pay"
	elseif math.abs(rate - 0.5) < 1e-6 then
		return "Half pay"
	elseif math.abs(rate - 0.25) < 1e-6 then
		return "Quarter pay"
	end
	return ("%d%% pay"):format(math.floor(rate * 100 + 0.5))
end

-- 28800 -> "8 hours", 3600 -> "1 hour", 1800 -> "30 minutes".
function WelcomeBack.span(seconds: number): string
	if seconds >= 3600 and seconds % 3600 == 0 then
		local hours = seconds // 3600
		return if hours == 1 then "1 hour" else ("%d hours"):format(hours)
	end
	local minutes = math.max(1, math.floor(seconds / 60 + 0.5))
	return if minutes == 1 then "1 minute" else ("%d minutes"):format(minutes)
end

function WelcomeBack.note(longNap: boolean?): string
	if longNap then
		return ("%s, up to %s"):format(
			WelcomeBack.payWord(Config.OfflineRatePass or 1),
			WelcomeBack.span(Config.OfflineCapPassSeconds or 57600)
		)
	end
	return ("%s while away, up to %s"):format(
		WelcomeBack.payWord(Config.OfflineRate or 0.5),
		WelcomeBack.span(Config.OfflineCapSeconds or 28800)
	)
end

return WelcomeBack
