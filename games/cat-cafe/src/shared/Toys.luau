--!strict
-- #4061 (spec 1.3, "Toys (fun only)"): the Ticket Booth's two held toys. The Water Squirter sprays a harmless splash
-- and the Pool Noodle bonks with a squeak. Fun only: nothing is earned, moved, slowed or taken, and no other player
-- is touched; the server only tells nearby clients to play the effect (ToyUsed). A toy is owned once its booth prize
-- is bought (the prize's once-limit, so nothing new is saved), held as the character attribute ATTRIBUTE (set by the
-- server alone) and put away with HoldToy(nil), a respawn or a rejoin. Pure, so the specs and both sides read the
-- same rules.
--   get(id) -> Toy?                              a toy by id ("squirter", "noodle")
--   owned(save) -> { string }                    the toys a ticket save owns, in LIST order
--   useBlocker(held, sinceUse, busy) -> string?  why UseToy does nothing now, or nil
--   target(origin, look, others) -> Vector3      where the Water Squirter's splash lands

local TicketBooth = require(script.Parent.TicketBooth)
local Types = require(script.Parent.Types)

local Toys = {}

export type Toy = {
	id: string,
	name: string,
	prize: string, -- its TicketBooth prize id
	asset: string, -- its model under ReplicatedStorage.Assets (kept client-visible: the client clones it to the hand)
	aimed: boolean, -- ToyUsed carries a target point
}

Toys.ATTRIBUTE = "HeldToy"
Toys.COOLDOWN = 1.5 -- seconds between uses
Toys.RANGE = 80 -- studs: the players told about a use
Toys.SQUIRT_REACH = 24 -- studs: how far the Water Squirter aims at the nearest player
Toys.SQUIRT_AHEAD = 10 -- studs ahead when nobody is in reach

Toys.LIST = table.freeze({
	table.freeze({
		id = "squirter",
		name = "Water Squirter",
		prize = "toySquirter",
		asset = "CatCafe_Item_WaterSquirter",
		aimed = true,
	}),
	table.freeze({
		id = "noodle",
		name = "Pool Noodle",
		prize = "toyNoodle",
		asset = "CatCafe_Item_PoolNoodle",
		aimed = false,
	}),
}) :: { Toy }

function Toys.get(id: string?): Toy?
	for _, toy in Toys.LIST do
		if toy.id == id then
			return toy
		end
	end
	return nil
end

-- Whether the ticket save bought `toy` at the booth.
function Toys.owns(save: Types.TicketSave, toy: Toy): boolean
	local prize = TicketBooth.prize(toy.prize)
	return prize ~= nil and TicketBooth.owns(save, prize)
end

function Toys.owned(save: Types.TicketSave): { string }
	local out: { string } = {}
	for _, toy in Toys.LIST do
		if Toys.owns(save, toy) then
			table.insert(out, toy.id)
		end
	end
	return out
end

-- Why a use does nothing now, or nil: no toy in hand, still cooling down (`sinceUse` seconds since the last use, nil
-- for none), or busy (a catch, a rescue or a cannon flight).
function Toys.useBlocker(held: string?, sinceUse: number?, busy: boolean): string?
	if Toys.get(held) == nil then
		return "none"
	end
	if busy then
		return "busy"
	end
	if sinceUse ~= nil and sinceUse < Toys.COOLDOWN then
		return "cooldown"
	end
	return nil
end

-- Where the Water Squirter's splash lands: the nearest of `others` (other players' positions) within SQUIRT_REACH of
-- `origin`, else SQUIRT_AHEAD studs along `look` (flattened; straight ahead on +Z for a zero look).
function Toys.target(origin: Vector3, look: Vector3, others: { Vector3 }): Vector3
	local best: Vector3? = nil
	local bestDistance = Toys.SQUIRT_REACH
	for _, position in others do
		local distance = (position - origin).Magnitude
		if distance <= bestDistance then
			best = position
			bestDistance = distance
		end
	end
	if best ~= nil then
		return best
	end
	local flat = Vector3.new(look.X, 0, look.Z)
	local ahead = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, 1)
	return origin + ahead * Toys.SQUIRT_AHEAD
end

return Toys
