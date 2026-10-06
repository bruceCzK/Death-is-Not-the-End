UIConsumeToken = {};

-- Kept until the server confirms, then removed locally so the client stops showing it.
local pendingToken = nil;
-- Reloading Lua re-registers the event handlers, so ignore duplicate answers for a token.
local handledTokens = {};

local function triggerLightning(player)
    local playerModData = player:getModData();
    playerModData.lightningFlashes = ZombRand(3) + 1;
    playerModData.lightningLevel = 1;
end

function UIConsumeToken.createMenu(playerIndex, context, items)
    local player = getSpecificPlayer(playerIndex);

    -- The event can run more than once for the same menu, only add our entry once.
    local optionText = getText('UI_NotTheEnd_Consume');
    if context:getOptionFromName(optionText) then
        return;
    end

    -- Will store the clicked stuff.
    local item;
    local stack;

    -- stop function if player has selected multiple item stacks
    if #items > 1 then
        return;
    end

    -- Iterate through all clicked items
    for i, entry in ipairs(items) do
        -- test if we have a single item
        if instanceof(entry, "InventoryItem") then
            item = entry; -- store in local variable
            break
        elseif type(entry) == "table" then
            stack = entry;
            break
        end
    end

    -- Adds context menu entry for single item.
    if item then
        if item:getType() == "DeathToken" then
            context:addOption(optionText, items, UIConsumeToken.ConsumeToken, player, item);
        end
    end

    -- Adds context menu entry for multiple items. A stack may hold several tokens,
    -- but one consume option is enough (it consumes the top one).
    if stack then
        for i = 1, #stack.items do
            local stackItem = stack.items[i];
            if instanceof(stackItem, "InventoryItem") and stackItem:getType() == "DeathToken" then
                context:addOption(optionText, items, UIConsumeToken.ConsumeToken, player, stackItem);
                break
            end
        end
    end
end

function UIConsumeToken.ConsumeToken(itemStack, player, item)
    if NotTheEnd.isSinglePlayer() then
        local ok, reason = NotTheEnd.consumeToken(player, item);
        if ok then
            triggerLightning(player);
        elseif reason == "notOwner" then
            player:Say(getText('UI_NotTheEnd_Not_Me'));
        end
    else
        -- The server consumes the token and answers with TokenConsumed or TokenRefused.
        pendingToken = item;
        sendClientCommand(player, "NotTheEnd", "ConsumeToken", { id = item:getID() });
    end
end

local function onServerCommand(module, command, args)
    if module ~= "NotTheEnd" then
        return;
    end
    local player = getPlayer();
    if not player then
        return;
    end
    if command == "TokenConsumed" then
        -- Guard against duplicated answers (e.g. after a Lua reload re-registered the handler).
        local tokenId = args.tokenId;
        if tokenId and tokenId ~= 0 then
            if handledTokens[tokenId] then
                return;
            end
            handledTokens[tokenId] = true;
        end
        -- The server already applied the recovery; apply the same amounts locally for instant feedback.
        if args.xp then
            NotTheEnd.applyXpList(player, args.xp);
            SyncXp(player);
            if ISPlayerStatsUI and ISPlayerStatsUI.instance then
                ISPlayerStatsUI.instance:loadPerks();
            end
        end
        if args.recipes then
            for _, recipe in ipairs(args.recipes) do
                if not player:isRecipeKnown(recipe) then
                    player:learnRecipe(recipe);
                end
            end
        end
        if pendingToken then
            NotTheEnd.removeTokenItem(pendingToken);
            pendingToken = nil;
        end
        triggerLightning(player);
    elseif command == "TokenRefused" and args.reason == "notOwner" then
        pendingToken = nil;
        player:Say(getText('UI_NotTheEnd_Not_Me'));
    elseif command == "TokenRefused" and args.reason == "notFound" then
        pendingToken = nil;
        player:Say(getText('UI_NotTheEnd_Token_Gone'));
    end
end

Events.OnPreFillInventoryObjectContextMenu.Add(UIConsumeToken.createMenu);
Events.OnServerCommand.Add(onServerCommand);
