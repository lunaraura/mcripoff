local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local BuildController = {}
BuildController.__index = BuildController

function BuildController.new()
	return setmetatable({ requestContextAction = remotes:WaitForChild("RequestContextAction") }, BuildController)
end

function BuildController:sendContext(payload)
	self.requestContextAction:FireServer(payload)
end

return BuildController
