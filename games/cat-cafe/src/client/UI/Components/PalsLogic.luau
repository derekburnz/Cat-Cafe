--!strict
-- Playing together's words on the UI (F92, playing-together.md sections 2, 3 and 5), pure so the cloud spec runner
-- checks them:
--   list(userIds, selfId)            the pals from PalsChanged, cleaned: whole positive ids, no repeats, never you
--   chip(count, short?)              the HUD chip's words, "+10% with pals" with one and "+15% with pals" with two or
--                                    more (shared Pals.bonus, so they match the tips), nil with none: a solo player
--                                    never sees a missing bonus; `short` (touch, #2712) "+10%" beside the headshots
--   faces(userIds)                   up to FACES ids for the chip's headshots, and how many more ("+2")
--   headshot(userId)                 the Roblox headshot picture for an id
--   arrived(name, areaName?)         the marker for a joiner whose pal is out: "Sam is in the Park", nil without an
--                                    area (the pal is at the cafe the joiner stands at)
--   inviteAsk()                      the one invite nudge's line, "Playing with a friend gives you both +10% tips.
--                                    Invite one?" (Config.PalTipBonus)
--   teamRescue(selfId, rescuerId, helperId, coins, nameOf)  the pop's line for this player: the rescuer reads
--                                    "Sam helped you free it!", the helper "You helped Alex free it!" and its tip
--                                    ("+$1,240") when there is one (none inside TeamRescueTipCooldown)
--   joinedNote(palName?, nextDoor)  #3995 (friend-join-3995.md 4): the joiner's note as (title, line): "You joined
--                                    Sam!" over "Your cafe is next door." when it is, else "Playing together" over
--                                    "You joined Sam!". No bonus words (Derek 2026-11-13)
--   arrivedNote(joinerName?)         #3995 (5): the friend's note, "Mia joined you!" over "They're at your front door."
--   nextDoorLine(palName?)           #3995 (6): a new joiner's first strip line, "Your cafe is next to Sam's: step
--                                    inside 🐾", until they walk into their own cafe
-- Names come from `nameOf`, the caller's Players lookup, with "A pal" or "your pal" when someone has left. The
-- #3995 lines cut a long display name as the cafe sign does (CafeName.shown).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShortNumber = require(script.Parent.ShortNumber)

local CafeName = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CafeName"))
local Pals = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pals")) :: any

local PalsLogic = {}

PalsLogic.FACES = 3 -- headshots on the chip before "+N"
PalsLogic.TITLE = "Team Rescue!"
PalsLogic.NOTE_TITLE = "Playing together" -- #3995: the small title over both join notes
PalsLogic.NOTE_SECONDS = 6 -- #3995: how long a join note stays; one tap puts it away sooner

function PalsLogic.list(userIds: unknown, selfId: number?): { number }
	local out: { number } = {}
	if type(userIds) ~= "table" then
		return out
	end
	local seen: { [number]: boolean } = {}
	for _, id in userIds :: { unknown } do
		if
			type(id) == "number"
			and id > 0
			and id == math.floor(id)
			and id ~= selfId
			and not seen[id]
		then
			seen[id] = true
			table.insert(out, id)
		end
	end
	return out
end

function PalsLogic.chip(count: number, short: boolean?): string?
	if count < 1 then
		return nil
	end
	local bonus: number = Pals.bonus(count)
	local percent = math.floor(bonus * 100 + 0.5)
	-- #2712: on touch "+10%" beside the headshots, so the chip takes less of the top bar
	return if short then ("+%d%%"):format(percent) else ("+%d%% with pals"):format(percent)
end

function PalsLogic.faces(userIds: { number }): ({ number }, number)
	local shown: { number } = {}
	for index = 1, math.min(#userIds, PalsLogic.FACES) do
		table.insert(shown, userIds[index])
	end
	return shown, math.max(0, #userIds - PalsLogic.FACES)
end

function PalsLogic.headshot(userId: number): string
	return ("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48"):format(math.floor(userId))
end

function PalsLogic.arrived(name: string?, areaName: string?): string?
	if areaName == nil or areaName == "" then
		return nil
	end
	return ("%s is in the %s"):format(name or "Your pal", areaName)
end

function PalsLogic.inviteAsk(): string
	return ("Playing with a friend gives you both +%d%% tips. Invite one?"):format(
		math.floor((Pals.bonus(1) :: number) * 100 + 0.5)
	)
end

function PalsLogic.teamRescue(
	selfId: number,
	rescuerId: number,
	helperId: number,
	coins: number,
	nameOf: (userId: number) -> string?
): string
	if selfId == helperId and selfId ~= rescuerId then
		local line = ("You helped %s free it!"):format(nameOf(rescuerId) or "your pal")
		if type(coins) == "number" and coins >= 1 then
			line ..= " +$" .. ShortNumber.format(math.floor(coins))
		end
		return line
	end
	return ("%s helped you free it!"):format(nameOf(helperId) or "A pal")
end

-- A name for the #3995 lines: the display name cut as the cafe sign cuts it, or nil when there is none.
local function shortName(name: string?): string?
	if type(name) ~= "string" or name == "" then
		return nil
	end
	local shown = CafeName.shown(name)
	return if shown ~= "" then shown else nil
end

function PalsLogic.joinedNote(palName: string?, nextDoor: boolean?): (string, string)
	local joined = ("You joined %s!"):format(shortName(palName) or "your friend")
	if nextDoor == true then
		return joined, "Your cafe is next door."
	end
	return PalsLogic.NOTE_TITLE, joined
end

function PalsLogic.arrivedNote(joinerName: string?): (string, string)
	return ("%s joined you!"):format(shortName(joinerName) or "A friend"),
		"They're at your front door."
end

function PalsLogic.nextDoorLine(palName: string?): string
	local name = shortName(palName)
	if name == nil then
		return "Your cafe is next door: step inside 🐾"
	end
	return ("Your cafe is next to %s's: step inside 🐾"):format(name)
end

return PalsLogic
