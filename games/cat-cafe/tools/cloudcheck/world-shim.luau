--!nocheck
--[[
	A small Roblox with geometry, so worldscan.mjs can run the real WorldBuilder in the cloud and read back every
	part it placed (QA, 2026-11-01: Derek's "lots of models are not connected to each other and are floating or
	have gaps"). Unlike roblox-shim.luau, which wraps a read-only tree for the specs, this one makes real instances:
	Instance.new, properties, parenting, Clone, Destroy, attributes and tags, CFrame and Vector3 maths, Model pivots,
	Attachment world frames and Workspace:Raycast against part boxes. Events are inert, nothing simulates.

	Called by worldscan.mjs with (tree, hostLoad): tree is rojo-tree.mjs's node tree for default.project.json and
	hostLoad(kind, key, env) returns a loaded chunk: kind "module" loads the source file `key` with `env` as its
	environment, kind "asset" loads assets/cat-cafe/rbx/<key>.model.json as a table.
]]

local tree, hostLoad = ...

local Shim = {}

local sqrt, abs, sin, cos, atan2, asin, huge = math.sqrt, math.abs, math.sin, math.cos, math.atan2, math.asin, math.huge

------------------------------------------------------------------------------------------------------------------
-- Vector3

local Vector3 = {}
local V3 = { __type = "Vector3" }

local function v3(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, V3)
end

local v3methods = {}
V3.__index = function(self, key)
	if key == "Magnitude" then
		return sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
	elseif key == "Unit" then
		local m = sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
		if m == 0 then
			return v3(0 / 0, 0 / 0, 0 / 0)
		end
		return v3(self.X / m, self.Y / m, self.Z / m)
	elseif key == "x" then
		return self.X
	elseif key == "y" then
		return self.Y
	elseif key == "z" then
		return self.Z
	end
	return v3methods[key]
end
V3.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	elseif type(a) == "number" then
		return v3(a / b.X, a / b.Y, a / b.Z)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__idiv = function(a, b)
	return v3(a.X // b, a.Y // b, a.Z // b)
end
V3.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3.__tostring = function(a)
	return string.format("%g, %g, %g", a.X, a.Y, a.Z)
end
function v3methods.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function v3methods.Cross(a, b)
	return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function v3methods.Lerp(a, b, t)
	return v3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t)
end
function v3methods.Min(a, ...)
	local x, y, z = a.X, a.Y, a.Z
	for _, b in { ... } do
		x, y, z = math.min(x, b.X), math.min(y, b.Y), math.min(z, b.Z)
	end
	return v3(x, y, z)
end
function v3methods.Max(a, ...)
	local x, y, z = a.X, a.Y, a.Z
	for _, b in { ... } do
		x, y, z = math.max(x, b.X), math.max(y, b.Y), math.max(z, b.Z)
	end
	return v3(x, y, z)
end
function v3methods.Abs(a)
	return v3(abs(a.X), abs(a.Y), abs(a.Z))
end
function v3methods.Floor(a)
	return v3(math.floor(a.X), math.floor(a.Y), math.floor(a.Z))
end
function v3methods.Ceil(a)
	return v3(math.ceil(a.X), math.ceil(a.Y), math.ceil(a.Z))
end
function v3methods.Sign(a)
	return v3(math.sign(a.X), math.sign(a.Y), math.sign(a.Z))
end
function v3methods.FuzzyEq(a, b, eps)
	eps = eps or 1e-5
	return abs(a.X - b.X) <= eps and abs(a.Y - b.Y) <= eps and abs(a.Z - b.Z) <= eps
end
function v3methods.Angle(a, b)
	local d = v3methods.Dot(a, b) / (a.Magnitude * b.Magnitude)
	return math.acos(math.clamp(d, -1, 1))
end

function Vector3.new(x, y, z)
	return v3(x or 0, y or 0, z or 0)
end
function Vector3.fromNormalId(normal)
	local n = normal.Name
	if n == "Top" then
		return v3(0, 1, 0)
	elseif n == "Bottom" then
		return v3(0, -1, 0)
	elseif n == "Front" then
		return v3(0, 0, -1)
	elseif n == "Back" then
		return v3(0, 0, 1)
	elseif n == "Right" then
		return v3(1, 0, 0)
	end
	return v3(-1, 0, 0)
end
function Vector3.fromAxis(axis)
	local n = axis.Name
	return if n == "X" then v3(1, 0, 0) elseif n == "Y" then v3(0, 1, 0) else v3(0, 0, 1)
end
Vector3.zero = v3(0, 0, 0)
Vector3.one = v3(1, 1, 1)
Vector3.xAxis = v3(1, 0, 0)
Vector3.yAxis = v3(0, 1, 0)
Vector3.zAxis = v3(0, 0, 1)

------------------------------------------------------------------------------------------------------------------
-- Vector2

local Vector2 = {}
local V2 = { __type = "Vector2" }
V2.__index = function(self, key)
	if key == "Magnitude" then
		return sqrt(self.X * self.X + self.Y * self.Y)
	elseif key == "Unit" then
		local m = sqrt(self.X * self.X + self.Y * self.Y)
		return setmetatable({ X = self.X / m, Y = self.Y / m }, V2)
	elseif key == "Dot" then
		return function(a, b)
			return a.X * b.X + a.Y * b.Y
		end
	elseif key == "Lerp" then
		return function(a, b, t)
			return setmetatable({ X = a.X + (b.X - a.X) * t, Y = a.Y + (b.Y - a.Y) * t }, V2)
		end
	end
	return nil
end
V2.__add = function(a, b)
	return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y }, V2)
end
V2.__sub = function(a, b)
	return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y }, V2)
end
V2.__mul = function(a, b)
	if type(a) == "number" then
		return setmetatable({ X = a * b.X, Y = a * b.Y }, V2)
	elseif type(b) == "number" then
		return setmetatable({ X = a.X * b, Y = a.Y * b }, V2)
	end
	return setmetatable({ X = a.X * b.X, Y = a.Y * b.Y }, V2)
end
V2.__div = function(a, b)
	if type(b) == "number" then
		return setmetatable({ X = a.X / b, Y = a.Y / b }, V2)
	end
	return setmetatable({ X = a.X / b.X, Y = a.Y / b.Y }, V2)
end
V2.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
function Vector2.new(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, V2)
end
Vector2.zero = Vector2.new(0, 0)
Vector2.one = Vector2.new(1, 1)

------------------------------------------------------------------------------------------------------------------
-- CFrame: position and a rotation matrix by rows (r00 r01 r02 / r10 r11 r12 / r20 r21 r22)

local CFrame = {}
local CF = { __type = "CFrame" }
local cfmethods = {}

local function cf(x, y, z, a, b, c, d, e, f, g, h, i)
	return setmetatable({ x, y, z, a, b, c, d, e, f, g, h, i }, CF)
end

CF.__index = function(self, key)
	if key == "Position" or key == "p" then
		return v3(self[1], self[2], self[3])
	elseif key == "X" or key == "x" then
		return self[1]
	elseif key == "Y" or key == "y" then
		return self[2]
	elseif key == "Z" or key == "z" then
		return self[3]
	elseif key == "LookVector" then
		return v3(-self[6], -self[9], -self[12])
	elseif key == "RightVector" or key == "XVector" then
		return v3(self[4], self[7], self[10])
	elseif key == "UpVector" or key == "YVector" then
		return v3(self[5], self[8], self[11])
	elseif key == "ZVector" then
		return v3(self[6], self[9], self[12])
	elseif key == "Rotation" then
		return cf(0, 0, 0, self[4], self[5], self[6], self[7], self[8], self[9], self[10], self[11], self[12])
	end
	return cfmethods[key]
end

local function mulCF(m, n)
	local a, b, c, d, e, f, g, h, i = m[4], m[5], m[6], m[7], m[8], m[9], m[10], m[11], m[12]
	local A, B, C, D, E, F, G, H, I = n[4], n[5], n[6], n[7], n[8], n[9], n[10], n[11], n[12]
	return cf(
		a * n[1] + b * n[2] + c * n[3] + m[1],
		d * n[1] + e * n[2] + f * n[3] + m[2],
		g * n[1] + h * n[2] + i * n[3] + m[3],
		a * A + b * D + c * G,
		a * B + b * E + c * H,
		a * C + b * F + c * I,
		d * A + e * D + f * G,
		d * B + e * E + f * H,
		d * C + e * F + f * I,
		g * A + h * D + i * G,
		g * B + h * E + i * H,
		g * C + h * F + i * I
	)
end

local function mulPoint(m, v)
	return v3(
		m[4] * v.X + m[5] * v.Y + m[6] * v.Z + m[1],
		m[7] * v.X + m[8] * v.Y + m[9] * v.Z + m[2],
		m[10] * v.X + m[11] * v.Y + m[12] * v.Z + m[3]
	)
end

local function inverse(m)
	local a, b, c, d, e, f, g, h, i = m[4], m[5], m[6], m[7], m[8], m[9], m[10], m[11], m[12]
	local x, y, z = m[1], m[2], m[3]
	return cf(-(a * x + d * y + g * z), -(b * x + e * y + h * z), -(c * x + f * y + i * z), a, d, g, b, e, h, c, f, i)
end

CF.__mul = function(m, n)
	if getmetatable(n) == CF then
		return mulCF(m, n)
	end
	return mulPoint(m, n)
end
CF.__add = function(m, v)
	return cf(m[1] + v.X, m[2] + v.Y, m[3] + v.Z, m[4], m[5], m[6], m[7], m[8], m[9], m[10], m[11], m[12])
end
CF.__sub = function(m, v)
	return cf(m[1] - v.X, m[2] - v.Y, m[3] - v.Z, m[4], m[5], m[6], m[7], m[8], m[9], m[10], m[11], m[12])
end
CF.__eq = function(m, n)
	for k = 1, 12 do
		if m[k] ~= n[k] then
			return false
		end
	end
	return true
end
CF.__tostring = function(m)
	return table.concat({ m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9], m[10], m[11], m[12] }, ", ")
end

local function rotX(t)
	local c, s = cos(t), sin(t)
	return cf(0, 0, 0, 1, 0, 0, 0, c, -s, 0, s, c)
end
local function rotY(t)
	local c, s = cos(t), sin(t)
	return cf(0, 0, 0, c, 0, s, 0, 1, 0, -s, 0, c)
end
local function rotZ(t)
	local c, s = cos(t), sin(t)
	return cf(0, 0, 0, c, -s, 0, s, c, 0, 0, 0, 1)
end

local function fromColumns(pos, rx, ry, rz)
	return cf(pos.X, pos.Y, pos.Z, rx.X, ry.X, rz.X, rx.Y, ry.Y, rz.Y, rx.Z, ry.Z, rz.Z)
end

local function lookAt(at, target, up)
	up = up or v3(0, 1, 0)
	local look = (target - at)
	if look.Magnitude < 1e-9 then
		return cf(at.X, at.Y, at.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	end
	look = look.Unit
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then
		right = look:Cross(v3(0, 0, if look.Y > 0 then 1 else -1))
	end
	right = right.Unit
	local up2 = right:Cross(look).Unit
	return fromColumns(at, right, up2, -look)
end

function CFrame.new(...)
	local n = select("#", ...)
	local a = ...
	if n == 0 then
		return cf(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	elseif n == 1 then
		return cf(a.X, a.Y, a.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	elseif n == 2 then
		local _, b = ...
		return lookAt(a, b)
	elseif n == 3 then
		local x, y, z = ...
		return cf(x, y, z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	elseif n == 7 then
		-- position and quaternion
		local x, y, z, qx, qy, qz, qw = ...
		local m = math.sqrt(qx * qx + qy * qy + qz * qz + qw * qw)
		qx, qy, qz, qw = qx / m, qy / m, qz / m, qw / m
		return cf(
			x,
			y,
			z,
			1 - 2 * (qy * qy + qz * qz),
			2 * (qx * qy - qz * qw),
			2 * (qx * qz + qy * qw),
			2 * (qx * qy + qz * qw),
			1 - 2 * (qx * qx + qz * qz),
			2 * (qy * qz - qx * qw),
			2 * (qx * qz - qy * qw),
			2 * (qy * qz + qx * qw),
			1 - 2 * (qx * qx + qy * qy)
		)
	end
	return cf(...)
end
function CFrame.Angles(rx, ry, rz)
	return mulCF(mulCF(rotX(rx or 0), rotY(ry or 0)), rotZ(rz or 0))
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.fromEulerAnglesYXZ(rx, ry, rz)
	return mulCF(mulCF(rotY(ry or 0), rotX(rx or 0)), rotZ(rz or 0))
end
CFrame.fromOrientation = CFrame.fromEulerAnglesYXZ
function CFrame.fromEulerAngles(rx, ry, rz, order)
	return CFrame.Angles(rx, ry, rz)
end
CFrame.lookAt = lookAt
function CFrame.lookAlong(at, direction, up)
	return lookAt(at, at + direction, up)
end
function CFrame.fromMatrix(pos, vx, vy, vz)
	vz = vz or vx:Cross(vy).Unit
	return fromColumns(pos, vx, vy, vz)
end
function CFrame.fromAxisAngle(axis, angle)
	local u = axis.Unit
	local c, s = cos(angle), sin(angle)
	local t = 1 - c
	local x, y, z = u.X, u.Y, u.Z
	return cf(
		0,
		0,
		0,
		t * x * x + c,
		t * x * y - s * z,
		t * x * z + s * y,
		t * x * y + s * z,
		t * y * y + c,
		t * y * z - s * x,
		t * x * z - s * y,
		t * y * z + s * x,
		t * z * z + c
	)
end
CFrame.identity = cf(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)

function cfmethods.Inverse(m)
	return inverse(m)
end
function cfmethods.GetComponents(m)
	return m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9], m[10], m[11], m[12]
end
cfmethods.components = cfmethods.GetComponents
function cfmethods.ToWorldSpace(m, ...)
	local out = {}
	for k, n in { ... } do
		out[k] = mulCF(m, n)
	end
	return table.unpack(out)
end
function cfmethods.ToObjectSpace(m, ...)
	local inv = inverse(m)
	local out = {}
	for k, n in { ... } do
		out[k] = mulCF(inv, n)
	end
	return table.unpack(out)
end
function cfmethods.PointToWorldSpace(m, ...)
	local out = {}
	for k, v in { ... } do
		out[k] = mulPoint(m, v)
	end
	return table.unpack(out)
end
function cfmethods.PointToObjectSpace(m, ...)
	local inv = inverse(m)
	local out = {}
	for k, v in { ... } do
		out[k] = mulPoint(inv, v)
	end
	return table.unpack(out)
end
function cfmethods.VectorToWorldSpace(m, ...)
	local out = {}
	for k, v in { ... } do
		out[k] = v3(
			m[4] * v.X + m[5] * v.Y + m[6] * v.Z,
			m[7] * v.X + m[8] * v.Y + m[9] * v.Z,
			m[10] * v.X + m[11] * v.Y + m[12] * v.Z
		)
	end
	return table.unpack(out)
end
function cfmethods.VectorToObjectSpace(m, ...)
	local out = {}
	for k, v in { ... } do
		out[k] = v3(
			m[4] * v.X + m[7] * v.Y + m[10] * v.Z,
			m[5] * v.X + m[8] * v.Y + m[11] * v.Z,
			m[6] * v.X + m[9] * v.Y + m[12] * v.Z
		)
	end
	return table.unpack(out)
end
function cfmethods.ToEulerAnglesXYZ(m)
	local ry = asin(math.clamp(m[6], -1, 1))
	local rx = atan2(-m[9], m[12])
	local rz = atan2(-m[5], m[4])
	return rx, ry, rz
end
function cfmethods.ToEulerAnglesYXZ(m)
	local rx = asin(math.clamp(-m[9], -1, 1))
	local ry = atan2(m[6], m[12])
	local rz = atan2(m[7], m[8])
	return rx, ry, rz
end
cfmethods.ToOrientation = cfmethods.ToEulerAnglesYXZ
function cfmethods.Orthonormalize(m)
	return m
end
function cfmethods.FuzzyEq(m, n, eps)
	eps = eps or 1e-5
	for k = 1, 12 do
		if abs(m[k] - n[k]) > eps then
			return false
		end
	end
	return true
end

local function toQuat(m)
	local a, b, c, d, e, f, g, h, i = m[4], m[5], m[6], m[7], m[8], m[9], m[10], m[11], m[12]
	local trace = a + e + i
	local qw, qx, qy, qz
	if trace > 0 then
		local s = sqrt(trace + 1) * 2
		qw, qx, qy, qz = 0.25 * s, (h - f) / s, (c - g) / s, (d - b) / s
	elseif a > e and a > i then
		local s = sqrt(1 + a - e - i) * 2
		qw, qx, qy, qz = (h - f) / s, 0.25 * s, (b + d) / s, (c + g) / s
	elseif e > i then
		local s = sqrt(1 + e - a - i) * 2
		qw, qx, qy, qz = (c - g) / s, (b + d) / s, 0.25 * s, (f + h) / s
	else
		local s = sqrt(1 + i - a - e) * 2
		qw, qx, qy, qz = (d - b) / s, (c + g) / s, (f + h) / s, 0.25 * s
	end
	return qx, qy, qz, qw
end

function cfmethods.ToAxisAngle(m)
	local qx, qy, qz, qw = toQuat(m)
	local angle = 2 * math.acos(math.clamp(qw, -1, 1))
	local s = sqrt(1 - qw * qw)
	if s < 1e-9 then
		return v3(1, 0, 0), 0
	end
	return v3(qx / s, qy / s, qz / s), angle
end

function cfmethods.Lerp(m, n, t)
	local ax, ay, az, aw = toQuat(m)
	local bx, by, bz, bw = toQuat(n)
	local dot = ax * bx + ay * by + az * bz + aw * bw
	if dot < 0 then
		bx, by, bz, bw, dot = -bx, -by, -bz, -bw, -dot
	end
	local wa, wb
	if dot > 0.9995 then
		wa, wb = 1 - t, t
	else
		local theta = math.acos(dot)
		local s = sin(theta)
		wa, wb = sin((1 - t) * theta) / s, sin(t * theta) / s
	end
	local p = v3(m[1], m[2], m[3]):Lerp(v3(n[1], n[2], n[3]), t)
	return CFrame.new(p.X, p.Y, p.Z, wa * ax + wb * bx, wa * ay + wb * by, wa * az + wb * bz, wa * aw + wb * bw)
end

------------------------------------------------------------------------------------------------------------------
-- Color3 and small value types

local Color3 = {}
local C3 = { __type = "Color3" }
local c3methods = {}
C3.__index = function(self, key)
	if key == "r" then
		return self.R
	elseif key == "g" then
		return self.G
	elseif key == "b" then
		return self.B
	end
	return c3methods[key]
end
C3.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end
local function c3(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3)
end
Color3.new = c3
function Color3.fromRGB(r, g, b)
	return c3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end
function Color3.fromHex(hex)
	hex = hex:gsub("#", "")
	return Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
end
function Color3.fromHSV(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i = i % 6
	if i == 0 then
		return c3(v, t, p)
	elseif i == 1 then
		return c3(q, v, p)
	elseif i == 2 then
		return c3(p, v, t)
	elseif i == 3 then
		return c3(p, q, v)
	elseif i == 4 then
		return c3(t, p, v)
	end
	return c3(v, p, q)
end
function Color3.toHSV(c)
	local r, g, b = c.R, c.G, c.B
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	local d = mx - mn
	local h = 0
	if d > 0 then
		if mx == r then
			h = ((g - b) / d) % 6
		elseif mx == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h /= 6
	end
	return h, if mx == 0 then 0 else d / mx, mx
end
function c3methods.Lerp(a, b, t)
	return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
function c3methods.ToHex(a)
	return string.format(
		"%02X%02X%02X",
		math.floor(a.R * 255 + 0.5),
		math.floor(a.G * 255 + 0.5),
		math.floor(a.B * 255 + 0.5)
	)
end
function c3methods.ToHSV(a)
	return Color3.toHSV(a)
end

local function valueType(typeName, fields)
	return setmetatable(fields, { __type = typeName })
end

local UDim = {
	new = function(scale, offset)
		return valueType("UDim", { Scale = scale or 0, Offset = offset or 0 })
	end,
}
local UDim2 = {}
function UDim2.new(xs, xo, ys, yo)
	return valueType("UDim2", { X = UDim.new(xs, xo), Y = UDim.new(ys, yo), Width = UDim.new(xs, xo), Height = UDim.new(ys, yo) })
end
function UDim2.fromScale(x, y)
	return UDim2.new(x, 0, y, 0)
end
function UDim2.fromOffset(x, y)
	return UDim2.new(0, x, 0, y)
end

local function genericType(typeName)
	return {
		new = function(...)
			return valueType(typeName, { ... })
		end,
	}
end

local NumberRange = {
	new = function(min, max)
		return valueType("NumberRange", { Min = min, Max = max or min })
	end,
}
local NumberSequenceKeypoint = genericType("NumberSequenceKeypoint")
local ColorSequenceKeypoint = genericType("ColorSequenceKeypoint")
local NumberSequence = genericType("NumberSequence")
local ColorSequence = genericType("ColorSequence")
local TweenInfo = genericType("TweenInfo")
local PhysicalProperties = genericType("PhysicalProperties")
local Rect = genericType("Rect")
local Ray = {
	new = function(origin, direction)
		return valueType("Ray", { Origin = origin, Direction = direction })
	end,
}
local Font = {
	new = function(family, weight, style)
		return valueType("Font", { Family = family, Weight = weight, Style = style })
	end,
	fromEnum = function(e)
		return valueType("Font", { Family = tostring(e) })
	end,
	fromName = function(name)
		return valueType("Font", { Family = name })
	end,
}
local BrickColor = {
	new = function(name)
		return valueType("BrickColor", { Name = tostring(name), Color = c3(0.6, 0.6, 0.6) })
	end,
}
BrickColor.random = BrickColor.new
BrickColor.White = function()
	return BrickColor.new("White")
end

------------------------------------------------------------------------------------------------------------------
-- Enum: any item, made on first use

local Enum = {}
local enumTypes = {}
local function enumType(typeName)
	local existing = enumTypes[typeName]
	if existing then
		return existing
	end
	local items = {}
	local t = setmetatable({}, {
		__index = function(_, itemName)
			if itemName == "GetEnumItems" then
				return function()
					local list = {}
					for _, item in items do
						table.insert(list, item)
					end
					return list
				end
			end
			local item = items[itemName]
			if item == nil then
				local count = 0
				for _ in items do
					count += 1
				end
				item = setmetatable({ Name = itemName, Value = count, EnumType = typeName }, {
					__type = "EnumItem",
					__tostring = function()
						return "Enum." .. typeName .. "." .. itemName
					end,
				})
				items[itemName] = item
			end
			return item
		end,
		__tostring = function()
			return typeName
		end,
	})
	enumTypes[typeName] = t
	return t
end
setmetatable(Enum, {
	__index = function(_, typeName)
		return enumType(typeName)
	end,
})

------------------------------------------------------------------------------------------------------------------
-- Signals: inert

local function signal()
	local s = {}
	function s:Connect()
		return { Disconnect = function() end, Connected = true }
	end
	s.Once = s.Connect
	s.ConnectParallel = s.Connect
	function s:Wait()
		return nil
	end
	return s
end

local EVENTS = {}
for _, name in
	{
		"Touched",
		"TouchEnded",
		"ChildAdded",
		"ChildRemoved",
		"DescendantAdded",
		"DescendantRemoving",
		"Changed",
		"AncestryChanged",
		"Destroying",
		"Triggered",
		"TriggerEnded",
		"PromptShown",
		"PromptHidden",
		"PromptButtonHoldBegan",
		"PromptButtonHoldEnded",
		"MouseButton1Click",
		"MouseButton1Down",
		"MouseEnter",
		"MouseLeave",
		"Activated",
		"AttributeChanged",
		"Heartbeat",
		"Stepped",
		"RenderStepped",
		"PreSimulation",
		"PostSimulation",
		"PlayerAdded",
		"PlayerRemoving",
		"CharacterAdded",
		"CharacterRemoving",
		"Died",
		"Event",
		"OnServerEvent",
		"OnClientEvent",
		"Completed",
		"Ended",
		"Played",
		"InputBegan",
		"InputEnded",
	}
do
	EVENTS[name] = true
end

------------------------------------------------------------------------------------------------------------------
-- Instances

local SUPER = {
	Part = "FormFactorPart",
	WedgePart = "FormFactorPart",
	CornerWedgePart = "BasePart",
	FormFactorPart = "BasePart",
	TrussPart = "BasePart",
	MeshPart = "BasePart",
	PartOperation = "BasePart",
	UnionOperation = "PartOperation",
	SpawnLocation = "Part",
	Seat = "Part",
	VehicleSeat = "BasePart",
	BasePart = "PVInstance",
	Model = "PVInstance",
	WorldModel = "Model",
	Workspace = "WorldRoot",
	WorldRoot = "Model",
	PVInstance = "Instance",
	Folder = "Instance",
	Attachment = "Instance",
	Bone = "Attachment",
	SpecialMesh = "FileMesh",
	FileMesh = "DataModelMesh",
	DataModelMesh = "Instance",
	SurfaceGui = "SurfaceGuiBase",
	SurfaceGuiBase = "LayerCollector",
	BillboardGui = "LayerCollector",
	ScreenGui = "LayerCollector",
	LayerCollector = "GuiBase2d",
	GuiBase2d = "GuiBase",
	GuiBase = "Instance",
	TextLabel = "GuiObject",
	TextButton = "GuiButton",
	ImageButton = "GuiButton",
	GuiButton = "GuiObject",
	ImageLabel = "GuiObject",
	Frame = "GuiObject",
	TextBox = "GuiObject",
	GuiObject = "GuiBase2d",
	PointLight = "Light",
	SpotLight = "Light",
	SurfaceLight = "Light",
	Light = "Instance",
	ProximityPrompt = "Instance",
	ParticleEmitter = "Instance",
	Decal = "FaceInstance",
	Texture = "Decal",
	FaceInstance = "Instance",
	Script = "BaseScript",
	LocalScript = "Script",
	BaseScript = "LuaSourceContainer",
	ModuleScript = "LuaSourceContainer",
	LuaSourceContainer = "Instance",
	StringValue = "ValueBase",
	ObjectValue = "ValueBase",
	NumberValue = "ValueBase",
	BoolValue = "ValueBase",
	IntValue = "ValueBase",
	ValueBase = "Instance",
	Sky = "Instance",
	Sound = "Instance",
	Beam = "Instance",
	Trail = "Instance",
	Highlight = "Instance",
	WeldConstraint = "Instance",
	Weld = "JointInstance",
	Motor6D = "JointInstance",
	JointInstance = "Instance",
	UICorner = "UIComponent",
	UIStroke = "UIComponent",
	UIComponent = "Instance",
	RemoteEvent = "Instance",
	RemoteFunction = "Instance",
	BindableEvent = "Instance",
	BindableFunction = "Instance",
}

local function isA(className, target)
	local current = className
	while current do
		if current == target then
			return true
		end
		if current == "Instance" then
			return target == "Instance"
		end
		current = SUPER[current] or "Instance"
	end
	return false
end

local DEFAULT_SIZE = {
	Part = v3(4, 1, 2),
	WedgePart = v3(4, 1, 2),
	CornerWedgePart = v3(2, 2, 2),
	TrussPart = v3(2, 2, 2),
	SpawnLocation = v3(12, 1, 12),
	Seat = v3(4, 1, 2),
	MeshPart = v3(1, 1, 1),
}

-- Property defaults read before anything set them (class-agnostic; enough for the world code).
local DEFAULTS = {
	Transparency = 0,
	Reflectance = 0,
	Anchored = false,
	CanCollide = true,
	CanQuery = true,
	CanTouch = true,
	CastShadow = true,
	Locked = false,
	Massless = false,
	Enabled = true,
	Visible = true,
	Archivable = true,
	LightInfluence = 1,
	Brightness = 1,
	Range = 8,
	MaxActivationDistance = 10,
	HoldDuration = 0,
	RequiresLineOfSight = true,
	Text = "",
	TextScaled = false,
	TextSize = 14,
	BackgroundTransparency = 0,
	TextTransparency = 0,
	ZIndex = 1,
	LayoutOrder = 0,
	PixelsPerStud = 50,
	Duration = 10,
	Value = nil,
}

local state = setmetatable({}, { __mode = "k" })
local Instance = {}
local InstanceMT = { __type = "Instance" }
local methods = {}
local registry = {} -- every instance ever made, in creation order (for tags)
local tagged = {} -- tag -> { [instance]: true }

local function newInstance(className)
	local self = setmetatable({}, InstanceMT)
	local s = {
		ClassName = className,
		Name = className,
		Parent = nil,
		children = {},
		props = {},
		attrs = {},
		tags = {},
		destroyed = false,
	}
	state[self] = s
	if isA(className, "BasePart") then
		s.props.CFrame = CFrame.identity
		s.props.Size = DEFAULT_SIZE[className] or v3(4, 1, 2)
		s.props.PivotOffset = CFrame.identity
		s.props.Color = c3(0.639, 0.635, 0.647)
		s.props.Material = Enum.Material.Plastic
		s.props.Shape = Enum.PartType.Block
	elseif className == "Attachment" or className == "Bone" then
		s.props.CFrame = CFrame.identity
	end
	table.insert(registry, self)
	return self
end

local function removeChild(parent, child)
	local list = state[parent].children
	for i = #list, 1, -1 do
		if list[i] == child then
			table.remove(list, i)
			return
		end
	end
end

local function setParent(self, parent)
	local s = state[self]
	if s.Parent == parent then
		return
	end
	if parent ~= nil then
		-- no cycles
		local at = parent
		while at ~= nil do
			if at == self then
				error("Attempt to set parent of " .. s.Name .. " to a descendant of itself", 3)
			end
			at = state[at].Parent
		end
	end
	if s.Parent ~= nil then
		removeChild(s.Parent, self)
	end
	s.Parent = parent
	if parent ~= nil then
		table.insert(state[parent].children, self)
	end
end

local function findChild(self, name)
	for _, child in state[self].children do
		if state[child].Name == name then
			return child
		end
	end
	return nil
end

-- the frame of the BasePart an Attachment rides, or identity
local function attachmentParentFrame(self)
	local parent = state[self].Parent
	if parent ~= nil and isA(state[parent].ClassName, "BasePart") then
		return state[parent].props.CFrame
	end
	return CFrame.identity
end

local function descendants(self, out)
	out = out or {}
	for _, child in state[self].children do
		table.insert(out, child)
		descendants(child, out)
	end
	return out
end

local function boundingBox(self)
	-- the parts' corners in the model pivot's orientation (as Roblox's GetBoundingBox does)
	local s = state[self]
	local pivot = methods.GetPivot(self)
	local rot = pivot.Rotation
	local inv = inverse(rot)
	local minX, minY, minZ, maxX, maxY, maxZ = huge, huge, huge, -huge, -huge, -huge
	for _, d in descendants(self) do
		local ds = state[d]
		if isA(ds.ClassName, "BasePart") then
			local frame = ds.props.CFrame
			local size = ds.props.Size
			for _, sx in { -0.5, 0.5 } do
				for _, sy in { -0.5, 0.5 } do
					for _, sz in { -0.5, 0.5 } do
						local p = mulPoint(inv, mulPoint(frame, v3(size.X * sx, size.Y * sy, size.Z * sz)))
						minX, minY, minZ = math.min(minX, p.X), math.min(minY, p.Y), math.min(minZ, p.Z)
						maxX, maxY, maxZ = math.max(maxX, p.X), math.max(maxY, p.Y), math.max(maxZ, p.Z)
					end
				end
			end
		end
	end
	if minX == huge then
		return pivot, v3(0, 0, 0)
	end
	local centre = mulPoint(rot, v3((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2))
	local _ = s
	return rot + centre, v3(maxX - minX, maxY - minY, maxZ - minZ)
end

InstanceMT.__index = function(self, key)
	local s = state[self]
	if key == "Name" or key == "ClassName" or key == "Parent" then
		return s[key]
	end
	local method = methods[key]
	if method ~= nil then
		return method
	end
	local props = s.props
	if key == "Position" then
		if props.CFrame then
			return props.CFrame.Position
		end
		return props.Position
	elseif key == "Orientation" and props.CFrame then
		local rx, ry, rz = cfmethods.ToEulerAnglesYXZ(props.CFrame)
		return v3(math.deg(rx), math.deg(ry), math.deg(rz))
	elseif key == "Rotation" and props.CFrame and isA(s.ClassName, "BasePart") then
		local rx, ry, rz = cfmethods.ToEulerAnglesXYZ(props.CFrame)
		return v3(math.deg(rx), math.deg(ry), math.deg(rz))
	elseif key == "WorldCFrame" then
		return mulCF(attachmentParentFrame(self), props.CFrame)
	elseif key == "WorldPosition" then
		return mulCF(attachmentParentFrame(self), props.CFrame).Position
	elseif key == "WorldPivot" and s.ClassName == "Model" then
		return methods.GetPivot(self)
	elseif key == "AssemblyLinearVelocity" or key == "AssemblyAngularVelocity" or key == "Velocity" then
		return v3(0, 0, 0)
	end
	local value = props[key]
	if value ~= nil then
		return value
	end
	if EVENTS[key] then
		return signal()
	end
	local child = findChild(self, key)
	if child ~= nil then
		return child
	end
	return DEFAULTS[key]
end

InstanceMT.__newindex = function(self, key, value)
	local s = state[self]
	if key == "Parent" then
		setParent(self, value)
		return
	elseif key == "Name" then
		s.Name = tostring(value)
		return
	elseif key == "ClassName" then
		error("ClassName is read-only", 2)
	end
	local props = s.props
	if key == "Position" then
		if props.CFrame then
			local m = props.CFrame
			props.CFrame = cf(value.X, value.Y, value.Z, m[4], m[5], m[6], m[7], m[8], m[9], m[10], m[11], m[12])
		else
			props.Position = value
		end
		return
	elseif key == "Orientation" and props.CFrame then
		local p = props.CFrame
		props.CFrame = cf(p[1], p[2], p[3], 1, 0, 0, 0, 1, 0, 0, 0, 1)
			* CFrame.fromOrientation(math.rad(value.X), math.rad(value.Y), math.rad(value.Z))
		return
	elseif key == "Rotation" and props.CFrame and isA(s.ClassName, "BasePart") then
		local p = props.CFrame
		props.CFrame = cf(p[1], p[2], p[3], 1, 0, 0, 0, 1, 0, 0, 0, 1)
			* CFrame.Angles(math.rad(value.X), math.rad(value.Y), math.rad(value.Z))
		return
	elseif key == "WorldCFrame" then
		props.CFrame = mulCF(inverse(attachmentParentFrame(self)), value)
		return
	elseif key == "WorldPosition" then
		local parentFrame = attachmentParentFrame(self)
		local localPos = mulPoint(inverse(parentFrame), value)
		local m = props.CFrame
		props.CFrame = cf(localPos.X, localPos.Y, localPos.Z, m[4], m[5], m[6], m[7], m[8], m[9], m[10], m[11], m[12])
		return
	elseif key == "WorldPivot" then
		s.worldPivot = value
		return
	end
	props[key] = value
end

InstanceMT.__tostring = function(self)
	return state[self].Name
end

function methods.IsA(self, className)
	return isA(state[self].ClassName, className)
end
function methods.GetChildren(self)
	return table.clone(state[self].children)
end
methods.getChildren = methods.GetChildren
function methods.GetDescendants(self)
	return descendants(self)
end
function methods.FindFirstChild(self, name, recursive)
	if recursive then
		for _, d in descendants(self) do
			if state[d].Name == name then
				return d
			end
		end
		return nil
	end
	return findChild(self, name)
end
function methods.WaitForChild(self, name)
	local child = findChild(self, name)
	if child == nil then
		error(string.format("Infinite yield: %s has no child %s (cloud world shim)", methods.GetFullName(self), name), 2)
	end
	return child
end
function methods.FindFirstChildWhichIsA(self, className, recursive)
	local list = if recursive then descendants(self) else state[self].children
	for _, d in list do
		if isA(state[d].ClassName, className) then
			return d
		end
	end
	return nil
end
function methods.FindFirstChildOfClass(self, className)
	for _, d in state[self].children do
		if state[d].ClassName == className then
			return d
		end
	end
	return nil
end
function methods.FindFirstAncestor(self, name)
	local at = state[self].Parent
	while at ~= nil do
		if state[at].Name == name then
			return at
		end
		at = state[at].Parent
	end
	return nil
end
function methods.FindFirstAncestorWhichIsA(self, className)
	local at = state[self].Parent
	while at ~= nil do
		if isA(state[at].ClassName, className) then
			return at
		end
		at = state[at].Parent
	end
	return nil
end
methods.FindFirstAncestorOfClass = methods.FindFirstAncestorWhichIsA
function methods.IsDescendantOf(self, other)
	local at = state[self].Parent
	while at ~= nil do
		if at == other then
			return true
		end
		at = state[at].Parent
	end
	return false
end
function methods.IsAncestorOf(self, other)
	return methods.IsDescendantOf(other, self)
end
function methods.GetFullName(self)
	local parts = {}
	local at = self
	while at ~= nil and state[at].ClassName ~= "DataModel" do
		table.insert(parts, 1, state[at].Name)
		at = state[at].Parent
	end
	return table.concat(parts, ".")
end
function methods.Destroy(self)
	local s = state[self]
	for _, child in table.clone(s.children) do
		methods.Destroy(child)
	end
	setParent(self, nil)
	s.destroyed = true
end
function methods.ClearAllChildren(self)
	for _, child in table.clone(state[self].children) do
		methods.Destroy(child)
	end
end
function methods.Remove(self)
	setParent(self, nil)
end
function methods.SetAttribute(self, name, value)
	state[self].attrs[name] = value
end
function methods.GetAttribute(self, name)
	return state[self].attrs[name]
end
function methods.GetAttributes(self)
	return table.clone(state[self].attrs)
end
function methods.GetAttributeChangedSignal()
	return signal()
end
function methods.GetPropertyChangedSignal()
	return signal()
end
function methods.AddTag(self, tag)
	state[self].tags[tag] = true
	tagged[tag] = tagged[tag] or setmetatable({}, { __mode = "k" })
	tagged[tag][self] = true
end
function methods.RemoveTag(self, tag)
	state[self].tags[tag] = nil
	if tagged[tag] then
		tagged[tag][self] = nil
	end
end
function methods.HasTag(self, tag)
	return state[self].tags[tag] == true
end
function methods.GetTags(self)
	local out = {}
	for tag in state[self].tags do
		table.insert(out, tag)
	end
	return out
end
function methods.GetPivot(self)
	local s = state[self]
	if isA(s.ClassName, "BasePart") then
		return mulCF(s.props.CFrame, s.props.PivotOffset or CFrame.identity)
	end
	local primary = s.props.PrimaryPart
	if primary ~= nil and state[primary] and methods.IsDescendantOf(primary, self) then
		local ps = state[primary]
		return mulCF(ps.props.CFrame, ps.props.PivotOffset or CFrame.identity)
	end
	if s.worldPivot ~= nil then
		return s.worldPivot
	end
	-- never set: the centre of the parts' box, kept from now on (Roblox fixes it when parts first arrive)
	local hasPart = false
	for _, d in descendants(self) do
		if isA(state[d].ClassName, "BasePart") then
			hasPart = true
			break
		end
	end
	if not hasPart then
		return CFrame.identity
	end
	s.worldPivot = CFrame.identity
	local box = boundingBox(self)
	s.worldPivot = box.Rotation + box.Position
	return s.worldPivot
end
function methods.PivotTo(self, target)
	local s = state[self]
	if isA(s.ClassName, "BasePart") then
		s.props.CFrame = mulCF(target, inverse(s.props.PivotOffset or CFrame.identity))
		return
	end
	local current = methods.GetPivot(self)
	local delta = mulCF(target, inverse(current))
	for _, d in descendants(self) do
		local ds = state[d]
		if isA(ds.ClassName, "BasePart") then
			ds.props.CFrame = mulCF(delta, ds.props.CFrame)
		end
	end
	if s.worldPivot ~= nil then
		s.worldPivot = mulCF(delta, s.worldPivot)
	end
end
function methods.SetPrimaryPartCFrame(self, target)
	local primary = state[self].props.PrimaryPart
	local current = state[primary].props.CFrame
	local delta = mulCF(target, inverse(current))
	for _, d in descendants(self) do
		local ds = state[d]
		if isA(ds.ClassName, "BasePart") then
			ds.props.CFrame = mulCF(delta, ds.props.CFrame)
		end
	end
end
function methods.GetPrimaryPartCFrame(self)
	return state[state[self].props.PrimaryPart].props.CFrame
end
function methods.GetBoundingBox(self)
	return boundingBox(self)
end
function methods.GetExtentsSize(self)
	local _, size = boundingBox(self)
	return size
end
function methods.TranslateBy(self, delta)
	methods.PivotTo(self, methods.GetPivot(self) + delta)
end
function methods.GetScale()
	return 1
end
function methods.ScaleTo(self, factor)
	if factor == 1 then
		return
	end
	local pivot = methods.GetPivot(self)
	for _, d in descendants(self) do
		local ds = state[d]
		if isA(ds.ClassName, "BasePart") then
			local rel = mulCF(inverse(pivot), ds.props.CFrame)
			local m = rel
			rel = cf(m[1] * factor, m[2] * factor, m[3] * factor, m[4], m[5], m[6], m[7], m[8], m[9], m[10], m[11], m[12])
			ds.props.CFrame = mulCF(pivot, rel)
			ds.props.Size = ds.props.Size * factor
		end
	end
end
function methods.Clone(self)
	local map = {}
	local function copy(src)
		local s = state[src]
		local dst = newInstance(s.ClassName)
		local d = state[dst]
		d.Name = s.Name
		for k, v in s.props do
			d.props[k] = v
		end
		for k, v in s.attrs do
			d.attrs[k] = v
		end
		for tag in s.tags do
			methods.AddTag(dst, tag)
		end
		d.worldPivot = s.worldPivot
		d.source = s.source
		d.assetName = s.assetName
		map[src] = dst
		for _, child in s.children do
			local c = copy(child)
			state[c].Parent = dst
			table.insert(d.children, c)
		end
		return dst
	end
	local root = copy(self)
	-- instance references inside the copy point into the copy
	for src, dst in map do
		local props = state[dst].props
		for k, v in props do
			if type(v) == "table" and getmetatable(v) == InstanceMT and map[v] then
				props[k] = map[v]
			end
		end
		local _ = src
	end
	return root
end
function methods.GetService(self, name)
	return Shim.service(name)
end
methods.FindService = methods.GetService
function methods.GetPlayers()
	return {}
end
function methods.IsServer()
	return true
end
function methods.IsClient()
	return false
end
function methods.IsStudio()
	return true
end
function methods.IsRunning()
	return true
end
function methods.GetServerTimeNow()
	return os.clock()
end
function methods.Play() end
function methods.Stop() end
function methods.Pause() end
function methods.Cancel() end
function methods.Fire() end
function methods.FireServer() end
function methods.FireClient() end
function methods.FireAllClients() end
function methods.Invoke() end
function methods.Create(self, instance, info, goals)
	-- TweenService:Create: a tween that does nothing
	return newInstance("Tween")
end
function methods.AddItem() end
function methods.GenerateGUID()
	return string.format("%08x-guid", math.random(0, 0x7fffffff))
end
function methods.JSONEncode(_, value)
	return tostring(value)
end
function methods.GetTagged(self, tag)
	local out = {}
	for instance in tagged[tag] or {} do
		if not state[instance].destroyed then
			table.insert(out, instance)
		end
	end
	return out
end
function methods.GetInstanceAddedSignal()
	return signal()
end
methods.GetInstanceRemovedSignal = methods.GetInstanceAddedSignal

-- Workspace:Raycast against part boxes (cylinders and balls count as their box). Enough for laying prints on the sets.
local function rayBox(origin, direction, frame, size)
	local inv = inverse(frame)
	local o = mulPoint(inv, origin)
	local d = v3(
		frame[4] * direction.X + frame[7] * direction.Y + frame[10] * direction.Z,
		frame[5] * direction.X + frame[8] * direction.Y + frame[11] * direction.Z,
		frame[6] * direction.X + frame[9] * direction.Y + frame[12] * direction.Z
	)
	local tmin, tmax = 0, 1
	local hitAxis, hitSign = nil, 0
	for _, axis in { "X", "Y", "Z" } do
		local half = size[axis] / 2
		local oa, da = o[axis], d[axis]
		if abs(da) < 1e-12 then
			if oa < -half or oa > half then
				return nil
			end
		else
			local t1, t2 = (-half - oa) / da, (half - oa) / da
			local sign = -1
			if t1 > t2 then
				t1, t2 = t2, t1
				sign = 1
			end
			if t1 > tmin then
				tmin = t1
				hitAxis, hitSign = axis, sign
			end
			tmax = math.min(tmax, t2)
			if tmin > tmax then
				return nil
			end
		end
	end
	local normalLocal = v3(0, 0, 0)
	if hitAxis then
		normalLocal = v3(
			if hitAxis == "X" then hitSign else 0,
			if hitAxis == "Y" then hitSign else 0,
			if hitAxis == "Z" then hitSign else 0
		)
	end
	return tmin, cfmethods.VectorToWorldSpace(frame, normalLocal)
end

function methods.Raycast(self, origin, direction, params)
	local candidates
	local include = params and params.FilterType and params.FilterType.Name == "Include"
	local list = params and params.FilterDescendantsInstances or {}
	if include then
		candidates = {}
		for _, root in list do
			if isA(state[root].ClassName, "BasePart") then
				table.insert(candidates, root)
			end
			for _, d in descendants(root) do
				table.insert(candidates, d)
			end
		end
	else
		candidates = descendants(self)
	end
	local excluded = {}
	if not include then
		for _, root in list do
			excluded[root] = true
			for _, d in descendants(root) do
				excluded[d] = true
			end
		end
	end
	local best, bestT, bestNormal = nil, huge, nil
	for _, part in candidates do
		local ps = state[part]
		if isA(ps.ClassName, "BasePart") and not excluded[part] and ps.props.CanQuery ~= false then
			if not (params and params.RespectCanCollide and ps.props.CanCollide == false) then
				local t, normal = rayBox(origin, direction, ps.props.CFrame, ps.props.Size)
				if t ~= nil and t < bestT then
					best, bestT, bestNormal = part, t, normal
				end
			end
		end
	end
	if best == nil then
		return nil
	end
	return {
		Instance = best,
		Position = origin + direction * bestT,
		Normal = bestNormal,
		Distance = direction.Magnitude * bestT,
		Material = state[best].props.Material,
	}
end

function Instance.new(className, parent)
	local inst = newInstance(className)
	if parent ~= nil then
		setParent(inst, parent)
	end
	return inst
end
function Instance.fromExisting(inst)
	return methods.Clone(inst)
end

-- Random: xorshift, seeded, so two scans of the same build place the same things
local Random = {}
Random.__index = Random
function Random.new(seed)
	local s = math.floor((seed or 12345) % 4294967296)
	if s == 0 then
		s = 2463534242
	end
	return setmetatable({ _state = s }, Random)
end
function Random:_next()
	local x = self._state
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self._state = x
	return x / 4294967296
end
function Random:NextNumber(min, max)
	local r = self:_next()
	if min == nil then
		return r
	end
	return min + r * ((max or 1) - min)
end
function Random:NextInteger(min, max)
	return min + math.floor(self:_next() * (max - min + 1))
end
function Random:Shuffle(t)
	for i = #t, 2, -1 do
		local j = self:NextInteger(1, i)
		t[i], t[j] = t[j], t[i]
	end
end
function Random:Clone()
	return setmetatable({ _state = self._state }, Random)
end

local RaycastParams = {
	new = function()
		return { FilterType = Enum.RaycastFilterType.Exclude, FilterDescendantsInstances = {}, IgnoreWater = false }
	end,
}
local OverlapParams = RaycastParams

------------------------------------------------------------------------------------------------------------------
-- typeof

local nativeTypeof = typeof
local function shimTypeof(value)
	local mt = getmetatable(value)
	if type(mt) == "table" and rawget(mt, "__type") then
		return rawget(mt, "__type")
	end
	return nativeTypeof(value)
end

------------------------------------------------------------------------------------------------------------------
-- The DataModel

local game = newInstance("DataModel")
state[game].Name = "game"
local services = {}

function Shim.service(name)
	local existing = services[name]
	if existing then
		return existing
	end
	local found = findChild(game, name)
	if found == nil then
		found = newInstance(name)
		state[found].Name = name
		setParent(found, game)
	end
	services[name] = found
	return found
end

local workspace = Shim.service("Workspace")
state[workspace].props.Gravity = 196.2
state[workspace].props.CurrentCamera = newInstance("Camera")
Shim.service("Lighting").ClockTime = 14

------------------------------------------------------------------------------------------------------------------
-- Loading the project: modules from source files, assets from model JSON

local moduleCache = {}
local loading = {}

local baseEnv = {
	Vector3 = Vector3,
	Vector2 = Vector2,
	CFrame = CFrame,
	Color3 = Color3,
	UDim = UDim,
	UDim2 = UDim2,
	NumberRange = NumberRange,
	NumberSequence = NumberSequence,
	NumberSequenceKeypoint = NumberSequenceKeypoint,
	ColorSequence = ColorSequence,
	ColorSequenceKeypoint = ColorSequenceKeypoint,
	TweenInfo = TweenInfo,
	PhysicalProperties = PhysicalProperties,
	Rect = Rect,
	Ray = Ray,
	Font = Font,
	BrickColor = BrickColor,
	Enum = Enum,
	Instance = Instance,
	RaycastParams = RaycastParams,
	OverlapParams = OverlapParams,
	typeof = shimTypeof,
	game = game,
	workspace = workspace,
	Workspace = workspace,
	tick = os.clock,
	time = os.clock,
	elapsedTime = os.clock,
	warn = function(...)
		Shim.warnings = (Shim.warnings or 0) + 1
		if Shim.verbose then
			print("[warn]", ...)
		end
	end,
	task = {
		spawn = function(f, ...)
			if type(f) == "function" then
				local ok, err = pcall(f, ...)
				if not ok and Shim.verbose then
					print("[task.spawn error]", err)
				end
			end
		end,
		defer = function() end,
		delay = function() end,
		wait = function()
			return 0
		end,
		cancel = function() end,
		synchronize = function() end,
		desynchronize = function() end,
	},
	wait = function()
		return 0
	end,
	delay = function() end,
	spawn = function() end,
	DateTime = {
		now = function()
			return { UnixTimestamp = os.time(), UnixTimestampMillis = os.time() * 1000 }
		end,
	},
	Random = Random,
}
setmetatable(baseEnv, { __index = _G })

local function requireModule(module)
	if type(module) ~= "table" or getmetatable(module) ~= InstanceMT then
		error("require expects a ModuleScript (cloud world shim)", 2)
	end
	local cached = moduleCache[module]
	if cached ~= nil then
		return cached
	end
	local s = state[module]
	if loading[module] then
		error("Requested module was required recursively: " .. methods.GetFullName(module), 2)
	end
	if s.source == nil then
		error("require: " .. methods.GetFullName(module) .. " has no source file", 2)
	end
	loading[module] = true
	local env = setmetatable({ script = module }, { __index = baseEnv })
	env.require = requireModule
	local chunk = hostLoad("module", s.source, env)
	local result = chunk()
	loading[module] = nil
	moduleCache[module] = result
	return result
end
baseEnv.require = requireModule

-- Rojo JSON model properties into instance properties.
local function toCFrame(data)
	local p, o = data.position, data.orientation
	return cf(p[1], p[2], p[3], o[1][1], o[1][2], o[1][3], o[2][1], o[2][2], o[2][3], o[3][1], o[3][2], o[3][3])
end

local ENUM_PROPS = {
	Material = "Material",
	Shape = "PartType",
	MeshType = "MeshType",
	TopSurface = "SurfaceType",
	BottomSurface = "SurfaceType",
	LeftSurface = "SurfaceType",
	RightSurface = "SurfaceType",
	FrontSurface = "SurfaceType",
	BackSurface = "SurfaceType",
	ModelStreamingMode = "ModelStreamingMode",
	Face = "NormalId",
}

local function fromData(data, name)
	local inst = newInstance(data.className or "Folder")
	local s = state[inst]
	s.Name = name or data.name or s.ClassName
	for key, value in data.properties or {} do
		if key == "CFrame" or key == "PivotOffset" then
			s.props[key] = toCFrame(value.CFrame)
		elseif key == "WorldPivotData" then
			if value.OptionalCFrame then
				s.worldPivot = toCFrame(value.OptionalCFrame)
			end
		elseif key == "Size" or key == "Scale" or key == "Offset" or key == "VertexColor" then
			s.props[key] = v3(value[1], value[2], value[3])
		elseif key == "Color" then
			s.props.Color = c3(value[1], value[2], value[3])
		elseif ENUM_PROPS[key] then
			s.props[key] = Enum[ENUM_PROPS[key]][value]
		elseif key == "Tags" then
			for _, tag in value do
				methods.AddTag(inst, tag)
			end
		else
			s.props[key] = value
		end
	end
	for key, value in data.attributes or {} do
		s.attrs[key] = value
	end
	for _, childData in data.children or {} do
		local child = fromData(childData)
		state[child].Parent = inst
		table.insert(s.children, child)
	end
	return inst
end

-- Rojo refs: Rojo_Target_<Prop> names the Rojo_Id of another instance in the same file.
local function resolveRefs(root)
	local byId = {}
	for _, d in descendants(root) do
		local id = state[d].attrs.Rojo_Id
		if id then
			byId[id] = d
		end
	end
	local all = descendants(root)
	table.insert(all, root)
	for _, d in all do
		local s = state[d]
		for key, value in table.clone(s.attrs) do
			local prop = string.match(key, "^Rojo_Target_(.+)$")
			if prop and byId[value] then
				s.props[prop] = byId[value]
			end
		end
	end
end

Shim.assetsLoaded = 0

local function build(node, parent)
	local inst
	if parent ~= nil and node.json and string.sub(node.name, -6) == ".model" then
		local name = string.sub(node.name, 1, -7)
		local data = hostLoad("asset", node.path)()
		inst = fromData(data, name)
		state[inst].assetName = name
		resolveRefs(inst)
		Shim.assetsLoaded += 1
	else
		if parent == nil then
			inst = game
		elseif state[parent].ClassName == "DataModel" then
			inst = Shim.service(node.name)
		else
			inst = newInstance(node.className or "Folder")
			state[inst].Name = node.name
		end
		if node.path then
			state[inst].source = node.path
		end
	end
	if parent ~= nil and state[inst].Parent == nil then
		setParent(inst, parent)
	end
	if not (node.json and string.sub(node.name, -6) == ".model") then
		for _, child in node.children do
			build(child, inst)
		end
	end
	return inst
end

build(tree, nil)

------------------------------------------------------------------------------------------------------------------
-- Reading the world back

function Shim.find(path)
	local at = game
	for segment in string.gmatch(path, "[^%.]+") do
		at = findChild(at, segment)
		if at == nil then
			error("no " .. segment .. " in " .. path)
		end
	end
	return at
end

Shim.require = requireModule
Shim.game = game

local function num(x)
	-- six decimals at most, no "-0"
	local r = math.floor(x * 1e6 + 0.5) / 1e6
	if r == 0 then
		r = 0
	end
	return r
end

-- Every BasePart under `root`, as tab-separated lines: path, class, shape, x y z, 9 rotation numbers, size x y z,
-- transparency, collides, mesh scale (SpecialMesh) or "", the placed unit's path, material, the unit's asset name.
function Shim.dumpParts(root)
	local lines = {}
	for _, d in descendants(root) do
		local s = state[d]
		if isA(s.ClassName, "BasePart") then
			local p = s.props
			local m = p.CFrame
			local shape = if p.Shape then p.Shape.Name else "Block"
			local meshScale = ""
			for _, child in s.children do
				local cs = state[child]
				if cs.ClassName == "SpecialMesh" then
					local k = cs.props.Scale or v3(1, 1, 1)
					local meshType = cs.props.MeshType
					meshScale = string.format(
						"%s %g %g %g",
						if meshType then meshType.Name else "Brick",
						k.X,
						k.Y,
						k.Z
					)
				end
			end
			-- the placed thing the part belongs to: the outermost asset clone above it, else its nearest Model
			local nearest = methods.FindFirstAncestorWhichIsA(d, "Model")
			local unit = nil
			local at = s.Parent
			while at ~= nil and at ~= root and at ~= workspace do
				if state[at].assetName ~= nil then
					unit = at
				end
				at = state[at].Parent
			end
			if root ~= workspace and state[root].assetName ~= nil and unit == nil then
				unit = root
			end
			unit = unit or nearest
			local ownerPath = if unit and unit ~= workspace then methods.GetFullName(unit) else ""
			local assetName = if unit then state[unit].assetName or "" else ""
			local fields = {
				methods.GetFullName(d),
				s.ClassName,
				shape,
			}
			for k = 1, 12 do
				table.insert(fields, tostring(num(m[k])))
			end
			table.insert(fields, tostring(num(p.Size.X)))
			table.insert(fields, tostring(num(p.Size.Y)))
			table.insert(fields, tostring(num(p.Size.Z)))
			table.insert(fields, tostring(p.Transparency or 0))
			table.insert(fields, if p.CanCollide == false then "0" else "1")
			table.insert(fields, meshScale)
			table.insert(fields, ownerPath)
			table.insert(fields, if p.Material then p.Material.Name else "Plastic")
			table.insert(fields, assetName)
			table.insert(lines, table.concat(fields, "\t"))
		end
	end
	return table.concat(lines, "\n")
end

-- the asset models themselves, each at its own pivot, for the per-model checks
function Shim.assetNames()
	local assets = findChild(Shim.service("ReplicatedStorage"), "Assets")
	local out = {}
	if assets then
		for _, child in state[assets].children do
			table.insert(out, state[child].Name)
		end
	end
	table.sort(out)
	return out
end

return Shim
