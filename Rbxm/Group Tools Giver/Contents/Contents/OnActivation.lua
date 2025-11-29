--!nocheck
-- @fattah412

--[[

A system to give the player tools if they have the required rank to do so.
Comments are provided.

- You can edit everything before the main script
- This system supports multiple groups
- 'STORAGE' is where all the tools are located, such as inside a folder
- You can swap out my model with yours by changing the 'REFERENCE_PART' and 'CLICK_DETECTOR'
- There is a template in 'GROUPS' for you to edit or add
- 'TOOLS' contains strings of names (tool names) in an array format
- The only important components is the 'REFERENCE_PART', 'CLICK_DETECTOR' and this script
- Supports both group rank and group roles. However, only one can be enabled for each group table

]]

---------------------------------------------------------------------------------

--> Customizable Settings

local STORAGE = game:GetService("ServerStorage") -- Where the tools are located, and will be used to search for them

local REFERENCE_PART = script.Parent.ReferencePart -- The part that the ClickDetector is in 
local CLICK_DETECTOR: ClickDetector = REFERENCE_PART.ClickDetector -- The ClickDetector itself
local ON_CLICK_COOLDOWN = 1 -- How long before the same player can click again
local PREVENT_MULTI_ITEMS = true -- If enabled, If a tool is already in the player's backpack, no additional tools will be given

local TOOLS = { -- The tools that will be given for the player
	"ToolA", "ToolB"
}

local GROUPS = { -- All the groups that can click on the button
	{ -- You can use this template

		GroupId = 7; -- The Group Id

		UseRanks = false; -- If enabled, uses the 'RankSettings' table to check for your rank
		RankSettings = {
			MinRank = 1; -- The minimum rank that the player is required to have inorder to click on the part
			MaxRank = 255; -- The maximum rank that the player can have to click on the part. Setting this to the 'MinRank' would only allow one rank to click on the part
		};

		UseRoles = true; -- If enabled, uses the 'RoleSettings' table to check for your role
		RoleSettings = {
			IgnorePositions = true;  -- If enabled, any roles that are above the mentioned role (first string) would be able to click on the part (This is to prevent typing every role in the group)
			Roles = { -- All the roles needed to click on the part (Only uses the first role if 'IgnorePositions' is enabled)
				"Member"; -- If 'IgnorePositions' is enabled, this will be used and any further added roles would be excluded
				"Group Admin";	
				"Owner";
			};
		};

	};
}

local function OnSuccess(player: Player)
	print(player, "Success!")
end

local function OnFailure(player: Player)
	print(player, "Failure!")
end

---------------------------------------------------------------------------------

--> Internal (Do not touch!)

local groupService = game:GetService("GroupService")
local playerDebounces = {}

local registeredGroups = {}
do
	for _, v in pairs(GROUPS) do
		local success, result = pcall(groupService.GetGroupInfoAsync, groupService, v.GroupId)
		if success and result then
			registeredGroups[v.GroupId] = {}
			for _, role in pairs(result.Roles) do
				registeredGroups[v.GroupId][role.Name] = role.Rank
			end
		end
	end
end

local function checkForValidation(player: Player)
	for _, v in pairs(GROUPS) do
		if v.UseRanks then
			local playerRank = player:GetRankInGroup(v.GroupId)
			if playerRank and playerRank >= v.RankSettings.MinRank and playerRank <= v.RankSettings.MaxRank then
				return true
			end
		elseif v.UseRoles then
			local playerRole = player:GetRoleInGroup(v.GroupId)
			if not v.RoleSettings.IgnorePositions then
				if playerRole and table.find(v.RoleSettings.Roles, playerRole) then
					return true
				end
			else
				local tab = registeredGroups[v.GroupId]
				if tab then
					local playerRank = player:GetRankInGroup(v.GroupId)
					if playerRank and tab[v.RoleSettings.Roles[1]] then
						if playerRank >= tab[v.RoleSettings.Roles[1]] then
							return true
						end
					end
				else
					if playerRole and table.find(v.RoleSettings.Roles, playerRole) then
						return true
					end
				end
			end
		end
	end
end

local function getMagnitude(player: Player)
	local char = player.Character
	if char and char.PrimaryPart then
		return (char:GetPivot().Position - REFERENCE_PART.Position).Magnitude
	end
end

local function giveTools(player: Player)
	local backpack = player.Backpack
	for _, v in pairs(TOOLS) do
		local tool = STORAGE:FindFirstChild(v)
		if tool and tool:IsA("Tool") then
			if PREVENT_MULTI_ITEMS then
				local existingTool = backpack:FindFirstChild(v)
				if existingTool then
					if not existingTool:IsA("Tool") then
						tool:Clone().Parent = backpack
					end
				else
					tool:Clone().Parent = backpack
				end
			else
				tool:Clone().Parent = backpack
			end
		end
	end
end

CLICK_DETECTOR.MouseClick:Connect(function(player)
	if playerDebounces[player.UserId] then
		if os.time() - playerDebounces[player.UserId] < ON_CLICK_COOLDOWN then
			return
		end
	end

	playerDebounces[player.UserId] = os.time()

	local dist = getMagnitude(player)
	if dist and dist <= CLICK_DETECTOR.MaxActivationDistance and checkForValidation(player) then
		giveTools(player) OnSuccess(player)
	else
		OnFailure(player)
	end
end)