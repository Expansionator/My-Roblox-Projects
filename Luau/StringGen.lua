--!nocheck
-- @fattah412

--[[

StringGen:
A string generator used to generate unused randomized strings.

------------------------------------------------------------------------------

Notes:

- Exceeding the character length (that was specified) will cause it to not use the exceeded characters
- The total amount of characters must be >= the character length 
- This is an alternative to game.HttpService:GenerateGUID()
- If there is already an existing code, it will attempt to regenerate before returning nil (uses the specified threshold)
- This system may be used for internal operations like secrets
- There must be 2 or more characters for it to work

------------------------------------------------------------------------------

Usage:

--> CustomSettings:

		> IncludeLowerCaseOnly: boolean
		> IncludeUpperCaseOnly: boolean
		> IncludeMixCases: boolean

--> Functions:

StringGen.GetSpecialCharacters()
> Description: Returns the special characters used to assist in randomizing a string
> Returns: string

StringGen.GenerateCustomCode()
> Description: Generates a custom code that is hard-coded inside the function
> Returns: string | nil | void

StringGen.Generate(length: number, chars: string, customSettings: CustomSettings)
> Description: Uses a custom generator function to generate a custom code
> Returns: string | nil | void

------------------------------------------------------------------------------

Example Usage:

local StringGen = require(game.ServerScriptService.StringGen)

local length = 30
local characters = "abcdefghijklmnopqrst123456789-"
local customSettings = {
	IncludeMixCases = true;
}

for _ = 1, 3 do
	local randomized_string = StringGen.Generate(length, characters, customSettings)
	print('My string is:', randomized_string)
end

print('Auto generated string is: ', StringGen.GenerateCustomCode())

------------------------------------------------------------------------------

]]

local StringGen = {}
local STORED_GENERATED_STRINGS = {}
local THRESHOLD = 10

export type CustomSettings = {
	IncludeLowerCaseOnly: boolean?,
	IncludeUpperCaseOnly: boolean?,
	IncludeMixCases: boolean?,
}

function StringGen.GetSpecialCharacters()
	return "!#$%&'()*+,-./:;<=>?@[]^_`{|}~"
end

function StringGen.GenerateCustomCode()
	local maxCharacters = 40
	local specialChars = StringGen.GetSpecialCharacters()
	local hard_coded_string = ""
	local chosen_keys = {}

	for i = 1, maxCharacters do
		local dec = math.clamp(64 + i, 64, 126)
		hard_coded_string = hard_coded_string..string.char(dec)
	end

	for _, v in (maxCharacters >= 2 and specialChars:split("")) or {} do
		local i = math.random(2, #hard_coded_string)
		if not chosen_keys[i] then
			local front = hard_coded_string:sub(1, i - 1)
			local back = hard_coded_string:sub(i + 1, #hard_coded_string)

			chosen_keys[i] = true
			hard_coded_string = front..v..back
		end
	end

	return StringGen.Generate(maxCharacters, hard_coded_string, {
		IncludeMixCases = true;
	})
end

function StringGen.Generate(length: number, chars: string, customSettings: CustomSettings)
	assert(length >= 2, "Length must be more or equals to 2!")
	assert(#chars >= length, "Characters must be equal to the required length!")

	chars = chars:sub(1, length)

	local splits = chars:split("")
	for i, v in splits do
		if v:gsub("%s+", "") == "" then
			table.remove(splits, i)
		end
	end

	table.sort(splits)
	local custom_Generated_String = ""

	for _ = 1, length do
		local index = math.random(#splits)
		local randomChar = splits[index]

		if customSettings then
			if customSettings.IncludeMixCases then
				randomChar = math.random(2) == 1 and randomChar:lower() or randomChar:upper()
			elseif customSettings.IncludeUpperCaseOnly then
				randomChar = randomChar:upper()
			elseif customSettings.IncludeLowerCaseOnly then
				randomChar = randomChar:lower()
			end
		end

		custom_Generated_String = custom_Generated_String..randomChar

		table.remove(splits, index)
		table.sort(splits)
	end

	if STORED_GENERATED_STRINGS[custom_Generated_String] then
		if STORED_GENERATED_STRINGS[custom_Generated_String] < THRESHOLD then
			STORED_GENERATED_STRINGS[custom_Generated_String] += 1
			return StringGen.Generate(length, chars, customSettings) 
		end
	else
		STORED_GENERATED_STRINGS[custom_Generated_String] = 1
		return custom_Generated_String
	end
end

return StringGen