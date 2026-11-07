--!strict
-- Catch v3 on the cat (catch-rework.md section 7, #1892). As the server judges each ring of this player's catch
-- (CatchJudged), the cat answers it: ears perk and a small lean in on a hit, a wriggle on a Miss, a swat at the net
-- when a paw ring is tapped (graded "miss" on a ring whose CatchSchedule kind is "paw"), and a small perk when a paw
-- ring is left alone ("left"). When trust fills (CatchResult success with its sixth `finish` argument), the net wraps
-- the cat and wobbles twice in Presets.catchReact.wrap.seconds, with the cat hunkering inside it, so VFX-Agent's
-- finish pop lands as the wobble ends. A Sleepy stray wakes from its curl while this player is catching it
-- (Cats.setCatching). The mood stances themselves are in Cats.luau, from the stray's Mood attribute.
--
-- Every new field is optional: an older server's CatchResult (no `finish`) plays no wrap, and circles with no kind
-- are plain rings. With Reduce Motion the cat doesn't move and the net closes without rocking. Listening only:
-- nothing here fires a remote, and the net is a local part that nothing collides with.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Cats = require(script.Parent.Cats)
local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Net = require(script.Parent.Parent.Net)
local NetPin = require(script.Parent.NetPin)
local Presets = require(script.Parent.Presets)

local CatchReact = {}

type Catching = { model: Model, kinds: { [number]: string } }

local catching: { [string]: Catching } = {}
local started = false

local function strayById(strayId: string): Model?
	for _, instance in CollectionService:GetTagged("Stray") do
		if instance:IsA("Model") and instance:GetAttribute("StrayId") == strayId then
			return instance :: Model
		end
	end
	return nil
end

-- The ring kinds by index from CatchSchedule's circles ("single", "double" or "paw"; missing on older servers).
local function kindsOf(circles: unknown): { [number]: string }
	local kinds: { [number]: string } = {}
	if type(circles) ~= "table" then
		return kinds
	end
	for index, circle in circles :: { any } do
		if
			type(index) == "number"
			and type(circle) == "table"
			and type(circle.kind) == "string"
		then
			kinds[index] = circle.kind
		end
	end
	return kinds
end

local function finish(strayId: string)
	local entry: Catching? = catching[strayId]
	catching[strayId] = nil
	if entry ~= nil then
		Cats.setCatching(entry.model, false)
	end
end

-- The net closing over the cat and wobbling twice: a local mesh ball round the cat's box, gone after `seconds`.
local function wrapNet(model: Model)
	local w = Presets.catchReact.wrap
	local frame, size = model:GetBoundingBox()
	if Context.distance(frame.Position) > Context.budget.animRadius then
		return
	end
	local still = Context.reducedMotion()
	local base = math.max(size.X, size.Y, size.Z)
	local net = Instance.new("Part")
	net.Name = "EffectsNetWrap"
	net.Shape = Enum.PartType.Ball
	net.Material = Enum.Material.ForceField
	net.Color = w.color
	net.Transparency = w.transparency
	net.Anchored = true
	net.CanCollide = false
	net.CanQuery = false
	net.CanTouch = false
	net.CastShadow = false
	net.Parent = Workspace
	local began = os.clock()
	local connection: RBXScriptConnection? = nil
	local function place()
		local alpha = (os.clock() - began) / w.seconds
		if alpha >= 1 or net.Parent == nil then
			local live: RBXScriptConnection? = connection
			if live then
				live:Disconnect()
			end
			net:Destroy()
			return
		end
		local scale, rock = Logic.netWrap(alpha)
		net.Size = Vector3.one * base * scale
		net.CFrame = frame * CFrame.Angles(0, 0, if still then 0 else rock)
	end
	place()
	connection = RunService.RenderStepped:Connect(place)
end

function CatchReact.start()
	if started then
		return
	end
	started = true

	Net.on("CatchSchedule", function(strayId: string, circles: unknown)
		if type(strayId) ~= "string" then
			return
		end
		local model = strayById(strayId)
		if model == nil then
			return
		end
		local old: Catching? = catching[strayId]
		if old ~= nil and old.model ~= model then
			Cats.setCatching(old.model, false)
		end
		catching[strayId] = { model = model, kinds = kindsOf(circles) }
		Cats.setCatching(model, true)
	end)

	Net.on("CatchJudged", function(strayId: string, index: unknown, grade: unknown)
		local entry: Catching? = catching[strayId]
		if entry == nil or Context.reducedMotion() then
			return
		end
		local kind = if type(index) == "number" then entry.kinds[index] else nil
		local react: Logic.CatchReact? = Logic.catchReactFor(grade, kind)
		if react ~= nil then
			Cats.react(entry.model, react :: Logic.CatchReact)
		end
	end)

	Net.on(
		"CatchResult",
		function(
			strayId: string,
			_grades: unknown,
			success: unknown,
			_charmGain: unknown,
			_retryAt: unknown,
			result: unknown
		)
			local entry: Catching? = catching[strayId]
			local model = if entry ~= nil then entry.model else strayById(strayId)
			finish(strayId)
			-- the v3 finish: only a server that sends it plays the wrap, and only on a catch
			if success ~= true or type(result) ~= "table" or model == nil then
				return
			end
			-- the net already down over the cat (#2005) wobbles; an older server's catch closes the ball round it
			if not NetPin.wobble(model) then
				wrapNet(model)
			end
			if not Context.reducedMotion() then
				Cats.react(model, "wrap")
			end
		end
	)
end

return CatchReact
