local CustomTypes = { -- "Put all your custom types in here as a string"
	
}

local function SearchType(Type:string)
	for _, CustomType:string in pairs(CustomTypes)  do
		if Type == CustomType then
			return CustomType
		end
	end
	return nil
end


--[[						How To Use

To Type check with custom types you must have a value of "ClassName" in either the serial table or metaTable for the type check to understand your custom Type

Features:

Allows you to Type check custom Types even if they arent listed in the Type List, "Will Result in a warn"
ByPasses Any Meta-Methods, "Dont need __index to type check"
Supports Serial and MetaData Typing

]]

local ET = {}

function ET:GetTypes()
	return CustomTypes
end

-- Only returns unInherited type if Instance
function ET.Type(GetType:any?, ShouldClassInstance:boolean) :string 
	if typeof(GetType) == "table" then
		local RawClass = rawget(GetType, "ClassName")
		if RawClass then
			if RawClass == SearchType(RawClass) then
				return RawClass
			else
				warn("ClassName Serial data found but is not recorded inside of Custom Type list")
				return RawClass
			end
			
			
		elseif getmetatable(GetType) then
			local MetaClass = rawget(getmetatable(GetType), "ClassName")
			if MetaClass then
				if MetaClass == SearchType(MetaClass) then
					return MetaClass
				else
					warn("ClassName MetaData found but is not recorded inside of Custom Type list")
					return MetaClass
				end
				
			else
				return typeof(GetType)
			end
		end
	elseif typeof(GetType) == "Instance" and ShouldClassInstance then
		return GetType.ClassName
	end
	return typeof(GetType)
end
return ET