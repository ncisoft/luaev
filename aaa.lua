local coscheduler = require("coscheduler")
local comessages = require("comessage")
local coroutine = require("coroutine")
local coutils = require("coutils")
local coutils_ext = require("coutils_ext")
local debug = debug
local base = _G
--trace = require("trace")
require("strict")

local log = coutils.new_logger(coutils.DEBUG)

function test()
	return 1,2,3,4,5,6
	
end

rargs = {test()}
--rargs = {1,2,3,4,5,6}
log:debug({xx=rargs})
log:debug("aa")

local n = 0
function co_f(x)
	--log:debug({co=base.coroutine.running(), n=n, x=x})
	--x = x*x
	n=n+1
end
local max,t = 200000

function ordinary_test()

end


	base.collectgarbage("collect")
base.collectgarbage("stop")
	log:fatal({event="collectgarbage.count", out=base.collectgarbage("count"), count=n})
	t = base.os.clock()
	for i=1, max do
		local co = base.coroutine.create(co_f)
		base.coroutine.resume(co, i*10)
	end
	print("\ttime[ordinary]="..(base.os.clock() - t))
	log:fatal({event="collectgarbage.count", out=base.collectgarbage("count"), count=n})
	print("")


base.collectgarbage("collect")
base.collectgarbage("stop")
log:fatal({event="collectgarbage.count", out=base.collectgarbage("count"), count=n})
t = base.os.clock()
for i=1, max do
	local co = coutils_ext.create_coroutine(co_f)
	base.coroutine.resume(co, i*10)
end
print("\ttime[pool]="..(base.os.clock() - t))
log:fatal({event="collectgarbage.count", out=base.collectgarbage("count"), count=n})
print("")

base.collectgarbage("stop")
base.collectgarbage("collect")
log:fatal({event="collectgarbage.count", out=base.collectgarbage("count"), count=n})
t = base.os.clock()
for i=1, max do
	co_f(i*10)
end
print("\ttime[direct call]="..(base.os.clock() - t))
log:fatal({event="collectgarbage.count", out=base.collectgarbage("count"), count=n})
print("")
