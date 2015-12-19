local table = require("table")
local coutils = require("coutils")
local os = os
local table = table
local string = string
local debug = debug
local collectgarbage = collectgarbage
local base = _G

module("copool")

local copool = {}
local log = coutils.new_logger(coutils.DEBUG)

function new()
	self = coutils.__init_object(copool)
	self.free_cos = {}
	return self
end

function copool:pcreate(f)
	local cos, available
	if self.free_cos[f] == nil then
		self.free_cos[f] = {}
	end
	cos = self.free_cos[f]
	if #cos > 0 then
		available = cos[#cos]
		table.remove(cos)
		return available
	end
	available = base.coroutine.create(function ( ... )
		local arg = {...}
		local this_co = base.coroutine.running()
		while true do
			local rc, message = base.pcall(f, base.unpack(arg))
			if (rc == true) then
				-- recycle the coroutine
				table.insert(cos, this_co)
				arg = {base.coroutine.yield()}
			else
				-- the coroutine is dead
				log:error({co=this_co, status=base.coroutine.status(this_co), event = "coroutine running fail", message = message or "nil"})
				return rc,message
			end
		end
	end)
	return available
end

function copool:create(f)
	local cos, available
	if self.free_cos[f] == nil then
		self.free_cos[f] = {}
	end
	cos = self.free_cos[f]
	if #cos > 0 then
		available = cos[#cos]
		table.remove(cos)
		return available
	end
	available = base.coroutine.create(function ( ... )
		local arg = {...}
		local this_co = base.coroutine.running()
		while true do
			f()
				-- recycle the coroutine
				base.table.insert(cos, this_co)
				arg = {base.coroutine.yield()}
		end
	end)
	return available
end
