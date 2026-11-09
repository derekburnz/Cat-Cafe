--!strict
-- #2798 (retention-ideas.md idea 10, Derek2: "10 yes"; its countdown is the gift icon's tooltip, not a new strip): the
-- Cozy Cafe line on the Rewards list. The server sets the owner's plot's CozyActive (true while you stand in your
-- cafe and can earn), CozyNextAt (os.time() of the next bag, while active) and CozyBagAt (os.time() the waiting bag
-- appeared, 0 for none); the bag sits on the counter with its own prompt, and taking it toasts. Pure, so the cloud
-- specs check it.
--   line(active, nextAt, bagAt, now) -> (string?, boolean)   the row's words and whether a bag waits; nil when
--                                                           there is nothing to say (outside the cafe, no bag)

local TipJarLogic = require(script.Parent.TipJarLogic)

local CozyLogic = {}

CozyLogic.WAITING = "Cozy gift waiting!" -- the bag on your counter; short enough for the list on a phone

function CozyLogic.line(
	active: unknown,
	nextAt: unknown,
	bagAt: unknown,
	now: number
): (string?, boolean)
	if type(bagAt) == "number" and bagAt > 0 then
		return CozyLogic.WAITING, true
	end
	if active == true and type(nextAt) == "number" and nextAt > 0 then -- 0: the timer is not running (cap reached)
		return "Cozy gift in " .. TipJarLogic.clock(math.max(0, nextAt - now)), false
	end
	return nil, false
end

return CozyLogic
