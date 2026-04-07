local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = Shared:WaitForChild("Creatures")
local CreatureFactoryRules = require(Creatures:WaitForChild("CreatureFactoryRules"))
local CreatureRuntime = require(script.Parent.Parent.Runtime.CreatureRuntime)

local CreatureService = {}
CreatureService.__index = CreatureService

function CreatureService.new(worldService, playerDataService)
	return setmetatable({ worldService = worldService, playerDataService = playerDataService }, CreatureService)
end

function CreatureService:spawnRuntime(speciesKey, team, x, z, opts)
	local creature = CreatureRuntime.new(speciesKey, team, x, z, opts)
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
		z = spawnPayload and spawnPayload.z,
		opts = spawnPayload and spawnPayload.opts,
	})
	return self:spawnRuntime(payload.speciesKey, payload.team, payload.x, payload.z, payload.opts)
end

function CreatureService:spawnPetFromOwned(player, ownedId, slot, pos, owned)
	local payload = CreatureFactoryRules.makePetRuntimePayload(player.UserId, ownedId, slot, pos, owned, self.worldService.time)
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
	tag.Size = UDim2.fromOffset(120, 28)
	tag.StudsOffset = Vector3.new(0, mainPart.Size.Y * 0.85, 0)
	tag.AlwaysOnTop = true
	tag.Parent = model

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextStrokeTransparency = 0.45
	text.TextColor3 = Color3.fromRGB(240, 240, 240)
	text.Text = self:getCreatureTagText(creature)
	text.Parent = tag

	model.PrimaryPart = mainPart
	creature.model = model
end

function CreatureService:updateModel(creature)
	if creature.model and creature.model.PrimaryPart then
		local body = creature.model.PrimaryPart
		body.Color = self:getCreatureColor(creature)
		body.Size = self:getCreatureVisualSize(creature)
		body.Position = creature.pos + Vector3.new(0, (body.Size.Y * 0.5), 0)
		local tag = creature.model:FindFirstChild("Tag")
		if tag then
			tag.StudsOffset = Vector3.new(0, body.Size.Y * 0.85, 0)
			local lbl = tag:FindFirstChildOfClass("TextLabel")
			if lbl then lbl.Text = self:getCreatureTagText(creature) end
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
			local pos = root.Position + offsets[slot]
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
	local tier = creature.mode == "wild" and (creature.wildTier or "normal") or "pet"
	local passive = creature.role == "passive" and " passive" or ""
	local arche = creature.mode == "wild" and creature.wildArchetype and ("/" .. creature.wildArchetype) or ""
	return string.format("%s (%s%s%s)", creature.speciesKey, tier, arche, passive)
end

return CreatureService
