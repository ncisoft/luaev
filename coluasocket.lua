local socket = require("socket")
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
local tostring = tostring
local setmetatable = setmetatable
local base = _G

module("coluasocket")
local coluasocket = {} -- the table representing the class, which will double as the metatable for the instances
--Mailbox.__index = Mailbox -- failed table lookups on the instances should fallback to the class table, to get methods

local log = coutils.new_logger(coutils.DEBUG)

local DEFAULT_BACKLOG = 32
local MTU_SIZE = 20480

--local ev_cos= { listen = {}, read = {}, write = {} }
local s_maps = {}	-- key=luasocket, value= {co, is_listen, r_queue{}, w_queue{}}

local function get_map_size(map)
	local n=0;
	for k,v in pairs(map) do
		n = n+1;
	end
	return n
end

local function __join_listener(s,co)
	log:debug("join_listner")
	--print(s_maps[ s ] == nil)
	if (s_maps[ s ] == nil) then
		s_maps[ s ] =  {co=co, socket=s, is_listen=true}
		log:debug("--listen sock was registered: "..type(coroutine.running()))
	end
	s_maps[ s ].co = co
	log:debug({ "s_maps size", get_map_size(s_maps)})
	log:debug({listen_socket_is=s})
end

local function __init()
	return coutils.__init_object(coluasocket)
	--return setmetatable({}, {__index=coluasocket})
end

-- non-blocking method
-- @return cosocket
function listenTCP(addr, port, backlog)
	assert(addr ~= nil and port ~= nil)
	local self = __init()
	self.addr = addr or "*"
	self.port = port or 7070 
	self.backlog = backlog or DEFAULT_BACKLOG
	log:debug("--enter listenTCP(),will listen on port:"..port)
	self.listen_s = socket.tcp()
	assert(self.listen_s:setoption("reuseaddr", true))
	assert(self.listen_s:bind(self.addr, self.port))
	assert(self.listen_s:listen(self.backlog))
--	assert(self.listen_s = socket.bind(self.addr, self.port, self.backlog))
--	assert(self.listen_s:setoption("reuseaddr", true))
	__join_listener(self.listen_s,nil)
	return self
end

-- accept from listen coluasocket, we will create a coroutine for accepted_func
-- blocking method
-- @return cosocket
-- @param accept_co will be resumed with (userdata,accepted cocoluasocket)
function coluasocket:accept(client_handler, userdata)
	assert(client_handler ~= nil and type(client_handler) == "function")
	local client = __init()

	__join_listener(self.listen_s, coroutine.running())
	client.s = coroutine.yield()
	log:info({"co_accept coroutine was resumed!",client.s})
	log:debug({accept__child=client.s or "nil"})
	__join_listener(self.listen_s, nil) -- detache accept coroutine from listen socket, will be attached next time

	local co_client = coroutine.create(function()
		client_handler(client, userdata)
	end)
	-- postpone running later
	coscheduler.join(co_client)

	return client
end

-- @return cosocket
--
function coluasocket:connect(addr, port)
	local self = __init()
end

function coluasocket:read(nbytes)
	return self:receive()
end

function coluasocket:receive(pattern, partial)
	local _co = coroutine.running()
	log:warn("......co_read was called")
	log:warn({co=_co or "nil"})
	-- step(1): join read
	if (s_maps[ self.s ] == nil) then
		s_maps[ self.s ] = {co=_co, socket=self.s, r_queue = {}}
	else
		s_maps[self.s].r_queue = {}
	end
	-- step(2): yield to read
	local data,msg  = coroutine.yield()
	log:warn("......co_read was resume.."..(data or "nil").." "..(msg or "nil msg"))
	if (msg == "closed") then 
		-- TODO: detach from reg_event
		log:error({s=self.s, msg="the socket was closed"})
		-- __detache_read(_socket)
		if (s_maps[self.s] ~= nil) then
			if (s_maps[self.s].w_queue == nil) then
				s_maps[self.s] = nil
			else
				s_maps[self.s].r_queue = nil
			end
		end

	end
	return data,msg

end

function coluasocket:write(data)
	return self:send(data)
end

function coluasocket:send(data)

	log:info({ev="......co_write was called", data=data or "nil"})
	data = data or "+hello\n"
	--__join_write(_co, fd, data)
	if (s_maps[self.s ] == nil) then
		s_maps[self.s] = {co=coroutine.running(), socket=self.s, w_queue = {}}
	end
	if (s_maps[self.s].w_queue == nil) then
		s_maps[self.s].w_queue = {}
	end
	table.insert(s_maps[self.s].w_queue, data)
	log:debug({s=s_maps[self.s]})

	local rc = coroutine.yield()
	log:warn("......co_write was resumed"..rc)
	return rc

end

function coluasocket:close()
end

local is_first_time = true
local n=0
local function step_scheduler()
	-- load listen coroutines
	if is_first_time then
		is_first_time = true
		log:debug("enter main loop")
	end
	-- run once only
	local r_set = {}
	local w_set = {}
	-- step(1): prepare r_set,w_set
	for k, v in pairs(s_maps) do
		log:debug({k, v})
		if (v.is_listen == true or v.r_queue ~= nil) then
			table.insert(r_set, v.socket)
		end
		if (v.w_queue ~= nil and #v.w_queue > 0) then
			table.insert(w_set, v.socket)
		end
	end
	n = n+1
	-- assert(n < 18)

	-- step(2): select
	log:info({r_set_size = #r_set, w_set_size = #w_set, rset=r_set[1], count=n})
	if (#r_set > 0 or #w_set > 0) then
		local readable, writeable, msg = socket.select(r_set, w_set, nil)

		-- step(3): process read event
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
				log:debug({s=s or "nil"})
				local data,errmsg,partial = s:receive(MTU_SIZE)
				if (data == nil) then
					log:debug(errmsg.."--read--nil")
					if (data == nil and errmsg == "closed") then
						log:error({socket_is_closed=true, will_resume_read_co=o, co_status=coroutine.status(o.co) or "nil"})
						coroutine.resume(o.co, nil, "closed")
					elseif (data == nil and errmsg == "timeout") then
						-- read partial data
						-- TODO: optimize the code
						table.insert(o.r_queue, partial)
						coroutine.resume(o.co, partial)
						table.remove(o.r_queue)
					end
				else
					log:debug({will_resume_read_co=o})
					table.insert(o.r_queue, data or partial)
					log:debug(o)
					coroutine.resume(o.co, data)
					table.remove(o.r_queue)
				end
			end
		end

		-- step(4): process write event
		for _, s in ipairs(writeable) do
			local v = s_maps[s]
			if (v.w_queue ~= nil and #v.w_queue > 0) then
				log:debug({will_resume_write_co=v})
				local rc,errmsg,pos = s:send(v.w_queue[1])
				if (rc == nil) then
					log:debug(errmsg.."--write--nil")
					coroutine.resume(v.co, false)
				else
					log:debug({write_rc=rc})
					table.remove(v.w_queue, 1)
					coroutine.resume(v.co, rc)
				end
			end
		end
	end
end

coscheduler.register_step_scheduler("coluasocket", step_scheduler)
