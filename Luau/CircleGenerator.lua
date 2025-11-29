--!nocheck
-- @fattah412

--[[

CircleGenerator:
A simple circle generator using a reference part

---------------------------------------------------

Notes:

- This uses Trigonometry (Cosine and Sine)
- If no reference part is provided, it will use the center part instead
- If 'RelativeToPart' is set to true, it will make the reference part go along the same local axis as the center part 

---------------------------------------------------

Usage:

CircleGen.CreateCircle(CenterPart: BasePart, Radius: number, TotalParts: number, ReferencePart: BasePart?, RelativeToPart: boolean?)
> Description: Creates a circle around the center with the same radius
> Returns: nil | void

---------------------------------------------------

Example Usage:

local CircleGen = require(game.ServerScriptService.CircleGenerator)
local Center = workspace.Center

local Radius = 15
local Total = 30

CircleGen.CreateCircle(Center, Radius, Total, nil, true)

---------------------------------------------------

]]

local CircleGen = {}

function CircleGen.CreateCircle(CenterPart: BasePart, Radius: number, TotalParts: number, ReferencePart: BasePart?, RelativeToPart: boolean?)
	local cf = CenterPart.CFrame
	local pi = math.pi * 2
	
	for i = 1, TotalParts do
		local unknown_angle = pi / TotalParts * i
		local cosine = math.cos(unknown_angle) * Radius
		local sine = math.sin(unknown_angle) * Radius
		local newPart = (ReferencePart or CenterPart):Clone()
		
		if RelativeToPart then
			local relative = cf:ToWorldSpace(CFrame.new(cosine, 0, sine))
			newPart.Position = relative.Position
		else
			local x, z = cf.X + cosine, cf.Z + sine
			local position = Vector3.new(x, cf.Y, z)
			newPart.Position = position
		end
		
		newPart.Parent = CenterPart.Parent
	end
end

return CircleGen