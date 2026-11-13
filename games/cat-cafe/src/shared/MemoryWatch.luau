--!strict
-- #3743 (PC client memory read about double after the launch build, from about 6 computers): measures it on every
-- client instead. At MARKS minutes into a session the client reports its total memory, and at TAG_MARKS also the
-- memory under each of TAGS (Roblox's own DeveloperMemoryTag groups), so growth over a session and what grew can
-- be read by device. Analytics only, pure: Controllers/MemoryWatchController sends, Telemetry checks and logs.
-- A report is one number: `encode(index, mb)` packs the mark's (or mark and tag's) index with the megabytes.
--   MARKS, TAG_MARKS, TAGS, MAX_MB, TOTAL, TAG
--   encode(index, mb) -> number            decode(value) -> (index, mb)?
--   tagIndex(markIndex, tagIndex) -> number    tagOf(index) -> (markIndex, tagIndex)?
--   growthBucket(firstMb, mb) -> string

local MemoryWatch = {}

MemoryWatch.MARKS = table.freeze({ 5, 15, 30, 60 }) -- minutes into the session
MemoryWatch.TAG_MARKS = table.freeze({ [1] = true, [3] = true }) -- the MARKS (by index) that also send the tags
MemoryWatch.TAGS = table.freeze({
	"LuaHeap",
	"Instances",
	"Gui",
	"GraphicsTexture",
	"GraphicsMeshParts",
	"Signals",
	"Sounds",
	"Animation",
})
MemoryWatch.MAX_MB = 65535
MemoryWatch.TOTAL = "mem_total" -- TelemetryReport names
MemoryWatch.TAG = "mem_tag"

local SCALE = 100000

function MemoryWatch.encode(index: number, mb: number): number
	return index * SCALE + math.clamp(math.floor(mb), 0, MemoryWatch.MAX_MB)
end

-- The index and megabytes of a report, or nil for anything that is not one.
function MemoryWatch.decode(value: unknown): (number?, number?)
	if type(value) ~= "number" or value ~= value or value < SCALE or value % 1 ~= 0 then
		return nil, nil
	end
	local index = value // SCALE
	local mb = value % SCALE
	if index > 1000 or mb > MemoryWatch.MAX_MB then
		return nil, nil
	end
	return index, mb
end

-- One index for a mark and a tag together (both by their place in MARKS and TAGS).
function MemoryWatch.tagIndex(markIndex: number, tagIndex: number): number
	return markIndex * 100 + tagIndex
end

function MemoryWatch.tagOf(index: number): (number?, number?)
	local mark, tag = index // 100, index % 100
	if MemoryWatch.TAG_MARKS[mark] ~= true or MemoryWatch.TAGS[tag] == nil then
		return nil, nil
	end
	return mark, tag
end

-- How much the total grew since the session's first mark, as an analytics field.
function MemoryWatch.growthBucket(firstMb: number?, mb: number): string
	if firstMb == nil then
		return "first"
	end
	local grew = mb - firstMb
	if grew < 200 then
		return "lt200"
	elseif grew < 500 then
		return "200-500"
	elseif grew < 1000 then
		return "500-1000"
	elseif grew < 2000 then
		return "1000-2000"
	end
	return "2000+"
end

return MemoryWatch
