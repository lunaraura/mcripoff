local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local HarvestConfig = require(Config:WaitForChild("HarvestConfig"))
local BuildableConfig = require(Config:WaitForChild("BuildableConfig"))
local PlacementRules = require(Shared:WaitForChild("Build"):WaitForChild("PlacementRules"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestContextAction = remotes:WaitForChild("RequestContextAction")

-- Player state tracking
local playerStates = {}

local function getPlayerState(player)
	if not playerStates[player] then
		playerStates[player] = {
			selectedTool = "node_demolisher",
			buildMode = false,
			selectedBuildKey = nil,
		}
	end
	return playerStates[player]
end

local function getNearbyNode(player, maxDistance)
	local character = player.Character
	if not character then return nil end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	
	local playerPos = hrp.Position
	local nearestNode = nil
	local nearestDist = maxDistance or 20
	
	-- Check Nodes folder
	local nodes = workspace:FindFirstChild("Nodes")
	if nodes then
		for _, node in ipairs(nodes:GetChildren()) do
			if node:IsA("BasePart") or node:IsA("Model") then
				local nodePos = node:IsA("Model") and node:GetPivot().Position or node.Position
				local dist = (playerPos - nodePos).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					nearestNode = node
				end
			end
			end
	end
	
	-- Check Flora folder for harvestable objects
	local flora = workspace:FindFirstChild("Flora")
	if flora then
		for _, plant in ipairs(flora:GetChildren()) do
			if plant:IsA("BasePart") then
				local dist = (playerPos - plant.Position).Magnitude
				if dist < nearestDist then
					-- Check if it's a harvestable node type
					local nodeType = plant:GetAttribute("NodeType") or plant.Name:lower()
					if HarvestConfig.getObstacleDef(nodeType) then
						nearestDist = dist
						nearestNode = plant
					end
				end
			end
			end
	end
	
	return nearestNode, nearestDist
end

local function getNearbyBerryBush(player, maxDistance)
	local character = player.Character
	if not character then return nil end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	
	local playerPos = hrp.Position
	local nearestBush = nil
	local nearestDist = maxDistance or 20
	
	local flora = workspace:FindFirstChild("Flora")
	if flora then
		for _, plant in ipairs(flora:GetChildren()) do
			if plant:IsA("BasePart") and plant.Name:find("BerryBush") then
				local dist = (playerPos - plant.Position).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					nearestBush = plant
				end
			end
		end
	end
	
	return nearestBush, nearestDist
end

local function harvestNode(player, node)
	if not node then return false, "no_target" end
	
	local nodeType = node:GetAttribute("NodeType") or node.Name:lower()
	local obstacleDef = HarvestConfig.getObstacleDef(nodeType)
	if not obstacleDef then return false, "invalid_node_type" end
	
	-- Get drop info
	local dropKey = obstacleDef.dropKey
	local dropAmount = obstacleDef.dropAmount or 1
	
	-- Add material to player
	local currentAmount = player:GetAttribute("Mat_" .. dropKey) or 0
	player:SetAttribute("Mat_" .. dropKey, currentAmount + dropAmount)
	
	-- Reduce durability or destroy
	local durability = node:GetAttribute("Durability") or obstacleDef.defaultDurability or 1
	durability = durability - 1
	if durability <= 0 then
		node:Destroy()
	else
		node:SetAttribute("Durability", durability)
	end
	
	return true, { dropKey = dropKey, amount = dropAmount }
end

local function plantBerry(player, bush, berryKey)
	if not bush then return false, "no_target" end
	
	local toolDef = HarvestConfig.getToolDef("berry_planter")
	if not toolDef or not toolDef.allowedBerryKinds[berryKey] then
		return false, "invalid_berry_type"
	end
	
	-- Check if player has the berry
	local currentAmount = player:GetAttribute("Mat_" .. berryKey) or 0
	if currentAmount < 1 then
		return false, "insufficient_berries"
	end
	
	-- Consume berry
	player:SetAttribute("Mat_" .. berryKey, currentAmount - 1)
	
	-- Update bush (for now, just change its name/appearance)
	bush.Name = "BerryBush_" .. berryKey
	
	return true, { berryKey = berryKey }
end

local function handleUseTool(player, toolKey)
	local state = getPlayerState(player)
	local toolDef = HarvestConfig.getToolDef(toolKey)
	if not toolDef then return false, "invalid_tool" end
	
	if toolDef.mode == "destroy" then
		-- Demolisher - harvest nodes
		local node, dist = getNearbyNode(player, 20)
		if not node then return false, "no_node_in_range" end
		
		-- Check if node type is allowed
		local nodeType = node:GetAttribute("NodeType") or node.Name:lower()
		if not toolDef.allowedNodeTypes[nodeType] then
			return false, "node_type_not_allowed"
		end
		
		return harvestNode(player, node)
		
	elseif toolDef.mode == "gather_tool" then
		-- Planter - interact with berry bushes
		local bush, dist = getNearbyBerryBush(player, 20)
		if not bush then return false, "no_bush_in_range" end
		
		-- For now, just harvest berries from the bush
		local berryType = bush.Name:match("BerryBush_(.+)") or "berry_red"
		local currentAmount = player:GetAttribute("Mat_" .. berryType) or 0
		player:SetAttribute("Mat_" .. berryType, currentAmount + 1)
		
		return true, { berryKey = berryType, amount = 1 }
	end
	
	return false, "unknown_tool_mode"
end

local function handleBuild(player, buildKey, position, yGround, rotationY)
	local def = PlacementRules.getBuildDef(buildKey)
	if not def then return false, "invalid_buildable" end
	
	-- Check materials
	for matKey, amt in pairs(def.cost or {}) do
		local current = player:GetAttribute("Mat_" .. matKey) or 0
		if current < amt then
			return false, "insufficient_materials"
		end
	end
	
	-- Consume materials
	for matKey, amt in pairs(def.cost or {}) do
		local current = player:GetAttribute("Mat_" .. matKey) or 0
		player:SetAttribute("Mat_" .. matKey, current - amt)
	end
	
	-- Create buildable (placeholder - in a real game this would create the actual object)
	-- For now, just return success
	return true, { buildKey = buildKey, position = position }
end

local function handleContextAction(player, payload)
	local action = payload.action
	
	if action == "useTool" then
		local toolKey = payload.tool
		if not toolKey then return false, "no_tool_specified" end
		return handleUseTool(player, toolKey)
		
	elseif action == "build" then
		return handleBuild(player, payload.buildKey, payload.position, payload.yGround, payload.rotationY)
		
	elseif action == "plantShrub" then
		local bush = getNearbyBerryBush(player, 20)
		return plantBerry(player, bush, payload.berryKey)
		
	elseif action == "context" then
		-- Generic context action - use currently selected tool
		local state = getPlayerState(player)
		if state.selectedTool then
			return handleUseTool(player, state.selectedTool)
		end
		return false, "no_tool_selected"
	end
	
	return false, "unknown_action"
end

-- Handle tool selection updates from client
local function handleToolSelection(player, toolKey)
	local state = getPlayerState(player)
	state.selectedTool = toolKey
	state.buildMode = false
end

requestContextAction.OnServerEvent:Connect(function(player, payload)
	if type(payload) ~= "table" then return end
	
	-- Handle tool selection updates
	if payload.updateTool then
		handleToolSelection(player, payload.updateTool)
		return
	end
	
	local success, result = handleContextAction(player, payload)
	-- Could send result back to client if needed
end)

Players.PlayerRemoving:Connect(function(player)
	playerStates[player] = nil
end)

print("ContextActionHandler initialized")
