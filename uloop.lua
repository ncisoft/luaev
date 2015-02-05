local socket = require("socket")
local string = require("string")
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

module("uloop")


local log = logging.new(function(self, level, message) 
	local info = debug.getinfo(4)
	local map = { info.short_src,":", info.name or "?", "():",info.currentline or "?"}
	print(level, table.concat(map),message) return true end)
log:setLevel (logging.DEBUG)

local EV = {
LISTEN = 1, READ = 2, WRITE = 3 } 
local ev_cos= { listen = {}, read = {}, write = {} }
local s_maps = {}

local function __is_kv_table_empty(map)
	for k,v in pairs(map) do
		return false
	end
	return true
end

local function wrap_nil(map)
	local map2={}
	if (map == nil) then return "nil map" end
	for k,v in pairs(map) do
		map2[k] =  v or"nil";
	end
	return map2
end


local MTU_SIZE = 20480

local function join_listener(s)
	print("join_listner")
	print("size is ".."_socket is ")
	s:settimeout(2)
	print(s_maps[ s ] == nil)
	if (s_maps[ s ] == nil) then
		s_maps[ s ] =  {co=coroutine.running(), socket=s, is_listen=true}
		log:debug("--listen sock was registered")
	else
		log:debug("--s_maps[s] is not nil")
	end
	log:debug({ "s_maps is empty?", wrap_nil(s_maps)})
	log:debug({"listen socket is", s})
	log:debug("haha")
end

local function join_read(_co, _socket)
	_socket:settimeout(0)
	if (s_maps[ socket ] == nil) then
		s_maps[_socket] = {co=_co, socket=_socket, r_queue = {}}
	end
	if (s_maps[_socket].r_queue == nil) then
		s_maps[_socket].r_queue = {}
	end
end

local function co_accept(_co, listen_socket)
	while true do
		local s_child = coroutine.yield()
		local co_child = coroutind.create(function(_co,listen_s)
			local data	= co_read(_co, s)
			if(data == nil) then
				print("client is dead\n")
				return
			end
			print("receive..."..data.."\n")
			co_write(_co, s, "+PONG")
		end)
		coroutine.resume(co_child, co_child, s_child)
	end
end

local function co_read(_co, _socket)
	join_read(co, _socket);
	rc, data = coroutine.yield()
	return data
end

local function join_write(_co, _socket, data)
	_socket:settimeout(0)
	if (s_maps[_socket ] == nil) then
		s_maps[_socket] = {co=_co, socket=_socket, w_queue = {}}
	end
	table.insert(s_maps[_socket].w_queue, data)
end

local function join_close(_co, _socket)

end

local function schedule(init_co,port)
	-- load listen coroutines
	log:debug("enter main loop, type(init_co)="..type(init_co))
	coroutine.resume(init_co, port)
	log:debug("after resume main coroutine")
	while true do
		local r_set = {}
		local w_set = {}
		for k, v in pairs(s_maps) do
			log:debug({k, v})
			if (v.is_listen == true or v.r_queue ~= nil) then
				table.insert(r_set, v.socket)
			end
			if (v.w_queue ~= nil) then
				table.insert(w_set, v.socket)
			end
		end
		if(#r_set == 0 and #w_set == 0)  then
			return
		end
		local rsocks, wsocks = socket.select(r_set, wr_set, 1)
		for _, s in ipairs(rsocks) do
			log:debug(wrap_nil({_s=s}))
			local o = s_maps[s]
			if (o.is_listen) then
				local apccepted_fd,errmsg = s:accept()
				log:debug(wrap_nil({server=s, client=accepted_fd or "nil",error=errmsg or "nil"}))
				print(debug.traceback ())
				os.exit(0)
				accepted_fd:settimeout(0)
				print("--accept new connection\n")
				coroutine.resume(o.co, accepted_fd)
		end
			if (v.r_queue ~= nil) then
				local data,errmsg = s.receive(MTU_SIZE)
				if (data == nil) then
					print(errmsg.."--read--nil\n")
				end
				table.insert(v.r_queue, data)
				coroutine.resume(v.co, v.r_queue)
			end
		end
		for i, s in ipairs(wsocks) do
			local v = s_maps(s)
			if (v.w_queue ~= nil) then
				local rc,errmsg,pos = s.send(v.w_queue[1])
				if (rc == nil) then
					print(errmsg.."--write--nil\n")
				end
				table.remove(v.r_queue, 1)
				coroutine.resume(v.co, v.r_queue)
			end
		end
	end
end

co_main = coroutine.create(function(port)
	port = port or 7070
	log:debug("--enter main(),will listen on port:"..port)
	local s-- = socket.tcp()
	s = assert(socket.bind("*", port))
	--assert(s:listen(20))
	assert(s:setoption("reuseaddr", true))
	log:debug("--enter main()...")
	join_listener(s)
	while true do
		co_accept(base.coroutine.running(), s)
	end
end)

	assert(#arg == 1, "usage: lua uloop.lua port")

	schedule(co_main, arg[1])
