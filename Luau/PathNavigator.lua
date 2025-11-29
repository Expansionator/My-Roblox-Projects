--!nocheck
-- @fattah412

--[[

PathNavigator:
This module helps you easily find and get things in your game by using custom paths to search for objects.

-------------------------------------------------------------------------------

Notes:

- 'DIRECTORY_CHAR' and 'CLASSTYPE_CHAR' are editable
- 'CLASSTYPE_CHAR' is used to search class names or data types inside a parent
	> Wrap the data type and pattern in curly brackets ({})
		> The data inside should contain: {classname or datatype: string | "index" or "value": string}
	> For example: "My Test Table/**/{string|value}" and "My Models/**/{Model|value}"
- If there's a special character inside a path, everything after it will be ignored
- If a path is invalid, or no value/object was found, it will return nil
- In order to index and search for numbers, you have to set 'convertStrToNumbers' to true
- There must be no spaces inside a path, and there cannot be the same special character within the names of objects
- Highly recommended to see the 'Example Usage' section for a real-world example

-------------------------------------------------------------------------------

Usage:

Path.filePath(path: string, tab: {}, convertStrToNumbers: boolean): any
> Description: Searches for a value inside a table
> Returns: any

Path.objPath(path: string, parentInstance: Instance, convertStrToNumbers: boolean): Instance | {Instance}
> Description: Searches for an Instance, using the parent instance to locate the object
> Returns: Instance | {Instance}

-------------------------------------------------------------------------------

Example Usage:

local Path = require(game.ServerScriptService.PathNavigator)
local templateTable = {
	["Test Table"] = {
		["Test Values"] = {
			["Dict"] = "My Dictionary",
			["456"] = "My Number which is a string",
			["Testing Bool"] = true,
			123
		};
	}
}

local mainPath = Path.filePath("Test Table/Test Values/123", templateTable, true)
local tablePath = Path.filePath("Test Table/Test Values/**/{string|value}", templateTable)

local contentsInBaseplate = Path.objPath("Baseplate/", workspace)
local decalsInBaseplate = Path.objPath("Baseplate/**/{Decal|value}", workspace)
local baseplate = Path.objPath("Baseplate", workspace)

print("Result:", baseplate, decalsInBaseplate, contentsInBaseplate)
print("Result:", mainPath, tablePath)

-------------------------------------------------------------------------------

]]

local Path = {}

local DIRECTORY_CHAR = "/" -- The prefix used to search another directory
local CLASSTYPE_CHAR = "**" -- The prefix used to search for class names or data types

local function toNumberPath(paths: {string})
	local t = {}
	for _, dir in paths do
		local char = tonumber(dir)
		table.insert(t, char or dir)
	end

	return t
end

local function countTableTypes(t: {})
	local count = 0
	for _, _ in t do
		count += 1
	end
	return count
end

local function containsSpecialChars(paths: {})
	local containsSpecials
	for index, dir in paths do
		if dir == CLASSTYPE_CHAR then
			containsSpecials = true break
		end
	end
	return containsSpecials
end

local function isDataTypeValid(str: string)
	return str and str:find("{") and str:find("}") and true
end

local function getDataAndType(pattern: string)
	pattern = pattern:gsub("{", "")
	pattern = pattern:gsub("}", "")

	local classes = pattern:find("|") and pattern:split("|")
	if classes ~= nil and #classes >= 2 then
		local dataType, patternType = classes[1], classes[2]
		if patternType == "index" or patternType == "value" then
			return dataType, patternType
		end
	end
end

local function getSpecial(paths: {string}, pos: number, lastDir, callBack: (dir: any, patt: string, class: string) -> {} | nil)
	local afterDir = paths[pos + 1]
	if lastDir and paths[pos] == CLASSTYPE_CHAR and isDataTypeValid(afterDir) then
		local datatype: string, pattern: string = getDataAndType(afterDir)
		if datatype and pattern and typeof(lastDir) == "table" then
			return callBack(lastDir, pattern, datatype)
		end
	end
end

local function breakPath(path: string, convertStrToNumbers: boolean)
	local lastCharacter = path:sub(#path, #path)
	local contents = path:split(DIRECTORY_CHAR)

	if contents[#contents]:gsub("%s+", "") == "" then
		contents[#contents] = nil
	end

	contents = convertStrToNumbers and toNumberPath(contents) or contents

	if lastCharacter == DIRECTORY_CHAR then
		return contents, true
	end
	return contents, false
end

function Path.filePath(path: string, tab: {}, convertStrToNumbers: boolean): any
	local paths, childrenAccounted = breakPath(path, convertStrToNumbers)
	local containsSpecial = containsSpecialChars(paths)
	local lastDirectory, lastTable

	local function onSpecialFound(dir, patt: string, class: string)
		local content = {}
		for index, value in dir do
			if patt == "index" and typeof(index) == class then
				content[index] = value
			elseif patt == "value" and typeof(value) == class then
				content[index] = value
			end
		end

		return countTableTypes(content) >= 1 and content
	end

	for index, dir in paths do
		local anySpecials = containsSpecial and getSpecial(paths, index, lastDirectory, onSpecialFound)
		lastDirectory = index == 1 and tab[dir] or lastDirectory[dir]

		if anySpecials then lastDirectory = anySpecials break end
		if lastDirectory == nil then
			if lastTable and table.find(lastTable, dir) then
				if dir == paths[#paths] and not childrenAccounted then
					lastDirectory = dir
				end
			end
			break
		end

		if typeof(lastDirectory) == "table" then
			lastTable = lastDirectory
		end
	end

	return lastDirectory
end

function Path.objPath(path: string, parentInstance: Instance, convertStrToNumbers: boolean): Instance | {Instance}
	local paths, childrenAccounted = breakPath(path, convertStrToNumbers)
	local containsSpecial = containsSpecialChars(paths)
	local lastInstance = parentInstance
	local returnedObject

	local function onSpecialFound(dir, patt: string, class: string)
		local content = {}
		for index, value in dir do
			if patt == "index" and typeof(index) == "Instance" and index:IsA(class) then
				table.insert(content, index)
			elseif patt == "value" and typeof(value) == "Instance" and value:IsA(class) then
				table.insert(content, value)
			end
		end

		return countTableTypes(content) >= 1 and content
	end

	for index, dir in paths do
		local anySpecials = containsSpecial and getSpecial(paths, index, lastInstance and lastInstance:GetChildren(), onSpecialFound)
		lastInstance = lastInstance and lastInstance:FindFirstChild(dir)

		if anySpecials then returnedObject = anySpecials break end
		if not lastInstance then
			break
		end
	end

	if lastInstance and not returnedObject then
		if childrenAccounted then
			returnedObject = lastInstance:GetChildren()
		else
			returnedObject = lastInstance
		end
	end

	return returnedObject
end

return Path