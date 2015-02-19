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
local base = _G

module("socketext")

local s2fd_map = {}
local fd2s_map = {}
local poller_fd = nil

local log = coutils.new_logger(coutils.DEBUG)

function ev_select(recvt, sendt, timeout)
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





socket.select = ev_select
return socket