--!strict
-- Tiny instance builder. Create("Frame", { Size = ..., Parent = x }, { child1, child2 })
-- Parent is applied last so the instance is fully configured before it replicates to the tree.
-- Returns `any` on purpose so call sites can assign to a typed local without a cast.

local function Create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent: Instance? = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

return Create
