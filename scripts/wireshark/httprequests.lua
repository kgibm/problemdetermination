do
	print("LUA HTML script loaded")
	-- frame
	local frame_time = Field.new("frame.time")
	local frame_number = Field.new("frame.number")
	local frame_len = Field.new("frame.len")

	-- tcp
	local tcp_dstport = Field.new("tcp.dstport")
	local tcp_srcport = Field.new("tcp.srcport")
	local tcp_stream = Field.new("tcp.stream")
	local tcp_pdu_size = Field.new("tcp.pdu.size")

	-- ipv4
	local ip_dst = Field.new("ip.dst")
	local ip_src = Field.new("ip.src")

	-- http
	local http_method = Field.new("http.request.method")
	local http_uri = Field.new("http.request.uri")
	local http_host = Field.new("http.host")
	local http_response_code = Field.new("http.response.code")
	local http_response_phrase = Field.new("http.response.phrase")
	local function init_listener()
		local tap = Listener.new("http")
		function tap.reset()
			print("tap reset")
		end
		function tap.packet(pinfo,tvb)
		        print("tap packet")
			-- some of these will be nil
			local method = http_method()
			local dstport = tcp_dstport()
			local srcport = tcp_srcport()
			local frametime = frame_time()
			local uri = http_uri()
			local host = http_host();
			local phrase = http_response_phrase()
			local response_code = http_response_code()
			local ipdst = ip_dst()
			local ipsrc = ip_src()
			local stream = tcp_stream()

			if method ~= nil then
				printpref(frametime, ipsrc, ipdst, srcport, dstport, stream)
				print("HTTP Request:  " .. tostring(method) .. " " .. tostring(host) .. tostring(uri))
			end
			if response_code ~= nil then
				printpref(frametime, ipsrc, ipdst, srcport, dstport, stream)
				print("HTTP Response: " .. tostring(response_code) .. " " .. tostring(phrase))
			end
		end
		function tap.draw()
			print("tap.draw")
		end
		function printpref(frametime, ipsrc, ipdst, srcport, dstport, stream)
			io.write("[" .. tostring(frametime) .. " src:" .. tostring(ipsrc) .. ":" .. tostring(srcport) .. " dst:" .. tostring(ipdst) .. ":" .. tostring(dstport) .. " stream:" .. tostring(stream) .. "] ")
		end
	end
	init_listener()
end

