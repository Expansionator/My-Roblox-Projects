--!nocheck
-- @fattah412

--[[

TextFiller:
Fills in the spaces from a text using a filler and adding a text after it.

-------------------------------------------------

Notes:

- max_chars does not count the amount of characters that is in after_text
- max_chars counts the total length that a text should have which includes the main text
- max_chars needs to be more than the length of the main text + 1 (added to have a space that can be filled)
- FillDictionary() table format is [main text] = after text
- FillDictionary() returns an array

-------------------------------------------------

Example Usage:

local TextFiller = require(game.ServerScriptService.TextFiller)

local filler = "_"
local afterText = "OK"
local base = 5

do
	local myArray = {
		"Starting Systems", "Initialization Complete"
	}

	local maxChars = TextFiller.FindMaxCharsFromTable(myArray) + base
	local newArray = TextFiller.FillArray(myArray, maxChars, filler, afterText)

	print("Array:", newArray)
end

do
	local myDictionary = {
		["Starting Systems"] = "OK",
		["Initialization Complete"] = "YES"
	}

	local maxChars = TextFiller.FindMaxCharsFromTable(myDictionary) + base
	local newArrayFromDict = TextFiller.FillDictionary(myDictionary, maxChars, filler, true)
	
	print("Dictionary:", newArrayFromDict)
end

-------------------------------------------------

]]

local TextFiller = {}

local function countDictionary(t: {}): number
	local n = 0
	for _ in t do
		n += 1
	end
	
	return n
end

function TextFiller.Fill(text: string, max_chars: number, filler: string, after_text: string): string
	local textLength = #text
	local spaceLeft = max_chars - textLength
	local fill = filler:rep(spaceLeft)
	
	local newText = text..fill..after_text
	return newText
end

function TextFiller.ReverseFill(text: string, max_chars: number, filler: string, after_text: string): string
	local afterTextLength = #after_text
	local spaceLeft = max_chars - afterTextLength
	local fill = filler:rep(spaceLeft)

	local newText = after_text..fill..text
	return newText
end

function TextFiller.FindMaxCharsFromTable(t: {string} | {[string]: string}): number
	if #t ~= 0 or countDictionary(t) ~= 0 then
		local lengthsTable = {}
		for index: string | number, value: string in t do
			table.insert(lengthsTable, (#t ~= 0 and #value or #index))
		end
		
		table.sort(lengthsTable, function(a, b)
			return a > b
		end)
		return lengthsTable[1]
	end	
	return nil
end

function TextFiller.FillArray(textTable: {string}, max_chars: number, filler: string, after_text: string, reverse: boolean?): {string}
	local newInserts = {}
	for _, value in textTable do
		local newText = TextFiller[reverse and "ReverseFill" or "Fill"](value, max_chars, filler, after_text)
		table.insert(newInserts, newText)
	end
	
	return newInserts
end

function TextFiller.FillDictionary(textTable: {[string]: string}, max_chars: number, filler: string, reverse: boolean?): {string}
	local newInserts = {}
	for value, after_text in textTable do
		local newText = TextFiller[reverse and "ReverseFill" or "Fill"](value, max_chars, filler, after_text)
		table.insert(newInserts, newText)
	end

	return newInserts
end

return TextFiller