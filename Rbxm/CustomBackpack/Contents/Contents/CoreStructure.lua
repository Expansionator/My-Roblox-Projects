--!nocheck
-- @fattah412

--[[

CustomBackpack:
A custom backpack system that is supposed to imitate the old roblox backpack.

----------------------------------------------------------------------------

Notes:

- Place this in StarterGui (recommended)
- This script is still new, some bugs might occur
- You can recreate your own UI, but with the same name, parents and properties
- This script should serve as a starter template, where you can add, fix or remove certain elements of the script

----------------------------------------------------------------------------

]]

local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService('RunService')
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")

local ScreenGui = script.Parent
local Container = ScreenGui.Container
local Slots = Container.Slots
local ViewInventory = Container.ViewInventory.Button
local Inventory = Container.Inventory
local Contents = Inventory.Contents
local SearchBar = Inventory.SearchBar.Input
local EmptyHotbar = Inventory.EmptyHotbar.Button
local ToolTip = Container.ToolTip

local maxBackpackSlots = 9
local playerSlots, playerInventory, toolConnections = {}, {}, {}
local originalTemplateButton = Contents.Template
local originalInvSize, isAnimationPlaying = Inventory.Size, false
local xOffset, yOffset = 25, 55
local holdingItem, holderItemData, charConnection

local KeycodesMapTable = {
	[Enum.KeyCode.One] = 1;
	[Enum.KeyCode.Two] = 2;
	[Enum.KeyCode.Three] = 3;
	[Enum.KeyCode.Four] = 4;
	[Enum.KeyCode.Five] = 5;
	[Enum.KeyCode.Six] = 6;
	[Enum.KeyCode.Seven] = 7;
	[Enum.KeyCode.Eight] = 8;
	[Enum.KeyCode.Nine] = 9;
}

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

for i = 1, maxBackpackSlots do
	playerSlots["Slot"..i] = {
		Tool = nil;
		Equipped = false;
	}
end

local function tween(...)
	local newTween = TweenService:Create(...)
	newTween:Play()

	return newTween
end

local function getHumanoid()
	if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
		return player.Character:FindFirstChildOfClass("Humanoid")
	end
end

local function updateInventoryFrame()
	local increment = 0.05
	local tweenInfo = TweenInfo.new(.25, Enum.EasingStyle.Sine)

	if isAnimationPlaying then return end
	isAnimationPlaying = true

	if Inventory.Visible then		
		holderItemData = nil
		if holdingItem then
			holdingItem:Destroy()
			holdingItem = nil
		end

		local Tween = tween(Inventory, tweenInfo, {Size = originalInvSize - UDim2.fromScale(increment, increment)})
		Tween.Completed:Wait()

		Inventory.Visible = false
	else
		Inventory.Visible = true
		Inventory.Size = originalInvSize - UDim2.fromScale(increment, increment)

		local Tween = tween(Inventory, tweenInfo, {Size = originalInvSize})
		Tween.Completed:Wait()
	end

	isAnimationPlaying = false
end

local function showHoveringItem()
	local mousePos = UIS:GetMouseLocation()
	local newTemplate = originalTemplateButton:Clone()
	newTemplate.Active = false
	newTemplate.Parent = ScreenGui
	newTemplate.Size = UDim2.fromScale(.045,.09)
	newTemplate.Name = "HoveringItem"
	newTemplate.Position = UDim2.fromOffset(mousePos.X - xOffset, mousePos.Y - yOffset)
	newTemplate.Visible = true

	local newUIStroke = Instance.new("UIStroke", newTemplate)
	newUIStroke.Color = Color3.fromRGB(123, 132, 255)
	newUIStroke.Enabled = true
	newUIStroke.Thickness = 2
	newUIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	holderItemData = nil
	if holdingItem then
		holdingItem:Destroy()
		holdingItem = nil
	end

	holdingItem = newTemplate
	return newTemplate
end

local function findAvailableSlot()	
	for i = 1, maxBackpackSlots do
		if not playerSlots["Slot"..i].Tool then
			return i
		end
	end
end

local function findToolHotbarSlot(tool: Tool)
	for i = 1, maxBackpackSlots do
		if playerSlots["Slot"..i].Tool and playerSlots["Slot"..i].Tool == tool then
			return i
		end
	end
end

local function resetInventoryButton(tool: Tool)
	for i, _ in playerInventory[tool].Connections do
		playerInventory[tool].Connections[i]:Disconnect()
		playerInventory[tool].Connections[i] = nil
	end

	playerInventory[tool].Button:Destroy()
	playerInventory[tool].Tool = nil
	playerInventory[tool].Button = nil
	playerInventory[tool] = nil
end

local function resetHotbarSlot(slot: number)
	playerSlots["Slot"..slot].Tool = nil
	playerSlots["Slot"..slot].Equipped = false

	local hotbarItem = Slots["Hotbar_"..slot]
	hotbarItem.Item.Text = ""
	hotbarItem.Icon.Image = ""
	hotbarItem.Selector.Enabled = false
end

local function doesToolExist(tool: Tool)
	for _, v in playerSlots do
		if v.Tool and v.Tool == tool then
			return true
		end
	end

	for _, v in playerInventory do
		if v.Tool and v.Tool == tool then
			return true
		end
	end
end

local function oppBackpackRemoved(tool: Tool)
	local slot = findToolHotbarSlot(tool)
	if doesToolExist(tool) then
		if slot then
			if playerSlots["Slot"..slot].Equipped then
				resetHotbarSlot(slot)
			end
		else
			if playerInventory[tool] then
				resetInventoryButton(tool)
			end
		end
	end
end

local function insertIntoInventory(tool: Tool)	
	local newTemplate = originalTemplateButton:Clone()
	newTemplate.Name = tool.Name
	newTemplate.Parent = Contents
	newTemplate.Visible = true

	if tool.TextureId:gsub("%s+", "") == "" then
		newTemplate.Item.Text = tool.Name
	else
		newTemplate.Image = tool.TextureId
	end

	playerInventory[tool] = {
		Tool = tool;
		Button = newTemplate;
		Connections = {};
	}

	playerInventory[tool].Connections["Hover"] = newTemplate.MouseButton1Down:Connect(function()
		local hoverItem = showHoveringItem()
		holderItemData = {
			Root = "Inventory",
			Tool = tool,
		}

		if tool.TextureId:gsub("%s+", "") == "" then
			hoverItem.Item.Text = tool.Name
		else
			hoverItem.Image = tool.TextureId
		end
	end)
end

local function insertIntoHotbar(tool: Tool, slot: number)
	playerSlots["Slot"..slot].Tool = tool
	playerSlots["Slot"..slot].Equipped = false

	local hotbarItem = Slots["Hotbar_"..slot]
	if tool.TextureId:gsub("%s+", "") == "" then
		hotbarItem.Item.Text = tool.Name
	else
		hotbarItem.Icon.Image = tool.TextureId
	end
end

local function unequipTool(slot: number)
	local humanoid: Humanoid = getHumanoid()
	if not humanoid then return end

	playerSlots["Slot"..slot].Equipped = false
	humanoid:UnequipTools()

	Slots["Hotbar_"..slot].Selector.Enabled = false
	ToolTip.Text = ""
end

local function equipTool(slot: number)
	local humanoid: Humanoid = getHumanoid()
	if not humanoid then return end

	for i = 1, maxBackpackSlots do
		unequipTool(i)
	end

	local tool = playerSlots["Slot"..slot].Tool

	playerSlots["Slot"..slot].Equipped = true
	Slots["Hotbar_"..slot].Selector.Enabled = true

	if tool then
		humanoid:EquipTool(tool)

		local gsub = tool.ToolTip:gsub("%s+", "")
		ToolTip.Text = tool.Name..(gsub ~= "" and " [ "..tool.ToolTip.." ]" or "")
	end
end

local function backpackRemoved(tool: Tool)
	if not tool:IsA("Tool") then return end

	local slot = findToolHotbarSlot(tool)
	if doesToolExist(tool) then
		if slot then
			if not playerSlots["Slot"..slot].Equipped then
				resetHotbarSlot(slot)
			end
		else
			if playerInventory[tool] then
				resetInventoryButton(tool)
			end
		end
	end
end

local function backpackAdded(tool: Tool)
	if not tool:IsA("Tool") then return end

	local slot = findAvailableSlot()
	if doesToolExist(tool) then return end

	if slot then
		unequipTool(slot)
		insertIntoHotbar(tool, slot)

		if not toolConnections[tool] then
			toolConnections[tool] = tool.Changed:Connect(function()
				if tool.Parent ~= player.Backpack and tool.Parent ~= player.Character then
					oppBackpackRemoved(tool) ToolTip.Text = ""
					toolConnections[tool]:Disconnect()
				end
			end)
		end
	else
		insertIntoInventory(tool)
	end
end

local function hookNewBackpack(backpack: Backpack, char: Model)
	for i, v in playerSlots do
		if v.Tool and (v.Tool.Parent ~= backpack and v.Tool.Parent ~= char) then
			local slot = findToolHotbarSlot(v.Tool)
			if slot then
				resetHotbarSlot(slot)
			end
		end
	end

	ToolTip.Text = ""

	for i, v in playerInventory do
		if v.Tool and (v.Tool.Parent ~= backpack and v.Tool.Parent ~= char) then
			if playerInventory[v.Tool] then
				resetInventoryButton(v.Tool)
			end
		end
	end

	for _, tool in backpack:GetChildren() do
		if tool:IsA("Tool") and tool.Parent == backpack then
			backpackAdded(tool) 
		end
	end

	local conn1 = backpack.ChildAdded:Connect(backpackAdded)
	local conn2 = backpack.ChildRemoved:Connect(backpackRemoved)
	local conn3

	conn3 = backpack.Destroying:Once(function()
		conn1:Disconnect() conn2:Disconnect()
		conn3:Disconnect()
	end)
end

local function checkForCharacter(char: Model)
	if charConnection then
		if not charConnection.Connected then
			charConnection = nil
		else
			charConnection:Disconnect()
			charConnection = nil
		end
	end

	hookNewBackpack(player.Backpack, char)

	if not charConnection then
		charConnection = char.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and not doesToolExist(child) then
				for i = 1, maxBackpackSlots do
					unequipTool(i)
				end
				backpackAdded(child)
			end
		end)
	end
end

EmptyHotbar.Activated:Connect(function()
	local humanoid: Humanoid = getHumanoid()
	if not humanoid then return end

	humanoid:UnequipTools()
	for i = 1, maxBackpackSlots do
		local tab = playerSlots["Slot"..i]
		if tab.Tool then
			insertIntoInventory(tab.Tool)
			resetHotbarSlot(i)
		end
	end
end)

SearchBar:GetPropertyChangedSignal("Text"):Connect(function()
	Contents.CanvasPosition = Vector2.new(0,0)
	for _, imageButton in Contents:GetChildren() do
		if imageButton:IsA("ImageButton") and imageButton ~= originalTemplateButton then
			imageButton.Visible = imageButton.Name:lower():find(SearchBar.Text:lower()) and true or false
		end
	end
end)

UIS.InputBegan:Connect(function(input, gp)	
	if not gp then
		if input.KeyCode == Enum.KeyCode.Backquote then
			updateInventoryFrame()
		elseif KeycodesMapTable[input.KeyCode] then
			local slot = KeycodesMapTable[input.KeyCode]
			if playerSlots["Slot"..slot].Equipped then
				unequipTool(slot)
			else
				equipTool(slot)
			end
		elseif input.KeyCode == Enum.KeyCode.Backspace then
			for _, v in playerSlots do
				if v.Tool and v.Tool.CanBeDropped and v.Equipped then
					oppBackpackRemoved(v.Tool)
				end
			end
		end
	end
end)

UIS.InputEnded:Connect(function(input, gp)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or
		input.UserInputType == Enum.UserInputType.Touch then

		if holdingItem and holderItemData then			
			local mousePos = UIS:GetMouseLocation() - GuiService:GetGuiInset()
			local guiObjects = playerGui:GetGuiObjectsAtPosition(mousePos.X, mousePos.Y)

			for _, obj in guiObjects do
				if holderItemData.Root == "Hotbar" then
					if obj == Contents then
						local tab = playerSlots["Slot"..holderItemData.Slot]
						if tab.Tool then
							insertIntoInventory(tab.Tool)
							for i = 1, maxBackpackSlots do
								unequipTool(i)
							end

							resetHotbarSlot(holderItemData.Slot)
						end
					elseif obj:IsA("Frame") and obj.Name:find("Hotbar_") and obj.Parent == Slots then
						local slot = obj.Name:gsub("Hotbar_", "")
						slot = tonumber(slot)

						if slot and slot ~= holderItemData.Slot then
							local tab = playerSlots["Slot"..slot]
							for i = 1, maxBackpackSlots do
								unequipTool(i)
							end

							resetHotbarSlot(holderItemData.Slot)

							if tab.Tool then
								insertIntoHotbar(tab.Tool, holderItemData.Slot)
								resetHotbarSlot(slot)
							end

							insertIntoHotbar(holderItemData.Tool, slot)
						end
					end
				elseif holderItemData.Root == "Inventory" and obj:IsA("Frame") and obj.Name:find("Hotbar_") and obj.Parent == Slots then
					local slot = obj.Name:gsub("Hotbar_", "")
					slot = tonumber(slot)

					if slot then
						local tab = playerSlots["Slot"..slot]
						if tab.Tool then
							insertIntoInventory(tab.Tool)
							for i = 1, maxBackpackSlots do
								unequipTool(i)
							end
						end

						resetInventoryButton(holderItemData.Tool)
						resetHotbarSlot(slot)
						insertIntoHotbar(holderItemData.Tool, slot)
					end
				end
			end

			holdingItem:Destroy()
			holdingItem = nil
			holderItemData = nil
		end
	end
end)

player.CharacterAdded:Connect(checkForCharacter)
if player.Character then checkForCharacter(player.Character) end

RunService.Heartbeat:Connect(function()
	if holdingItem then
		local mousePos = UIS:GetMouseLocation()
		holdingItem.Position = UDim2.fromOffset(mousePos.X - xOffset, mousePos.Y - yOffset)
	end

	for i, v in toolConnections do
		if not v.Connected then
			toolConnections[i] = nil
		end
	end
end)

for _, hotbar in Slots:GetChildren() do
	if hotbar:IsA("Frame") and hotbar.Name:match("Hotbar_") then
		local str = hotbar.Name:gsub("Hotbar_", "")
		local slot = tonumber(str)
		if slot then
			local button: ImageButton = hotbar.Button
			button.Activated:Connect(function()
				if playerSlots["Slot"..slot].Equipped then
					unequipTool(slot)
				else
					equipTool(slot)
				end
			end)

			button.MouseButton1Down:Connect(function()
				if playerSlots["Slot"..slot] and playerSlots["Slot"..slot].Tool and Inventory.Visible then
					local newTemplate = showHoveringItem()
					holderItemData = {
						Root = "Hotbar",
						Slot = slot,
						Tool = playerSlots["Slot"..slot].Tool
					}

					if hotbar.Icon.Image:gsub("%s+", "") == "" then
						newTemplate.Item.Text = playerSlots["Slot"..slot].Tool.Name
					else
						newTemplate.Image = hotbar.Icon.Image
					end
				end
			end)
		end
	end
end

ViewInventory.Activated:Connect(updateInventoryFrame)