local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local AbilityConfig = require(Config:WaitForChild("AbilityConfig"))
local CompositeConfig = require(Config:WaitForChild("CompositeConfig"))

local CombatService = {}
CombatService.__index = CombatService

function CombatService.new(worldService)
	return setmetatable({ worldService = worldService, playerDataService = nil, morphService = nil }, CombatService)
end

function CombatService:configureProgression(playerDataService, morphService)
	self.playerDataService = playerDataService
	self.morphService = morphService
end

function CombatService:hasMoveEquipped(creature, abilityKey)
	for _, key in ipairs(creature.moveset or {}) do
		if key == abilityKey then
			return true
		end
	end
	return false
end

function CombatService:resolveResistance(map, damageTypes, fallback)
	local keys = (damageTypes and #damageTypes > 0) and damageTypes or { fallback }
	local total = 0
	for _, k in ipairs(keys) do
		total += (map[k] or 1)
	end
	return total / math.max(1, #keys)
end

function CombatService:getDamageParts(source, ability)
	return {
		physical = (ability.flatDmg.p or 0) + (ability.dmgScale.p or 0) * source.modifiedStats.pAtk,
		energy = (ability.flatDmg.e or 0) + (ability.dmgScale.e or 0) * source.modifiedStats.eAtk,
	}
end

function CombatService:getFallbacks(parts)
	return {
		physical = parts.physical > 0 and "impact" or "pierce",
		energy = parts.energy > 0 and "electric" or "heat",
	}
end

function CombatService:applyDamagePacket(source, target, ability)
	local parts = self:getDamageParts(source, ability)
	local profile = ability.damageProfile or {}
	local fallback = self:getFallbacks(parts)
	local resistance = target:GetCompositeResistances()
	local physicalTypes = (#(profile.physical or {}) > 0) and profile.physical or { fallback.physical }
	local energyTypes = (#(profile.energy or {}) > 0) and profile.energy or { fallback.energy }
	local physicalMod = self:resolveResistance(resistance.physical or CompositeConfig.defaults.physical, physicalTypes, fallback.physical)
	local energyMod = self:resolveResistance(resistance.energy or CompositeConfig.defaults.energy, energyTypes, fallback.energy)
	local raw = parts.physical * physicalMod + parts.energy * energyMod
	local atkScaled = raw * (source.runtimeAtkMult or 1)
	local reduced = atkScaled * (1 - (target.runtimeDmgReduction or 0))
	local final = math.max(1, reduced)
	target.currentHP = math.max(0, target.currentHP - final)
	self.worldService:pushFloatingText(target.pos, tostring(math.floor(final + 0.5)), "#ffd7d7")
	if target.currentHP <= 0 then
		target.alive = false
		target.lifecycle = "defeated"
		if self.playerDataService and source and source.ownerUserId and source.ownedId then
			local player = game:GetService("Players"):GetPlayerByUserId(source.ownerUserId)
			if player then
				local xpGain = math.max(5, math.floor((target.level or 1) * 6))
				local ok, gain = self.playerDataService:addOwnedXP(player, source.ownedId, xpGain)
				if ok and self.morphService then
					self.morphService:awardPoints(player, source.ownedId, 1)
				end
				local lvlUp = gain and gain.levelUps or 0
				if lvlUp > 0 then
					self.worldService:pushEventLog(player, string.format("+%d XP  Level up x%d", xpGain, lvlUp), "#a8ffd7")
				else
					self.worldService:pushEventLog(player, string.format("+%d XP", xpGain), "#d7fcb7")
				end
			end
		end
	end
end

function CombatService:evaluateAbility(source, abilityKey, target)
	local ability = AbilityConfig[abilityKey]
	if not ability then return false, "unknown" end
	if not self:hasMoveEquipped(source, abilityKey) then return false, "not_learned" end
	if (source.cooldowns[abilityKey] or 0) > 0 then return false, "cooldown" end
	if (ability.resourceUse.stamina or 0) > source.currentStamina then return false, "stamina" end
	if (ability.resourceUse.energy or 0) > source.currentEnergy then return false, "energy" end
	if not target or not target.alive or target.team == source.team then return false, "target" end
	local d = (Vector3.new(source.pos.X,0,source.pos.Z)-Vector3.new(target.pos.X,0,target.pos.Z)).Magnitude
	if d > (ability.range or 20) then return false, "range" end
	return true, ability
end

function CombatService:tryUseAbility(source)
	local key = source.intent.abilityKey
	if not key then return end
	local target = self.worldService:getCreatureById(source.intent.targetId)
	local ok, abilityOrReason = self:evaluateAbility(source, key, target)
	source.intent.abilityKey = nil
	source.intent.targetId = nil
	if not ok then return end
	local ability = abilityOrReason
	source.currentStamina -= (ability.resourceUse.stamina or 0)
	source.currentEnergy -= (ability.resourceUse.energy or 0)
	source.cooldowns[key] = ability.cooldown or 1
	if source.ownerUserId then
		local player = game:GetService("Players"):GetPlayerByUserId(source.ownerUserId)
		if player and target then
			self.worldService:pushEventLog(player, string.format("%s used %s on %s", source.speciesKey, ability.name, target.speciesKey), "#ffd9a8")
		end
	end
	self:applyDamagePacket(source, target, ability)
end

return CombatService
