--!strict
-- #4674 (Derek 2026-11-16 00:04 UTC: "when going into the cannon menu for tutorial steps point to the alleyway button
-- until launch clicked"): in the bowl first walk-through (shared/TutorialOrder), the Cat Cannon picker rings the
-- Alleyway card's Launch with the tutorial's gold ring and arrow (Screens/Cannon setRing, as #2915 does for the Park)
-- while the two Alleyway catches are still to do. Launch ends it for that opening; the next opening rings it again
-- while the catches are still owed. Pure, so the specs test it.

local WalkRingLogic = {}

WalkRingLogic.AREA = "alley" -- shared/SecondCat.AREA: where the two catches are made

export type View = {
	bowlFirst: boolean, -- shared/TutorialOrder.bowlFirst()
	tier: number?,
	secondCatDone: boolean?, -- UI state's: nil reads as finished
	cannonId: string?, -- the cannon the picker opened at ("town" or a camp's area id)
	flyRing: string?, -- UI.cannon.fly.ring: the Park ring from Rank Up wins
}

-- The area whose Launch the picker rings for the walk-through, or nil.
function WalkRingLogic.area(view: View): string?
	if not view.bowlFirst or view.flyRing ~= nil then
		return nil
	end
	if view.secondCatDone ~= false or (view.tier or 1) >= 2 then
		return nil
	end
	if view.cannonId == WalkRingLogic.AREA then
		return nil -- the Alleyway camp's own cannon has no Alleyway card
	end
	return WalkRingLogic.AREA
end

return WalkRingLogic
