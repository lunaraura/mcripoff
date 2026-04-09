local CreatureFactoryRules = {}

function CreatureFactoryRules.makeSpawnPayload(input)
	input = input or {}
	return {
		speciesKey = input.speciesKey,
		team = input.team or 1,
		x = input.x or 0,
		y = input.y,
		z = input.z or 0,
		opts = input.opts or {},
	}
end

function CreatureFactoryRules.makePetRuntimePayload(ownerUserId, ownedId, slot, pos, owned, worldTime)
	return {
		speciesKey = owned.speciesKey,
		team = 0,
		x = pos.X,
		y = pos.Y,
		z = pos.Z,
		opts = {
			mode = "pet",
			level = owned.level or 1,
			morphPoints = owned.morphPoints or 0,
		},
		identity = {
			ownerUserId = ownerUserId,
			ownedId = ownedId,
			partySlot = slot,
			familyKey = owned.familyKey,
			outerCompositeKey = owned.outerCompositeKey,
			innerCompositeKey = owned.innerCompositeKey,
			compositeKey = owned.compositeKey,
			command = { type = "follow", issuedAt = worldTime or 0 },
		},
		loadout = {
			moveset = owned.moveset,
			cooldowns = {},
		},
	}
end

function CreatureFactoryRules.applyRuntimeIdentity(creature, identity)
	identity = identity or {}
	creature.ownerUserId = identity.ownerUserId
	creature.ownedId = identity.ownedId
	creature.partySlot = identity.partySlot
	creature.familyKey = identity.familyKey or creature.familyKey
	creature.outerCompositeKey = identity.outerCompositeKey or creature.outerCompositeKey
	creature.innerCompositeKey = identity.innerCompositeKey or creature.innerCompositeKey
	creature.compositeKey = identity.compositeKey or creature.compositeKey
	creature.command = identity.command or creature.command
end

function CreatureFactoryRules.applyLoadout(creature, loadout)
	loadout = loadout or {}
	creature.moveset = table.clone(loadout.moveset or creature.moveset or {})
	creature.cooldowns = loadout.cooldowns or {}
	for _, key in ipairs(creature.moveset or {}) do
		if creature.cooldowns[key] == nil then creature.cooldowns[key] = 0 end
	end
end

function CreatureFactoryRules.applyLifecycleDefaults(creature, worldTime)
	creature.spawnTime = worldTime or creature.spawnTime or 0
	creature.lifecycle = creature.alive and "alive" or (creature.lifecycle or "alive")
end

function CreatureFactoryRules.syncOwnedFromRuntime(owned, runtime)
	if not owned or not runtime then return end
	owned.speciesKey = runtime.speciesKey
	owned.level = runtime.level
	owned.morphPoints = runtime.morphPoints
	owned.familyKey = runtime.familyKey
	owned.outerCompositeKey = runtime.outerCompositeKey
	owned.innerCompositeKey = runtime.innerCompositeKey
	owned.compositeKey = runtime.compositeKey
	owned.abilities = table.clone(runtime.abilities or owned.abilities or {})
	owned.moveset = table.clone(runtime.moveset or owned.moveset or {})
end

return CreatureFactoryRules
