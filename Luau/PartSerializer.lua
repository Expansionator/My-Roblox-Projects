--!nocheck
-- @fattah412

--[[

PartSerializer:
A module that allows you to serialize and deserialize basepart properties.

----------------------------------------------------------------------

Notes:

- Not all properties are savable
- When serializing, the string that is returned must *not* be edited
- Only BaseParts are accepted. (e.g Part, MeshPart & WedgePart)
- When serializing multiple BaseParts, the total size will increase drastically if all properties are used
- This can be used as data inside Datastores
- See "export type Properties" for a list of savable properties

----------------------------------------------------------------------

Usage:

--> Functions:

PartSerializer.Serialize(Basepart: BasePart, DataToSerialize: Properties)
> Description: Converts the basepart properties into a string
> Returns: string

PartSerializer.Deserialize(Basepart: BasePart, DataToDeserialize: string)
> Description: Converts the serialized string back into basepart properties
> Returns: BasePart

PartSerializer.MultiSerialize(Baseparts: {BasePart}, DataToSerialize: Properties)
> Description: Converts multiple baseparts into a table of strings
> Returns: {string}

PartSerializer.GetDefaultProperties()
> Description: Returns a table of default properties that can be used to serialize
> Returns: Properties

PartSerializer.GetPropertiesWithWhitelist(Whitelist: Properties)
> Description: Returns a table of properties that are in the whitelist
> Returns: Properties

PartSerializer.GetPropertiesWithBlacklist(Blacklist: Properties)
> Description: Returns a table of properties that are not in the blacklist
> Returns: Properties

PartSerializer.IsDataUnder4MegaBytes(SerializedData: string, ComparitiveValue: any?)
> Description: Returns true if the serialized data is under 4MB, and the total size it occupies
> Returns: boolean, number

----------------------------------------------------------------------

Example Usage:
[Server]

local PartSerializator = require(game.ServerScriptService.PartSerializer)
local Basepart = Instance.new("Part", workspace)

Basepart.Name = "My Testing Part"
Basepart.Anchored = true
Basepart.Position = Vector3.new(5, 10.5, 3.251)
Basepart.Color = Color3.fromRGB(255, 150, 100)
Basepart.Transparency = 0.5555

local PropertiesToSave = PartSerializator.GetPropertiesWithBlacklist({
	Archivable = true; MaterialVariant = false;
})

local SerializedData: string = PartSerializator.Serialize(Basepart, PropertiesToSave)
local DeSerializedBasepart: Part = PartSerializator.Deserialize(SerializedData)
local IsDataUnder4MB: boolean, TotalSizeInMB: number = 
	PartSerializator.IsDataUnder4MegaBytes(SerializedData)

print(SerializedData, DeSerializedBasepart.Name)
print((IsDataUnder4MB and "Data is less than 4MB!" or "Data is more than 4MB!"), TotalSizeInMB.." MB")

Basepart:Destroy()

----------------------------------------------------------------------

]]

local HttpService = game:GetService("HttpService")
local PartSerializer = {}

local base_cframe_components = 12
local primary_surface_type = Enum.SurfaceType.Smooth
local total_decimal_places = 2

local batch_seperator = "|"
local class_name_identifier = "C:"
local classtype_seperator = "/"
local properties_seperator = "<>"

local first_seperator = properties_seperator:sub(1, 1)
local second_seperator = properties_seperator:sub(2, 2)

export type Properties = {
	Anchored: boolean,
	Color: boolean,
	Position: boolean,
	Size: boolean,

	Parent: boolean,
	Name: boolean,
	CastShadow: boolean,
	Reflectance: boolean,

	Transparency: boolean,
	Locked: boolean,
	Archivable: boolean,
	Rotation: boolean,

	CanCollide: boolean,
	CanTouch: boolean,
	CanQuery: boolean,
	CollisionGroup: boolean,

	Orientation: boolean,
	CFrame: boolean,
	Material: boolean,
	Massless: boolean,

	Shape: boolean,
	PivotOffset: boolean,
	BrickColor: boolean,
	MaterialVariant: boolean,
}

local function convert_Base10_To_Raw(n: number)
	local int, fp = math.modf(n)
	fp = math.abs(fp)

	local str, extras = tostring(fp), ""
	if fp ~= 0 then
		if str:sub(3, 3) == "0" then
			local total_zeros = 0
			for i = 3, #str do
				if str:sub(i, i) == "0" then
					total_zeros += 1
				else
					break
				end
			end

			extras = string.rep("0", total_zeros)
		end

		fp = str:sub(3, #str)
	end

	fp = (fp == 0 and "0" or fp)

	local dec_values = tonumber(fp:sub(1, total_decimal_places))
	local value = tostring(int)..((dec_values) ~= 0 and "."..(extras..dec_values) or "")

	return tostring(value)
end

local function convert_Vector3_To_Raw(v3: Vector3)
	local raw_data = nil

	local xValue = convert_Base10_To_Raw(v3.X)
	local yValue = convert_Base10_To_Raw(v3.Y)
	local zValue = convert_Base10_To_Raw(v3.Z)

	raw_data = xValue..batch_seperator..yValue..batch_seperator..zValue
	return raw_data
end

local function get_Data_From_Args(Serialize: boolean, Data: boolean, SavedData: string)
	if Serialize then
		return tostring(Data)
	else
		if SavedData == "true" then
			return true
		elseif SavedData == "false" then
			return false
		end
	end
end

local function get_DataInt_From_Args(Serialize: boolean, Data: number, SavedData: string)
	if Serialize then
		local n = convert_Base10_To_Raw(Data)
		return n
	else
		return tonumber(SavedData)
	end
end

local function convert_Raw_To_V3(existingData)
	local groups = existingData:split(batch_seperator)
	local xRot, yRot, zRot = groups[1], groups[2], groups[3]
	xRot = tonumber(xRot) yRot = tonumber(yRot) zRot = tonumber(zRot)

	return Vector3.new(xRot, yRot, zRot)
end

local PrimaryProperties = {
	MaterialVariant = function(serialize: boolean, basePart: BasePart?, existingData: string?)
		if serialize then
			return basePart.MaterialVariant
		else
			return existingData
		end
	end,

	BrickColor = function(serialize: boolean, basePart: BasePart?, existingData: string?)
		if serialize then
			return basePart.BrickColor.Name
		else
			local brickColor = BrickColor.new(existingData)
			return brickColor
		end
	end,

	Shape = function(serialize: boolean, basePart: BasePart?, existingData: string?)
		if serialize then
			return basePart.Shape.Name
		else
			local shape = Enum.PartType[existingData]
			return shape
		end
	end,

	Massless = function(serialize: boolean, basePart: BasePart?, existingData: string?)
		return get_Data_From_Args(serialize, basePart and basePart.Massless, existingData)
	end,

	Material = function(serialize: boolean, basePart: BasePart?, existingData: string?)
		if serialize then
			return basePart.Material.Name
		else
			local material = Enum.Material[existingData]
			return material
		end
	end,

	PivotOffset = function(serialize: boolean, basePart: BasePart?, existingData: string?)
		if serialize then
			local CFrameValues = tostring(basePart.PivotOffset):split(", ")
			local newTable = {}

			for i = 1, base_cframe_components do
				local v = CFrameValues[i]
				newTable[i] = convert_Base10_To_Raw(tonumber(v))
			end

			local newCFrame = table.concat(newTable, batch_seperator)
			return newCFrame
		else
			local CFrameValues = existingData:split(batch_seperator)
			local newTable = {}

			for i = 1, base_cframe_components do
				local v = CFrameValues[i]
				newTable[i] = tonumber(v)
			end

			local newCFrame = CFrame.new(table.unpack(CFrameValues, 1, #CFrameValues))
			return newCFrame
		end
	end,

	CFrame = function(serialize: boolean, basePart: BasePart?, existingData: string?)
		if serialize then
			local CFrameValues = tostring(basePart.CFrame):split(", ")
			local newTable = {}

			for i = 1, base_cframe_components do
				local v = CFrameValues[i]
				newTable[i] = convert_Base10_To_Raw(tonumber(v))
			end

			local newCFrame = table.concat(newTable, batch_seperator)
			return newCFrame
		else
			local CFrameValues = existingData:split(batch_seperator)
			local newTable = {}

			for i = 1, base_cframe_components do
				local v = CFrameValues[i]
				newTable[i] = tonumber(v)
			end

			local newCFrame = CFrame.new(table.unpack(CFrameValues, 1, #CFrameValues))
			return newCFrame
		end
	end,

	CanCollide = function(serialize: boolean, basePart: BasePart?, existingData: string?)
		return get_Data_From_Args(serialize, basePart and basePart.CanCollide, existingData)
	end,

	CanTouch = function(serialize: boolean, basePart: BasePart?, existingData: string?)
		return get_Data_From_Args(serialize, basePart and basePart.CanTouch, existingData)
	end,

	CanQuery = function(serialize: boolean, basePart: BasePart?, existingData: string?)
		return get_Data_From_Args(serialize, basePart and basePart.CanQuery, existingData)
	end,

	CollisionGroup = function(serialize: boolean, basePart: BasePart?, existingData: string?)
		if serialize then
			return basePart.CollisionGroup
		else
			return existingData
		end
	end,

	Orientation = function(serialize: boolean, basePart: BasePart?, existingData: string?)
		if serialize then
			local raw_data = convert_Vector3_To_Raw(basePart.Orientation)
			return raw_data
		else
			return convert_Raw_To_V3(existingData)
		end
	end,

	Archivable = function(serialize: boolean, basePart: BasePart?, existingData: string?)
		return get_Data_From_Args(serialize, basePart and basePart.Archivable, existingData)
	end,

	Locked = function(serialize: boolean, basePart: BasePart?, existingData: string?)
		return get_Data_From_Args(serialize, basePart and basePart.Locked, existingData)
	end,

	CastShadow = function(serialize: boolean, basePart: BasePart?, existingData: string?)
		return get_Data_From_Args(serialize, basePart and basePart.CastShadow, existingData)
	end,

	Reflectance = function(serialize: boolean, basePart: BasePart?, existingData: string?)
		return get_DataInt_From_Args(serialize, basePart and basePart.Reflectance, existingData)
	end,

	Transparency = function(serialize: boolean, basePart: BasePart?, existingData: string?)
		return get_DataInt_From_Args(serialize, basePart and basePart.Transparency, existingData)
	end,

	Anchored = function(serialize: boolean, basePart: BasePart?, existingData: string?)
		return get_Data_From_Args(serialize, basePart and basePart.Anchored, existingData)
	end,

	Color = function(serialize: boolean, basePart: BasePart?, existingData: string?)
		if serialize then
			local color = basePart.Color
			local r, g, b = color.R * 255, color.G * 255, color.B * 255
			r = math.round(r) g = math.round(g) b = math.round(b)

			local data = r..batch_seperator..g..batch_seperator..b
			return data
		else
			local colorValues = existingData:split(batch_seperator)
			return Color3.fromRGB(colorValues[1], colorValues[2], colorValues[3])
		end
	end,

	Rotation = function(serialize: boolean, basePart: BasePart?, existingData: string?)
		if serialize then
			local raw_data = convert_Vector3_To_Raw(basePart.Rotation)
			return raw_data
		else
			return convert_Raw_To_V3(existingData)
		end
	end,

	Position = function(serialize: boolean, basePart: BasePart?, existingData: string?)
		if serialize then
			local raw_data = convert_Vector3_To_Raw(basePart.Position)
			return raw_data
		else
			return convert_Raw_To_V3(existingData)
		end
	end,

	Size = function(serialize: boolean, basePart: BasePart?, existingData: string?)
		if serialize then
			local raw_data = convert_Vector3_To_Raw(basePart.Size)
			return raw_data
		else
			return convert_Raw_To_V3(existingData)
		end
	end,

	Parent = function(serialize: boolean, basePart: BasePart?, existingData: string?)
		if serialize then
			local fullName = basePart:GetFullName()
			fullName = fullName:gsub("."..basePart.Name, "")

			return fullName
		else
			local groups_of_childrens = existingData:split(".")
			local lastDirectory

			for i = 1, #groups_of_childrens do
				if not lastDirectory then
					lastDirectory = game[groups_of_childrens[i]]
				else
					lastDirectory = lastDirectory[groups_of_childrens[i]]
				end
			end

			return lastDirectory
		end
	end,

	Name = function(serialize: boolean, basePart: BasePart?, existingData: string?)
		if serialize then
			return basePart.Name
		else
			return existingData
		end
	end,
}

local function duplicateTable(t: {})
	local newTable = {}

	for k, v in t do
		if typeof(v) == "table" then
			v = duplicateTable(v)
		end
		newTable[k] = v
	end

	return newTable
end

local function getKeysFromTable()
	local reference = PrimaryProperties
	local newTable = {}

	for k, _ in reference do
		newTable[k] = true
	end

	return newTable
end

local function constructProperty(basePart: BasePart, propertyName: string)
	if PrimaryProperties[propertyName] then
		return PrimaryProperties[propertyName](true, basePart)
	end
end

local function deConstructProperty(propertyName: string, propertyValues: string)
	if PrimaryProperties[propertyName] then
		return PrimaryProperties[propertyName](false, nil, propertyValues)
	end
end

function PartSerializer.Serialize(Basepart: BasePart, DataToSerialize: Properties): string
	local raw_data = class_name_identifier..Basepart.ClassName	
	for propertyName, propertyValue in DataToSerialize do
		if propertyValue == true then
			local data = constructProperty(Basepart, propertyName)
			if data ~= nil then
				local joinedData = first_seperator..propertyName..classtype_seperator..data..second_seperator
				raw_data = raw_data..joinedData
			end
		end
	end

	return raw_data
end

function PartSerializer.Deserialize(SerializedData: string, CustomSurfaceTypes: {[string]: Enum.SurfaceType}?): BasePart
	local class_name, total_steps
	for i = 1, #SerializedData do
		local str = SerializedData:sub(i, i)
		if str == first_seperator then
			total_steps = i - 1
			break
		end
	end

	if total_steps then
		local totalText = SerializedData:sub(1, total_steps)
		class_name = totalText:gsub(class_name_identifier, "")
	end

	local my_base_part: BasePart = Instance.new(class_name or "Part")
	local groups = {}

	for startingIndex = 1, #SerializedData do
		local str = SerializedData:sub(startingIndex, startingIndex)
		if str == first_seperator then
			for endingIndex = startingIndex, #SerializedData do
				str = SerializedData:sub(endingIndex, endingIndex)
				if str == second_seperator then
					local pattern = SerializedData:sub(startingIndex, endingIndex)
					table.insert(groups, pattern)

					break
				end
			end
		end
	end

	for _, pattern: string in groups do
		local first_pattern = pattern:gsub(first_seperator, "")
		local data = first_pattern:gsub(second_seperator, "")
		local classtypeIndex = data:find(classtype_seperator)

		local propertyName = data:sub(1, classtypeIndex - 1)
		local propertyValue = data:sub(classtypeIndex + 1, #data)

		local new_data = deConstructProperty(propertyName, propertyValue)
		if new_data ~= nil then
			my_base_part[propertyName] = new_data
		end
	end

	local function getSurfaceType(surface: string)
		local existingSurface = CustomSurfaceTypes and CustomSurfaceTypes[surface]
		my_base_part[surface] = existingSurface or primary_surface_type
	end

	getSurfaceType("BackSurface") getSurfaceType("FrontSurface")
	getSurfaceType("BottomSurface") getSurfaceType("TopSurface")
	getSurfaceType("LeftSurface") getSurfaceType("RightSurface")

	return my_base_part
end

function PartSerializer.MultiSerialize(Baseparts: {BasePart}, DataToSerialize: Properties): {string}
	local dataInArray = {}
	for _, basePart: BasePart in Baseparts do
		local raw_data = PartSerializer.Serialize(basePart, DataToSerialize)
		if raw_data then
			table.insert(dataInArray, raw_data)
		end
	end
	return dataInArray
end

function PartSerializer.GetDefaultProperties(): Properties
	local defaultTemplate = getKeysFromTable()
	return duplicateTable(defaultTemplate)
end

function PartSerializer.GetPropertiesWithWhitelist(Whitelist: Properties): Properties
	local templateTable = getKeysFromTable()
	local mainTable = {}

	for i, _ in templateTable do
		mainTable[i] = Whitelist[i] and true or false
	end

	return duplicateTable(mainTable)
end

function PartSerializer.GetPropertiesWithBlacklist(Blacklist: Properties): Properties
	local templateTable = getKeysFromTable()
	local mainTable = {}

	for i, _ in templateTable do
		if Blacklist[i] then
			mainTable[i] = false
		else
			mainTable[i] = true
		end
	end

	return duplicateTable(mainTable)
end

function PartSerializer.IsDataUnder4MegaBytes(SerializedData: string, ComparitiveValue: any?): string & number
	local max_size = 4000000
	local content_size = #HttpService:JSONEncode(SerializedData)

	if ComparitiveValue ~= nil then
		local data_in_value = #HttpService:JSONEncode(ComparitiveValue)
		local total_size = content_size + data_in_value
		return total_size < max_size, total_size / max_size 
	end

	return content_size < max_size, content_size / max_size
end

return PartSerializer