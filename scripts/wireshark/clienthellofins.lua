-- Usage: tshark -q -r $PCAP -X lua_script:clienthellofins.lua

local totalPackets = 0
local finsAfterClientHellos = 0
local firstTime = nil
local lastTime = nil
local countClientHellos = 0
local countServerHellos = 0

do
  function scriptprint(message)
    print("clienthellofins.lua: " .. message)
  end

  scriptprint("Started clienthellofins.lua")

  -- Fields we're using
  local frame_time = Field.new("frame.time")
  local frame_number = Field.new("frame.number")
  local tcp_stream = Field.new("tcp.stream")
  local tcp_flags_fin = Field.new("tcp.flags.fin")
  local handshakeType = Field.new("tls.handshake.type")

  local streams = {}

  local function init_listener()
    local tap = Listener.new("tcp")

    function tap.reset()
      -- print("tap reset")
    end

    function tap.packet(pinfo,tvb)
      local frametime = tostring(frame_time())
      local framenumber = tonumber(tostring(frame_number()))
      local stream = tonumber(tostring(tcp_stream()))
      local stateMachine = streams[stream]
      local handshakeTypeObj = handshakeType()

      totalPackets = totalPackets + 1
      if firstTime == nil then
        firstTime = frametime
      end
      lastTime = frametime

      if handshakeTypeObj ~= nil and tonumber(tostring(handshakeTypeObj)) == 1 then
        countClientHellos = countClientHellos + 1
        streams[stream] = {
          state = 1,
        };
      else
        if stateMachine ~= nil then
          if stateMachine.state == 1 then
            -- First we expect just an ACK to the client hello
            stateMachine.state = 2
          elseif stateMachine.state == 2 then
            -- Now check if this is a FIN
            if tostring(tcp_flags_fin()) == "True" then
              finsAfterClientHellos = finsAfterClientHellos + 1
              scriptwarning(stream, stateMachine, "FIN right after a Client Hello", frametime, framenumber)
            end
            stateMachine.state = 3
          elseif stateMachine.state == 3 then
            -- Nothing else to check on this stream
          end

          if handshakeTypeObj ~= nil and tonumber(tostring(handshakeTypeObj)) == 2 then
            countServerHellos = countServerHellos + 1
          end
        else
          -- Nothing to do as we haven't seen a Client Hello yet
        end
      end
    end
    
    function scripterror(stream, stateMachine, message, curtime, curframe)
      scriptalert("ERROR", stream, stateMachine, message, curtime, curframe)
    end
    
    function scriptwarning(stream, stateMachine, message, curtime, curframe)
      scriptalert("WARNING", stream, stateMachine, message, curtime, curframe)
    end
    
    function scriptalert(alert, stream, stateMachine, message, curtime, curframe)
      if curtime ~= nil then
        scriptprint(alert .. ": " .. message .. ". Stream " .. stream .. ", Frame time: " .. curtime .. " (Frame: " .. curframe .. ")")
      else
        scriptprint(alert .. ": " .. message .. ". Stream " .. stream)
      end
    end

    function tap.draw()

      scriptprint("Finished")
      scriptprint("Total FINs immediately after Client Hellos: " .. finsAfterClientHellos .. " (total packets checked: " .. totalPackets .. ", start: " .. firstTime .. ", end: " .. lastTime .. ")")
    end
  end

  init_listener()
end
