--!strict
-- #2766 (Derek2 2026-11-09: "do whatever you suggest", the audience 16+ and past 100 visits): the update Event's ask.
-- Roblox shows an Event only on the game's page, and only players who tap Notify Me hear when it starts, so a player
-- in the game gets one slide-in ask a session (Screens/AskCard, through UI.asks.card) to tap Remind me, which opens
-- Roblox's own Notify Me prompt. Asked only before the Event starts (Config.UpdateEventId, UpdateEventStartsAt), only
-- to a player past the tutorial, never to one who already answered Roblox's prompt (Going or Not going), and nothing
-- is locked behind it. Both Roblox calls fail quietly where they are not offered.
--   EventRsvp.due(id, startsAt, now) -> boolean   pure: an Event is set and has not started
--   EventRsvp.window(played) -> boolean            pure: the session is 3 to 10 minutes old (#3450)
--   EventRsvp.status(id) -> string?                "none", "going" or "not_going", nil when Roblox cannot say
--   EventRsvp.prompt(id) -> string?                Roblox's Notify Me prompt; its answer as status says, nil on failure
--   EventRsvp.title(startsAt, now) -> string       the ask's words
--
-- Roblox terms: an Event (Creator Hub, Events) is a dated happening on the game's page. SocialService's
-- PromptRsvpToEventAsync shows Roblox's own Notify Me prompt for one, and GetEventRsvpStatusAsync says what this player
-- answered (Enum.RsvpStatus: None, NotGoing, Going). Both are client calls that yield.

local SocialService = game:GetService("SocialService")

local EventRsvp = {}

EventRsvp.REMIND = "Remind me"
EventRsvp.LATER = "Not now"
EventRsvp.ASK_SECONDS = 20
EventRsvp.SOON_SECONDS = 12 * 3600 -- an Event this close is "today"
-- #3450 (Derek 2026-11-12: "prompt them 3-10minutes into the game"): the ask comes only in this part of a session,
-- counted in seconds since the player's game started.
EventRsvp.FROM_SECONDS = 180
EventRsvp.UNTIL_SECONDS = 600

function EventRsvp.due(id: unknown, startsAt: unknown, now: number): boolean
	return type(id) == "string"
		and string.match(id :: string, "^%d+$") ~= nil
		and type(startsAt) == "number"
		and now < (startsAt :: number)
end

function EventRsvp.window(played: number): boolean
	return played >= EventRsvp.FROM_SECONDS and played <= EventRsvp.UNTIL_SECONDS
end

local function named(status: unknown): string?
	if status == Enum.RsvpStatus.Going then
		return "going"
	elseif status == Enum.RsvpStatus.NotGoing then
		return "not_going"
	elseif status == Enum.RsvpStatus.None then
		return "none"
	end
	return nil
end

function EventRsvp.status(id: string): string?
	local ok, status = pcall(function()
		return (SocialService :: any):GetEventRsvpStatusAsync(id)
	end)
	return if ok then named(status) else nil
end

function EventRsvp.prompt(id: string): string?
	local ok, status = pcall(function()
		return (SocialService :: any):PromptRsvpToEventAsync(id)
	end)
	return if ok then named(status) else nil
end

function EventRsvp.title(startsAt: number, now: number): string
	local when = if startsAt - now <= EventRsvp.SOON_SECONDS then "today" else "soon"
	return ("🔔 A new update is coming %s! Want a reminder when it lands?"):format(when)
end

return EventRsvp
