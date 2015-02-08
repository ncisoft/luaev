local socket = require("socket")
local string = require("string")
local table = require("table")
local coroutine = require("coroutine")
local logging = require("logging")
local coutils = require("coutils")
local term   = require 'term'
local colors = term.colors -- or require 'term.colors'
local strict = require("strict")
local os = os
local ipairs = ipairs
local pairs = pairs
local assert = assert
local print = print
local type = type
local tostring = tostring
local unpack = unpack
local debug = debug
local arg = arg
local base = _G

-- purpose: will handle with socket_coroutine, file_coroutine, timer_coroutine, ordinary_coroutine

module("coscheduler")

local log = coutils.new_logger()
local co_set = {}
local __co_detached_array = {}
local __schedulers = {}



-- attache/join a coroutine object to be managed
-- @return void
-- @param co coroutine object
-- @param ... args to be passed to coroutine.resume

-- detache
function attache(co, ...)
	assert(co)
	log:debug({co=co, msg="was joined"})
	co_set[co] = arg
end

join = attache 

function detache(co)
	co = co or coroutine.running()
	table.insert(__co_detached_array, co)	
end


-- private method
-- 
local function __detache(co)
	assert(co ~= nil)
	if (co_set[co] ~= nil) then
		co_set[co] = nil
	end
end

function register_step_scheduler(name, step_func)
	assert(name ~= nil and type(step_func) == "function")
	__schedulers[ name ] = step_func 	-- register once
end

function loop()
	local is_first_time = true

	while true do
		--log:debug("loop(co_set)")
		for co,args in pairs(co_set) do
			if is_first_time then
				log:info({co=co, status=coroutine.status(co)})
				base.coroutine.resume(co)--, unpack(args))
			else
				log:info({co=co, status=coroutine.status(co)})
				base.coroutine.resume(co)
			end
			if coroutine.status(co) == "dead" then
				detache(co)
			end
		end
		--log:debug("loop(detache)")
		for _,co in ipairs(__co_detached_array) do
			__detache(co)
		end
		is_first_time = false
		local n_scheduler, n_false = 0,0
		for scheduler, step in pairs(__schedulers) do
			n_scheduler = n_scheduler + 1
			if (step() == false) then
				n_false = n_false + 1
			end
		end
		if n_scheduler == n_false then
			return
		end
	end
end



