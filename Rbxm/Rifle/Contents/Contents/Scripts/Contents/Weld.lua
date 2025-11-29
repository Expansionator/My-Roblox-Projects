--!nocheck

local Gun = script.Parent.Parent

local Parts = Gun.Parts
local Barrel = Gun.Barrel
local Handle = Gun.Handle

local ObjectsToWeld = {Parts:GetChildren(), {Barrel}}
local RootPart = Handle

for _, objects: {Instance} in ObjectsToWeld do
	for _, object in objects do
		if object:IsA("BasePart") then
			do
				local weldConstraint = object:FindFirstChildOfClass("WeldConstraint")
				if weldConstraint then
					weldConstraint:Destroy()
				end
			end
			
			local weldConstraint = Instance.new("WeldConstraint")
			weldConstraint.Part0 = object
			weldConstraint.Part1 = RootPart
			weldConstraint.Name = "Weld"
			weldConstraint.Parent = object
		end
	end
end

script:Destroy()