-- Multiplayer side: the server owns the token (creation on death, consumption), so it persists
-- and is visible to every client. The client only sends requests and shows the result.
if not isServer() then
    return
end

local function isDeathToken(item, itemId)
    if not item or item:getType() ~= "DeathToken" then
        return false;
    end
    return itemId == nil or item:getID() == itemId;
end

local function findInContainer(container, itemId)
    if itemId then
        return container:getItemWithIDRecursiv(itemId);
    end
    local items = container:getItems();
    for i = 0, items:size() - 1 do
        if isDeathToken(items:get(i), nil) then
            return items:get(i);
        end
    end
    return nil;
end

-- Looks for the token in the player's inventory and in containers of the nearby squares
-- (floor drops, corpses, crates). Falls back to any death token nearby when the id is unknown.
local function findToken(player, itemId)
    if itemId == 0 then
        itemId = nil;
    end

    for pass = 1, 2 do
        local item = findInContainer(player:getInventory(), itemId);
        if item and isDeathToken(item, itemId) then
            return item;
        end

        local square = player:getSquare();
        local cell = getCell();
        if square and cell then
            local x, y, z = square:getX(), square:getY(), square:getZ();
            for dx = -2, 2 do
                for dy = -2, 2 do
                    local sq = cell:getGridSquare(x + dx, y + dy, z);
                    if sq then
                        local objects = sq:getObjects();
                        for i = 0, objects:size() - 1 do
                            local obj = objects:get(i);
                            if instanceof(obj, "IsoWorldInventoryObject") then
                                local worldItem = obj:getItem();
                                if isDeathToken(worldItem, itemId) then
                                    return worldItem;
                                end
                            end
                            local container = obj:getContainer();
                            if container then
                                item = findInContainer(container, itemId);
                                if item and isDeathToken(item, itemId) then
                                    return item;
                                end
                            end
                        end
                    end
                end
            end
        end

        if itemId == nil then
            break
        end
        itemId = nil; -- retry without the id, the client may not know it (e.g. old items)
    end
    return nil;
end

local function onClientCommand(module, command, player, args)
    if module ~= "NotTheEnd" then
        return;
    end

    if command == "SyncBaseline" then
        local pModData = player:getModData();
        pModData.initPerks = args.perks or {};
        pModData.initRecipes = args.recipes or {};
        if pModData.lastTokenTime == nil then
            pModData.lastTokenTime = 0;
        end
        if pModData.tokensConsumed == nil then
            pModData.tokensConsumed = 0;
        end
        if pModData.tokenPenalty == nil then
            pModData.tokenPenalty = 0;
        end
    elseif command == "DropToken" then
        local tokenName = type(args.name) == "string" and string.sub(args.name, 1, 256) or nil;
        local tokenDesc = type(args.desc) == "string" and string.sub(args.desc, 1, 256) or nil;
        -- Take the creation-time baseline from the request itself, so it cannot be lost with a
        -- sync that was sent before the client finished joining.
        local pModData = player:getModData();
        if type(args.perks) == "table" then
            pModData.initPerks = args.perks;
        end
        if type(args.recipes) == "table" then
            pModData.initRecipes = args.recipes;
        end
        NotTheEnd.createToken(player, tokenName, tokenDesc);
    elseif command == "ConsumeToken" then
        if player:isDead() then
            sendServerCommand(player, "NotTheEnd", "TokenRefused", { reason = "notFound" });
            return;
        end
        local item = findToken(player, args.id);
        if not item then
            sendServerCommand(player, "NotTheEnd", "TokenRefused", { reason = "notFound" });
            return;
        end
        local ok, reason, recovery = NotTheEnd.consumeToken(player, item, true);
        if ok then
            -- Same model as the vanilla /addxp command: the server applies the XP (authoritative
            -- record) and the client applies the same amounts locally for instant feedback.
            NotTheEnd.applyXpList(player, recovery.xp);
            if recovery.recipes then
                for _, recipe in ipairs(recovery.recipes) do
                    if not player:isRecipeKnown(recipe) then
                        player:learnRecipe(recipe);
                    end
                end
            end
            recovery.tokenId = item:getID();
            sendServerCommand(player, "NotTheEnd", "TokenConsumed", recovery);
        else
            sendServerCommand(player, "NotTheEnd", "TokenRefused", { reason = reason });
        end
    end
end

local function onPlayerDeath(player)
    NotTheEnd.createToken(player);
end

Events.OnClientCommand.Add(onClientCommand);
Events.OnPlayerDeath.Add(onPlayerDeath);
