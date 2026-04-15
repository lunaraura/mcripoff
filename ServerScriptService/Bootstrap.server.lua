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

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local AbilityConfig = require(Config:WaitForChild("AbilityConfig"))
local ItemConfig = require(Config:WaitForChild("ItemConfig"))
local Items = Shared:WaitForChild("Items")
local ItemUseRules = require(Items:WaitForChild("ItemUseRules"))

local remotes = {	RequestPetCommand = ensureRemote("RequestPetCommand"),
	RequestContextAction = ensureRemote("RequestContextAction"),
	RequestManualCast = ensureRemote("RequestManualCast"),
	RequestStarterChoice = ensureRemote("RequestStarterChoice"),
	RequestClientOption = ensureRemote("RequestClientOption"),
	UseBerry = ensureRemote("UseBerry"),
	FloatingTextEvent = ensureRemote("FloatingTextEvent"),
	EventLogEvent = ensureRemote("EventLogEvent"),
	PetHudUpdate = ensureRemote("PetHudUpdate"),
	ManualCastResult = ensureRemote("ManualCastResult"),
	ItemUseResult = ensureRemote("ItemUseResult"),
	RequestCreatureManage = ensureRemote("RequestCreatureManage"),
	CreatureManageResult = ensureRemote("CreatureManageResult"),
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
local effectService = EffectService.new(worldService)
local combatService = CombatService.new(worldService, effectService)
local aiService = AIService.new(worldService)
local spawnService = SpawnService.new(worldService, creatureService)
local harvestService = HarvestService.new(worldService, inventoryService)
local buildService = BuildService.new(worldService, inventoryService)
local morphService = MorphService.new(playerDataService, creatureService)
local berryService = BerryService.new(worldService, inventoryService, creatureService, playerDataService)
harvestService:configure(playerDataService, creatureService, morphService)
combatService:configureProgression(playerDataService, morphService)
local hudTimer = 0
local hudReplicationCache = {}
local HUD_KEEPALIVE_SECONDS = 1.0
local COMMAND_OVERRIDE_SECONDS = 2.5

local PlayerSpawnService = require(Services:WaitForChild("PlayerSpawnService"))

local playerSpawnService = PlayerSpawnService.new(worldService, {
	spawnX = 0,
	spawnZ = 0,
	fallbackY = 128,
	spawnHeightOffset = 6,
	chunkRadius = 2,
	maxGroundRetries = 30,
	groundRetryDelay = 0.1,
	anchorDuringPlacement = true,
})

playerSpawnService:init()

local function getDesignatedAttrKey(slot)
	return string.format("PetDesignatedTargetSlot%d", tonumber(slot) or 1)
end

local function getPetBySlot(player, slot)
	for _, c in ipairs(worldService.creatures) do
		if c.ownerUserId == player.UserId and c.partySlot == slot and c.mode == "pet" and c.alive then
			return c
		end
	end
	return nil
end

local function findNearestEnemyTarget(sourcePet, preferredRange)
	if not sourcePet then return nil end
	local best, bestDist = nil, math.max(20, tonumber(preferredRange) or 120)
	for _, c in ipairs(worldService.creatures) do
		if c.alive and c.team ~= sourcePet.team then
			local d = (Vector3.new(sourcePet.pos.X, 0, sourcePet.pos.Z) - Vector3.new(c.pos.X, 0, c.pos.Z)).Magnitude
			if d <= bestDist then
				bestDist = d
				best = c
			end
		end
	end
	return best
end

local function setDesignatedTarget(player, slot, targetId)
	local attrKey = getDesignatedAttrKey(slot)
	if targetId then
		player:SetAttribute(attrKey, tonumber(targetId))
	else
		player:SetAttribute(attrKey, nil)
	end
	local activeSlot = tonumber(player:GetAttribute("ActivePetSlot")) or 1
	if tonumber(slot) == activeSlot then
		player:SetAttribute("ActiveDesignatedTargetId", targetId and tonumber(targetId) or nil)
	end
end

local function pushManualCastResult(player, pet, payload)
	payload = payload or {}
	local result = {
		ok = payload.ok == true,
		code = tostring(payload.code or "unknown"),
		slot = pet and pet.partySlot or payload.slot,
		petId = pet and pet.id or nil,
		abilityKey = payload.abilityKey,
		targetId = payload.targetId,
		targetType = payload.targetType,
		targetResolution = payload.targetResolution,
		t = worldService.time,
	}
	if pet then
		if result.ok then
			pet.manualCastState = (result.code == "accepted") and "pending" or "accepted"
		else
			pet.manualCastState = "rejected"
		end
		pet.manualCastNote = result.code
		pet.lastManualCastResult = result
	end
	if remotes.ManualCastResult then
		remotes.ManualCastResult:FireClient(player, result)
	end
end

Players.PlayerAdded:Connect(function(player)
	local data = playerDataService:getOrCreate(player)
	player:SetAttribute("StarterChosen", data.starterChosen == true)
	player:SetAttribute("RadiusChunks", 2)
	player:SetAttribute("PetLeashDistance", 90)
	player:SetAttribute("PetHoldDefenseRange", 30)
	player:SetAttribute("ActivePetSlot", 1)
	player:SetAttribute("PetControlMode", "AUTO")
	player:SetAttribute("PetStance", "FOLLOW")
	player:SetAttribute("ActiveDesignatedTargetId", nil)
	player:SetAttribute("PetDesignatedTargetSlot1", nil)
	player:SetAttribute("PetDesignatedTargetSlot2", nil)
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
	player:SetAttribute("StarterChosen", true)
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
		if t == "follow" then
			return { type = "setStance", stance = "FOLLOW", issuedAt = worldService.time }
		end
		if t == "hold" then
			return { type = "setStance", stance = "HOLD", issuedAt = worldService.time }
		end
		if t == "setStance" and (input.stance == "FOLLOW" or input.stance == "HOLD" or input.stance == "AGGRESSIVE") then
			return { type = "setStance", stance = input.stance, issuedAt = worldService.time }
		end
		if t == "attackNearest" then
			return { type = t, issuedAt = worldService.time }
		end
		if t == "setActive" then
			return { type = "setActive" }
		end
		if t == "setControlMode" and (input.mode == "AUTO" or input.mode == "MANUAL") then
			return { type = "setControlMode", mode = input.mode }
		end
		if t == "move" and typeof(input.point) == "Vector3" then
			return { type = "move", point = input.point, issuedAt = worldService.time }
		end
		if t == "attack" and tonumber(input.targetId) then
			return { type = "attack", targetId = tonumber(input.targetId), issuedAt = worldService.time }
		end
		if t == "designateTarget" and tonumber(input.targetId) then
			return { type = "designateTarget", targetId = tonumber(input.targetId), issuedAt = worldService.time }
		end
		if t == "clearDesignatedTarget" then
			return { type = "clearDesignatedTarget", issuedAt = worldService.time }
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
	if command.type == "setActive" then
		local slot = tonumber(payload.slot)
		if slot == 1 or slot == 2 then
			player:SetAttribute("ActivePetSlot", slot)
			player:SetAttribute("ActiveDesignatedTargetId", tonumber(player:GetAttribute(getDesignatedAttrKey(slot))))
			local pet = getPetBySlot(player, slot)
			if pet then
				local stance = tostring(player:GetAttribute("PetStance") or "FOLLOW")
				local stanceCommandType = (stance == "HOLD" and "hold") or (stance == "AGGRESSIVE" and "aggressive") or "follow"
				pet.commandOverrideUntil = worldService.time + COMMAND_OVERRIDE_SECONDS
				pet.command = { type = stanceCommandType, issuedAt = worldService.time }
			end
		end
		return
	end
	if command.type == "setControlMode" then
		player:SetAttribute("PetControlMode", command.mode)
		worldService:pushEventLog(player, "Control mode: " .. tostring(command.mode), "#bfe2ff")
		return
	end
	if command.type == "setStance" then
		player:SetAttribute("PetStance", command.stance)
		worldService:pushEventLog(player, "Stance: " .. tostring(command.stance), "#bfe2ff")
		return
	end
	for _, c in ipairs(worldService.creatures) do
		if c.ownerUserId == player.UserId and c.partySlot and c.partySlot <= 2 then
			if payload.slot == nil or payload.slot == c.partySlot then
				c.lastReceivedCommandType = tostring(command.type or "-")
				c.lastReceivedCommandTargetId = tonumber(command.targetId)
				c.lastReceivedCommandPoint = command.point and string.format("%.1f,%.1f,%.1f", command.point.X, command.point.Y, command.point.Z) or nil
				c.lastSanitizedCommandType = tostring(command.type or "-")
				c.command = command
				c.commandOverrideUntil = worldService.time + COMMAND_OVERRIDE_SECONDS
				if c.partySlot == (tonumber(payload.slot) or c.partySlot) then
					player:SetAttribute("ActivePetSlot", c.partySlot)
				end
				if command.type == "attack" then
					setDesignatedTarget(player, c.partySlot, command.targetId)
					c.designatedTargetId = command.targetId
				elseif command.type == "designateTarget" then
					setDesignatedTarget(player, c.partySlot, command.targetId)
					c.designatedTargetId = command.targetId
				elseif command.type == "clearDesignatedTarget" then
					setDesignatedTarget(player, c.partySlot, nil)
					c.designatedTargetId = nil
				end
			end
		end
	end
end)



remotes.RequestCreatureManage.OnServerEvent:Connect(function(player, payload)
	payload = payload or {}
	local action = tostring(payload.action or "")
	local ownedId = tonumber(payload.ownedId)
	local ok, reason, indexOrSlot = false, "invalid_action", nil

	if action == "move_to_party" then
		ok, reason, indexOrSlot = playerDataService:moveOwnedToParty(player, ownedId, tonumber(payload.targetSlot))
	elseif action == "move_to_reserve" then
		ok, reason, indexOrSlot = playerDataService:moveOwnedToReserve(player, ownedId)
	elseif action == "swap_party_slots" then
		ok, reason = playerDataService:swapPartySlots(player, tonumber(payload.slotA), tonumber(payload.slotB))
	elseif action == "swap_with_party" then
		ok, reason, indexOrSlot = playerDataService:moveOwnedToParty(player, ownedId, tonumber(payload.targetSlot))
	elseif action == "use_item" then
		ok = berryService:tryUseBerry(player, payload.itemKey, tonumber(payload.targetSlot), ownedId)
		reason = ok and "item_used" or "item_use_failed"
	end

	if action == "move_to_party" or action == "move_to_reserve" or action == "swap_party_slots" or action == "swap_with_party" then
		if ok then
			creatureService:respawnPartyFromOwned(player)
		end
	end
	if ok then
		worldService:pushEventLog(player, string.format("Manage: %s (%s)", action, tostring(reason)), "#bfe2ff")
	else
		worldService:pushEventLog(player, string.format("Manage failed: %s (%s)", action, tostring(reason)), "#ffb3b3")
	end
	if remotes.CreatureManageResult then
		remotes.CreatureManageResult:FireClient(player, {
			ok = ok,
			action = action,
			reason = tostring(reason),
			indexOrSlot = indexOrSlot,
			t = worldService.time,
		})
	end
end)
remotes.RequestManualCast.OnServerEvent:Connect(function(player, payload)
	payload = payload or {}
	local requestedSlot = tonumber(payload.slot)
	if requestedSlot ~= 1 and requestedSlot ~= 2 then
		pushManualCastResult(player, nil, {
			ok = false,
			code = "invalid_slot",
			slot = requestedSlot,
			abilityKey = payload.abilityKey,
			targetId = payload.targetId,
		})
		return
	end
	local pet = getPetBySlot(player, requestedSlot)
	if not pet then
		pushManualCastResult(player, nil, {
			ok = false,
			code = "pet_unavailable",
			slot = requestedSlot,
			abilityKey = payload.abilityKey,
			targetId = payload.targetId,
		})
		return
	end
	local abilityKey = tostring(payload.abilityKey or "")
	if abilityKey == "" then
		pushManualCastResult(player, pet, {
			ok = false,
			code = "missing_ability",
			slot = requestedSlot,
		})
		return
	end
	local requestedTargetId = tonumber(payload.targetId)
	local designatedTargetId = tonumber(player:GetAttribute(getDesignatedAttrKey(requestedSlot)))
	local chosenTargetId = requestedTargetId or designatedTargetId
	local chosenTarget = chosenTargetId and worldService:getCreatureById(chosenTargetId) or nil
	local abilityDef = AbilityConfig[abilityKey]
	local targetType = combatService:getAbilityTargetType(abilityDef)
	if targetType == "enemyTarget" and not chosenTarget then
		local nearest = findNearestEnemyTarget(pet, abilityDef and abilityDef.range)
		if nearest then
			chosenTarget = nearest
			chosenTargetId = nearest.id
		end
	end
	local result = combatService:validateManualCast(pet, abilityKey, chosenTarget)
	if not result.ok then
		pushManualCastResult(player, pet, result)
		worldService:pushEventLog(player, string.format("Manual cast rejected [%s type=%s res=%s]", tostring(result.code), tostring(result.targetType or "-"), tostring(result.targetResolution or "-")), "#ffb3b3")
		return
	end
	pet.manualCastRequest = {
		abilityKey = abilityKey,
		targetId = chosenTarget and chosenTarget.id or nil,
		createdAt = worldService.time,
	}
	pet.manualCastState = "pending"
	pet.manualCastNote = "validated"
	pet.commandOverrideUntil = worldService.time + COMMAND_OVERRIDE_SECONDS
	pet.command = { type = "hold", issuedAt = worldService.time }
	if chosenTarget and chosenTarget.team ~= pet.team then
		setDesignatedTarget(player, requestedSlot, chosenTarget.id)
		pet.designatedTargetId = chosenTarget.id
	end
	pushManualCastResult(player, pet, result)
end)

remotes.RequestContextAction.OnServerEvent:Connect(function(player, payload)
	payload = payload or {}
	local ok = false
	if payload.action == "harvestCreature" and payload.targetId then
		ok = harvestService:tryHarvestCreature(player, payload.targetId)
	elseif payload.action == "useTool" and payload.tool then
		ok = harvestService:tryUseTool(player, payload)
		if not ok then
			worldService:pushEventLog(player, "Tool use failed", "#ffb3b3")
			return
		end
	elseif payload.action == "tameCreature" and payload.targetId then
		ok = harvestService:tryTameDefeated(player, payload.targetId)
		if not ok then
			worldService:pushEventLog(player, "Tame failed (need lure_meat or valid target)", "#ffb3b3")
			return
		end
	elseif payload.action == "plantShrub" then
		ok = buildService:tryPlantShrub(player, payload)
		if not ok then
			worldService:pushEventLog(player, "Plant shrub failed", "#ffb3b3")
			return
		end
	elseif payload.action == "context" or payload.action == "harvest" then
		ok = harvestService:tryTameNearestDefeated(player, payload.radius or 16)
		if not ok then
			ok = harvestService:tryHarvestNearbyBerryBush(player, payload.radius or 14)
		end
		if not ok then
			ok = harvestService:tryHarvestNearbyNode(player, payload.radius or 14)
		end
		if not ok then
			ok = harvestService:tryHarvestNearestPassive(player, payload.radius or 14)
		end
	end
	if not ok then
		local buildOk, buildResult = buildService:handleContextAction(player, payload)
		if not buildOk and payload.action == "build" then
			local reasonCode = (type(buildResult) == "table" and buildResult.reasonCode) or tostring(buildResult)
			worldService:pushEventLog(player, string.format("Build failed [%s]", tostring(reasonCode or "BUILD_UNKNOWN")), "#ffb3b3")
		end
	end
end)

remotes.UseBerry.OnServerEvent:Connect(function(player, payload)
	payload = payload or {}
	local targetSlot = tonumber(payload.targetSlot)
	local targetOwnedId = tonumber(payload.targetOwnedId)
	berryService:tryUseBerry(player, payload.kind, targetSlot, targetOwnedId)
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
		for matKey, amount in pairs(data.materials or {}) do
			player:SetAttribute("Mat_" .. tostring(matKey), tonumber(amount) or 0)
		end
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
					commandTargetId = isAlive and (pet.command and tonumber(pet.command.targetId) or nil) or nil,
					targetId = isAlive and (pet.intent and pet.intent.targetId or nil) or nil,
					designatedTargetId = isAlive and (pet.designatedTargetId or nil) or nil,
					forcedState = isAlive and (pet.debugAI and pet.debugAI.forcedState or nil) or nil,
					commandIgnoreReason = isAlive and (pet.debugAI and pet.debugAI.commandIgnoreReason or nil) or nil,
					manualCastState = isAlive and (pet.manualCastState or "idle") or "idle",
					manualCastCode = isAlive and (pet.lastManualCastResult and pet.lastManualCastResult.code or pet.manualCastNote or "-") or "-",
					commandOverride = isAlive and (worldService.time <= (pet.commandOverrideUntil or 0)) or false,
					cooldowns = cooldowns,
					moveset = table.clone((isAlive and pet.moveset) or (owned.moveset) or {}),
				}
			else
				petPayload[i] = nil
			end
		end

		local function buildManagedCreatureEntry(ownedId, location, slotOrIndex)
			if not ownedId then return nil end
			local owned = data.ownedCreatures[ownedId]
			if not owned then return nil end
			local runtime = worldService:getRuntimeCreatureForOwnedId(player.UserId, ownedId)
			local alive = runtime and runtime.alive and not owned.isDefeated
			return {
				ownedId = owned.ownedId,
				speciesKey = owned.speciesKey,
				name = owned.nickname,
				level = tonumber(owned.level) or 1,
				state = alive and "alive" or (owned.isDefeated and "defeated" or "stored"),
				hp = alive and math.floor((runtime.currentHP or 0) + 0.5) or 0,
				maxHP = alive and math.floor(((runtime.modifiedStats and runtime.modifiedStats.maxHP) or 0) + 0.5) or 0,
				stamina = alive and math.floor((runtime.currentStamina or 0) + 0.5) or 0,
				energy = alive and math.floor((runtime.currentEnergy or 0) + 0.5) or 0,
				compositeKey = owned.compositeKey,
				location = location,
				slotOrIndex = slotOrIndex,
			}
		end

		local managedParty = {}
		for slot = 1, 2 do
			managedParty[slot] = buildManagedCreatureEntry(data.partySlots[slot], "party", slot)
		end
		local managedReserve = {}
		for reserveIndex, reserveOwnedId in ipairs(data.reserve) do
			local entry = buildManagedCreatureEntry(reserveOwnedId, "reserve", reserveIndex)
			if entry then
				table.insert(managedReserve, entry)
			end
		end
		local managedItems = {}
		for _, item in ipairs(ItemUseRules.getDisplayItems()) do
			table.insert(managedItems, {
				key = item.key,
				label = item.label,
				targeting = item.targeting,
				count = tonumber(data.materials[item.key]) or 0,
				targetType = (ItemConfig[item.key] and ItemConfig[item.key].targetType) or nil,
			})
		end
		local summary = summarizeHudPayloadForReplication(petPayload)
		local cache = hudReplicationCache[player.UserId]
		local sameAsLast = cache and cache.summary == summary
		local sinceLast = cache and (worldService.time - cache.lastSentAt) or math.huge
		if not sameAsLast or sinceLast >= HUD_KEEPALIVE_SECONDS then
			remotes.PetHudUpdate:FireClient(player, {
				pets = petPayload,
				meta = {
					activeSlot = tonumber(player:GetAttribute("ActivePetSlot")) or 1,
					controlMode = tostring(player:GetAttribute("PetControlMode") or "AUTO"),
					stance = tostring(player:GetAttribute("PetStance") or "FOLLOW"),
					activeDesignatedTargetId = tonumber(player:GetAttribute("ActiveDesignatedTargetId")),
					starterChosen = player:GetAttribute("StarterChosen") == true,
					management = { party = managedParty, reserve = managedReserve, items = managedItems },
				},
				t = worldService.time,
			})
			hudReplicationCache[player.UserId] = { summary = summary, lastSentAt = worldService.time }
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	worldService:stepTime(dt)
	worldService:updateChunksAroundPlayers()
	spawnService:update(dt)
	harvestService:tickNodeRegrowth()
	buildService:tickStructureEffects()
	combatService:update(dt)
	for _, creature in ipairs(worldService.creatures) do
		if creature.alive then
			effectService:tickCreature(creature, dt)
			aiService:think(creature, dt)
			combatService:tryUseAbility(creature)
			creature:Tick(dt)
			creatureService:updateModel(creature)
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		for slot = 1, 2 do
			local attrKey = getDesignatedAttrKey(slot)
			local targetId = tonumber(player:GetAttribute(attrKey))
			if targetId then
				local target = worldService:getCreatureById(targetId)
				if not target or not target.alive then
					player:SetAttribute(attrKey, nil)
					local pet = getPetBySlot(player, slot)
					if pet then
						pet.designatedTargetId = nil
					end
					if slot == (tonumber(player:GetAttribute("ActivePetSlot")) or 1) then
						player:SetAttribute("ActiveDesignatedTargetId", nil)
					end
				end
			end
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
