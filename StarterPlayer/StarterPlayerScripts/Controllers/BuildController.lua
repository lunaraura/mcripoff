local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Build = Shared:WaitForChild("Build")
local PlacementRules = require(Build:WaitForChild("PlacementRules"))
local Config = Shared:WaitForChild("Config")
local BuildableConfig = require(Config:WaitForChild("BuildableConfig"))
local HarvestConfig = require(Config:WaitForChild("HarvestConfig"))
local PlacementPreviewHelper = require(script.Parent:WaitForChild("PlacementPreviewHelper"))

local BuildController = {}
BuildController.__index = BuildController

-- Interaction prompt settings
local INTERACTION_RANGE = 20
local PROMPT_UPDATE_RATE = 0.1

function BuildController.new()
	local self = setmetatable({
		requestContextAction = remotes:WaitForChild("RequestContextAction"),
		selectedTool = "node_demolisher",
		buildMode = false,
		selectedBuildKey = "tent",
		selectedRotationY = 0,
		placement = { valid = false, worldPos = nil, reasonCode = PlacementRules.Reason.INVALID_ACTION, yGround = nil },
		preview = PlacementPreviewHelper.new(),
		-- Interaction prompt state
		currentTarget = nil,
		currentTargetType = nil,
		currentPromptText = "",
		lastPromptUpdate = 0,
		promptGui = nil,
	}, BuildController)
	self:createInteractionPrompt()
	return self
end

-- Create the world interaction prompt GUI
function BuildController:createInteractionPrompt()
	-- Intentionally disabled: the floating interaction prompt box was removed for UX cleanup.
	self.promptGui = nil
	self.promptLabel = nil
end

function BuildController:sendContext(payload)
	self.requestContextAction:FireServer(payload)
end

-- Get the current interaction target and type
function BuildController:getInteractionTarget()
	local player = Players.LocalPlayer
	local character = player.Character
	if not character then return nil, nil end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil, nil end
	
	local playerPos = hrp.Position
	local nearestTarget = nil
	local nearestDist = INTERACTION_RANGE
	local targetType = nil
	
	-- Check for nodes (trees, rocks, etc.)
	local nodes = Workspace:FindFirstChild("Nodes")
	if nodes then
		for _, node in ipairs(nodes:GetChildren()) do
			if node:IsA("BasePart") or node:IsA("Model") then
				local nodePos = node:IsA("Model") and node:GetPivot().Position or node.Position
				local dist = (playerPos - nodePos).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					nearestTarget = node
					targetType = "node"
				end
			end
		end
	end
	
	-- Check for berry bushes and harvestable objects
	local flora = Workspace:FindFirstChild("Flora")
	if flora then
		for _, plant in ipairs(flora:GetChildren()) do
			if plant:IsA("BasePart") then
				local dist = (playerPos - plant.Position).Magnitude
				if dist < nearestDist then
					if plant.Name:find("BerryBush") then
						nearestDist = dist
						nearestTarget = plant
						targetType = "berry_bush"
					elseif HarvestConfig.getObstacleDef(plant:GetAttribute("NodeType") or plant.Name:lower()) then
						nearestDist = dist
						nearestTarget = plant
						targetType = "node"
					end
				end
			end
		end
	end
	
	return nearestTarget, targetType
end

-- Generate prompt text based on current tool and target
function BuildController:getPromptText()
	local target, targetType = self:getInteractionTarget()
	self.currentTarget = target
	self.currentTargetType = targetType
	
	if not target then
		return ""
	end
	
	local toolDef = HarvestConfig.getToolDef(self.selectedTool)
	if not toolDef then
		return ""
	end
	
	-- Generate context-appropriate prompt
	if targetType == "node" then
		local nodeType = target:GetAttribute("NodeType") or target.Name:lower()
		local obstacleDef = HarvestConfig.getObstacleDef(nodeType)
		
		if toolDef.mode == "destroy" and toolDef.allowedNodeTypes[nodeType] then
			return string.format("[E] Harvest %s with %s", obstacleDef and obstacleDef.label or nodeType, toolDef.label)
		else
			return string.format("[E] Interact with %s", obstacleDef and obstacleDef.label or nodeType)
		end
		
	elseif targetType == "berry_bush" then
		local berryType = target.Name:match("BerryBush_(.+)") or "berry"
		
		if toolDef.mode == "gather_tool" then
			return string.format("[E] Gather %s with %s", berryType:gsub("_", " "), toolDef.label)
		else
			return string.format("[E] Interact with %s bush", berryType:gsub("_", " "))
		end
	end
	
	return "[E] Interact"
end

-- Update the interaction prompt display
function BuildController:updateInteractionPrompt()
	-- Prompt UI removed; keep target detection logic via getPromptText/getInteractionTarget intact.
	return
end

function BuildController:selectTool(toolKey)
	self.selectedTool = toolKey
	self.buildMode = false
	self:clearPreview()
end

function BuildController:setBuildMode(enabled)
	self.buildMode = enabled and true or false
	if not self.buildMode then self:clearPreview() end
end

function BuildController:toggleBuildMode()
	self.buildMode = not self.buildMode
	return self.buildMode
end

function BuildController:selectBuildable(buildKey)
	self.selectedBuildKey = buildKey
	self:clearPreview()
end

function BuildController:getBuildableEntries()
	local entries = {}
	for key, def in pairs(BuildableConfig) do
		if def and def.placement then
			table.insert(entries, {
				key = key,
				label = def.name or key,
				cost = def.cost or {},
			})
		end
	end
	table.sort(entries, function(a, b)
		return tostring(a.label) < tostring(b.label)
	end)
	return entries
end

-- Unified action execution - called by both E key and UI button
function BuildController:handlePrimaryAction()
	if self.buildMode then
		if self.placement.valid and self.placement.worldPos then
			return self:sendContext({ action = "build", buildKey = self.selectedBuildKey, position = self.placement.worldPos, yGround = self.placement.yGround, rotationY = self.selectedRotationY })
		end
		return false
	end
	
	-- Use the selected tool on the current target
	return self:sendContext({ action = "context", preferredTool = self.selectedTool, radius = 16 })
end

-- Get current tool info for UI display
function BuildController:getCurrentToolInfo()
	local toolDef = HarvestConfig.getToolDef(self.selectedTool)
	if not toolDef then
		return {
			key = self.selectedTool,
			label = self.selectedTool,
			mode = "unknown",
		}
	end
	return {
		key = self.selectedTool,
		label = toolDef.label,
		mode = toolDef.mode,
	}
end


function BuildController:plantShrub(berryKey)
	local pos = self.placement and self.placement.worldPos
	self:sendContext({ action = "plantShrub", berryKey = berryKey, position = pos })
end

function BuildController:bind(mouse)
	self.mouse = mouse
	self.renderConn = RunService.RenderStepped:Connect(function()
		self:updatePreview()
		self:updateInteractionPrompt()
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
	self.placement = { valid = false, worldPos = nil, reasonCode = PlacementRules.Reason.INVALID_ACTION, yGround = nil }
	self.preview:destroy()
end

function BuildController:getMousePlacementPoint()
	local cam = Workspace.CurrentCamera
	if not cam or not self.mouse then return nil, nil end
	local ray = cam:ViewportPointToRay(self.mouse.X, self.mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Players.LocalPlayer.Character, self.preview.part }
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 400, params)
	return result and result.Position or nil, result
end

function BuildController:hasEnoughMaterials(buildKey)
	local def = PlacementRules.getBuildDef(buildKey)
	if not def then return false end
	local player = Players.LocalPlayer
	for matKey, amt in pairs(def.cost or {}) do
		if (tonumber(player:GetAttribute("Mat_" .. matKey)) or 0) < amt then return false end
	end
	return true
end

function BuildController:getBlockingReason(cframe, size)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Players.LocalPlayer.Character, self.preview.part }
	for _, part in ipairs(Workspace:GetPartBoundsInBox(cframe, size, params)) do
		if part.CanCollide and part.Transparency < 0.95 then
			local category = part:GetAttribute("CollisionCategory")
			if category == "buildable" or part:FindFirstAncestor("Buildables") then return PlacementRules.Reason.OVERLAP_BUILD end
			if category == "node" or category == "obstacle" or part:FindFirstAncestor("Nodes") then return PlacementRules.Reason.OVERLAP_OBSTACLE end
			if part:FindFirstAncestor("CreatureModels") then return PlacementRules.Reason.OVERLAP_CREATURE end
		end
	end
	return nil
end

function BuildController:updatePreview()
	if not self.buildMode then return self:clearPreview() end
	local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character.PrimaryPart
	if not root then return self:clearPreview() end
	local point, rayResult = self:getMousePlacementPoint()
	if not point then return self:clearPreview() end
	local def = PlacementRules.getBuildDef(self.selectedBuildKey)
	local rules = PlacementRules.getPlacement(self.selectedBuildKey)
	if not def or not rules then return self:clearPreview() end
	if not rules.allowRotation then self.selectedRotationY = 0 end

	local snapped = PlacementRules.snapPosition(point, rules.grid, point.Y + (rules.footprintSize.y or 4) * 0.5)
	local size = Vector3.new(rules.footprintSize.x or 4, rules.footprintSize.y or 4, rules.footprintSize.z or 4)
	local cframe = CFrame.new(snapped) * CFrame.Angles(0, math.rad(self.selectedRotationY), 0)
	local inRange = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(snapped.X, 0, snapped.Z)).Magnitude <= rules.placementRange
	local terrainClass = PlacementRules.classifyTerrain(rayResult and rayResult.Material)
	local terrainOk = PlacementRules.isTerrainAllowed(terrainClass, rules)
	local overlapReason = self:getBlockingReason(cframe, size)
	local matsOk = self:hasEnoughMaterials(self.selectedBuildKey)

	local reasonCode = PlacementRules.Reason.OK
	if not inRange then reasonCode = PlacementRules.Reason.TOO_FAR
	elseif not terrainOk then reasonCode = PlacementRules.Reason.INVALID_TERRAIN
	elseif overlapReason then reasonCode = overlapReason
	elseif not matsOk then reasonCode = PlacementRules.Reason.MISSING_MATERIALS end

	local valid = reasonCode == PlacementRules.Reason.OK
	self.preview:update(def, cframe, valid)
	self.placement.valid = valid
	self.placement.worldPos = snapped
	self.placement.yGround = point.Y
	self.placement.reasonCode = reasonCode
end

return BuildController
