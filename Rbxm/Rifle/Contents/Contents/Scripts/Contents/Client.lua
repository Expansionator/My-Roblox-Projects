--!nocheck

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Gun = script.Parent.Parent

local Remotes = Gun.Remotes
local Config = require(Gun.Configuration)

local Barrel = Gun.Barrel
local Handle = Gun.Handle

local player = Players.LocalPlayer
local playerGui = player.PlayerGui
local Camera = workspace.CurrentCamera

local isZooming = false
local isToolEquipped = false
local isHoldingButton = false
local hasHumanoidDied = false

local humanoidConnection: RBXScriptConnection
local currentAmmoUI: ScreenGui

local function createAction(t: {}, callback: () -> (), condition: () -> boolean?)
	if Config.EnableMobileControls then
		if condition and not condition() then
			return
		end
		ContextActionService:BindAction(t.Name, callback, true)

		if t.Title then
			ContextActionService:SetTitle(t.Name, t.Title)
		end

		if t.Image then
			ContextActionService:SetImage(t.Name, t.Image)
		end

		if t.Description then
			ContextActionService:SetDescription(t.Name, t.Description)
		end

		if t.Position then
			ContextActionService:SetPosition(t.Name, t.Position)
		end
	end
end

local function stopZooming()
	if Config.Zoom.Enabled and isZooming then
		Config.Zoom.StopZooming(Camera)
		isZooming = false
	end
end

local function startZooming()
	if Config.Zoom.Enabled and not isZooming then
		isZooming = true
		Config.Zoom.StartZooming(Camera)
	end
end

local function bindToReload(_, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin and Config.Reload.Enabled then
		Remotes.Reload:FireServer()
	end
end

local function bindToZoomIn(_, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin and Config.Zoom.Enabled then
		startZooming()
	end
end

local function bindToZoomOut(_, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin and Config.Zoom.Enabled then
		stopZooming()
	end
end

local function onUnequipped()
	isHoldingButton = false
	isToolEquipped = false

	if Config.EnableMobileControls then
		for _, tab: {Name: string} in Config.ActionSettings do
			ContextActionService:UnbindAction(tab.Name)
		end
	end

	if humanoidConnection then
		humanoidConnection:Disconnect()
		humanoidConnection = nil
	end

	if Config.FirstPersonView then
		player.CameraMode = Enum.CameraMode.Classic
	end

	stopZooming()
end

Gun.Equipped:Connect(function()
	if hasHumanoidDied then return end
	isToolEquipped = true

	local char: Model = Gun.Parent
	local humanoid: Humanoid? = char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoidConnection = humanoid.Died:Connect(function()
			hasHumanoidDied = true
			onUnequipped()
		end)
	end

	if Config.FirstPersonView then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	end

	createAction(Config.ActionSettings.Reload, bindToReload, function()
		return Config.Reload.Enabled
	end)

	createAction(Config.ActionSettings.ZoomIn, bindToZoomIn, function()
		return Config.Zoom.Enabled
	end)

	createAction(Config.ActionSettings.ZoomOut, bindToZoomOut, function()
		return Config.Zoom.Enabled
	end)
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp or hasHumanoidDied then return end
	if Config.Reload.Enabled and input.KeyCode == Config.Reload.Key then
		Remotes.Reload:FireServer()
		return
	end

	if isToolEquipped and Config.Zoom.Enabled and input.UserInputType == Config.Zoom.Key then
		startZooming()
	end

	for _, v in Config.InputTypes do
		if input[Config.Input] == v then
			isHoldingButton = true
			while isHoldingButton do
				local raycastParams = RaycastParams.new()
				raycastParams.FilterType = Enum.RaycastFilterType.Exclude
				raycastParams.FilterDescendantsInstances = {
					player.Character, Gun
				}

				local mousePosition = UserInputService:GetMouseLocation()
				local ray = Camera:ViewportPointToRay(mousePosition.X, mousePosition.Y, 0)
				local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * Config.MaxDistance, raycastParams)

				if raycastResult then
					Remotes.Shoot:FireServer(raycastResult.Position)
				end

				if not Config.Automatic then
					isHoldingButton = false
					break
				end
				task.wait(Config.Rate)
			end
			break
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, gp)
	if gp then return end
	if isToolEquipped and Config.Zoom.Enabled and input.UserInputType == Config.Zoom.Key then
		stopZooming()
	end

	for _, v in Config.InputTypes do
		if input[Config.Input] == v then
			isHoldingButton = false
			break
		end
	end
end)

Remotes.Display.OnClientEvent:Connect(function(...)
	local maxAmmo = Config.Reload.Enabled and Config.Reload.MaxAmmo or Config.UIFormat.InfiniteAmmo
	local args = table.pack(...)
	args["n"] = nil

	if args[1] == "Show" and not currentAmmoUI then
		local ammoUI = Gun.AmmoUI:Clone()
		ammoUI.Parent = playerGui
		ammoUI.Gun.Text = Config.UIFormat.GunName:format(args[2])
		ammoUI.Ammo.Text = Config.UIFormat.Ammo:format(args[3], maxAmmo)

		currentAmmoUI = ammoUI
	end

	if args[1] == "Hide" then
		if currentAmmoUI then
			currentAmmoUI:Destroy()
		end
		currentAmmoUI = nil
	end

	if args[1] == "Update" and currentAmmoUI then
		currentAmmoUI.Ammo.Text = Config.UIFormat.Ammo:format(args[2], maxAmmo)
	end

	if args[1] == "Reloading" then
		currentAmmoUI.Ammo.Text = Config.UIFormat.Reload
	end
end)

Gun.Unequipped:Connect(onUnequipped)