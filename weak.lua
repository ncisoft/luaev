local tbl={}

local tbl_ref = {__mode="kv"}
--setmetatable(tbl, tbl_ref)

tbl.sss = {name="leeyg", age=40}
tbl.sss = nil

for k,v in pairs(tbl) do
	print(v)
end
