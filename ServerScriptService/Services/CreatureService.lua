local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = Shared:WaitForChild("Creatures")
local CreatureFactoryRules = require(Creatures:WaitForChild("CreatureFactoryRules"))
local CreatureRuntime = require(script.Parent.Parent.Runtime.CreatureRuntime)

local CreatureService = {}
CreatureService.__index = CreatureService

local function ensurePetTagBars(tag)
	local panel = tag:FindFirstChild("PetBars")
	if panel then return panel end
	panel = Instance.new("Frame")
	panel.Name = "PetBars"
	panel.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
	panel.BackgroundTransparency = 0.18
	panel.BorderSizePixel = 0
	panel.Size = UDim2.new(1, -6, 0, 44)
	panel.Position = UDim2.fromOffset(3, 16)
	panel.Parent = tag

	local function addBar(name, y, color)
		local label = Instance.new("TextLabel")
		label.Name = name .. "_Label"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromOffset(18, 10)
		label.Position = UDim2.fromOffset(2, y)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 8
		label.TextColor3 = Color3.fromRGB(232, 238, 244)
		label.Text = name
		label.Parent = panel

		local track = Instance.new("Frame")
		track.Name = name .. "_Track"
		track.BackgroundColor3 = Color3.fromRGB(46, 54, 68)
		track.BorderSizePixel = 0
		track.Size = UDim2.new(1, -24, 0, 6)
		track.Position = UDim2.fromOffset(20, y + 2)
		track.Parent = panel

		local fill = Instance.new("Frame")
		fill.Name = name .. "_Fill"
		fill.BackgroundColor3 = color
		fill.BorderSizePixel = 0
		fill.Size = UDim2.fromScale(1, 1)
		fill.Parent = track
	end

	addBar("HP", 2, Color3.fromRGB(214, 78, 78))
	addBar("ST", 15, Color3.fromRGB(234, 198, 92))
	addBar("EN", 28, Color3.fromRGB(92, 166, 235))
	return panel
end

local function setTagBarFill(panel, key, current, maxValue)
	if not panel then return end
	local fill = panel:FindFirstChild(key .. "_Track") and panel[key .. "_Track"]:FindFirstChild(key .. "_Fill")
	if not fill then return end
	local maxV = math.max(1, tonumber(maxValue) or 1)
	local ratio = math.clamp((tonumber(current) or 0) / maxV, 0, 1)
	fill.Size = UDim2.fromScale(ratio, 1)
end

function CreatureService.new(worldService, playerDataService)
	return setmetatable({ worldService = worldService, playerDataService = playerDataService }, CreatureService)
end

function CreatureService:resolveGroundY(x, z, fallbackY)
	return self.worldService:resolveCreatureGroundY(x, z, fallbackY)
end

function CreatureService:spawnRuntime(speciesKey, team, x, z, opts)
	local creature = CreatureRuntime.new(speciesKey, team, x, z, opts)
	self.worldService:snapCreatureToGround(creature)
	CreatureFactoryRules.applyLifecycleDefaults(creature, self.worldService.time)
	self.worldService:addCreature(creature)
	self:attachModel(creature)
	return creature
end

function CreatureService:spawnFromSpawnPayload(speciesKey, spawnPayload)
	local payload = CreatureFactoryRules.makeSpawnPayload({
		speciesKey = speciesKey,
		team = spawnPayload and spawnPayload.team,
		x = spawnPayload and spawnPayload.x,
		y = spawnPayload and spawnPayload.y,
		z = spawnPayload and spawnPayload.z,
		opts = spawnPayload and spawnPayload.opts,
	})
	payload.opts = payload.opts or {}
	payload.opts.y = self:resolveGroundY(payload.x, payload.z, payload.y)
	return self:spawnRuntime(payload.speciesKey, payload.team, payload.x, payload.z, payload.opts)
end

function CreatureService:spawnPetFromOwned(player, ownedId, slot, pos, owned)
	local payload = CreatureFactoryRules.makePetRuntimePayload(player.UserId, ownedId, slot, pos, owned, self.worldService.time)
	payload.y = self:resolveGroundY(payload.x, payload.z, payload.y)
	local pet = self:spawnFromSpawnPayload(payload.speciesKey, payload)
	CreatureFactoryRules.applyRuntimeIdentity(pet, payload.identity)
	CreatureFactoryRules.applyLoadout(pet, payload.loadout)
	pet:RebuildStats()
	return pet
end

function CreatureService:syncOwnedFromRuntime(player, ownedId, runtime)
	local data = self.playerDataService:getOrCreate(player)
	local owned = data.ownedCreatures[ownedId]
	CreatureFactoryRules.syncOwnedFromRuntime(owned, runtime)
end

function CreatureService:attachModel(creature)
	local modelsFolder = self:getOrCreateCreatureModelsFolder()
	if not modelsFolder then return end
	local model = Instance.new("Model")
	model.Name = string.format("C_%d_%s", creature.id, creature.speciesKey)
	model.Parent = modelsFolder

	local mainPart = Instance.new("Part")
	mainPart.Name = "Body"
	mainPart.Shape = Enum.PartType.Ball
	mainPart.Anchored = true
	mainPart.CanCollide = false
	mainPart.Material = Enum.Material.SmoothPlastic
	mainPart.Color = self:getCreatureColor(creature)
	mainPart.Size = self:getCreatureVisualSize(creature)
	mainPart.Position = creature.pos + Vector3.new(0, (mainPart.Size.Y * 0.5), 0)
	mainPart.Parent = model

	local tag = Instance.new("BillboardGui")
	tag.Name = "Tag"
	tag.Adornee = mainPart
	tag.Size = creature.mode == "pet" and UDim2.fromOffset(132, 66) or UDim2.fromOffset(120, 28)
	tag.StudsOffset = Vector3.new(0, mainPart.Size.Y * (creature.mode == "pet" and 0.95 or 0.85), 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = creature.mode == "pet" and 110 or 70
	tag.Parent = model

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = creature.mode == "pet" and UDim2.new(1, 0, 0, 16) or UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = creature.mode ~= "pet"
	text.TextSize = creature.mode == "pet" and 11 or 12
	text.TextStrokeTransparency = 0.45
	text.TextColor3 = Color3.fromRGB(240, 240, 240)
	text.Text = self:getCreatureTagText(creature)
	text.Parent = tag
	if creature.mode == "pet" then
		ensurePetTagBars(tag)
	end

	model.PrimaryPart = mainPart
	model:SetAttribute("CreatureId", creature.id)
	model:SetAttribute("CreatureMode", tostring(creature.mode or "unknown"))
	model:SetAttribute("CreatureDefeated", creature.alive ~= true)
	model:SetAttribute("CreatureLifecycle", tostring(creature.lifecycle or (creature.alive and "alive" or "defeated")))
	creature.model = model
end

function CreatureService:updateModel(creature)
	local terrainY = self.worldService:snapCreatureToGround(creature)
	if creature.model and creature.model.PrimaryPart then
		local body = creature.model.PrimaryPart
		body.Color = self:getCreatureColor(creature)
		body.Size = self:getCreatureVisualSize(creature)
		local modelCenterY = creature.pos.Y + (body.Size.Y * 0.5)
		body.Position = Vector3.new(creature.pos.X, modelCenterY, creature.pos.Z)
		if creature.ai then
			creature.model:SetAttribute("AI_Brain", tostring(creature.ai.brainType or "-"))
			creature.model:SetAttribute("AI_State", tostring(creature.ai.behaviorState or "-"))
			creature.model:SetAttribute("AI_TargetId", tonumber(creature.ai.targetId) or -1)
			creature.model:SetAttribute("AI_Intent", tostring(creature.ai.lastIntent or "idle"))
			creature.model:SetAttribute("AI_Ability", tostring(creature.ai.lastChosenAbility or "-"))
			creature.model:SetAttribute("AI_AbilityScore", tostring(creature.ai.lastAbilityScoreSummary or "-"))
			creature.model:SetAttribute("AI_ControlMode", tostring(creature.debugAI and creature.debugAI.controlMode or "-"))
			creature.model:SetAttribute("AI_CommandOverride", creature.debugAI and creature.debugAI.commandOverride and true or false)
			creature.model:SetAttribute("AI_IntendedMove", tostring(creature.debugAI and creature.debugAI.intendedMove or "0,0,0"))
			creature.model:SetAttribute("AI_NextThinkAt", tonumber(creature.debugAI and creature.debugAI.nextThinkAt) or 0)
			creature.model:SetAttribute("AI_IdleSleepUntil", tonumber(creature.debugAI and creature.debugAI.idleSleepUntil) or 0)
			creature.model:SetAttribute("AI_IsDormant", creature.debugAI and creature.debugAI.isDormant and true or false)
		end
		if creature.mode == "pet" and creature.ownerUserId then
			local owner = Players:GetPlayerByUserId(creature.ownerUserId)
			if owner then
				creature.model:SetAttribute("PetControlMode", tostring(owner:GetAttribute("PetControlMode") or "AUTO"))
				creature.model:SetAttribute("PetStance", tostring(owner:GetAttribute("PetStance") or "FOLLOW"))
			end
		end
		creature.model:SetAttribute("DesignatedTargetId", tonumber(creature.designatedTargetId) or -1)
		creature.model:SetAttribute("CreatureMode", tostring(creature.mode or "unknown"))
		creature.model:SetAttribute("CreatureDefeated", creature.alive ~= true)
		creature.model:SetAttribute("CreatureLifecycle", tostring(creature.lifecycle or (creature.alive and "alive" or "defeated")))
		creature.model:SetAttribute("DefeatedExpiresAt", tonumber(creature.defeatedExpiresAt) or 0)
		creature.model:SetAttribute("DefeatedOutcome", tostring(creature.defeatedOutcome or ""))
		creature.model:SetAttribute("ManualCastState", tostring(creature.manualCastState or "idle"))
		creature.model:SetAttribute("ManualCastNote", tostring(creature.manualCastNote or "-"))
		creature.model:SetAttribute("LastManualCastCode", tostring(creature.lastManualCastResult and creature.lastManualCastResult.code or "-"))
		creature.model:SetAttribute("LastCmdType", tostring(creature.lastReceivedCommandType or (creature.command and creature.command.type) or "-"))
		creature.model:SetAttribute("LastCmdTargetId", tonumber(creature.lastReceivedCommandTargetId) or -1)
		creature.model:SetAttribute("LastCmdPoint", tostring(creature.lastReceivedCommandPoint or "-"))
		creature.model:SetAttribute("LastSanitizedCmd", tostring(creature.lastSanitizedCommandType or "-"))
		creature.model:SetAttribute("GroundY", creature.pos.Y)
		creature.model:SetAttribute("EffectSummary", tostring(creature.effectSummary or ""))
		creature.model:SetAttribute("EffectFlags", creature.effectFlags and string.format("b:%s bl:%s s:%s sh:%s g:%s h:%s w:%s",
			creature.effectFlags.burning and "1" or "0",
			creature.effectFlags.bleeding and "1" or "0",
			creature.effectFlags.slowed and "1" or "0",
			creature.effectFlags.shocked and "1" or "0",
			creature.effectFlags.guarded and "1" or "0",
			creature.effectFlags.hasted and "1" or "0",
			creature.effectFlags.wet and "1" or "0"
			) or "")
		creature.model:SetAttribute("LastReaction", tostring(creature.lastReactionTriggered or "-"))
		if creature.debugStatLayers then
			local base = creature.debugStatLayers.baseStats or {}
			local roll = creature.debugStatLayers.rollStats or {}
			local growth = creature.debugStatLayers.growthStats or {}
			local final = creature.debugStatLayers.finalStats or {}
			creature.model:SetAttribute("Stats_Base", string.format("HP:%s PA:%s EA:%s SPD:%s ST:%s EN:%s", tostring(base.maxHP or 0), tostring(base.pAtk or 0), tostring(base.eAtk or 0), tostring(base.spd or 0), tostring(base.stamina or 0), tostring(base.energy or 0)))
			creature.model:SetAttribute("Stats_Roll", string.format("HP:+%s PA:+%s EA:+%s SPD:+%s ST:+%s EN:+%s", tostring(roll.maxHP or 0), tostring(roll.pAtk or 0), tostring(roll.eAtk or 0), tostring(roll.spd or 0), tostring(roll.stamina or 0), tostring(roll.energy or 0)))
			creature.model:SetAttribute("Stats_Growth", string.format("HP:+%s PA:+%s EA:+%s SPD:+%s ST:+%s EN:+%s", tostring(growth.maxHP or 0), tostring(growth.pAtk or 0), tostring(growth.eAtk or 0), tostring(growth.spd or 0), tostring(growth.stamina or 0), tostring(growth.energy or 0)))
			creature.model:SetAttribute("Stats_Final", string.format("HP:%s PA:%s EA:%s SPD:%s ST:%s EN:%s", tostring(final.maxHP or 0), tostring(final.pAtk or 0), tostring(final.eAtk or 0), tostring(final.spd or 0), tostring(final.stamina or 0), tostring(final.energy or 0)))
		end
		creature.model:SetAttribute("TerrainY", terrainY or creature.pos.Y)
		creature.model:SetAttribute("ModelCenterY", modelCenterY)
		creature.model:SetAttribute("VisualSizeY", body.Size.Y)
		local tag = creature.model:FindFirstChild("Tag")
		if tag then
			tag.StudsOffset = Vector3.new(0, body.Size.Y * (creature.mode == "pet" and 0.95 or 0.85), 0)
			local lbl = tag:FindFirstChildOfClass("TextLabel")
			if lbl then lbl.Text = self:getCreatureTagText(creature) end
			if creature.mode == "pet" and creature.alive then
				local panel = ensurePetTagBars(tag)
				setTagBarFill(panel, "HP", creature.currentHP, creature.modifiedStats and creature.modifiedStats.maxHP)
				setTagBarFill(panel, "ST", creature.currentStamina, creature.modifiedStats and creature.modifiedStats.stamina)
				setTagBarFill(panel, "EN", creature.currentEnergy, creature.modifiedStats and creature.modifiedStats.energy)
			end
		end
	end
end

function CreatureService:spawnPartyPetsForPlayer(player)
	self:HydrateParty(player)
end

function CreatureService:HydrateParty(player)
	local data = self.playerDataService:getOrCreate(player)
	local root = player.Character and player.Character.PrimaryPart
	if not root then return end
	self:despawnPetsForPlayer(player)
	local offsets = { Vector3.new(-6, 0, 8), Vector3.new(6, 0, 8) }
	for slot = 1, 2 do
		local ownedId = data.partySlots[slot]
		local owned = ownedId and data.ownedCreatures[ownedId] or nil
		if owned and not owned.isDefeated then
			local offset = offsets[slot]
			local x = root.Position.X + offset.X
			local z = root.Position.Z + offset.Z
			local y = self:resolveGroundY(x, z, root.Position.Y)
			local pos = Vector3.new(x, y, z)
			self:spawnPetFromOwned(player, ownedId, slot, pos, owned)
		end
	end
end

function CreatureService:despawnPetsForPlayer(player)
	local remaining = {}
	for _, c in ipairs(self.worldService.creatures) do
		if c.ownerUserId == player.UserId and c.mode == "pet" then
			c.alive = false
			if c.model then c.model:Destroy(); c.model = nil end
			self.worldService.creaturesById[c.id] = nil
		else
			table.insert(remaining, c)
		end
	end
	self.worldService.creatures = remaining
end

function CreatureService:respawnPartyFromOwned(player)
	self:HydrateParty(player)
end

function CreatureService:getOrCreateCreatureModelsFolder()
	local worldFolder = Workspace:FindFirstChild("World") or Instance.new("Folder")
	worldFolder.Name = "World"
	worldFolder.Parent = Workspace
	local modelsFolder = worldFolder:FindFirstChild("CreatureModels") or Instance.new("Folder")
	modelsFolder.Name = "CreatureModels"
	modelsFolder.Parent = worldFolder
	return modelsFolder
end

function CreatureService:getCreatureColor(creature)
	if creature.alive ~= true and creature.mode == "wild" then
		return Color3.fromRGB(125, 125, 125)
	end
	if creature.role == "passive" then return Color3.fromRGB(177, 229, 157) end
	if creature.team == 0 then return Color3.fromRGB(120, 220, 255) end
	if creature.wildTier == "big" then return Color3.fromRGB(242, 130, 104) end
	if creature.wildTier == "small" then return Color3.fromRGB(255, 199, 114) end
	return Color3.fromRGB(255, 155, 120)
end

function CreatureService:getCreatureVisualSize(creature)
	local base = creature.modifiedStats and creature.modifiedStats.size or 3
	local core = math.max(1.5, math.min(6, base * 0.45))
	local tierScale = (creature.wildTier == "small" and 0.85) or (creature.wildTier == "big" and 1.25) or 1
	local final = core * tierScale
	return Vector3.new(final, final, final)
end

function CreatureService:getCreatureTagText(creature)
	local level = math.max(1, math.floor(tonumber(creature.level) or 1))
	if creature.mode == "pet" then
		return string.format("%s Lv.%d", tostring(creature.speciesKey), level)
	end
	if creature.alive ~= true and creature.mode == "wild" then
		return string.format("%s Lv.%d (downed)", tostring(creature.speciesKey), level)
	end
	if creature.role == "passive" then
		return string.format("%s (passive)", tostring(creature.speciesKey))
	end
	return string.format("%s Lv.%d", tostring(creature.speciesKey), level)
end

return CreatureService
