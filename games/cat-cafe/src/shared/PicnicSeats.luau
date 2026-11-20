--!strict
-- #5572 the Picnic Party's blanket and its three seats, worked out from the Picnic Basket station's pivot alone, so the
-- server (Gameplay's picnic strays stand still on the seats) and the client (Effects/PicnicParty lays the blanket
-- there) agree to the stud. The station's pivot is on the ground at its middle (Model-Agent's
-- CatCafe_Camp_Park_PicnicStation); the blanket lies on the ground on the station's +X side, GAP studs past HALF,
-- SIZE studs square. Pure.

local PicnicSeats = {}

PicnicSeats.SIZE = 6 -- studs along each side of the blanket (Model-Agent's CatCafe_Prop_PicnicBlanket)
-- studs from the station's pivot to its +X side: Model-Agent's #5580 station reaches 4.95 there (its parts' boxes;
-- Review-QA: the manifest's 8.66 x 7.48 footprint sits off the pivot), so 5 keeps the blanket clear of the A-frame
PicnicSeats.HALF = 5
PicnicSeats.GAP = 1 -- studs between the station's side and the blanket's near edge
PicnicSeats.THICK = 0.06 -- the blanket's height, so a seat stands on it
-- Where each seat is on the blanket, in fractions of its sides from its middle (-0.5 to 0.5): X across, Y outward.
PicnicSeats.SPOTS =
	table.freeze({ Vector2.new(-0.25, -0.15), Vector2.new(0.05, 0.05), Vector2.new(0.3, -0.05) })

local function outward(pivot: CFrame): Vector3
	local right = pivot.RightVector
	local flat = Vector3.new(right.X, 0, right.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(1, 0, 0)
end

-- The blanket's near edge on the ground, looking outward: its -Z runs out across the blanket, +X along the edge.
function PicnicSeats.near(pivot: CFrame): CFrame
	local out = outward(pivot)
	local edge = pivot.Position + out * (PicnicSeats.HALF + PicnicSeats.GAP)
	return CFrame.lookAt(edge, edge + out)
end

-- The blanket's middle on the ground, turned as `near`.
function PicnicSeats.centre(pivot: CFrame): CFrame
	return PicnicSeats.near(pivot) * CFrame.new(0, 0, -PicnicSeats.SIZE / 2)
end

-- A spot `up` studs over the blanket's top at `at` (fractions from its middle), turned as `near`.
function PicnicSeats.spot(pivot: CFrame, at: Vector2, up: number): CFrame
	return PicnicSeats.centre(pivot)
		* CFrame.new(at.X * PicnicSeats.SIZE, PicnicSeats.THICK + up, -at.Y * PicnicSeats.SIZE)
end

-- Seat `n` (1 to 3) on the blanket's top, facing back toward the basket; nil for another n.
function PicnicSeats.seat(pivot: CFrame, n: number): CFrame?
	local at: Vector2? = PicnicSeats.SPOTS[n]
	if at == nil then
		return nil
	end
	local spot = PicnicSeats.spot(pivot, at :: Vector2, 0)
	local basket = Vector3.new(pivot.Position.X, spot.Position.Y, pivot.Position.Z)
	return CFrame.lookAt(spot.Position, basket)
end

-- All three seats, in order.
function PicnicSeats.seats(pivot: CFrame): { CFrame }
	local out: { CFrame } = {}
	for n = 1, #PicnicSeats.SPOTS do
		table.insert(out, PicnicSeats.seat(pivot, n) :: CFrame)
	end
	return out
end

return PicnicSeats
