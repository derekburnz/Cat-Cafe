--!strict
-- #3171 (Derek2: "make the like the game show an image of the gamepage with a big click cursor over like"): a small
-- drawing of the game's Roblox page for the like gift card, so players see where the thumbs-up is. Drawn from frames
-- in our colours, not a screenshot: a picture tile, the game's name, a grey "By" line, the green Play button with
-- 👍 / 👎 beside it, with a big pointing-hand cursor on 👍 that taps it. No names, numbers or player details.
-- The tap is a small bob and a ring on 👍; Reduce Motion keeps the cursor still. Nothing here is a button.
--   LikePicture.new(parent, layoutOrder?) -> LikePicture
--   picture.frame          the drawing (PICTURE_H tall, its parent's width)
--   picture:play()         start the tap loop (show calls it)
--   picture:stop()
--   picture:destroy()

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Create = require(script.Parent.Create)
local Outline = require(script.Parent.Outline)
local Theme = require(script.Parent.Parent.Theme)

export type LikePicture = {
	frame: Frame,
	play: (self: LikePicture) -> (),
	stop: (self: LikePicture) -> (),
	destroy: (self: LikePicture) -> (),
}

local LikePicture = {}
LikePicture.__index = LikePicture

LikePicture.PICTURE_H = 100
local PAD = 8
local TILE_W = 128 -- the game's picture, 16:9 near enough
local TILE_H = LikePicture.PICTURE_H - PAD * 2
local THUMB = 28 -- the 👍 and 👎 chips
local CURSOR = 50
local THUMBS_W = THUMB * 2 + 22 -- 👍 and 👎 beside Play
local PAGE = Color3.fromHex("232527") -- a dark page, as the game page looks in dark mode
local CHIP = Color3.fromHex("393B3D")
local TAP_IN = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TAP_OUT = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RING = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local LOOP_SECONDS = 1.6

local function corner(radius: number): UICorner
	return Create("UICorner", { CornerRadius = UDim.new(0, radius) }) :: UICorner
end

local function bar(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	colour: Color3
): Frame
	return Create("Frame", {
		Name = name,
		BackgroundColor3 = colour,
		BorderSizePixel = 0,
		Position = UDim2.new(0, x, 0, y),
		Size = UDim2.new(w, 0, 0, h),
		Parent = parent,
	}, { corner(math.floor(h / 2)) }) :: Frame
end

function LikePicture.new(parent: Instance, layoutOrder: number?): LikePicture
	local self = setmetatable({}, LikePicture) :: any
	self._token = 0

	local frame: Frame = Create("Frame", {
		Name = "LikePicture",
		BackgroundColor3 = PAGE,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Size = UDim2.new(1, 0, 0, LikePicture.PICTURE_H),
		LayoutOrder = layoutOrder or 0,
		Parent = parent,
	}, { corner(Theme.sizes.radius) })
	Outline.border(frame, 2)
	self.frame = frame

	-- the game's picture: the cafe's colours and a cat at a cup
	Create("TextLabel", {
		Name = "Tile",
		BackgroundColor3 = Theme.colors.caramel,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(PAD, PAD),
		Size = UDim2.fromOffset(TILE_W, TILE_H),
		FontFace = Theme.fonts.display,
		TextSize = 34,
		Text = "🐱☕",
		TextColor3 = Theme.colors.white,
		Parent = frame,
	}, {
		corner(6),
		Create("UIGradient", {
			Color = ColorSequence.new(Theme.colors.gold, Theme.colors.caramel),
			Rotation = 90,
		}),
	})

	-- the right side: name, a "By" line, Play, then the thumbs row
	local side: Frame = Create("Frame", {
		Name = "Side",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD * 2 + TILE_W, PAD),
		Size = UDim2.new(1, -(PAD * 3 + TILE_W), 1, -PAD * 2),
		Parent = frame,
	})
	Create("TextLabel", {
		Name = "Name",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		FontFace = Theme.fonts.display,
		TextSize = 16,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "Catch a Cat Cafe",
		Parent = side,
	})
	bar(side, "By", 0, 21, 0.55, 5, Color3.fromHex("6B6E70"))
	Create("TextLabel", {
		Name = "Play",
		BackgroundColor3 = Color3.fromHex("33B249"),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 27),
		Size = UDim2.new(1, -(THUMBS_W + 8), 0, THUMB),
		FontFace = Theme.fonts.display,
		TextSize = 16,
		TextColor3 = Theme.colors.white,
		Text = "▶",
		Parent = side,
	}, { corner(6) })

	local row: Frame = Create("Frame", {
		Name = "Thumbs",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 27),
		Size = UDim2.fromOffset(THUMBS_W, THUMB),
		Parent = side,
	})
	local up: TextLabel = Create("TextLabel", {
		Name = "Up",
		BackgroundColor3 = CHIP,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(THUMB + 8, THUMB),
		FontFace = Theme.fonts.display,
		TextSize = 18,
		Text = "👍",
		Parent = row,
	}, { corner(6) })
	Create("UIStroke", {
		Name = "Glow",
		Color = Theme.colors.gold,
		Thickness = 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = up,
	})
	Create("TextLabel", {
		Name = "Down",
		BackgroundColor3 = CHIP,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(THUMB + 14, 0),
		Size = UDim2.fromOffset(THUMB + 8, THUMB),
		FontFace = Theme.fonts.display,
		TextSize = 18,
		Text = "👎",
		TextTransparency = 0.35,
		Parent = row,
	}, { corner(6) })
	-- the like bar under Play, all green: no real numbers
	bar(side, "Votes", 0, 27 + THUMB + 8, 1, 5, Color3.fromHex("33B249"))

	-- the ring 👍 gives off at each tap
	local ring: Frame = Create("Frame", {
		Name = "Ring",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Parent = up,
	}, { corner(8) })
	local ringStroke: UIStroke = Create("UIStroke", {
		Color = Theme.colors.gold,
		Thickness = 2,
		Transparency = 1,
		Parent = ring,
	}) :: UIStroke
	self._ring, self._ringStroke = ring, ringStroke

	-- the big pointing-hand cursor, its fingertip on 👍
	local cursor: TextLabel = Create("TextLabel", {
		Name = "Cursor",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.3, 0.05), -- the fingertip
		Position = UDim2.fromScale(0.62, 0.72), -- low on 👍, so the thumb still shows
		Size = UDim2.fromOffset(CURSOR, CURSOR),
		FontFace = Theme.fonts.display,
		TextSize = CURSOR - 8, -- the hand is wider than its size
		Text = "👆",
		ZIndex = 5,
		Parent = up,
	})
	Outline.text(cursor, 2)
	self._cursor = cursor
	self._rest = cursor.Position
	return self :: LikePicture
end

-- One tap: the cursor dips onto 👍 and back, and the ring grows and fades.
function LikePicture._tap(self: any)
	local cursor: TextLabel = self._cursor
	local rest: UDim2 = self._rest
	TweenService:Create(cursor, TAP_IN, { Position = rest - UDim2.fromOffset(0, 6) }):Play()
	task.delay(TAP_IN.Time, function()
		TweenService:Create(cursor, TAP_OUT, { Position = rest }):Play()
	end)
	local ring: Frame = self._ring
	local stroke: UIStroke = self._ringStroke
	ring.Size = UDim2.fromScale(1, 1)
	stroke.Transparency = 0
	TweenService:Create(ring, RING, { Size = UDim2.new(1, 14, 1, 14) }):Play()
	TweenService:Create(stroke, RING, { Transparency = 1 }):Play()
end

function LikePicture.play(self: any)
	self._token += 1
	local token = self._token
	self._cursor.Position = self._rest
	if GuiService.ReducedMotionEnabled then
		return
	end
	task.spawn(function()
		while self._token == token and self.frame.Parent ~= nil do
			self:_tap()
			task.wait(LOOP_SECONDS)
		end
	end)
end

function LikePicture.stop(self: any)
	self._token += 1
end

function LikePicture.destroy(self: any)
	self:stop()
	self.frame:Destroy()
end

return LikePicture
