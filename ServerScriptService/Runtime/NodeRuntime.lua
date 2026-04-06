local NodeRuntime = {}
NodeRuntime.__index = NodeRuntime

local nextNodeId = 1

function NodeRuntime.new(nodeType, position, cooldown)
	local self = setmetatable({}, NodeRuntime)
	self.id = nextNodeId
	nextNodeId += 1
	self.nodeType = nodeType
	self.position = position
	self.cooldown = cooldown or 0
	self.cooldownLeft = 0
	return self
end

function NodeRuntime:IsActive()
	return self.cooldownLeft <= 0
end

function NodeRuntime:Tick(dt)
	self.cooldownLeft = math.max(0, self.cooldownLeft - dt)
end

return NodeRuntime
