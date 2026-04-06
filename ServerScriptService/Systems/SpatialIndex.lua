local SpatialIndex = {}

function SpatialIndex.findNearestCreature(creatures, fromPos, predicate, maxRange)
	local best, bestDist = nil, maxRange or math.huge
	for _, c in pairs(creatures) do
		if c.alive and (not predicate or predicate(c)) then
			local d = (Vector3.new(fromPos.X, 0, fromPos.Z) - Vector3.new(c.pos.X, 0, c.pos.Z)).Magnitude
			if d < bestDist then
				best = c
				bestDist = d
			end
		end
	end
	return best, bestDist
end

return SpatialIndex
