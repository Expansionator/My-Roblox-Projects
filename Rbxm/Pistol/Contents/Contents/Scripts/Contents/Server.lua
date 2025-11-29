local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Tool = script.Parent.Parent
local Muzzle = Tool.Muzzle
local Handle = Tool.Handle

local OnShoot = Tool.Remotes.OnShoot
local Configuration = require(Tool.Configuration)

local Reloading = Tool.Miscellaneous.Reloading

local ShootingDebounce, ReloadDebounce, Character, LoadedCoreAnims
local CurrentAmmo = Configuration.InfiniteAmmo and math.huge or Configuration.MaxAmmo

local BulletContainer = workspace:FindFirstChild("Bullets_Container") or Instance.new("Folder", workspace)
BulletContainer.Name = "Bullets_Container"

local BulletsFolder: Folder

local function updateCurrentAmmo()
	Tool.Miscellaneous.CurrentAmmo.Value = CurrentAmmo
end

local function isRealPlayer(Char: Model)
	if not Configuration.OnlyShootPlayers then
		return true
	end
	return Players:GetPlayerFromCharacter(Char) and true
end

local function getDefaultBullet()
	local configTable = Configuration.BulletProperties
	local bullet = Instance.new("Part", BulletsFolder)
	bullet.Name = "Bullet"
	bullet.CastShadow = false
	bullet.CanCollide = false
	bullet.CanQuery = false
	bullet.CanTouch = false
	bullet.Color = configTable.Color
	bullet.Material = configTable.Material
	bullet.Size = Vector3.new(configTable.Sizes.X, configTable.Sizes.Y, 0)

	return bullet
end

local function clearCreatorTags(Humanoid: Humanoid)
	for _, CreatorTag: Instance in Humanoid:GetChildren() do
		if CreatorTag.Name == Configuration.CreatorTagName and CreatorTag:IsA("StringValue") then
			CreatorTag:Destroy()
		end
	end
end

local function createCreatorTag(Humanoid: Humanoid, PlayerWhoShot: string)
	local CreatorTag = Instance.new("StringValue", Humanoid)
	CreatorTag.Name = Configuration.CreatorTagName
	CreatorTag.Value = PlayerWhoShot
end

local function canShootNonTeamPlayer(Char: Model)
	if not Configuration.TeamCheck then
		return true
	end
	
	local player: Player = Players:GetPlayerFromCharacter(Char)
	if player then
		local playerTeam = player.Team
		if playerTeam then
			return not table.find(Configuration.ValidTeams, playerTeam.Name) and true
		end
	end
	
	return true
end

local function checkForFriendlyFire(player: Player, Char: Model)
	if not Configuration.NoFriendlyFire then
		return true
	end
	
	local target: Player = Players:GetPlayerFromCharacter(Char)
	if target then
		local playerTeam = player.Team
		local targetTeam = target.Team
		
		if playerTeam and targetTeam then
			return playerTeam.Name ~= targetTeam.Name
		end
	end
	
	return true
end

local function visualizeBullet(position: Vector3)
	local folderName = "VisualizedBullets_"..Character.Name
	BulletsFolder = BulletContainer:FindFirstChild(folderName) or Instance.new("Folder", BulletContainer)
	BulletsFolder.Name = folderName

	local originPosition = Muzzle.Position
	local magnitude = (position - originPosition).Magnitude
	local speed = not Configuration.RayBulletType and 
		(Configuration.BulletLifetime * Configuration.BulletSpeed)

	local bullet: Part
	if Configuration.RayBulletType then
		local midPosition = (originPosition + position) / 2

		bullet = getDefaultBullet()
		bullet.Anchored = true
		bullet.Position = midPosition
		bullet.CFrame = CFrame.new(midPosition, position)
		bullet.Size += Vector3.new(0, 0, magnitude)
	else
		local direction = (position - originPosition).Unit * 
			(Configuration.BulletSpeed * magnitude)

		bullet = getDefaultBullet()
		bullet.Anchored = false
		bullet.Position = originPosition
		bullet.CFrame = CFrame.new(originPosition, position)
		bullet.Size += Vector3.new(0, 0, Configuration.BulletProperties.Sizes.Z)

		local newAttachment = Instance.new("Attachment", bullet)
		local newLinearVelocity = Instance.new("LinearVelocity", bullet)

		newLinearVelocity.Attachment0 = newAttachment
		newLinearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
		newLinearVelocity.VectorVelocity = direction
	end

	Debris:AddItem(bullet, speed or Configuration.BulletLifetime)
end

local function loadCoreAnimations()
	if Character and not LoadedCoreAnims then
		local humanoid: Humanoid = Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			LoadedCoreAnims = true
			
			local animTable = Configuration.Animations[humanoid.RigType.Name]
			local animFolder = Tool.Animations
			
			if animTable.Idle then
				animFolder.Idle.AnimationId = "rbxassetid://"..animTable.Idle
			end
			
			if animTable.Reload then
				animFolder.Reload.AnimationId = "rbxassetid://"..animTable.Reload
			end
			
			if animTable.Shoot then
				animFolder.Shoot.AnimationId = "rbxassetid://"..animTable.Shoot
			end
		end
	end
end

local function onShootTarget(player: Player, position: Vector3)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {Tool, Character}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local originPosition = Muzzle.Position + Muzzle.CFrame.LookVector
	local direction = (position - originPosition).Unit * Configuration.MaxDistance
	local raycast = workspace:Raycast(originPosition, direction, raycastParams)

	if raycast then
		local Model: Model = raycast.Instance:FindFirstAncestorOfClass("Model")
		local Humanoid: Humanoid = Model and Model:FindFirstChildOfClass("Humanoid")
		
		Handle.Fire:Play()
		
		if Configuration.BulletVisualization then
			visualizeBullet(raycast.Position)
		end
		
		if Humanoid and Humanoid.Health > 0 then
			if Configuration.SafeProtection then
				if Model:FindFirstChildOfClass("ForceField") then
					return
				end
			end
			
			if isRealPlayer(Model) and canShootNonTeamPlayer(Model) and checkForFriendlyFire(player, Model) then
				Handle.Hitmark:Play()

				if Configuration.HeadshotEnabled and raycast.Instance.Name == "Head" then
					Humanoid.Health -= Configuration.HeadDamage
					return
				end
				
				if Configuration.CreatorTag then
					clearCreatorTags(Humanoid)
					createCreatorTag(Humanoid, player.Name)
				end

				Humanoid.Health -= Configuration.BaseDamage
			end
		end
	end
end

local function reloadWeapon()
	ReloadDebounce = true
	Handle.Reload:Play()
	
	Reloading.Value = true
	task.wait(Configuration.ReloadSpeed)
	Reloading.Value = false
	
	CurrentAmmo = Configuration.MaxAmmo
	updateCurrentAmmo()
	
	ReloadDebounce = false
end

OnShoot.OnServerEvent:Connect(function(player, ...)
	local args = table.pack(...)
	args["n"] = nil
	
	if not Character or player.Name ~= Character.Name then
		return
	end
	
	if args[1] == "Shoot" then
		local position = args[2]
		if typeof(position) ~= "Vector3" then
			return
		end		

		if not ShootingDebounce and not ReloadDebounce then
			ShootingDebounce = true

			if CurrentAmmo <= 0 and not Configuration.InfiniteAmmo then
				reloadWeapon()
			else
				CurrentAmmo -= 1
				
				updateCurrentAmmo()
				onShootTarget(player, position)
				
				task.wait(Configuration.FireRate)
			end

			ShootingDebounce = false
		end
	end
	
	if args[1] == "Reload" then
		if CurrentAmmo ~= Configuration.MaxAmmo then
			if not ReloadDebounce and not ShootingDebounce then
				if not Configuration.InfiniteAmmo then
					reloadWeapon()
				end
			end
		end
	end
end)

Tool.Equipped:Connect(function()
	Character = Tool.Parent
	loadCoreAnimations()
end)

Tool.Unequipped:Connect(function()
	Character = nil
end)

updateCurrentAmmo()