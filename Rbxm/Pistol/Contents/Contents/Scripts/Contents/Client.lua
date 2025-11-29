local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

local Tool = script.Parent.Parent
local OnShoot = Tool.Remotes.OnShoot

Tool:WaitForChild("Miscellaneous")

local AmmoUI = Tool.Miscellaneous.AmmoUI
local CurrentAmmo = Tool.Miscellaneous.CurrentAmmo

local Reloading = Tool.Miscellaneous.Reloading

local Configuration = require(Tool.Configuration)
local Character, Debounce, Connection, HumanoidIsDead, IsHoldingMouse

local ActionName = "GunReload"

local LoadedAnimations = {}

local function playAnimation(animationName: string)
	if Character then
		local humanoid: Humanoid = Character:FindFirstChildOfClass("Humanoid")
		local animator: Animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		
		if animator then
			local animation = Tool.Animations[animationName]
			if animation.AnimationId == "" then
				local animTable = Configuration.Animations[humanoid.RigType.Name]
				if animTable[animationName] then
					repeat task.wait() until animation.AnimationId ~= ""
				else
					return
				end
			end
			
			local animationTrack: AnimationTrack = LoadedAnimations[animationName] or animator:LoadAnimation(animation)
			
			animationTrack:Play()
			LoadedAnimations[animationName] = animationTrack
		end
	end
end

local function stopAnimation(animationName: string)
	if LoadedAnimations[animationName] then
		LoadedAnimations[animationName]:Stop()
		LoadedAnimations[animationName] = nil
	end
end

local function stopAllAnimations()
	for _, anim in Tool.Animations:GetChildren() do
		stopAnimation(anim.Name)
	end
end

local function onReloading(actionName, actionState)
	if actionName == ActionName and actionState == Enum.UserInputState.Begin then
		OnShoot:FireServer("Reload")
	end
end

local function bindAction()
	if HumanoidIsDead then 
		return 
	end

	ContextActionService:UnbindAction(ActionName)
	ContextActionService:BindAction(ActionName, onReloading,
		Configuration.CreateTouchButton, Configuration.ReloadKey)

	if Configuration.CreateTouchButton then
		local propertiesTable = Configuration.ButtonProperties

		if propertiesTable.Position then
			ContextActionService:SetPosition(ActionName, propertiesTable.Position)
		end

		if propertiesTable.Image then
			ContextActionService:SetImage(ActionName, propertiesTable.Image)
		end

		if propertiesTable.Description then
			ContextActionService:SetDescription(ActionName, propertiesTable.Description)
		end

		if propertiesTable.Title then
			ContextActionService:SetTitle(ActionName, propertiesTable.Title)
		end
	end
end

local function updateAmmoUI(text)
	local currentAmmoUI = playerGui:FindFirstChild(AmmoUI.Name)
	if currentAmmoUI then
		currentAmmoUI.Ammo.Text = text
	end
end

local function createAmmoUI()
	local currentAmmoUI = playerGui:FindFirstChild(AmmoUI.Name)
	if currentAmmoUI then
		currentAmmoUI:Destroy()
	end

	if Configuration.ShowAmmoUI then
		local newAmmoUI = AmmoUI:Clone()
		newAmmoUI.Enabled = true
		newAmmoUI.Ammo.Text = CurrentAmmo.Value.." / "..Configuration.MaxAmmo
		newAmmoUI.Parent = playerGui
	end
end

local function removeAmmoUI()
	local currentAmmoUI = playerGui:FindFirstChild(AmmoUI.Name)
	if currentAmmoUI then
		currentAmmoUI:Destroy()
	end
end

local function unbindAction()
	ContextActionService:UnbindAction(ActionName)
	Character = nil

	if Connection then
		Connection:Disconnect()
		Connection = nil
	end
end

local function shootTarget()
	if not Debounce then
		Debounce = true
		
		local hitPosition = mouse.Hit
		if hitPosition then
			OnShoot:FireServer("Shoot", hitPosition.Position)	
			playAnimation("Shoot")
		end
		
		task.wait(Configuration.FireRate)
		Debounce = false
	end
end

Tool.Equipped:Connect(function()
	Character = Tool.Parent
	
	playAnimation("Idle")
	bindAction() createAmmoUI()
	
	if not Connection then
		local Humanoid: Humanoid = Character:FindFirstChildOfClass("Humanoid")
		if Humanoid then
			Connection = Humanoid.Died:Connect(function()
				HumanoidIsDead = true 
				IsHoldingMouse = false
				
				unbindAction() removeAmmoUI()
				stopAllAnimations()
			end)
		end
	end
end)

Tool.Unequipped:Connect(function()
	IsHoldingMouse = false
	
	unbindAction() removeAmmoUI()
	stopAllAnimations()
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if Character and Tool.Parent == Character then
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if not IsHoldingMouse then
				IsHoldingMouse = true
				if Configuration.Automatic then
					while IsHoldingMouse do
						shootTarget() task.wait()
					end
				else
					shootTarget()
				end
			end
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, gp)
	if gp then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		IsHoldingMouse = false
	end
end)

CurrentAmmo:GetPropertyChangedSignal("Value"):Connect(function()
	updateAmmoUI(CurrentAmmo.Value.." / "..Configuration.MaxAmmo)
end)

Reloading:GetPropertyChangedSignal("Value"):Connect(function()
	if Reloading.Value then
		updateAmmoUI("Reloading..")
		playAnimation("Reload")
	end
end)