local TableUtil = {}

function TableUtil.shallowCopy(src)
	local out = {}
	for k, v in pairs(src or {}) do
		out[k] = v
	end
	return out
end

function TableUtil.deepCopy(src)
	if type(src) ~= "table" then
		return src
	end
	local out = {}
	for k, v in pairs(src) do
		out[k] = TableUtil.deepCopy(v)
	end
	return out
end

function TableUtil.merge(base, overrides)
	local out = TableUtil.shallowCopy(base)
	for k, v in pairs(overrides or {}) do
		out[k] = v
	end
	return out
end

return TableUtil
