local socket = require("socket")
local string = require("string")
local table = require("table")
local coroutine = require("coroutine")
local coscheduler = require("coscheduler")
local coutils = require("coutils")
local os = os
local ipairs = ipairs
local pairs = pairs
local assert = assert
local print = print
local type = type
local tostring = tostring
local setmetatable = setmetatable
local base = _G

module("comessage")

local log = coutils.new_logger()
local messages =  {}			-- map: (receiver_id, msg)
local suspent_coroutines = {} 	-- map: (id, co)

local Mailbox = {} -- the table representing the class, which will double as the metatable for the instances
--Mailbox.__index = Mailbox -- failed table lookups on the instances should fallback to the class table, to get methods

local function new_message(sender_id, body)
	self = {}
	self.sender_id = sender_id
	self.body = body
	return self
end

function new_mailbox(my_id)
	local self = setmetatable({}, {__index=Mailbox})
	assert(my_id ~= nil)
	self.id = my_id
	return self
end

function Mailbox:sendto(receiver_id, msg_body)
	log:debug({sendto=self})
	local _msg = new_message(self.id, msg_body)
	assert(receiver_id ~= nil and msg_body ~= nil)
	if messages[ receiver_id] == nil then
		messages[ receiver_id] = { _msg }
	else
		table.insert(messages[ receiver_id], _msg)
	end

	-- will suspend until receiver get the message
end

function Mailbox:receive()
	log:warn("receive was call, myid="..(self.id or "nil"))
	suspent_coroutines[ self.id ] = coroutine.running()
	local sender_id, msg = coroutine.yield()
	return sender_id, msg
--suspent_coroutines 
end

local function step_scheduler()
	local rc = false
	for receiver_id, co in pairs(suspent_coroutines) do
		local mailbox = messages[receiver_id]
		if (mailbox ~= nil) then 
			local msg = mailbox[1]
			log:debug({msg=msg})
			table.remove(mailbox, 1) 
			if (#mailbox == 0) then
				messages[receiver_id] = nil
			end

			coroutine.resume(co, msg.sender_id, msg.body)
			rc = true
		end
	end
	return rc
end

coscheduler.register_step_scheduler("comessage", step_scheduler)
