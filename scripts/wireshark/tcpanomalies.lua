-- Usage: tshark -q -r ${CAPTURE_FILE} -X lua_script:tcpanomalies.lua
-- 
-- tcpanomalies.lua: Find all TCP streams and:
--  1) Print the time it takes for a response to a SYN (either direction). Modify minSynResponseDelta in script to only print those longer than X seconds,
--  2) Print an ERROR if the response to a SYN is not SYNACK (e.g. RST),
--  3) Print an ERROR if a SYN is sent on the same stream without a response to a previous SYN,
--  4) Print a WARNING if a SYN does not receive a response by the end of the capture (only warning because capture may have ended right before a legitimate response).
-- Notes:
--  1) We look at each 4-tuple of (source IP, source port, destination IP, destination port) - Wireshark calls this a "stream" and conveniently numbers each tuple uniquely for us (tcp.stream),
--  2) By default, we suppress the warning if the script finds packets on a stream without a previous SYN as these are probably at the start of the capture.
--  3) Only works on a single file, so use mergecap to merge rolling files together. (Note: DO NOT merge captures from different machines.)
--
-- Example:
-- $ tshark -q -r http1-rstnoack.pcap -X lua_script:tcpanomalies.lua
-- tcpanomalies.lua: Started
-- tcpanomalies.lua: First packet time: "Mar 22, 2014 07:08:36.967090000 PDT"
-- tcpanomalies.lua: ===================================
-- tcpanomalies.lua: ERROR: Received RST in response to SYN after 2.4080276489258e-05 seconds. First SYN sent: "Mar 22, 2014 07:08:36.967090000 PDT", Stream 0, Frame: 1, Source: nil:36016, Destination: nil:80,  frame time: "Mar 22, 2014 07:08:36.967114000 PDT" (Frame: 2)
-- tcpanomalies.lua: WARNING: Stream 1 did not get a response by the end of the capture. First SYN sent: "Mar 22, 2014 07:08:36.967251000 PDT", Stream 1, Frame: 3, Source: 127.0.0.1:45317, Destination: 127.0.0.1:80, Current frame time:  (Frame: )
-- tcpanomalies.lua: ===================================
-- tcpanomalies.lua: Last packet time: "Mar 22, 2014 07:08:36.967251000 PDT"
-- tcpanomalies.lua: Finished

local suppressMissingHandshake = true

-- Update this to search for long SYN response times. In seconds, e.g. .0000250
local minSynResponseDelta = 1

-- Update this to search for gaps between packets after the handshake. In seconds, e.g. .0000250
local minDiffDelta = 0

-- Whether to warn on a suspected TCP retransmission frame
local warnSuspectedRetransmission = true

-- Whether to warn on a suspected TCP retransmission frame
local suspectedRetransmissionsCount = 0

-- If true, check if messages are GIOP and print response time statistics.
local checkGIOP = false

-- If checkGIOP=true, update this to search for gaps between GIOP requests and replies. In seconds, e.g. .0000250
local minGIOPDiffDelta = .01

local tcpHandshakes = 0

local giopStats = {
  messageCount = 0,
  messageMin = -1,
  messageMax = -1,
  messageSum = 0,
  locateMessageCount = 0,
  locateMessageMin = -1,
  locateMessageMax = -1,
  locateMessageSum = 0
};

-- If true, check if messages are WXSXIO and print response time statistics.
local checkXIO = false

-- If checkXIO=true, update this to search for gaps between XIO requests and replies. In seconds, e.g. .0000250
local minXIODiffDelta = .01

local xioStats = {
  messageCount = 0,
  messageMin = -1,
  messageMax = -1,
  messageSum = 0
};

-- Internal variable
local lastTime = nil

do
  function scriptprint(message)
    print("tcpanomalies.lua: " .. message)
  end

  scriptprint("Started tcpanomalies.lua")

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
  local tcp_retransmit = Field.new("tcp.analysis.retransmission")

  -- ipv4
  local ip_dst = Field.new("ip.dst")
  local ip_src = Field.new("ip.src")

  -- giop
  local giop_message_type = Field.new("giop.type")
  local giop_request_id = Field.new("giop.request_id")

  -- wxsxio
  local wxsxio_message_type = Field.new("wxsxio.messagetype")
  local wxsxio_senderrefid = Field.new("wxsxio.senderrefid")
  local wxsxio_senderrefindex = Field.new("wxsxio.senderrefindex")
  local wxsxio_senderrefendpointid = Field.new("wxsxio.senderrefendpointid")
  local wxsxio_targetrefid = Field.new("wxsxio.targetrefid")
  local wxsxio_targetrefindex = Field.new("wxsxio.targetrefindex")
  local wxsxio_targetrefendpointid = Field.new("wxsxio.targetrefendpointid")

  local streams = {}
  local giopRequests = {}
  local wxsxioRequests = {}

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
      local isretransmit = tobool(tcp_retransmit())

      if lastTime == nil then
        scriptprint("First packet time: " .. frametime)
        scriptprint("===================================")
      end
      lastTime = frametime

      local machine = streams[stream]

      -- First check if this is a new connection: SYN and not ACK
      if flagssyn == 1 and flagsack == 0 then

        -- Check if there's any previous machine state
        if machine ~= nil then
          if machine.state == 1 then
            scripterror(stream, machine, "Never received SYN response before a new SYN", frametime, framenumber)
          end
        end

        streams[stream] = {
          frame = framenumber,
          time = frametime,
          source = tostring(ipsrc) .. ":" .. tostring(srcport),
          destination = tostring(ipdst) .. ":" .. tostring(dstport),
          start = frameepochtime,
          state = 1,
          lastpackettime = frameepochtime,
          lastpacketframe = framenumber,
          lastpacketdatetime = frametime,
          lastGIOP = -1,
          lastGIOPFrame = nil,
          lastGIOPtime = nil
        };
      else
        -- Otherwise, use the state machine

        if machine ~= nil then

          if machine.state == 1 then
            -- Only have a SYN so far, so we expect this to be a SYN ACK
            local diff = frameepochtime - machine.start
            if flagsack == 1 and flagssyn == 1 then
              if diff >= minSynResponseDelta then
                postsyn(stream, machine, "SYNACK", frametime, framenumber, diff)
              end
	      tcpHandshakes = tcpHandshakes + 1
              machine.state = 2
            elseif flagsrst == 1 then
              if diff >= minSynResponseDelta then
                scripterror(stream, machine, "Received RST in response to SYN after " .. string.format("%f", diff) .. " seconds", frametime, framenumber)
              end
              machine.state = 2
            elseif flagsfin == 1 then
              scriptwarning(stream, machine, "Received FIN in response to SYN after " .. string.format("%f", diff) .. " seconds", frametime, framenumber)
              machine.state = 2
            else
              scripterror(stream, machine, "Expected SYNACK or RST, instead got frame " .. framenumber .. " after " .. string.format("%f", diff) .. " seconds", frametime, framenumber)
              machine.state = 3
            end
          elseif machine.state == 3 then
            -- This state means that we've already reported an error on this stream, so we only report the first error
          else
            -- Check for delta between any other two packets
            checkDiff(machine.lastpackettime, frameepochtime, minDiffDelta, "frames", stream, machine, framenumber, frametime)

            machine.lastpackettime = frameepochtime
            machine.lastpacketframe = framenumber
            machine.lastpacketdatetime = frametime
          end

          checkpacket(stream, machine, framenumber, frametime, isretransmit)

        else
          -- We haven't seen a handshake on this stream, but we track it anyway to find packet diffs
          streams[stream] = {
            state = -1,
            lastpackettime = frameepochtime,
            lastpacketframe = framenumber,
            lastpacketdatetime = frametime,
            lastGIOP = -1,
            lastGIOPFrame = nil,
            lastGIOPtime = nil
          };
          machine = streams[stream]
          if not suppressMissingHandshake then
            scriptwarning(stream, nil, "Frame " .. framenumber .. " did not have matching SYN", frametime, framenumber)
          end

          checkpacket(stream, nil, framenumber, frametime, isretransmit)

        end
      end

      if checkXIO then
	local wxsxioMessageTypeObj = wxsxio_message_type()
	if wxsxioMessageTypeObj ~= nil then
	  local wxsxio_senderrefidObj = wxsxio_senderrefid()
	  local wxsxio_targetrefidObj = wxsxio_targetrefid()
	  if wxsxio_senderrefidObj ~= nil and wxsxio_targetrefidObj ~= nil then
	    local senderrefid = tonumber(tostring(wxsxio_senderrefidObj))
	    local senderrefindex = tonumber(tostring(wxsxio_senderrefindex()))
	    local senderrefendpointid = tostring(wxsxio_senderrefendpointid())
	    local map1 = wxsxioRequests[senderrefid]
	    if map1 == nil then
	      wxsxioRequests[senderrefid] = {}
	    end
	    local map2 = wxsxioRequests[senderrefid][senderrefindex]
	    if map2 == nil then
	      wxsxioRequests[senderrefid][senderrefindex] = {}
	    end
	    wxsxioRequests[senderrefid][senderrefindex][senderrefendpointid] = {
	      requestFrame = framenumber,
	      requestTime = frameepochtime
	    };
	    print("Request," .. framenumber .. "," .. frameepochtime .. "," .. senderrefid .. "," .. senderrefindex .. "," .. senderrefendpointid)
          elseif wxsxio_targetrefidObj ~= nil then
	    local targetrefid = tonumber(tostring(wxsxio_targetrefidObj))
	    local targetrefindex = tonumber(tostring(wxsxio_targetrefindex()))
	    local targetrefendpointid = tostring(wxsxio_targetrefendpointid())
	    local request = wxsxioRequests[targetrefid]
	    print("Response," .. framenumber .. "," .. frameepochtime .. "," .. targetrefid .. "," .. targetrefindex .. "," .. targetrefendpointid)
	    if request ~= nil then
	      request = request[targetrefindex]
	    end
	    if request ~= nil then
	      request = request[targetrefendpointid]
	    end
	    if request ~= nil then
	      local diff = checkDiff(request.requestTime, frameepochtime, minXIODiffDelta, "WXSXIO request and response frames", stream, machine, framenumber, frametime)
	      xioStats.messageCount = xioStats.messageCount + 1
	      xioStats.messageSum = xioStats.messageSum + diff
	      if xioStats.messageMin == -1 then
		xioStats.messageMin = diff
	      elseif diff < xioStats.messageMin then
		xioStats.messageMin = diff
	      end
	      if xioStats.messageMax == -1 then
		xioStats.messageMax = diff
	      elseif diff > xioStats.messageMin then
		xioStats.messageMax = diff
	      end
	    end
	  end
	end
      end

      if checkGIOP then
        local giopTypeObj = giop_message_type()
        if giopTypeObj ~= nil then
          local giopType = tonumber(tostring(giopTypeObj))
          local giopRequestIdObj = giop_request_id()
          if giopRequestIdObj ~= nil then
            local giopRequestId = tonumber(tostring(giop_request_id()))

            -- Request or Fragment
            if giopType == 0 or giopType == 7 then
              -- We only care about the first fragment
              local giopRequest = giopRequests[giopRequestId]
              if giopRequest == nil then
                giopRequests[giopRequestId] = {
                  lastGIOP = giopType,
                  lastGIOPFrame = framenumber,
                  lastGIOPtime = frameepochtime
                };
              end

            -- Reply
            elseif giopType == 1 then
              -- Check for delta between request and reply messages
              local giopMachine = giopRequests[giopRequestId]
              if giopMachine ~= nil then
                local diff = checkDiff(giopMachine.lastGIOPtime, frameepochtime, minGIOPDiffDelta, "GIOP request and reply frames", stream, machine, framenumber, frametime)
                giopMachine.lastGIOP = -1
                giopStats.messageCount = giopStats.messageCount + 1
                giopStats.messageSum = giopStats.messageSum + diff
                if giopStats.messageMin == -1 then
                  giopStats.messageMin = diff
                elseif diff < giopStats.messageMin then
                  giopStats.messageMin = diff
                end
                if giopStats.messageMax == -1 then
                  giopStats.messageMax = diff
                elseif diff > giopStats.messageMin then
                  giopStats.messageMax = diff
                end
              else
                --scriptwarning(stream, machine, "Reply without a matching request for ID " .. giopRequestId, frametime, framenumber)
              end

            -- LocateRequest
            elseif giopType == 3 then
              giopRequests[giopRequestId] = {
                lastGIOP = giopType,
                lastGIOPFrame = framenumber,
                lastGIOPtime = frameepochtime
              };

            -- LocateReply
            elseif giopType == 4 then
              -- Check for delta between locate request and locate reply messages
              local giopMachine = giopRequests[giopRequestId]
              if giopMachine ~= nil then
                local diff = checkDiff(giopMachine.lastGIOPtime, frameepochtime, minGIOPDiffDelta, "GIOP locate request and locate reply frames", stream, machine, framenumber, frametime)
                giopMachine.lastGIOP = -1
                giopStats.locateMessageCount = giopStats.locateMessageCount + 1
                giopStats.locateMessageSum = giopStats.locateMessageSum + diff
                if giopStats.locateMessageMin == -1 then
                  giopStats.locateMessageMin = diff
                elseif diff < giopStats.locateMessageMin then
                  giopStats.locateMessageMin = diff
                end
                if giopStats.locateMessageMax == -1 then
                  giopStats.locateMessageMax = diff
                elseif diff > giopStats.locateMessageMin then
                  giopStats.locateMessageMax = diff
                end
              else
                scriptwarning(stream, machine, "LocateReply without a matching request for ID " .. giopRequestId, frametime, framenumber)
              end

            -- MessageError
            elseif giopType == 6 then
              scripterror(stream, machine, "GIOP Error Message", frametime, framenumber)
            else
              scriptwarning(stream, machine, "Unknown GIOP Message Type " .. giopType, frametime, framenumber)
            end
          else
            scripterror(stream, machine, "GIOP Message Does Not Have Request ID, message type " .. giopType .. " (0=Request,1=Reply,3=LocateRequest,4=LocateReply,6=MessageError,7=Fragment)", frametime, framenumber)
          end
        end
      end
    end
    
    function postsyn(stream, machine, response, responsetime, responseframe, diff)
      scriptprint("Stream " .. stream .. " received SYN response (" .. response .. ") after " .. diff .. " seconds. SYN sent: " .. machine.time .. " (Frame: " .. machine.frame .. "), Source: " .. machine.source .. ", Destination: " .. machine.destination .. ", Response time: " .. responsetime .. " (Frame: " .. responseframe .. ")")
    end
    
    function scripterror(stream, machine, message, curtime, curframe)
      scriptalert("ERROR", stream, machine, message, curtime, curframe)
    end
    
    function scriptwarning(stream, machine, message, curtime, curframe)
      scriptalert("WARNING", stream, machine, message, curtime, curframe)
    end
    
    function scriptalert(alert, stream, machine, message, curtime, curframe)
      if machine ~= nil and machine.time ~= nil then
        if curtime ~= nil then
          scriptprint(alert .. ": " .. message .. ". First SYN sent: " .. machine.time .. ", Stream " .. stream .. ", Frame: " .. machine.frame .. ", Source: " .. machine.source .. ", Destination: " .. machine.destination .. ", Frame time: " .. curtime .. " (Frame: " .. curframe .. ")")
        else
          scriptprint(alert .. ": " .. message .. ". First SYN sent: " .. machine.time .. ", Stream " .. stream .. ", Frame: " .. machine.frame .. ", Source: " .. machine.source .. ", Destination: " .. machine.destination)
        end
      else
        if curtime ~= nil then
          scriptprint(alert .. ": " .. message .. ". Stream " .. stream .. ", Frame time: " .. curtime .. " (Frame: " .. curframe .. ")")
        else
          scriptprint(alert .. ": " .. message .. ". Stream " .. stream)
        end
      end
    end

    function checkpacket(stream, machine, framenumber, frametime, isretransmit)
      if isretransmit then
	if warnSuspectedRetransmission then
	  scriptwarning(stream, machine, "Frame " .. framenumber .. " is a suspected retransmission", frametime, framenumber)
	end
	suspectedRetransmissionsCount = suspectedRetransmissionsCount + 1
      end
    end

    function tobool(x)
      if x ~= nil then
        return true
      else
        return false
      end
    end

    function checkDiff(timex, timey, threshold, checkType, stream, machine, framenumber, frametime)
      local diff = timey - timex
      if threshold > 0 and diff >= threshold then
        local passMachine = machine
        if machine.state == -1 then
          passMachine = nil
        end
        scriptwarning(stream, passMachine, "Time between " .. checkType .. " " .. machine.lastpacketframe .. " (" .. machine.lastpacketdatetime .. ") and " .. framenumber .. " (" .. frametime .. ") is " .. string.format("%f", diff) .. " seconds", frametime, framenumber)
      end
      return diff
    end

    function tap.draw()
      -- Check for any SYNs without a response
      for stream,machine in pairs(streams) do
        if machine.state == 1 then
          scriptwarning(stream, machine, "Stream " .. stream .. " did not get a response by the end of the capture", nil, nil)
        end
      end

      if lastTime ~= nil then
        scriptprint("===================================")
        scriptprint("Last packet time: " .. lastTime)
      end

      scriptprint("TCP handshakes: " .. tcpHandshakes)

      if suspectedRetransmissionsCount > 0 then
	scriptprint("WARNING: Suspected TCP retransmissions: " .. suspectedRetransmissionsCount)
      end

      if checkGIOP then
        scriptprint("===================================")
        scriptprint("GIOP Statistics")
        scriptprint("-----------------------------")
        scriptprint("GIOP Non-Locate Messages: " .. giopStats.messageCount)
        if giopStats.messageCount > 0 then
          scriptprint("GIOP Non-Locate Message Response Time Minimum (s): " .. giopStats.messageMin)
          scriptprint("GIOP Non-Locate Message Response Time Maximum (s): " .. giopStats.messageMax)
          scriptprint("GIOP Non-Locate Message Response Time Average (s): " .. (giopStats.messageSum / giopStats.messageCount))
        end
        scriptprint("GIOP Locate Messages: " .. giopStats.locateMessageCount)
        if giopStats.locateMessageCount > 0 then
          scriptprint("GIOP Locate Message Response Time Minimum (s): " .. giopStats.locateMessageMin)
          scriptprint("GIOP Locate Message Response Time Maximum (s): " .. giopStats.locateMessageMax)
          scriptprint("GIOP Locate Message Response Time Average (s): " .. (giopStats.locateMessageSum / giopStats.locateMessageCount))
        end
        scriptprint("===================================")
      end

      if checkXIO then
        scriptprint("===================================")
        scriptprint("XIO Statistics")
        scriptprint("-----------------------------")
        scriptprint("XIO Messages: " .. xioStats.messageCount)
        if xioStats.messageCount > 0 then
          scriptprint("XIO Message Response Time Minimum (s): " .. xioStats.messageMin)
          scriptprint("XIO Message Response Time Maximum (s): " .. xioStats.messageMax)
          scriptprint("XIO Message Response Time Average (s): " .. (xioStats.messageSum / xioStats.messageCount))
        end
        scriptprint("===================================")
      end

      scriptprint("Finished")
    end
  end

  init_listener()
end

