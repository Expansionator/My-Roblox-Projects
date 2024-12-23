--!nocheck
-- @fattah412

--[[

DataCacher:
A datastore extension module that behaves similarly to a normal datastore.

------------------------------------------------------

Notes:

- This system caches the player's data into a table which can be easily modified
- A basic session-locking mechanism has also been implemented into this system
	If a session is loaded and has not expired, the player will be kicked from the server
- Tables that are returned from Listeners will be a duplicate and is meant to be viewed only
- Listeners can return different types of values
- Auto saving is automatically enabled in this system
- If 'AllowClientSideToRead' is true, you have to invoke the RemoteFunction that is located inside ReplicatedStorage to retrieve the client data
	Warning: The data received will show the whole contents of the player's data
- If 'ViewRawData' is true, you cannot modify that data
- You can only migrate/import ('MigratedData') new data if it had not been saved
- If datastores are not able to run, this server will not be able to use datastore methods such as GetAsync(), UpdateAsync() and SetAsync()

------------------------------------------------------

Usage:

--> Functions:

DataCacher.CreateDatastore(DatastoreKey: string, DatastoreOptions: DatastoreOptions?)
> Description: Creates and Registers a datastore object
> Returns: Datastore: {@metatable}

DataCacher.GetRegisteredDatastore(DatastoreKey: string, Timeout: number?)
> Description: Gets a registered datastore, with all raw table-sets (self)
> Returns: Datastore: {@metatable}

Datastore:Load(player: Player, MigratedData: {}?): {}
> Description: Loads the player's data, with an option to use an existing data as a 'template'
> Note: The player will be kicked if there is already a session active
> Returns: Data: {}

Datastore:Save(player: Player, Callback: (data: {}, oldData: {}) -> {}?, AutoSaving: boolean?): boolean
> Description: Saves the player's data using UpdateAsync, with an option to configure what it should save
> Returns: Success: boolean

Datastore:Get(player: Player, ViewRawData: boolean?): {}
> Description: Gets the player's cached data, or if 'ViewRawData' is true, returns a duplicate of the raw data
> Returns: Data: {} | Raw Data: {}

Datastore:Wipe(player: Player)
> Description: Clears the player's data and replacing it with a fresh one, and using the method SetAsync to overwrite the player's data
> Returns: nil | void

Datastore:GetDataAsync(UserId: number): {}
> Description: Returns a duplicate of the player's saved or used data (if any), which can be saved (via SaveDataAsync()) later
> Returns: Data: {}

Datastore:SaveDataAsync(UserId: number, Data: {}, ForceSave: boolean?): boolean
> Description: Saves the provided data using SetAsync, preferably data from GetDataAsync()
> Notes: This function will not save if there is already a session active
		 If ForceSave is true, data will be saved regardless if there is an active session
		 This *would* result in data loss if the session is active
> Returns: Success: boolean

Datastore:GetListener(ListenerType: Listeners, Callback: (player: Player, ...any) -> nil)
> Description: Listens to when the player's data is added, modified, removed, wiped or auto-saved
> Returns: nil | void
> Methods [Listener Type]: Changed | Loaded | Released | Wiped | AutoSave

Datastore:RemoveListener(ListenerType: Listeners)
> Description: Stops listening to an existing active listener
> Returns: nil | void
> Methods [Listener Type]: Changed | Loaded | Released | Wiped | AutoSave

Datastore:ClearListeners()
> Description: Similar to RemoveListener(), except that it's for all listener types
> Returns: nil | void

DataCacher:GetDatastoreObject(): DataStore?
> Description: Returns the actual datastore object
> Returns: DataStore

------------------------------------------------------

Example Usage:

local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local DataCacher = require(ServerScriptService.DataCacher)

local TemplateData = {
	Coins = 0;
}

local DatastoreOptions = {
	CreateListeners = true;
	TemplateData = TemplateData;
}

local DatastoreKey = "Coins"
local Datastore = DataCacher.CreateDatastore(DatastoreKey, DatastoreOptions)

Players.PlayerAdded:Connect(function(player)
	local data = Datastore:Load(player)
	if data then
		local rawData = Datastore:Get(player, true)
		print('Data Loaded! - Version: '..(rawData and rawData.Version or "?"))
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local success = Datastore:Save(player)
	if success then
		print('Data Saved!')
	end
end)

local unusedTable = {}
Datastore:GetListener("Changed", function(player: Player, oldData: {}, newData: {})
	table.insert(unusedTable, 
		"Data changed!".." Old: "..oldData.Coins.." | New: "..newData.Coins)
	
	if #unusedTable % 30 == 0 then
		print('Data has reached '..newData.Coins..' coins!')
	end
end)

Datastore:GetListener("Loaded", function(player: Player, newData: {})
	print(player.Name.."'s data has been loaded!", newData)
end)

Datastore:GetListener("Released", function(player: Player)
	print(player.Name.."'s data has now been removed!")
end)

Datastore:GetListener("AutoSave", function(player: Player)
	print(player.Name.."'s data was auto-saved!")
end)

while true do
	for _, player: Player in Players:GetPlayers() do
		local data = Datastore:Get(player)
		if data then
			data.Coins += 1
		end
	end
	
	task.wait(1)
end

------------------------------------------------------

]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DatastoreService = game:GetService("DataStoreService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local DataCacher = {}
DataCacher.__index = DataCacher

---------------------------------------

--// The total time, in seconds, for a session to be expired for other entries to use the session
local SESSION_LOCK_TIMEOUT: number = 30 * 60

--// The time, in seconds, for data to be saved and for a new session key to be generated to prevent expiration 
-->> *MUST BE LOWER THAN SESSION_LOCK_TIMEOUT*
local AUTO_SAVE_INTERVAL: number = 5 * 60

--// The message that is displayed when the player is kicked from having an active session
local SESSION_KICK_MESSAGE: string = "A session was already loaded! Please rejoin later."

--// The total decimal places to round for
local DECIMAL_PLACES: number = 3

--// Uses this string if the text fails to filter
local FILTERED_RESULT: string = "###?"

--// Uses this datastore name to check if datastores are enabled (in Studio)
local BURNER_DATASTORE_NAME: string = "____DS"

--// The time, in seconds, that Load() has to wait if the player rejoined too quickly
local THRESHOLD_FOR_REQUEST_CALLS: number = 10 

---------------------------------------
----------- DEBUGGING TOOLS -----------

local ALLOW_GETASYNC_CALLS = true
local ALLOW_UPDATEASYNC_CALLS = true

---------------------------------------

local TemplateOptions = {
	--// The key used to save the player's data (%i is the player's userid)
	Key = "Player_%i";

	--// The default data assigned to the player
	TemplateData = {};

	--// Creates a signal that are tasked to listen to when data is modified, loaded or released
	CreateListeners = false;

	--// Compresses/Rounds floating point numbers (like 3.142) to the nearest ('x') decimal places
	CompressFloatNumbers = false;

	--// Filters out the strings that are in the player's data when it is loaded
	FilterStringContent = false;

	--// Filtering Options for 'FilterStringContent'
	FilterStringContentOptions = {
		--// Allows only certain string indexes to be filtered
		WhiteListEnabled = false;

		--// Allows it to filter every string indexes except the ones that are mentioned in the list
		BlackListEnabled = false;

		--// The list (array of strings) for WhiteList/BlackList
		StringIndexList = {};
	};

	--// Creates a RemoteFunction to allow clients to *read* their *own* data
	AllowClientSideToRead = false;

	--// The name for the RemoteEvent ('AllowClientSideToRead')
	ClientSideAgent = "DataCacherRemote";

	--// If data fails to save/load, it will retry for a specified amount of attempts before it is considered to be a failure
	RecursiveCalls = true;

	--// The amount of attempts to save/load data ('RecursiveCalls')
	CallAttempts = 5;

	--// The delay between each saving/loading attempt
	RetryCallDelay = 1;
}

export type Listeners = "Changed" | "Loaded" | "Released" | "Wiped" | "AutoSave"
export type DatastoreOptions = {
	Key: string?;
	ClientSideAgent: string?;

	TemplateData: {}?;

	CreateListeners: boolean?;
	CompressFloatNumbers: boolean?;
	FilterStringContent: boolean?;
	AllowClientSideToRead: boolean?;
	RecursiveCalls: boolean?;

	FilterStringContentOptions: {
		WhiteListEnabled: boolean?;
		BlackListEnabled: boolean?;

		StringIndexList: {}?;
	}?;

	CallAttempts: number?;
	RetryCallDelay: number?;
}

local _g_header = `[{script.Name}]: `
do
	if RunService:IsClient() then
		error(_g_header.."Module cannot be required by the client!")
	end

	if AUTO_SAVE_INTERVAL >= SESSION_LOCK_TIMEOUT then
		error(_g_header.."AUTO_SAVE_INTERVAL cannot be more than SESSION_LOCK_TIMEOUT!")
	end
end

local __is_datstores_enabled = "NO_RESPONSE"
do
	if not RunService:IsStudio() then
		__is_datstores_enabled = true
	else
		task.defer(function()
			local success = pcall(function()
				DatastoreService:GetDataStore(BURNER_DATASTORE_NAME):SetAsync(
					BURNER_DATASTORE_NAME, os.time()
				)
			end)
			__is_datstores_enabled = success
		end)
	end
end

local Globals
do
	Globals = {
		ClientRemote = nil;
		DecimalPlace = nil;

		RegisteredDataStores = {};
		ReadWriteLimits = {
			GET = nil;
			UPDATE = nil;
		};
	}

	local decimal_place = DECIMAL_PLACES
	if decimal_place > 0 then
		local fp_numbers = string.rep("0", decimal_place - 1).."1"
		local total_decimal_places = tonumber("0."..fp_numbers)

		Globals.DecimalPlace = total_decimal_places
	end

	Globals.New = function(className: string, objectProperties: {})
		local object = Instance.new(className)
		if objectProperties then
			for propertyName, propertyValue in objectProperties do
				object[propertyName] = propertyValue
			end
		end
		return object
	end

	Globals.Reconcile = function(tab: {}, template: {})
		local newTable = tab
		for k, v in template do
			if type(k) ~= "string" then continue end
			if newTable[k] == nil then
				if type(v) == "table" then
					newTable[k] = Globals.Duplicate(v)
				else
					newTable[k] = v
				end
			end

			if type(newTable[k]) == "table" and type(v) == "table" then
				Globals.Reconcile(newTable[k], v)
			end
		end
		return newTable
	end

	Globals.Duplicate = function(t: {})
		local newTable = {}
		for index, value in t do
			if typeof(value) == "table" then
				value = Globals.Duplicate(value)
			end
			newTable[index] = value
		end
		return newTable
	end

	Globals.CountDictionary = function(t: {})
		local index = 0
		for _, _ in t do
			index += 1
		end
		return index
	end

	Globals.IsTableIdentical = function(old: {}, new: {})
		if Globals.CountDictionary(old) ~= Globals.CountDictionary(new) then
			return false
		end

		for key, value in old do
			if type(value) == "table" then
				if not Globals.IsTableIdentical(value, new[key]) then
					return false
				end
			elseif new[key] ~= value then
				return false
			end
		end

		return true
	end

	Globals.FilterText = function(player: Player, text: string)
		local success, result = pcall(function()
			local str_result = TextService:FilterStringAsync(text, player.UserId)
			local filtered_text = str_result:GetNonChatStringForBroadcastAsync()
			return filtered_text
		end)
		return success and result or FILTERED_RESULT
	end
end

local Signal
do
	Signal = {
		signal_stored_connections = {};
	}

	Signal.Connect = function(agent, callback)
		if not Signal.signal_stored_connections[agent] then
			Signal.signal_stored_connections[agent] = {
				connection = function(...)
					task.spawn(callback, ...)
				end,
			}
		end
	end

	Signal.Fire = function(agent, ...)
		if Signal.signal_stored_connections[agent] then
			Signal.signal_stored_connections[agent].connection(...)
		end
	end

	Signal.Disconnect = function(agent)
		if Signal.signal_stored_connections[agent] then
			Signal.signal_stored_connections[agent] = nil
		end
	end
end

local function getPlayerKey(player, key)
	return key:format(typeof(player) == "Instance" and player.UserId or player)
end

local function handleNestedTableWithOperation(t, callback)
	local function iterateTable(tab)
		for index, value in tab do
			if typeof(value) == "table" then
				iterateTable(value)
				continue
			end
			callback(index, value)
		end
	end
	iterateTable(t)
end

local function loopTableWithValuesAsDefault(t, callback)
	local newTable = {}
	for index, value in t do
		if typeof(value) == "table" then
			value = loopTableWithValuesAsDefault(value, callback)
		else
			value = callback and callback(value, index) or value
		end
		newTable[index] = value
	end
	return newTable
end

local function checkForArguments(options: DatastoreOptions)
	if options.RecursiveCalls then
		if options.CallAttempts < 1 then
			error(_g_header.."CallAttempts cannot be less than 1 attempt(s)!")
		else
			local totalDuration = options.RetryCallDelay * options.CallAttempts
			if totalDuration >= 30 then
				error(_g_header.."CallAttempts exceeded for more than 30 seconds!")
			end
		end
	end
end

local function isInTheSameSession(session)
	return session.PlaceId == game.PlaceId and session.JobId == game.JobId
end

local function getRequestsLimit()
	return 60 + #Players:GetPlayers() * 10
end

local function isDatastoreEnabledForExperience()
	if __is_datstores_enabled == "NO_RESPONSE" then
		return false
	end
	return __is_datstores_enabled
end

local function waitForDatastoreEnabledResponse()
	if __is_datstores_enabled == "NO_RESPONSE" then
		repeat RunService.Heartbeat:Wait()
		until __is_datstores_enabled ~= "NO_RESPONSE"
	end
end

local function isPlayerInGame(player: Player)
	return player and player:IsDescendantOf(Players)
end

function DataCacher.CreateDatastore(DatastoreKey: string, DatastoreOptions: DatastoreOptions?)
	if Globals.RegisteredDataStores[DatastoreKey] then
		return
	end

	local options = Globals.Duplicate(DatastoreOptions or {})
	options = Globals.Reconcile(options, TemplateOptions)

	checkForArguments(options)

	if options.AllowClientSideToRead then
		if not Globals.ClientRemote then
			local RemoteFunction: RemoteFunction = Globals.New("RemoteFunction", {
				Parent = ReplicatedStorage,
				Name = options.ClientSideAgent
			})

			Globals.ClientRemote = {
				Event = RemoteFunction,
				Registered = {};
			}

			RemoteFunction.OnServerInvoke = function(player: Player, key: string)
				if typeof(key) ~= "string" then return end
				if Globals.ClientRemote.Registered[key] then
					local datastore = DataCacher.GetRegisteredDatastore(key, 1)
					if datastore then
						local data = datastore:Get(player)
						local dupeTable = data and Globals.Duplicate(data)
						return dupeTable
					end
				end
			end
		end

		if not Globals.ClientRemote.Registered[DatastoreKey] then
			Globals.ClientRemote.Registered[DatastoreKey] = DatastoreKey
		end
	end

	local self = {
		__raw = {
			name = DatastoreKey,
			options = options,

			is_shutting_down = false,

			player_data = {},
			kicked_players = {},
			loaded_players = {},

			events = {},
			changed = {},

			operations = {
				write = {},
				player_threshold = {
					players = {},
					queue = {},
				},
			},

			datastore = nil,
		},
	}

	do
		task.spawn(function()
			local success, datastore = pcall(function()
				return DatastoreService:GetDataStore(DatastoreKey)
			end)

			if success and datastore then
				self.__raw.datastore = datastore
				return
			end
			warn(_g_header.."Datastores are not able to function! Using default data for all players.")
		end)
	end

	self.__raw.waitForThrottle = function(method)
		if not Globals.ReadWriteLimits[method] then
			Globals.ReadWriteLimits[method] = {
				requests = 1;
				timer = task.spawn(function()
					task.wait(1 * 60) while true do
						Globals.ReadWriteLimits[method].requests = 0
						task.wait(1 * 60)
					end
				end)
			}
		else
			Globals.ReadWriteLimits[method].requests += 1
			if Globals.ReadWriteLimits[method].requests > getRequestsLimit() then
				repeat RunService.Heartbeat:Wait()
				until Globals.ReadWriteLimits[method].requests <= getRequestsLimit()
			end
		end
	end

	self.__raw.fire = function(Listener, ...)
		if self.__raw.events[Listener] then
			local vargs, args = {}, {...}
			for index = 1, #args do
				local value = args[index]
				if value ~= nil then
					if typeof(value) == "table" then
						local dupe = Globals.Duplicate(value)
						table.insert(vargs, dupe)
					else
						table.insert(vargs, value)
					end
				end
			end

			Signal.Fire(Listener, table.unpack(vargs, 1, #vargs))
		end
	end

	self.__raw.addChangeSpeaker = function(player: Player)
		if options.CreateListeners and self.__raw.events["Changed"] then
			if self.__raw.player_data[player] and not self.__raw.changed[player] then
				local previous_data = Globals.Duplicate(self.__raw.player_data[player].data)
				self.__raw.changed[player] = RunService.Heartbeat:Connect(function()
					local new_data = self.__raw.player_data[player]
					new_data = new_data and new_data.data

					if new_data and not Globals.IsTableIdentical(previous_data, new_data) then
						self.__raw.fire("Changed", player, previous_data, new_data)
						previous_data = Globals.Duplicate(new_data)
					end
				end)
			end
		end
	end

	local Datastore = setmetatable(self, DataCacher)
	Globals.RegisteredDataStores[DatastoreKey] = Datastore

	return Datastore
end

function DataCacher.GetRegisteredDatastore(DatastoreKey: string, Timeout: number?)
	waitForDatastoreEnabledResponse()
	if not Globals.RegisteredDataStores[DatastoreKey] then
		local time_now = os.clock()
		Timeout = Timeout or math.huge

		repeat
			local tab = Globals.RegisteredDataStores[DatastoreKey]
			RunService.Heartbeat:Wait()
		until tab or (os.clock() - time_now) >= Timeout
	end

	return Globals.RegisteredDataStores[DatastoreKey]
end

function DataCacher:Load(player: Player, MigratedData: {}?): {}?
	if self.__raw.is_shutting_down then
		return
	end

	if self.__raw.player_data[player] then
		if table.find(self.__raw.operations.write, player.UserId) then
			repeat task.wait()
			until not table.find(self.__raw.operations.write, player.UserId)
		else
			return
		end
	end

	do
		local current_queue	

		local queue = self.__raw.operations.player_threshold.queue[player.UserId]
		local clock = self.__raw.operations.player_threshold.players[player.UserId]

		self.__raw.operations.player_threshold.queue[player.UserId] = queue and queue + 1 or 1
		current_queue = self.__raw.operations.player_threshold.queue[player.UserId]

		local diff = clock and os.clock() - clock
		if (queue and clock) and diff < THRESHOLD_FOR_REQUEST_CALLS then
			local timeToWait = os.clock() + (THRESHOLD_FOR_REQUEST_CALLS - diff)

			repeat task.wait()
			until os.clock() >= timeToWait
		end

		if self.__raw.operations.player_threshold.queue[player.UserId] ~= current_queue then
			return
		end

		self.__raw.operations.player_threshold.players[player.UserId] = os.clock()
		task.delay(THRESHOLD_FOR_REQUEST_CALLS, function()
			if self.__raw.operations.player_threshold.queue[player.UserId] == current_queue then
				self.__raw.operations.player_threshold.queue[player.UserId] = nil
				self.__raw.operations.player_threshold.players[player.UserId] = nil
			end
		end)
	end

	if not isPlayerInGame(player) then
		return
	end

	waitForDatastoreEnabledResponse()

	local key = getPlayerKey(player, self.__raw.options.Key)
	local function updateAsynchronous()
		local success, result = pcall(function()
			self.__raw.waitForThrottle("GET")
			if isDatastoreEnabledForExperience() then
				return ALLOW_GETASYNC_CALLS and self.__raw.datastore:GetAsync(key)
			end
		end)
		return success, result
	end

	local success, result = updateAsynchronous()
	if self.__raw.options.RecursiveCalls and not success then
		for _ = 1, self.__raw.options.CallAttempts do
			success, result = updateAsynchronous()
			if success then 
				break 
			end

			task.wait(self.__raw.options.RetryCallDelay)
		end
	end

	if not isPlayerInGame(player) then
		return
	end

	if result and result.data then
		if result.Session then
			if result.Session.Active and not isInTheSameSession(result.Session) then
				local difference = os.time() - result.Session.Timestamp
				if difference < SESSION_LOCK_TIMEOUT then
					return player:Kick(SESSION_KICK_MESSAGE)
				end
			end
		end

		local data = self.__raw.options.FilterStringContent and loopTableWithValuesAsDefault(result.data, function(value, index)
			if typeof(index) == "string" and typeof(value) == "string" then
				local filtering_options = self.__raw.options.FilterStringContentOptions
				if filtering_options.WhiteListEnabled then
					if table.find(filtering_options.StringIndexList, index) then
						return Globals.FilterText(player, value)
					end
				elseif filtering_options.BlackListEnabled then
					if not table.find(filtering_options.StringIndexList, index) then
						return Globals.FilterText(player, value)
					end
				else
					return Globals.FilterText(player, value)
				end
			end
			return value
		end) or result.data

		result.data = Globals.Reconcile(data, self.__raw.options.TemplateData)
	end

	local existing_data
	if MigratedData and typeof(MigratedData) == "table" then
		existing_data = Globals.Reconcile(MigratedData, self.__raw.options.TemplateData)
	end

	self.__raw.player_data[player] = result or {data = existing_data or self.__raw.options.TemplateData}
	self.__raw.player_data[player]["LastJoined"] = os.time()
	self.__raw.player_data[player]["Version"] = self.__raw.player_data[player]["Version"] or 1
	self.__raw.player_data[player]["Session"] = self.__raw.player_data[player]["Session"] or {}

	self.__raw.player_data[player]["Session"].Active = true
	self.__raw.player_data[player]["Session"].JobId = self.__raw.player_data[player]["Session"].JobId or game.JobId
	self.__raw.player_data[player]["Session"].PlaceId = self.__raw.player_data[player]["Session"].PlaceId or game.PlaceId
	self.__raw.player_data[player]["Session"].Timestamp = self.__raw.player_data[player]["Session"].Timestamp or os.time()

	if not isInTheSameSession(self.__raw.player_data[player]["Session"]) then
		local difference = os.time() - self.__raw.player_data[player]["Session"].Timestamp
		if difference >= SESSION_LOCK_TIMEOUT then
			self.__raw.player_data[player]["Session"].JobId = game.JobId
			self.__raw.player_data[player]["Session"].PlaceId = game.PlaceId
			self.__raw.player_data[player]["Session"].Timestamp = os.time()
		end
	end

	self:Save(player, nil, true)
	self.__raw.addChangeSpeaker(player)

	self.__raw.fire("Loaded", player, self.__raw.player_data[player]["data"])
	self.__raw.loaded_players[player] = true

	return self.__raw.player_data[player]["data"]
end

function DataCacher:Save(player: Player, Callback: (data: {}, oldData: {}) -> {}?, AutoSaving: boolean?): boolean
	if not self.__raw.player_data[player] then
		return
	end

	waitForDatastoreEnabledResponse()

	local key = getPlayerKey(player, self.__raw.options.Key)
	local data = Globals.Duplicate(self.__raw.player_data[player])

	data["LastLeft"] = not AutoSaving and os.time() or data["LastLeft"]
	data["Version"] = data.Version or 1

	if not AutoSaving then	
		self.__raw.player_data[player] = nil
		if self.__raw.changed[player] then
			self.__raw.changed[player]:Disconnect()
			self.__raw.changed[player] = nil
		end

		if not table.find(self.__raw.operations.write, player.UserId) then
			table.insert(self.__raw.operations.write, player.UserId)
		end
	end

	if self.__raw.options.CompressFloatNumbers then
		data = loopTableWithValuesAsDefault(data, function(value)
			if typeof(value) == "number" then
				return math.floor(value / Globals.DecimalPlace) * Globals.DecimalPlace
			end
			return value
		end)
	end

	local function updateAsynchronous()
		local success, err = pcall(function()
			local is_kicked = self.__raw.kicked_players[player]

			self.__raw.waitForThrottle("UPDATE")
			if isDatastoreEnabledForExperience() then
				self.__raw.datastore:UpdateAsync(key, function(latest_data: {})
					local previous_data = latest_data or {}
					previous_data["Version"] = previous_data.Version or 1

					if is_kicked or data.Version ~= previous_data.Version or not ALLOW_UPDATEASYNC_CALLS then
						return nil
					end

					if Callback then
						return Callback(data, previous_data)
					end

					if AutoSaving then
						if previous_data.Session and not previous_data.Session.Active then
							data.Session.Active = true
							data.Session.JobId = game.JobId
							data.Session.PlaceId = game.PlaceId
						end

						data.Session.Timestamp = os.time()
						return data
					else
						data.Version += 1

						data.Session.Active = false
						data.Session.JobId = nil
						data.Session.PlaceId = nil
						data.Session.Timestamp = nil

						return data
					end
				end)
			end
		end)

		return success, err
	end

	local success, err = updateAsynchronous()
	if self.__raw.options.RecursiveCalls and not success then
		for _ = 1, self.__raw.options.CallAttempts do
			success, err = updateAsynchronous()
			if success then 
				break 
			end

			task.wait(self.__raw.options.RetryCallDelay)
		end
	end

	if not AutoSaving then
		self.__raw.kicked_players[player] = nil
		self.__raw.loaded_players[player] = nil
		self.__raw.fire("Released", player) 

		table.remove(self.__raw.operations.write, table.find(
			self.__raw.operations.write, player.UserId)
		)
	end
	return success
end

function DataCacher:Get(player: Player, ViewRawData: boolean?): {}
	waitForDatastoreEnabledResponse()

	if table.find(self.__raw.operations.write, player.UserId) then
		repeat task.wait()
		until not table.find(self.__raw.operations.write, player.UserId)
	end

	return self.__raw.player_data[player] and 
		(ViewRawData and Globals.Duplicate(self.__raw.player_data[player]) or
			self.__raw.player_data[player]["data"])
end

function DataCacher:Wipe(player: Player)
	waitForDatastoreEnabledResponse()
	if self.__raw.player_data[player] then
		local session = self.__raw.player_data[player]["Session"] or {}

		self.__raw.player_data[player] = {data = self.__raw.options.TemplateData}
		self.__raw.player_data[player]["LastJoined"] = os.time()
		self.__raw.player_data[player]["LastLeft"] = nil
		self.__raw.player_data[player]["Version"] = 1
		self.__raw.player_data[player]["Session"] = session

		local success, err = pcall(function()
			local key = getPlayerKey(player.UserId, self.__raw.options.Key)
			if isDatastoreEnabledForExperience() then
				self.__raw.datastore:SetAsync(key, self.__raw.player_data[player])
			end
		end)

		session = nil
		self.__raw.fire("Wiped", player)
	end
end

function DataCacher:GetDataAsync(UserId: number): {}?
	local key = getPlayerKey(UserId, self.__raw.options.Key)
	local success, result = pcall(function()
		local player_in_game = Players:GetPlayerByUserId(UserId)
		if player_in_game then
			local fetched_data = self.__raw.player_data[player_in_game]
			if fetched_data then
				return fetched_data
			end
		end

		waitForDatastoreEnabledResponse()
		if isDatastoreEnabledForExperience() then
			self.__raw.waitForThrottle("GET")
			return self.__raw.datastore:GetAsync(key)
		end
	end)

	return result and Globals.Duplicate(result)
end

function DataCacher:SaveDataAsync(UserId: number, Data: {}, ForceSave: boolean?): boolean
	local key = getPlayerKey(UserId, self.__raw.options.Key)
	local success, result = pcall(function()
		if not ForceSave then
			local latest_data = self:GetDataAsync(UserId)
			if latest_data.Session and latest_data.Session.Active then
				return false
			end
		end

		waitForDatastoreEnabledResponse()
		if isDatastoreEnabledForExperience() then
			self.__raw.waitForThrottle("UPDATE")
			self.__raw.datastore:SetAsync(key, Data)

			return true
		end
		return false
	end)

	return success and result
end

function DataCacher:GetListener(ListenerType: Listeners, Callback: (player: Player, ...any) -> nil)
	if self.__raw.options.CreateListeners then
		local validListeners = {
			["Changed"] = true;
			["Loaded"] = true;
			["Released"] = true;
			["Wiped"] = true;
			["AutoSave"] = true;
		}

		if validListeners[ListenerType] then
			if not self.__raw.events[ListenerType] then
				self.__raw.events[ListenerType] = {Functions = {}}

				Signal.Connect(ListenerType, function(...)
					for _, callback in self.__raw.events[ListenerType].Functions do
						callback(...)
					end
				end)

				if ListenerType == "Changed" then
					for _, player: Player in Players:GetPlayers() do
						self.__raw.addChangeSpeaker(player)
					end
				end
			end

			table.insert(self.__raw.events[ListenerType].Functions, Callback)
		end
	end
end

function DataCacher:RemoveListener(ListenerType: Listeners)
	if self.__raw.events[ListenerType] then
		Signal.Disconnect(ListenerType)

		table.clear(self.__raw.events[ListenerType].Functions)
		self.__raw.events[ListenerType] = nil

		if ListenerType == "Changed" and Globals.CountDictionary(self.__raw.changed) >= 1 then
			for player: Player, _ in self.__raw.changed do
				self.__raw.changed[player]:Disconnect()
				self.__raw.changed[player] = nil
			end
		end
	end
end

function DataCacher:ClearListeners()
	for listener, _ in self.__raw.events do
		self:RemoveListener(listener)
	end
end

function DataCacher:GetDatastoreObject(): DataStore?
	return self.__raw.datastore
end

local last_thread_running, active_threads = false, {}
local hb_request_calls, hb_success_calls = 0, 0
local auto_save_datastores = {}

RunService.Heartbeat:Connect(function()
	if last_thread_running then return end
	last_thread_running = true

	for key, _ in Globals.RegisteredDataStores do
		local datastore = DataCacher.GetRegisteredDatastore(key, 1)
		if datastore then
			if not auto_save_datastores[key] then
				auto_save_datastores[key] = {}
			end

			for user_id in auto_save_datastores[key] do
				local found_player = Players:GetPlayerByUserId(user_id)
				if not found_player then
					if auto_save_datastores[key][user_id].thread then
						task.cancel(auto_save_datastores[key][user_id].thread)
						auto_save_datastores[key][user_id].thread = nil
					end

					auto_save_datastores[key][user_id].temp_data = nil
					auto_save_datastores[key][user_id] = nil
				end
			end

			for user_key, user_data in active_threads do
				if not user_data.is_alive then
					if user_data.thread then
						task.cancel(user_data.thread)
					end

					user_data.thread = nil
					active_threads[user_key] = nil
				end
			end

			if datastore.__raw.is_shutting_down then
				continue
			end

			for player: Player in datastore.__raw.player_data do
				if player and player:IsDescendantOf(game) then 
					if not auto_save_datastores[key][player.UserId] then
						auto_save_datastores[key][player.UserId] = {
							clock = os.clock(),

							emergency_bypass = false,

							temp_data = nil,
							thread = nil,
						}
					end

					local auto_saving_duration = AUTO_SAVE_INTERVAL
					local difference = os.clock() - auto_save_datastores[key][player.UserId].clock

					if auto_save_datastores[key][player.UserId].emergency_bypass or difference >= auto_saving_duration then
						if difference >= auto_saving_duration then
							auto_save_datastores[key][player.UserId].clock = os.clock()

							if auto_save_datastores[key][player.UserId].thread then
								task.cancel(auto_save_datastores[key][player.UserId].thread)
							end

							auto_save_datastores[key][player.UserId].thread = task.defer(function()
								pcall(datastore.Save, datastore, player, nil, true)
								auto_save_datastores[key][player.UserId].thread = nil
							end)

							datastore.__raw.fire("AutoSave", player)
						end

						local latest_data = auto_save_datastores[key][player.UserId].temp_data or datastore:GetDataAsync(player.UserId)
						if latest_data and latest_data.Session then
							if latest_data.Session.Active and not isInTheSameSession(latest_data.Session) then
								if table.find(datastore.__raw.operations.write, player.UserId) or not datastore.__raw.loaded_players[player] then
									auto_save_datastores[key][player.UserId].emergency_bypass = true
									auto_save_datastores[key][player.UserId].temp_data = 
										auto_save_datastores[key][player.UserId].temp_data or latest_data

									continue
								end

								auto_save_datastores[key][player.UserId].emergency_bypass = false
								auto_save_datastores[key][player.UserId].temp_data = nil

								datastore.__raw.kicked_players[player] = true
								player:Kick(SESSION_KICK_MESSAGE)
							end
						end
					end

					continue
				end

				local user_key = key..player.UserId
				if not active_threads[user_key] then
					active_threads[user_key] = {
						is_alive = true,
					}

					active_threads[user_key].thread = task.spawn(function()
						local burner_timeout = os.clock()
						if table.find(datastore.__raw.operations.write, player.UserId) then
							local max_burner_timeout = 1 * 60
							while true do
								if os.clock() - burner_timeout >= max_burner_timeout then
									break
								end
								RunService.Heartbeat:Wait()
							end
						end

						if not (player and player:IsDescendantOf(game)) then
							local latest_data = datastore:GetDataAsync(player.UserId)
							if latest_data.Session.Active and not isInTheSameSession(latest_data.Session) then
								datastore.__raw.kicked_players[player] = true
							end

							hb_request_calls += 1

							datastore:Save(player)
							hb_success_calls += 1
						end

						active_threads[user_key].is_alive = false
					end)
				end	
			end
		end
	end

	last_thread_running = false
end)

game:BindToClose(function()
	local total_requests_needed = 0
	local requests_made = 0

	for key, _ in Globals.RegisteredDataStores do
		local datastore = DataCacher.GetRegisteredDatastore(key, 1)
		if datastore then
			datastore.__raw.is_shutting_down = true

			for _, player in Players:GetPlayers() do
				total_requests_needed += 1
				coroutine.wrap(function()
					pcall(datastore.Save, datastore, player)
					requests_made += 1
				end)()
			end
		end
	end

	while true do
		if requests_made == total_requests_needed and hb_request_calls == hb_success_calls then
			break
		end
		RunService.Heartbeat:Wait()
	end
end)

return DataCacher