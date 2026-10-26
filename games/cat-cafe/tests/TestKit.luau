--!strict
--[[
	TestKit: a small test framework for Purr Pot that runs both inside Roblox Studio
	and in the cloud (plain Luau VM, no Roblox APIs needed).

	The API is a subset of TestEZ (Roblox's test framework), so specs written here
	keep working if the studio switches to TestEZ or Jest-Lua later:

		return function()
			local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

			describe("Config", function()
				it("has a positive base customer spawn rate", function()
					expect(Config.CustomerSpawnSeconds).to.be.a("number")
					expect(Config.CustomerSpawnSeconds > 0).to.equal(true)
				end)
			end)
		end

	Globals injected into each spec function: describe, it, itSKIP, xit, itFOCUS, fit,
	describeSKIP, xdescribe, describeFOCUS, fdescribe, beforeEach, afterEach, beforeAll,
	afterAll, expect.

	expect(value) supports the TestEZ chain words (to, be, been, have, was, at, never)
	and these checks: ok(), equal(x), near(x, limit), a(typeName) / an(typeName),
	throw(messagePart?), plus two extensions: deepEqual(x) and contain(item).

	Owner: qa-playtester. Specs live in tests/specs/*.spec.luau.
]]

local TestKit = {}

export type Status = "pass" | "fail" | "skip"

export type Result = {
	path: string,
	status: Status,
	message: string?,
	durationSeconds: number,
}

export type Summary = {
	passed: number,
	failed: number,
	skipped: number,
	results: { Result },
	failures: { Result },
	durationSeconds: number,
}

type Hook = () -> ()

type Node = {
	kind: "describe" | "it",
	name: string,
	body: (() -> ())?,
	children: { Node },
	parent: Node?,
	skip: boolean,
	focus: boolean,
	beforeEach: { Hook },
	afterEach: { Hook },
	beforeAll: { Hook },
	afterAll: { Hook },
}

type SpecEntry = {
	name: string,
	body: (env: { [string]: any }) -> (),
}

export type RunOptions = {
	print: ((string) -> ())?,
	verbose: boolean?,
}

local function newNode(kind: "describe" | "it", name: string, parent: Node?): Node
	return {
		kind = kind,
		name = name,
		body = nil,
		children = {},
		parent = parent,
		skip = false,
		focus = false,
		beforeEach = {},
		afterEach = {},
		beforeAll = {},
		afterAll = {},
	}
end

local function nodePath(node: Node): string
	local parts = {}
	local current: Node? = node
	while current do
		if current.parent ~= nil then
			table.insert(parts, 1, current.name)
		end
		current = current.parent
	end
	return table.concat(parts, " > ")
end

local function now(): number
	return os.clock()
end

-- Some Roblox builtins are not in a plain Luau VM. Resolve them once, with fallbacks.
local typeOf: (any) -> string = (typeof :: any) or type

-- Deep equality for tables (by value), identity for everything else.
local function deepEqual(a: any, b: any, seen: { [any]: boolean }?): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	local visited = seen or {}
	if visited[a] then
		return true
	end
	visited[a] = true
	for key, value in pairs(a) do
		if not deepEqual(value, b[key], visited) then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local function describeValue(value: any): string
	local kind = typeOf(value)
	if kind == "string" then
		return string.format("%q", value)
	elseif kind == "table" then
		local parts = {}
		local count = 0
		for key, item in pairs(value) do
			count += 1
			if count > 6 then
				table.insert(parts, "...")
				break
			end
			table.insert(parts, string.format("%s = %s", tostring(key), tostring(item)))
		end
		return "{ " .. table.concat(parts, ", ") .. " }"
	end
	return tostring(value) .. " (" .. kind .. ")"
end

-------------------------------------------------------------------------------
-- expect
-------------------------------------------------------------------------------

local CHAIN_WORDS = { to = true, be = true, been = true, have = true, was = true, at = true }

local Expectation = {}
Expectation.__index = function(self: any, key: string): any
	if CHAIN_WORDS[key] then
		return self
	end
	if key == "never" then
		rawset(self, "_negate", not rawget(self, "_negate"))
		return self
	end
	local check = Expectation[key]
	if type(check) == "function" then
		-- Bind self so TestEZ style `expect(x).to.equal(y)` works with a dot, not a colon.
		return function(...)
			return check(self, ...)
		end
	end
	return check
end

local function assertCondition(self: any, condition: boolean, message: string, negatedMessage: string)
	local negate = rawget(self, "_negate") == true
	if negate then
		if condition then
			error(negatedMessage, 3)
		end
	else
		if not condition then
			error(message, 3)
		end
	end
	rawset(self, "_negate", false)
	return self
end

function Expectation.ok(self: any)
	local value = rawget(self, "_value")
	return assertCondition(
		self,
		value ~= nil and value ~= false,
		string.format("Expected value to be ok (not nil or false), got %s", describeValue(value)),
		string.format("Expected value to never be ok, got %s", describeValue(value))
	)
end

function Expectation.equal(self: any, other: any)
	local value = rawget(self, "_value")
	return assertCondition(
		self,
		value == other,
		string.format("Expected %s to equal %s", describeValue(value), describeValue(other)),
		string.format("Expected %s to never equal %s", describeValue(value), describeValue(other))
	)
end

function Expectation.deepEqual(self: any, other: any)
	local value = rawget(self, "_value")
	return assertCondition(
		self,
		deepEqual(value, other),
		string.format("Expected %s to deep-equal %s", describeValue(value), describeValue(other)),
		string.format("Expected %s to never deep-equal %s", describeValue(value), describeValue(other))
	)
end

function Expectation.near(self: any, other: number, limit: number?)
	local value = rawget(self, "_value")
	local tolerance = limit or 1e-7
	local isNumber = type(value) == "number" and type(other) == "number"
	local close = isNumber and math.abs((value :: number) - other) <= tolerance
	return assertCondition(
		self,
		close,
		string.format("Expected %s to be within %s of %s", describeValue(value), tostring(tolerance), tostring(other)),
		string.format("Expected %s to never be within %s of %s", describeValue(value), tostring(tolerance), tostring(other))
	)
end

function Expectation.a(self: any, typeName: string)
	local value = rawget(self, "_value")
	local actual = typeOf(value)
	return assertCondition(
		self,
		actual == typeName,
		string.format("Expected value of type %s, got %s (%s)", typeName, actual, describeValue(value)),
		string.format("Expected value to never be of type %s, got %s", typeName, describeValue(value))
	)
end
Expectation.an = Expectation.a

function Expectation.throw(self: any, messagePart: string?)
	local value = rawget(self, "_value")
	if type(value) ~= "function" then
		error(string.format("expect(...).to.throw() needs a function, got %s", describeValue(value)), 2)
	end
	local ok, err = pcall(value)
	local threw = not ok
	local errText = tostring(err)
	if threw and messagePart ~= nil then
		threw = string.find(errText, messagePart, 1, true) ~= nil
		return assertCondition(
			self,
			threw,
			string.format("Expected error containing %q, got %q", messagePart, errText),
			string.format("Expected no error containing %q, got %q", messagePart, errText)
		)
	end
	return assertCondition(
		self,
		threw,
		"Expected function to throw, but it returned normally",
		string.format("Expected function to never throw, but it threw: %s", errText)
	)
end

function Expectation.contain(self: any, item: any)
	local value = rawget(self, "_value")
	local found = false
	if type(value) == "table" then
		for _, entry in pairs(value) do
			if entry == item then
				found = true
				break
			end
		end
	elseif type(value) == "string" and type(item) == "string" then
		found = string.find(value, item, 1, true) ~= nil
	end
	return assertCondition(
		self,
		found,
		string.format("Expected %s to contain %s", describeValue(value), describeValue(item)),
		string.format("Expected %s to never contain %s", describeValue(value), describeValue(item))
	)
end

local function expect(value: any)
	return setmetatable({ _value = value, _negate = false }, Expectation)
end

TestKit.expect = expect

-------------------------------------------------------------------------------
-- Collection: build the describe/it tree by running the spec body
-------------------------------------------------------------------------------

local function buildEnvironment(root: Node)
	local current = root
	local env: { [string]: any } = {}

	local function addDescribe(name: string, body: () -> (), skip: boolean, focus: boolean)
		local node = newNode("describe", name, current)
		node.skip = skip
		node.focus = focus
		table.insert(current.children, node)
		local previous = current
		current = node
		local ok, err = pcall(body)
		current = previous
		if not ok then
			-- A describe body that errors becomes a single failing test so it is visible.
			local failing = newNode("it", "(describe block errored)", node)
			failing.body = function()
				error(err, 0)
			end
			table.insert(node.children, failing)
		end
	end

	local function addIt(name: string, body: (() -> ())?, skip: boolean, focus: boolean)
		local node = newNode("it", name, current)
		node.body = body
		node.skip = skip or body == nil
		node.focus = focus
		table.insert(current.children, node)
	end

	env.describe = function(name: string, body: () -> ())
		addDescribe(name, body, false, false)
	end
	env.describeSKIP = function(name: string, body: () -> ())
		addDescribe(name, body, true, false)
	end
	env.xdescribe = env.describeSKIP
	env.describeFOCUS = function(name: string, body: () -> ())
		addDescribe(name, body, false, true)
	end
	env.fdescribe = env.describeFOCUS

	env.it = function(name: string, body: (() -> ())?)
		addIt(name, body, false, false)
	end
	env.itSKIP = function(name: string, body: (() -> ())?)
		addIt(name, body, true, false)
	end
	env.xit = env.itSKIP
	env.itFOCUS = function(name: string, body: () -> ())
		addIt(name, body, false, true)
	end
	env.fit = env.itFOCUS

	env.beforeEach = function(hook: Hook)
		table.insert(current.beforeEach, hook)
	end
	env.afterEach = function(hook: Hook)
		table.insert(current.afterEach, hook)
	end
	env.beforeAll = function(hook: Hook)
		table.insert(current.beforeAll, hook)
	end
	env.afterAll = function(hook: Hook)
		table.insert(current.afterAll, hook)
	end
	env.expect = expect

	return env
end

local function hasFocus(node: Node): boolean
	if node.focus then
		return true
	end
	for _, child in ipairs(node.children) do
		if hasFocus(child) then
			return true
		end
	end
	return false
end

-------------------------------------------------------------------------------
-- Running
-------------------------------------------------------------------------------

local function collectHooks(node: Node, field: "beforeEach" | "afterEach"): { Hook }
	local chain = {}
	local current: Node? = node.parent
	while current do
		table.insert(chain, current)
		current = current.parent
	end
	local hooks = {}
	if field == "beforeEach" then
		for index = #chain, 1, -1 do
			for _, hook in ipairs(chain[index][field]) do
				table.insert(hooks, hook)
			end
		end
	else
		for _, ancestor in ipairs(chain) do
			for _, hook in ipairs(ancestor[field]) do
				table.insert(hooks, hook)
			end
		end
	end
	return hooks
end

local function callProtected(fn: () -> ()): (boolean, string?)
	local traceback: string? = nil
	local ok, err = xpcall(fn, function(message)
		traceback = debug.traceback(tostring(message), 2)
		return message
	end)
	if ok then
		return true, nil
	end
	return false, traceback or tostring(err)
end

local function runNode(node: Node, inheritedSkip: boolean, focusMode: boolean, summary: Summary, options: RunOptions)
	local output = options.print or print
	local skip = inheritedSkip or node.skip

	if node.kind == "it" then
		local path = nodePath(node)
		local shouldRun = not skip and (not focusMode or node.focus or (node.parent ~= nil and hasFocusAncestor(node)))
		if not shouldRun then
			summary.skipped += 1
			table.insert(summary.results, { path = path, status = "skip", message = nil, durationSeconds = 0 })
			if options.verbose then
				output("  [SKIP] " .. path)
			end
			return
		end

		local started = now()
		local ok, err = true, nil :: string?
		for _, hook in ipairs(collectHooks(node, "beforeEach")) do
			ok, err = callProtected(hook)
			if not ok then
				break
			end
		end
		if ok and node.body then
			ok, err = callProtected(node.body :: () -> ())
		end
		for _, hook in ipairs(collectHooks(node, "afterEach")) do
			local hookOk, hookErr = callProtected(hook)
			if ok and not hookOk then
				ok, err = hookOk, hookErr
			end
		end
		local duration = now() - started
		local result: Result = {
			path = path,
			status = if ok then "pass" else "fail",
			message = err,
			durationSeconds = duration,
		}
		table.insert(summary.results, result)
		if ok then
			summary.passed += 1
			if options.verbose then
				output("  [PASS] " .. path)
			end
		else
			summary.failed += 1
			table.insert(summary.failures, result)
			output("  [FAIL] " .. path)
		end
		return
	end

	-- describe: run beforeAll, children, afterAll
	local ranAll = false
	if not skip then
		for _, hook in ipairs(node.beforeAll) do
			local ok, err = callProtected(hook)
			if not ok then
				summary.failed += 1
				local result: Result = {
					path = nodePath(node) .. " > beforeAll",
					status = "fail",
					message = err,
					durationSeconds = 0,
				}
				table.insert(summary.results, result)
				table.insert(summary.failures, result)
				output("  [FAIL] " .. result.path)
				skip = true
				break
			end
		end
		ranAll = not skip
	end
	for _, child in ipairs(node.children) do
		runNode(child, skip, focusMode, summary, options)
	end
	if ranAll then
		for _, hook in ipairs(node.afterAll) do
			local ok, err = callProtected(hook)
			if not ok then
				summary.failed += 1
				local result: Result = {
					path = nodePath(node) .. " > afterAll",
					status = "fail",
					message = err,
					durationSeconds = 0,
				}
				table.insert(summary.results, result)
				table.insert(summary.failures, result)
				output("  [FAIL] " .. result.path)
			end
		end
	end
end

function hasFocusAncestor(node: Node): boolean
	local current: Node? = node.parent
	while current do
		if current.focus then
			return true
		end
		current = current.parent
	end
	return false
end

--[[
	Runs a list of specs. Each entry is { name = "Config.spec", body = <spec function> }.
	The spec function is called with the test environment table and, where the VM allows
	it, also has that table set as its function environment so bare `describe`/`it`/`expect`
	work (TestEZ style).
]]
function TestKit.runSpecs(specs: { SpecEntry }, options: RunOptions?): Summary
	local opts: RunOptions = options or {}
	local output = opts.print or print
	local summary: Summary = {
		passed = 0,
		failed = 0,
		skipped = 0,
		results = {},
		failures = {},
		durationSeconds = 0,
	}
	local started = now()

	local root = newNode("describe", "(root)", nil)
	for _, spec in ipairs(specs) do
		local specNode = newNode("describe", spec.name, root)
		table.insert(root.children, specNode)
		local env = buildEnvironment(specNode)

		local setEnvironment = (setfenv :: any)
		local getEnvironment = (getfenv :: any)
		if setEnvironment ~= nil and getEnvironment ~= nil then
			local ok = pcall(function()
				local outer = getEnvironment(spec.body)
				setmetatable(env, { __index = outer })
				setEnvironment(spec.body, env)
			end)
			if not ok then
				setmetatable(env, nil)
			end
		end

		local ok, err = callProtected(function()
			spec.body(env)
		end)
		if not ok then
			local failing = newNode("it", "(spec file errored while loading)", specNode)
			failing.body = function()
				error(err, 0)
			end
			table.insert(specNode.children, failing)
		end
	end

	local focusMode = hasFocus(root)
	output(string.format("TestKit: running %d spec file(s)%s", #specs, if focusMode then " (FOCUS mode)" else ""))
	for _, specNode in ipairs(root.children) do
		output("- " .. specNode.name)
		for _, child in ipairs(specNode.children) do
			runNode(child, false, focusMode, summary, opts)
		end
	end

	summary.durationSeconds = now() - started

	if #summary.failures > 0 then
		output("")
		output("Failures:")
		for index, failure in ipairs(summary.failures) do
			output(string.format("%d) %s", index, failure.path))
			output("   " .. string.gsub(failure.message or "(no message)", "\n", "\n   "))
		end
	end
	output("")
	output(
		string.format(
			"Tests: %d passed, %d failed, %d skipped (%.2fs)",
			summary.passed,
			summary.failed,
			summary.skipped,
			summary.durationSeconds
		)
	)
	return summary
end

return TestKit
