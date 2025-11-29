--!nocheck

local Tool = script.Parent

local Handle = Tool.Handle
local Event = Tool.Event

local SFX = Handle.SFX
local SpotLight = Handle.SpotLight
local Mesh = Handle.Mesh

local States = {
	Enabled = {
		MeshId = "http://www.roblox.com/asset/?id=115955313",
		TextureId = "http://www.roblox.com/asset?id=115984370"
	},
	
	Disabled = {
		MeshId = "http://www.roblox.com/asset/?id=115955313",
		TextureId = "http://www.roblox.com/asset?id=115955343",
	}
}

Event.OnServerEvent:Connect(function()
	SpotLight.Enabled = not SpotLight.Enabled
	SFX:Play()
	
	if SpotLight.Enabled then
		Mesh.MeshId = States.Enabled.MeshId
		Mesh.TextureId = States.Enabled.TextureId
	else
		Mesh.MeshId = States.Disabled.MeshId
		Mesh.TextureId = States.Disabled.TextureId
	end
end)