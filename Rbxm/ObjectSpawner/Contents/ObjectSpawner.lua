--!nocheck
-- @fattah412

--[[

ObjectSpawner:
The module that can create an object using a randomized position in a defined region.

----------------------------------------------------------------------------

Notes:

- When creating objects using a model, there must be a PrimaryPart with it
	> This includes objects that are in the 'Include' table
- It's not guaranteed that the same object will be created a specified number of times, as the attempts may exceed the maximum limit
- This system supports terrain
	> This also allows the ability to only create objects on certain materials

* Read table 'DefaultConfiguration' for more information

----------------------------------------------------------------------------

Usage:

--> Functions:

ObjectSpawner.RaycastMap(Objects: {Model | BasePart}, MinPos: Vector3, MaxPos: Vector3, Configuration: Configuration?)
> Description: Raycasts the map to find a random position for the objects
> Returns: timeTakenToGenerate: number, totalObjects: {Model | BasePart}

ObjectSpawner.GetMinAndMaxPos(BasePart: BasePart, YOffset: number?): Vector3
> Description: Gets the two corners of a basepart
> Returns: BottomLeftCorner: Vector3, TopRightCorner: Vector3

----------------------------------------------------------------------------

Example Usage:

local ObjectSpawner = require(script.ObjectSpawner)
local Baseplate = workspace.Baseplate

local myNewPart = Instance.new("Part")
myNewPart.Size = Vector3.new(5,5,5)
myNewPart.Name = "Dummy Part"
myNewPart.Anchored = true
myNewPart.BrickColor = BrickColor.Red()

local function onFailure(typeOfError: "Raycast" | "Attempts", position: Vector3)
	print('(Creation Failure) Type & Position:', typeOfError, position)
end

local minPos, maxPos = ObjectSpawner.GetMinAndMaxPos(Baseplate, 50)
local Config = {
	Total = 15;
	CustomMaterial = {["Dummy Part"] = Enum.Material.Grass};
	ErrorFunction = onFailure;
}

local timeTook, totalObjects = ObjectSpawner.RaycastMap({myNewPart}, minPos, maxPos, Config)
print(("It took %i seconds to generate %i objects!"):format(timeTook, #totalObjects))

----------------------------------------------------------------------------

]]

local RunService = game:GetService("RunService")

local Reconcile = require(script.Reconciler)
local ObjectSpawner = {}

local raycastParams = RaycastParams.new()
raycastParams.IgnoreWater = false

local DefaultConfiguration = {
	Total = 15; -- The total amount of times to generate the object (if attempt succeeded)
	MaxAttempts = 30; -- The total amount of attempts to regenerate the object, before skipping to the next iteration

	UseDistance = true; -- If true, checks any nearby objects with a specified distance
	MinDistance = 30; -- The minimum distance that the object can spawn

	Parent = workspace; -- Where the objects will be parented to

	UseNormal = true; -- If true, objects that are created will respect the normal vector of the current position, orientating itself to align with the surface

	ObjectOffset = Vector3.zero; -- The offset that is used when positioning objects

	CustomMaterial = {}; -- The materials that each object will only spawn on

	RaycastParam = raycastParams; -- The provided parameters when creating a raycast
	Include = {}; -- The objects (Basepart or Model) to check when creating objects

	ErrorFunction = nil; -- The function that will be called when the raycast fails or when the total number of attempts exceeds the max limit
}

export type Configuration = {
	Total: number?;
	MaxAttempts: number?;

	UseDistance: boolean?;
	MinDistance: number?;

	Parent: Instance?;

	UseNormal: boolean?;

	ObjectOffset: Vector3?;

	CustomMaterial: {
		[ObjectName]: Enum.Material	
	}?;

	RaycastParam: RaycastParams?;
	Include: {BasePart | Model}?;

	ErrorFunction: (typeOfError: "Raycast" | "Attempts", position: Vector3) -> (...any);
}

local function getRandomPosition(Min: Vector3, Max: Vector3)
	local Random = Random.new()

	local minX, maxX = math.min(Min.X, Max.X), math.max(Min.X, Max.X)
	local minZ, maxZ = math.min(Min.Z, Max.Z), math.max(Min.Z, Max.Z)

	local newX = Random:NextNumber(minX, maxX)
	local newZ = Random:NextNumber(minZ, maxZ)

	return Vector3.new(newX, Max.Y, newZ)
end

function ObjectSpawner.RaycastMap(Objects: {Model | BasePart}, MinPos: Vector3, MaxPos: Vector3, Configuration: Configuration?)
	Configuration = Reconcile.Copy(Configuration or {}, DefaultConfiguration)
	local V3, CreatedObjects = Vector3.new, {}
	local timeNow = os.time()
	
	for _, v in Configuration.Include do
		table.insert(CreatedObjects, v)
	end

	for index = 1, #Objects do
		for _ = 1, Configuration.Total do
			local attemptsNotExceeded, attemptPosition = false, nil
			for i = 1, Configuration.MaxAttempts do
				local newPosition = getRandomPosition(MinPos, MaxPos)
				local direction = ((V3(0, MaxPos.Y, 0) - V3(0, MinPos.Y, 0)).Magnitude) + 1
				local raycastResult = workspace:Raycast(newPosition, V3(0, -direction, 0), Configuration.RaycastParam)

				attemptPosition = newPosition

				if raycastResult then
					local existingMaterial = Configuration.CustomMaterial[Objects[index].Name]
					if existingMaterial and raycastResult.Material ~= existingMaterial then
						continue
					end

					local function createInstance()
						local rayPosition = raycastResult.Position + Configuration.ObjectOffset
						local newCFrame = Configuration.UseNormal and CFrame.new(rayPosition, rayPosition + raycastResult.Normal) or CFrame.new(rayPosition)
						local newInstance = Objects[index]:Clone()

						newInstance.Parent = Configuration.Parent
						newInstance:PivotTo(newCFrame)

						table.insert(CreatedObjects, newInstance)
						attemptsNotExceeded = true
					end

					if Configuration.UseDistance then
						local success = true
						for _, v in CreatedObjects do
							local magnitude = (v:GetPivot().Position - raycastResult.Position).Magnitude
							if magnitude < Configuration.MinDistance then
								success = false break
							end

							if #CreatedObjects > 500 then -- Prevents iterating the instances instantly
								RunService.Heartbeat:Wait()
							end
						end

						if success then
							createInstance()
							break
						end
					else
						createInstance()
						break
					end
				else
					if Configuration.ErrorFunction then
						Configuration.ErrorFunction("Raycast", newPosition)
					end
				end

				RunService.Heartbeat:Wait()
			end

			if not attemptsNotExceeded and attemptPosition then
				if Configuration.ErrorFunction then
					Configuration.ErrorFunction("Attempts", attemptPosition)
				end
			end

			RunService.Heartbeat:Wait()	
		end
	end

	return (os.time() - timeNow), CreatedObjects
end

function ObjectSpawner.GetMinAndMaxPos(BasePart: BasePart, YOffset: number?): Vector3
	local size, pos = BasePart.Size, BasePart.Position
	local bottomLeftCorner = Vector3.new(pos.X - (size.X / 2), 0, pos.Z - (size.Z / 2))
	local topRightCorner = Vector3.new(pos.X + (size.X / 2), 0, pos.Z + (size.Z / 2))
	local lowestY = pos.Y - (size.Y / 2)
	local highestY = (pos.Y + (size.Y / 2)) + (YOffset or 0)

	bottomLeftCorner += Vector3.new(0, lowestY, 0)
	topRightCorner += Vector3.new(0, highestY, 0)

	return bottomLeftCorner, topRightCorner
end

return ObjectSpawner