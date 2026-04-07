local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local BuildableConfig = require(Config:WaitForChild("BuildableConfig"))
local PlacementPreviewHelper = require(script.Parent:WaitForChild("PlacementPreviewHelper"))

local BuildController = {}
BuildController.__index = BuildController

function BuildController.new()
	return setmetatable({
		requestContextAction = remotes:WaitForChild("RequestContextAction"),
		selectedTool = "node_demolisher",
		buildMode = false,
		selectedBuildKey = "tent",
		selectedRotationY = 0,
		placement = {
			valid = false,
			worldPos = nil,
			reason = "inactive",
		},
		preview = PlacementPreviewHelper.new(),
	}, BuildController)
end

function BuildController:sendContext(payload)
	self.requestContextAction:FireServer(payload)
end

function BuildController:selectTool(toolKey)
	self.selectedTool = toolKey
	self.buildMode = false
	self:clearPreview()
end

function BuildController:setBuildMode(enabled)
	self.buildMode = enabled and true or false
	if not self.buildMode then
		self:clearPreview()
	end
end

function BuildController:toggleBuildMode()
	self.buildMode = not self.buildMode
	return self.buildMode
end

function BuildController:selectBuildable(buildKey)
	self.selectedBuildKey = buildKey
	if not self.buildMode then
		self:clearPreview()
	end
end

function BuildController:handlePrimaryAction()
	if self.buildMode then
		if self.placement.valid and self.placement.worldPos then
			return self:sendContext({
				action = "build",
				buildKey = self.selectedBuildKey,
				position = self.placement.worldPos,
				rotationY = self.selectedRotationY,
			})
		end
		return false
	end
	if self.selectedTool then
		return self:sendContext({ action = "useTool", tool = self.selectedTool })
	end
	return self:sendContext({ action = "context" })
end

function BuildController:bind(mouse)
	self.mouse = mouse
	self.renderConn = RunService.RenderStepped:Connect(function()
		self:updatePreview()
	end)
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.X then
			self:setBuildMode(false)
		elseif input.KeyCode == Enum.KeyCode.R and self.buildMode then
			self.selectedRotationY = (self.selectedRotationY + 90) % 360
		end
	end)
end

function BuildController:clearPreview()
	self.placement.valid = false
	self.placement.worldPos = nil
	self.placement.reason = "inactive"
	self.preview:destroy()
end

function BuildController:getBuildSize(buildKey)
	if buildKey == "tent" then
		return Vector3.new(8, 5, 8)
	end
	return Vector3.new(4, 4, 4)
end

function BuildController:getMousePlacementPoint()
	local cam = Workspace.CurrentCamera
	if not cam or not self.mouse then return nil, nil end
	local ray = cam:ViewportPointToRay(self.mouse.X, self.mouse.Y)
	local params = RaycastParams.new()
	local localPlayer = Players.LocalPlayer
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { localPlayer.Character, self.preview.part }
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 400, params)
	if result then
		return result.Position, result
	end
	return nil, nil
end

function BuildController:hasEnoughMaterials(buildKey)
	local def = BuildableConfig[buildKey]
	if not def then return false end
	local player = Players.LocalPlayer
	for matKey, amt in pairs(def.cost or {}) do
		local count = tonumber(player:GetAttribute("Mat_" .. matKey)) or 0
		if count < amt then
			return false
		end
	end
	return true
end

function BuildController:isOverlapping(cframe, size)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Players.LocalPlayer.Character, self.preview.part }
	local parts = Workspace:GetPartBoundsInBox(cframe, size, params)
	for _, part in ipairs(parts) do
		if part.CanCollide and part.Transparency < 0.95 then
			return true
		end
	end
	return false
end

function BuildController:updatePreview()
	if not self.buildMode then
		self:clearPreview()
		return
	end
	local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character.PrimaryPart
	if not root then
		self:clearPreview()
		return
	end
	local point, rayResult = self:getMousePlacementPoint()
	if not point then
		self:clearPreview()
		return
	end
	local grid = 4
	local x = math.floor((point.X / grid) + 0.5) * grid
	local z = math.floor((point.Z / grid) + 0.5) * grid
	local size = self:getBuildSize(self.selectedBuildKey)
	local y = point.Y + size.Y * 0.5
	local cframe = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(self.selectedRotationY), 0)
	local inRange = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(x, 0, z)).Magnitude <= 18
	local allowedTerrain = not (rayResult and rayResult.Material == Enum.Material.Water)
	local noOverlap = not self:isOverlapping(cframe, size)
	local enoughMaterials = self:hasEnoughMaterials(self.selectedBuildKey)
	local valid = inRange and allowedTerrain and noOverlap and enoughMaterials
	self.preview:update(self.selectedBuildKey, cframe, valid)
	self.placement.valid = valid
	self.placement.worldPos = Vector3.new(x, y, z)
	self.placement.reason = valid and "ok" or "invalid"
end

return BuildController
