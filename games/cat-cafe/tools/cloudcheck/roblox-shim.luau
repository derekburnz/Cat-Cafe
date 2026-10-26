--!nocheck
--[[
	roblox-shim: builds a fake Roblox instance tree (from a Rojo project file, parsed by
	run-tests.mjs) and the handful of Roblox globals that pure modules tend to touch at
	load time. Enough to require shared modules and run TestKit specs outside Studio.

	What works: game, workspace, game:GetService(), Instance navigation (Name, ClassName,
	Parent, children by name, FindFirstChild, WaitForChild, GetChildren, GetDescendants,
	IsA, GetFullName), require(instance) and require("./relative"), task.*, warn, tick,
	Color3, Vector2, Vector3, UDim, UDim2, NumberRange, Random, and a permissive Enum.

	What does not: Instance.new, events, physics, DataStores, Players, RunService:IsServer.
	A module that needs those is Studio-only; its spec will fail here with a clear message.
]]

local tree, hostRequire = ...

local Shim = {}

-------------------------------------------------------------------------------
-- Class hierarchy for IsA
-------------------------------------------------------------------------------

local SUPERCLASS = {
	ModuleScript = "LuaSourceContainer",
	Script = "BaseScript",
	LocalScript = "BaseScript",
	BaseScript = "LuaSourceContainer",
	LuaSourceContainer = "Instance",
	Folder = "Instance",
	DataModel = "ServiceProvider",
	ServiceProvider = "Instance",
	Model = "PVInstance",
	PVInstance = "Instance",
	StarterPlayerScripts = "StarterPlayerScripts",
	Workspace = "WorldRoot",
	WorldRoot = "Model",
}

local function isA(className, target)
	local current = className
	while current do
		if current == target then
			return true
		end
		if current == "Instance" then
			return false
		end
		current = SUPERCLASS[current] or "Instance"
	end
	return false
end

-------------------------------------------------------------------------------
-- Instance proxies
-------------------------------------------------------------------------------

local proxyById = {}
local nodeByProxy = {}

local function fullName(node)
	local parts = {}
	local current = node
	while current and current.parent do
		table.insert(parts, 1, current.name)
		current = current.parent
	end
	return table.concat(parts, ".")
end

local function buildProxy(node, parent)
	node.parent = parent
	local proxy = newproxy and newproxy(true) or setmetatable({}, {})
	local meta = getmetatable(proxy)
	proxyById[node.id] = proxy
	nodeByProxy[proxy] = node

	local childProxies = {}
	for name, child in pairs(node.children or {}) do
		childProxies[name] = buildProxy(child, node)
	end
	node.childProxies = childProxies

	local methods = {}
	methods.GetService = function(_, serviceName)
		if type(serviceName) ~= "string" then
			error("GetService: service name must be a string", 2)
		end
		local existing = childProxies[serviceName]
		if existing then
			return existing
		end
		-- Create an empty stub service so `local RunService = game:GetService("RunService")`
		-- works at load time. Calling methods on it errors with a clear message.
		local stub = { id = node.id .. "/" .. serviceName, name = serviceName, className = serviceName, children = {}, stub = true }
		node.children[serviceName] = stub
		childProxies[serviceName] = buildProxy(stub, node)
		return childProxies[serviceName]
	end
	methods.FindFirstChild = function(_, childName)
		return childProxies[childName]
	end
	methods.WaitForChild = function(_, childName)
		local child = childProxies[childName]
		if child == nil then
			error(string.format("WaitForChild: %s has no child named %q (cloud shim never waits)", fullName(node), tostring(childName)), 2)
		end
		return child
	end
	methods.GetChildren = function()
		local list = {}
		for _, child in pairs(childProxies) do
			table.insert(list, child)
		end
		table.sort(list, function(a, b)
			return nodeByProxy[a].name < nodeByProxy[b].name
		end)
		return list
	end
	methods.GetDescendants = function()
		local list = {}
		local function walk(current)
			for _, child in ipairs(current) do
				table.insert(list, child)
				walk(nodeByProxy[child] and methods_of(child).GetChildren() or {})
			end
		end
		walk(methods.GetChildren())
		return list
	end
	methods.IsA = function(_, className)
		return isA(node.className, className)
	end
	methods.GetFullName = function()
		return fullName(node)
	end
	methods.IsDescendantOf = function(_, other)
		local otherNode = nodeByProxy[other]
		local current = node.parent
		while current do
			if current == otherNode then
				return true
			end
			current = current.parent
		end
		return false
	end
	methods.GetAttribute = function()
		return nil
	end
	methods.Destroy = function() end
	node.methods = methods

	meta.__index = function(_, key)
		if key == "Name" then
			return node.name
		elseif key == "ClassName" then
			return node.className
		elseif key == "Parent" then
			return parent and proxyById[parent.id] or nil
		elseif key == "__nodeId" then
			return node.id
		end
		local method = methods[key]
		if method then
			return method
		end
		local child = childProxies[key]
		if child then
			return child
		end
		if node.stub then
			error(string.format("%s.%s is not available in cloud tests (the %s service is a stub). This module is Studio-only.", node.name, tostring(key), node.name), 2)
		end
		error(string.format("%s is not a valid member of %s \"%s\"", tostring(key), node.className, fullName(node)), 2)
	end
	meta.__newindex = function(_, key)
		error(string.format("cannot set %s on %s in cloud tests", tostring(key), fullName(node)), 2)
	end
	meta.__tostring = function()
		return node.name
	end
	meta.__metatable = "The metatable is locked"
	return proxy
end

function methods_of(proxy)
	return nodeByProxy[proxy].methods
end

local game = buildProxy(tree, nil)
Shim.game = game

function Shim.getProxy(id)
	return proxyById[id]
end

-------------------------------------------------------------------------------
-- require: instance paths and relative strings, both delegated to the host
-------------------------------------------------------------------------------

local function resolveRelative(fromNode, specifier)
	local start
	local rest
	if string.sub(specifier, 1, 2) == "./" then
		start = fromNode.parent
		rest = string.sub(specifier, 3)
	elseif string.sub(specifier, 1, 3) == "../" then
		start = fromNode.parent and fromNode.parent.parent
		rest = string.sub(specifier, 4)
	elseif string.sub(specifier, 1, 6) == "@self/" then
		start = fromNode
		rest = string.sub(specifier, 7)
	else
		error(string.format("require(%q): only ./, ../ and @self/ string requires are supported", specifier), 3)
	end
	local current = start
	for segment in string.gmatch(rest, "[^/]+") do
		if segment == ".." then
			current = current and current.parent
		elseif segment ~= "." then
			current = current and current.children and current.children[segment]
		end
		if current == nil then
			error(string.format("require(%q) from %s: module not found", specifier, fullName(fromNode)), 3)
		end
	end
	return current
end

function Shim.makeEnv(nodeId)
	local node
	for proxy, candidate in pairs(nodeByProxy) do
		if candidate.id == nodeId then
			node = candidate
			break
		end
	end
	assert(node, "makeEnv: unknown node " .. tostring(nodeId))

	local env = setmetatable({}, { __index = _G })
	env.script = proxyById[nodeId]
	env.require = function(target)
		local targetNode
		if type(target) == "string" then
			targetNode = resolveRelative(node, target)
		elseif nodeByProxy[target] ~= nil then
			targetNode = nodeByProxy[target]
		else
			error("require: expected a ModuleScript or a relative string path, got " .. typeof(target), 2)
		end
		if targetNode.className ~= "ModuleScript" then
			error(string.format("Attempted to call require with invalid argument(s): %s is a %s, not a ModuleScript", fullName(targetNode), targetNode.className), 2)
		end
		return hostRequire(targetNode.id)
	end
	return env
end

-------------------------------------------------------------------------------
-- Minimal Roblox globals
-------------------------------------------------------------------------------

_G.game = game
local workspaceNode = tree.children and tree.children.Workspace
if workspaceNode then
	_G.workspace = proxyById[workspaceNode.id]
end
_G.shared = {}

_G.warn = function(...)
	local parts = {}
	for index = 1, select("#", ...) do
		parts[index] = tostring(select(index, ...))
	end
	print("[warn] " .. table.concat(parts, " "))
end

_G.tick = os.clock
_G.time = os.clock
_G.elapsedTime = os.clock

_G.task = {
	wait = function(seconds)
		return seconds or 0
	end,
	spawn = function(fn, ...)
		-- Like Roblox: the handler runs in its own thread and an error there is reported, not raised.
		local thread = coroutine.create(fn)
		local ok, err = coroutine.resume(thread, ...)
		if not ok then
			print("[task.spawn error] " .. tostring(err))
		end
		return thread
	end,
	defer = function(fn, ...)
		return _G.task.spawn(fn, ...)
	end,
	delay = function(_, fn, ...)
		return _G.task.spawn(fn, ...)
	end,
	cancel = function() end,
	synchronize = function() end,
	desynchronize = function() end,
}
_G.wait = _G.task.wait
_G.spawn = function(fn)
	return _G.task.spawn(fn)
end
_G.delay = _G.task.delay

_G.Instance = {
	new = function(className)
		error(string.format("Instance.new(%q) is not available in cloud tests; this module is Studio-only", tostring(className)), 2)
	end,
}

-- Enum: any Enum.Foo.Bar works and gives { Name = "Bar", Value = 0, EnumType = <Foo> }.
local function makeEnumType(typeName)
	return setmetatable({}, {
		__index = function(self, itemName)
			local item = setmetatable({ Name = itemName, Value = 0, EnumType = self }, {
				__tostring = function()
					return "Enum." .. typeName .. "." .. itemName
				end,
			})
			rawset(self, itemName, item)
			return item
		end,
		__tostring = function()
			return "Enum." .. typeName
		end,
	})
end
_G.Enum = setmetatable({}, {
	__index = function(self, typeName)
		local enumType = makeEnumType(typeName)
		rawset(self, typeName, enumType)
		return enumType
	end,
})

-- Color3
local Color3 = {}
Color3.__index = Color3
function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3)
end
function Color3.fromRGB(r, g, b)
	return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end
function Color3.fromHex(hex)
	hex = string.gsub(hex, "^#", "")
	if #hex == 3 then
		hex = string.rep(string.sub(hex, 1, 1), 2) .. string.rep(string.sub(hex, 2, 2), 2) .. string.rep(string.sub(hex, 3, 3), 2)
	end
	return Color3.fromRGB(tonumber(string.sub(hex, 1, 2), 16), tonumber(string.sub(hex, 3, 4), 16), tonumber(string.sub(hex, 5, 6), 16))
end
function Color3.fromHSV(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i = i % 6
	if i == 0 then return Color3.new(v, t, p) end
	if i == 1 then return Color3.new(q, v, p) end
	if i == 2 then return Color3.new(p, v, t) end
	if i == 3 then return Color3.new(p, q, v) end
	if i == 4 then return Color3.new(t, p, v) end
	return Color3.new(v, p, q)
end
function Color3:Lerp(other, alpha)
	return Color3.new(self.R + (other.R - self.R) * alpha, self.G + (other.G - self.G) * alpha, self.B + (other.B - self.B) * alpha)
end
function Color3:ToHex()
	return string.format("%02X%02X%02X", math.round(self.R * 255), math.round(self.G * 255), math.round(self.B * 255))
end
Color3.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end
Color3.__tostring = function(c)
	return string.format("%g, %g, %g", c.R, c.G, c.B)
end
_G.Color3 = Color3

-- Vector3 / Vector2
local function makeVector(fields)
	local V = {}
	V.__index = V
	function V.new(...)
		local values = { ... }
		local self = {}
		for index, field in ipairs(fields) do
			self[field] = values[index] or 0
		end
		return setmetatable(self, V)
	end
	local function map(a, b, op)
		local out = {}
		for index, field in ipairs(fields) do
			local bv = type(b) == "number" and b or b[field]
			local av = type(a) == "number" and a or a[field]
			out[index] = op(av, bv)
		end
		return V.new(table.unpack(out))
	end
	V.__add = function(a, b) return map(a, b, function(x, y) return x + y end) end
	V.__sub = function(a, b) return map(a, b, function(x, y) return x - y end) end
	V.__mul = function(a, b) return map(a, b, function(x, y) return x * y end) end
	V.__div = function(a, b) return map(a, b, function(x, y) return x / y end) end
	V.__unm = function(a) return map(a, -1, function(x, y) return x * y end) end
	V.__eq = function(a, b)
		for _, field in ipairs(fields) do
			if a[field] ~= b[field] then return false end
		end
		return true
	end
	V.__tostring = function(v)
		local parts = {}
		for _, field in ipairs(fields) do table.insert(parts, tostring(v[field])) end
		return table.concat(parts, ", ")
	end
	V.__index = function(self, key)
		if key == "Magnitude" then
			local sum = 0
			for _, field in ipairs(fields) do sum += rawget(self, field) ^ 2 end
			return math.sqrt(sum)
		elseif key == "Unit" then
			local m = self.Magnitude
			return map(self, m == 0 and 1 or m, function(x, y) return x / y end)
		end
		return V[key]
	end
	function V:Dot(other)
		local sum = 0
		for _, field in ipairs(fields) do sum += self[field] * other[field] end
		return sum
	end
	function V:Lerp(other, alpha)
		return self + (other - self) * alpha
	end
	V.zero = V.new()
	V.one = V.new(1, 1, 1)
	return V
end
_G.Vector3 = makeVector({ "X", "Y", "Z" })
_G.Vector3.xAxis = _G.Vector3.new(1, 0, 0)
_G.Vector3.yAxis = _G.Vector3.new(0, 1, 0)
_G.Vector3.zAxis = _G.Vector3.new(0, 0, 1)
_G.Vector2 = makeVector({ "X", "Y" })

-- UDim / UDim2 / NumberRange
local UDim = {}
UDim.__index = UDim
function UDim.new(scale, offset)
	return setmetatable({ Scale = scale or 0, Offset = offset or 0 }, UDim)
end
UDim.__eq = function(a, b) return a.Scale == b.Scale and a.Offset == b.Offset end
_G.UDim = UDim
local UDim2 = {}
UDim2.__index = UDim2
function UDim2.new(xScale, xOffset, yScale, yOffset)
	return setmetatable({ X = UDim.new(xScale, xOffset), Y = UDim.new(yScale, yOffset) }, UDim2)
end
function UDim2.fromScale(x, y) return UDim2.new(x, 0, y, 0) end
function UDim2.fromOffset(x, y) return UDim2.new(0, x, 0, y) end
_G.UDim2 = UDim2
local NumberRange = {}
NumberRange.__index = NumberRange
function NumberRange.new(min, max)
	return setmetatable({ Min = min, Max = max or min }, NumberRange)
end
_G.NumberRange = NumberRange

-- Random: deterministic xorshift so tests can seed it
local Random = {}
Random.__index = Random
function Random.new(seed)
	local state = (seed or os.clock() * 1e6) % 4294967296
	if state == 0 then state = 88172645463325252 % 4294967296 end
	return setmetatable({ _state = math.floor(state) }, Random)
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
	if min == nil then return r end
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
_G.Random = Random

return Shim
