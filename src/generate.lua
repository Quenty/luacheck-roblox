local OUTPUT_FILE = "roblox_standard.lua"

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

		return assert(json:decode(jsonDump))
	end

	local jsonDump = assert(http.request(("http://setup.roblox.com/%s-API-Dump.json"):format(version)))
	local api = assert(json:decode(jsonDump))

	local file = assert(io.open(path, "w"))
	file:write(jsonDump)
	file:close()

	return api
end

local api = get_api()






-- local function createTable(api)
--   local output = {}

--   local indent = addHeader(output)

--   addFunctions(output, indent, api.functions)
--   addCallbacks(output, indent, api.callbacks)

--   addModules  (output, indent, api.modules  )

--   addFooter(output)

--   return table.concat(output, "\n")
-- end

-- local function write()
--   local file = io.open(OUTPUT_FILE, "w")
--   assert(file, "ERROR: Can't write file: " .. OUTPUT_FILE)
--   file:write(data)
-- end