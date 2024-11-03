log.info("Successfully loaded " .. _ENV["!guid"] .. ".")
params = {}
mods["RoRRModdingToolkit-RoRR_Modding_Toolkit"].auto()
mods.on_all_mods_loaded(function()
    for k, v in pairs(mods) do
        if type(v) == "table" and v.tomlfuncs then
            Toml = v
        end
    end
end)

LastWet = -1.0
BlockSinking = 0
player = nil
Initialize(function()
    Callback.add("onPlayerInit", "SinkFaster-onPlayerInit", function()
        player = Player.get_client()
        LastWet = -1
    end)
    Callback.add("onPlayerStep", "SinkFaster-onPlayerStep", function()
        if player.value.wet > LastWet then
            LastWet = player.value.wet
            if player.value.ropeDown == 1.0 and player.value.pVspeed > 0 then
                player.value.pGravity1 = 1.0
            else
                player.value.pGravity1 = player.value.pGravity1_base
            end
        else
            player.value.pGravity1 = player.value.pGravity1_base
        end
    end)
end)
