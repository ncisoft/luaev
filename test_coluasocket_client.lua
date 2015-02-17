local coscheduler = require("coscheduler")
local comessages = require("comessage")
local coroutine = require("coroutine")
local coutils = require("coutils")
local cosocket = require("coluasocket")
local debug = debug
--trace = require("trace")
require("strict")

local log = coutils.new_logger()
coutils.set_global_log_level( coutils.FATAL)
--print(logging.FATAL)

local co_connect = coroutine.create(function()
	log:info("co_connect was resume")
	coscheduler.detache()

	local connect_s = cosocket.connectTCP("127.0.0.1", 7070)
	assert(connect_s)
	while true do
		local rc,err,msg = connect_s:write("hello")
		log:debug({event="read data", rc=rc or "nil", err=err or "nil"})
		msg, err, rc = connect_s:read()
		if msg == nil and err == "closed" then
			log:warn("co_client was closed, the coroutine is going to dead")
			return
		end
		log:debug({out="client read messages: ", msg=msg or "nil", err=err or "nil"})
		--debug.debug()
	end

	end)


coscheduler.join(co_connect)
coscheduler.loop()

log:fatal("exit");
