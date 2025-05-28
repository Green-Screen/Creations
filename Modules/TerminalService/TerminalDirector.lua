local RunContext = game:GetService("RunService"):IsServer()
local ET = require(script.Dependencies.EasyType)
local Types = require(script.Types)

-- For type Annotating Station is the default type
-- Server and Client get created when :Activate() is called and are created based on RunContext NOT CHOSEN

export type Station = Types.Station
export type ServerEvent = Types.ServerEvent
export type ClientEvent = Types.ClientEvent

local Terminal : Types.TerminalService = {}

local Counter = 1

function Terminal.CreateStation(Direction:"Client" | "Server" | "Omni", Type : "Reliable" | "UnReliable" | "Function", IDName: string, SecurityProtocol:boolean ) : Types.Station
	assert(Direction == "Client" or Direction == "Server" or Direction == "Omni", "Argument 1 Attempt to pass Direction got other")
	assert(Type == "Reliable" or Type == "UnReliable" or Type == "Function" , "Argument 2 attempt to pass EventType got other")
	assert(typeof(IDName) == "string", "Argument 3 string expected got "..typeof(IDName) )
	
	local self = {} :: Types.ClientEvent | Types.ServerEvent
	
	self.Direction = Direction -- Where it is being sent to
	self.Type = Type
	self.IDName = IDName
	self.SecurityProtocol = if SecurityProtocol or SecurityProtocol == nil then true else false
	self.FunctionBindedID = Counter

	Counter += 1
	
	local ReturnedMeta = {}
	ReturnedMeta.__index = ReturnedMeta
	ReturnedMeta.ClassName = "Station"
	
	if RunContext then
		function ReturnedMeta:Activate() : (Types.ServerEvent)
			repeat task.wait() until script:GetAttribute("ServerLoading")
			return require(script.Operations.ServerTerminal).NewEvent(false, self)
		end
		
		return setmetatable(self, ReturnedMeta)
		
	else
		
		function ReturnedMeta:Activate() : (Types.ClientEvent, string?)
			repeat task.wait() until script:GetAttribute("ServerLoading") and script:GetAttribute("ClientLoading")
			return require(script.Operations.ClientTerminal).NewEvent(self)

		end

		return setmetatable(self, ReturnedMeta)
		
	end
	
end

if script:FindFirstAncestorOfClass("ServerScriptService") or script:FindFirstAncestorOfClass("ServerStorage") then 
	return error("[TerminalService]: TerminalService must be placed in a location accessible to both the Server and Client", 10) 
end

return Terminal
