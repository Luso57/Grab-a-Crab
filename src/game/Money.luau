--!strict

local Money = {}

local SUFFIXES = {
	"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "D",
	"Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg",
}

local function clean(value: any): string
	if typeof(value) == "number" then
		if value ~= value or value <= 0 or value == math.huge then
			return "0"
		end
		value = string.format("%.0f", math.floor(value))
	end
	if typeof(value) ~= "string" or not string.match(value, "^%d+$") then return "0" end
	local result = string.gsub(value, "^0+", "")
	return if result == "" then "0" else result
end

function Money.normalize(value: any): string
	return clean(value)
end

function Money.get(data: any, key: string): string
	local old = data[key]()
	local value = clean(old)
	if old ~= value then
		data[key](value)
	end
	return value
end

function Money.set(data: any, key: string, value: any)
	data[key](clean(value))
end

function Money.compare(left: any, right: any): number
	local a, b = clean(left), clean(right)
	if #a ~= #b then return if #a < #b then -1 else 1 end
	if a == b then return 0 end
	return if a < b then -1 else 1
end

function Money.add(left: any, right: any): string
	local a, b = clean(left), clean(right)
	local i, j, carry = #a, #b, 0
	local digits = {}
	while i > 0 or j > 0 or carry > 0 do
		local x = if i > 0 then string.byte(a, i) - 48 else 0
		local y = if j > 0 then string.byte(b, j) - 48 else 0
		local sum = x + y + carry
		table.insert(digits, string.char(48 + sum % 10))
		carry = math.floor(sum / 10)
		i -= 1
		j -= 1
	end
	for index = 1, math.floor(#digits / 2) do
		digits[index], digits[#digits - index + 1] = digits[#digits - index + 1], digits[index]
	end
	return table.concat(digits)
end

function Money.subtract(left: any, right: any): string
	local a, b = clean(left), clean(right)
	if Money.compare(a, b) <= 0 then return "0" end
	local i, j, borrow = #a, #b, 0
	local digits = {}
	while i > 0 do
		local x = string.byte(a, i) - 48 - borrow
		local y = if j > 0 then string.byte(b, j) - 48 else 0
		borrow = if x < y then 1 else 0
		if borrow > 0 then
			x += 10
		end
		table.insert(digits, string.char(48 + x - y))
		i -= 1
		j -= 1
	end
	for index = 1, math.floor(#digits / 2) do
		digits[index], digits[#digits - index + 1] = digits[#digits - index + 1], digits[index]
	end
	return clean(table.concat(digits))
end

function Money.multiplySmall(value: any, multiplier: number): string
	local a = clean(value)
	if multiplier ~= multiplier or multiplier < 0 or multiplier == math.huge then return "0" end
	multiplier = math.floor(multiplier)
	local carry = 0
	local digits = {}
	for index = #a, 1, -1 do
		local product = (string.byte(a, index) - 48) * multiplier + carry
		table.insert(digits, string.char(48 + product % 10))
		carry = math.floor(product / 10)
	end
	while carry > 0 do
		table.insert(digits, string.char(48 + carry % 10))
		carry = math.floor(carry / 10)
	end
	for index = 1, math.floor(#digits / 2) do
		digits[index], digits[#digits - index + 1] = digits[#digits - index + 1], digits[index]
	end
	return clean(table.concat(digits))
end

function Money.log10(value: any): number
	local digits = clean(value)
	if digits == "0" then return 0 end
	if #digits <= 15 then
		return math.log10(tonumber(digits) or 1)
	end
	local leading = tonumber(string.sub(digits, 1, 15)) or 0
	return if leading == 0 then 0 else #digits - 15 + math.log10(leading)
end

function Money.format(value: any, decimalPlaces: number?): string
	local digits = clean(value)
	if #digits <= 3 then return digits end
	local group = math.floor((#digits - 1) / 3)
	local leadingCount = #digits - group * 3
	local decimals = math.clamp(math.floor(decimalPlaces or 2), 0, 2)
	local rounded = (tonumber(string.sub(digits, 1, leadingCount + decimals + 1)) or 0) / (10 ^ (decimals + 1))
	rounded = math.floor(rounded * (10 ^ decimals) + 0.5) / (10 ^ decimals)
	local carriedGroup = rounded >= 1000
	if carriedGroup then
		group += 1
		rounded = 1
	end
	local mantissa = string.format("%." .. tostring(decimals) .. "f", rounded)
	if decimals > 0 then
		mantissa = string.gsub(string.gsub(mantissa, "0+$", ""), "%.$", "")
	end
	local suffix = SUFFIXES[group + 1]
	if suffix then return mantissa .. suffix end
	local exponent = #digits - 1 + (if carriedGroup or rounded >= 10 then 1 else 0)
	local scientific = string.format("%." .. tostring(decimals) .. "f", if rounded >= 10 then 1 else rounded)
	scientific = string.gsub(string.gsub(scientific, "0+$", ""), "%.$", "")
	return scientific .. "e" .. tostring(exponent)
end

return Money
