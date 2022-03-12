-- Credit to Viceroy 

local overlayLightning1 = getTexture("media/textures/GUI/lightning1.png");
local overlayLightning2 = getTexture("media/textures/GUI/lightning2.png");
local overlayLightning = getTexture("media/textures/GUI/lightning.png");

local screenX;
local screenY;
local overlayOffsetX;
local overlayOffsetY;

-- Tweak values listed below:
-- Current is merely used to blend smoothly.
-- Rate is how fast an overlay changes blend.
-- Cap is how many times you divide the opacity to lower it. 1 being not at all and 10 being ten times as dim.
-- Do NOT EVER set a cap to 0.

local lightningLevel;
local lightningFlashes;
local lightningHold = 0;
local lightningDelay = 0;
local thunder = true;
local lightningStrike = overlayLightning1;

local function drawOverlay2()
	player = getPlayer();
	if player then
		local pMod = player:getModData();
		if pMod.lightningLevel ~= nil then 
			lightningLevel = getPlayer():getModData().lightningLevel;
			lightningFlashes = getPlayer():getModData().lightningFlashes;
			
			if lightningFlashes > 0 then
				-- player:Say(tostring(thunder));
				overlayLightning = lightningStrike;
				
				if lightningLevel <= 100 and lightningHold <= 0 then
					pMod.lightningLevel = lightningLevel + 10;
				end
				if lightningHold > 0 then
					lightningHold = lightningHold - 1;
				end
				if lightningDelay > 0 then
					lightningDelay = lightningDelay - 1;
				end
				if lightningDelay <= 0 and thunder == true then
					player:getEmitter():playSound("thunder2");
					thunder = false;
				end
				if lightningDelay <= 0 then
					UIManager.DrawTexture(overlayLightning, 0, 0, screenX, screenY, lightningLevel);
				end
				if (lightningLevel >= 100) then
					thunder = true;
					pMod.lightningFlashes = lightningFlashes - 1;
					pMod.lightningLevel = 1;
					lightningDelay = ZombRandBetween(1,10);
					lightningHold = ZombRandBetween(0,8);
					local randLight = ZombRandBetween(1,3);
					-- player:Say(tostring(randLight));
					if randLight == 1 then
						lightningStrike = overlayLightning1;
						else
						lightningStrike = overlayLightning2;
					end
				end
			end
		end
	end	
end

local function screenSize()
	screenX = getCore():getScreenWidth();
	screenY = getCore():getScreenHeight();
end

local function screensSizeChange( _ox, _oy, x, y )
	screenX = x;
	screenY = y;
end

Events.OnGameBoot.Add( screenSize );
Events.OnResolutionChange.Add( screensSizeChange );
Events.OnPreUIDraw.Add( drawOverlay2 );