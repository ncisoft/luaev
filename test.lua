local coscheduler = require("coscheduler")
local comessages = require("comessage")
local coroutine = require("coroutine")
local coutils = require("coutils")
local print = print

local log = coutils.new_logger()
local co_buyer = coroutine.create(function()
	log:info("co_buyer was resume")
	local me = comessages.new_mailbox("buyer")

	coscheduler.detache()
	log:info("222")
	me:sendto("seller", "how much")
	local sender_id, msg
	log:info("333")

	sender_id,msg = me:receive()
	print(msg)
end)

local co_seller = coroutine.create(function()
	log:info("co_seller was resume")
	local me = comessages.new_mailbox("seller")
	local sender_id, msg

	log:debug(me)
	coscheduler.detache()
	sender_id,msg = me:receive()
	me:sendto(sender_id, "99 dollars")
	print(msg)
end)

coscheduler.join(co_buyer)
coscheduler.join(co_seller)
coscheduler.loop()

log:fatal("exit");
