--!strict
-- The Ticket Booth's buy moment (#4061, ticket-booth.md): when you buy a prize, paper tickets in the booth's red,
-- cream and gold fly up off its counter with a few gold sparkles and one gold ring at its feet. Only you see your
-- own, and only when you are near the booth (the window opens from its prompt, so you nearly always are). Reduce
-- Motion keeps fewer tickets and no ring (Particles' own rule); Low performance keeps the sparkles alone.
--
-- Sources: the `TicketBooth`-tagged model (WorldBuilder) with Model-Agent's `BangAnchor` attachment, and each
-- ProfileSync's `ticketBooth` view: tickets spent going up between two syncs is a prize bought, the same read as the
-- sound's (Audio's Logic.ticketPrizeBought). The first sync only sets the count. Listening only. Numbers in
-- Presets.boothFx.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Net = require(script.Parent.Parent.Net)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local BoothFx = {}

local started = false

-- True when a prize was bought between two `ticketBooth` views (nil while the switch is off or the tier is not
-- reached): the tickets spent went up.
function BoothFx.bought(before: any, after: any): boolean
	if type(before) ~= "table" or type(after) ~= "table" then
		return false
	end
	local was, now = before.spent, after.spent
	return type(was) == "number" and type(now) == "number" and now > was
end

local function booth(): Model?
	for _, instance in CollectionService:GetTagged(Presets.boothFx.tag) do
		if instance:IsA("Model") and instance:IsDescendantOf(Workspace) then
			return instance :: Model
		end
	end
	return nil
end

local function play()
	local model = booth()
	if model == nil or model:FindFirstChildWhichIsA("BasePart", true) == nil then
		return -- not placed, or not streamed in
	end
	local p = Presets.boothFx
	local middle, size = model:GetBoundingBox()
	local at = middle.Position + Vector3.new(0, size.Y * p.under, 0)
	local anchor = model:FindFirstChild(p.anchor, true)
	if anchor ~= nil and anchor:IsA("Attachment") then
		at = (anchor :: Attachment).WorldPosition
	end
	if Context.distance(at) > Context.budget.animRadius then
		return
	end
	Particles.burst("catchSparkle", at, p.sparkles, Presets.palette.golden)
	if Context.lowPerformance then
		return
	end
	Particles.confetti(at, math.ceil(Context.budget.confetti * p.tickets), p.colours)
	Particles.ring(middle.Position - Vector3.new(0, size.Y / 2, 0), Presets.palette.golden, p.ring)
end

function BoothFx.start()
	if started then
		return
	end
	started = true
	local seen = false
	local last: any = nil
	Net.on("ProfileSync", function(state: unknown)
		if type(state) ~= "table" then
			return
		end
		local view = (state :: { [string]: unknown }).ticketBooth
		local bought = seen and BoothFx.bought(last, view)
		seen, last = true, view
		if bought then
			play()
		end
	end)
end

return BoothFx
