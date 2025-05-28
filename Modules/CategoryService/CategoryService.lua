export type Category = {
	Category:string,
	ClassFiller:string,
	TasksAssigned:{},
	
	InsertToCategory: (self:Category, TblOfThings:{}) -> Category,
	Concat: (self:Category, OtherCategory:Category) -> Category,
	Len: (self:Category) -> number,
	Seduce: (self:Category, Method:number | RBXScriptSignal | ()-> () | nil) -> (),
	
	Insertion:RBXScriptSignal,
}

--DEPENDENCIES - EasyType is a custom Type checker needed to allow the type checking abillity of custom types as it is built In to this module but is also a standalone.

--          https://create.roblox.com/store/asset/81865879533988/EasyType             --

--[[--------------------------------------------------------------------------------------------------------------------------------]]--

local EasyType = require(script.Parent.EasyType)
local ActiveCategories: {Category} = {}

-- Public
local CategoryCreatedEvent = Instance.new("BindableEvent")
local CategoryClosedEvent = Instance.new("BindableEvent")

-- Private

local CategoryInsertion = Instance.new("BindableEvent")

--[[--------------------------------------------------------------------------------------------------------------------------------]]--

local function FindCategory(Name:string, ReturnIndexInstead:number) : Category | number
	--assert(type(Name) == "string", "Name must be a string")
	for _, Categories:Category in pairs(ActiveCategories) do
		if Categories.Category == Name then
			if ReturnIndexInstead then return _ else return Categories end
		end
	end
	return false
end

local function ValidityChecks(Name:string, Tbl:{})
	if type(Name) ~= "string" then
		error("Name must be a string",0)
	end
	if type(Tbl) ~= "table" then
		error("Attempt to iterate over non table",0)
	end
	if not FindCategory(Name) then
		error("Attempt to index "..Name.. " in category list, Returned Nil",0)
	end
	if EasyType.Type(FindCategory(Name)) ~= "Category" then
		error("Attempt to index Name with Category, EasyType returned "..EasyType.Type(FindCategory(Name)),0)
	end
end

local function CheckValidType(T:{any}?) :{}
	local AllowedTypes = {
		["function"] = true,
		["Tween"] = true,
		["Instance"] = true,
		["thread"] = true,
		["RBXScriptConnection"] = true,
		
	}
	if type(T) == "string" then
		if not AllowedTypes[T] then
			error("Attempt to index as valid type "..T.. " Returned Nil",0)
		end
		return AllowedTypes[T] == true
	end
	
	local CurrentType = typeof(T[1])
	for _, v in pairs(T) do
		if typeof(v) ~= CurrentType  then
			error("Table Value must be congruent found "..typeof(v).." In mandated "..CurrentType.." table",0)
		end
		if not AllowedTypes[typeof(v)] then
			error("Type "..typeof(v).." Is not supported with CategoryService",0)
		end
	end
	return T
end

local function GetCategoriesOfTypeStated(Type:string) :{Category?}
	local TC = {}
	for _, v:Category in pairs(ActiveCategories) do
		if v.ClassFiller == Type then
			table.insert(TC, v)
		end
	end
	return TC, Type
end

local function DoClean(self:Category)
	--if self.ClassFiller == "Any" then return end
	for _, V in pairs(self.TasksAssigned) do
		if self.ClassFiller == "function" then
			V()
		elseif self.ClassFiller == "Tween" then
			V:Cancel()
		elseif self.ClassFiller == "Instance" then
			V:Destroy()
		elseif self.ClassFiller == "thread" then
			coroutine.close(V)
		elseif self.ClassFiller == "RBXScriptConnection" then
			V:Disconnect()
		end
	end
	return table.remove(ActiveCategories, FindCategory(self.Category, true)), CategoryClosedEvent:Fire()
end

--[[--------------------------------------------------------------------------------------------------------------------------------]]--

local CSMeta:Category = {}

CSMeta.__index = CSMeta
CSMeta.ClassName = "Category"

-- Table inserted my be full of the same type stated, To check use the ``ClassFilter`` property and if Any its undecided
function CSMeta:InsertToCategory(TblOfThings:{any}) : Category
	CheckValidType(TblOfThings)

	if #self.TasksAssigned == 0 then
		self.TasksAssigned = TblOfThings
		self.ClassFiller = if EasyType.Type(TblOfThings[1], true) == "Tween" then EasyType.Type(TblOfThings[1], true) else EasyType.Type(TblOfThings[1])
	else
		if self.ClassFiller == "Any" then
			self.ClassFiller = if EasyType.Type(TblOfThings[1], true) == "Tween" then EasyType.Type(TblOfThings[1], true) else EasyType.Type(TblOfThings[1])
		end

		if if EasyType.Type(TblOfThings[1], true) == "Tween" then EasyType.Type(TblOfThings[1], true) else EasyType.Type(TblOfThings[1]) == self.ClassFiller then
			for _, V:Category in pairs(TblOfThings) do
				table.insert(self.TasksAssigned, V)
			end
		else
			error("Attempt to concatinate table of type "..EasyType.Type(TblOfThings[1], true).." to a table of type "..self.ClassFiller,0)
		end
	end

	return self, CategoryInsertion:Fire(self)
end

function CSMeta:Concat(TableToConcat:Category) : Category
	local NewTbl = self:InsertToCategory(TableToConcat.TasksAssigned)
	table.remove(ActiveCategories, table.find(ActiveCategories, TableToConcat))
	return NewTbl, CategoryInsertion:Fire()
end

function CSMeta:Len() : number
	return #self.TasksAssigned
end

--[[

Cleans table

Number will set a delayed thread for clean after -Time in seconds
RBXScriptSignal, Give a event to trigger seduce,
Null will seduce on thread
if a function is passed default suduction will be bypassed and is up to whatever the function has. Can result in errors

If a function is passed then expect the first param to be the Tasks Assigned
All internal functions such as clearing will be handled but this expects you to actually clear wtv your doing.

]]
function CSMeta:Seduce(Method:number | RBXScriptSignal | ({Category}) -> nil) : nil
	
	if typeof(Method) == "number" then
		task.delay(Method, DoClean, self)
	elseif typeof(Method) == "RBXScriptSignal" then
		Method:Once(function()
			DoClean(self)
		end)
	elseif Method == nil then
		DoClean(self)
	elseif typeof(Method == "function") then
		task.spawn(Method, self.TasksAssigned)
		return table.remove(ActiveCategories, FindCategory(self.Category, true)), CategoryClosedEvent:Fire()
	else
		error("Attempt to suduce invadild method type "..typeof(Method),0)
	end
end

CSMeta.Insertion = CategoryInsertion.Event

--[[--------------------------------------------------------------------------------------------------------------------------------]]--

local CategoryService = {}

-- Table inserted my be full of the same type stated, To check use the ``ClassFilter`` property and if Any its undecided
CategoryService.NewCategory = function(Identifyer:string) : Category
	assert(type(Identifyer) == "string", "Name must be a string")
	local self:any = setmetatable({}, CSMeta)
	
	self.Category = Identifyer 
	self.ClassFiller = "Any"
	self.TasksAssigned = {}
	
	table.insert(ActiveCategories, self)
	CategoryCreatedEvent:Fire(self)
	
	return self
end

-- Constructs a new category based on two already created catergories, Cat1 takes priority
CategoryService.ConcatViaName = function(Cat1:string, Cat2:string) : Category
	Cat2 = CategoryService:GetCategoryInfo(Cat2)
	local NewTbl = CategoryService:AddToCategory(Cat1, Cat2.TasksAssigned)
	table.remove(ActiveCategories, table.find(ActiveCategories, Cat2))
	return NewTbl, CategoryInsertion:Fire(NewTbl)
end

-- Table inserted my be full of the same type stated, To check use the ``ClassFilter`` property and if Any its undecided
function CategoryService:AddToCategory(Identifyer:string, TblOfThings:{})
	ValidityChecks(Identifyer, TblOfThings)
	CheckValidType(TblOfThings)
	local CC = FindCategory(Identifyer)
	
	if #CC.TasksAssigned == 0 then
		CC.TasksAssigned = TblOfThings
		CC.ClassFiller = if EasyType.Type(TblOfThings[1], true) == "Tween" then EasyType.Type(TblOfThings[1], true) else EasyType.Type(TblOfThings[1])
	else
		if CC.ClassFiller == "Any" then
			CC.ClassFiller = if EasyType.Type(TblOfThings[1], true) == "Tween" then EasyType.Type(TblOfThings[1], true) else EasyType.Type(TblOfThings[1])
		end
		
		if typeof(TblOfThings[1]) == CC.ClassFiller then
			for _, V:Category in pairs(TblOfThings) do
				table.insert(CC.TasksAssigned, V)
			end
		else
			error("Attempt to concatinate table of type "..typeof(TblOfThings[1]).." to a table of type "..CC.ClassFiller,0)
		end
	end
	
	return CC, CategoryInsertion:Fire(CC)
end

-- Returns Category if name match else Nil
function CategoryService:GetCategoryInfo(Identifyer:string) : Category
	ValidityChecks(Identifyer, {})
	return FindCategory(Identifyer)
end

-- Returns all active categories
function CategoryService:GetAllActiveCategories() : {Category}
	return ActiveCategories
end

-- Returns all Categories of some holding type
function CategoryService:GetAllCategoriesOfType(Type:"function" | "RBXScriptConnection" | "Thread" | "Instance" | "Tween") :{Category}?
	if CheckValidType(Type) then return GetCategoriesOfTypeStated(Type) end
end

-- Cleans via Type
function CategoryService:SeduceByType(Type:"function" | "RBXScriptConnection" | "Thread" | "Instance" | "Tween") : nil
	if CheckValidType(Type) then 
		for _, v in pairs(GetCategoriesOfTypeStated(Type)) do
			DoClean(v)
		end
	end
end

-- Cleans via Name
function CategoryService:SeduceByName(Identifyer:string) : nil
	ValidityChecks(Identifyer, {})
	return DoClean(FindCategory(Identifyer))
end

-- Cleans all types
function CategoryService:SeduceAll() : nil
	for _, V:Category in pairs(ActiveCategories) do
		DoClean(V)
	end
	ActiveCategories = {}
	return
end

CategoryService.CategoryOpened = CategoryCreatedEvent.Event
CategoryService.CategoryClosed = CategoryClosedEvent.Event

-- Same As SeduceAll
function CategoryService.Clean()
	CategoryService:SeduceAll()
end

return CategoryService :: typeof(CategoryService)

--[[--------------------------------------------------------------------------------------------------------------------------------]]--