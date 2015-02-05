local socket = require("socket")
local string = require("string")
local table = require("table")
local coroutine = require("coroutine")
local logging = require("logging")
local term   = require 'term'
local colors = term.colors -- or require 'term.colors'
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
	local color_map = {}
	color_map[ logging.DEBUG ] =  ""
	color_map[ logging.INFO ] =  colors.yellow
	color_map[ logging.WARN ] =  colors.red
	local color = color_map [ level ] or ""
	local map = { info.short_src,":", info.name or "?", "():",info.currentline or "?"}
	print(color, level, table.concat(map),message,colors.reset) return true end)
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

local function get_map_size(map)
	local n=0;
	for k,v in pairs(map) do
		n = n+1;
	end
	return n
end


local MTU_SIZE = 20480

local function join_listener(s)
	log:debug("join_listner")
	s:settimeout(2)
	print(s_maps[ s ] == nil)
	if (s_maps[ s ] == nil) then
		s_maps[ s ] =  {co=coroutine.running(), socket=s, is_listen=true}
		log:debug("--listen sock was registered: "..type(coroutine.running()))
	else
		log:debug("--s_maps[s] is not nil")
	end
	log:debug({ "s_maps size", get_map_size(s_maps)})
	log:debug({listen_socket_is=s})
end

local function join_read(_co, _socket)
	if (s_maps[ socket ] == nil) then
		s_maps[_socket] = {co=_co, socket=_socket, r_queue = {}}
	end
end

local function co_accept(_co, listen_socket)
	while true do
		log:info({coroutine.running()})
		local fd = coroutine.yield()
		log:info({"co_accept coroutine was resumed!",fd})
		local co_child = coroutine.create(function(fd)
			local co = coroutine.running()
			log:warn("child.fork coroutine was resumed")
			while 1 do
				local data	= __co_read(co, fd)
				if(data == nil) then
					log:debug("client is dead\n")
					assert(data)
				end
				log:debug("receive..."..data.."\n")
				co_write(co, fd, "+"..data)
			end
		end)
		log:debug("accept a child")
		coroutine.resume(co_child, fd)
	end
end

local function __co_read(_co, _socket)
	log:warn("......co_read was called")
	print("lalllaaa")
	join_read(co, _socket);
	data = coroutine.yield()
	return data
end

local function co_write(_co, fd, data)
	join_write(_co, _socket, data)
	local rc = coroutine.yield(_co)
	return rc
end

local function join_write(_co, _socket, data)
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
	while 1 do
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
		log:debug({r_set_size = #r_set, w_set_size = #w_set, rset=r_set[1]})
		assert(#r_set > 0 or #w_set > 0)
		local readable, writeable, msg = socket.select(r_set, w_set, nil)
		for _, s in ipairs(readable) do
			local o = s_maps[s]
			assert(o.socket == s)
			if (o.is_listen) then
				local fd,errmsg = s:accept()
				log:debug({server=s, client=fd or "nil",error=errmsg or "nil", err=msg or "nil"})
				assert(fd)
				fd:settimeout(0)
				log:debug({"accept new connection, will resume accept coroutine",o.co})
				coroutine.resume(o.co, fd)
			end
			if (o.r_queue ~= nil) then
				local data,errmsg = s.receive(MTU_SIZE)
				if (data == nil) then
					log:debug(errmsg.."--read--nil")
				end
				table.insert(v.r_queue, data)
				coroutine.resume(v.co, data)
			end
		end
		for i, s in ipairs(writeable) do
			local v = s_maps[s]
			if (v.w_queue ~= nil) then
				local rc,errmsg,pos = s.send(v.w_queue[1])
				if (rc == nil) then
					log:debug(errmsg.."--write--nil")
				coroutine.resume(v.co, false)
				end
				table.remove(v.w_queue, 1)
				coroutine.resume(v.co, true)
			end
		end
	end
end

co_main = base.coroutine.create(function(port)
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
