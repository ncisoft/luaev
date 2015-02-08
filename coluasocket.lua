local socket = require("socket")
local string = require("string")
local table = require("table")
local os = os
local ipairs = ipairs
local assert = assert
local print = print
local type = type
local tostring = tostring
local base = _G

module("cosocket")
local cosocket = {} -- the table representing the class, which will double as the metatable for the instances
--Mailbox.__index = Mailbox -- failed table lookups on the instances should fallback to the class table, to get methods


local DEFAULT_BACKLOG = 32

-- @return cosocket
local function listenTCP(addr, port, backlog)
	local self = setmetatable({}, {__index=cosocket})
	self.addr = addr or "*"
	self.backlog = backlog or DEFAULT_BACKLOG
end

-- @return cosocket
--
function create(co, socket)
	self.co = co
	self.socket = socket
	return self
end

-- @return cosocket
--
function connect(addr, port)
end

local function cosocket:read()
end

local function write(data)
	self.socket:send(data)
	coroutine.yield(self.co, self.co, self.socket )
end

local function close()
end


