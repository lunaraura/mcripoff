local BiomeSystem = require(script.Parent.BiomeSystem)

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

function ChunkSystem.generateChunk(cx, cz)
	local cells = {}
	local cellsPerAxis = ChunkSystem.CHUNK_SIZE / ChunkSystem.CELL_SIZE
	for iz = 0, cellsPerAxis - 1 do
		for ix = 0, cellsPerAxis - 1 do
			local wx = cx * ChunkSystem.CHUNK_SIZE + ix * ChunkSystem.CELL_SIZE
			local wz = cz * ChunkSystem.CHUNK_SIZE + iz * ChunkSystem.CELL_SIZE
			local biome = BiomeSystem.sample(wx, wz)
			local terrainClass = BiomeSystem.terrainClass(wx, wz)
			local blocked = terrainClass == "rock"
			local water = terrainClass == "water"
			cells[iz * cellsPerAxis + ix + 1] = {
				x = wx,
				z = wz,
				dominantBiome = biome,
				blocked = blocked,
				water = water,
				terrainClass = terrainClass,
				spawnable = (not blocked and not water),
				nodeable = (not blocked),
			}
		end
	end
	return { cx = cx, cz = cz, key = chunkKey(cx, cz), cells = cells, generatedAt = os.clock() }
end

function ChunkSystem.ensureLoaded(world, centerX, centerZ)
	local ccx, ccz = ChunkSystem.worldToChunk(centerX, centerZ)
	for dz = -ChunkSystem.LOAD_RADIUS, ChunkSystem.LOAD_RADIUS do
		for dx = -ChunkSystem.LOAD_RADIUS, ChunkSystem.LOAD_RADIUS do
			local cx, cz = ccx + dx, ccz + dz
			local key = chunkKey(cx, cz)
			if not world.chunks[key] then
				world.chunks[key] = ChunkSystem.generateChunk(cx, cz)
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
