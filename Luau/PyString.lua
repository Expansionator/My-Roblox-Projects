--!nocheck
-- @fattah412

--[[

PyString:
A module encompassing string methods inherited from Python.

-----------------------------------------------------------

Notes:

- Not all Python string methods are included
- These methods are identical to Python's string methods
- splitlines() uses '\\n' as an escape character
- expandtabs() uses '\\t' as an escape character

-----------------------------------------------------------

Example Usage:

local PyString = require(game.ServerScriptService.PyString)

local str: string = "Hello, world!"
local centered = PyString.center(str, 29, "_")

print(centered)

-----------------------------------------------------------

]]

local Py = {}

function Py.encode(str: string): {number}
	local byte_chars = {}	
	local split = str:split("")
	
	for i = 1, #str, 1 do
		local value: string = split[i]
		local byte = value:byte()
		
		table.insert(byte_chars, byte)
	end
	
	return byte_chars
end

function Py.decode(encoded: {number}): string
	local decoded = ""
	for i = 1, #encoded, 1 do
		local value = encoded[i]
		local char = string.char(value)
		
		decoded = decoded..char
	end
	
	return decoded
end

function Py.count(str: string, pattern: string): number
	local similar_patterns = 0
	local content = str
	
	if pattern:lower() == "" then
		return #str
	end
	
	while content:find(pattern) do
		local startIndex, endIndex = content:find(pattern)
		local split = content:split("")
		local raw = ""
		
		local encountered_pattern = false
		for i = 1, #split, 1 do
			if i >= startIndex and i <= endIndex then
				encountered_pattern = true continue
			end
			raw = raw..split[i]
		end
		
		content = raw
		if encountered_pattern then
			similar_patterns += 1
		end
		
		task.wait()
	end
	
	return similar_patterns
end

function Py.center(str: string, width: number, filler: string?): string
	local length = #str
	local totalLength = width - length
	
	if totalLength >= 1 then
		local lengthOccupied = 0
		local leftSide = false
		local raw = str
		
		while lengthOccupied < totalLength do
			if leftSide then
				raw = (filler or " ")..raw
			else
				raw = raw..(filler or " ")
			end
			
			lengthOccupied += 1
			leftSide = not leftSide
			
			task.wait()
		end
		return raw
	end
	return str
end

function Py.ljust(str: string, width: number, filler: string?): string
	local length = #str
	local totalLength = width - length

	if totalLength >= 1 then
		local lengthOccupied = 0
		local raw = str
		
		while lengthOccupied < totalLength do
			raw = raw..(filler or " ")
			lengthOccupied += 1
			
			task.wait()
		end
		return raw
	end
	return str
end

function Py.rjust(str: string, width: number, filler: string?): string
	local length = #str
	local totalLength = width - length

	if totalLength >= 1 then
		local lengthOccupied = 0
		local raw = str

		while lengthOccupied < totalLength do
			raw = (filler or " ")..raw
			lengthOccupied += 1
			
			task.wait()
		end
		return raw
	end
	return str
end

function Py.partition(str: string, pattern: string): {string}
	local split = str:split(pattern)
	local joinedSplit = {}
	
	local leftContent = split[1]
	local rightContent = ""
	
	for i = 2, #split, 1 do
		local value: string = split[i]
		if value then
			table.insert(joinedSplit, value)
		end
	end
	
	rightContent = table.concat(joinedSplit, pattern)
	return {
		leftContent, pattern, rightContent
	}
end

function Py.rpartition(str: string, pattern: string): {string}
	local split = str:split(pattern)
	local joinedSplit = {}

	local rightContent = split[#split]
	local leftContent = ""

	for i = 1, (#split - 1), 1 do
		local value: string = split[i]
		if value then
			table.insert(joinedSplit, value)
		end
	end
	
	leftContent = table.concat(joinedSplit, pattern)
	return {
		leftContent, pattern, rightContent
	}
end

function Py.isalpha(str: string): boolean
	local min, max = 97, 122
	
	local split = str:split("")
	local isAlpha = true
	
	for i = 1, #split, 1 do
		local value: string = split[i]:lower()
		local byte = value:byte()
		
		if byte >= min and byte <= max then
			continue
		end
		
		isAlpha = false
		break
	end
	
	return isAlpha
end

function Py.isdecimal(str: string): boolean
	local min, max = 48, 57

	local split = str:split("")
	local isdecimal = true

	for i = 1, #split, 1 do
		local value: string = split[i]:lower()
		local byte = value:byte()

		if byte >= min and byte <= max then
			continue
		end

		isdecimal = false
		break
	end

	return isdecimal
end

function Py.isalnum(str: string): boolean
	local alphaMin, alphaMax = 97, 122
	local numMin, numMax = 48, 57
	
	local split = str:split("")
	local isalnum = true

	for i = 1, #split, 1 do
		local value: string = split[i]:lower()
		local byte = value:byte()

		if byte >= alphaMin and byte <= alphaMax
			or byte >= numMin and byte <= numMax then
				continue
		end

		isalnum = false
		break
	end

	return isalnum
end

function Py.isascii(str: string): boolean
	local min, max = 0, 127

	local split = str:split("")
	local isascii = true

	for i = 1, #split, 1 do
		local value: string = split[i]:lower()
		local byte = value:byte()

		if byte >= min and byte <= max then
			continue
		end

		isascii = false
		break
	end

	return isascii
end

function Py.isspace(str: string): boolean
	return str:gsub("%s+", " ") == " "
end

function Py.istitle(str: string): boolean
	local split = str:gsub("%s+", "_"):split("_")
	local istitle = true
	
	for _, value: string in split do
		local firstChar = value:sub(1, 1)
		if firstChar:upper() == firstChar then
			continue
		end
		
		istitle = false
		break
	end

	return istitle
end

function Py.isupper(str: string): boolean
	return str:upper() == str
end

function Py.islower(str: string): boolean
	return str:lower() == str
end

function Py.splitlines(str: string, keepends: boolean?): {string}	
	local split = str:split("\\n")
	if keepends then
		for index: number, value: string in split do
			split[index] = value.."\\n"
		end
	end
	
	return split
end

function Py.replace(str: string, from: string, to: string, replacements: number?): string
	local modified_str = str:gsub(from, to, replacements)
	return modified_str
end

function Py.index(str: string, match: string): number
	local startIndex = str:find(match)
	return startIndex and startIndex - 1 or -1
end

function Py.rindex(str: string, match: string): number
	local split = str:split("")
	local joined = ""
	
	local indexStop
	for i = #str, 1, -1 do
		local value: string = split[i]
		joined = value..joined
		
		if joined:match(match) then
			indexStop = i - 1
			break
		end
	end
	
	return indexStop or -1
end

function Py.strip(str: string, chars: string?): string
	local content = ""
	local split = str:split("")
	
	local startIndex = 1
	for i = 1, #str, 1 do
		local value: string = split[i]
		if value ~= (chars or " ") then
			startIndex = i
			break
		end
	end
	
	local endIndex = #str
	for i = #str, 1, -1 do
		local value: string = split[i]
		if value ~= (chars or " ") then
			endIndex = i
			break
		end
	end
	
	content = str:sub(startIndex, endIndex)
	return content
end

function Py.rstrip(str: string, chars: string?): string
	local content = ""
	local split = str:split("")
	
	local endIndex = #str
	for i = #str, 1, -1 do
		local value: string = split[i]
		if value ~= (chars or " ") then
			endIndex = i
			break
		end
	end
	
	content = str:sub(1, endIndex)
	return content
end

function Py.lstrip(str: string, chars: string?): string
	local content = ""
	local split = str:split("")

	local startIndex = 1
	for i = 1, #str, 1 do
		local value: string = split[i]
		if value ~= (chars or " ") then
			startIndex = i
			break
		end
	end

	content = str:sub(startIndex, #str)
	return content
end

function Py.join(str: string, list: {string}): string
	return table.concat(list, str)
end

function Py.expandtabs(str: string, tabsize: number?): string
	local gsub = str:gsub("\\t", (" "):rep(tabsize or 8))
	return gsub
end

function Py.removeprefix(str: string, prefix: string): string	
	if str:sub(1, #prefix) == prefix then
		return str:sub(#prefix + 1)
	end
	return str
end

function Py.removesuffix(str: string, suffix: string): string
	if str:sub(-#suffix) == suffix then
		return str:sub(1, -#suffix - 1)
	end
	return str
end

function Py.format_map(str: string, dict: {[string]: string | number}): string
	local availableMethods = {}
	for method: string, _ in dict do
		table.insert(availableMethods, method)
	end
	
	local formatted_str = str
	for _, method: string in availableMethods do
		local pattern = "{"..method.."}"
		local value = dict[method]
		
		formatted_str = formatted_str:gsub(pattern, value)
	end
	
	return formatted_str
end

function Py.swapcase(str: string): string
	local split = str:split("")
	local content = ""
	
	for i = 1, #split, 1 do
		local value: string = split[i]
		if value:upper() == value then
			value = value:lower()
		elseif value:lower() == value then
			value = value:upper()
		end
		content = content..value
	end
	
	return content
end

function Py.title(str: string): string
	local noSpace = str:gsub("%s+", "_")
	local split = noSpace:split("_")
	
	for index: number, value: string in split do
		local firstChar = value:sub(1, 1):upper()
		local remainingChar = value:sub(2, #value):lower()
		
		split[index] = firstChar..remainingChar
	end
	
	return table.concat(split, " ")
end

function Py.startswith(str: string, pattern: string): boolean
	local startIndex, endIndex = str:find(pattern)
	if startIndex and endIndex then
		if startIndex == 1 then
			return true
		end
	end
	return false
end

function Py.endswith(str: string, pattern: string): boolean
	local startIndex, endIndex = str:find(pattern)
	if startIndex and endIndex then
		if endIndex == #str then
			return true
		end
	end
	return false
end

function Py.capitalize(str: string): string
	local sub = str:sub(2, #str):lower()
	local content = str:sub(1, 1):upper()..sub
	
	return content
end

function Py.casefold(str: string): string
	return str:lower()
end

function Py.zfill(str: string, width: number): string
	return ("0"):rep(width)..str
end

return Py