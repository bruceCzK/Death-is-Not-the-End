UIConsumeToken = {};
function UIConsumeToken.createMenu(playerIndex, context, items)
	local player = getSpecificPlayer(playerIndex);
	--local clickedItems = items;
	
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
            break;
        elseif type(entry) == "table" then
            stack = entry;
            break;
        end
    end

    -- Adds context menu entry for single item.
    if item then
    	-- Check if it is one of our containers
    	if item:getType() == "DeathToken" then
			local addXP = context:addOption("Consume Death Token", items, UIConsumeToken.ConsumeToken, player, item);				
		end
		usedItem = item;
    end

    -- Adds context menu entries for multiple items.
    if stack then
		for i = #stack.items, #stack.items do
			local item = stack.items[i];
			if instanceof(item, "InventoryItem") then
				usedItem = item;
				if item:getType() == "DeathToken" and player:getInventory():contains(usedItem) then
					local addXP = context:addOption("Consume Death Token", items, UIConsumeToken.ConsumeToken, player, item);
				end
			end
		end
	end
end

local function isSinglePlayer()
    return not isClient() and not isServer();
end

function UIConsumeToken.ConsumeToken(itemStack,player,item)
	local itemModData = item:getModData();
	local playerModData = player:getModData();
	local userName = player:getUsername();

	if SandboxVars.NotTheEnd.OnlyOwnerCanConsume then 
		if not isSinglePlayer() and itemModData.userName ~= nil then
			player:Say('This does not look like me');
			return
		end
	end

	local curPerkTab = 1;
	local xpMod = 0;

	local initialPercentage = SandboxVars.NotTheEnd.InitialReturnPercentage;
	local penaltyIncreasePercentage = SandboxVars.NotTheEnd.PenaltyIncreasePercentage;
	local penaltyCapPercentage = SandboxVars.NotTheEnd.PenaltyCapPercentage;

	
	local penaltyPercentage = (itemModData.tokenNumber * penaltyIncreasePercentage);
	if penaltyPercentage > penaltyCapPercentage then
		penaltyPercentage = penaltyCapPercentage;
	end
	local newXpMod = (100 - initialPercentage) + penaltyPercentage;

	playerModData.tokensConsumedThisLife = playerModData.tokensConsumedThisLife + 1;	
	playerModData.tokensConsumed = itemModData.tokenNumber + 1;
	
	if SandboxVars.NotTheEnd.RecoveredStats ~= 2 then
		for i = 0, PerkFactory.PerkList:size() - 1 do
			local perk = PerkFactory.PerkList:get(i);
			local perkName = perk:getName();
			if perk:getParent() ~= Perks.None then
				local perkBoost = 1 + (player:getXp():getPerkBoost(perk) * 0.25);
				local savedXP = itemModData.knownPerks[perkName];
				local increaseXP = (savedXP - (savedXP * newXpMod / 100)) * perkBoost; --Apply knowledge boost of new caharcter

				local newMult = player:getXp():getMultiplier(perk);
				if newMult <= 0 then
					newMult = 1;
				end

				if tostring(perk) == "Sprinting" then
					player:getXp():AddXP(perk, increaseXP/SandboxVars.XpMultiplier);
				elseif tostring(perk) == "Fitness" or tostring(perk) == "Strength" then
					player:getXp():AddXP(perk, increaseXP);
				else				
					player:getXp():AddXPNoMultiplier(perk, increaseXP*4/SandboxVars.XpMultiplier);
				end
			end

		end
	end
	
	if SandboxVars.NotTheEnd.RecoveredStats > 1 then
		if itemModData.knownRecipes ~= nil then
			local savedRecipes = itemModData.knownRecipes;
			
			for i, k in pairs(savedRecipes) do
				local recipe = k;
				if not player:getKnownRecipes():contains(recipe) then
					player:getKnownRecipes():add(recipe);
				end
			end
		end
	end
	
	playerModData.lightningFlashes = ZombRand(3)+1;
	playerModData.lightningLevel = 1;
	
	player:getInventory():Remove(usedItem);
end

Events.OnPreFillInventoryObjectContextMenu.Add(UIConsumeToken.createMenu);