local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local Services = SSS:WaitForChild("Services")
local Systems = SSS:WaitForChild("Systems")
local Runtime = SSS:WaitForChild("Runtime")

local function ensureRemote(name)
	local folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
	local evt = folder:FindFirstChild(name)
	if not evt then
		evt = Instance.new("RemoteEvent")
		evt.Name = name
		evt.Parent = folder
	end
	return evt
end

local remotes = {
	RequestPetCommand = ensureRemote("RequestPetCommand"),
	RequestContextAction = ensureRemote("RequestContextAction"),
	RequestManualCast = ensureRemote("RequestManualCast"),
	RequestStarterChoice = ensureRemote("RequestStarterChoice"),
	RequestClientOption = ensureRemote("RequestClientOption"),
	UseBerry = ensureRemote("UseBerry"),
	FloatingTextEvent = ensureRemote("FloatingTextEvent"),
	EventLogEvent = ensureRemote("EventLogEvent"),
	PetHudUpdate = ensureRemote("PetHudUpdate"),
}

local WorldService = require(Services:WaitForChild("WorldService"))
local CreatureService = require(Services:WaitForChild("CreatureService"))
local CombatService = require(Services:WaitForChild("CombatService"))
local AIService = require(Services:WaitForChild("AIService"))
local SpawnService = require(Services:WaitForChild("SpawnService"))
local EffectService = require(Services:WaitForChild("EffectService"))
local HarvestService = require(Services:WaitForChild("HarvestService"))
local InventoryService = require(Services:WaitForChild("InventoryService"))
local BuildService = require(Services:WaitForChild("BuildService"))
local MorphService = require(Services:WaitForChild("MorphService"))
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local BerryService = require(Services:WaitForChild("BerryService"))

local playerDataService = PlayerDataService.new()
local worldService = WorldService.new(remotes)
local inventoryService = InventoryService.new(playerDataService)
local creatureService = CreatureService.new(worldService, playerDataService)
local combatService = CombatService.new(worldService)
local aiService = AIService.new(worldService)
local spawnService = SpawnService.new(worldService, creatureService)
local effectService = EffectService.new()
local harvestService = HarvestService.new(worldService, inventoryService)
local buildService = BuildService.new(worldService, inventoryService)
local morphService = MorphService.new(playerDataService, creatureService)
local berryService = BerryService.new(worldService, inventoryService, creatureService, playerDataService)
harvestService:configure(playerDataService, creatureService, morphService)
combatService:configureProgression(playerDataService, morphService)
local hudTimer = 0
local hudReplicationCache = {}
local HUD_KEEPALIVE_SECONDS = 1.0

Players.PlayerAdded:Connect(function(player)
	playerDataService:getOrCreate(player)
	player:SetAttribute("RadiusChunks", 2)
	player:SetAttribute("PetLeashDistance", 90)
	player:SetAttribute("PetHoldDefenseRange", 30)
	player.CharacterAdded:Connect(function()
		task.wait(0.3)
		creatureService:HydrateParty(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	hudReplicationCache[player.UserId] = nil
end)

remotes.RequestStarterChoice.OnServerEvent:Connect(function(player, payload)
	payload = payload or {}
	local speciesKey = payload.speciesKey
	local ok = playerDataService:chooseStarter(player, speciesKey)
	if not ok then return end
	creatureService:HydrateParty(player)
	local root = player.Character and player.Character.PrimaryPart
	if root then
		worldService:pushFloatingText(root.Position, "Starter: " .. tostring(speciesKey), "#a8ffd7")
	end
	worldService:pushEventLog(player, "Starter chosen: " .. tostring(speciesKey), "#a8ffd7")
end)

remotes.RequestPetCommand.OnServerEvent:Connect(function(player, payload)
	payload = payload or {}
	local command = payload.command or {}
	local function sanitizeCommand(input)
		if type(input) ~= "table" then return nil end
		local t = input.type
		if t == "follow" or t == "hold" or t == "attackNearest" then
			return { type = t, issuedAt = worldService.time }
		end
		if t == "move" and typeof(input.point) == "Vector3" then
			return { type = "move", point = input.point, issuedAt = worldService.time }
		end
		if t == "attack" and tonumber(input.targetId) then
			return { type = "attack", targetId = tonumber(input.targetId), issuedAt = worldService.time }
		end
		if t == "swapReserve" then
			return { type = "swapReserve", reserveIndex = tonumber(input.reserveIndex) or 1 }
		end
		return nil
	end
	command = sanitizeCommand(command)
	if not command then
		return
	end
	if command.type == "swapReserve" then
		local ok = playerDataService:swapPartyWithReserve(player, payload.slot or 1, command.reserveIndex)
		if ok then
			creatureService:respawnPartyFromOwned(player)
			worldService:pushEventLog(player, "Reserve swapped into slot " .. tostring(payload.slot or 1), "#bfe2ff")
		else
			worldService:pushEventLog(player, "Reserve swap failed", "#ffb3b3")
		end
		return
	end
	for _, c in ipairs(worldService.creatures) do
		if c.ownerUserId == player.UserId and c.partySlot and c.partySlot <= 2 then
			if payload.slot == nil or payload.slot == c.partySlot then
				c.command = command
			end
		end
	end
end)

remotes.RequestManualCast.OnServerEvent:Connect(function(player, payload)
	payload = payload or {}
	local requestedSlot = tonumber(payload.slot)
	if requestedSlot ~= 1 and requestedSlot ~= 2 then
		return
	end
	for _, c in ipairs(worldService.creatures) do
		if c.ownerUserId == player.UserId and c.partySlot == requestedSlot then
			c.intent.abilityKey = payload.abilityKey
			c.intent.targetId = payload.targetId
		end
	end
end)

remotes.RequestContextAction.OnServerEvent:Connect(function(player, payload)
	payload = payload or {}
	local ok = false
	if payload.action == "harvestCreature" and payload.targetId then
		ok = harvestService:tryHarvestCreature(player, payload.targetId)
	elseif payload.action == "tameCreature" and payload.targetId then
		ok = harvestService:tryTameDefeated(player, payload.targetId)
		if not ok then
			worldService:pushEventLog(player, "Tame failed (need lure_meat or valid target)", "#ffb3b3")
			return
		end
	elseif payload.action == "context" or payload.action == "harvest" then
		ok = harvestService:tryHarvestNearbyBerryBush(player, payload.radius or 14)
		if not ok then
			ok = harvestService:tryHarvestNearestPassive(player, payload.radius or 14)
		end
	end
	if not ok then
		buildService:handleContextAction(player, payload)
	end
end)

remotes.UseBerry.OnServerEvent:Connect(function(player, payload)
	payload = payload or {}
	berryService:tryUseBerry(player, payload.kind)
end)

remotes.RequestClientOption.OnServerEvent:Connect(function(player, payload)
	payload = payload or {}
	local key = tostring(payload.key or "")
	local value = tonumber(payload.value)
	if not value then return end
	if key == "RadiusChunks" then
		player:SetAttribute("RadiusChunks", math.clamp(math.floor(value + 0.5), 2, 7))
	elseif key == "PetLeashDistance" then
		player:SetAttribute("PetLeashDistance", math.clamp(value, 35, 160))
	elseif key == "PetHoldDefenseRange" then
		player:SetAttribute("PetHoldDefenseRange", math.clamp(value, 10, 60))
	end
end)

local function summarizeHudPayloadForReplication(petPayload)
	local tokens = {}
	for i = 1, 2 do
		local pet = petPayload[i]
		if not pet then
			tokens[i] = "empty"
		else
			tokens[i] = table.concat({
				tostring(pet.state or "?"),
				tostring(pet.name or pet.species or "?"),
				tostring(math.floor((pet.hp or 0) + 0.5)),
				tostring(math.floor((pet.maxHP or 0) + 0.5)),
				tostring(math.floor((pet.stamina or 0) + 0.5)),
				tostring(math.floor((pet.energy or 0) + 0.5)),
				tostring(pet.command or "-"),
				tostring(pet.targetId or "-"),
			}, "|")
		end
	end
	return table.concat(tokens, "||")
end

local function pushPetHud()
	if not remotes.PetHudUpdate then return end
	for _, player in ipairs(Players:GetPlayers()) do
		local data = playerDataService:getOrCreate(player)
		local petPayload = {}
		for i = 1, 2 do
			local ownedId = data.partySlots[i]
			local owned = ownedId and data.ownedCreatures[ownedId] or nil
			if owned then
				local pet = worldService:getRuntimeCreatureForOwnedId(player.UserId, ownedId)
				local isAlive = pet and pet.alive and not owned.isDefeated
				local cooldowns = {}
				if isAlive then
					for _, moveKey in ipairs(pet.moveset or {}) do
						cooldowns[moveKey] = math.max(0, pet.cooldowns[moveKey] or 0)
					end
				end
				petPayload[i] = {
					species = owned.speciesKey,
					name = owned.nickname,
					level = pet and pet.level or owned.level,
					state = isAlive and "alive" or "defeated",
					hp = isAlive and pet.currentHP or 0,
					maxHP = (isAlive and pet.modifiedStats.maxHP) or (pet and pet.modifiedStats and pet.modifiedStats.maxHP) or 0,
					stamina = isAlive and pet.currentStamina or 0,
					energy = isAlive and pet.currentEnergy or 0,
					command = isAlive and (pet.command and pet.command.type or "auto") or nil,
					targetId = isAlive and (pet.intent and pet.intent.targetId or nil) or nil,
					cooldowns = cooldowns,
				}
			else
				petPayload[i] = nil
			end
		end
		local summary = summarizeHudPayloadForReplication(petPayload)
		local cache = hudReplicationCache[player.UserId]
		local sameAsLast = cache and cache.summary == summary
		local sinceLast = cache and (worldService.time - cache.lastSentAt) or math.huge
		if not sameAsLast or sinceLast >= HUD_KEEPALIVE_SECONDS then
			remotes.PetHudUpdate:FireClient(player, { pets = petPayload, t = worldService.time })
			hudReplicationCache[player.UserId] = { summary = summary, lastSentAt = worldService.time }
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	worldService:stepTime(dt)
	worldService:updateChunksAroundPlayers()
	spawnService:update(dt)
	for _, creature in ipairs(worldService.creatures) do
		if creature.alive then
			effectService:tickCreature(creature, dt)
			aiService:think(creature, dt)
			combatService:tryUseAbility(creature)
			creature:Tick(dt)
			creatureService:updateModel(creature)
		end
	end
	for _, creature in ipairs(worldService.creatures) do
		if (not creature.alive) and creature.mode == "pet" and creature.ownerUserId and creature.ownedId then
			local owner = Players:GetPlayerByUserId(creature.ownerUserId)
			if owner then
				playerDataService:setOwnedDefeated(owner, creature.ownedId, true)
			end
		end
	end
	worldService:removeDead()
	hudTimer += dt
	if hudTimer >= 0.25 then
		hudTimer = 0
		pushPetHud()
	end
	-- TODO: Add nearby-only UI/state replication stream for cooldowns/hp bars.
end)
