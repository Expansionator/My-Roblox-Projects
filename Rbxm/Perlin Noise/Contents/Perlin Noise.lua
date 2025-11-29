--!nocheck
-- @fattah412

--[[

Perlin Noise:
The process of generating terrain using Perlin noise.

-----------------------------------------------------------------------------

Notes:

- The function yields until the terrain has been fully generated
- The function returns the total time it took to complete, as well as the center of the terrain
- If 'ShowPercentage' is true, be aware that the IntValue will delete itself after it reaches a value of a 100
- The terrain generation is not randomized, it solely relies on the values 'Amplitude', 'Resolution' and 'Frequency'
- If no perlin noise table was provided, it will use its default one
- If a property inside the perlin noise table was not provided, it will use the default property
- 'NoYield' when set to true can have the possibility of crashing one's game
- 'UseTerrain' when set to false can tremendously create alot of lag if the scale is too big
- Refer to the 'DefaultNoiseSettings' table to see what each property does
- Refer to the 'Example Usage' section to see how biomes are created

-----------------------------------------------------------------------------

Usage:

PerlinNoise.Create(MinPosition: Vector3, MaxPosition: Vector3, NoiseSettings: PerlinNoiseSettings?)
> Description: Creates the terrain, utilizing the min and max positions and a custom noise setting (uses the default if no value is provided)
> Returns: TotalTime: number, CentralPosition: Vector3

-----------------------------------------------------------------------------

Example Usage:

local PerlinNoise = require(game.ServerScriptService:WaitForChild("Perlin Noise"))

local minPosition = Vector3.new(-50, 50, -50)
local maxPosition = Vector3.new(150, 70, 180)

local perlinNoiseSettings = {	
	RespectBothHeights = true;
	UseTerrain = true;
	
	ShowPercentage = true;
	
	Amplitude = 20;
	
	BiomesEnabled = true;
	Biomes = {
		{
			Material = Enum.Material.Sand;
			X = {Min = 10, Max = 100};
			Z = {Min = 10, Max = 100};
		};
	};
}

local totalTime, centralPosition = PerlinNoise.Create(minPosition, maxPosition, perlinNoiseSettings)
print('It took '..totalTime..' seconds to complete!')

local middlePoint = Instance.new("Part", workspace)
middlePoint.Shape = Enum.PartType.Ball
middlePoint.Color = Color3.fromRGB(255,0,0)
middlePoint.Anchored = true
middlePoint.Size = Vector3.new(5,5,5)
middlePoint.Position = centralPosition
middlePoint.Material = Enum.Material.Neon

-----------------------------------------------------------------------------

]]

local min = math.min
local max = math.max
local noise = math.noise
local clamp = math.clamp
local round = math.round
local v3 = Vector3.new

local Terrain = workspace:FindFirstChildOfClass("Terrain")
local RunService = game:GetService("RunService")

local PerlinNoise = {}
local Reconciler = require(script.Reconciler)
local Operations = script.Operations

local DefaultNoiseSettings = {
	Amplitude = 5; -- How 'high' should each peak be
	Frequency = 5; -- How 'frequent' should the peaks appear
	Resolution = 100; -- How 'flat' should the terrain be

	UseTerrain = true; -- Uses terrain instead of parts
	TerrainMaterial = Enum.Material.Grass; -- The material used for the terrain

	TemplatePart = nil; -- The part used (Size & Parent not counted) when 'UseTerrain' is false. Uses the default part if no part was provided
	BasePartParent = nil; -- The parent of each created part

	VisualizeNoise = false; -- If 'UseTerrain' is false, shows the color of each part based on their height (black = lowest & white = highest)

	NoYield = false; -- Instantly creates the terrain (not recommended to be true)

	RespectBothHeights = false; -- If set to true, the system will not use the minimum height; instead, it will use both the minimum and maximum heights

	ShowPercentage = false; -- Creates an IntValue inside the folder named 'Operations'. It will automatically delete itself when the value reaches 100
	PercentageName = "Map Generation"; -- The name used to create the IntValue

	IncrementY = 1.025; -- The additional 'Y' height for each part. Needed to fill the missing gaps when generating the terrain

	BiomesEnabled = false; -- The different materials used in specific regions of the terrain
	Biomes = { -- The configuration table for biomes
		--[[
		
		{
			Material: Enum.Material,
			X: {Min: number, Max: number},
			Z: {Min: number, Max: number}
		};
		
		]]
	}; 
}

export type PerlinNoiseSettings = {
	Amplitude: number?,
	Frequency: number?,
	Resolution: number?,

	UseTerrain: boolean?,
	TerrainMaterial: Enum.Material?,

	TemplatePart: BasePart?,
	BasePartParent: Instance?,

	VisualizeNoise: boolean?,

	NoYield: boolean?,

	RespectBothHeights: boolean?,

	ShowPercentage: boolean?,
	PercentageName: string?,

	IncrementY: number?,

	BiomesEnabled: boolean?,
	Biomes: {}?
}

function PerlinNoise.Create(MinPosition: Vector3, MaxPosition: Vector3, NoiseSettings: PerlinNoiseSettings?)
	local minX, minZ = min(MinPosition.X, MaxPosition.X), min(MinPosition.Z, MaxPosition.Z)
	local maxX, maxZ = max(MinPosition.X, MaxPosition.X), max(MinPosition.Z, MaxPosition.Z)
	local lowestY = min(MinPosition.Y, MaxPosition.Y) * 2
	local highestY = max(MinPosition.Y, MaxPosition.Y) * 2
	local noiseSettings = NoiseSettings and Reconciler.Copy(NoiseSettings, DefaultNoiseSettings) or DefaultNoiseSettings
	local percentage = noiseSettings.ShowPercentage and Instance.new("IntValue", Operations)
	local totalSize = round((maxX - minX + 1) * (maxZ - minZ + 1))
	local timeNow = os.time()

	if percentage then
		percentage.Name = noiseSettings.PercentageName
	end

	local function getAlphaHeight(x, z)
		local noiseHeight = noise(x / noiseSettings.Resolution * noiseSettings.Frequency, z / noiseSettings.Resolution * noiseSettings.Frequency)
		noiseHeight = clamp(noiseHeight, -0.5, 0.5) + 0.5

		return noiseHeight
	end

	local function getMaterial(x, z)
		if noiseSettings.BiomesEnabled then
			for _, v in noiseSettings.Biomes do
				if x >= v.X.Min and x <= v.X.Max then
					if z >= v.Z.Min and z <= v.Z.Max then
						return v.Material
					end
				end
			end
		end

		return noiseSettings.TerrainMaterial
	end

	local counter = 0
	for z = minZ, maxZ do
		for x = minX, maxX do
			local height = getAlphaHeight(x, z)
			local part: BasePart = noiseSettings.TemplatePart
			if not part then
				part = Instance.new("Part")
				part.Anchored = true
				part.Material = Enum.Material.SmoothPlastic
			end

			local additionalHeight = noiseSettings.RespectBothHeights and ((lowestY + highestY) / 2) or lowestY
			local posY = additionalHeight + (height * noiseSettings.Amplitude)
			local sizeY = (v3(x, lowestY, z) - v3(x, posY, z)).Magnitude

			part.Position = v3(x, posY / 2, z)
			part.Size = v3(1, sizeY + noiseSettings.IncrementY, 1)

			if noiseSettings.VisualizeNoise and not noiseSettings.UseTerrain then
				part.Color = Color3.new(height, height, height)
			end

			if noiseSettings.UseTerrain then
				Terrain:FillBlock(part.CFrame, part.Size, getMaterial(x, z))
				part:Destroy()
			else
				part.Parent = noiseSettings.BasePartParent or workspace
			end

			if percentage then
				counter += 1
				percentage.Value = round(counter / totalSize * 100)
			end
		end

		if not noiseSettings.NoYield then
			RunService.Heartbeat:Wait()
		end
	end

	local x = (minX + maxX) / 2
	local y = (lowestY + highestY) / 2
	local z = (minZ + maxZ) / 2

	if percentage then
		percentage:Destroy()
	end

	return tonumber(("%.2f"):format(os.time() - timeNow)), v3(x, y, z)
end

return PerlinNoise