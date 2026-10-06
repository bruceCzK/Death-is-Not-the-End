-- Init token
local function initToken(index, player)
    local pModData = player:getModData();

    -- Capture once per character: a later join must not re-capture, that would count earned
    -- XP as starting XP and the token would then lose it on the next death.
    if pModData.initPerks and next(pModData.initPerks) then
        return
    end

    -- Do not apply to existing game
    if player:getHoursSurvived() > 0 then
        return
    end

    local initPerks, initRecipes = NotTheEnd.captureBaseline(player);
    pModData.initPerks = initPerks;
    pModData.initRecipes = initRecipes;

    pModData.lightningLevel = 0; -- lightning Alpha level
    pModData.lightningFlashes = 0; -- number of strikes

    pModData.lastTokenTime = 0;
    pModData.tokensConsumedThisLife = 0;
    pModData.tokensConsumed = 0;
    pModData.tokenPenalty = 0; -- accumulated penalty carried between tokens

    -- In multiplayer the server owns the token, hand it the baseline.
    if isClient() then
        sendClientCommand(player, "NotTheEnd", "SyncBaseline", { perks = initPerks, recipes = initRecipes });
    end
end

-- Create Token
local function createToken(player)
    -- In multiplayer the server creates the token, so it persists for everyone.
    -- OnPlayerDeath is only reliable on the client there, so ask the server to do it.
    -- The server has no mod translations, so send the texts resolved in the player's language.
    if isClient() then
        local tokenOwner = player:getUsername();
        if not tokenOwner or tokenOwner == "" then
            tokenOwner = player:getFullName();
        end
        local tokenName = getText('UI_NotTheEnd_Token_Name_Player', tokenOwner);
        if tokenName == 'UI_NotTheEnd_Token_Name_Player' then
            tokenName = tokenOwner .. "'s Death Token";
        end
        local descTemplate = getText('UI_NotTheEnd_Token_Desc', '%1');
        if descTemplate == 'UI_NotTheEnd_Token_Desc' then
            descTemplate = 'Token number %1';
        end
        local charLine, timeLine = NotTheEnd.getTokenDescExtraLines(player:getFullName());
        descTemplate = descTemplate .. "\n" .. charLine .. "\n" .. timeLine;
        -- The baseline rides along with the drop: the creation-time sync can be sent before the
        -- join has finished and then be lost, while the death request always reaches the server.
        local pModData = player:getModData();
        sendClientCommand(player, "NotTheEnd", "DropToken", { name = tokenName, desc = descTemplate,
            perks = pModData.initPerks or {}, recipes = pModData.initRecipes or {} });
        return;
    end
    NotTheEnd.createToken(player);
end

Events.OnPlayerDeath.Add(createToken);
Events.OnCreatePlayer.Add(initToken);
