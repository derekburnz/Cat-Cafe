--!strict
-- #2005 section 1 (Derek2: "your net stays on top of the cat ... with an exclamation mark to show its being caught"):
-- a gold "!" badge over every stray that is being caught, on every player's screen, so others can see the cat is
-- taken. The server sets the stray's NetDown attribute while it is locked for a catch (CatService) and clears it
-- when the catch ends; the badge pops in and goes with it. It sits just above where the catcher's trust bar hangs
-- (Components/TrustBar), whatever the distance, as the billboard is that bar's height plus the badge's, centred on
-- the bar's spot. The mood icon hides while the cat is locked (MoodIcons), so the two never stack.
-- #2469 (Derek2's tackle lesson): the lesson's staged cat (shared/TackleStage.STRAY_TAG, "StagedStray") gets the same
-- "!" when IntroController sets its NetDown, so the "safe while catching" shot shows a net pinning a cat as a real one.
--   CatchMark.new()   watches the Stray and StagedStray tags
--   mark:destroy()
--
-- Roblox terms: a BillboardGui parented under a part draws over it and always faces the camera; an offset Size stays
-- the same on screen at any distance, and MaxDistance hides it past that many studs.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local Theme = require(script.Parent.Parent.Theme)
local TrustBar = require(script.Parent.Parent.Components.TrustBar)
local Tween = require(script.Parent.Parent.Components.Tween)

export type CatchMark = {
	destroy: (self: CatchMark) -> (),
}

local CatchMark = {}
CatchMark.__index = CatchMark

CatchMark.TAG = "Stray"
CatchMark.TAGS = { CatchMark.TAG, "StagedStray" } -- #2469: TackleStage.STRAY_TAG, the lesson's local cat
CatchMark.ATTRIBUTE = "NetDown"
CatchMark.BADGE = 40 -- px, the round badge
local GAP = 6 -- px between the badge and the trust bar's top

local function anchorOf(model: Instance): (BasePart?, number)
	local part: BasePart? = nil
	if model:IsA("Model") then
		part = (model :: Model).PrimaryPart
	end
	if not part then
		local found = model:FindFirstChildWhichIsA("BasePart", true)
		part = if found then found :: BasePart else nil
	end
	if not part then
		return nil, 0
	end
	assert(part, "anchor part")
	local top = part.Position.Y + part.Size.Y / 2
	if model:IsA("Model") then
		local boxCFrame, boxSize = (model :: Model):GetBoundingBox()
		top = math.max(top, boxCFrame.Position.Y + boxSize.Y / 2)
	end
	return part, top - part.Position.Y
end

function CatchMark.new(): CatchMark
	local self = setmetatable({}, CatchMark) :: any
	self._marks = {} :: { [Instance]: BillboardGui }
	self._watched = {} :: { [Instance]: { RBXScriptConnection } }
	self._connections = {} :: { RBXScriptConnection }
	for _, tag in CatchMark.TAGS do
		for _, stray in CollectionService:GetTagged(tag) do
			self:_watch(stray)
		end
		table.insert(
			self._connections,
			CollectionService:GetInstanceAddedSignal(tag):Connect(function(stray: Instance)
				self:_watch(stray)
			end)
		)
		table.insert(
			self._connections,
			CollectionService:GetInstanceRemovedSignal(tag):Connect(function(stray: Instance)
				self:_unwatch(stray)
			end)
		)
	end
	return self :: CatchMark
end

function CatchMark._watch(self: any, stray: Instance)
	if self._watched[stray] then
		return
	end
	self._watched[stray] = {
		stray:GetAttributeChangedSignal(CatchMark.ATTRIBUTE):Connect(function()
			self:_refresh(stray)
		end),
		stray.AncestryChanged:Connect(function()
			if not stray:IsDescendantOf(Workspace) then
				self:_unwatch(stray)
			end
		end),
	}
	self:_refresh(stray)
end

function CatchMark._unwatch(self: any, stray: Instance)
	local watched = self._watched[stray]
	if watched then
		for _, connection in watched do
			connection:Disconnect()
		end
		self._watched[stray] = nil
	end
	self:_drop(stray)
end

function CatchMark._refresh(self: any, stray: Instance)
	local down = stray:GetAttribute(CatchMark.ATTRIBUTE) == true
	if down and self._marks[stray] == nil then
		self:_make(stray)
	elseif not down then
		self:_drop(stray)
	end
end

function CatchMark._make(self: any, stray: Instance)
	local part, height = anchorOf(stray)
	if not part then
		return
	end
	-- centred on the trust bar's spot: the bar's half, the gap and the badge above it, and as much below
	local half = TrustBar.HEIGHT / 2 + GAP + CatchMark.BADGE
	local billboard: BillboardGui = Create("BillboardGui", {
		Name = "CatCafeCatchMark",
		Size = UDim2.fromOffset(CatchMark.BADGE + 8, 2 * half),
		StudsOffsetWorldSpace = Vector3.new(0, height + TrustBar.LIFT, 0),
		AlwaysOnTop = true,
		MaxDistance = 120,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Parent = part,
	})
	local badge: Frame = Create("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, CatchMark.BADGE / 2 + 2),
		Size = UDim2.fromOffset(CatchMark.BADGE, CatchMark.BADGE),
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		Parent = billboard,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIStroke", { Color = Theme.colors.outline, Thickness = 3 }),
	})
	local glyph: TextLabel = Create("TextLabel", {
		Name = "Glyph",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextSize = 32,
		TextColor3 = Theme.colors.paper,
		Text = "!",
		Parent = badge,
	})
	Outline.text(glyph, 3)
	Tween.popIn(badge, 0.3)
	self._marks[stray] = billboard
end

function CatchMark._drop(self: any, stray: Instance)
	local billboard: BillboardGui? = self._marks[stray]
	if billboard then
		billboard:Destroy()
		self._marks[stray] = nil
	end
end

function CatchMark.destroy(self: any)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	for stray in self._watched do
		self:_unwatch(stray)
	end
	for stray in self._marks do
		self:_drop(stray)
	end
end

return CatchMark
