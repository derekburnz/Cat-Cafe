--!strict
-- #5357 (Derek 2026-11-18: "things in town like the paw print path dont fully render and should always"). With
-- streaming on (#4788) the Town Square's paving (CatCafe_Square_Paving: its slab, the lighter cross and the darker
-- tiles round the walk-up rings) and the paw print paths (WorldBuilder.buildPawPaths) stream out part by part at a
-- distance, so the ground shows with gaps. With the townGround switch on, each of those models (tagged TAG) is
-- Persistent: sent to every device whole and never streamed out. About 420 flat parts of paving and 5 per paw print,
-- none colliding with anything but the slab. Off, they stream as built (Default).
--
-- Roblox terms: a Model's ModelStreamingMode says how streaming treats it. Default streams each part on its own by
-- distance; Persistent sends the whole model to every client when it joins and keeps it there.

local TownGround = {}

TownGround.FLAG = "townGround"
TownGround.TAG = "TownGround"
TownGround.STEP = 5 -- seconds between reads of the switch

function TownGround.mode(on: boolean): Enum.ModelStreamingMode
	return if on then Enum.ModelStreamingMode.Persistent else Enum.ModelStreamingMode.Default
end

-- #5471 (Derek 2026-11-19: "cat paw path in town square still not loading in"): Persistent is set at run time, after
-- the prints have streamed, and an older server never got #5412. With switch `townPawsLocal` on, each client builds
-- the prints itself (Effects/TownPaws) from the list the server writes to ReplicatedStorage's StringValue PAWS_VALUE,
-- as local parts streaming never touches, and fades the server's PawPaths so nothing doubles.
TownGround.LOCAL_FLAG = "townPawsLocal"
TownGround.PAWS_VALUE = "TownPawPrints"
TownGround.PATHS_NAME = "PawPaths"
-- each print: a pad PAD studs across at its middle and four toes TOE across at TOES (x, z off the middle, -Z the
-- front), 0.03 thick, flat on the ground
TownGround.PAD = 0.95
TownGround.TOE = 0.38
TownGround.TOES = { { -0.55, -0.5 }, { -0.2, -0.78 }, { 0.2, -0.78 }, { 0.55, -0.5 } }

export type Print = { x: number, y: number, z: number, rotY: number, r: number, g: number, b: number }

-- Pure: the prints as one string, "x,y,z,rotY,r,g,b" (colour 0 to 255) for each, joined by ";".
function TownGround.encode(prints: { Print }): string
	local out = table.create(#prints)
	for _, p in prints do
		table.insert(
			out,
			string.format("%.3f,%.3f,%.3f,%.1f,%d,%d,%d", p.x, p.y, p.z, p.rotY, p.r, p.g, p.b)
		)
	end
	return table.concat(out, ";")
end

-- Pure: the prints back from TownGround.encode's string; a piece that is not seven numbers is skipped.
function TownGround.decode(text: unknown): { Print }
	local prints: { Print } = {}
	if type(text) ~= "string" then
		return prints
	end
	for piece in string.gmatch(text, "[^;]+") do
		local n: { number } = {}
		for value in string.gmatch(piece, "[^,]+") do
			local number = tonumber(value)
			if number == nil then
				break
			end
			table.insert(n, number)
		end
		if #n == 7 then
			table.insert(
				prints,
				{ x = n[1], y = n[2], z = n[3], rotY = n[4], r = n[5], g = n[6], b = n[7] }
			)
		end
	end
	return prints
end

return TownGround
