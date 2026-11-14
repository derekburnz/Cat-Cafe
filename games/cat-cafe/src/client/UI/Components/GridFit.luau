--!strict
-- #4007 (Derek 2026-11-13: "make the ui boxes in things like daycart slightly smaller so its easier to go through maybe
-- 4 per row"): how many picture cards a shop grid shows a row. Four when each still gets `minCell` design pixels, else
-- three, so a narrow window never cuts a card's words. Pure apart from the layout it sets.
--   columns(width, minCell, gap)    4 or 3 for a grid `width` design pixels wide
--   fit(grid, layout, minCell, gap, height)   sets the layout's CellSize now and on every resize

local Scale = require(script.Parent.Parent.Scale)

local GridFit = {}

GridFit.MOST = 4
GridFit.FEWEST = 3

function GridFit.columns(width: number, minCell: number, gap: number): number
	for columns = GridFit.MOST, GridFit.FEWEST + 1, -1 do
		if width >= columns * minCell + (columns - 1) * gap then
			return columns
		end
	end
	return GridFit.FEWEST
end

-- The cell for `columns` across, each `height` tall, sharing the row's gaps.
function GridFit.cell(columns: number, gap: number, height: number): UDim2
	return UDim2.new(1 / columns, -math.ceil(gap * (columns - 1) / columns), 0, height)
end

-- Keeps `layout` at the columns `grid` has room for. `height` is read each time, so a card that grows still fits.
function GridFit.fit(
	grid: GuiObject,
	layout: UIGridLayout,
	minCell: number,
	gap: number,
	height: () -> number
)
	local function apply()
		local scale = Scale.get()
		local width = if scale > 0 then grid.AbsoluteSize.X / scale else 0
		layout.CellSize = GridFit.cell(GridFit.columns(width, minCell, gap), gap, height())
	end
	grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply)
	apply()
end

return GridFit
