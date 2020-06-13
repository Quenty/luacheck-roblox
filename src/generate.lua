local OUTPUT_FILE = ".luacheckrc"
local TAB = "    "
local MAX_LINE_LENGTH = 100

local json = require("json")
local http = require("socket.http")

local function get_api()
	local version = assert(http.request("http://setup.roblox.com/versionQTStudio"))
	local path = ("./data/%s.json"):format(version)

	local existing = io.open(path, "r")
	if existing then
		-- read cache
		local jsonDump = existing:read("*all")
		existing:close()

		return assert(json.decode(jsonDump))
	end

	local jsonDump = assert(http.request(("http://setup.roblox.com/%s-API-Dump.json"):format(version)))
	local api = assert(json.decode(jsonDump))

	local file = assert(io.open(path, "w"))
	file:write(jsonDump)
	file:close()

	return api
end

local function cache_classes(api)
	local cache = {}
	for _, item in pairs(api.Classes) do
		cache[item.Name] = item
	end
	return cache
end

local function write_head(output)
	local HEAD = [[local empty = {}
local read_write = { read_only = false }
local read_write_class = { read_only = false, other_fields = true }
local read_only = { read_only = true }

local function def_fields(field_list)
   local fields = {}

   for _, field in ipairs(field_list) do
      fields[field] = empty
   end

   return { fields = fields }
end

local enum = def_fields({"Value", "Name"})

local function def_enum(field_list)
   local fields = {}

   for _, field in ipairs(field_list) do
      fields[field] = enum
   end

   fields["GetEnumItems"] = read_only

   return { fields = fields }
end

stds.roblox = {]]
	table.insert(output, HEAD)
end

local function get_all_members(class_cache, class_name)
	local members = {}
	local class = class_cache[class_name]
	while class do
		for _, item in pairs(class.Members) do
			table.insert(members, item)
		end
		class = class_cache[class.Superclass]
	end
	return members
end

local function extract_enum_names(items)
	local output = {}
	for _, item in pairs(items) do
		table.insert(output, item.Name)
	end
	return output
end

local function write_fields(items, indent, str)
	local fields = {}
	str = indent .. str

	for _, item in ipairs(items) do
		local name = ("\"%s\", "):format(item)
		if #(str .. name) > MAX_LINE_LENGTH then
			str = str:sub(1, -2) -- strip whitespace
			table.insert(fields, str)
			str = indent .. TAB .. name
		else
			str = str .. name
		end
	end

	table.insert(fields, str)
	fields[#fields] = fields[#fields]:sub(1, -3) .. "}),"

	return fields
end


local function write_enums(indent, api, output)
	table.insert(output, indent .. "-- Enums")
	table.insert(output, indent .. "Enum = {")
	table.insert(output, indent .. TAB .. "readonly = true,")
	table.insert(output, indent .. TAB .. "fields = {")

	for _, item in pairs(api.Enums) do
		local fields = write_fields(extract_enum_names(item.Items), indent .. TAB:rep(2), item.Name .. " = def_enum({")
		for i=1, #fields do
			table.insert(output, fields[i])
		end
	end
	table.insert(output, indent .. TAB .. "}")
	table.insert(output, indent .. "}")
end

local function write_item(output, indent, name, values)
	local str = name .. " = def_fields({"
	local fields = write_fields(values, indent, str)
	for i=1, #fields do
		table.insert(output, fields[i])
	end
	table.insert(output, "")
end

local function has_tag(tags, value)
	if not tags then
		return false
	end

	for _, tag in pairs(tags) do
		if tag == value then
			return true
		end
	end

	return false
end

local function is_value_category(member,category)
	return 	member.ValueType and
			member.ValueType.Category == category -- only compare category, as classname can be specific, but luacheck can't infer that statically
end

--- Used for script, datamodel, and workspace which are global variables
local function write_class(output, indent, name, class_cache, class_name)
	local members = get_all_members(class_cache, class_name)

	table.insert(output, indent .. name .. " = {")
	table.insert(output, indent .. TAB .. "other_fields = true,")
	table.insert(output, indent .. TAB .. "fields = {")

	for _, member in pairs(members) do
		if not has_tag(member.Tags, "Deprecated") then
			local mode = "read_write"; -- default mode
			if has_tag(member.Tags, "ReadOnly") then
				mode = "read_only";
			elseif is_value_category(member, "Class") then -- is not readonly and the member type a roblox class?
				mode = "read_write_class"
			end
			local output_type = member.Name .. (" = %s;"):format(mode)
			table.insert(output, indent .. TAB:rep(2) .. output_type)
		end
	end

	table.insert(output, indent .. TAB .. "}")
	table.insert(output, indent .. "},")
end

local function write_methods(indent, output)
	table.insert(output, indent .. "-- Methods")
	local METHODS = {
		"delay";
		"settings";
		"spawn";
		"tick";
		"time";
		"typeof";
		"version";
		"wait";
		"warn";
		"UserSettings";
	}

	for _, item in pairs(METHODS) do
		table.insert(output, indent .. ("%s = empty;"):format(item))
	end
	table.insert(output, "")
end

local function write_types(indent, output)
	table.insert(output, indent .. "-- Types")

	write_item(output, indent, "Axes", {"new"})
	write_item(output, indent, "BrickColor", {
		"new",
		"palette",
		"random",
		"White",
		"Gray",
		"DarkGray",
		"Black",
		"Red",
		"Yellow",
		"Green",
		"Blue",
	})
	write_item(output, indent, "CFrame", {
		"new",
		"fromEulerAnglesXYZ",
		"Angles",
		"fromOrientation",
		"fromAxisAngle",
		"fromMatrix",
	})
	write_item(output, indent, "Color3", {
		"new",
		"fromRGB",
		"fromHSV",
		"toHSV",
	})
	write_item(output, indent, "ColorSequence", {"new"})
	write_item(output, indent, "ColorSequenceKeypoint", {"new"})
	write_item(output, indent, "DockWidgetPluginGuiInfo", {"new"})
	write_item(output, indent, "Enums", {"GetEnums"})
	write_item(output, indent, "Faces", {"new"})
	write_item(output, indent, "Instance", {"new"})
	write_item(output, indent, "NumberRange", {"new"})
	write_item(output, indent, "NumberSequence", {"new"})
	write_item(output, indent, "NumberSequenceKeypoint", {"new"})
	write_item(output, indent, "PhysicalProperties", {"new"})
	write_item(output, indent, "Random", {"new"})
	write_item(output, indent, "Ray", {"new"})
	write_item(output, indent, "RaycastParams", {"new"})
	write_item(output, indent, "Rect", {"new"})
	write_item(output, indent, "Region3", {"new"})
	write_item(output, indent, "Region3int16", {"new"})
	write_item(output, indent, "TweenInfo", {"new"})
	write_item(output, indent, "UDim", {"new"})
	write_item(output, indent, "UDim2", {
		"new",
		"fromScale",
		"fromOffset"
	})
	write_item(output, indent, "Vector2", {"new"})
	write_item(output, indent, "Vector2int16", {"new"})
	write_item(output, indent, "Vector3", {
		"new",
		"FromNormalId",
		"FromAxis"
	})
	write_item(output, indent, "Vector3int16", {"new"})
end

local function write_libraries(indent, output)
	table.insert(output, indent .. "-- Libraries")
	write_item(output, indent, "math", {
		"abs",
		"acos",
		"asin",
		"atan",
		"atan2",
		"ceil",
		"clamp",
		"cos",
		"cosh",
		"deg",
		"exp",
		"floor",
		"fmod",
		"frexp",
		"ldexp",
		"log",
		"log10",
		"max",
		"min",
		"modf",
		"noise",
		"pow",
		"rad",
		"random",
		"randomseed",
		"sign",
		"sin",
		"sinh",
		"sqrt",
		"tan",
		"tanh",
		"huge",
		"pi",
	})
	write_item(output, indent, "table", {
		"concat",
		"foreach",
		"foreachi",
		"getn",
		"insert",
		"remove",
		"sort",
		"pack",
		"unpack",
		"move",
		"create",
		"find",
	})
	write_item(output, indent, "os", {
		"time",
		"difftime",
		"date"
	})
	write_item(output, indent, "debug", {
		"traceback",
		"profilebegin",
		"profileend",
	})
	write_item(output, indent, "utf8", {
		"char",
		"codes",
		"codepoint",
		"len",
		"offset",
		"graphemes",
		"nfcnormalize",
		"nfdnormalize",
		"charpattern",
	})
	write_item(output, indent, "bit32", {
		"arshift",
		"band",
		"bnot",
		"bor",
		"btest",
		"bxor",
		"extract",
		"replace",
		"lrotate",
		"lshift",
		"rrotate",
		"rshift",
	})
	write_item(output, indent, "string", {
		"byte",
		"char",
		"find",
		"format",
		"gmatch",
		"gsub",
		"len",
		"lower",
		"match",
		"rep",
		"reverse",
		"split",
	})
end

local function write_foot(output)
	local FOOT = [[
}

stds.testez = {
	read_globals = {
		"describe",
		"it", "itFOCUS", "itSKIP",
		"FOCUS", "SKIP", "HACK_NO_XPCALL",
		"expect",
	}
}

stds.plugin = {
	read_globals = {
		"plugin",
		"DebuggerManager",
	}
}

ignore = {}

std = "lua51+roblox"

files["**/*.spec.lua"] = {
	std = "+testez",
}
]]
	table.insert(output, FOOT)
end

local function write_globals(indent, output, class_cache)
	table.insert(output, indent .. "globals = {")

	write_class(output, indent .. TAB, "script", class_cache, "Script")
	write_class(output, indent .. TAB, "game", class_cache, "DataModel")
	write_class(output, indent .. TAB, "workspace", class_cache, "Workspace")

	table.insert(output, indent .. "},")
end

local function write_readglobals(indent, output, api)
	table.insert(output, indent .. "read_globals = {")

	write_methods(indent .. TAB, output)
	write_libraries(indent .. TAB, output)
	write_types(indent .. TAB, output)
	write_enums(indent .. TAB, api, output)

	table.insert(output, indent .. "},")
end

local function create_table(api)
	local output = {}

	local class_cache = cache_classes(api)

	write_head(output)
	write_globals(TAB, output, class_cache)
	write_readglobals(TAB, output, api)
	write_foot(output)

	return table.concat(output, "\n")
end

local function write()
	local api = get_api()
	local output = create_table(api)

	local file = assert(io.open(OUTPUT_FILE, "w"))
	file:write(output)
	file:close()
end

write()