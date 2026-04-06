local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Util = Shared:WaitForChild("Util")
local BiomeConfig = require(Config:WaitForChild("BiomeConfig"))
local MathUtil = require(Util:WaitForChild("MathUtil"))
local ChunkSystem = require(script.Parent.Parent.Systems.ChunkSystem)

local SpawnService = {}
SpawnService.__index = SpawnService

function SpawnService.new(worldService, creatureService)
	return setmetatable({ worldService = worldService, creatureService = creatureService, timer = 0, interval = 2.0, maxWild = 12 }, SpawnService)
end

function SpawnService:getTierConfig(tier)
	if tier == "small" then
		return { team = 1, aggroMult = 0.72, pursuitRange = 90, targetNearPlayerBias = 0.55, statMult = { maxHP = 0.86, pAtk = 0.9, eAtk = 0.9, spd = 1.05 }, sizeMult = 0.85, timidness = 1.35, commitment = 0.75 }
	elseif tier == "big" then
		return { team = 2, aggroMult = 1.45, pursuitRange = 180, targetNearPlayerBias = 0.0, statMult = { maxHP = 1.35, pAtk = 1.22, eAtk = 1.22, spd = 0.94 }, sizeMult = 1.26, timidness = 0.82, commitment = 1.28 }
	end
	return { team = 1, aggroMult = 1, pursuitRange = 120, targetNearPlayerBias = 0, statMult = nil, sizeMult = 1, timidness = 1, commitment = 1 }
end

function SpawnService:rollTier()
	local r = math.random()
	if r < 0.24 then return "small" end
	if r < 0.92 then return "normal" end
	return "big"
end

function SpawnService:update(dt)
	self.timer += dt
	if self.timer < self.interval then return end
	self.timer = 0
	local wildAlive = 0
	for _, c in ipairs(self.worldService.creatures) do
		if c.mode == "wild" and c.alive then wildAlive += 1 end
	end
	if wildAlive >= self.maxWild then return end
	local players = Players:GetPlayers()
	if #players == 0 then return end
	local player = players[math.random(1, #players)]
	local root = player.Character and player.Character.PrimaryPart
	if not root then return end
	ChunkSystem.ensureLoaded(self.worldService, root.Position.X, root.Position.Z)
	local cells = ChunkSystem.collectSpawnableCells(self.worldService)
	if #cells == 0 then return end
	local cell = cells[math.random(1, #cells)]
	local tier = self:rollTier()
	local cfg = self:getTierConfig(tier)
	local biome = BiomeConfig[cell.dominantBiome] or BiomeConfig.plains
	local speciesKey = MathUtil.pickWeighted(biome.spawns)
	self.creatureService:spawnRuntime(speciesKey, cfg.team, cell.x, cell.z, {
		mode = "wild",
		wildTier = tier,
		wildProfile = cfg,
		spawnAnchor = Vector3.new(cell.x, 0, cell.z),
	})
end

return SpawnService
