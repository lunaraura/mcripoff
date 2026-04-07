local HarvestService = {}
HarvestService.__index = HarvestService
local CollectionService = game:GetService("CollectionService")

function HarvestService.new(worldService, inventoryService)
	return setmetatable({ worldService = worldService, inventoryService = inventoryService }, HarvestService)
end

function HarvestService:configure(playerDataService, creatureService, morphService)
	self.playerDataService = playerDataService
	self.creatureService = creatureService
	self.morphService = morphService
	self:bindBerryBushPrompts()
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
	local owned, destination = self.playerDataService:addOwnedCreature(player, c.speciesKey)
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
	self.worldService:pushEventLog(player, string.format("Tamed %s -> %s", c.speciesKey, destination), "#a8ffd7")
	return true, { ownedId = owned.ownedId, destination = destination }
end

return HarvestService
