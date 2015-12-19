local coscheduler = require("coscheduler")
local comessages = require("comessage")
local coroutine = require("coroutine")
local coutils = require("coutils")
local cosocket = require("coluasocket")
local lanes = require "lanes"
lanes.configure({with_timers = false})
luaproc = require "luaproc"
local base = _G
--trace = require("trace")
require("strict")

local log = coutils.new_logger()

--base.jit.opt.start(2)

local function client_loop(client, userdata)
	log:warn({"co_client was resumed", client, coroutine.running()})
	log:warn("new client was accepted, userdata="..(userdata or "nil"))
	coscheduler.detache()
	while true do
		local msg, err, rc = client:read()
		if msg == nil and err == "closed" then
			log:warn("co_client was closed, the coroutine is going to dead")
			return
		end
		log:debug({out="client read messages: ", msg=msg or "nil", err=err or "nil"})
		rc = string.find(msg, "PING")
		if rc == 1 then 
			msg = "PONG\r\n"
		end
		rc,err = client:write("+"..msg)
	end
end

local _linda = lanes.linda()

local client_thread = function (_linda)
--thread-begin
	print("------------------")
	local coscheduler = require("coscheduler")
	print("-----------------!!!!!!!!!!")
	local comessages = require("comessage")
	local coroutine = require("coroutine")
	local coutils = require("coutils")
	local socket = require("socketext")
	local cosocket = require("coluasocket")
	--local lanes = require "lanes"
	local base = _G
	--trace = require("trace")
	--require("strict")

	print("-----------------!!!!!!!!!!")
	local log = coutils.new_logger()

	local function _client_loop(client, userdata)
		log:warn({"co_client was resumed", client, coroutine.running()})
		log:warn("new client was accepted, userdata="..(userdata or "nil"))
		coscheduler.detache()
		while true do
			local msg, err, rc = client:read()
			if msg == nil and err == "closed" then
				log:warn("co_client was closed, the coroutine is going to dead")
				return
			end
			log:debug({out="client read messages: ", msg=msg or "nil", err=err or "nil"})
			rc = base.string.find(msg, "PING")
			if rc == 1 then 
				msg = "PONG\r\n"
			end
			rc,err = client:write("+"..msg)
		end
	end


	local co_new_client = coroutine.create(function()

		while true do
			log:debug("................,,,,,,")
			--local client_fd = _linda:receive(0, "client_fd")
			local client_fd = _luaproc.receive("chn", true)
			if client_fd ~= nil then
				log:info({event="new client", fd=client_fd})
				local client= cosocket.__init()
				client.s = socket.tcp(client_fd)
				local co_client = coroutine.wrap(_client_loop)
				co_client()
			else
				coroutine.yield()
			end
		end
		end)

	log:debug("................")

	coscheduler.join(co_new_client)
	coscheduler.loop()
--thread-end
end 

local function client_dispatcher(client,userdata)
	log:debug("................")
	coscheduler.detache()
	log:debug({event="send linda data", fd=client.s:getfd()})
	_linda:send("client_fd", client.s:getfd())
	--luaproc.send("chn", client.s:getfd())
	log:debug({event="send linda data", fd=client.s:getfd()})
	return
end
local co_listen = coroutine.create(function()
	log:info("co_listen was resume")
	coscheduler.detache()

	local listen_s = cosocket.listenTCP("*", 7070)
	base.assert(listen_s)
	while true do
		listen_s:accept(client_dispatcher, "kid")
	end

	end)


local th= lanes.gen("*", client_thread)
assert(th(_linda))
coscheduler.join(co_listen)
luaproc.newchannel("chn")
local client_thread_body = coutils.parse_thread_body()
luaproc.newproc(client_thread_body)

--os.exit()
--base.collectgarbage("stop")
coscheduler.loop()

log:fatal("exit");
