local socket = require("socket")
local string = require("string")
local table = require("table")
local coroutine = require("coroutine")
local logging = require("logging")
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
local setmetatable = setmetatable
local debug = debug
local arg = arg
local base = _G

module("coutils") 

DEBUG = logging.DEBUG
INFO = logging.INFO
WARN = logging.WARN
ERROR = logging.ERROR
FATAL = logging.FATAL

local global_log_level = nil

function set_global_log_level(level)
	assert(level ~= nil)
	global_log_level = level
end

function __init_object(class)
	return setmetatable({}, {__index=class})
end

function new_logger(log_level)
	log_level = log_level or DEBUG
	local log = logging.new(function(self, level, message) 
		local info = debug.getinfo(4)
		local is_windows = os.getenv("windir") and true
		local color_map = {}
		color_map[ logging.DEBUG ] =  ""
		color_map[ logging.INFO ] =  colors.yellow
		color_map[ logging.WARN ] =  colors.cyan
		color_map[ logging.ERROR ] =  colors.red
		--	if (false and level ~= logging.DEBUG) then
		if (info.currentline ==163) then 
			local i, flag = 2, true
			while flag do
				i=i+1	
				print("....................."..i)
				info = debug.getinfo(i)
				if (info.currentline > 0) then
					flag = false
				elseif (info["source"] == "[C]") then 
					info = debug.getinfo(4)
					flag = false
				else
					for k,v in pairs(info) do
						print(k.."="..tostring(v))
					end
				end
			end
		end
		--info = debug.getinfo(4)

		local color = color_map [ level ] or ""
		local map = { info.short_src,":", info.name or "?", "():",info.currentline or "?"}
		if is_windows then
			print(level, table.concat(map),message) 
		else
			print(color, level, table.concat(map),message,colors.reset) 
		end
		return true 
	end)
	log:setLevel (global_log_level or log_level)
	return log
end

local log = new_logger()

function resume_coroutine(co, ... )
	local rc,message = coroutine.resume(co,...)
	if rc == false then
		log:error({co=co, status=coroutine.status(co), event = "resume coroutine fail", message = message or "nil"})
		log:error(debug.traceback(co))
	end
	return rc, message
end
