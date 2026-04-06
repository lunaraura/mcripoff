local BiomeSystem = {}

function BiomeSystem.sample(x, z)
	local temp = 0.5 + math.noise(x * 0.004, z * 0.004) * 0.35
	if temp >= 0.55 then
		return "plains"
	end
	return "stormfield"
end

function BiomeSystem.terrainClass(x, z)
	local h = math.noise(x * 0.01, z * 0.01)
	if h < -0.35 then return "water" end
	if h > 0.55 then return "rock" end
	return "ground"
end

return BiomeSystem
