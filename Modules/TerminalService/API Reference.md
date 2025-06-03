 														How to Use?

What is? - Terminal Service is a remote event wrapper that prioritizes security. "This module does 0 data compression"
Terminal Service offers many security features such as

- UUID codes generated per event and are different for every player.
- Hides remote events\functions from client when not in use "Prevents exploiters from listening"
- Remote function timeouts.
- Multi Threading.
- Low impact on performance.
- Ran Internally based on RunContext.
- Options for bi-Directional events.
- Logging for SCM events "Security Code Mismatch" that appear under the game "Custom Events" in the analytics tab
- Replication is automatic and done on its own
- Custom Event Types.
- Allows for multiple listners of a remote event "Not functions"
- Fully Type annotated with autofill.
- Built in rate limiter.
- Built in security against exploitation manipulation
	

 														How to setup?

TerminalService is a module built for all to begin using it you must create a "Stations" dictionary in a seperate module script and require the main Module "TerminalDirector"
The module itself must be placed in a service accessable to the server and client. "ReplicatedStorage for best affect"

Example,

```lua
local TerminalService:TerminalService = require(game:GetService("ReplicatedStorage").TerminalDirector)

export type Station = TerminalService.Station
export type ServerEvent = TerminalService.ServerEvent
export type ClientEvent = TerminalService.ClientEvent

return {
	
	TestEvent = TerminalService.CreateStation("Omni", "Reliable", "Event")
	
} -- You can paste this into your "Station" module
```

First is the require of the main module TerminalDirector. "You will not need to require any sub modules"
Next is up to you. The type exports are purely optional and there is you want to add type autofill to your scripts

To use events you will create the index you would want to use, you then set it to ``` [TerminalService].CreateStation() -> Station```
See below for function descriptions v.

Above is a example on how to set up the module. You will only require the director in this module and to then on use the events you will require this new module script.


														--DO NOT FORGET to change the path directory above to fit yours!!!--
														

if you want autofill you must manually type annotate the event. "Roblox isnt smart enough to do this on its own :/ and im too lazy to learn TypeScript"
Events are created based on RunContext NOT DIRECTION

Ie: ServerEvent would be on ALL server scripts and vise versa

Once you have your dictionary script set up you will then require the Dictonary NOT THE DIRECTOR.
to then turn they events from a station type to either a ClientType or ServerType you must call the :Register() method -- Type is assigned by script RunContext NOT DIRECTION

If the securityProtocol paramater is true (deafult) then calling activate on a Client script may also return a String as the security Token. This token is needed for all transactions with that event.
As of now TerminalService will not replicate the code more then once you either must share the code or use multiple events when trying to send packet data.
BUT, TerminalService does allow you to activate multiple events which will allow multi listeners and will run functions accordingly.

-- Multi function binding --



														Documentation!!




TerminalDirector: - The main module used to create the basic Station Type

```lua 
CreateStation : (Direction: Receiver, Type: Type, IDName:string, SecurityProtocol:boolean?, RequestsPerMinute:number) -> Station

Direction = "Client, Server, Omni"
Type = "Reliable, UnReliable, Function
```

The direction Parameter is based on where the packet data IS GOING while Omni means Bi-Directional communications
The Type Parameter is based on the type of RemoteEvent to use Reliable - Normal, Unreliable - Unreliable, Function - Function
The ID-Name is a string parameter. This is used internally and can be set to whatever you want. \ ID names cannot the same /
The SecurityProtocol parameter determins if Security is used "Only affects Server/Omni directional events". Defaulted to true if false no code will be returned and you must put Nil in as the security token instead
The RequestPerMinute is needed for the RateLimiter. You input the maximum amount of requests/transactions allowed through the event EVERY MINUTE
This function will return a "Station" type which to activate you must call Register()



Station: - The basic type created from ```TerminalDirector.CreateStation()```

Properties-
--Direction - The direction of data transfer See above for more info ^
--Type - The event instance type see above for more info ^
--IDName - The UI of the event -Used internally-
--SecurityProtocol - A true or false value depending if to use the security methods built into the module. Deafult is True
-- RateLimit - A number representing the maximum amount of transactions allowed PER MINUTE

Methods-

``` Register() -> (ServerEvent | ClientEvent, String?) ```
The Register Method will turn the Station type into either a (ClientEvent or ServerEvent) this is determined on script **RUNCONTEXT NOT DIRECTION**

If SecurityProtocol is true then when THE FIRST activate call that has a direction of either (Server or Omni) will return the Security ``Token:String``
If the event has already been activated and another activate call is created in a seperate script a warning will be pushed and the Security Token will be Nil. -- Note that this event will only be able to Listen to events and not Send without errors being raised

DO NOT RECOMEND
storeing Tokens in a table nor module script.
Leaving the tokens as single use varibles are the most secure and never Printing/Sharing them in code.


ServerEvent: The Event type created when a station is activated on a Server Script

Properties-

--Inharites: Station
--FunctionBindedID - A number that is a UI for the function the event is linked to. Will be nil if no function is binded.

Methods-

``` Connect(FN(plr:Player, ...:any?) -> ()) -- Connects a function to be ran when the event is triggered ```
The first Param is the Player who triggered.
RETURNS NIL - All script connections are handled internally

``` Disconnect() -- Disconnects a function from a event if one is present```
To know if a function is Binded Check the FunctionBindedID property.

``` DispatchToStation(Plr:Player, ...any?) -- Triggers a event Invoke to the player specifyed```
Same as FireClient
If a function is not binded a warning will be raised on the Client

``` DispatchToAllStations(...:any?) -- Triggers a event Invoke to all Players in the game```
Same as FireAllClients
If a function is not binded a warning will be raised on the Client

``` DispatchToStationGroup({Player}, ...any?) -- Triggers a event Invoke to all players in the table```
Opposite of DispatchToStationsExcluding
If a function is not binded a warning will be raised on the Client

``` DispatchToStationsExcluding({Player}, ...any?) -- Triggers a event Invoke to all players BUT the ones that are in the table```
Opposite of DispatchToStationGroup
If a function is not binded a warning will be raised on the Client


``` GetListenersAsync(CollectionTime:Number?, ReturnDuplicates:Boolean?) -> {ListenerLog} -- Triggers a call to all players and will force listeners to return a listeners Log ```
CollectionTimerepresents - the time it will yield collecting callback data default is 0.5 seconds
ReturnDuplicates - Determins if Duplicate Listeners of a event to be published in the log

GetListeners is a function that will invoke all players and recored their responses. This will return EVERY client listener if they have a function binded.
This is where return duplicates can simplify the table and compact it to 1 per player instead of Many.



ClientEvent: The Event type created when a station is activated on a ClientScript

Properties-

--Inharites: Station
--FunctionBindedID - A number that is a UI for the function the event is linked to. Will be nil if no function is binded.

Methods-

``` Connect(FN(plr:Player, ...:any?) -> ()) -- Connects a function to be ran when the event is triggered ```
The first Param is the Player who triggered.
RETURNS NIL - All script connections are handled internally

``` Disconnect() - Disconnects a function from a event if one is present ```
To know if a function is Binded Check the FunctionBindedID property.

``` DispatchToHub(SecurityToken:String, ...any?) -- Triggers a event Invoke to the Server ```
Same as FireServer
If a function is not binded a warning will be raised on the Server

The first parameter is the securityToken that was created when the event was Registered.
If the event is NOT USING the security of this module Use Nil to fill.
If the token is incorrect then a error will be raised on the server and if the settings are allowed
Either Logging or the player being kicked will result or both.

``` GetPing() -> Number ```
A call to the server and back that is timed internally and calculated to the resulting time that is taken or "Ping"
DOES NOT REQUIRE A SECURITY CODE while no data can be passed nor will a function be triggered



 														Function Types!

TerminalService provides support for all roblox Remote types Normal and Functions.
There are built in protections such as a timeout for remote functions
and whether or not function callbacks can yield

--_RemoteEvent/UnreliableEvent_
Remote Event are virtually untouched but one thing they allow are multiple connections
such as binding multiple functions to a event.

--_Remote Function_
Remote functions will return a tuple. ``DidExpire:Boolean, Result:any?``
DidExpire will mark if the function hit the timeout limit or a rate limit error. A warning/error will also be raised
while the value will be returned as nil and DidExpire as true

The CanRemoteFunctionsYield determins if a function has a yielding line to skip over. "A feature of coroutines"
This will force the function to finish but may return wrongful data. This in turns makes it so the function will NEVER yield, DidExpire will always return False even if the data is malformed
Remote functions do not allow for multi function binding. If this occurs the previously binded will be overwritten and a warning will be pushed




 														Final Notes!

If you encouter any internal errors that are not the fault of you or your code then message me with errors and screenshots.
Discord - green_screen

If you enjoy this module and want to see more check out the following game V
to see all my games or Take the teleporter to the module store where all past, present, and future modules will be published for all.

