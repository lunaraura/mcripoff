local HarvestService = {}
HarvestService.__index = HarvestService
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ecology = Shared:WaitForChild("Ecology")
local EcologyRules = require(Ecology:WaitForChild("EcologyRules"))
local FloraSystem = require(script.Parent.Parent.Systems.FloraSystem)

function HarvestService.new(worldService, inventoryService)
	return setmetatable({ worldService = worldService, inventoryService = inventoryService }, HarvestService)
end

function HarvestService:configure(playerDataService, creatureService, morphService)
	self.playerDataService = playerDataService
	self.creatureService = creatureService
	self.morphService = morphService
	self:bindBerryBushPrompts()
	self:bindHarvestNodePrompts()
end

function HarvestService:bindBerryBushPrompts()
	if self._berryPromptBound then return end
	self._berryPromptBound = true
	local function hookBush(bush)
		if not bush or not bush:IsA("BasePart") then return end
		local prompt = bush:FindFirstChildOfClass("ProximityPrompt")
		if not prompt then return end
		if prompt:GetAttribute("BoundHarvest") then return end
		prompt:SetAttribute("BoundHarvest", true)
		prompt.Triggered:Connect(function(player)
			self:tryHarvestBerryBushInstance(player, bush)
		end)
	end
	for _, bush in ipairs(CollectionService:GetTagged("BerryBush")) do
		hookBush(bush)
	end
	CollectionService:GetInstanceAddedSignal("BerryBush"):Connect(hookBush)
end

function HarvestService:tryHarvestBerryBushInstance(player, bush)
	if not bush or not bush.Parent then return false, "missing bush" end
	local uses = math.max(0, tonumber(bush:GetAttribute("Uses")) or 0)
	if uses <= 0 then return false, "empty bush" end
	local kind = tostring(bush:GetAttribute("BerryKind") or "berry_red")
	local granted = self.inventoryService:grant(player, { { key = kind, amount = 1 } })
	bush:SetAttribute("Uses", uses - 1)
	if bush.Size.X > 3 then
		bush.Size -= Vector3.new(0.4, 0.4, 0.4)
		bush.CFrame += Vector3.new(0, -0.2, 0)
	end
	self.worldService:pushEventLog(player, string.format("Picked %s", kind), "#d7fcb7")
	if uses - 1 <= 0 then
		bush:Destroy()
	end
	return true, granted
end

function HarvestService:tryHarvestNearbyBerryBush(player, radius)
	local root = player.Character and player.Character.PrimaryPart
	if not root then return false, "no character" end
	local best, bestD = nil, radius or 14
	for _, bush in ipairs(CollectionService:GetTagged("BerryBush")) do
		if bush:IsA("BasePart") and bush.Parent then
			local d = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(bush.Position.X, 0, bush.Position.Z)).Magnitude
			if d < bestD then
				best, bestD = bush, d
			end
		end
	end
	if not best then return false, "no berry bush nearby" end
	return self:tryHarvestBerryBushInstance(player, best)
end

function HarvestService:bindHarvestNodePrompts()
	if self._nodePromptBound then return end
	self._nodePromptBound = true
	local function hookNode(node)
		if not node or not node:IsA("BasePart") then return end
		local prompt = node:FindFirstChildOfClass("ProximityPrompt")
		if not prompt then return end
		if prompt:GetAttribute("BoundNodeHarvest") then return end
		prompt:SetAttribute("BoundNodeHarvest", true)
		prompt.Triggered:Connect(function(player)
			self:tryHarvestNodeInstance(player, node, { source = "prompt" })
		end)
	end
	for _, node in ipairs(CollectionService:GetTagged("HarvestNode")) do
		hookNode(node)
	end
	CollectionService:GetInstanceAddedSignal("HarvestNode"):Connect(hookNode)
end

function HarvestService:tryHarvestNodeInstance(player, node, opts)
	opts = opts or {}
	if tostring(opts.toolKey or "") ~= "node_demolisher" then
		self.worldService:pushEventLog(player, "Need Node Demolisher tool to harvest nodes", "#ffb3b3")
		return false, "tool_required_node_demolisher"
	end
	if not node or not node.Parent then return false, "missing node" end
	if node:GetAttribute("Depleted") then
		return false, "depleted node"
	end
	local durability = math.max(0, tonumber(node:GetAttribute("Durability")) or 1)
	if durability <= 0 then return false, "depleted node" end
	durability -= 1
	node:SetAttribute("Durability", durability)
	self.worldService:pushFloatingText(node.Position, tostring(math.max(0, durability)), "#d7fcb7")
	if durability > 0 then
		return true, { progress = true, durability = durability }
	end
	local dropKey = tostring(node:GetAttribute("DropKey") or "stone")
	local dropAmount = math.max(1, math.floor(tonumber(node:GetAttribute("DropAmount")) or 1))
	local granted = self.inventoryService:grant(player, { { key = dropKey, amount = dropAmount } })
	self.worldService:pushEventLog(player, string.format("Harvested %s node", tostring(node:GetAttribute("NodeType") or "resource")), "#d7fcb7")
	self:depleteNode(node)
	return true, granted
end

function HarvestService:tryHarvestNearbyNode(player, radius)
	local root = player.Character and player.Character.PrimaryPart
	if not root then return false, "no character" end
	local best, bestD = nil, radius or 14
	for _, node in ipairs(CollectionService:GetTagged("HarvestNode")) do
		if node:IsA("BasePart") and node.Parent then
			local d = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(node.Position.X, 0, node.Position.Z)).Magnitude
			if d < bestD then
				best, bestD = node, d
			end
		end
	end
	if not best then return false, "no node nearby" end
	return self:tryHarvestNodeInstance(player, best, { source = "nearby" })
end

function HarvestService:ensureFloraFolder()
	local flora = Workspace:FindFirstChild("Flora")
	if not flora then
		flora = Instance.new("Folder")
		flora.Name = "Flora"
		flora.Parent = Workspace
	end
	return flora
end

function HarvestService:tryUseDemolishHarvestTool(player, payload)
	payload = payload or {}
	local root = player.Character and player.Character.PrimaryPart
	if not root then return false, "no character" end
	local radius = tonumber(payload.radius) or 12
	local best, bestD = nil, radius
	for _, node in ipairs(CollectionService:GetTagged("HarvestNode")) do
		if node:IsA("BasePart") and node.Parent then
			local d = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(node.Position.X, 0, node.Position.Z)).Magnitude
			if d < bestD then
				best, bestD = node, d
			end
		end
	end
	if not best then return false, "no non-berry node nearby" end
	return self:tryHarvestNodeInstance(player, best, { source = "tool", toolKey = "node_demolisher" })
end

function HarvestService:setNodeVisualActive(node, active)
	local list = { node }
	for _, d in ipairs(node:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	for _, p in ipairs(list) do
		if p:IsA("BasePart") and p:GetAttribute("NodeVisualPart") then
			p.Transparency = active and 0 or 1
			local restoreCanCollide = p:GetAttribute("RestoreCanCollide")
			if active then
				p.CanCollide = restoreCanCollide == true
			else
				p.CanCollide = false
			end
		end
	end
	local prompt = node:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = active
	end
end

function HarvestService:depleteNode(node)
	local nodeType = tostring(node:GetAttribute("NodeType") or "Unknown")
	local nodeSource = tostring(node:GetAttribute("NodeSource") or "natural")
	local lifecycleClass = tostring(node:GetAttribute("NodeLifecycleClass") or EcologyRules.classifyNodeLifecycle(nodeType, nodeSource))
	local policy = EcologyRules.getNodeLifecyclePolicy(lifecycleClass)
	local respawnPolicy = tostring(policy.respawnPolicy or "none")
	local ecoId = tostring(node:GetAttribute("EcologyId") or "")

	node:SetAttribute("NodeLifecycleClass", lifecycleClass)
	node:SetAttribute("NodeRespawnPolicy", respawnPolicy)
	node:SetAttribute("NodePlayerGrowable", policy.playerGrowable == true)
	node:SetAttribute("NodeHarvestable", policy.harvestable ~= false)
	node:SetAttribute("NodeNonRespawning", respawnPolicy == "none")
	node:SetAttribute("Depleted", true)
	node:SetAttribute("DepletedAt", self.worldService.time)
	node:SetAttribute("Durability", 0)
	node:SetAttribute("DepletedUntil", 0)
	self:setNodeVisualActive(node, false)
	if respawnPolicy == "none" then
		if nodeSource == "natural" and ecoId ~= "" then
			FloraSystem.markNaturalNodeDepleted(ecoId)
		end
		node:SetAttribute("RemovedFromEcologyRuntime", true)
	else
		node:SetAttribute("RemovedFromEcologyRuntime", false)
	end
end

function HarvestService:tickNodeRegrowth()
	for _, node in ipairs(CollectionService:GetTagged("HarvestNode")) do
		if node:IsA("BasePart") and node.Parent and node:GetAttribute("Depleted") then
			local respawnPolicy = tostring(node:GetAttribute("NodeRespawnPolicy") or "none")
			local playerGrowable = node:GetAttribute("NodePlayerGrowable") == true
			local timerEnabled = node:GetAttribute("NodeAllowTimerRegrowth") == true
			if respawnPolicy ~= "timer" or (not playerGrowable) or (not timerEnabled) then
				continue
			end
			local untilT = tonumber(node:GetAttribute("DepletedUntil")) or 0
			if self.worldService.time >= untilT then
				local maxDur = math.max(1, math.floor(tonumber(node:GetAttribute("MaxDurability")) or 1))
				node:SetAttribute("Depleted", false)
				node:SetAttribute("Durability", maxDur)
				node:SetAttribute("DepletedUntil", 0)
				node:SetAttribute("RemovedFromEcologyRuntime", false)
				self:setNodeVisualActive(node, true)
			end
		end
	end
end

function HarvestService:tryUseBerryPlanterTool(player, payload)
	payload = payload or {}
	local root = player.Character and player.Character.PrimaryPart
	if not root then return false, "no character" end
	local berryKind = tostring(payload.kind or "berry_red")
	local allowed = {
		berry_red = true,
		berry_yellow = true,
		berry_blue = true,
		revive_berry = true,
		replenish_berry = true,
	}
	if not allowed[berryKind] then
		return false, "invalid berry kind"
	end
	if self.inventoryService:getCount(player, berryKind) <= 0 then
		return false, "missing berry seed item"
	end
	local placePos = root.Position + root.CFrame.LookVector * 8
	local minDistance = 9
	for _, bush in ipairs(CollectionService:GetTagged("BerryBush")) do
		if bush:IsA("BasePart") and bush.Parent then
			local d = (Vector3.new(placePos.X, 0, placePos.Z) - Vector3.new(bush.Position.X, 0, bush.Position.Z)).Magnitude
			if d < minDistance then
				return false, "too close to existing bush"
			end
		end
	end
	local bush = Instance.new("Part")
	bush.Name = "BerryBush_" .. berryKind .. "_Planted"
	bush.Shape = Enum.PartType.Ball
	bush.Anchored, bush.CanCollide = true, false
	bush.Material = Enum.Material.Grass
	bush.Color = Color3.fromRGB(170, 85, 85)
	bush.Size = Vector3.new(4.4, 4.4, 4.4)
	bush.CFrame = CFrame.new(placePos.X, root.Position.Y + 1.6, placePos.Z)
	bush.Parent = self:ensureFloraFolder()
	bush:SetAttribute("BerryKind", berryKind)
	bush:SetAttribute("Uses", 3)
	bush:SetAttribute("PlantedByUserId", player.UserId)
	bush:SetAttribute("NodeSource", "player")
	bush:SetAttribute("NodeLifecycleClass", "player_growable")
	bush:SetAttribute("NodeRespawnPolicy", "player_driven")
	bush:SetAttribute("NodePlayerGrowable", true)
	bush:SetAttribute("NodeHarvestable", true)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick Berry"
	prompt.ObjectText = "Berry Bush"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = bush
	CollectionService:AddTag(bush, "BerryBush")
	self.inventoryService:tryConsume(player, berryKind, 1)
	self.worldService:pushEventLog(player, string.format("Planted %s bush", berryKind), "#a8ffd7")
	return true, { planted = true, kind = berryKind }
end

function HarvestService:tryUseTool(player, payload)
	payload = payload or {}
	local toolKey = tostring(payload.tool or "")
	if toolKey == "node_demolisher" then
		return self:tryUseDemolishHarvestTool(player, payload)
	elseif toolKey == "berry_planter" then
		return self:tryUseBerryPlanterTool(player, payload)
	end
	return false, "unknown tool"
end

function HarvestService:tryHarvestCreature(player, targetId)
	local c = self.worldService:getCreatureById(targetId)
	if not c then
		return false, "invalid target"
	end
	if not c.alive then
		if c._harvested then
			return false, "already harvested"
		end
		local rewards = c.drop or {}
		if #rewards <= 0 then
			return false, "nothing to harvest"
		end
		local granted = self.inventoryService:grant(player, rewards)
		self.worldService:pushEventLog(player, string.format("Harvested defeated %s", c.speciesKey), "#ffd9a8")
		c._harvested = true
		self.worldService:removeCreature(c.id)
		return true, granted
	end
	if c.role ~= "passive" then
		return false, "invalid target"
	end
	if self.worldService.time < (c.nextHarvestAt or 0) then
		return false, "cooldown"
	end
	local granted = self.inventoryService:grant(player, c.harvestDrop)
	if c.speciesKey == "sheeplet" then
		local berryKinds = { "berry_red", "berry_yellow", "berry_blue" }
		local berryKey = berryKinds[math.random(1, #berryKinds)]
		local berryGrant = self.inventoryService:grant(player, { { key = berryKey, amount = 1 } })
		for _, item in ipairs(berryGrant) do
			table.insert(granted, item)
		end
	end
	c.nextHarvestAt = self.worldService.time + (c.harvestCooldown or 0)
	self.worldService:pushFloatingText(c.pos, "Harvested", "#d7fcb7")
	self.worldService:pushEventLog(player, string.format("Harvested %s", c.speciesKey), "#d7fcb7")
	return true, granted
end

function HarvestService:tryHarvestNearestPassive(player, radius)
	local root = player.Character and player.Character.PrimaryPart
	if not root then
		return false, "no character"
	end
	local best, bestD = nil, radius or 14
	for _, c in ipairs(self.worldService.creatures) do
		if c.alive and c.role == "passive" then
			local d = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(c.pos.X, 0, c.pos.Z)).Magnitude
			if d < bestD then
				best, bestD = c, d
			end
		end
	end
	if not best then
		return false, "no passive nearby"
	end
	return self:tryHarvestCreature(player, best.id)
end

function HarvestService:tryTameDefeated(player, targetId)
	if not self.playerDataService then
		return false, "player data unavailable"
	end
	local c = self.worldService:getCreatureById(targetId)
	if not c or c.alive or c.mode ~= "wild" then
		return false, "invalid tame target"
	end
	local hasBait = self.inventoryService:getCount(player, "lure_meat") > 0
	if not hasBait then
		return false, "need lure_meat"
	end
	self.inventoryService:tryConsume(player, "lure_meat", 1)
	local owned, destination, slotOrIndex = self.playerDataService:addOwnedFromRuntime(player, c)
	if not owned then
		return false, "failed to add owned creature"
	end
	if self.morphService then
		self.morphService:awardPoints(player, owned.ownedId, 2)
	end
	self.worldService:removeCreature(c.id)
	if destination == "party" and self.creatureService then
		self.creatureService:respawnPartyFromOwned(player)
	end
	local whereToken = destination == "party" and ("slot " .. tostring(slotOrIndex or "?")) or ("reserve " .. tostring(slotOrIndex or "?"))
	self.worldService:pushEventLog(player, string.format("Captured %s Lv.%d -> %s", c.speciesKey, owned.level or 1, whereToken), "#a8ffd7")
	return true, { ownedId = owned.ownedId, destination = destination, slotOrIndex = slotOrIndex }
end

function HarvestService:tryTameNearestDefeated(player, radius)
	local root = player.Character and player.Character.PrimaryPart
	if not root then
		return false, "no character"
	end
	local best, bestD = nil, radius or 16
	for _, c in ipairs(self.worldService.creatures) do
		if (not c.alive) and c.mode == "wild" then
			local d = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(c.pos.X, 0, c.pos.Z)).Magnitude
			if d < bestD then
				best = c
				bestD = d
			end
		end
	end
	if not best then
		return false, "no tame target nearby"
	end
	return self:tryTameDefeated(player, best.id)
end

return HarvestService
