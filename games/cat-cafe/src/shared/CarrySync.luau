--!strict
-- #3145 (Derek2 2026-11-10: "sometimes cat don't drop off from bag and then stays like this and cant drop", with the
-- carry banner still up): whether the screen's carry state has drifted from the server's and must be set again.
--
-- The server says which cat is in the hands in every ProfileSync (`carrying`, nil for none). The client used to act
-- only when that value changed from the last one it applied, so anything that got between the two (a sync applied
-- late or out of order, an error half way through showing or hiding the banner, a state copied without the banner)
-- left the banner up for a cat the server no longer had: Drop then did nothing and no camp took it. UIController now
-- asks this on every sync and twice a second, and sets the screen again whenever it says so. Pure.

local CarrySync = {}

-- What the screen holds now.
export type View = {
	built: boolean, -- the HUD exists; before that there is no banner to compare
	catId: string?, -- the cat the UI's own state says is carried
	banner: boolean, -- the carry banner is up
}

-- `want` is the newest ProfileSync's carrying; `applied` the value last handed to the UI.
function CarrySync.stale(want: string?, applied: string?, view: View): boolean
	if want ~= applied then
		return true
	end
	if not view.built then
		return false
	end
	return view.catId ~= want or view.banner ~= (want ~= nil)
end

return CarrySync
