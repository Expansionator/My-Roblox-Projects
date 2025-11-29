--!nocheck
-- @fattah412

--[[

TableConverter:
A module to convert a type of table into another.

-------------------------------------------------

Notes:

- DictionaryToArray() does not convert in chronological order

-------------------------------------------------

Example Usage:

local TableConverter = require(script.TableConverter)

local myTableInArray = {
	"Hey", "Cheese", 123, true, false, {}, nil
}

local myTableInDictionary = {
	Hey = "Hi",
	[123] = "Number",
	[{}] = {},
}

local newDictFromArray = TableConverter.ArrayToDictionary(myTableInArray, function(Step: number, Value): any 
	return Step - 1
end)

local newArrayFromDict = TableConverter.DictionaryToArray(myTableInDictionary)

print(newDictFromArray)
print(newArrayFromDict)

-------------------------------------------------

]]

local TableConverter = {}

function TableConverter.ArrayToDictionary(TabInArray: {any}, CustomKey: (Step: number, Value: any) -> any?): {[any]: any}
	local newDictionary = {}
	
	for index = 1, #TabInArray do
		local value: any = TabInArray[index]
		local customKey: any = typeof(CustomKey) == "function" and CustomKey(index, value)
		
		if customKey then
			newDictionary[customKey] = value
			continue
		end
		newDictionary[index] = value
	end
	
	return newDictionary
end

function TableConverter.DictionaryToArray(TabInDictionary: {[any]: any}, UseKeysAsValues: boolean?): {any}
	local newArray = {}
	
	for index: any, value: any in TabInDictionary do
		if UseKeysAsValues then
			table.insert(newArray, index)
			continue
		end
		table.insert(newArray, value)
	end
	
	return newArray
end

return TableConverter