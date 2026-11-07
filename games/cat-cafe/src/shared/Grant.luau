--!strict
-- A paid prize given in steps (#2127, found in the #2118 purchase edge cases). ProductService records a receipt's
-- PurchaseId and then pays the prize, so a step that throws halfway used to lose the rest of the prize: Roblox
-- delivered the receipt again, but the recorded id paid nothing. Now each step runs in its own pcall:
-- - `first` is the riskiest step (the gift cat), run before anything else is paid. If it throws and `changed` says
--   it left the save as it was, nothing else runs and the result is `undone`: the caller forgets the id and answers
--   NotProcessedYet, so the redelivery pays the whole prize once the fault is fixed.
-- - Otherwise every later step runs whatever the others did, and `failed` names the ones that threw, so one fault
--   loses only its own step and is logged (Telemetry grant_failed).
-- Nothing here yields, so the id and the prize still land in one step.

local Grant = {}

export type Step = { name: string, run: () -> () }
export type Result = { undone: boolean, failed: { string }, errors: { string } }

-- An error's text for a server log: at most 120 characters, long digit runs (a user id) masked, since logs are public.
function Grant.errorText(err: unknown): string
	return (string.sub(string.gsub(tostring(err), "%d%d%d%d%d+", "#"), 1, 120))
end

-- pcall typed for a step that returns nothing: (true, nil) or (false, the error).
local function try(fn: () -> ()): (boolean, any)
	local call: any = pcall
	return call(fn)
end

-- Runs `first`, then each of `rest` in order (see the header).
function Grant.run(first: Step, changed: () -> boolean, rest: { Step }): Result
	local result: Result = { undone = false, failed = {}, errors = {} }
	local function note(step: Step, err: unknown)
		table.insert(result.failed, step.name)
		table.insert(result.errors, Grant.errorText(err))
	end
	local ok, err = try(first.run)
	if not ok then
		note(first, err)
		local changedOk, didChange = pcall(changed)
		if changedOk and didChange == false then
			result.undone = true
			return result
		end
	end
	for _, step in rest do
		local stepOk, stepErr = try(step.run)
		if not stepOk then
			note(step, stepErr)
		end
	end
	return result
end

return Grant
