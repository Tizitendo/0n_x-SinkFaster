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

Initialize(function()
    local packetConfig = Packet.new()
    local JumpPacket = Packet.new()

    Callback.add(Callback.TYPE.onPlayerInit, "NoGeyserFallDamage-onGameStart", function(self)
        local playerdata = Instance.wrap(self):get_data()
        playerdata.LastWet = -1
        playerdata.FasterSink = 0
        playerdata.moveUpHold = 0
        playerdata.ropeDown = 0
        playerdata.wet = 0
        playerdata.SinkSpeed = params.SinkSpeed
        playerdata.JumpToFloat = params.JumpToFloat
    end)

    Callback.add(Callback.TYPE.onGameStart, "SinkFaster-onGameStart", function()
        local function GameStart()
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
                end
            end
        end
        Alarm.create(GameStart, 2)
    end)

    packetConfig:onReceived(function(msg)
        local msgplayer = msg:read_instance()
        local playerdata = msgplayer:get_data()
        playerdata.SinkSpeed = msg:read_float()
        playerdata.JumpToFloat = msg:read_byte()
        playerdata.LastWet = -1
        playerdata.FasterSink = 0
        playerdata.moveUpHold = 0
        playerdata.ropeDown = 0
        playerdata.wet = 0
        playerdata.FasterSink = 0

        if gm._mod_net_isHost() then
            local msg = packetConfig:message_begin()
            msg:write_instance(msgplayer)
            msg:write_float(playerdata.SinkSpeed)
            msg:write_byte(playerdata.JumpToFloat)
            msg:send_to_all()
        end
    end)

    JumpPacket:onReceived(function(msg)
        -- local player = msg:read_instance()
        -- player.moveUpHold = msg:read_byte()
        -- player.ropeDown = msg:read_byte()
        -- player.wet = msg:read_int()
        local playerdata = msg:read_instance():get_data()
        playerdata.moveUpHold = msg:read_byte()
        playerdata.ropeDown = msg:read_byte()
        playerdata.wet = msg:read_int()
    end)

    Callback.add("onPlayerStep", "SinkFaster-onPlayerStep", function(self)
        local playerdata = Instance.wrap(self):get_data()
        playerdata.moveUpHold = self.moveUpHold
        playerdata.ropeDown = self.ropeDown
        playerdata.wet = self.wet
        
        if gm._mod_net_isOnline() and gm._mod_net_isHost() then
            local msg = JumpPacket:message_begin()
            msg:write_instance(Instance.wrap(self))
            msg:write_byte(playerdata.moveUpHold)
            msg:write_byte(playerdata.ropeDown)
            msg:write_int(playerdata.wet)
            msg:send_to_all()
        end

        if playerdata.wet and playerdata.wet > playerdata.LastWet and self.pVspeed > 0 then
            playerdata.LastWet = playerdata.wet
            if gm.bool(playerdata.JumpToFloat) then
                if not gm.bool(playerdata.moveUpHold) then
                    if not gm.bool(playerdata.FasterSink) then
                        self.pVspeed = self.pVspeed + playerdata.SinkSpeed
                    end
                end
            else
                if gm.bool(playerdata.ropeDown) then
                    if not gm.bool(playerdata.FasterSink) then
                        self.pVspeed = self.pVspeed + playerdata.SinkSpeed
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
