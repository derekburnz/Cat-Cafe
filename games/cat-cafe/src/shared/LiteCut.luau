--!strict
-- #5686 (tablets fall behind in the Park, minutes 3 to 10). The Park's backdrop ring (Model-Agent's
-- CatCafe_Park_BackdropF85, wildbackdrop.py) keeps the pieces a lighter ring can do without in one child model,
-- <ring>_LiteCut, tagged TAG: each tree's second leaf ball, each bush's second ball, the flower tufts, and every other
-- tree on the hills and in the parkland (571 of the ring's 1,208 instances). With the parkLite switch on, the server
-- holds those models in ServerStorage, so no device draws them; off puts each back where it was. Off (the default)
-- the ring is the same as before. Services/LiteCutService does the work. Pure.
--
-- Roblox terms: an instance moved out of the Workspace into ServerStorage is removed from every client at once, and
-- comes back to them when it is moved back.

local LiteCut = {}

LiteCut.FLAG = "parkLite" -- shared/LiveFlags, off by default
LiteCut.TAG = "LiteCut" -- rbx_export.TAGS "_LiteCut"
LiteCut.STEP = 5 -- seconds between reads of the switch
LiteCut.HOLD = "LiteCutHeld" -- the ServerStorage folder the cut pieces wait in

-- What to do with a tagged piece: "hold" it (switch on, in the world), "restore" it (switch off, held) or nothing.
function LiteCut.action(on: boolean, held: boolean): "hold" | "restore" | "none"
	if on and not held then
		return "hold"
	elseif not on and held then
		return "restore"
	end
	return "none"
end

return LiteCut
