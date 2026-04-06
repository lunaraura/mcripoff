local BiomeSystem = require(script.Parent.BiomeSystem)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Terrain = workspace.Terrain
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local BiomeConfig = require(Config:WaitForChild("BiomeConfig"))

local ChunkSystem = {}
ChunkSystem.CHUNK_SIZE = 64
ChunkSystem.CELL_SIZE = 8
ChunkSystem.LOAD_RADIUS = 2

function ChunkSystem.worldToChunk(x, z)
	return math.floor(x / ChunkSystem.CHUNK_SIZE), math.floor(z / ChunkSystem.CHUNK_SIZE)
end

local function chunkKey(cx, cz)
	return string.format("%d:%d", cx, cz)
end

function ChunkSystem.key(cx, cz)
	return chunkKey(cx, cz)
end

local BIOME_MATS = {
	ocean = { ground = Enum.Material.Sand, high = Enum.Material.Rock },
	desert = { ground = Enum.Material.Sand, high = Enum.Material.Rock },
	forest = { ground = Enum.Material.Grass, high = Enum.Material.Ground },
	plains = { ground = Enum.Material.Grass, high = Enum.Material.Ground },
	stormfield = { ground = Enum.Material.Slate, high = Enum.Material.Rock },
	volcanic = { ground = Enum.Material.Basalt, high = Enum.Material.Rock },
	tundra = { ground = Enum.Material.Snow, high = Enum.Material.Ice },
	polar = { ground = Enum.Material.Snow, high = Enum.Material.Ice },
}

function ChunkSystem.generateChunk(cx, cz)
	local cells = {}
	local cellsPerAxis = ChunkSystem.CHUNK_SIZE / ChunkSystem.CELL_SIZE
	for iz = 0, cellsPerAxis - 1 do
		for ix = 0, cellsPerAxis - 1 do
			local wx = cx * ChunkSystem.CHUNK_SIZE + ix * ChunkSystem.CELL_SIZE
			local wz = cz * ChunkSystem.CHUNK_SIZE + iz * ChunkSystem.CELL_SIZE
			local env = BiomeSystem.sampleEnvironment(wx, wz)
			local biome = env.biomeKey
			local terrainClass = env.terrainClass
			local blocked = terrainClass == "rock"
			local water = terrainClass == "water"
				cells[iz * cellsPerAxis + ix + 1] = {
					x = wx,
					z = wz,
					dominantBiome = biome,
					climate = env.climate,
					blocked = blocked,
					water = water,
					terrainClass = terrainClass,
					heightNoise = env.heightNoise,
					yG = env.yGround,
					yW = env.yWater,
					spawnable = (not blocked and not water),
					nodeable = (not blocked),
				}
			end
		end
	return { cx = cx, cz = cz, key = chunkKey(cx, cz), cells = cells, generatedAt = os.clock() }
end

function ChunkSystem.writeChunkTerrain(chunk)
	for _, cell in ipairs(chunk.cells) do
		local matDef = BIOME_MATS[cell.dominantBiome] or BIOME_MATS.plains
		local y = math.max(2, cell.yG or 4)
		local mat = y > 18 and matDef.high or matDef.ground
		Terrain:FillBlock(
			CFrame.new(cell.x, y * 0.5, cell.z),
			Vector3.new(ChunkSystem.CELL_SIZE, y, ChunkSystem.CELL_SIZE),
			mat
		)
		if (cell.yW or 0) > y then
			local hW = math.max(2, (cell.yW or 0) - y)
			Terrain:FillBlock(
				CFrame.new(cell.x, y + hW * 0.5, cell.z),
				Vector3.new(ChunkSystem.CELL_SIZE, hW, ChunkSystem.CELL_SIZE),
				Enum.Material.Water
			)
		end
	end
end

function ChunkSystem.clearChunkTerrain(chunk)
	local clearH = 256
	for _, cell in ipairs(chunk.cells) do
		Terrain:FillBlock(
			CFrame.new(cell.x, clearH * 0.5, cell.z),
			Vector3.new(ChunkSystem.CELL_SIZE, clearH, ChunkSystem.CELL_SIZE),
			Enum.Material.Air
		)
	end
end

function ChunkSystem.ensureLoaded(world, centerX, centerZ, radiusOverride)
	local ccx, ccz = ChunkSystem.worldToChunk(centerX, centerZ)
	local radius = radiusOverride or ChunkSystem.LOAD_RADIUS
	for dz = -radius, radius do
		for dx = -radius, radius do
			local cx, cz = ccx + dx, ccz + dz
			local key = chunkKey(cx, cz)
			if not world.chunks[key] then
				local chunk = ChunkSystem.generateChunk(cx, cz)
				world.chunks[key] = chunk
				ChunkSystem.writeChunkTerrain(chunk)
			end
		end
	end
end

function ChunkSystem.collectSpawnableCells(world)
	local out = {}
	for _, chunk in pairs(world.chunks) do
		for _, cell in ipairs(chunk.cells) do
			if cell.spawnable then table.insert(out, cell) end
		end
	end
	return out
end

return ChunkSystem
