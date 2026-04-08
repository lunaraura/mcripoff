local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local SpeciesConfig = require(Config:WaitForChild("SpeciesConfig"))
local FamilyConfig = require(Config:WaitForChild("FamilyConfig"))
local CompositeConfig = require(Config:WaitForChild("CompositeConfig"))

local CreatureRuntime = {}
CreatureRuntime.__index = CreatureRuntime

local nextId = 1

function CreatureRuntime.new(speciesKey, team, x, z, opts)
	opts = opts or {}
	local def = SpeciesConfig[speciesKey]
	assert(def, "Unknown species: " .. tostring(speciesKey))
	local self = setmetatable({}, CreatureRuntime)
	self.id = nextId
	nextId += 1
	self.speciesKey = speciesKey
	self.team = team
	self.mode = opts.mode or (team == 0 and "pet" or "wild")
	self.role = def.role or "fighter"
	-- Canonical Y contract: pos.Y is terrain ground-contact (feet), not visual/model center.
	self.pos = Vector3.new(x, opts.y or 0, z)
	self.spawnAnchor = opts.spawnAnchor or self.pos
	self.familyKey = def.familyKey or "canine"
	self.outerCompositeKey = def.outerCompositeKey or def.compositeKey or "animal"
	self.innerCompositeKey = def.innerCompositeKey or def.compositeKey or "animal"
	self.compositeKey = def.compositeKey or self.outerCompositeKey
	self.baseStats = table.clone(def.baseStats)
	self.modifiedStats = table.clone(def.baseStats)
	self.level = opts.level or 1
	self.morphPoints = opts.morphPoints or 0
	self.moveset = table.clone(opts.movesetOverride or def.moveset or {})
	self.cooldowns = {}
	for _, k in ipairs(self.moveset) do self.cooldowns[k] = 0 end
	self.currentHP = self.modifiedStats.maxHP
	self.currentStamina = self.modifiedStats.stamina
	self.currentEnergy = self.modifiedStats.energy
	self.harvestDrop = table.clone(def.harvestDrop or {})
	self.harvestCooldown = def.harvestCooldown or 0
	self.nextHarvestAt = 0
	self.drop = table.clone(def.drop or {})
	self.intent = { move = Vector3.zero, abilityKey = nil, targetId = nil, contextAction = nil }
	self.runtimeAtkMult = 1
	self.runtimeDmgReduction = 0
	self.runtimeMoveMult = 1
	self.statuses = {}
	self.alive = true
	self.lifecycle = "alive"
	self.command = { type = "follow", issuedAt = 0, targetId = nil, point = nil }
	self.ai = {
		brainType = opts.brainType or ((self.mode == "pet" and "petFollower") or (self.role == "passive" and "passiveWild") or "hostileWild"),
		behaviorState = "idle",
		targetId = nil,
		targetLockUntil = 0,
		homeAnchor = self.spawnAnchor,
		roamAnchor = self.spawnAnchor,
		leashRadius = 80,
		aggroRadius = 60,
		disengageRadius = 110,
		lastSeenTargetTime = 0,
		nextThinkAt = 0,
		movementRefreshAt = 0,
		recentThreatId = nil,
		lastIntent = "idle",
		lastChosenAbility = nil,
		lastAbilityScoreSummary = nil,
	}
	self.model = nil
	self.wildProfile = {
		aggroMult = 1,
		pursuitRange = nil,
		targetNearPlayerBias = 0,
		statMult = nil,
		sizeMult = 1,
		timidness = 1,
		commitment = 1,
	}
	self.wildArchetype = opts.wildArchetype
	self:SetWildProfile(opts.wildTier or "normal", opts.wildProfile)
	return self
end

function CreatureRuntime:SetWildProfile(tier, profile)
	profile = profile or {}
	self.wildTier = tier or "normal"
	self.wildProfile.aggroMult = profile.aggroMult or self.wildProfile.aggroMult
	self.wildProfile.pursuitRange = profile.pursuitRange or self.wildProfile.pursuitRange
	self.wildProfile.targetNearPlayerBias = profile.targetNearPlayerBias or 0
	self.wildProfile.statMult = profile.statMult
	self.wildProfile.sizeMult = profile.sizeMult or 1
	self.wildProfile.timidness = profile.timidness or 1
	self.wildProfile.commitment = profile.commitment or 1
	self:RebuildStats()
end

function CreatureRuntime:RebuildStats()
	self.modifiedStats = table.clone(self.baseStats)
	local family = FamilyConfig[self.familyKey]
	if family and family.statMult then
		for k, mult in pairs(family.statMult) do
			if self.modifiedStats[k] then self.modifiedStats[k] *= mult end
		end
	end
	local traits = (CompositeConfig[self.compositeKey] and CompositeConfig[self.compositeKey].traits) or CompositeConfig.animal.traits
	self.modifiedStats.maxHP *= 1 + ((traits.toughness or 0) * 0.35)
	self.modifiedStats.spd *= 1 + ((traits.mobilityBias or 0) * 0.25)
	self.modifiedStats.energy *= 1 + ((traits.energyBias or 0) * 0.45)
	if self.wildProfile.statMult then
		for k, mult in pairs(self.wildProfile.statMult) do
			if self.modifiedStats[k] then self.modifiedStats[k] *= mult end
		end
	end
	self.currentHP = math.min(self.currentHP, self.modifiedStats.maxHP)
	self.currentStamina = math.min(self.currentStamina, self.modifiedStats.stamina)
	self.currentEnergy = math.min(self.currentEnergy, self.modifiedStats.energy)
end

function CreatureRuntime:Tick(dt)
	if not self.alive then return end
	for k, v in pairs(self.cooldowns) do self.cooldowns[k] = math.max(0, v - dt) end
	self.currentStamina = math.min(self.modifiedStats.stamina, self.currentStamina + (self.modifiedStats.recoverStamina or 1) * dt)
	self.currentEnergy = math.min(self.modifiedStats.energy, self.currentEnergy + (self.modifiedStats.recoverEnergy or 1) * dt)
	local move = self.intent.move or Vector3.zero
	local mag = move.Magnitude
	local dir = mag > 0 and (move / mag) or Vector3.zero
	self.pos += Vector3.new(dir.X, 0, dir.Z) * self.modifiedStats.spd * (self.runtimeMoveMult or 1) * dt
end

function CreatureRuntime:GetCompositeResistances()
	local outer = (CompositeConfig[self.outerCompositeKey or self.compositeKey] and CompositeConfig[self.outerCompositeKey or self.compositeKey].resistances) or CompositeConfig.defaults
	local inner = (CompositeConfig[self.innerCompositeKey or self.compositeKey] and CompositeConfig[self.innerCompositeKey or self.compositeKey].resistances) or CompositeConfig.defaults
	local out = { physical = {}, energy = {} }
	for k, v in pairs(CompositeConfig.defaults.physical) do
		local ov = (outer.physical and outer.physical[k]) or v
		local iv = (inner.physical and inner.physical[k]) or v
		out.physical[k] = (ov + iv) * 0.5
	end
	for k, v in pairs(CompositeConfig.defaults.energy) do
		local ov = (outer.energy and outer.energy[k]) or v
		local iv = (inner.energy and inner.energy[k]) or v
		out.energy[k] = (ov + iv) * 0.5
	end
	return out
end

return CreatureRuntime
