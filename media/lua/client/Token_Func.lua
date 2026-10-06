local function isSinglePlayer()
    return not isClient() and not isServer();
end

local function nowMs()
	if getTimestampMs then
		return getTimestampMs();
	end
	return getGameTime():getWorldAgeHours() * 3600000;
end

local function initToken(index, player)
	local pModData = player:getModData(); 

	-- Changes made by me - bruceczk
	-- Capture once per character; a later join must not re-capture, that would count
	-- earned XP as starting XP and the token would then lose it on the next death.
	if pModData.initPerks and next(pModData.initPerks) then
		return
	end

	if player:getHoursSurvived() > 0 then
		return
	end
	
	pModData.initPerks = {};
	pModData.initRecipes = {};
	
	-- Save starting Perk XP, keyed by list position (perk names are localized on the client)
	for i = 0, PerkFactory.PerkList:size() - 1 do
		local perk = PerkFactory.PerkList:get(i);
		if perk:getParent() ~= Perks.None then
			local startXP = player:getXp():getXP(perk);
			-- Professions can grant the starting level without the matching XP pool, that
			-- starting progress must never be inherited through the token.
			local levelXP = perk:getXpForLevel(player:getPerkLevel(perk));
			if levelXP and levelXP > startXP then
				startXP = levelXP;
			end
			pModData.initPerks[i] = startXP;
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
				
	pModData.lastTokenTime = 0;
	pModData.tokensConsumedThisLife = 0;
	pModData.tokensConsumed = 0;
end

local function createToken(player)
	local pModData = player:getModData();
	local userName = player:getUsername();
	local charName = player:getFullName();

	-- Debounce: the death may be reported twice, but a stale flag must never block a later
	-- death, so only a short time window is used.
	local now = nowMs();
	local last = pModData.lastTokenTime or 0;
	local blocked = last > 0 and now >= last and now - last < 3000;

	if not blocked then

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
				local initXP = player:getModData().initPerks[i];
				if initXP == nil then
					initXP = player:getModData().initPerks[perkName]; -- saves from older versions
				end
				local savedXP = (curXP - (initXP or 0)) / perkBoost; 

				deathToken:getModData().knownPerks[i] = savedXP;
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
		
		pModData.lastTokenTime = now; -- prevents creation of multiple tokens for one death
	end
end

Events.OnPlayerDeath.Add(createToken);
Events.OnCreatePlayer.Add(initToken);
