local MathUtil = {}

function MathUtil.clamp(v, minV, maxV)
	return math.max(minV, math.min(maxV, v))
end

function MathUtil.distance2D(a, b)
	local dx = (b.X or b.x) - (a.X or a.x)
	local dz = (b.Z or b.z) - (a.Z or a.z)
	return math.sqrt(dx * dx + dz * dz)
end

function MathUtil.normalize2D(x, z)
	local len = math.sqrt(x * x + z * z)
	if len <= 1e-6 then
		return 0, 0
	end
	return x / len, z / len
end

function MathUtil.pickWeighted(entries, rng)
	rng = rng or Random.new()
	local total = 0
	for _, e in ipairs(entries) do
		total += (e.weight or 0)
	end
	if total <= 0 then
		return entries[1] and entries[1].key or nil
	end
	local r = rng:NextNumber(0, total)
	for _, e in ipairs(entries) do
		r -= (e.weight or 0)
		if r <= 0 then
			return e.key
		end
	end
	return entries[#entries] and entries[#entries].key or nil
end

return MathUtil
