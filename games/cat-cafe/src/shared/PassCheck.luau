--!strict
-- Game pass lookups' timing and the purchase check (PassService), pure so the specs can drive them.
--   PassCheck.retryAfter(attempt) -> seconds   #2130: a join lookup that failed is tried again after 5, 15 and 45
--                                              seconds, then every LATE_RETRY_SECONDS while the player stays, so a
--                                              Marketplace outage longer than a minute never keeps a paid pass off
--                                              for the whole session
--   PassCheck.confirm(lookup, wait) -> boolean #2131: PromptGamePassPurchaseFinished's "purchased" is only a hint
--                                              from the prompt, so a pass counts once UserOwnsGamePassAsync says so:
--                                              `lookup` (true, false, or nil when it failed) is asked after each of
--                                              CONFIRM_SECONDS, as the answer can lag a moment after a real buy

local PassCheck = {}

PassCheck.RETRY_SECONDS = table.freeze({ 5, 15, 45 }) :: { number }
PassCheck.LATE_RETRY_SECONDS = 300
PassCheck.CONFIRM_SECONDS = table.freeze({ 0, 3, 8 }) :: { number }

-- How long to wait before retry number `attempt` (1 first) of a failed join lookup.
function PassCheck.retryAfter(attempt: number): number
	local n = math.max(1, math.floor(attempt))
	return PassCheck.RETRY_SECONDS[n] or PassCheck.LATE_RETRY_SECONDS
end

-- True once `lookup` says the pass is owned, asked after each of CONFIRM_SECONDS (`wait` is task.wait on the server);
-- false when every answer was no or a failure, so a faked purchase flag grants nothing.
function PassCheck.confirm(lookup: () -> boolean?, wait: (seconds: number) -> ()): boolean
	for _, seconds in PassCheck.CONFIRM_SECONDS do
		if seconds > 0 then
			wait(seconds)
		end
		if lookup() == true then
			return true
		end
	end
	return false
end

return PassCheck
