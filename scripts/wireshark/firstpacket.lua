-- Usage: tshark -r ${CAPTURE_FILE} -X lua_script:firstpacket.lua
local lastTime = nil

do
	function scriptprint(message)
	        print("firstpacket.lua: " .. message)
	end

	-- frame
	local frame_time = Field.new("frame.time")
	local frame_number = Field.new("frame.number")
	local frame_len = Field.new("frame.len")
	local frame_epochtime = Field.new("frame.time_epoch")

	-- tcp
	local tcp_dstport = Field.new("tcp.dstport")
	local tcp_srcport = Field.new("tcp.srcport")
	local tcp_stream = Field.new("tcp.stream")
	local tcp_pdu_size = Field.new("tcp.pdu.size")
	local tcp_flags_syn = Field.new("tcp.flags.syn")
	local tcp_flags_ack = Field.new("tcp.flags.ack")
	local tcp_flags_rst = Field.new("tcp.flags.reset")
	local tcp_flags_fin = Field.new("tcp.flags.fin")

	-- ipv4
	local ip_dst = Field.new("ip.dst")
	local ip_src = Field.new("ip.src")
	
	local streams = {}

	local function init_listener()
		local tap = Listener.new("tcp")
		function tap.reset()
			-- print("tap reset")
		end
		
		function tap.packet(pinfo,tvb)
			local dstport = tcp_dstport()
			local srcport = tcp_srcport()
			local frametime = tostring(frame_time())
			local frameepochtime = tonumber(tostring(frame_epochtime()))
			local framenumber = tonumber(tostring(frame_number()))
			local ipdst = ip_dst()
			local ipsrc = ip_src()
			local stream = tonumber(tostring(tcp_stream()))
			local flagssyn = tonumber(tostring(tcp_flags_syn()))
		        local flagsack = tonumber(tostring(tcp_flags_ack()))
		        local flagsrst = tonumber(tostring(tcp_flags_rst()))
		        local flagsfin = tonumber(tostring(tcp_flags_fin()))
		        
		        scriptprint("First packet time: " .. frametime)
		        os.exit(0)
		end
		
		function scripterror(stream, machine, message, curtime, curframe)
		        scriptalert("ERROR", stream, machine, message, curtime, curframe)
		end
		
		function scriptwarning(stream, machine, message, curtime, curframe)
		        scriptalert("WARNING", stream, machine, message, curtime, curframe)
		end
		
		function scriptalert(alert, stream, machine, message, curtime, curframe)
		        scriptprint(alert .. ": " .. message .. ". First SYN sent: " .. machine.time .. ", Stream " .. stream .. ", Frame: " .. machine.frame .. ", Source: " .. machine.source .. ", Destination: " .. machine.destination .. ", Current frame time: " .. curtime .. " (Frame: " .. curframe .. ")")
		end

		function tap.draw()
		end
	end
	
	init_listener()
end

