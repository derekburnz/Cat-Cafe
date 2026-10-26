--!strict
--[[
	StudioRunner: finds every ModuleScript named *.spec under a folder (default: the Tests
	folder this script lives in), requires each one and runs it with TestKit.

	In Roblox Studio (after `rojo serve tests.project.json` so ReplicatedStorage.Tests exists),
	run this from the command bar or through the Studio MCP execute_luau tool:

		local run = require(game:GetService("ReplicatedStorage").Tests.StudioRunner)
		local summary = run(nil, { verbose = true })
		return string.format("%d passed, %d failed, %d skipped", summary.passed, summary.failed, summary.skipped)

	In the cloud, tools/cloudcheck/run-tests.mjs builds a fake instance tree from the Rojo
	project file and calls this same function, so both paths run identical code.
]]

local TestKit = require(script.Parent.TestKit)

type SpecEntry = { name: string, body: (env: { [string]: any }) -> () }

local function isSpec(instance: Instance): boolean
	return instance:IsA("ModuleScript") and string.sub(instance.Name, -5) == ".spec"
end

local function collect(root: Instance, filter: string?): { SpecEntry }
	local specs: { SpecEntry } = {}
	local found = {}
	for _, instance in ipairs(root:GetDescendants()) do
		if isSpec(instance) then
			table.insert(found, instance)
		end
	end
	table.sort(found, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)

	for _, moduleScript in ipairs(found) do
		if filter ~= nil and not string.find(moduleScript.Name, filter, 1, true) then
			continue
		end
		local ok, result = pcall(require, moduleScript)
		if ok and type(result) == "function" then
			table.insert(specs, { name = moduleScript.Name, body = result })
		else
			local message = if ok
				then string.format("spec must return a function, got %s", typeof(result))
				else tostring(result)
			table.insert(specs, {
				name = moduleScript.Name,
				body = function()
					error("Could not load spec: " .. message, 0)
				end,
			})
		end
	end
	return specs
end

return function(root: Instance?, options: { verbose: boolean?, filter: string?, print: ((string) -> ())? }?): TestKit.Summary
	local opts = options or {}
	local folder = root or script.Parent
	local specs = collect(folder, opts.filter)
	return TestKit.runSpecs(specs, { verbose = opts.verbose, print = opts.print })
end
