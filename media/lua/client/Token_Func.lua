local function isSinglePlayer()
    return not isClient() and not isServer();
end

local function initToken(index, player)
	local pModData = player:getModData(); 

	-- Changes made by me - bruceczk
	if player:getHoursSurvived() > 0 then
		return
	end
	
	pModData.initPerks = {};
	pModData.initRecipes = {};
	
	-- Save starting Perk XP
	for i = 0, PerkFactory.PerkList:size() - 1 do
		local perk = PerkFactory.PerkList:get(i);
		local perkName = perk:getName();
		if perk:getParent() ~= Perks.None then
			local initXP = player:getXp():getXP(perk);
			print(perkName, " ", initXP);
			
			pModData.initPerks[perkName] = initXP;
		end
	end

	-- Save starting recipes
	local recipes = player:getKnownRecipes();
	for i = 0, recipes:size() - 1 do 
		local recipe = recipes:get(i); 
		--table.insert(pModData.initRecipes, recipe); 
		pModData.initRecipes[recipe] = true;
	end

	pModData.lightningLevel = 0; -- lightning Alpha level
	pModData.lightningFlashes = 0; -- number of strikes
				
	pModData.hasToken = false;
	pModData.tokensConsumedThisLife = 0;
	pModData.tokensConsumed = 0;
end

local function createToken(player)
	local pModData = player:getModData();
	local userName = player:getUsername();
	local charName = player:getFullName();

	if pModData.hasToken == false then

		local deathToken = InventoryItemFactory.CreateItem('Token.DeathToken');
		deathToken:setName(charName .. "'s Death Token"); 
		
		if not isSinglePlayer() then
			deathToken:getModData().userName = userName;
		end
		deathToken:getModData().knownRecipes = {};
		deathToken:getModData().knownPerks = {};
				
		-- Save recipes in the token unless granted for free on char creation
		local recipes = player:getKnownRecipes();
		for i = 0, recipes:size()-1 do 
			local recipe = recipes:get(i); 
			if not pModData.initRecipes[recipe] then
				table.insert(deathToken:getModData().knownRecipes, recipe);
			end
		end

		-- Save gained XP except XP granted on character creation
		for i = 0, PerkFactory.PerkList:size() - 1 do
			local perk = PerkFactory.PerkList:get(i);
			local perkName = perk:getName();
			if perk:getParent() ~= Perks.None then
				local perkBoost = 1 + (player:getXp():getPerkBoost(perk) * 0.25);
				local curXP = player:getXp():getXP(perk);	
				local initXP = player:getModData().initPerks[perkName];
				local savedXP = (curXP - initXP) / perkBoost; 

				deathToken:getModData().knownPerks[perkName] = savedXP;
			end
		end
		
		deathToken:getModData().tokenNumber = getPlayer():getModData().tokensConsumed;
		
		deathToken:setDescription("Token number " .. tostring(deathToken:getModData().tokenNumber));
		
		-- if SandboxVars.NotTheEnd.SpawnLocation == 1 then
		if false then
			local inventory = player:getInventory();
			inventory:AddItem(deathToken);
		else
			player:getSquare():AddWorldInventoryItem(deathToken, 0,0,0);
		end
		
		getPlayer():getModData().hasToken = true; -- prevents creation of multiple tokens
	end
end

Events.OnPlayerDeath.Add(createToken);
Events.OnCreatePlayer.Add(initToken);
