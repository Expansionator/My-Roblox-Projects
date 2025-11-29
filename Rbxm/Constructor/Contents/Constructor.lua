--!nocheck
-- @fattah412

--[[

Constructor:
A module that helps the creations of Instances and can be nested into oneanother.

---------------------------------------------------------------------------------

Notes:

- You can nest functions inside of an constructor.
- Once a object is created via :Add(), it will behave the same way as .Create()
- You cannot set events as properties. Use :GetProperty() or .Instance for it.
- 'Children' is a custom built-in property where you can nest objects into oneanother.
- If an object gets destroyed without calling :Destroy(), it will automatically call the function.
- All children objects will not be accounted for, and you have to manually retrieve them.

---------------------------------------------------------------------------------

Usage:

--> Properties:

Object.Instance
> Description: Refers to the actual instance. It will be nil if it's destroyed
> Returns: Instance

Object.IsDestroyed
> Description: Returns a boolean indicating if this object was destroyed via :Destroy() or the parent of it is nil
> Returns: boolean

--> Functions:

Constructor.Create(ClassName: string, ObjectData: Instance | {PropertyName: string, PropertyValue: any})
> Description: Adds a new Instance, with a parent or custom properties for the instance
> Returns: Object: metatable

Object:Add(ClassName: string, ObjectData: Instance | {PropertyName: string, PropertyValue: any})
> Description: Behaves the same way as Constructor.Create(), but instead parents itself to the parent unless a new parent was specified
> Returns: Object: metatable

Object:SetProperty(PropertyName: string, PropertyValue: any)
> Description: Sets a object's property with the provided value
> Returns: void | nil

Object:GetProperty(PropertyName: string)
> Description: Gets the property value from the object or an Instance
> Returns: any

Object:Destroy()
> Description: Destroys the object, making it unusable. Changing 'IsDestroyed' to true
> Returns: void | nil

---------------------------------------------------------------------------------

Example Usage:

local Constructor = require(Path.To.Constructor)
local MyPart = Constructor.Create("Part", {
	Name = "MyPart";
	Parent = workspace;
	Anchored = true;
	Position = Vector3.new(0, 5, 0);
	Children = {
		{"PointLight", {
			Shadows = true;
		}};
	}
})

print(MyPart.Instance.Name, MyPart:GetProperty("Name"))

local ClickDetector = MyPart:Add("ClickDetector")
local IsClicked = ClickDetector:Add("BoolValue", {
	Name = "IsClicked";
	Value = false
})

local Connection
Connection = ClickDetector:GetProperty("MouseClick"):Connect(function(player)
	print(player.Name, "has clicked on the part!")
	
	IsClicked:SetProperty("Value", true)
	MyPart:SetProperty("Color", Color3.fromRGB(255, 121, 121))
	
	ClickDetector:Destroy()
	
	Connection:Disconnect()
	Connection = nil
end)

]]

local Constructor = {}
local Signal = require(script.Signal) -- create.roblox.com/marketplace/asset/15215016637/Signal
Constructor.__index = Constructor

function LoopInstance(Object: Instance, PropertyTable: {})
	for index, value in pairs(PropertyTable) do
		if typeof(index) ~= "string" then continue end
		if index:lower() == "children" and typeof(value) == "table" then
			for _, v in pairs(value) do
				local objName, ptTable = v[1], v[2]
				local newObject = Instance.new(objName, Object)
				if typeof(ptTable) == "table" then
					LoopInstance(newObject, ptTable)
				end
			end
		else
			Object[index] = value
		end
	end
end

local function BoundObjectToTable(ClassName, ObjectData, ExistingParent)
	local Object: Instance = Instance.new(ClassName)
	local self = setmetatable({
		["Instance"] = Object;
		["IsDestroyed"] = false;
		["_Container"] = Signal.Create();
	}, Constructor)

	if typeof(ObjectData) == "Instance" and not ExistingParent then
		Object.Parent = ObjectData
	elseif ExistingParent then
		Object.Parent = ExistingParent
	end
	
	if typeof(ObjectData) == "table" then
		LoopInstance(Object, ObjectData)
	end
	
	self._Container:Connect(self.Instance.AncestryChanged, function()
		if self.Instance and not self.Instance.Parent then
			self.Instance = nil
			self:Destroy()
		end
	end)

	return self
end

function Constructor.Create(ClassName: string, ObjectData: Instance | {PropertyName: string, PropertyValue: any})
	return BoundObjectToTable(ClassName, ObjectData)
end

function Constructor:Add(ClassName: string, ObjectData: Instance | {PropertyName: string, PropertyValue: any})
	return BoundObjectToTable(ClassName, ObjectData, self.Instance)
end

function Constructor:SetProperty(PropertyName: string, PropertyValue: any)
	self.Instance[PropertyName] = PropertyValue
end

function Constructor:GetProperty(PropertyName: string)
	return self.Instance[PropertyName]
end

function Constructor:Destroy()
	if self.Instance then
		self.Instance:Destroy()
	end
	
	self.Instance = nil
	self.IsDestroyed = true
	
	if not self._Container.Destroyed then
		self._Container:Clean()
	end
end

return Constructor