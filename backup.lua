		for _, s in ipairs(writeable) do
			local v = s_maps[s]
			if (v.w_queue ~= nil and #v.w_queue > 0) then
				log:debug({will_resume_write_co=v})
				local rc, errmsg, partial_index = s:send(v.w_queue[1])
				--log:debug({send.rc=rc or "nil", msg=errmsg or "nil", partial_index=partial_index or "nil"})
				if (rc == nil) then
					log:debug({error=errmsg or "nil"})
					-- step(4.1): process remained data
					if (partial ~= nil) then
						local msg = v.w_queue[1]
						msg = string.byte(msg, partial+1, strlen(msg))
						table.remove(1)
						table.insert(v.w_queue, 1, msg)
					end

					if (errmsg = "closed") then
						-- tell client the socket was closed
						coroutine.resume(v.co, false,errmsg)
					elseif (errormsg == "timeout") then 
						coroutine.resume(v.co, true, errmsg)
					end
				else -- write success, remove sent data from queue
					table.remove(v.w_queue, 1)
					coroutine.resume(v.co, true,errmsg)
				end
			end
		end
	end -- end of loop

