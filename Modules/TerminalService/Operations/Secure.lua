-- Child of ServerTerminal
local RS = game:GetService("RunService")
assert(RS:IsServer(), "Security module may only be loaded on sever")

local ATS = game:GetService("AnalyticsService")
local HTTPS = game:GetService("HttpService")

local Types = require(script.Parent.Parent.Parent.Types)
local Settings = require(script.Parent.Parent.Parent.Settings)

local LogCodes = {}

local function Logging()
	-- Use AnalyticsService to log code erros
end

local function GenerateCode()
	return HTTPS:GenerateGUID(false)
end

local function ConstructLog(self:Types.Station) :Types.SecurityLog
	local T:Types.SecurityLog
	
	return {
		["EventID"] = self.IDName,
		["IsRequired"] = false,
		["PlayerRequired"] = 0,
		["SecurityCode"] = GenerateCode()
	}
		
	
end

local Security = {}

function Security:GetCode(plr:Player, Event:string, GrabDuplicate:boolean, AddToLog:boolean)
	local Log:Types.SecurityLog = LogCodes[plr.UserId][Event]
	
	if Log.IsRequired and not GrabDuplicate then 
		
		return nil, warn(Log.EventID.." Has been activated more then once by "..Log.PlayerRequired.Name.. " code has not been replicated") 
	else 
		if not GrabDuplicate and AddToLog then
			self:LogEventActivated(plr, Event)
		end
		
		assert(AddToLog, "GrabDuplicate must be false to properly Add to log")
		return Log.SecurityCode
	end
end

function Security:CheckCode(plr:Player, Event:string, Code:string)
	if Event and Code and LogCodes[plr.UserId][Event].SecurityCode == Code then
		return true 
	else
		if Settings.UseLogger then
			ATS:LogCustomEvent(plr, "TerminalService_Security", 401, {
				[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = "SCM", -- Log Type "Security Code MisMatch"
				[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = Event, -- Event ID name
				[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = LogCodes[plr.UserId][Event].SecurityCode.." : "..tostring(Code), -- Security code Needed, Security code Given
			})
		end
		
		if Settings.KickOnMisMatch then
			plr:Kick("[TerminalService]: Security code mismatch: Logging")
		end
		return false, error("[TerminalService]: Security code mismatch: Logging",10)
	end
end

function Security:LogEventActivated(plr:Player, Event:string)
	local EventLog:Types.SecurityLog = LogCodes[plr.UserId][Event]
	
	if EventLog.IsRequired then return error(EventLog.EventID.." has been logged by "..EventLog.PlayerRequired) end
	
	EventLog.IsRequired = true
	EventLog.PlayerRequired = plr
	
	return EventLog
end

--Function is used Internally
function Security.JoinLogger(plr:Player, Station:{Types.Station})
	if LogCodes[plr.UserId] then return plr:Kick("[TerminalService]: Duplicate Profiles found please rejoin.") end
	
	LogCodes[plr.UserId] = {}
	
	for _, v :Types.Station in pairs(Station) do
		if v.Direction == "Client" then continue end
		
		LogCodes[plr.UserId][v.IDName] = ConstructLog(v)
		
	end
end

function Security.LeaveLogger(plr:Player)
	if LogCodes[plr.UserId] then LogCodes[plr.UserId] = nil end
end

-- Leaving nil will return complete log
function Security:GrabLog(plr:Player | nil)
	if plr then return LogCodes[plr.UserId] else return LogCodes end
end

return Security
