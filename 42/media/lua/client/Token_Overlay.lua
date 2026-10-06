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

local lightningLevel = 0;
local lightningFlashes = 0;
local lightningHold = 0;
local lightningDelay = 0;
local thunder = true;
local lightningStrike = overlayLightning1;

local function drawOverlay2()
    local player = getPlayer();
    if player then
        local pMod = player:getModData();
        if pMod.lightningLevel ~= nil then
            local lightningLevel = pMod.lightningLevel;
            local lightningFlashes = pMod.lightningFlashes;

            if lightningFlashes > 0 then
                local overlayLightningToDraw = lightningStrike;

                if lightningLevel < 100 and lightningHold <= 0 then
                    lightningLevel = lightningLevel + 10;
                    if lightningLevel > 100 then
                        lightningLevel = 100;
                    end
                    pMod.lightningLevel = lightningLevel;
                end
                if lightningHold > 0 then
                    lightningHold = lightningHold - 1;
                end
                if lightningDelay > 0 then
                    lightningDelay = lightningDelay - 1;
                end
                if lightningDelay <= 0 and thunder == true then
                    player:getEmitter():playSound("Thunder");
                    thunder = false;
                end
                if lightningDelay <= 0 then
                    UIManager.DrawTexture(overlayLightningToDraw, 0, 0, screenX, screenY, lightningLevel);
                end
                if (lightningLevel >= 100) then
                    thunder = true;
                    lightningFlashes = lightningFlashes - 1;
                    pMod.lightningFlashes = lightningFlashes;
                    lightningLevel = 1;
                    pMod.lightningLevel = lightningLevel;
                    lightningDelay = ZombRand(10);
                    lightningHold = ZombRand(9);
                    local randLight = ZombRandBetween(1, 3);
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

local function screensSizeChange(_ox, _oy, x, y)
    screenX = x;
    screenY = y;
end

local function resetThunder()
    thunder = true;
end

Events.OnGameBoot.Add(screenSize);
Events.OnResolutionChange.Add(screensSizeChange);
Events.OnPreUIDraw.Add(drawOverlay2);
Events.OnPlayerDeath.Add(resetThunder);
