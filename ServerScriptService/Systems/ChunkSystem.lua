local BiomeSystem = require(script.Parent.BiomeSystem)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Terrain = workspace.Terrain
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local FloraSystem = require(script.Parent.FloraSystem)

local ChunkSystem = {}
ChunkSystem.CHUNK_SIZE = 64
ChunkSystem.CELL_SIZE = 8
ChunkSystem.LOAD_RADIUS = 2

local ORTHOGONAL_STEP = ChunkSystem.CELL_SIZE
local DIAGONAL_STEP = ChunkSystem.CELL_SIZE * math.sqrt(2)

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
	local biomeMixTotals = {}
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
			local biomeMix = env.biomeMix or { [biome] = 1 }
			for biomeKey, weight in pairs(biomeMix) do
				biomeMixTotals[biomeKey] = (biomeMixTotals[biomeKey] or 0) + weight
			end
				cells[iz * cellsPerAxis + ix + 1] = {
					x = wx,
					z = wz,
					dominantBiome = biome,
					biomeMix = biomeMix,
					climate = env.climate,
					blocked = blocked,
					water = water,
					terrainClass = terrainClass,
					heightNoise = env.heightNoise,
					yG = env.yGround,
					yW = env.yWater,
					slope = 0,
					moveCost = water and 2.2 or (blocked and math.huge or 1),
					spawnable = (not blocked and not water),
					nodeable = (not blocked),
				}
			end
		end

	local function getCell(ix, iz)
		if ix < 0 or iz < 0 or ix >= cellsPerAxis or iz >= cellsPerAxis then
			return nil
		end
		return cells[iz * cellsPerAxis + ix + 1]
	end

	for iz = 0, cellsPerAxis - 1 do
		for ix = 0, cellsPerAxis - 1 do
			local cell = getCell(ix, iz)
			local y = cell.yG or 0
			local dx = 0
			local dz = 0

			local west = getCell(ix - 1, iz)
			local east = getCell(ix + 1, iz)
			local north = getCell(ix, iz - 1)
			local south = getCell(ix, iz + 1)

			if west and east then
				dx = ((east.yG or y) - (west.yG or y)) / (2 * ORTHOGONAL_STEP)
			elseif east then
				dx = ((east.yG or y) - y) / ORTHOGONAL_STEP
			elseif west then
				dx = (y - (west.yG or y)) / ORTHOGONAL_STEP
			end

			if north and south then
				dz = ((south.yG or y) - (north.yG or y)) / (2 * ORTHOGONAL_STEP)
			elseif south then
				dz = ((south.yG or y) - y) / ORTHOGONAL_STEP
			elseif north then
				dz = (y - (north.yG or y)) / ORTHOGONAL_STEP
			end

			local ne = getCell(ix + 1, iz - 1)
			local nw = getCell(ix - 1, iz - 1)
			local se = getCell(ix + 1, iz + 1)
			local sw = getCell(ix - 1, iz + 1)
			local diagDx, diagDz = 0, 0
			if nw and ne and sw and se then
				diagDx = ((ne.yG + se.yG) - (nw.yG + sw.yG)) / (4 * DIAGONAL_STEP)
				diagDz = ((sw.yG + se.yG) - (nw.yG + ne.yG)) / (4 * DIAGONAL_STEP)
				dx = dx * 0.7 + diagDx * 0.3
				dz = dz * 0.7 + diagDz * 0.3
			end

			local slope = math.sqrt(dx * dx + dz * dz)
			cell.slope = slope
			if cell.blocked then
				cell.moveCost = math.huge
			elseif cell.water then
				cell.moveCost = 2.2 + slope * 3.2
			else
				cell.moveCost = 1 + slope * 2.6
			end
		end
	end

	local biomeMixSummary = {}
	local dominantBiome, dominantWeight = "plains", -math.huge
	local totalCells = math.max(1, #cells)
	for biomeKey, totalWeight in pairs(biomeMixTotals) do
		local normalized = totalWeight / totalCells
		biomeMixSummary[biomeKey] = normalized
		if normalized > dominantWeight then
			dominantWeight = normalized
			dominantBiome = biomeKey
		end
	end

	return {
		cx = cx,
		cz = cz,
		key = chunkKey(cx, cz),
		cells = cells,
		biomeMixSummary = biomeMixSummary,
		dominantBiome = dominantBiome,
		generatedAt = os.clock(),
	}
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
	FloraSystem.unloadChunk(chunk.key)
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
					FloraSystem.scatterChunk(chunk)
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
