luaproc = require "luaproc"
local lanes = require "lanes"
lanes.configure({with_timers = false})

-- create an additional worker
luaproc.setnumworkers( 2 )
	
local function test(name)
	print("hellokkk "..name)
end

function client_thread()
  return [[
  local io =  require 'io'
  luaproc.send("chn", 123)
  print("xxxx")
  io.write("aaaa\n")
  ]]
end
-- create a new lua process

local x = string.dump(test)

luaproc.newchannel("chn")
luaproc.newproc(client_thread())
yy = luaproc.receive("chn")
local str = "--thread-end\n"
local i,j = string.find(str, "thread%-end")
print(i,j)
print(yy)

local th= lanes.gen("*", test)
th("leeyg")