--!strict
-- Moments share (#4911, Design-Agent's spec on the issue): a "Share this catch!" button on the big catch card, so a
-- player can send the picture of a Mythical or Secret catch to friends through Roblox's own share sheet. Pure; the
-- card (Screens/BigPull) draws the button and UI.securedRare asks `offer`.
--   offer(ask) -> boolean       whether this card shows the button
--   RARITIES                    the rarities that offer it (gold and rainbow coats of them too)
--   PLAY_SECONDS                session play before the first offer
--   CLOSE_AT                    the card's close time while the button shows (the plain card closes at 2.4 s)
--   LAUNCH_DATA                 what a join through the shared picture carries (shared/JoinSource.SHARE)
--   REPORTS                     the TelemetryReport "share" values, each logged once a session by the server

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JoinSource = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("JoinSource"))

local ShareCatchLogic = {}

ShareCatchLogic.RARITIES = { Mythical = true, Secret = true } :: { [string]: boolean }
ShareCatchLogic.PLAY_SECONDS = 5 * 60
ShareCatchLogic.CLOSE_AT = 6
ShareCatchLogic.LAUNCH_DATA = JoinSource.SHARE
ShareCatchLogic.REPORTS = { "shown", "tapped", "shared", "cancelled", "failed" }

export type Ask = {
	on: boolean, -- the momentsShare switch
	allowed: boolean?, -- PolicyService's IsContentSharingAllowed; nil until it came (or when it failed)
	rarity: string,
	tutorialDone: boolean,
	played: number, -- seconds of play this session
	offered: boolean, -- the button already showed this session
}

-- Only with the switch on, sharing allowed for this player, a Mythical or Secret cat, the walk-through done, five
-- minutes into the session and once a session.
function ShareCatchLogic.offer(ask: Ask): boolean
	return ask.on
		and ask.allowed == true
		and ShareCatchLogic.RARITIES[ask.rarity] == true
		and ask.tutorialDone
		and ask.played >= ShareCatchLogic.PLAY_SECONDS
		and not ask.offered
end

return ShareCatchLogic
