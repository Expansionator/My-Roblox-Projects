--!nocheck

--// DataCacher V2
--// @fattah412

--// Desc:
--// A datastore extension module that behaves similarly to a normal datastore.
--// This module is the successor to DataCacher V1.

--[[

-------------------------------

Features:

[ Data Caching ]
• Player data (also known as "Profile") is temporarily stored in the server’s memory.
• This enables fast read and write operations without repeatedly accessing the Datastore.

[ Session Locking ]
• Acts as a safeguard against data loss or corruption in multi-server environments.
• Ensures that only a single server can modify a player’s profile at any given time, maintaining data integrity and consistency.

[ Mock Datastore ]
• Uses a separate Datastore instance when running in studio.
• If API Services are enabled, the environment runs in STUDIO mode, using a distinct Datastore that doesn’t affect live data.
• Otherwise, the environment runs in SANDBOX mode, which simulates Datastore behavior without making real API calls.

[ Automatic Saving ]
• Implements a smart, rotation-based auto-saving system on RunService.Heartbeat. 
• This distributes the save load evenly across all active profiles, preventing large spikes in datastore requests every time a save operation runs.

[ Profile State Tracking ]
• Tracks the profile's current state. 
• These include: "Locked", "Available", "Saving", "Loading", "Auto-Saving"

[ Queue Management ]
• For methods such as LoadProfile and SaveProfile, each request is added to a queue specific to that profile.
• This ensures operations are processed sequentially and prevents race conditions, especially during quick joins/leaves or multiple concurrent requests.

[ Data Reconciliation ]
• Compares the player’s data to a predefined template. If any keys from the template are missing, they are automatically added with their default values.

[ Version Migration ]
• Provides full support for migrating data from the V1 DataCacher module format to the new V2 format, allowing for seamless and backward-compatible transitions.

-------------------------------

Functions:

DataCacher.CreateDatastore(Name: string, Settings: Config.Datastore?): DatastoreObject
• Creates a new datastore instance using the specified name and optional settings.

DataCacher.GetDatastore(Name: string, Timeout: number?, IgnoreSuffix: boolean?): DatastoreObject?
• Finds and retrieves a datastore that was previously created by CreateDatastore().

-------------------------------

Methods:

DatastoreObject:LoadProfile(Player: Player): Profile?
• Initializes the player's profile and loads their data into memory on the server. This method handles session locking.

DatastoreObject:GetProfile(Player: Player, Raw: boolean?): Profile? | RawProfile?
• Retrieves the player's profile if it is currently loaded in memory. The optional Raw parameter returns the full profile, including the metadata.

DatastoreObject:SaveProfile(Player: Player, AutoSave: boolean?, ValueCallback: ValueCallback?): boolean?
• Saves the player's profile to the datastore. It is used for final saves (when a player leaves) or for the rotation-based auto-save.

DatastoreObject:WipeProfile(Player: Player)
• Replaces the player's current profile data with the configured template data, effectively resetting their data.

DatastoreObject:DeleteProfile(Player: Player): boolean
• Saves the profile (to release the lock) and then calls RemoveAsync() to mark the profile for deletion from the Datastore.

DatastoreObject:GetProfileKey(Username: string?, UserId: number?): string
• Retrieves the unique key used for the player's profile based on the configured key function.

DatastoreObject:GetProfileState(ProfileKey: string): ProfileState?
• Retrieves the current state of a profile from the server's cache or by fetching it externally.

DatastoreObject:IsProfileLocked(ProfileKey: string): boolean?
• Returns true if the player's profile is currently being used.

DatastoreObject:OnProfileStateChanged(ProfileKey: string, StateCallback: StateCallback): Disconnect
• Listens for profile state changes on the server and runs a callback function when the state updates.

DatastoreObject:GetProfileAsync(ProfileKey: string): RawProfile?
• Returns a copy of the profile by fetching it externally (using GetAsync), or returns the in-memory copy if the server already owns the profile.

DatastoreObject:SaveProfileAsync(ProfileKey: string, Profile: RawProfile): boolean
• Saves a provided profile copy using SetAsync(), but will fail if the profile is currently locked by any server.

-------------------------------

Example Usage:


local Players = game:GetService("Players")
local DataCacher = require(Path.To.DataCacher)

local myTemplateData = {
	Coins = 0,
}

local Datastore = DataCacher.CreateDatastore(`MyDatastore`, {
	TemplateData = myTemplateData,
})

local function onPlayerAdded(player)
	local profile = Datastore:LoadProfile(player)

	if profile then
		print(`Data for {player.Name} is loaded.`, profile)
	end
end

local function onPlayerRemoving(player)
	local success = Datastore:SaveProfile(player)

	if success then
		print(`Data for {player.Name} is saved.`)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

while true do
	for _, player in Players:GetPlayers() do
		local profile = Datastore:GetProfile(player)

		if profile then
			profile.Coins += 5
			print(`{player.Name}'s coins has changed to {profile.Coins}.`)
		end
	end

	task.wait(5)
end

-------------------------------

--]]

--// Services

local MessagingService = game:GetService("MessagingService")
local DatastoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local DataCacher, Config = {}, require(script.Settings)
DataCacher.__index = DataCacher

--// Internal Settings
--// Note: Certain numerical values are expressed in seconds

local ONLY_ALLOW_SINGLE_MODULE = true --// Allows only one DataCacher module to run in the experience

local MAX_DELAY_ON_SERVER_SHUTDOWN = 8 --// If AutoRetry is true, this value defines the delay between consecutive retry attempts

local DELAY_BETWEEN_PROFILE_RECLAIM_ATTEMPT = 7.5 --// The delay when a server tries to reclaim the profile’s session on each attempt

--// The maximum number of full reclaim cycles the system will make before giving up
--// Each cycle counts as two attempts, so three cycles equal six attempts (twice the UpdateAsync() calls)
local MAX_FULL_CYCLES_ALLOWED = 3

local MAX_PROFILE_RECLAIM_REQUESTS = 5 --// The maximum number of requests stored in ReclaimRequests before older ones are removed

--// If AutoSave is true, this value is added after doubling AutoSaveInterval
--// It acts as an offset, allowing multiple autosaves and increasing the chance that LastUpdated is refreshed before assuming the profile's host server is unavailable
local SESSION_DEAD_THRESHOLD_OFFSET = 30

local DATA_KEY = "Data" --// For "__Data"
local SESSION_KEY = "Metadata" --// For "__Metadata"

local LAST_CHARACTER_SUFFIX = "DC" --// For IndexingName, the character	s appended to the key if there's a duplicate

local METADATA_TEMPLATE = { --// System variables associated with the player's profile

	--// The version of the profile of which when data is saved
	Version = 1, 

	--// The state, either "Locked" or "Available", which reflects on the profile's availability
	State = "Available",

	--// The time when the profile was created or last reformatted
	Created = nil,

	--// The time when the profile was last updated via UpdateAsync()
	LastUpdated = nil,

	Session = {

		--// The job ID of the server currently managing the profile
		JobId = nil,

		--// The place ID of the server currently managing the profile
		PlaceId = nil,

		--// The list of servers and associated information attempting to load the profile
		ReclaimRequests = {},

	},
}

--// Types

export type Profile = {}
export type RawProfile = { __Data: Profile, __Metadata: Metadata }
export type ProfileState = "Locked" | "Available" | "Saving" | "Loading" | "Auto-Saving"

export type ValueCallback = ( OldProfile: RawProfile, CurrentProfile: RawProfile ) -> RawProfile
export type StateCallback = ( State: ProfileState ) -> nil

export type Disconnect = { Disconnect: () -> nil }

export type DatastoreObject = typeof( setmetatable({} :: DatastoreObjectAttributes, {} :: { __index: DatastoreObjectMethods }) )
export type DatastoreObjectAttributes = { Settings: Config.Datastore, Datastore: DataStore }

export type DatastoreObjectMethods = {

	LoadProfile: ( self: DatastoreObject, Player: Player ) -> Profile?,
	GetProfile: ( self: DatastoreObject, Player: Player, Raw: boolean? ) -> Profile? | RawProfile?,
	SaveProfile: ( self: DatastoreObject, Player: Player, AutoSave: boolean?, ValueCallback: ValueCallback? ) -> boolean?,
	WipeProfile: ( self: DatastoreObject, Player: Player ) -> nil,
	DeleteProfile: ( self: DatastoreObject, Player: Player ) -> boolean,
	GetProfileKey: ( self: DatastoreObject, Username: string?, UserId: number? ) -> string,
	GetProfileState: ( self: DatastoreObject, ProfileKey: string ) -> ProfileState?,
	IsProfileLocked: ( self: DatastoreObject, ProfileKey: string ) -> boolean?,
	OnProfileStateChanged: ( self: DatastoreObject, ProfileKey: string, StateCallback: StateCallback ) -> Disconnect,
	GetProfileAsync: ( self: DatastoreObject, ProfileKey: string ) -> RawProfile?,
	SaveProfileAsync: ( self: DatastoreObject, ProfileKey: string, Profile: RawProfile ) -> boolean,

}

export type Metadata = {

	Created: number,
	Version: number,
	LastUpdated: number,

	State: "Locked" | "Available",

	Session: {

		JobId: string,
		PlaceId: number,

		ReclaimRequests: { string },

	}

}

assert(RunService:IsServer(), 'Module is unable to be required from the client.')

--// Global Variables

local GlobalSettings = Config.Globals

local DatastoreEnabled = true
local MockDatastoreEnabled = false

local ProfilePointer = 0
local LastUpdate

local ActiveProfileRequests = 0

local StudioToken
local IsServerClosing = false

local gTable = {

	TaskResponses = {},
	Datastores = {},
	AutoUpdateList = {},

}

table.freeze(Config.Globals) --// Prevent any changes being made

local function SetTaskResponse(taskName)
	gTable.TaskResponses[taskName] = true
end

local function WaitForTaskResponse(taskName)

	--// Ensures the system is fully ready before accessing datastores
	while not gTable.TaskResponses[taskName] do
		task.wait()
	end
end

local function Clone(t)

	--// Enables thorough copying (deep copy)

	local newTable = {}

	for index, value in t do
		if typeof(value) == "table" then
			value = Clone(value)
		end
		newTable[index] = value
	end
	return newTable
end

local function GetTime()

	--// A replacement for os.time(), which is no longer recommended for upcoming developments
	return DateTime.now().UnixTimestamp
end

do

	--// Handles the creation of a mock datastore system
	--// There are two types of mock datastore systems:
	--//
	--// STUDIO:
	--// Used when API services are enabled
	--// Operates on a separate datastore instance, distinct from the one used by public servers
	--//
	--// SANDBOX:
	--// Used when API services are unavailable
	--// Simulates real datastore behavior locally
	--// Some features are unavailable in this mode

	if GlobalSettings.MockDatastore and RunService:IsStudio() then

		--// Creates a JobId for studio sessions
		StudioToken = HttpService:GenerateGUID(false)

		task.defer(function()
			local success = pcall(function()
				DatastoreService:GetDataStore(GlobalSettings.BurnerDataStore):SetAsync(GlobalSettings.BurnerDataStore, GetTime())
			end)

			DatastoreEnabled = false
			MockDatastoreEnabled = if GlobalSettings.SandboxMode then false else success --// Decides which type of mock datastore should be used

			SetTaskResponse("MockDatastoreInit")
		end)
	else
		SetTaskResponse("MockDatastoreInit")
	end
end

do

	--// Checks for other DataCacher modules
	--// Although DataCacher supports multiple modules, a single module is recommended

	if ONLY_ALLOW_SINGLE_MODULE then

		assert(not _G.__IsDataCacherLoaded, "_G.__IsDataCacherLoaded already has a reference to an identical module.")
		_G.__IsDataCacherLoaded = true
	end
end

local Wrapper = {}
do

	--// Wraps the primary function, allowing additional functions to run alongside it

	Wrapper.__index = Wrapper

	function Wrapper.Create(Callback: () -> nil)
		return setmetatable({

			Primary = Callback,

		}, Wrapper)
	end

	function Wrapper:Execute(Callbacks: {() -> nil}?, ...: any?)
		self.Primary(...)

		for _, callback in (Callbacks or {}) do
			callback(...)
		end
	end
end

local MockDatastore = {}
do

	--// Creates the SANDBOX mock datastore system
	--// Does not handle the STUDIO system

	MockDatastore.__Datastores = {}
	MockDatastore.__index = MockDatastore

	function MockDatastore.New(Name: string)
		assert(not MockDatastore.__Datastores[Name], `There's already an existing mock datastore called {Name}.`)

		local mock = setmetatable({ 

			Container = {},
			Queue = {},
			IsQueueRunning = {},

		}, MockDatastore)

		MockDatastore.__Datastores[Name] = mock
		return mock
	end

	function MockDatastore:Get(Key: string): (boolean, {}?)
		task.wait( math.random() ) --// Simulate API call delay

		local container = self.Container
		if not container[Key] then

			container[Key] = {

				Data = nil,
				Previous = nil,

			}
		end
		return true, container[Key].Data
	end

	function MockDatastore:Update(Key: string, Transform: (Data: {}) -> {}): {}?
		local gContainer = self.Container
		local gQueue = self.Queue

		local function Fn()
			local container = gContainer[Key]
			if not container then
				gContainer[Key] = { Data = nil, Previous = nil }
				container = gContainer[Key]
			end

			--// Updates the current data
			local currentData = container.Data and Clone(container.Data)
			local newData = Transform(currentData)

			if not newData then

				--// Transform function did not return anything
				return
			end

			container.Previous = currentData
			container.Data = newData

			task.wait( math.random() ) --// Simulate API call delay
		end

		if not gQueue[Key] then
			gQueue[Key] = {}
		end
		table.insert(gQueue[Key], Fn)

		local keyQueue = gQueue[Key]
		if #keyQueue == 1 then

			--// Handles the queue system

			local function RunNext()
				local nextFn = keyQueue[1]
				if nextFn then
					nextFn()
					table.remove(keyQueue, 1)

					if #keyQueue > 0 then
						RunNext() --// Proceed to the next queue
					else
						gQueue[Key] = nil --// Clears the queue automatically
					end
				end
			end
			RunNext()

		end
		return gContainer[Key].Data
	end

	function MockDatastore:Clear(Key: string)
		self.Container[Key] = nil
		self.Queue[Key] = nil
	end
end

local function Reconcile(t, refTable)

	--// Enables thorough reconciliation (deep)

	for key, value in refTable do
		if typeof(key) ~= "string" then continue end

		if t[key] == nil then
			t[key] = typeof(value) == "table" and Clone(value) or value
		end

		if typeof(t[key]) == "table" and typeof(value) == "table" then
			Reconcile(t[key], value)
		end
	end
end

local function IsTableArray(t)
	local n = 0

	for index in t do
		if typeof(index) ~= "number" or index < 1 or index % 1 ~= 0 then
			return false
		end
		n += 1
	end
	return n == #t
end

local function IsTableMixed(t)
	local hasArrayKeys = false
	local hasDictKeys = false

	local n = 0

	for index in t do
		if typeof(index) == "number" and index >= 1 and index % 1 == 0 then
			hasArrayKeys = true
			n += 1

			continue
		end
		hasDictKeys = true
	end

	if (hasArrayKeys and not hasDictKeys and n == #t) or (hasDictKeys and not hasArrayKeys) then
		return false
	end
	return true
end

local function Count(t)
	local index = 0

	for _, _ in t do
		index += 1
	end
	return index
end

local function IsV1Format(data)

	--// DataCacher V1 support

	local doesContainStructure = true
	local oldStructure = {

		--// V1 profile structure

		LastJoined = -1,
		LastLeft = -1,
		Version = -1,

		Session = {},
		data = {},

	}

	for index, value in oldStructure do
		if not data[index] or typeof(data[index]) ~= typeof(value) then

			doesContainStructure = false
			break
		end
	end

	--// The structure must be identical, with the same number of values
	if doesContainStructure and Count(oldStructure) == Count(data) then
		return true
	end
	return false
end

local function AddProfileToAutoList(profileKey, datastoreName)

	--// Checks if there's already an identical profile
	for _, profileInfo in gTable.AutoUpdateList do
		if profileInfo.ProfileKey == profileKey and profileInfo.DatastoreName == datastoreName then

			--// Found an identical profile
			return
		end
	end

	if #gTable.AutoUpdateList == 0 then

		--// Logs the current time for the first profile
		LastUpdate = os.clock()
	end

	table.insert(gTable.AutoUpdateList, {

		--// Essential for tracking newly created profiles
		LastCreated = os.clock(),

		ProfileKey = profileKey,
		DatastoreName = datastoreName,

	})

	--// Align the pointer to accommodate for the new profile
	ProfilePointer += 1
end

local function RemoveProfileFromAutoList(profileKey, datastoreName)

	--// Checks if there's already an identical profile
	for index, profileInfo in gTable.AutoUpdateList do
		if profileInfo.ProfileKey == profileKey and profileInfo.DatastoreName == datastoreName then

			--// Removes the profile from the list
			table.remove(gTable.AutoUpdateList, index)

			--// Align the pointer to adjust with the current profiles
			ProfilePointer -= 1

			if #gTable.AutoUpdateList == 0 then

				--// Reset the timer to allow a new profile to record its time again
				LastUpdate = nil
			else
				if ProfilePointer <= 0 then

					--// Resets the pointer to 1 if it’s misaligned while profiles exist
					ProfilePointer = 1
				end
			end
			break
		end
	end
end

local function GetMetadata()
	local metadata = Clone(METADATA_TEMPLATE)
	return metadata
end

local function GetJobId()
	return StudioToken or game.JobId
end

local function IsSessionReadyForUse(jobId, placeId, isOwnershipRequired)

	--// A critical function for session locking and validation

	if jobId == GetJobId() and placeId == game.PlaceId then

		--// Session is owned by this server
		return true
	end

	if not isOwnershipRequired and (not jobId and not placeId) then

		--// Session is empty and is ready to be locked
		return true
	end

	--// Session is owned by a different server
	return false
end

--[[
Creates a datastore using the specified name.
Includes methods and settings associated with the datastore.
]]
function DataCacher.CreateDatastore(Name: string, Settings: Config.Datastore?)
	WaitForTaskResponse("MockDatastoreInit")

	if not DatastoreEnabled then

		--// Append the mock datastore name suffix
		Name = Name..GlobalSettings.MockDatastoreSuffix
	end

	local newSettings = Clone(Settings or {})
	Reconcile(newSettings, Config.Datastore)

	table.freeze(newSettings) --// Prevent any changes being made

	assert(typeof(Name) == "string", `The datastore name must be a string.`)
	assert(not gTable.Datastores[Name], `There's already an existing datastore with the same name ({Name}).`)
	assert(not IsTableMixed(newSettings.TemplateData), `The TemplateData table for {Name} contains both arrays and dictionaries.`)

	local container = setmetatable({

		__Internal = {

			Name = Name,
			Settings = newSettings,

			--// The cached profiles stored in this table
			PlayerData = {},

			--// Metadata that is used for the server for each player
			--// Predefined in the server table for ease of accessibility

			PlayerUserIds = {},
			ProfileLoaded = {},
			SkipNewerSaveRequests = {},
			DeletionRequests = {},
			PendingLoadRequests = {},
			Subscriptions = {},

			States = {},
			StateCallbacks = {},

			Queue = {

				UpdateAsync = {},
				Requests = {},

			},

			--//

			Datastore = (DatastoreEnabled or MockDatastoreEnabled) and 
				DatastoreService:GetDataStore(Name) or MockDatastore.New(Name),

		}

	}, DataCacher)

	local self = container.__Internal
	do

		self.RequestProfileSave = function(...)

			--// A simpler reference to the SaveProfile method
			container:SaveProfile(...)
		end

		self.IsProfileLoaded = function(profileKey)

			--// Returns a boolean indicating whether the profile has been fully loaded by LoadProfile

			if table.find(self.ProfileLoaded, profileKey) then
				return true
			end
			return false
		end

		self.IsLatestRequest = function(profileKey, actionType)

			--// Returns a boolean indicating whether the request (Load, Save, or Auto-save) is the most recent

			local totalQueueByType = self.GetTotalQueue(profileKey, actionType)
			if totalQueueByType and totalQueueByType > 1 then
				return false
			end
			return true
		end

		self.GetStructureKeys = function()

			--// __Data, __Metadata and __Studio
			return `{newSettings.InternalKeys}{DATA_KEY}`, `{newSettings.InternalKeys}{SESSION_KEY}`, (not DatastoreEnabled and newSettings.KeySuffix or "")
		end

		self.ClearProfileSubscriptions = function(profileKey)

			--// For MessagingService, deletes all active subscriptions

			local activeSubscriptions = self.Subscriptions
			local profileSubscriptions = activeSubscriptions[profileKey]

			if not profileSubscriptions then
				return
			end

			for _, subscription in profileSubscriptions do
				subscription:Disconnect()
			end
			activeSubscriptions[profileKey] = nil
		end

		self.WaitInQueue = function(key, queueType, actionType)

			--// A critical system that organizes and executes requests in sequential order

			local queueTable = self.Queue
			local requestTable = queueTable.Requests

			local isFirst = false
			local queue = queueTable[queueType][key]

			if not queue then
				queueTable[queueType][key] = {}

				isFirst = true
				queue = queueTable[queueType][key]
			end

			local profileCounterTable
			if actionType then

				--// Handles LoadProfile and SaveProfile counters
				--// Uses a separate table instead of the queue for faster performance

				if not requestTable[key] then
					requestTable[key] = {}
				end
				profileCounterTable = requestTable[key]

				if not profileCounterTable[actionType] then

					--// ProfileKey = { ActionType = 0 }
					profileCounterTable[actionType] = 0
				end

				--// This action is now recognised in the queue
				profileCounterTable[actionType] += 1
			end

			if not isFirst then

				--// Stores the current coroutine into the queue and halt execution until it is resumed

				table.insert(queue, coroutine.running())
				coroutine.yield()
			end

			return function()
				local co = table.remove(queue, 1)
				if co then
					if actionType then

						--// The previous request has finished
						profileCounterTable[actionType] -= 1
					end

					coroutine.resume(co) --// Resume the next queue
					return
				end

				--// Clear the queue and counter tables if there's no more queue left

				queueTable[queueType][key] = nil
				requestTable[key] = nil
			end
		end

		self.GetTotalQueue = function(profileKey, actionType)

			--// The total number of requests associated with a profile

			local profileCounterTable = self.Queue.Requests[profileKey]
			local totalQueue = profileCounterTable and profileCounterTable[actionType]

			return totalQueue
		end

		self.SetPlayerState = function(profileKey, state)

			--// Sets the profile to the specified state and executes any callbacks associated with it

			local function FireStateCallbacks()
				local currentState = self.States[profileKey]
				local iterable = currentState and self.StateCallbacks[profileKey]

				--// Use an empty table if the table or state is missing
				for _, callback in (iterable or {}) do

					--// Fires each callback that was assigned to this profile
					task.spawn(callback, currentState)
				end
			end

			self.States[profileKey] = state
			FireStateCallbacks()

			--// At the time of when this function is called, if the state is the same, update the state
			return function()

				if self.States[profileKey] == state then

					self.States[profileKey] = self.IsProfileLoaded(profileKey) and "Locked" or nil
					FireStateCallbacks()
				end
			end
		end

		self.WaitForPlayerState = function(profileKey, iterate)

			--// Waits until the profile is ready for use

			local currentState = self.States[profileKey]
			if not currentState or currentState == "Locked" then

				--// The profile is ready for use
				return true
			end

			if not iterate then

				--// Keep waiting until the profile is available

				repeat task.wait()
				until self.WaitForPlayerState(profileKey, true)
			end
		end

		self.Request = function(profileKey, params)

			--// The core handler that ensures all profile asynchronous requests are processed correctly

			local dataKey, sessionKey = self.GetStructureKeys()

			local profile = self.PlayerData[profileKey]
			local templateData = Clone(newSettings.TemplateData)

			local hasIgnoredAndSavedRequest = false
			local hasIgnoredRequest = false
			local ignoreSessionRequest = false
			local isLatestRequest = true

			local success, newData

			local totalAttempts = newSettings.AutoRetry and newSettings.RetryAttempts or 1
			local expBackoff, attempt = 1, 0

			while attempt < totalAttempts or IsServerClosing do

				--// Iterates once or the specified number of retry attempts
				--// Continues iterating indefinitely if the server is closing to maximize the chance of the request being successful

				attempt += 1

				if not isLatestRequest then

					--// While waiting for the next attempt, a duplicate request was added to the queue

					hasIgnoredRequest = true 
					break
				end

				if IsServerClosing and params.Action ~= "Saving" then

					--// Reject this request if this function is attempting to load or auto-save the profile during a server shutdown

					hasIgnoredRequest = true 
					break
				end

				if params.Action ~= "Loading" and not (profile and self.IsProfileLoaded(profileKey)) then

					--// An attempt to save or auto-save but the profile is not loaded

					hasIgnoredRequest = true
					break
				end

				if params.RestoreSession then

					--// The server should no longer access the profile and must immediately remove the player

					ignoreSessionRequest = true
					hasIgnoredRequest = true

					break
				end

				--// Request (Atomic)
				success, newData = pcall(function()

					local function Transform(data)
						local metadataTemplate = GetMetadata()
						local hasValueInData = true

						if typeof(data) ~= "table" then

							--// Creates a new table if the data is missing
							--// Converts the current value to a table and stores the original value inside

							data = data and { data } or templateData
							hasValueInData = data ~= nil
						end

						if not (data[dataKey] and data[sessionKey]) then

							--// Handles DataCacher v1.0 importation
							--// Imports older data for migration to the new format
							--// Ensures that the profile is consistent with the new format


							--// DataCacher v1.0 migration
							if GlobalSettings.PreviousVersionSupport and IsV1Format(data) then

								data = data.data
								hasValueInData = true
							end

							local oldData = Clone(data)

							local isTemplateArray = IsTableArray(templateData)
							local isDataArray = IsTableArray(oldData)

							--// Array handling
							if hasValueInData and isTemplateArray and not isDataArray then

								oldData = { oldData }
							end

							--// Dictionary handling
							if hasValueInData and not isTemplateArray then

								local indexName = newSettings.IndexingName
								local charactersToAdd = ""

								local function GenerateChars()
									local defaultLength = indexName:len()
									local maxLength = defaultLength

									for index in templateData do
										if typeof(index) ~= "string" then continue end

										local len = index:len()
										if index:match(indexName) and len > maxLength then
											maxLength = len
										end
									end

									local newSuffix = `{("_"):rep((maxLength - defaultLength) + 1)}{LAST_CHARACTER_SUFFIX}`
									return newSuffix
								end

								if templateData[indexName] then

									--// Find a new index that is not in the table
									charactersToAdd = GenerateChars()
								end

								if isDataArray then

									--// Wrap the table into a dictionary format if it is an array
									oldData = { [indexName..charactersToAdd] = oldData }
								end
							end

							data = {

								[dataKey] = oldData,
								[sessionKey] = metadataTemplate,

							}
						end

						if newSettings.Reconcile then

							--// May be slightly computationally expensive
							Reconcile(data[dataKey], templateData)
						end
						Reconcile(data[sessionKey], metadataTemplate)

						do

							local metadata = data[sessionKey]
							local session = metadata.Session

							local currentMetadata = profile and profile[sessionKey]

							do

								--// Manages conditions associated with session locking

								local sessionReady = IsSessionReadyForUse(session.JobId, session.PlaceId, params.Action ~= "Loading")
								local isReclaimsInList = params.Action == "Loading" and #session.ReclaimRequests > 0

								if not sessionReady or isReclaimsInList then

									--// The session must be empty to load the profile
									--// The session must be owned by this server to save or auto-save the profile
									--// The session must not have other servers attempting to load the profile

									if params.ManageSession then

										--// An attempt was made to load the profile, but it was met with a session conflict

										local hasConflictBeenHandled = params.ManageSession(data)
										if not hasConflictBeenHandled then

											--// The session could not be transferred to this server
											--// Save the session while continuing to retry reclaiming the profile

											hasIgnoredAndSavedRequest = true
											return data
										end
									else

										--// An attempt was made to save or auto-save the profile but the session is not owned by this server
										--// This can happen if API services are unavailable, inadvertently allowing other servers to reclaim the profile while the original server is still running

										local hasSessionReverted = params.RevertSession and params.RevertSession(data)
										if not hasSessionReverted then

											--// There's no fail-safe function for this edge case, so we fall back to removing the player

											ignoreSessionRequest = true
											hasIgnoredRequest = true

											return
										end
									end
								end
							end

							if profile and currentMetadata.Version ~= metadata.Version then

								--// Both versions are not identical

								hasIgnoredRequest = true
								return
							end

							if params.RejectSave then

								--// Refresh LastUpdated without saving data

								metadata.LastUpdated = GetTime()
								return data
							end
						end

						if params.Transform then

							local metadata = data[sessionKey]
							if not metadata.Created then

								--// Logs the Unix timestamp at the time the profile is created
								metadata.Created = GetTime()
							end

							--// Finally, update the profile once all checks have passed or the session has been successfully reclaimed
							params.Transform(data)
						end
						return data
					end

					if DatastoreEnabled or MockDatastoreEnabled then
						return self.Datastore:UpdateAsync(profileKey, Transform)
					end
					return self.Datastore:Update(profileKey, Transform)
				end)

				local isRequestSuccessful = success and newData
				if isRequestSuccessful then

					--// The request was successful, so we can exit the loop safely
					break
				end

				if hasIgnoredRequest then

					--// The request specifies that no value should be returned
					break
				end

				--// Profile couldn't be updated, retry until an attempt succeeds or the max attempt limit is reached

				local jitter = expBackoff / 2
				local expDelay = Random.new():NextNumber(jitter, expBackoff)

				local offset = math.min(IsServerClosing and MAX_DELAY_ON_SERVER_SHUTDOWN or math.huge, expDelay)

				local startTime = os.clock()
				local endTime = startTime + offset

				while os.clock() < endTime do

					--// A replacement for task.wait, with logic implemented

					if not self.IsLatestRequest(profileKey, params.Action) then

						--// This request isn't the most latest request

						isLatestRequest = false
						break
					end

					if IsServerClosing and offset > MAX_DELAY_ON_SERVER_SHUTDOWN then

						--// Server is shutting down while waiting for end time to complete (e.g., 32 seconds)
						--// Adjusts the end time to cap at 8 seconds, continuing from the current time until the limit is reached
						--// Reset the offset to prevent this if-statement from running again

						endTime = startTime + MAX_DELAY_ON_SERVER_SHUTDOWN
						offset = MAX_DELAY_ON_SERVER_SHUTDOWN
					end

					task.wait()
				end

				--// Exponentially increases the delay per attempt
				expBackoff *= 2
			end

			if hasIgnoredRequest then

				--// The system was forced not to save
				return nil, ignoreSessionRequest
			end
			return success and newData, success and hasIgnoredAndSavedRequest
		end
	end

	gTable.Datastores[Name] = container
	return container
end

--[[
Finds and retrieves a datastore that was created by CreateDatastore().
Settings are read-only and can't be modified.
]]
function DataCacher.GetDatastore(Name: string, Timeout: number?, IgnoreSuffix: boolean?): DatastoreObject?
	WaitForTaskResponse("MockDatastoreInit")

	if not IgnoreSuffix and not DatastoreEnabled then

		--// Append the mock datastore name suffix
		Name = Name..GlobalSettings.MockDatastoreSuffix
	end

	if not gTable.Datastores[Name] then
		local elapsedTime = os.clock()
		Timeout = Timeout or math.huge

		repeat task.wait() --// Waits until there's a matching datastore, the time running out or when the server is closing
		until gTable.Datastores[Name] or (os.clock() - elapsedTime) >= Timeout or IsServerClosing
	end

	--// This could return a datastore that might not exist
	return gTable.Datastores[Name]
end

--[[
Initializes the player's profile and stores their data in memory.
This method fails if the profile is already loaded or in a saving state.
]]
function DataCacher:LoadProfile(Player: Player): Profile?
	local self = self.__Internal
	local Settings = self.Settings

	local profileKey = Settings.Key(Player.Name, Player.UserId)
	local dataKey, sessionKey, topicKey = self.GetStructureKeys()

	local ignoreSessionRequest = false
	local jobId = GetJobId()

	local actionType = "Loading"

	ActiveProfileRequests += 1

	local nextQueue = self.WaitInQueue(profileKey, "UpdateAsync", actionType) --// Helps with rejoining too quickly	
	local wrapper = Wrapper.Create(function(isReadyToDisconnect)

		--// Decrements total requests and runs the next queue

		if isReadyToDisconnect then

			--// The subscription for the profile is created before calling Request()
			--// If the process cannot complete, the subscription must be unsubscribed to prevent memory leaks
			--// For example, the server explicitly requests profile removal or the profile cannot be loaded

			self.ClearProfileSubscriptions(profileKey)
		end

		if ignoreSessionRequest then

			--// The server has requested the player’s removal due to session locking
			Player:Kick(Settings.ProfileLockText)
		end

		ActiveProfileRequests -= 1
		nextQueue()
	end)

	do
		self.WaitForPlayerState(profileKey)

		if not self.IsLatestRequest(profileKey, actionType) then

			--// This request isn't the most latest request
			return wrapper:Execute()
		end

		if IsServerClosing or self.IsProfileLoaded(profileKey) then

			--// Ignores this request if there's already a profile or during server shutdown
			return wrapper:Execute()
		end

		if table.find(self.DeletionRequests, profileKey) then

			--// There's an attempt to delete the profile, reject this request
			return wrapper:Execute()
		end
	end

	local makeProfileReady = self.SetPlayerState(profileKey, "Loading")
	local profile, isAttemptingToReclaim
	do

		--// Handles profile loading and session locking

		local pendingListTable = self.PendingLoadRequests
		local isLatestRequest = true

		if not table.find(pendingListTable, profileKey) then
			table.insert(pendingListTable, profileKey)
		end

		local function HandleProfileSubscription()

			--// task.spawn runs this function asynchronously so it doesn’t block the current thread

			if not DatastoreEnabled and not MockDatastoreEnabled then

				--// Currently in SANDBOX mode, blocking subscription creation
				return
			end

			local activeSubscriptions = self.Subscriptions
			local profileSubscriptions

			if not activeSubscriptions[profileKey] then

				--// Uses a table to track multiple subscriptions and handle duplicates caused by SubscribeAsync’s unpredictable behavior
				activeSubscriptions[profileKey] = {}
			end
			profileSubscriptions = activeSubscriptions[profileKey]

			if #profileSubscriptions > 0 then

				--// We should avoid creating a new subscription when an active one is already running
				return
			end

			table.insert(profileSubscriptions, MessagingService:SubscribeAsync(profileKey..topicKey, function(message)

				--// This is the other session, currently attempting to remove the player from this server so the original server retains profile ownership
				--// Used only in very specific fallback scenarios, since API services are usually active

				local session = message and message.Data and message.Data.Session
				if session and not IsSessionReadyForUse(session.JobId, session.PlaceId, true) then

					--// Ensures the original server does not handle messages it originally published
					--// Reject saving the profile and immediately remove the player to prevent any remaining references

					self.RequestProfileSave({Key = profileKey, RestoreSession = true})
				end
			end))

			if #profileSubscriptions > 1 then

				--// Because SubscribeAsync yields, another subscription may be created before it finishes, causing duplicate subscriptions
				--// Previously, the change wasn’t noticeable due to timing conflicts, so a table is used to track and handle duplicate subscriptions to prevent memory leaks
				--// Remove duplicate subscriptions, keeping only the original

				for index = #profileSubscriptions, 2, -1 do

					--// Loop backwards when removing subscriptions to prevent skipping any due to index shifts
					--// Disconnect the subscription and remove it from the list

					profileSubscriptions[index]:Disconnect()
					table.remove(profileSubscriptions, index)
				end
			end
		end
		task.spawn(HandleProfileSubscription)

		local maxProfileReclaimAttempts = MAX_FULL_CYCLES_ALLOWED * 2
		local totalAttempts, isServerInQueue = 0, false
		local lastJobId, lastSessionJobId

		while isLatestRequest and not IsServerClosing and table.find(pendingListTable, profileKey) and totalAttempts < maxProfileReclaimAttempts do

			--// Ensure that this is the most recent request, the server is active, this request is still permitted to run, and retry attempts remain within the allowed limit

			profile, isAttemptingToReclaim = self.Request(profileKey, {

				Action = actionType,

				ManageSession = function(latestData)

					--// Attempt to reclaim the profile

					local metadata = latestData[sessionKey]
					local session = metadata.Session

					local reclaimRequests = session.ReclaimRequests

					local function IsServerTheLatest(serverJobId)
						local totalServersInQueue = #reclaimRequests
						local latestJobId = reclaimRequests[totalServersInQueue]

						if serverJobId == latestJobId or totalServersInQueue == 1 then

							--// The latest server in the queue either matches the provided JobId or is the last in the queue
							return true
						end

						--// The server isn’t the newest in the queue
						return false
					end

					if not table.find(reclaimRequests, jobId) then

						--// The server is missing from the queue

						if isServerInQueue then

							--// Another server has forcibly removed this server from the queue
							--// Reduces UpdateAsync calls to avoid overwhelming the Datastore

							ignoreSessionRequest = true
							return false
						else

							--// The server has just started requesting to reclaim the profile

							isServerInQueue = true
							table.insert(reclaimRequests, jobId)
						end
					end

					local totalServersInQueue = #reclaimRequests
					if totalServersInQueue > MAX_PROFILE_RECLAIM_REQUESTS then

						--// More servers are attempting to reclaim the profile than the allowed limit
						--// Shift the excess queue from the right side to the left side to remove outdated servers

						local totalOutdatedServers = totalServersInQueue - MAX_PROFILE_RECLAIM_REQUESTS
						for _ = 1, totalOutdatedServers do
							table.remove(reclaimRequests, 1)
						end
						totalServersInQueue = #reclaimRequests
					end

					local lastUpdated = metadata.LastUpdated
					local currentJobId = session.JobId

					local expiryTime = GlobalSettings.AutoSave and ((GlobalSettings.AutoSaveInterval * 2) + SESSION_DEAD_THRESHOLD_OFFSET) or GlobalSettings.SessionDeadThreshold
					local lockExpiryDiff = lastUpdated and GetTime() - lastUpdated

					if IsServerTheLatest(jobId) and (IsSessionReadyForUse(currentJobId, session.PlaceId) or (lockExpiryDiff and lockExpiryDiff >= expiryTime)) then

						--// The server is the latest one, and the session is either unlocked or its lock has expired
						return true
					else
						if not lastSessionJobId then

							--// Stores the JobId of the server that currently owns the profile to determine if ownership has changed
							lastSessionJobId = currentJobId
						end
					end

					if (lastSessionJobId and currentJobId) and lastSessionJobId ~= currentJobId then

						--// After a server reclaims the profile, the queue should be cleared
						--// In rare cases, if this server misses the change, it will stop and remove the player

						ignoreSessionRequest = true
						return false
					end

					if totalServersInQueue > 1 then

						--// There's a race between servers trying to reclaim the profile
						--// Each server removes the current latest server in the queue. If other servers are inactive, the server continues attempting to reclaim the profile
						--// Removing the current latest server after some time allows other servers to reclaim the profile and helps reduce the queue


						--// After self.Request succeeds, totalAttempts is incremented by one
						--// Adding +1 makes the first attempt part of the first cycle (changing 0 % 2 == 0 to 1 % 2 == 1)
						local hasCompletedFullCycle = (totalAttempts + 1) % 2 == 0
						local latestJobId = reclaimRequests[totalServersInQueue]

						if hasCompletedFullCycle then

							--// Each cycle completes after two attempts (including this attempt)
							--// Verifies whether each server in the queue is still active

							if lastJobId == latestJobId and not IsServerTheLatest(jobId) then

								--// Ensure that only the same server captured in the previous attempt is removed (for cases where the server is removed by another server)
								--// Do not remove this server if it’s the latest and let other servers handle it

								table.remove(reclaimRequests, totalServersInQueue) --// Allow other servers to attempt reclaiming the profile
							end
						else

							--// Sets lastJobId to the most latest server in the queue for the next attempt, ensuring sufficient time before removing the server from the queue
							--// This gives the latest server a chance to reclaim the profile twice before being removed by other servers

							lastJobId = latestJobId
						end
					end

					--// Session has not been reclaimed by this server
					return false
				end,

				Transform = function(latestData)
					local metadata = latestData[sessionKey]
					local session = metadata.Session

					--// Updates the metadata

					metadata.LastUpdated = GetTime()
					metadata.State = "Locked"

					session.JobId = jobId
					session.PlaceId = game.PlaceId

					--// To start fresh without any servers wanting to reclaim the profile
					table.clear(session.ReclaimRequests)
				end

			})

			if profile then

				--// The loop will continue if the profile couldn't be fetched

				totalAttempts += 1

				if not isAttemptingToReclaim then

					--// The profile was successfully fetched and claimed by this server
					--// Creates the subscription if it was not created previously

					task.spawn(HandleProfileSubscription)
					break
				end
			end

			--// Ensures the profile only returns if it is fetched successfully
			profile = nil

			if ignoreSessionRequest then

				--// The server cannot safely continue managing the profile because the session can no longer be reclaimed
				break
			end

			--// Ensures that the subscription is created (if it was not created previously) only while the loop is active, minimizing unnecessary cleanup
			task.spawn(HandleProfileSubscription)

			local endTime = os.clock() + DELAY_BETWEEN_PROFILE_RECLAIM_ATTEMPT
			while os.clock() < endTime do

				--// A replacement for task.wait, with logic implemented

				if IsServerClosing or not table.find(pendingListTable, profileKey) then

					--// The server is shutting down or the player has left the server (save method called)
					break
				end

				if not self.IsLatestRequest(profileKey, actionType) then

					--// A new request attempted to load the same profile while it was being reclaimed. Prioritize the latest request instead

					isLatestRequest = false
					break
				end

				task.wait()
			end
		end

		if totalAttempts >= maxProfileReclaimAttempts and not profile then

			--// Remove the player if the profile cannot be fetched after all retries to avoid leaving stale references on the server
			ignoreSessionRequest = true
		end

		local pendingListIndex = table.find(pendingListTable, profileKey)
		if pendingListIndex then

			table.remove(pendingListTable, pendingListIndex)
		end
	end

	if not profile then

		--// Removes the player state when profile cannot be fetched
		return wrapper:Execute({makeProfileReady}, true)
	end

	--// Create references to the player

	self.PlayerData[profileKey] = profile
	self.PlayerUserIds[profileKey] = Player.UserId

	table.insert(self.ProfileLoaded, profileKey)

	AddProfileToAutoList(profileKey, self.Name)

	wrapper:Execute({makeProfileReady})
	return profile[dataKey] --// Profile is ready!
end

--[[
Retrieves the player's profile if it is loaded.
If Raw is true, this method returns the raw profile format, including __Data and __Metadata.
]]
function DataCacher:GetProfile(Player: Player, Raw: boolean?): Profile? | RawProfile?
	local self = self.__Internal

	local profileKey = self.Settings.Key(Player.Name, Player.UserId)
	local dataKey = self.GetStructureKeys()

	do
		self.WaitForPlayerState(profileKey)

		if IsServerClosing or not self.IsProfileLoaded(profileKey) then

			--// The server is shutting down or there's no profile
			return
		end
	end

	local profile = self.PlayerData[profileKey]

	--// Returns the profile with either only the actual data or both actual data and metadata
	return Raw and profile or profile[dataKey]
end

--[[
Saves the player's profile to the datastore.

Set AutoSave to true to save data during the session.
ValueCallback is an optional callback function that returns a modified profile.
]]
function DataCacher:SaveProfile(Player: Player, AutoSave: boolean?, ValueCallback: ValueCallback?): boolean?
	local self = self.__Internal
	local Settings = self.Settings

	--// Supports provided metadata because of BindToClose, Heartbeat, and other internal operations
	--// For internal use only. Not intended for use by other scripts
	local profileSaveMetaData = typeof(Player) == "table" and Player

	local profileKey = profileSaveMetaData and profileSaveMetaData.Key or Settings.Key(Player.Name, Player.UserId)
	local dataKey, sessionKey, topicKey = self.GetStructureKeys()

	local isRestoringSession = profileSaveMetaData and profileSaveMetaData.RestoreSession

	local actionType = AutoSave and "Auto-Saving" or "Saving"

	ActiveProfileRequests += 1

	local pendingRequestIndex = table.find(self.PendingLoadRequests, profileKey)
	if pendingRequestIndex and not AutoSave then

		--// The profile currently has an active load/reclaim request. Stop the request and allow the save operation to begin
		table.remove(self.PendingLoadRequests, pendingRequestIndex)
	end

	local nextQueue = self.WaitInQueue(profileKey, "UpdateAsync", actionType)
	local wrapper = Wrapper.Create(function()

		--// Decrements total requests and runs the next queue

		local skipSaveRequestIndex = table.find(self.SkipNewerSaveRequests, profileKey)
		if skipSaveRequestIndex then

			table.remove(self.SkipNewerSaveRequests, skipSaveRequestIndex)
		end

		ActiveProfileRequests -= 1
		nextQueue()
	end)

	do
		self.WaitForPlayerState(profileKey)

		if not self.IsLatestRequest(profileKey, actionType) then

			--// This request isn't the most latest request
			return wrapper:Execute()
		end

		if (IsServerClosing and AutoSave) or not self.IsProfileLoaded(profileKey) then

			--// Ignores the request if there's no profile or the request is an auto-save during server shutdown
			return wrapper:Execute()
		end

		if table.find(self.DeletionRequests, profileKey) and AutoSave then

			--// Allow save requests only if the profile is being deleted
			return wrapper:Execute()
		end

		if table.find(self.SkipNewerSaveRequests, profileKey) then

			--// Prevents the request from proceeding when an existing request takes priority over incoming requests
			return wrapper:Execute()
		end
	end

	local releaseProfile = self.SetPlayerState(profileKey, AutoSave and "Auto-Saving" or "Saving")

	if isRestoringSession and not AutoSave then

		--// In rare cases, when the server requests the removal of a player due to session locking,
		--// newer incoming requests may overwrite this high-priority request if API services are unavailable
		--// To prevent disruption of the profile release process (clearing references without saving), incoming requests should be rejected

		table.insert(self.SkipNewerSaveRequests, profileKey)
	end

	local profile = self.PlayerData[profileKey]
	local newProfile, ignoreSessionRequest = self.Request(profileKey, {

		Action = actionType,

		RestoreSession = isRestoringSession,
		RejectSave = profileSaveMetaData and profileSaveMetaData.RejectSave,

		RevertSession = function(latestData)

			--// Another session reclaimed ownership without realizing the original server still owns the profile

			local currentMetadata = profile[sessionKey]

			local metadata = latestData[sessionKey]
			local session = metadata.Session

			local jobId = GetJobId()

			do

				--// Restore the modified session to the original session

				metadata.Version = currentMetadata.Version
				metadata.State = "Locked"

				session.JobId = jobId
				session.PlaceId = game.PlaceId
			end

			task.spawn(MessagingService.PublishAsync, MessagingService, profileKey..topicKey, {

				--// Quickly request the other session to remove the player from that server

				Session = {

					JobId = jobId,
					PlaceId = game.PlaceId,

				}
			})
			return true
		end,

		Transform = function(latestData)
			local metadata = latestData[sessionKey]
			local session = metadata.Session

			metadata.LastUpdated = GetTime()

			if ValueCallback then

				--// Handles the custom callback if provided

				ValueCallback(latestData, profile)
				return
			end

			--// Updates the player's data
			latestData[dataKey] = profile[dataKey]

			if not AutoSave then

				--// Updates the metadata

				metadata.Version += 1
				metadata.State = "Available"

				session.JobId = nil
				session.PlaceId = nil
			end
		end

	})

	if not AutoSave then

		--// Remove any references to the player as the player is leaving

		self.PlayerData[profileKey] = nil
		if not ignoreSessionRequest then

			--// Allow the other condition to delete it after removing the player
			self.PlayerUserIds[profileKey] = nil
		end

		table.remove(self.ProfileLoaded, table.find(self.ProfileLoaded, profileKey))

		self.ClearProfileSubscriptions(profileKey)
		RemoveProfileFromAutoList(profileKey, self.Name)
	end

	if ignoreSessionRequest then

		--// In rare cases, the server that previously owned the profile may have its ownership transferred to another server during an auto-save or save attempt
		--// Remove the player to ensure the server clears its reference to the profile, helping prevent data corruption or loss

		local playerUserId = self.PlayerUserIds[profileKey]
		local playerInServer = playerUserId and Players:GetPlayerByUserId(playerUserId)

		if playerInServer then

			--// Remove the player from the server
			playerInServer:Kick(Settings.ProfileLockText)
		end

		self.PlayerUserIds[profileKey] = nil
		return wrapper:Execute({releaseProfile})
	end

	if not newProfile then

		--// Removes the player state when profile cannot be fetched
		return wrapper:Execute({releaseProfile})
	end

	wrapper:Execute({releaseProfile})
	return true --// Profile is saved!
end

--[[
Replaces the player's profile data with the template.
It is recommended to kick the player after calling this method.
]]
function DataCacher:WipeProfile(Player: Player)
	local self = self.__Internal
	local Settings = self.Settings

	local profileKey = Settings.Key(Player.Name, Player.UserId)
	local dataKey = self.GetStructureKeys()

	do
		self.WaitForPlayerState(profileKey)

		if IsServerClosing or not self.IsProfileLoaded(profileKey) then

			--// The server is shutting down or there's no profile
			return
		end
	end

	local profile = self.PlayerData[profileKey]

	--// Replaces the profile data with the template while retaining its metadata
	profile[dataKey] = Clone(Settings.TemplateData)
end

--[[
Deletes the player's profile from the datastore.
Call this method once the profile has been loaded.
]]
function DataCacher:DeleteProfile(Player: Player): boolean
	local self = self.__Internal
	local Settings = self.Settings

	local deletionTable = self.DeletionRequests
	local profileKey = Settings.Key(Player.Name, Player.UserId)

	if IsServerClosing or table.find(deletionTable, profileKey) then

		--// This method was already called or the server is shutting down
		return false
	end

	table.insert(deletionTable, profileKey) --// Prevent all requests except save requests

	--// Saves the profile to remove any remaining references
	self.RequestProfileSave(Player)

	local wrapper = Wrapper.Create(function()
		local deletedKeyIndex = table.find(deletionTable, profileKey)
		if deletedKeyIndex then

			table.remove(deletionTable, deletedKeyIndex)
		end
	end)

	if self.IsProfileLoaded(profileKey) then

		--// The profile remains loaded even after a save attempt

		wrapper:Execute()
		return false
	end

	local success = pcall(function()

		--// Removes the profile from the datastore
		--// Note: RemoveAsync() marks the profile as deleted but does not erase it until after the 30 day period

		self.Datastore:RemoveAsync(profileKey)
	end)

	if success then

		--// Remove the player to prevent potential bugs and ensure stability
		Player:Kick(Settings.ProfileDeletionText)
	end

	wrapper:Execute()
	return success
end

--[[
Retrieves the player's profile key using their Username and/or UserId.
Only one argument might be required, depending on Settings.Key.
]]
function DataCacher:GetProfileKey(Username: string?, UserId: number?): string
	local self = self.__Internal
	return self.Settings.Key(Username, UserId)
end

--[[
Retrieves the current player's profile state from the server or externally if not found. 
Default states “Locked” and “Available” are returned from the server or externally.

Locked: The profile is currently in use and not controlled by other states.
Available: The profile is inactive and not owned by a server.
Saving: The profile is currently being saved.
Loading: The profile is currently being loaded.
Auto-Saving: The profile is currently being automatically saved.
]]
function DataCacher:GetProfileState(ProfileKey: string): ProfileState?
	local self = self.__Internal

	local _, sessionKey = self.GetStructureKeys()

	local state = self.States[ProfileKey]
	if not state and (DatastoreEnabled or MockDatastoreEnabled) then

		--// State missing, likely because the player isn't in the server
		--// Falls back to fetching the state externally

		local success, profile = pcall(function()
			return self.Datastore:GetAsync(ProfileKey)
		end)

		if not success or not profile then

			--// Skip state retrieval if the profile doesn't exist
			return
		end

		do

			--// Checks if the profile is a valid profile and that there is a legitimate state
			--// Does not prevent user tampering

			if typeof(profile) ~= "table" then
				return
			end

			local metadata = profile[sessionKey]
			if not metadata or typeof(metadata) ~= "table" then
				return
			end

			local unknownState = metadata.State
			if unknownState ~= "Locked" and unknownState ~= "Available" then
				return
			end
		end

		--// Finally, return the state that is either "Locked" or "Available"
		return profile[sessionKey]["State"]
	end

	--// The profile is loaded and has an active state
	return state
end

--[[
Returns true if the player's profile is currently being used by a server.
]]
function DataCacher:IsProfileLocked(ProfileKey: string): boolean?
	local state = self:GetProfileState(ProfileKey)
	if not state then

		--// No state was found
		return
	end
	return state ~= "Available"
end

--[[
Listens for profile state changes from the server.
Returns a table with a Disconnect() function to stop listening to the given callback.
]]
function DataCacher:OnProfileStateChanged(ProfileKey: string, StateCallback: StateCallback): Disconnect
	local self = self.__Internal

	local stateCallbacks = self.StateCallbacks
	local profileStates = stateCallbacks[ProfileKey]

	if not profileStates then

		--// Creates the table for future callbacks

		stateCallbacks[ProfileKey] = {}
		profileStates = stateCallbacks[ProfileKey]
	end

	table.insert(profileStates, StateCallback)

	local isDisconnected = false
	return {

		Disconnect = function()
			if isDisconnected then

				--// This function was already called
				return
			end
			isDisconnected = true

			for index, callback in profileStates do
				if callback == StateCallback then

					--// Removes the callback from the table
					table.remove(profileStates, index)
					break
				end
			end

			if #profileStates == 0 then

				--// Deletes the table as there are no callbacks left

				stateCallbacks[ProfileKey] = nil
				profileStates = nil
			end
		end,

	}
end

--[[
Returns a copy of the player's original profile by fetching it externally.
If the current server owns the profile, this method returns the original profile directly without external fetching.

This method might return an invalid profile format unless corrected at runtime.
]]
function DataCacher:GetProfileAsync(ProfileKey: string): RawProfile?
	local self = self.__Internal

	if self.IsProfileLoaded(ProfileKey) then

		--// Profile is already loaded on this server
		return self.PlayerData[ProfileKey]
	else
		if DatastoreEnabled or MockDatastoreEnabled then

			--// API services are enabled

			local success, profile = pcall(function()
				return self.Datastore:GetAsync(ProfileKey)
			end)
			return success and profile
		end
	end
end

--[[
Saves the provided profile using SetAsync() rather than UpdateAsync().
This method fails if the player's profile is already loaded on a server.
]]
function DataCacher:SaveProfileAsync(ProfileKey: string, Profile: RawProfile): boolean
	local state = self:GetProfileState(ProfileKey)
	if state ~= "Available" then

		--// The profile is either in use by a server or does not exist
		return false
	end

	local success = pcall(function()

		--// Saves the provided profile
		self.__Internal.Datastore:SetAsync(ProfileKey, Profile)
	end)
	return success
end

RunService.Heartbeat:Connect(function()

	do

		--// Auto-saving of profiles / Auto-refreshing of LastUpdated

		--// Based on the ProfileStore system, with added documentation and minor changes
		--// https://devforum.roblox.com/t/profilestore-save-your-player-data-easy-datastore-module/3190543

		local interval = GlobalSettings.AutoSave and GlobalSettings.AutoSaveInterval or GlobalSettings.SessionDeadThreshold / 2
		local autoUpdateList = gTable.AutoUpdateList

		local totalProfiles = #autoUpdateList

		if totalProfiles > 0 then

			--// Adjusts the delay dynamically based on the total number of profiles in the list
			local delayPerProfile = interval / totalProfiles
			local profile

			local now = os.clock()

			local function AdjustProfilePointer()
				ProfilePointer += 1 --// Move to the next profile
				if ProfilePointer > totalProfiles then

					--// Loops the pointer back to the first profile when it reaches the end of the list
					ProfilePointer = 1
				end
			end

			local function IsProfileReadyForUpdate()

				--// Returns true if the profile’s age exceeds half of Interval
				--// This system automatically saves profiles over time using a rotation-based approach
				--// It spreads saves evenly across all active profiles to avoid spikes in datastore requests
				--// After the first save, the system enforces full rotation timing automatically

				--// An example with two profiles and an interval of one minute:
				--[[
					
					T = Time
					Delay = 60 seconds / 2 profiles (30 seconds for each profile)
					
					Timeline:
					T = 0s (Profiles were just created)
					T = 30s (Profile #1 is saved)
					T = 60s (Profile #2 is saved)
					T = 90s (Profile #1 is saved, since the full one minute has passed)
					T = 120s (Profile #2 is saved, since the full one minute has passed)
					
				]]

				return (now - profile.LastCreated) >= (interval / 2)
			end

			--// Checks if sufficient time has passed before saving a profile
			--// Uses a while loop to catch up on timing when the frame runs slower than expected
			while (now - LastUpdate) > delayPerProfile do
				LastUpdate += delayPerProfile --// Uses delayPerProfile to keep the system on schedule and prevent timing drift

				for _ = 1, totalProfiles do

					--// Checks for every profile in the list
					--// Maximizes each save attempt to find a profile until one meets the age requirement

					profile = autoUpdateList[ProfilePointer]

					if IsProfileReadyForUpdate() then

						--// The current profile is eligible for saving
						break
					end

					--// Set the profile to nil and move to the next profile

					profile = nil
					AdjustProfilePointer()
				end

				if profile then

					--// Save the profile and move to the next profile

					local datastore = DataCacher.GetDatastore(profile.DatastoreName, nil, true)
					task.defer(datastore.SaveProfile, datastore, {

						Key = profile.ProfileKey,
						RejectSave = not GlobalSettings.AutoSave, --// For LastUpdated

					}, true)

					AdjustProfilePointer()
				end
			end
		end
	end
end)

game:BindToClose(function()

	--// Used for final edge cases such as when the server shuts down unexpectedly

	IsServerClosing = true
	WaitForTaskResponse("MockDatastoreInit")

	if DatastoreEnabled or MockDatastoreEnabled then
		local activeProfileSaveRequests = 0

		for _, datastore in gTable.Datastores do
			local self = datastore.__Internal

			--// Saves any remaining profiles
			for profileKey in self.PlayerData do
				activeProfileSaveRequests += 1

				task.spawn(function()

					self.RequestProfileSave({Key = profileKey})
					activeProfileSaveRequests -= 1
				end)
			end
		end

		--// Yields until all asynchronous operations are complete 
		while activeProfileSaveRequests > 0 or ActiveProfileRequests > 0 do
			task.wait()
		end
	else

		--// Since it's a mock datastore, there's no need to wait for operations to complete
		return
	end
end)

return DataCacher
