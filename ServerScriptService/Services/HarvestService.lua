local HarvestService = {}
HarvestService.__index = HarvestService

local function scaleRewards(rewards, mult)
	local out = {}
	for _, reward in ipairs(rewards or {}) do
		local entry = table.clone(reward)
		if entry.amount then
			entry.amount = math.max(1, math.floor((tonumber(entry.amount) or 1) * (tonumber(mult) or 1) + 0.5))
		end
		table.insert(out, entry)
	end
	return out
end
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ecology = Shared:WaitForChild("Ecology")
local EcologyRules = require(Ecology:WaitForChild("EcologyRules"))
local Config = Shared:WaitForChild("Config")
local HarvestConfig = require(Config:WaitForChild("HarvestConfig"))
local FloraSystem = require(script.Parent.Parent.Systems.FloraSystem)
local DEFEATED_WILD_TIMEOUT_SECONDS = 60

function HarvestService.new(worldService, inventoryService)
	return setmetatable({ worldService = worldService, inventoryService = inventoryService }, HarvestService)
end

function HarvestService:isDefeatedWildTarget(creature)
	return creature
		and creature.mode == "wild"
		and creature.lifecycle == "defeated"
		and creature.alive ~= true
		and creature.defeatedOutcome == nil
		and (tonumber(creature.defeatedExpiresAt) or -1) > self.worldService.time
end

function HarvestService:ensureDefeatedWindow(creature)
	if not creature or creature.mode ~= "wild" or creature.alive == true then return end
	local now = self.worldService.time
	creature.lifecycle = "defeated"
	creature.defeatedAt = tonumber(creature.defeatedAt) or now
	creature.defeatedExpiresAt = tonumber(creature.defeatedExpiresAt) or (creature.defeatedAt + DEFEATED_WILD_TIMEOUT_SECONDS)
end

function HarvestService:hasToolInInventory(player, toolKey)
	if not player or not toolKey then return false end
	-- Backward-compat: if tool keys are not tracked as inventory materials yet, treat as available.
	local count = self.inventoryService:getCount(player, toolKey)
	if count == nil then
		return true
	end
	return (tonumber(count) or 0) > 0
end

function HarvestService:resolveToolForNode(player, requestedToolKey, nodeTypeKey)
	local toolKey = tostring(requestedToolKey or "")
	local toolDef = HarvestConfig.getToolDef(toolKey)
	if toolDef and toolDef.mode == "destroy" and (not toolDef.allowedNodeTypes or toolDef.allowedNodeTypes[nodeTypeKey]) then
		return toolKey, toolDef
	end
	for key, def in pairs(HarvestConfig.toolDefs or {}) do
		if def.mode == "destroy" and (not def.allowedNodeTypes or def.allowedNodeTypes[nodeTypeKey]) and self:hasToolInInventory(player, key) then
			return key, def
		end
	end
	return nil, nil
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
	if not node or not node.Parent then return false, "missing node" end
	if node:GetAttribute("Depleted") then
		return false, "depleted node"
	end
	local nodeType = tostring(node:GetAttribute("NodeType") or "resource")
	local nodeDef = HarvestConfig.getObstacleDef(nodeType)
	local nodeTypeKey = string.lower(nodeType)
	local toolKey, toolDef = self:resolveToolForNode(player, opts.toolKey, nodeTypeKey)
	if not toolDef then
		self.worldService:pushEventLog(player, "Missing required harvesting tool in inventory", "#ffb3b3")
		return false, "tool_required_in_inventory"
	end
	if toolDef.allowedNodeTypes and not toolDef.allowedNodeTypes[nodeTypeKey] then
		return false, "tool_cannot_harvest_node_type"
	end
	local durability = math.max(0, tonumber(node:GetAttribute("Durability")) or (nodeDef and nodeDef.defaultDurability) or 1)
	if durability <= 0 then return false, "depleted node" end
	durability -= 1
	node:SetAttribute("Durability", durability)
	self.worldService:pushFloatingText(node.Position, tostring(math.max(0, durability)), "#d7fcb7")
	if durability > 0 then
		return true, { progress = true, durability = durability }
	end
	local dropKey = tostring(node:GetAttribute("DropKey") or (nodeDef and nodeDef.dropKey) or "stone")
	local dropAmount = math.max(1, math.floor(tonumber(node:GetAttribute("DropAmount")) or (nodeDef and nodeDef.dropAmount) or 1))
	local granted = self.inventoryService:grant(player, { { key = dropKey, amount = dropAmount } })
	self.worldService:pushEventLog(player, string.format("Harvested %s node", (nodeDef and nodeDef.label) or nodeType), "#d7fcb7")
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
	local planterDef = HarvestConfig.getToolDef("berry_planter")
	local allowed = planterDef and planterDef.allowedBerryKinds or {}
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
	local toolDef = HarvestConfig.getToolDef(toolKey)
	if not toolDef then
		return false, "unknown tool"
	end
	if not self:hasToolInInventory(player, toolKey) then
		return false, "tool_missing_inventory"
	end
	if toolKey == "node_demolisher" then
		return self:tryUseDemolishHarvestTool(player, payload)
	elseif toolKey == "berry_planter" then
		return self:tryUseBerryPlanterTool(player, payload)
	end
	return false, "tool_mode_not_implemented"
end

function HarvestService:tryHarvestCreature(player, targetId)
	local c = self.worldService:getCreatureById(targetId)
	if not c then
		return false, "invalid target"
	end
	if not c.alive then
		self:ensureDefeatedWindow(c)
		if not self:isDefeatedWildTarget(c) then
			if c.defeatedOutcome == "harvest" then
				return false, "already harvested"
			end
			if c.defeatedOutcome == "tame" then
				return false, "already tamed"
			end
			if (tonumber(c.defeatedExpiresAt) or 0) <= self.worldService.time then
				return false, "target expired"
			end
			return false, "invalid target"
		end
		local rewards = c.drop or {}
		local rewardMult = c.wildProfile and tonumber(c.wildProfile.rewardMult) or 1
		if rewardMult > 1 then
			rewards = scaleRewards(rewards, rewardMult)
		end
		if #rewards <= 0 then
			return false, "nothing to harvest"
		end
		c.defeatedOutcome = "claiming"
		c.defeatedInteractedBy = player.UserId
		local granted = self.inventoryService:grant(player, rewards)
		if not granted then
			c.defeatedOutcome = nil
			c.defeatedInteractedBy = nil
			return false, "harvest_failed"
		end
		self.worldService:pushEventLog(player, string.format("Harvested defeated %s", c.speciesKey), "#ffd9a8")
		c.defeatedOutcome = "harvest"
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
		local berryKinds = { "berry_red", "berry_yellow", "berry_blue", "lure_berry" }
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
	if not c then
		return false, "target already despawned"
	end
	self:ensureDefeatedWindow(c)
	if c.alive or c.mode ~= "wild" then
		return false, "target not defeated"
	end
	if (tonumber(c.defeatedExpiresAt) or 0) <= self.worldService.time then
		return false, "target expired"
	end
	if c.defeatedOutcome == "harvest" then
		return false, "target already harvested"
	end
	if c.defeatedOutcome == "tame" then
		return false, "target already claimed"
	end
	if c.defeatedOutcome ~= nil then
		return false, "target busy"
	end
	c.defeatedOutcome = "claiming"
	c.defeatedInteractedBy = player.UserId
	local hasBait = self.inventoryService:getCount(player, "lure_berry") > 0
	if not hasBait then
		c.defeatedOutcome = nil
		c.defeatedInteractedBy = nil
		return false, "need lure_berry"
	end
	local consumed = self.inventoryService:tryConsume(player, "lure_berry", 1)
	if not consumed then
		c.defeatedOutcome = nil
		c.defeatedInteractedBy = nil
		return false, "need lure_berry"
	end
	local owned, destination, slotOrIndex = self.playerDataService:addOwnedFromRuntime(player, c)
	if not owned then
		self.inventoryService:grant(player, { { key = "lure_berry", amount = 1 } })
		c.defeatedOutcome = nil
		c.defeatedInteractedBy = nil
		return false, "failed to add owned creature"
	end
	if self.morphService then
		local bonus = c.wildProfile and tonumber(c.wildProfile.morphPointBonus) or 0
		self.morphService:awardPoints(player, owned.ownedId, 2 + bonus)
	end
	c.defeatedOutcome = "tame"
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
		if self:isDefeatedWildTarget(c) then
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

function HarvestService:tickDefeatedWilds()
	local now = self.worldService.time
	local expiredIds = {}
	for _, c in ipairs(self.worldService.creatures) do
		if c.mode == "wild" and c.alive ~= true and c.lifecycle == "defeated" then
			self:ensureDefeatedWindow(c)
			if c.defeatedOutcome == nil and now >= (tonumber(c.defeatedExpiresAt) or 0) then
				c.defeatedOutcome = "expired"
				table.insert(expiredIds, c.id)
			end
		end
	end
	for _, id in ipairs(expiredIds) do
		self.worldService:removeCreature(id)
	end
end

return HarvestService
