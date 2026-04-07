local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local BuildController = {}
BuildController.__index = BuildController

function BuildController.new()
	return setmetatable({
		requestContextAction = remotes:WaitForChild("RequestContextAction"),
		selectedTool = "node_demolisher",
		buildMode = false,
		selectedBuildKey = "tent",
	}, BuildController)
end

function BuildController:sendContext(payload)
	self.requestContextAction:FireServer(payload)
end

function BuildController:selectTool(toolKey)
	self.selectedTool = toolKey
	self.buildMode = false
end

function BuildController:setBuildMode(enabled)
	self.buildMode = enabled and true or false
end

function BuildController:toggleBuildMode()
	self.buildMode = not self.buildMode
	return self.buildMode
end

function BuildController:selectBuildable(buildKey)
	self.selectedBuildKey = buildKey
end

function BuildController:handlePrimaryAction()
	if self.buildMode then
		return self:sendContext({ action = "build", buildKey = self.selectedBuildKey })
	end
	if self.selectedTool then
		return self:sendContext({ action = "useTool", tool = self.selectedTool })
	end
	return self:sendContext({ action = "context" })
end

return BuildController
