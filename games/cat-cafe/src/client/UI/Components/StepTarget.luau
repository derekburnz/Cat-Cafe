--!strict
-- #2697 (Derek2 11-09: "HIGHTLIGHT/FLASH EVERYTHING make it insanely clear what to click with arrows and flashing
-- highlights around buttons for tutorial steps"): the one step-target highlight every tutorial step uses.
--   StepTarget.ui(target, on)   a button on screen: the pulsing gold ring (Components/TutorialGlow) and the big
--                               bouncing arrow at it (Components/TutorialArrow); off takes both away
--   StepTarget.new(parent)      the world half, one per client:
--     :show(target)             a thing in the world (the Bait bowl, the cannon, the alley's stray spot): a flashing
--                               gold Highlight round it and, while it is off screen, the big arrow at the screen's
--                               edge pointing toward it. The marker over it (Components/WorldMarker) says what it is
--                               and how far. Calling it again with the same target is free.
--     :hide(), :destroy()
-- The Highlight goes round the target's model when that model is one thing (StepTargetLogic.small), else round the
-- part alone, and never round a see-through spot. With Roblox's Reduce Motion on, the Highlight holds steady and the
-- arrow does not bob.
--
-- Roblox terms: a Highlight draws a coloured fill and outline round its Adornee (a model or a part); AlwaysOnTop shows
-- it through walls, so the bowl behind the cafe still shows where it is. It is made by this client, so no other player
-- sees it. WorldToViewportPoint turns a world position into a screen pixel and a depth.

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Scale = require(script.Parent.Parent.Scale)
local StepTargetLogic = require(script.Parent.StepTargetLogic)
local Theme = require(script.Parent.Parent.Theme)
local TutorialArrow = require(script.Parent.TutorialArrow)
local TutorialGlow = require(script.Parent.TutorialGlow)

local StepTarget = {}

-- #4152: the HUD's pieces in screen px (UI.init sets it once the HUD is built), which the edge arrow keeps clear of
local avoid: (() -> { StepTargetLogic.Box })? = nil

function StepTarget.setAvoid(boxes: (() -> { StepTargetLogic.Box })?)
	avoid = boxes
end
StepTarget.__index = StepTarget

StepTarget.NAME = "CatCafeStepTarget"
local ARROW = 64 -- design px, the size of TutorialArrow's
local FLASH_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local FILL_DIM, FILL_BRIGHT = 0.85, 0.45
local EDGE_REACH = 1.5 -- #4158: how far the drawn edge arrow reaches from its centre, in arrow sizes
local LOOK_SECONDS = 0.05 -- the edge arrow follows the camera at 20 Hz

export type Target = BasePart | Attachment | Vector3

export type StepTarget = {
	show: (self: StepTarget, target: Target) -> (),
	hide: (self: StepTarget) -> (),
	destroy: (self: StepTarget) -> (),
}

function StepTarget.ui(target: GuiObject?, on: boolean)
	TutorialGlow.set(target, on)
end

-- #2751 (Laptop-Tester: the food step's ring never showed): a see-through marker inside a whole plot (the BaitBowl
-- anchor) has nothing to ring itself, so the visible thing standing on it (the bowl CafeService puts in the plot's
-- Bait folder) takes the Highlight: the nearest visible part within NEAR studs that is not a floor or a wall, as its
-- own model when that is one small thing.
local NEAR = 5
local PIECE = 12 -- studs: a part longer than this (a floor, a wall) is not the thing on the marker
local RETRY_SECONDS = 1 -- a target with nothing to ring looks again this often (the bowl streams in later)

local function visibleNear(within: Instance, at: Vector3): Instance?
	local best: BasePart? = nil
	local bestDistance = NEAR
	for _, item in within:GetDescendants() do
		if item:IsA("BasePart") and item.Transparency < 0.95 then
			local size = item.Size
			if math.max(size.X, size.Y, size.Z) <= PIECE then
				local distance = (item.Position - at).Magnitude
				if distance < bestDistance then
					best, bestDistance = item :: BasePart, distance
				end
			end
		end
	end
	if best == nil then
		return nil
	end
	local owner = best:FindFirstAncestorOfClass("Model")
	if owner ~= nil and owner ~= within and StepTargetLogic.small(owner:GetExtentsSize()) then
		return owner
	end
	return best
end

-- What the Highlight goes round: the target's model when it is one small thing, else the part, else the visible
-- thing on a see-through marker (visibleNear), nil for a bare position or a marker with nothing on it.
local function adornee(target: Target): Instance?
	if typeof(target) ~= "Instance" then
		return nil
	end
	local part: BasePart? = nil
	if target:IsA("BasePart") then
		part = target
	elseif target:IsA("Attachment") and target.Parent and target.Parent:IsA("BasePart") then
		part = target.Parent :: BasePart
	end
	if part == nil then
		return nil
	end
	local model = part:FindFirstAncestorOfClass("Model")
	if
		model ~= nil
		and model ~= (Workspace :: Instance)
		and StepTargetLogic.small(model:GetExtentsSize())
	then
		return model
	end
	if part.Transparency >= 0.95 then
		local within = model or part.Parent
		return if within ~= nil and within ~= (Workspace :: Instance)
			then visibleNear(within, part.Position)
			else nil
	end
	return part
end

local function position(target: Target): Vector3?
	if typeof(target) == "Vector3" then
		return target
	elseif typeof(target) == "Instance" then
		if target:IsA("BasePart") then
			return target.Position
		elseif target:IsA("Attachment") then
			return target.WorldPosition
		end
	end
	return nil
end

function StepTarget.new(parent: Instance): StepTarget
	local self = setmetatable({}, StepTarget) :: any
	self._target = nil :: Target?
	self._loop = nil :: RBXScriptConnection?
	self._flash = nil :: Tween?
	local gui = Instance.new("ScreenGui")
	gui.Name = StepTarget.NAME
	gui.IgnoreGuiInset = true -- WorldToViewportPoint's pixels are the whole screen's
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4 -- under the windows, so an open window covers it
	gui.Enabled = false
	gui.Parent = parent
	self._gui = gui
	local arrow = TutorialArrow.make("EdgeArrow")
	arrow.Parent = gui
	self._arrow = arrow
	local highlight = Instance.new("Highlight")
	highlight.Name = "StepTargetHighlight"
	highlight.FillColor = Theme.colors.gold
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = FILL_BRIGHT
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = false
	-- under the camera (this client's own, inside Workspace) so it draws for sure with its Adornee in the world; a
	-- Highlight under a ScreenGui may not (Review-Agent on #2751)
	highlight.Parent = Workspace.CurrentCamera or gui
	self._highlight = highlight
	return self :: StepTarget
end

function StepTarget._place(self: any)
	local target: Target? = self._target
	local arrow: Frame = self._arrow
	local camera = Workspace.CurrentCamera
	local at = if target ~= nil then position(target) else nil
	if camera == nil or at == nil then
		arrow.Visible = false
		return
	end
	-- #3153 (Derek2: "the arrow points randomly"): while the big arrow points at a button the step wants pressed (the
	-- Upgrades tile), this one at the screen's edge keeps away, so there is one arrow to follow
	if TutorialArrow.leading() then
		arrow.Visible = false
		return
	end
	local px = ARROW * Scale.get()
	local point = camera:WorldToViewportPoint(at)
	local place = StepTargetLogic.edge(point, camera.ViewportSize, px)
	if place == nil then
		arrow.Visible = false
		return
	end
	local boxes = avoid
	if boxes == nil then
		arrow:SetAttribute("ClearResult", "skipped") -- debug for Studio checks (#4158)
	else
		-- Review-QA on #4158 (667x375): turned and bobbing, the drawn arrow (its head glyph overflows the frame) reaches
		-- about 1.5 times its size from its centre, past its own square
		local list = boxes()
		local clear, how =
			StepTargetLogic.clear(place, px, list, camera.ViewportSize, nil, px * EDGE_REACH)
		-- debug for Studio checks (#4158): how many HUD boxes it kept clear of, and which way it found a spot
		arrow:SetAttribute("AvoidCount", #list)
		arrow:SetAttribute("ClearResult", how)
		arrow:SetAttribute("PosY", if clear ~= nil then clear.y else place.y)
		if clear == nil then
			arrow.Visible = false -- no spot on this edge is clear of the HUD (a short phone)
			return
		end
		place = clear
	end
	arrow.Size = UDim2.fromOffset(px, px)
	arrow.Position = UDim2.fromOffset(place.x, place.y)
	arrow.Rotation = place.rotation
	local head = arrow:FindFirstChild("Head", true)
	if head and head:IsA("TextLabel") then
		(head :: TextLabel).TextSize = px
	end
	arrow.Visible = true
end

-- The flashing Highlight round what `target` shows, when there is something to ring.
function StepTarget._ring(self: any, target: Target)
	local highlight: Highlight = self._highlight
	local around = adornee(target)
	highlight.Adornee = around
	highlight.Enabled = around ~= nil
	highlight.FillTransparency = FILL_BRIGHT
	if around ~= nil and self._flash == nil and not GuiService.ReducedMotionEnabled then
		local flash = TweenService:Create(highlight, FLASH_INFO, {
			FillTransparency = FILL_DIM,
			OutlineTransparency = 0.4,
		})
		flash:Play()
		self._flash = flash
	end
end

function StepTarget.show(self: any, target: Target)
	if self._target == target and self._gui.Enabled then
		return
	end
	self:hide()
	self._target = target
	self:_ring(target)
	self._gui.Enabled = true
	local clock, retry = 0, 0
	self._loop = RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		retry += dt
		if clock < LOOK_SECONDS then
			return
		end
		clock = 0
		if retry >= RETRY_SECONDS then
			retry = 0
			if self._highlight.Adornee == nil then
				self:_ring(target) -- #2751: the thing to ring may have streamed in since
			end
		end
		local part = if typeof(target) == "Instance" then target else nil
		if part ~= nil and part.Parent == nil then
			self:hide() -- streamed out or gone: the next step names a new target
			return
		end
		self:_place()
	end)
	self:_place()
end

function StepTarget.hide(self: any)
	local loop: RBXScriptConnection? = self._loop
	if loop then
		loop:Disconnect()
		self._loop = nil
	end
	local flash: Tween? = self._flash
	if flash then
		flash:Cancel()
		self._flash = nil
	end
	self._target = nil
	self._highlight.Enabled = false
	self._highlight.Adornee = nil
	self._arrow.Visible = false
	self._gui.Enabled = false
end

-- The edge arrow while it shows, or nil (the UI gate's scenes read it).
function StepTarget.edgeArrow(self: any): Frame?
	local arrow: Frame = self._arrow
	return if self._gui.Enabled and arrow.Visible then arrow else nil
end

function StepTarget.destroy(self: any)
	self:hide()
	self._highlight:Destroy()
	self._gui:Destroy()
end

return StepTarget
