local config = require("config")
local socket = require("socket")
local socket_ext = require("socket_ext")
local string = require("string")
local table = require("table")
local coroutine = require("coroutine")
local coscheduler = require("coscheduler")
local coutils = require("coutils")
local os = os
local pairs = pairs
local ipairs = ipairs
local assert = assert
local print = print
local type = type
local string = string
local debug = debug
local collectgarbage = collectgarbage
local getmetatable = getmetatable
local base = _G

module("socketext")

local s2fd_map = {}
local fd2s_map = {}
local poller_fd = nil

local log = coutils.new_logger(coutils.DEBUG)
local wrapper = {}

local function __select_wrapper(recvt, sendt, timeout)
log:info("enter ev_select")
	-- step(1): create poller_fd
	if poller_fd == nil then
		poller_fd = socket_ext.create_poller()
	end
	-- step(2) register event
	for _,s in ipairs(recvt) do
		if (s2fd_map[s] == nil) then
			s2fd_map[s] = s:getfd()
			fd2s_map[ s:getfd() ] = s
		end
			socket_ext.register_fd(poller_fd, s2fd_map[s], s,false)
			log:debug({fd=s:getfd()})
	end
	for _,s in ipairs(sendt) do
		if (s2fd_map[s] == nil) then
			s2fd_map[s] = s:getfd()
			fd2s_map[ s:getfd() ] = s
		end
			socket_ext.register_fd(poller_fd, s2fd_map[s], s,true)
	end
	-- step(3): wait poller event
	local readable, writeable, msg =  socket_ext.wait_ev(poller_fd, timeout or -1);
	if (readable ~= nil) then
		local t = {}
		for _, fd in ipairs(readable) do
			local s = fd2s_map[fd]
			if (s ~= nil) then 
				table.insert(t,s)
			end
			log:debug({fd=fd, s=s or "nil"})

		end
		readable = t
	end
	if (writeable ~= nil) then
		local t = {}
		for _, fd in ipairs(writeable) do
			local s = fd2s_map[fd]
			if (s ~= nil) then 
				table.insert(t,s)
			end
		end
		writeable = t
	end

	log:debug({event="readable", out=readable or "nil"})
	log:debug({event="writeable", out=writeable or "nil", msg=msg or "nil"})
	--debug.debug()
	return readable,writeable,msg
end

local class_metatables = {}
local function __intercept_metatable(tcp)
	local class = tcp.class
	local tcp_metatable = class_metatables [class]
	if tcp_metatable == nil then
		local tcp_meta_index = {}
		tcp_metatable = base.getmetatable(tcp)
		tcp_meta_index.__close = tcp_metatable.__index.close
		--tcp_meta_index.__connect = x.__index.connect
		tcp_meta_index.__accept = tcp_metatable.__index.accept
		tcp_meta_index.close = wrapper.__close
		--tcp_meta_index.connect = __connect_wrapper
		tcp_meta_index.accept = wrapper.__accept
		for k,v in pairs(tcp_meta_index) do
			tcp_metatable.__index[k] = v
		end
	end
	debug.setmetatable(tcp, tcp_metatable)
end 
wrapper.__select = __select_wrapper

local function __close_wraper(tcp_s)
	socket_ext.unregister_fd(poller_fd, tcp_s.getfd())
	self:__close()
end
wrapper.__close = __close_wraper


local function __connect_wrapper(tcp_s, addr, port)
end
wrapper.__connect = __connect_wrapper

local function __accept_wrapper(listen_s)
	local client_s, errmsg = listen_s:__accept()
	if client_s ~= nil then
		__intercept_metatable(client_s)
	end
	return client_s,errmsg
end
wrapper.__accept = __accept_wrapper

local function __tcp_wrapper()
	log:debug("socket.tcp")
	local tcp,msg = socket.__tcp()
	if tcp ~= nil then
		__intercept_metatable(tcp)
	end
	return tcp,msg
end
wrapper.__tcp = __tcp_wrapper

socket.__select = socket.select
socket.__tcp = socket.tcp

socket.select = __select_wrapper
socket.tcp = __tcp_wrapper

return socket