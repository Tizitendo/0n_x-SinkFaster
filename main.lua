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
        playerdata.SinkSpeed = params.SinkSpeed
        playerdata.JumpToFloat = params.JumpToFloat

        self:onStatRecalc(function(actor)
            actor:get_data().FasterSink = 0
        end)
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

        if gm._mod_net_isHost() then
            local msg = packetConfig:message_begin()
            msg:write_instance(msgplayer)
            msg:write_float(playerdata.SinkSpeed)
            msg:write_byte(playerdata.JumpToFloat)
            msg:send_to_all()
        end
    end)

    JumpPacket:onReceived(function(msg)
        local player = msg:read_instance()
        player.moveUpHold = msg:read_byte()
        player.ropeDown = msg:read_byte()
        player.wet = msg:read_int()
    end)

    Callback.add("onPlayerStep", "SinkFaster-onPlayerStep", function(self)
        local playerdata = Instance.wrap(self):get_data()
        
        if gm._mod_net_isOnline() and gm._mod_net_isHost() then
            local msg = JumpPacket:message_begin()
            msg:write_instance(Instance.wrap(self))
            msg:write_byte(self.moveUpHold)
            msg:write_byte(self.ropeDown)
            msg:write_int(self.wet)
            msg:send_to_all()
        end

        -- if self.pGravity1 < 0.1 then
        --     self.pGravity1 = 0.52
        --     playerdata.FasterSink = 0
        -- end
        if self.wet ~= nil then
            if self.wet > playerdata.LastWet then
                playerdata.LastWet = self.wet
                if gm.bool(playerdata.JumpToFloat) then
                    if not gm.bool(self.moveUpHold) and self.pVspeed > 0 then
                        if not gm.bool(playerdata.FasterSink) then
                            playerdata.FasterSink = 1
                            self.pGravity1 = self.pGravity1 + playerdata.SinkSpeed
                        end
                    else
                        if gm.bool(playerdata.FasterSink) then
                            playerdata.FasterSink = 0
                            self.pGravity1 = self.pGravity1 - playerdata.SinkSpeed
                        end
                    end
                else
                    if gm.bool(self.ropeDown) and self.pVspeed > 0 then
                        if not gm.bool(playerdata.FasterSink) then
                            self.pGravity1 = self.pGravity1 + playerdata.SinkSpeed
                            playerdata.FasterSink = 1
                        end
                    else
                        if gm.bool(playerdata.FasterSink) then
                            playerdata.FasterSink = 0
                            self.pGravity1 = self.pGravity1 - playerdata.SinkSpeed
                        end
                    end
                end
            else
                if gm.bool(playerdata.FasterSink) then
                    self.pGravity1 = self.pGravity1 - playerdata.SinkSpeed
                    playerdata.FasterSink = 0
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
