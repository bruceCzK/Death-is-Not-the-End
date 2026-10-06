-- Shared logic: the authoritative side (server in multiplayer, the single process in singleplayer)
-- creates and consumes tokens; the client only drives the UI.
NotTheEnd = NotTheEnd or {};

function NotTheEnd.isSinglePlayer()
    return not isClient() and not isServer();
end

-- Save what the character started with, so the token can tell apart starting bonuses from earned progress.
function NotTheEnd.captureBaseline(player)
    local initPerks = {};
    for i = 0, PerkFactory.PerkList:size() - 1 do
        local perk = PerkFactory.PerkList:get(i);
        if perk:getParent() ~= Perks.None then
            local startXP = player:getXp():getXP(perk);
            -- Professions may grant the starting level without the matching XP pool; that
            -- starting progress must never be inherited through the token.
            local levelXP = perk:getXpForLevel(player:getPerkLevel(perk));
            if levelXP and levelXP > startXP then
                startXP = levelXP;
            end
            -- Keyed by list position: perk names are not a stable identity across Lua contexts.
            initPerks[i] = startXP;
        end
    end
    local initRecipes = {};
    local recipes = player:getKnownRecipes();
    for i = 0, recipes:size() - 1 do
        initRecipes[recipes:get(i)] = true;
    end
    return initPerks, initRecipes;
end

-- The multiplayer server has no mod translations, so the client may pass ready-made texts.
function NotTheEnd.getGameTimeText()
    local gameTime = getGameTime();
    return string.format("%04d-%02d-%02d %02d:%02d", gameTime:getYear(), gameTime:getMonth() + 1,
        gameTime:getDay() + 1, gameTime:getHour(), gameTime:getMinutes());
end

-- Extra token description lines: which character died and when the token dropped.
function NotTheEnd.getTokenDescExtraLines(characterName)
    local charLine = getText('UI_NotTheEnd_Token_DescChar', characterName);
    if charLine == 'UI_NotTheEnd_Token_DescChar' then
        charLine = 'Character: ' .. tostring(characterName);
    end
    local timeText = NotTheEnd.getGameTimeText();
    local timeLine = getText('UI_NotTheEnd_Token_DescTime', timeText);
    if timeLine == 'UI_NotTheEnd_Token_DescTime' then
        timeLine = 'Dropped at: ' .. timeText;
    end
    return charLine, timeLine;
end

function NotTheEnd.createToken(player, tokenNameOverride, tokenDescTemplate)
    local pModData = player:getModData();

    -- Debounce: the death can be reported twice (client event + server hook), but a stale flag
    -- must never block a later death, so only a short time window is used.
    local now = getTimestampMs();
    local last = pModData.lastTokenTime or 0;
    if last > 0 and now >= last and now - last < 3000 then
        return nil;
    end

    local initPerks = pModData.initPerks or {};
    local initRecipes = pModData.initRecipes or {};

    local deathToken = instanceItem('Token.DeathToken');
    -- Name the token after the player (the character is recreated every death).
    local tokenOwner = player:getUsername();
    if not tokenOwner or tokenOwner == "" then
        tokenOwner = player:getFullName();
    end
    local tokenName = tokenNameOverride;
    if not tokenName then
        tokenName = getText('UI_NotTheEnd_Token_Name_Player', tokenOwner);
        if tokenName == 'UI_NotTheEnd_Token_Name_Player' then
            -- The active language has no translation for us, keep a readable fallback.
            tokenName = tokenOwner .. "'s Death Token";
        end
    end
    deathToken:setName(tokenName);
    deathToken:setCustomName(true);

    local tokenModData = deathToken:getModData();
    tokenModData.userName = player:getUsername();
    tokenModData.knownRecipes = {};
    tokenModData.knownPerks = {};
    tokenModData.tokenPenalty = pModData.tokenPenalty or 0;

    -- Save recipes in the token unless granted for free on char creation
    -- Only save recipes if RecoveredStats is Recipes or Both
    if SandboxVars.NotTheEnd.RecoveredStats == 2 or SandboxVars.NotTheEnd.RecoveredStats == 3 then
        local recipes = player:getKnownRecipes();
        for i = 0, recipes:size() - 1 do
            local recipe = recipes:get(i);
            if not initRecipes[recipe] then
                tokenModData.knownRecipes[recipe] = true;
            end
        end
    end

    -- Save gained XP except XP granted on character creation
    -- Only save perks if RecoveredStats is Perks or Both
    if SandboxVars.NotTheEnd.RecoveredStats == 1 or SandboxVars.NotTheEnd.RecoveredStats == 3 then
        for i = 0, PerkFactory.PerkList:size() - 1 do
            local perk = PerkFactory.PerkList:get(i);
            local perkName = perk:getName();
            if perk:getParent() ~= Perks.None then
                local perkBoost = 1 + (player:getXp():getPerkBoost(perk) * 0.25);
                local curXP = player:getXp():getXP(perk);
                tokenModData.knownPerks[perkName] = (curXP - (initPerks[i] or 0)) / perkBoost;
            end
        end
    end

    local tokenNumber = pModData.tokensConsumed or 0;
    tokenModData.tokenNumber = tokenNumber;
    local description;
    if tokenDescTemplate then
        description = string.gsub(tokenDescTemplate, "%%1", tostring(tokenNumber));
    else
        description = getText('UI_NotTheEnd_Token_Desc', tostring(tokenNumber));
        if description == 'UI_NotTheEnd_Token_Desc' then
            description = 'Token number ' .. tostring(tokenNumber);
        end
        local charLine, timeLine = NotTheEnd.getTokenDescExtraLines(player:getFullName());
        description = description .. "\n" .. charLine .. "\n" .. timeLine;
    end
    deathToken:setDescription(description);

    if SandboxVars.NotTheEnd.SpawnLocation == 1 then
        player:getSquare():AddWorldInventoryItem(deathToken, 0, 0, 0);
    else
        -- On a server the death may already be processed when the request arrives, so the
        -- inventory cannot be used anymore: put the token on the fresh corpse instead.
        local container;
        local square = player:getSquare();
        if isServer() and player:isDead() and square then
            local bodies = square:getDeadBodys();
            if bodies:size() > 0 then
                container = bodies:get(bodies:size() - 1):getContainer();
            end
        end
        if container then
            container:AddItem(deathToken);
        else
            player:getInventory():AddItem(deathToken);
        end
    end

    pModData.lastTokenTime = getTimestampMs(); -- prevents creation of multiple tokens for one death
    return deathToken;
end

function NotTheEnd.findPerk(perkName)
    if perkName == nil then
        return nil;
    end
    local target = tostring(perkName);
    for i = 0, PerkFactory.PerkList:size() - 1 do
        local perk = PerkFactory.PerkList:get(i);
        if tostring(perk:getName()) == target then
            return perk;
        end
    end
    return nil;
end

-- In multiplayer the player's own client owns the skills, so the server computes the amounts
-- and the client applies them (same model as the debug "Add XP" button).
-- Returns the number of perks that got XP and the total amount applied.
function NotTheEnd.applyXpList(player, xpList)
    local applied = 0;
    local total = 0;
    for _, entry in ipairs(xpList) do
        -- Prefer the list index: perk names are not stable across contexts.
        local perk;
        if type(entry.index) == "number" and entry.index >= 0 and entry.index < PerkFactory.PerkList:size() then
            perk = PerkFactory.PerkList:get(entry.index);
        end
        if not perk then
            perk = NotTheEnd.findPerk(entry.perk);
        end
        if perk then
            applied = applied + 1;
            total = total + (entry.amount or 0);
            if entry.noMultiplier then
                player:getXp():AddXP(perk, entry.amount, true);
            else
                player:getXp():AddXP(perk, entry.amount);
            end
        end
    end
    return applied, total;
end

-- Removes a consumed token: floor drops need the full removal sequence (same as picking a
-- world item up), otherwise the item stays on the square and clients keep seeing it.
function NotTheEnd.removeTokenItem(item)
    local worldItem = item:getWorldItem();
    if worldItem then
        local square = worldItem:getSquare();
        if square then
            if isServer() then
                square:transmitRemoveItemFromSquareOnClients(worldItem);
            else
                square:transmitRemoveItemFromSquare(worldItem);
            end
        end
        worldItem:removeFromWorld();
        worldItem:removeFromSquare();
        worldItem:setSquare(nil);
        item:setWorldItem(nil);
    end
    local container = item:getContainer();
    if container then
        container:Remove(item);
    end
end

-- Returns ok, reason, recovery. On success the token is removed.
-- With collectOnly the recovered stats are returned instead of applied (the client applies them).
function NotTheEnd.consumeToken(player, item, collectOnly)
    local itemModData = item:getModData();
    local playerModData = player:getModData();

    if SandboxVars.NotTheEnd.OnlyOwnerCanConsume and not NotTheEnd.isSinglePlayer()
        and itemModData.userName ~= nil and itemModData.userName ~= player:getUsername() then
        return false, "notOwner";
    end

    local initialPercentage = SandboxVars.NotTheEnd.InitialReturnPercentage;
    local penaltyIncreasePercentage = SandboxVars.NotTheEnd.PenaltyIncreasePercentage;
    local penaltyCapPercentage = SandboxVars.NotTheEnd.PenaltyCapPercentage;

    -- Tokens created before this option existed carry no penalty, fall back to the token number.
    local penaltyPercentage = itemModData.tokenPenalty or (itemModData.tokenNumber * penaltyIncreasePercentage);
    if penaltyPercentage > penaltyCapPercentage then
        penaltyPercentage = penaltyCapPercentage;
    end
    local recoveryPercentage = initialPercentage - penaltyPercentage;
    if recoveryPercentage < 0 then
        recoveryPercentage = 0;
    end

    playerModData.tokensConsumedThisLife = (playerModData.tokensConsumedThisLife or 0) + 1;
    playerModData.tokensConsumed = (itemModData.tokenNumber or 0) + 1;
    playerModData.tokenPenalty = penaltyPercentage + penaltyIncreasePercentage;
    if playerModData.tokenPenalty > penaltyCapPercentage then
        playerModData.tokenPenalty = penaltyCapPercentage;
    end

    local xpList = {};
    if SandboxVars.NotTheEnd.RecoveredStats ~= 2 then
        for i = 0, PerkFactory.PerkList:size() - 1 do
            local perk = PerkFactory.PerkList:get(i);
            local perkName = perk:getName();
            if perk:getParent() ~= Perks.None then
                local perkBoost = 1 + (player:getXp():getPerkBoost(perk) * 0.25);
                local savedXP = (itemModData.knownPerks or {})[perkName] or 0;
                local increaseXP = savedXP * recoveryPercentage / 100 * perkBoost; -- apply knowledge boost of new character

                -- XP is applied with noMultiplier, so the earned amount carries over 1:1.
                xpList[#xpList + 1] = { index = i, perk = perkName, amount = increaseXP, noMultiplier = true };
            end
        end
    end

    local recipeList;
    if SandboxVars.NotTheEnd.RecoveredStats > 1 and itemModData.knownRecipes ~= nil then
        recipeList = {};
        for recipe in pairs(itemModData.knownRecipes) do
            recipeList[#recipeList + 1] = recipe;
        end
    end

    if not collectOnly then
        NotTheEnd.applyXpList(player, xpList);
        if recipeList then
            for _, recipe in ipairs(recipeList) do
                if not player:isRecipeKnown(recipe) then
                    player:learnRecipe(recipe);
                end
            end
        end
    end

    NotTheEnd.removeTokenItem(item);

    return true, nil, { xp = xpList, recipes = recipeList, recovery = recoveryPercentage };
end
