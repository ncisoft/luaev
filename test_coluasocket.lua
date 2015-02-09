local coscheduler = require("coscheduler")
local comessages = require("comessage")
local coroutine = require("coroutine")
local coutils = require("coutils")
local cosocket = require("coluasocket")
trace = require("trace")
require("strict")

local log = coutils.new_logger()

local function client_loop(client, userdata)
	log:warn({"co_client was resumed", client})
	log:warn("new client was accepted".."userdata="..(userdata or "nil"))
	coscheduler.detache()
	while true do
		local msg = client:read()
		log:debug({"client read messages: ", msg})
		client:write("+"..msg)
	end
end

local co_listen = coroutine.create(function()
	log:info("co_listen was resume")
	coscheduler.detache()

	local listen_s = cosocket.listenTCP("*", 7070)
	assert(listen_s)
	while true do
		listen_s:accept(client_loop, "kid")
	end

end)


coscheduler.join(co_listen)
coscheduler.loop()

log:fatal("exit");
