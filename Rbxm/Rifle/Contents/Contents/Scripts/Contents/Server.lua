--!nocheck

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Gun = script.Parent.Parent

local Remotes = Gun.Remotes
local Config = require(Gun.Configuration)

local Barrel = Gun.Barrel
local Handle = Gun.Handle

local isToolEquipped = false
local reloading = false

local currentAmmo = Config.Reload.Enabled and Config.Reload.MaxAmmo 
	or math.huge

local deltaTime = os.clock()
local playerOwner

local function tween(object: Instance, info: TweenInfo, propertyTable: {}): Tween
	local newTween = TweenService:Create(object, info, propertyTable)
	newTween:Play()

	return newTween
end

local function playSound(name: string)
	local soundId: string? = Config.Sounds[name]
	if not soundId then 
		return
	end

	local soundObject: Sound = Handle:FindFirstChild(name)
	if not soundObject then
		local newSound = Instance.new("Sound", Handle)
		newSound.SoundId = soundId
		newSound.Name = name

		for setting: string, value: any in Config.SoundSettings do
			newSound[setting] = value
		end
		soundObject = newSound
	end

	soundObject:Play()
end

local function isValueInTable(object: Instance, t: {}): boolean
	local objectsInDict = {}
	for _, value: Instance in t do
		objectsInDict[value] = value
	end

	if objectsInDict[object] then
		return true
	end
	return false
end

local function getCharacterFromPart(char: BasePart?): Model?
	if typeof(char) == "Model" then
		return char
	end

	if char.Parent:IsA("Model") then
		return char.Parent
	end

	local isModel = char:FindFirstAncestorOfClass("Model")
	if isModel then
		return isModel
	end
end

local function forceReload(player: Player)
	if reloading then return end
	if Config.Reload.Enabled and currentAmmo ~= Config.Reload.MaxAmmo then
		reloading = true

		playSound("Reload")
		Remotes.Display:FireClient(player, "Reloading")

		task.wait(Config.Reload.Speed)

		currentAmmo = Config.Reload.MaxAmmo
		Remotes.Display:FireClient(player, "Update", currentAmmo)

		reloading = false
	end
end

local function onShoot(player: Player, raycastResult: RaycastResult)
	local bulletsFolder: Folder = workspace[Config.BulletFolderName]
	local middlePosition = (Barrel.Origin.WorldPosition + raycastResult.Position) / 2

	if Config.Bullet.Enabled then
		local newBullet = Instance.new("Part", bulletsFolder)
		newBullet.Anchored = true
		newBullet.Size = Vector3.new(Config.Bullet.Size, Config.Bullet.Size, raycastResult.Distance)
		newBullet.CFrame = CFrame.lookAt(middlePosition, raycastResult.Position)
		newBullet.Color = Config.Bullet.Color
		newBullet.Material = Config.Bullet.Material
		newBullet.CanTouch = false
		newBullet.CanCollide = false
		newBullet.CastShadow = false
		newBullet.Transparency = Config.Bullet.Transparency

		local info = TweenInfo.new(Config.Bullet.Lifespan)
		tween(newBullet, info, {Transparency = 1})

		Debris:AddItem(newBullet, Config.Bullet.Lifespan)
	end

	if Config.Reload.Enabled then
		currentAmmo -= 1
	end

	if Config.BulletMarkEnabled and Config.Bullet.Enabled then
		local exclusions: {Instance?} = Config.OnBulletMark(raycastResult)
		if exclusions then
			for _, object: Instance in exclusions do
				if not isValueInTable(object, Config.Exclusions) then
					table.insert(Config.Exclusions, object)
				end
			end
		end
	end

	playSound("Shoot")
	Remotes.Display:FireClient(player, "Update", currentAmmo)

	local bodyPart: BasePart? = raycastResult.Instance
	local char: Model? = bodyPart and getCharacterFromPart(bodyPart)
	if char then
		local humanoid: Humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			local target: Player? = Players:GetPlayerFromCharacter(char)
			if Config.CheckForPlayers and not target then
				return
			end

			if Config.NoFriendlyFire and target then
				if player.Team.Name == target.Team.Name then
					return
				end
			end

			if Config.CreatorTag.Enabled then
				local creatorTag: StringValue = humanoid:FindFirstChild(Config.CreatorTag.Name) or
					Instance.new("StringValue", humanoid)

				creatorTag.Name = Config.CreatorTag.Name
				creatorTag.Value = player.Name
			end

			local totalDamage = Config.BodyPartDamageEnabled and 
				Config.CustomBodyParts[bodyPart.Name] or Config.Damage

			if Config.CheckForForceField then
				humanoid:TakeDamage(totalDamage)
			else
				humanoid.Health -= totalDamage
			end
		end
	end
end

local function requestToShoot(player: Player, origin: Vector3)
	if not isToolEquipped then return end
	if reloading then return end

	if typeof(origin) ~= "Vector3" then
		return
	end

	local diff = (origin - Barrel.Origin.WorldPosition)
	if diff.Magnitude > Config.MaxDistance then
		return
	end

	if Config.Reload.Enabled and currentAmmo <= 0 then
		playSound("NoAmmo")
		forceReload(player)

		return
	end

	if (os.clock() - deltaTime) < Config.Rate then
		return
	end
	deltaTime = os.clock()

	local bulletsFolder = workspace:FindFirstChild(Config.BulletFolderName)
	if not bulletsFolder then
		bulletsFolder = Instance.new("Folder", workspace)
		bulletsFolder.Name = Config.BulletFolderName
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {
		bulletsFolder, player.Character, Gun, table.unpack(Config.Exclusions)
	}

	local distance, barrelPosition = diff.Magnitude, Barrel.Origin.WorldPosition
	local raycastResult = workspace:Raycast(barrelPosition, diff.Unit * (distance + 1), raycastParams)

	if raycastResult then
		onShoot(player, raycastResult)
	end
end

Gun.Equipped:Connect(function()
	isToolEquipped = true

	local player: Player = Players:GetPlayerFromCharacter(Gun.Parent)
	if player then
		playerOwner = player
		Remotes.Display:FireClient(player, "Show", Gun.Name, currentAmmo)
	end
end)

Gun.Unequipped:Connect(function()
	isToolEquipped = false

	if playerOwner then
		Remotes.Display:FireClient(playerOwner, "Hide")
		playerOwner = nil
	end
end)

Remotes.Shoot.OnServerEvent:Connect(requestToShoot)
Remotes.Reload.OnServerEvent:Connect(forceReload)