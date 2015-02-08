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

local DEFAULT_BACKLOG = 32
local function listenTCP(addr, port, backlog)
	addr = addr or "*"
	backlog = backlog or DEFAULT_BACKLOG
end

local function create(co, socket)
	self.co = co
	self.socket = socket
	return self
end

local function connect(addr, port)
end

local function read()
end

local function write(data)
	self.socket:send(data)
	coroutine.yield(self.co, self.co, self.socket )
end

local function close()
end


