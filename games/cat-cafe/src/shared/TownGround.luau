--!strict
-- #5357 (Derek 2026-11-18: "things in town like the paw print path dont fully render and should always"). With
-- streaming on (#4788) the Town Square's paving (CatCafe_Square_Paving: its slab, the lighter cross and the darker
-- tiles round the walk-up rings) and the paw print paths (WorldBuilder.buildPawPaths) stream out part by part at a
-- distance, so the ground shows with gaps. With the townGround switch on, each of those models (tagged TAG) is
-- Persistent: sent to every device whole and never streamed out. About 420 flat parts of paving and 5 per paw print,
-- none colliding with anything but the slab. Off, they stream as built (Default).
--
-- Roblox terms: a Model's ModelStreamingMode says how streaming treats it. Default streams each part on its own by
-- distance; Persistent sends the whole model to every client when it joins and keeps it there.

local TownGround = {}

TownGround.FLAG = "townGround"
TownGround.TAG = "TownGround"
TownGround.STEP = 5 -- seconds between reads of the switch

function TownGround.mode(on: boolean): Enum.ModelStreamingMode
	return if on then Enum.ModelStreamingMode.Persistent else Enum.ModelStreamingMode.Default
end

return TownGround
