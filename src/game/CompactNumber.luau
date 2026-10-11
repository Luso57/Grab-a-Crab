local SUFFIXES = {
	{ threshold = 1e33, suffix = "D" },
	{ threshold = 1e30, suffix = "No" },
	{ threshold = 1e27, suffix = "Oc" },
	{ threshold = 1e24, suffix = "Sp" },
	{ threshold = 1e21, suffix = "Sx" },
	{ threshold = 1e18, suffix = "Qi" },
	{ threshold = 1e15, suffix = "Qa" },
	{ threshold = 1e12, suffix = "T" },
	{ threshold = 1e9, suffix = "B" },
	{ threshold = 1e6, suffix = "M" },
	{ threshold = 1e3, suffix = "K" },
}

local CompactNumber = {}

function CompactNumber.format(value: number, decimalPlaces: number?, lowercaseSuffix: boolean?): string
	if value ~= value then
		return "0"
	elseif value == math.huge then
		return "inf"
	elseif value == -math.huge then
		return "-inf"
	end

	local decimals = math.clamp(math.floor(decimalPlaces or 1), 0, 3)
	if math.abs(value) >= 1e36 then
		return string.format(`%.{decimals}e`, value)
	end

	for _, entry in SUFFIXES do
		if math.abs(value) >= entry.threshold then
			local formatString = "%." .. tostring(decimals) .. "f"
			local formatted = string.format(formatString, value / entry.threshold)
			if decimals > 0 then
				formatted = string.gsub(formatted, "0+$", "")
				formatted = string.gsub(formatted, "%.$", "")
			end

			local suffix = if lowercaseSuffix then string.lower(entry.suffix) else entry.suffix
			return formatted .. suffix
		end
	end

	return tostring(math.floor(value))
end

return CompactNumber
