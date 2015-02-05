local socket = require("socket")
local logging = require("logging")
local coroutine = require("coroutine")
local debug = debug
local table = table
local table = require("table")
local coroutine = require("coroutine")
local logging = require("logging")
local os = os
local ipairs = ipairs
local pairs = pairs
local assert = assert
local print = print
local type = type
local tostring = tostring
local debug = debug
local arg = arg
local base = _G

local log = logging.new(function(self, level, message) 
	local info = debug.getinfo(4)
	local map = { info.short_src,":", info.name or "?", "():",info.currentline or "?"}
	print(level, table.concat(map),message) return true end)
log:setLevel (logging.DEBUG)
local ss --= socket.tcp()

local function wrap_nil(map)
	if (map == nil) then return "nil map" end
	for k,v in pairs(map) do
		if (v == nil) then map[k] = "nil" end
	end
end

local function run()

	log:debug("--enter main()")
	print(table.concat(debug.getinfo(1), " "))
	assert(#arg == 1, "usage: lua test.lua port")
	ss = socket.tcp()
	assert(ss:bind("*",arg[1]))
	assert(ss:listen(32))
	--ss = assert(socket.bind("*", 7070))
	assert(ss:setoption("reuseaddr", true))
	local ip, port = ss:getsockname()
	print("--enter main()...")
	-- load listen coroutines
	while true do
		local r_set = {ss}
		local w_set = {}
		local ready_forread,msg
		--table.insert(r_set, ss)

		ready_forread, _,msg = socket.select(r_set, nil, 1)
		for k,v in ipairs(ready_forread) do
			if (v == ss) then
				log:debug("accept event occur",msg)
			end
			log:debug({listen=v or "nil"})
			local client,errmsg = v:accept()
			log:debug({listen=ss or nil, client=client or "nil", error=errmsg or "nil"})
			assert(client)
			ss:close()
			socket.sleep(1)
			os.exit(0)
			accepted_fd:settimeout(0)
			print("--accept new connection\n")
		end
	end
end
local co_main = _G.coroutine.create(function(port)
	port = port or 7070
end)


	log:debug({"type", type(co_main)})
if (run()) then
	--
else
	ss:close()
	print(debug.traceback ())
	os.exit(0)
end
