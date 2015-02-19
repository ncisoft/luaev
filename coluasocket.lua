local socket = require("socketext")
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
log:debug("will join listener")
__join_listener(self.listen_s,nil)
return self
end

function connectTCP(addr, port)
	assert(addr ~= nil and port ~= nil)
	local self = __init()
	self.s = socket.tcp()
	self.s:settimeout(0)
	local rc,err = self.s:connect(addr, port)
	log:debug({event="connect", rc=rc or "nil", error=err or "nil"})
	if (s_maps[ self.s ] == nil) then
		s_maps[ self.s ] =  {co=coroutine.running(), socket=self.s, is_connecting=true,w_queue = {}}
		log:debug("--accept sock was registered: "..type(coroutine.running()))
	end
	rc,err = coroutine.yield()
	s_maps[ self.s ] = nil
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
	coscheduler.join_once(co_client)


	return client
end

function coluasocket:read(nbytes)
	nbytes = nbytes or MTU_SIZE
	local out,err = self:receive(nbytes)
	log:debug({read=out or "nil", err=err or "nil"})
	return out,err
end

function coluasocket:__isclosed()
	return self.is_closed or false
end

function coluasocket:close()
	if not self.is_closed then
		self.s:__close()
	end
end
	
function coluasocket:__close()
	self.is_closed = true
	self.s:close()
	-- TODO: detach from reg_event
	log:warn({s=self.s, msg="the socket was closed"})
		-- __detache_read(_socket)
		if (s_maps[self.s] ~= nil) then
			if (s_maps[self.s].w_queue == nil) then
				s_maps[self.s] = nil
			end
			s_maps[self.s].r_queue = nil
		end
		-- __detache_write(_socket)
		if (s_maps[self.s] ~= nil) then
			if (s_maps[self.s].w_queue == nil) then
				s_maps[self.s] = nil
			else
				s_maps[self.s].w_queue = nil
			end
		end
		s_maps[self.s] = nil
	end


	function coluasocket:receive(nbytes)
		local _co = coroutine.running()
		log:debug({msg="......co_read was called", co=_co or "nil"})
		if self.is_close then
			log.error("the socket has been closed")
			return nil,"closed"
		end
    -- step(1): join read
    if (s_maps[ self.s ] == nil) then
    	s_maps[ self.s ] = {co=_co, socket=self.s, r_queue = {}}
    else
    	s_maps[self.s].r_queue = {}
    end
    -- step(2): yield to read
    local read_done = false
    while not read_done do
    	log:warn({msg="yield to read", co=_co})
    	local rc,msg = coroutine.yield()
    	log:debug({out="......co_read was resume..",rc=rc or "nil", msg=msg or "nil msg"})
    	if (msg == "closed") then
    		self:__close()
    		return nil, "closed"
    	end

    	local data = table.concat( s_maps[self.s].r_queue )
    	if (string.len(data) >= nbytes) then
    		s_maps[self.s].r_queue = {string.byte(data, nbytes+1, string.len(data))}
    		return string.byte(1, nbytes),""
    	else
            -- still wait for reading
            s_maps[self.s].r_queue = {}
            return data, "timeout"
        end
    end
end

function coluasocket:write(data)
	return self:send(data)
end

function coluasocket:send(data)

log:info({ev="......co_write was called", data=data or "nil"})
if self.is_close then
	log.error("the socket has been closed")
	return false, "closed"
end

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

	--- XXX: really need yield()?
	local rc,errmsg = coroutine.yield()
	log:warn({out = "......co_write was resumed", rc=rc or "nil"})
	if rc == nil and errmsg == "closed" then
		self:__close()
	end
	return rc

end

-- TODO: 
function coluasocket:close()
end

local is_first_time = true
local n=0
local function step_scheduler()
	-- load listen coroutines
	if is_first_time then
		is_first_time = false
		log:debug("enter main loop")
	end
	n=n+1
	
	-- run once only
	local r_set = {}
	local w_set = {}
	-- step(1): prepare r_set,w_set
	for k, v in pairs(s_maps) do
		log:debug({k, v})
		if (v.is_listen == true or v.r_queue ~= nil) then
			table.insert(r_set, v.socket)
		end
		if (v.is_connecting == true or (v.w_queue ~= nil and #v.w_queue > 0)) then
			table.insert(w_set, v.socket)
		end
	end

	-- step(2): select
	log:info({r_set_size = #r_set, w_set_size = #w_set, rset=r_set[1], count=n})
	for i, s in ipairs(r_set) do
		log:debug({event=string.format("r_set[%d]", i), s=s})
	end
	if (#r_set > 0 or #w_set > 0) then
		local readable, writeable, msg = socket.select(r_set, w_set, nil)

		--log:debug(readable)
		-- step(3): process read event
		for _, s in ipairs(readable) do
			log:debug(s)
			local o = s_maps[s]
			assert(o.socket == s)
            -- step(3.1): accept
            if (o.is_listen) then
            	local fd,errmsg = s:accept()
            	log:debug({server=s, client=fd or "nil",error=errmsg or "nil", err=msg or "nil"})
            	assert(fd)
            	fd:settimeout(0)
            	log:debug({"accept new connection, will resume accept coroutine",o.co})
				--coroutine.resume(o.co, fd)
				coutils.resume_coroutine(o.co, fd)
			end

            -- step(3.2): read
            if (o.r_queue ~= nil) then
            	log:debug({s=s or "nil"})
            	local data, errmsg, partial = s:receive(MTU_SIZE)
            	if (data == nil) then
            		log:debug({errmsg=errmsg or "nil", data=data or "nil", partial=partial or "nil", o=o})
                    -- read partial data
                    if data == nil and partial ~= nil then
                    	table.insert(o.r_queue, partial)
                    end
                    if (data == nil and errmsg == "closed") then
                    	log:debug({socket_is_closed=true, will_resume_read_co=o, co_status=coroutine.status(o.co) or "nil"})
						--coroutine.resume(o.co, nil, "closed")
						coutils.resume_coroutine(o.co, nil, "closed")
						elseif (data == nil and errmsg == "timeout") then
                        -- TODO: optimize the code
                        log:info({msg="resume with partial data", o=o, status=coroutine.status(o.co)})
                        --debug.debug()
                        local rc, comsg = coutils.resume_coroutine(o.co, true, nil)
						--coroutine.resume(o.co, true, nil)
						log:info({msg="resume return", rc = rc or "nil", comsg=comsg or "nil"})
					end
				else
					log:debug({will_resume_read_co=o})
					table.insert(o.r_queue, data)
					log:debug(o)
					coutils.resume_coroutine(o.co, true,nil)
				end
			end
		end

		-- step(4): process write event
		for _, s in ipairs(writeable) do
			local v = s_maps[s]

			-- step(4.1): handle connect event
			if (v.is_connecting) then
				log:debug({event="select.connect",server=s})
				log:debug({event="connect is success, will resume accept coroutine",v.co})
				--coroutine.resume(o.co, fd)
				coutils.resume_coroutine(v.co, true)
			end

			-- step(4.2): handle write event
			if (v.w_queue ~= nil and #v.w_queue > 0) then
				log:debug({will_resume_write_co=v,status=coroutine.status(v.co)})
				local rc, errmsg, partial_index = s:send(v.w_queue[1])
				--log:debug({send.rc=rc or "nil", msg=errmsg or "nil", partial_index=partial_index or "nil"})
				if (rc == nil) then
					log:debug({error=errmsg or "nil"})
					-- step(4.1): process remained data
					if (partial_index ~= nil) then
						local msg = v.w_queue[1]
						msg = string.byte(msg, partial_index+1, string.len(msg))
						table.remove(1)
						table.insert(v.w_queue, 1, msg)
					end

					if (errmsg == "closed") then
						-- tell client the socket was closed
						coutils.resume_coroutine(v.co, false,errmsg)
						elseif (errmsg == "timeout") then 
							coutils.resume_coroutine(v.co, true, errmsg)
						end
				else -- write success, remove sent data from queue
					table.remove(v.w_queue, 1)
					coutils.resume_coroutine(v.co, true,errmsg)
				end
			end
		end
	end

end

coscheduler.register_step_scheduler("coluasocket", step_scheduler)
