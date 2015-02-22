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

local n = 0
local function __select_wrapper(recvt, sendt, timeout)
log:info("enter ev_select")
	-- step(1): create poller_fd
	if poller_fd == nil then
		poller_fd = socket_ext.create_poller()
	end
	n=n+1
	if n%1000 == 0 then
		s2fd_map = coutils.compact_table(s2fd_map)
		fd2s_map = coutils.compact_table(fd2s_map)
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
		tcp_meta_index.__bind = tcp_metatable.__index.bind
		tcp_meta_index.__listen = tcp_metatable.__index.listen
		tcp_meta_index.__accept = tcp_metatable.__index.accept
		tcp_meta_index.__close = tcp_metatable.__index.close
		--tcp_meta_index.__connect = x.__index.connect
		tcp_meta_index.bind = wrapper.__bind
		tcp_meta_index.listen = wrapper.__listen
		tcp_meta_index.accept = wrapper.__accept
		tcp_meta_index.close = wrapper.__close
		--tcp_meta_index.connect = __connect_wrapper
		for k,v in pairs(tcp_meta_index) do
			tcp_metatable.__index[k] = v
		end
	end
	debug.setmetatable(tcp, tcp_metatable)
	class_metatables [class] = tcp_metatable
	log:error({event="tcp __intercept_metatable", meta= base.getmetatable(tcp), new_accept=wrapper.__accept, s=tcp})
	log:error({wrapper=wrapper})
end 
wrapper.__select = __select_wrapper

local function __close_wraper(tcp_s)
	socket_ext.unregister_fd(poller_fd, tcp_s:getfd())
	log:info({event="unregister_fd", fd=tcp_s:getfd()})
	s2fd_map[tcp_s] = nil
	fd2s_map[tcp_s:getfd()] = nil
	tcp_s:__close()

end
wrapper.__close = __close_wraper				-- checked


local function __bind_wrapper(s, addr, port)	-- "tcp{master} --> "tcp{server}
	local rc, msg = s:__bind(addr, port)
	if rc ~= nil then
		__intercept_metatable(s)
	end
	log:error("__bind_wrapper")
	return rc,msg
end
wrapper.__bind = __bind_wrapper					-- checked

local function __listen_wrapper(s, backlog)	-- "tcp{master} --> "tcp{server}
	local rc, msg = s:__listen(backlog)
	if rc ~= nil then
		__intercept_metatable(s)
	end
	log:error("__listen_wrapper")
	return rc,msg
end
wrapper.__listen = __listen_wrapper					-- checked

local function __connect_wrapper(tcp_s, addr, port)
end
wrapper.__connect = __connect_wrapper			-- checked

local function __accept_wrapper(listen_s)
	local client_s, errmsg = listen_s:__accept()
	if client_s ~= nil then
		__intercept_metatable(client_s)
	end
	log:error("__accept_wrapper")
	return client_s,errmsg
end
wrapper.__accept = __accept_wrapper				-- checked

local function __tcp_wrapper()
	log:debug("socket.tcp")
	local tcp,msg = socket.__tcp()
	if tcp ~= nil then
		__intercept_metatable(tcp)
	end
	return tcp,msg
end
wrapper.__accept = __accept_wrapper				-- checkeds

if config.global_use_socket_ev then
	wrapper.__tcp = __tcp_wrapper

	socket.__select = socket.select
	socket.__tcp = socket.tcp

	socket.select = __select_wrapper
	socket.tcp = __tcp_wrapper

	log:error("socketext was injected!!!")
end
return socket