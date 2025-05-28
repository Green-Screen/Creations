local RS = game:GetService("RunService")
assert(RS:IsClient(), "Terminal Client may only be ran on client")

local CATSER = require(script.Parent.Parent.Dependencies.CategoryService)
local Types = require(script.Parent.Parent.Types)

local Settings = require(script.Parent.Parent.Settings)

local EventConnections:CATSER.Category = CATSER.NewCategory("EventClientConnections")
local HostFolder = script.Parent.Parent:WaitForChild("EventFolder")

local Plr = game.Players.LocalPlayer

local ET:RemoteFunction

local FunctionBindedID = 1
local ActiveEvents:{Types.ClientEvent} = {}
local ResponseFunctions = {}

local function ConstructListenerLog(Station:Types.Station) : Types.ListenerLog
	return {
		["Player"] = Plr,
		["ResponseTick"] = os.clock(),
		["ScriptHosted"] = script.Name,
		["EventID"] = Station.IDName,
		
		
	} :: Types.ListenerLog
end

local function Ping(Event:RemoteEvent | UnreliableRemoteEvent | RemoteFunction)
	assert(Event:GetAttribute("Direction") ~= "Client", "[TerminalService]: Ping can only be relayed on Server/Omni Directionals")
	
	Event.Parent = script.Parent
	local StartTime = tick()
	local Ping = nil
	
	if Event:IsA("RemoteFunction") then
		Event:InvokeServer("Ping")
		Event.Parent = nil
		return math.ceil((tick() - StartTime) * 1000)
	else
		Event.OnClientEvent:Once(function()
			Ping = math.ceil((tick() - StartTime) * 1000)
		end)

		Event:FireServer("Ping")
		repeat task.wait() until Ping ~= nil
		
		Event.Parent = nil
		
		return Ping :: number
	end
end

-- Treats Remote events like functions
local function CustomREHandler(Event:RemoteFunction, Operation : "GetKey" | "Ping" | "GetTube", Station : Types.Station) : RemoteEvent | UnreliableRemoteEvent | RemoteFunction | any
	if Operation == "Ping" then
		return Ping(Event)
	else
		Event.Parent = script.Parent
		local RV = Event:InvokeServer(Operation, Station)
		Event.Parent = nil
		
		return RV
	end
	
end

local function HandleTimeOut(F:() -> any?, ...:any?) : (any?, boolean)
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

local function OnRecive(Event:Types.Station, ...:any)
	if ... == "Ping" then return end
	
	if ... == "GetListeners" then
		if Event.Type ~= "Function" then
			for FunctionID:number, v:() -> () in ResponseFunctions[Event.IDName] do
				local RE:Instance = CustomREHandler(ET, "GetTube", Event)
				RE.Parent = HostFolder
				RE:FireServer(Event.IDName.."_ListenerResponse", ConstructListenerLog(Event))
				RE.Parent = nil
			end
		else
			if next(ResponseFunctions[Event.IDName]) then
				return Event.IDName.."_ListenerResponse", ConstructListenerLog(Event)
			end
		end
		return
	end
	
	if not next(ResponseFunctions[Event.IDName]) then return warn("[TerminalService]: "..Event.IDName.." was dropped: No function is binded") end 
		
	if Event.Type == "Function" then
		local _, Func = next(ResponseFunctions[Event.IDName])
		if Settings.CanRemoteFunctionsYield then
			return HandleTimeOut(Func, ...)
		else
			return false, coroutine.wrap(Func, ...)(...)
		end
		
	else
		for _, Func:() -> () in ResponseFunctions[Event.IDName] do
			task.spawn(Func, ...)
		end
	end
	
end



local CTMETA : Types.ClientEvent = {}
CTMETA.__index = CTMETA
CTMETA.ClassName = "ClientEvent"

-- Connects a function to a event
function CTMETA:Connect(FN: () -> ())
	assert(type(FN) == "function", "Invalid Argument 1 Function expected got: "..typeof(FN))
	assert(self.Direction ~= "Server", "Invalid Request, Attempt to Bind function that will never be called: Direction Invalid")
	
	if #ResponseFunctions[self.IDName] ~= 0 and self.Type == "Function" then
		warn("[TerminalService]: Multiy return binded: You can only bind 1 function to a Remote function per event Overwriting")
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
function CTMETA:Disconnect()
	if self.FunctionBindedID then
		ResponseFunctions[self.IDName][self.FunctionBindedID] = nil
		
		self.FunctionBindedID = nil
	end
end

-- Same as fireServer
function CTMETA:DispatchToHub(SecurityCode:string, ...:any) : nil | any?
	if SecurityCode ~= nil and not self.SecurityProtocol then return error("[TerminalService]: Set Security Code to nil when not using Security Protocol for event "..self.IDName,10) end
	assert(self.Direction ~= "Client", "[TerminalService]: "..self.IDName.." Packet send was dropped: Direction is invalid for mode of transport")
	
	local Event:RemoteEvent | UnreliableRemoteEvent | RemoteFunction = self.Event
	Event.Parent = HostFolder
	if self.Type == "Function" then
		return Event:InvokeServer(SecurityCode, ...)
	else
		Event:FireServer(SecurityCode, ...)
	end
	
	Event.Parent = nil
end

-- Returns time in Milliseconds of time taken to send a recive blank packets
function CTMETA:GetPing() : number
	return Ping(self.Event)
end

local CT : Types.TerminalServiceClient = {}

-- Internal function DO NOT CALL
function CT.NewEvent(self:Types.Station) : (Types.ClientEvent, string?)
	repeat task.wait() until ET ~= nil
	local Event:RemoteEvent | RemoteFunction | UnreliableRemoteEvent = CustomREHandler(ET, "GetTube", self)
	assert(Event, "Attempt to index "..Event.Name.." in event folder, Returned nil")
	--if ResponseFunctions[self.IDName] then ResponseFunctions[self.IDName] = nil end
	CTMETA.Event = Event
	
	return setmetatable({
		["Type"] = self.Type,
		["Direction"] = self.Direction,
		["IDName"] = self.IDName,
		["SecurityProtocol"] = self.SecurityProtocol,
		--["FunctionBindedID"] = FunctionBindedID,
		
		
		}, CTMETA), if (self.Direction == "Server" or self.Direction == "Omni") and self.SecurityProtocol then CustomREHandler(ET, "GetKey", self) else nil
		
		--return error("Attempt to bind"..Event.Name.." in opposite direction")
end

-- DO NOT CALL used internally
function CT:SetHost()
	if script:GetAttribute("Hosted") and script.Name ~= "TerminalService_Client_Host" then return error("[TerminalService]: TerminalService is hosted internally DO NOT call this function", 10) end
	script:SetAttribute("Hosted", true)
	local EN:RemoteEvent = script.Parent:WaitForChild("Encryption_Tunnel", Settings.TimeOut)
	
	if not EN then
		Plr:Kick("[TerminalService]: T-SET Connection Error Please rejoin")
		return error("[TerminalService]: T-SET Connection Error",10)
	end
	
	warn("[TerminalService]: T-SET: Connected in", Ping(EN), "MS")
	EN.Parent = nil
	
	ET = EN
	
	for _,v:Types.Station in pairs(require(Settings.StationsDirectory)) do
		
		local Event:Instance = CustomREHandler(ET, "GetTube", v)
		if v.Direction == "Client" or v.Direction == "Omni" then
			if v.Type == "Function" then
				
				Event.OnClientInvoke = function(...) return OnRecive(v, ...) end
			else
				
				EventConnections:InsertToCategory({Event.OnClientEvent:Connect(function(...:any)
					OnRecive(v, ...)
				end)})
			end
			ResponseFunctions[v.IDName] = {}
		end
		
		
		Event.Parent = nil
	end
	
	return script.Parent.Parent:SetAttribute("ClientLoading", true)
end

return CT
