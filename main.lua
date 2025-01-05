log.info("Successfully loaded " .. _ENV["!guid"] .. ".")
mods["RoRRModdingToolkit-RoRR_Modding_Toolkit"].auto(true)
mods.on_all_mods_loaded(function()
    for k, v in pairs(mods) do
        if type(v) == "table" and v.tomlfuncs then
            Toml = v
        end
    end
    params = {
        SinkSpeed = 0.6,
        JumpToFloat = false
    }
    params = Toml.config_update(_ENV["!guid"], params) -- Load Save
end)

local SinkSpeedMP = {}
local JumpToFloatMP = {}

local LastWet = {}
local player = {}
local FasterSink = {}
Initialize(function()
    local packetConfig = Packet.new()
    local JumpPacket = Packet.new()
    local PlayerIndex = 1
    Callback.add("onPlayerInit", "SinkFaster-onPlayerInit", function(self)
        if not gm._mod_net_isOnline() then
            if (Player.get_client():same(self)) then
                player = {}
                PlayerIndex = 1
            end
            player[PlayerIndex] = Wrap.wrap(self)
            LastWet[PlayerIndex] = -1
            SinkSpeedMP[PlayerIndex] = params.SinkSpeed
            JumpToFloatMP[PlayerIndex] = params.JumpToFloat
            PlayerIndex = PlayerIndex + 1
            FasterSink[1] = 0
        end
    end)

    Callback.add("onGameStart", "SinkFaster-onGameStart", function()
        local function myFunc()
            if gm._mod_net_isOnline() then
                if gm._mod_net_isClient() then
                    local msg = packetConfig:message_begin()
                    msg:write_instance(Player.get_client())
                    msg:write_float(params.SinkSpeed)
                    msg:write_byte(params.JumpToFloat)
                    msg:send_to_host()
                end
                if gm._mod_net_isHost() then
                    local msg = packetConfig:message_begin()
                    msg:write_instance(Player.get_client())
                    msg:write_float(params.SinkSpeed)
                    msg:write_byte(params.JumpToFloat)
                    msg:send_to_all()

                    player[1] = Player.get_client()
                    SinkSpeedMP[1] = params.SinkSpeed
                    JumpToFloatMP[1] = params.JumpToFloat
                    LastWet[1] = -1
                    FasterSink[1] = 0
                end
            end
        end

        Alarm.create(myFunc, 60)
        SinkSpeedMP = {}
        JumpToFloatMP = {}
        player = {}
        LastWet = {}
        FasterSink = {}
    end)

    packetConfig:onReceived(function(msg)
        local msgplayer = msg:read_instance()
        player[msgplayer.m_id] = msgplayer
        SinkSpeedMP[msgplayer.m_id] = msg:read_float()
        JumpToFloatMP[msgplayer.m_id] = msg:read_byte()
        LastWet[msgplayer.m_id] = -1
        FasterSink[msgplayer.m_id] = 0

        if gm._mod_net_isHost() then
            local msg = packetConfig:message_begin()
            msg:write_instance(msgplayer)
            msg:write_float(SinkSpeedMP[msgplayer.m_id])
            msg:write_byte(JumpToFloatMP[msgplayer.m_id])
            msg:send_to_all()
        end
    end)

    JumpPacket:onReceived(function(msg)
        local PlayerId = msg:read_byte()
        if player[PlayerId] ~= nil then
            player[PlayerId].moveUpHold = msg:read_byte()
            player[PlayerId].ropeDown = msg:read_byte()
            player[PlayerId].wet = msg:read_int()
        end
    end)

    Callback.add("onStageStart", "SinkFaster-onStageStart", function()
        for i = 1, #player do
            FasterSink[i] = 0
        end
    end)


    Callback.add("onPlayerStep", "SinkFaster-onPlayerStep", function(self)
        if gm._mod_net_isOnline() and gm._mod_net_isHost() then
            for i = 1, #player do
                if player[i] then
                    local msg = JumpPacket:message_begin()
                    msg:write_byte(player[i].m_id)
                    msg:write_byte(player[i].moveUpHold)
                    msg:write_byte(player[i].ropeDown)
                    msg:write_int(player[i].wet)
                    msg:send_to_all()
                end
            end
        end

        for i = 1, #player do
            if player[i] then
                if player[i].wet ~= nil and player[i].wet > LastWet[i] then
                    LastWet[i] = player[i].wet
                    if JumpToFloatMP[i] == true or JumpToFloatMP[i] == 1 then
                        if player[i].moveUpHold == false or player[i].moveUpHold == 0 and player[i].pVspeed > 0 then
                            if FasterSink[i] == 0 then
                                player[i].pGravity1 = player[i].pGravity1 + SinkSpeedMP[i]
                                FasterSink[i] = 1
                            end
                        else
                            if FasterSink[i] == 1 then
                                FasterSink[i] = 0
                                player[i].pGravity1 = player[i].pGravity1 - SinkSpeedMP[i]
                            end
                        end
                    else
                        if player[i].ropeDown == 1.0 or player[i].ropeDown == true and player[i].pVspeed > 0 then
                            if FasterSink[i] == 0 then
                                player[i].pGravity1 = player[i].pGravity1 + SinkSpeedMP[i]
                                FasterSink[i] = 1
                            end
                        else
                            if FasterSink[i] == 1 then
                                FasterSink[i] = 0
                                player[i].pGravity1 = player[i].pGravity1 - SinkSpeedMP[i]
                            end
                        end
                    end
                else
                    if player[i].wet == LastWet[i] and FasterSink[i] == 1 then
                        LastWet[i] = LastWet[i] + 1
                        player[i].pGravity1 = player[i].pGravity1 - SinkSpeedMP[i]
                        FasterSink[i] = 0
                    end
                end
            end
        end
    end)
end)

-- Add ImGui window
gui.add_to_menu_bar(function()
    params.SinkSpeed = ImGui.DragFloat("SinkSpeed", params.SinkSpeed)
    params.JumpToFloat = ImGui.Checkbox("Hold Jump to float", params.JumpToFloat)
    Toml.save_cfg(_ENV["!guid"], params)
end)
gui.add_imgui(function()
    if ImGui.Begin("SinkFaster") then
        params.SinkSpeed = ImGui.InputFloat("SinkSpeed", params.SinkSpeed, 0.1, 0.5, "%.1f")
        params.JumpToFloat = ImGui.Checkbox("Hold Jump to float", params.JumpToFloat)
        Toml.save_cfg(_ENV["!guid"], params)
    end
    ImGui.End()
end)
