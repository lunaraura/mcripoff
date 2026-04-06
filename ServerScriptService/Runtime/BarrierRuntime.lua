local BarrierRuntime = {}
BarrierRuntime.__index = BarrierRuntime

function BarrierRuntime.new(ownerId, team, position, radius, duration)
	return setmetatable({
		ownerId = ownerId,
		team = team,
		position = position,
		radius = radius,
		timeLeft = duration,
	}, BarrierRuntime)
end

function BarrierRuntime:Tick(dt)
	self.timeLeft -= dt
	return self.timeLeft > 0
end

return BarrierRuntime
