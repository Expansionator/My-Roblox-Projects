--!nocheck
-- @fattah412

--[[

LookAt:
An alternative to CFrame.lookAt().

----------------------------------

Example Usage:

local LookAt = require(game.ServerScriptService.LookAt)
local PartA, PartB = workspace.A, workspace.B

PartA.CFrame = LookAt.lookAt(PartA.Position, PartB.Position)

----------------------------------

]]

local LookAt = {}

function LookAt.lookAt(Position: Vector3, At: Vector3, UpVector: Vector3?): CFrame
	local lookVector = (Position - At).Unit
	local rightVector = lookVector:Cross(UpVector or Vector3.yAxis)
	local upVector = rightVector:Cross(lookVector)
	
	return CFrame.fromMatrix(Position, rightVector, upVector)
end

return LookAt