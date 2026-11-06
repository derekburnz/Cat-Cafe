--!strict
-- The Jukebox Pass (#1168 row 2, Monetization-Agent 2026-11-06), pure: four extra cafe songs a pass owner may pick
-- to play in place of the day and night rotation. Cosmetic only. Owning the pass is looked up each session
-- (Config.JukeboxPassId, 0 until made), so nothing is saved for it; profile.jukebox is the pick, nil for the normal
-- rotation, and a pick the player no longer owns plays the rotation. Each track's `cue` is the client Audio cue that
-- Sound-Agent adds (Audio/Cues); the client plays the pick while the cafe music would play.
--   owned(ownsPass) -> { id }            every track id while the pass is owned, else none
--   shown(pick, ownsPass) -> id?         the pick if it is owned, else nil (the rotation)
--   pickFor(raw, ownsPass) -> (ok, id?)  what SetJukeboxTrack may save: nil/""/"default" or an owned track
--   sanitizePick(raw) -> id?             a saved pick made whole (a known id or nil)

local Config = require(script.Parent.Config)

local Jukebox = {}

export type Track = { id: string, name: string, cue: string }

Jukebox.DEFAULT = "default" -- the normal day and night rotation; "" and nil mean the same
Jukebox.PASS_KEY = "JukeboxPassId"

local TRACKS: { Track } = {
	{ id = "jukebox_rainy_window", name = "Rainy Window", cue = "musicJukeboxRainyWindow" },
	{ id = "jukebox_catnap_waltz", name = "Catnap Waltz", cue = "musicJukeboxCatnapWaltz" },
	{ id = "jukebox_bakery_bounce", name = "Bakery Bounce", cue = "musicJukeboxBakeryBounce" },
	{ id = "jukebox_starlight_purr", name = "Starlight Purr", cue = "musicJukeboxStarlightPurr" },
}
for _, track in TRACKS do
	table.freeze(track)
end
table.freeze(TRACKS)
Jukebox.TRACKS = TRACKS

local byId: { [string]: Track } = {}
for _, track in TRACKS do
	byId[track.id] = track
end

function Jukebox.get(id: string): Track?
	return byId[id]
end

function Jukebox.passId(): number
	local id = (Config :: any)[Jukebox.PASS_KEY]
	return if type(id) == "number" then id else 0
end

local function ownsIt(ownsPass: (passId: number) -> boolean): boolean
	local id = Jukebox.passId()
	return id ~= 0 and ownsPass(id)
end

function Jukebox.owned(ownsPass: (passId: number) -> boolean): { string }
	local ids: { string } = {}
	if ownsIt(ownsPass) then
		for _, track in TRACKS do
			table.insert(ids, track.id)
		end
	end
	return ids
end

function Jukebox.shown(pick: string?, ownsPass: (passId: number) -> boolean): string?
	if pick == nil or byId[pick] == nil or not ownsIt(ownsPass) then
		return nil
	end
	return pick
end

function Jukebox.pickFor(raw: unknown, ownsPass: (passId: number) -> boolean): (boolean, string?)
	if raw == nil or raw == "" or raw == Jukebox.DEFAULT then
		return true, nil
	end
	if type(raw) ~= "string" or byId[raw] == nil or not ownsIt(ownsPass) then
		return false, nil
	end
	return true, raw
end

function Jukebox.sanitizePick(raw: unknown): string?
	return if type(raw) == "string" and byId[raw] ~= nil then raw else nil
end

return Jukebox
