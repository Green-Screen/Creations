local RS = game:GetService("RunService")
assert(RS:IsServer(), "ServerTerminal Must run on Server")

local Types = require(script.Parent.Parent.Types)
local CATSER = require(script.Parent.Parent.Dependencies.CategoryService)
local SecurityModule = require(script.Secure)

local Settings = require(script.Parent.Parent.Settings)

local PS = game:GetService("Players")

local EventConnections :CATSER.Category = CATSER.NewCategory("EventServerConnections")

local LogEventsActive = {}

local FunctionBindedID = 1
local ResponseFunctions : {(any?) -> nil} = {
	["Ping"] = function(Plr, Event : string) if LogEventsActive[Event]:IsA("RemoteFunction") then return "Ping" else return LogEventsActive[Event]:FireClient(Plr, "Ping") end end,
}

local HostFolder = Instance.new("Folder", script.Parent.Parent)
HostFolder.Name = "EventFolder"

-- DidExpire:Boolean, Result:Any?
local function HandleTimeOut(F:() -> (), ...:any?) : (boolean, any?)
	
	local Result = nil
	local StartTime = tick()
	local TimeOutThread = task.spawn(function(...) Result = F(...) end, ...)
	
	
	while task.wait() do
		if Result ~= nil then
			task.cancel(TimeOutThread)
			return false, Result
		elseif tick() - StartTime > Settings.TimeOut then
			task.cancel(TimeOutThread)
			warn("[TerminalService]: Callback yield timeout reached Function returned Nil")
			return true, nil
		end
	end
end

local function SpawnEvent(Values:Types.Station) : RemoteEvent | UnreliableRemoteEvent | RemoteFunction
	local Event:RemoteEvent | UnreliableRemoteEvent | RemoteFunction = if Values.Type == "Reliable" then Instance.new("RemoteEvent") elseif Values.Type == "UnReliable" then Instance.new("UnreliableRemoteEvent") else Instance.new("RemoteFunction")

	Event.Parent = HostFolder
	Event.Name = Values.IDName
	Event:SetAttribute("Direction", Values.Direction)
	
	return Event
end

local function OnRecive(Plr:Player, Event:Types.Station, SecurityCode:string, ...:any)
	
	if SecurityCode ~= nil and SecurityCode:find("_ListenerResponse") then return end
	
	if SecurityCode == "Ping" then
		return task.spawn(ResponseFunctions["Ping"], Plr, Event.IDName)
	end
	
	if Event.SecurityProtocol then
		SecurityModule:CheckCode(Plr, Event.IDName, SecurityCode)
	end
	
	if not next(ResponseFunctions[Event.IDName]) then return warn("[TerminalService]: "..Event.IDName.." was dropped: No function is binded") end 
	
	if Event.Type == "Function" then
		local _, Func = next(ResponseFunctions[Event.IDName])
		if Settings.CanRemoteFunctionsYield then
			return HandleTimeOut(Func, Plr, ...)
		else
			return coroutine.wrap(Func)(Plr, ...), false
		end
		
	else
		for _, Func:() -> () in ResponseFunctions[Event.IDName] do
			task.spawn(Func, Plr, ...)
		end
	end
	
end

local function HandleSend(Event:Types.ServerEvent, IgnoreMode:boolean, Plrs: {Player?}, ...:any?)
	assert(Event.Direction ~= "Server", "[TerminalService]: "..Event.IDName.." Packet send was dropped: Direction is invalid for mode of transport")
	
	if IgnoreMode then
		if #Plrs == 0 then warn("IgnoreMode triggered but missing players to ignore, Sending to all") end
		local CurrentPlayers = PS:GetPlayers()
		
		for _, v in pairs(Plrs) do
			CurrentPlayers[v] = nil
		end
		
		for _, SendingPlayer in pairs(CurrentPlayers) do
			
			if Event.Type == "Function" then
				return Event.Event:InvokeClient(SendingPlayer, ...)
			else
				Event.Event:FireClient(SendingPlayer, ...)
			end
		end
		
	else
		assert(#Plrs ~= 0, "Invalid Target, Attempt to send to players Nil was given")

		for _, SendingPlayer in pairs(Plrs) do
			if Event.Type == "Function" then
				return Event.Event:InvokeClient(SendingPlayer, ...)
			else
				Event.Event:FireClient(SendingPlayer, ...)
			end
		end
	end
end

local function HandleEncyptionChannel()
	local EncryptionTube = Instance.new("RemoteFunction", script.Parent)
	EncryptionTube.Name = "Encryption_Tunnel"
	
	EncryptionTube.OnServerInvoke = function(plr:Player, Operation : "GetKey" | "Ping" | "GetTube", Station : Types.Station)
		
		if Operation == "Ping" then
			return
		elseif Operation == "GetKey" then
			if not Station.SecurityProtocol then return nil end
			
			if Station.Direction == "Server" or Station.Direction == "Omni" then
				return SecurityModule:GetCode(plr, Station.IDName, false, true)
			else
				return error("[TerminalService]: Invalid Request, No key Generated for Client Direction")
			end
		elseif Operation == "GetTube" then
			if not LogEventsActive[Station.IDName] then
				return plr:Kick("[TerminalService]: "..Station.IDName.. " event was not found")
			end
			return LogEventsActive[Station.IDName]
		end
		
		return nil
	end
	
end

-- True means Index
local function FindDuplicate(T:{any}, LookAt:boolean, Value:any) : boolean
	assert(type(T) == "table", "Invalid Argument 1 table expected got: ".. typeof(T))
	
	for I, v in pairs(T) do
		if LookAt then
			if I == Value then
				return true
			end
		else
			if v == Value then
				return true
			end
		end
		if type(v) == "table" then if FindDuplicate(v, LookAt, Value) then return true end end
	end
	return false
end


local STMETA = {}
STMETA.__index = STMETA
STMETA.ClassName = "ServerEvent"

-- Connects a function to a event
function STMETA:Connect(FN : () -> ())
	assert(type(FN) == "function", "Invalid Argument 1 Function expected got: "..typeof(FN))

	if #ResponseFunctions[self.IDName] ~= 0 and self.Type == "Function" then
		warn("[TerminalService]: Multiy return binded: You can only bind 1 function to a Remote function per event Overwriting", 100)
		ResponseFunctions[self.IDName][1] = FN

		self.FunctionBindedID = 1
		return
	end

	if not self.FunctionBindedID then
		ResponseFunctions[self.IDName][FunctionBindedID] = FN

		self.FunctionBindedID = FunctionBindedID
		FunctionBindedID += 1
	else
		warn("[TerminalService]: Multiy return binded: You can only bind 1 function to a event Overwriting", 100)
		ResponseFunctions[self.IDName][self.FunctionBindedID] = FN
	end
end

-- Disconnects a function from a event
function STMETA:Disconnect()
	if self.FunctionBindedID then
		ResponseFunctions[self.IDName][self.FunctionBindedID] = nil

		self.FunctionBindedID = nil
	end
end

-- Same as FireClient
function STMETA:DispatchToStation(plr:Player, ...:any?)
	
	if self.Type == "Function" then
		return HandleSend(self, false, {plr}, ...)
	else
		HandleSend(self, false, {plr}, ...)
	end
end

-- Same as FireAllClients
function STMETA:DispatchToAllStations(...:any?)
	assert(self.Type ~= "Function", "[TerminalService]: Remote functions cannot be sent in groups only single players")
	HandleSend(self, false, PS:GetPlayers(), ...)
end

-- Same as fireClient but given a table of players to send to
function STMETA:DispatchToStationGroup(PlayerGroup: {Players}, ...:any?)
	assert(self.Type ~= "Function", "[TerminalService]: Remote functions cannot be sent in groups only single players")
	HandleSend(self, false, PlayerGroup, ...)
end

-- Same as FireClient but the table given is who it will NOT be sent to
function STMETA:DispatchToAllStationsExcluding(PlayerGroup: {Players}, ...:any?)
	assert(self.Type ~= "Function", "[TerminalService]: Remote functions cannot be sent in groups only single players")
	HandleSend(self, true, PlayerGroup, ...)
end
-- CollectionTime default is 0.5, ReturnDuplicates default is true
function STMETA:GetListenersAsync(CollectionTime:number?, ReturnDuplicates:boolean?)
	assert(self.Direction ~= "Server", "[TerminalService]: Attempt to get Listeners of a inverse event: "..self.IDName)
	local self:Types.ServerEvent = self
	local Responses : {Types.ListenerLog} = {}
	
	local SendTick = os.clock()
	local CollectionThread:thread
	
	if self.Type == "Function" then
		CollectionThread = task.spawn(function()
			for _, v in PS:GetPlayers() do
				local EventID:string, ResponseLog:Types.ListenerLog = self:DispatchToStation(v, "GetListeners")
				if not EventID:find("_ListenerResponse") then continue end
				
				ResponseLog.ResponseTick = math.ceil((ResponseLog.ResponseTick - SendTick) * 1000)/1000
				
				table.insert(Responses, ResponseLog)
			end
			
		end)
	else
		CollectionThread = task.spawn(function() 
			self.Event.OnServerEvent:Connect(function(plr:Player, EventID:string, ResponseLog:Types.ListenerLog)
				if not EventID:find("_ListenerResponse") then return end
				ResponseLog.ResponseTick = math.ceil((ResponseLog.ResponseTick - SendTick) * 1000)/1000
				
				if ReturnDuplicates == true or ReturnDuplicates == nil then 
					table.insert(Responses, ResponseLog) 
				else
					
					if not FindDuplicate(Responses, false, plr) then
						table.insert(Responses, ResponseLog)
					end
				end
			end)
			
			self:DispatchToAllStations("GetListeners")
			
		end)
		
	end
	task.wait(CollectionTime or 0.5)
	task.cancel(CollectionThread)
	
	return Responses
end


local ST = {}

-- Internal function DO NOT CALL
function ST.NewEvent(CreateEvent:boolean, Values:Types.Station) : Types.ServerEvent
	local Event = LogEventsActive[Values.IDName] or nil
	if CreateEvent then
		Event = SpawnEvent(Values)
	end
	
	STMETA.Event = Event
	return setmetatable({
		
		["Type"] = Values.Type,
		["Direction"] = Values.Direction,
		["IDName"] = Values.IDName,
		["SecurityProtocol"] = Values.SecurityProtocol

	}, STMETA) :: Types.ServerEvent 
end

-- Internal Function DO NOT CALL
function ST:SetHost()
	if script:GetAttribute("Hosted") and script.Name ~= "TerminalService_Server_Host" then return error("[TerminalService]: TerminalService is hosted internally DO NOT call this function", 10) end
	script:SetAttribute("Hosted", true)
	
	local Stations : Types.Station = require(Settings.StationsDirectory)
	-- Run Server Setup
	-- Create Replicated Items
	
	
	for _, Values : Types.Station in pairs(Stations) do
		
		local Event : Types.ServerEvent = self.NewEvent(true, Values)
		
		LogEventsActive[Values.IDName] = Event.Event

		if (Event.Direction == "Server" or Event.Direction == "Omni") then
			
			if Event.Type == "Function" then
				
				Event.Event.OnServerInvoke = function(Plr, ...) return OnRecive(Plr, Event, ...) end
				
			else
				EventConnections:InsertToCategory({Event.Event.OnServerEvent:Connect(function(Plr, ...) 
					OnRecive(Plr, Event, ...)
				end)})
			end
			
		end
		ResponseFunctions[Event.IDName] = {}
		
	end
	
	PS.PlayerAdded:Connect(function(...) SecurityModule.JoinLogger(..., Stations) end)
	PS.PlayerRemoving:Connect(SecurityModule.LeaveLogger)
	
	HandleEncyptionChannel()
	
	return script.Parent.Parent:SetAttribute("ServerLoading", true)
end

return ST :: Types.TerminalServiceServer
