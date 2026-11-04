--!strict
-- Draws a glyph's picture from the uploaded icon sheet (Theme.iconSheet, assets/cat-cafe/ui/icons) over the
-- TextLabel that shows that glyph, so the menus get drawn icons in place of emoji (Derek 2026-10-27: "a lot of the
-- symbols like index upgrades and cats could use a tiny bit more quality also").
--
-- The emoji stays the fallback: it shows until the picture has loaded (a new upload draws blank until Roblox
-- moderation approves it), for glyphs the sheet has no picture of, and with no sheet id at all.
--
--   IconArt.set(label, glyph, scale?)        the label's glyph changed (or was just made); scale shrinks the picture.
--                                            A glyph in Theme.glyphImages (the golden fish) draws that whole picture,
--                                            and one in Theme.cleanGlyphs its clean symbol (#1027) before the sheet
--   IconArt.setImage(label, image, scale?)   a whole uploaded picture instead of a sheet cell (the shop icons of
--                                            Components/ShopIcons); nil goes back to the glyph
--   IconArt.setTransparency(label, value)    fade or grey the icon, picture or emoji, whichever shows
--
-- Roblox terms: ImageRectOffset and ImageRectSize cut one cell out of a bigger picture; IsLoaded turns true once
-- the picture has downloaded.
--
-- Live fix (11-04, "it is still this old ui"): a picture waits at WAITING, not fully see-through. Roblox does not
-- fetch an image it would not draw, so at ImageTransparency 1 IsLoaded never turned true and every menu showed its
-- emoji (the Decor tile's sofa draws nothing, hence its blank tile). ContentProvider also fetches each new picture.

local ContentProvider = game:GetService("ContentProvider")

local Create = require(script.Parent.Create)
local ShopIcons = require(script.Parent.ShopIcons)
local Theme = require(script.Parent.Parent.Theme)

local IconArt = {}

local ART = "IconArt"
local BASE = "IconTransparency" -- the transparency the caller asked for, whichever of the two shows
local WAITING = 0.99 -- a picture still loading: as good as hidden, but still drawn, so Roblox downloads it
local fetched: { [string]: boolean } = {} -- pictures already asked of ContentProvider

-- The sheet cell for a glyph, or nil when the sheet has no picture of it or is not uploaded.
function IconArt.cell(glyph: string?): Vector2?
	local sheet = Theme.iconSheet
	if glyph == nil or sheet.image == "" then
		return nil
	end
	return sheet.cells[glyph]
end

local function apply(label: TextLabel)
	local art = label:FindFirstChild(ART) :: ImageLabel?
	local value = label:GetAttribute(BASE)
	local transparency = if type(value) == "number" then value else 0
	if art and art.Visible and art.IsLoaded then
		label.TextTransparency = 1
		art.ImageTransparency = transparency
	else
		label.TextTransparency = transparency
		if art then
			art.ImageTransparency = if art.Visible then WAITING else 1
		end
	end
end

-- The label's picture, made the first time; nil hides it, so the glyph shows.
local function artFor(label: TextLabel, image: string?, scale: number?): ImageLabel?
	if label:GetAttribute(BASE) == nil then
		label:SetAttribute(BASE, label.TextTransparency)
	end
	local art = label:FindFirstChild(ART) :: ImageLabel?
	if image == nil or image == "" then
		if art then
			art.Visible = false
		end
		apply(label)
		return nil
	end
	if art == nil then
		local made: ImageLabel = Create("ImageLabel", {
			Name = ART,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ImageTransparency = WAITING,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = label.ZIndex,
			Parent = label,
		})
		made:GetPropertyChangedSignal("IsLoaded"):Connect(function()
			apply(label)
		end)
		art = made
	end
	local picture = art :: ImageLabel
	local size = scale or 1
	picture.Image = image :: string
	picture.Size = UDim2.fromScale(size, size)
	picture.Visible = true
	local id = image :: string
	if not fetched[id] then
		fetched[id] = true
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync({ id })
			end)
			if picture.Parent then
				apply(label)
			end
		end)
	end
	return picture
end

function IconArt.set(label: TextLabel, glyph: string?, scale: number?)
	local whole = if glyph then Theme.glyphImages[glyph] else nil
	local clean = if glyph then Theme.cleanGlyphs[glyph] else nil
	if (whole == nil or whole == "") and clean then
		whole = ShopIcons.clean(clean)
	end
	if whole and whole ~= "" then
		IconArt.setImage(label, whole, scale)
		return
	end
	local cell = IconArt.cell(glyph)
	local picture = artFor(label, if cell then Theme.iconSheet.image else nil, scale)
	if picture and cell then
		picture.ImageRectSize = Vector2.new(Theme.iconSheet.cell, Theme.iconSheet.cell)
		picture.ImageRectOffset = cell * Theme.iconSheet.cell
		apply(label)
	end
end

function IconArt.setImage(label: TextLabel, image: string?, scale: number?)
	local picture = artFor(label, image, scale)
	if picture then
		picture.ImageRectSize = Vector2.zero
		picture.ImageRectOffset = Vector2.zero
		apply(label)
	end
end

function IconArt.setTransparency(label: TextLabel, transparency: number)
	if label:GetAttribute(BASE) == transparency then
		return -- already shown; markers fade every frame, so skip the attribute write (reviewer N215)
	end
	label:SetAttribute(BASE, transparency)
	apply(label)
end

return IconArt
