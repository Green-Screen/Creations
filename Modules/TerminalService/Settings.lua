local Settings = {}

-- Path for Stations Table
Settings.StationsDirectory = game:GetService("ReplicatedStorage").DLL.Stations :: ModuleScript

-- RemoteFunction Time out time
Settings.TimeOut = 10 :: number

-- Determins if a remote function callback can yield. If this is left false and a function yields then the function will return a the value or nil depending on the yielding element
Settings.CanRemoteFunctionsYield = true :: boolean

-- Should the player be kicked if a code is mismatched
Settings.KickOnMisMatch = true :: boolean

-- Should Anaylitics service be active based on Security Code mismatches
Settings.UseLogger = true :: boolean





if game["Run Service"]:IsServer() then
	print("[TerminalService]: Active settings:", Settings)
	script.Name = "Settings"
end
return Settings :: typeof(Settings)
