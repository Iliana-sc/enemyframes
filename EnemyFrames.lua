EnemyFrames = {}

EnemyFrames.DebugEnabled    = {}    -- Map to enable various debug levels
EnemyFrames.EnemyData       = {}    -- playername => playerdata map
EnemyFrames.UnitNames       = {}    -- enemyframeunitname => playername map
EnemyFrames.LastZone        = ""
EnemyFrames.ZoneTimer       = nil
EnemyFrames.MaxDisplayUnits = 10
EnemyFrames.DebugChatFrame  = ChatFrame3
EnemyFrames.HideUnknownUnitError = false

-- Localized shit:
EnemyFrames.FlagPicked   = "The ([^ ]+) [Ff]lag was picked up by ([^ ]+)!"
EnemyFrames.FlagCaptured = "([^ ]+) captured the ([^ ]+) [Ff]lag!"
EnemyFrames.FlagDropped  = "The ([^ ]+) [Ff]lag was dropped by ([^ ]+)!"
EnemyFrames.FlagReturn   = ".* was returned to .*"
EnemyFrames.UnknownUnitError = "Unknown unit."

-- Debug levels
EnemyFrames.DebugEnabled.Zone           = false  -- Debug messages about loading screens
EnemyFrames.DebugEnabled.Flags          = false  -- Debug messages about WSG flag pickups
EnemyFrames.DebugEnabled.TargetData     = false  -- Debug messages for getting data from target of target (of target ...)
EnemyFrames.DebugEnabled.DisplayUpdate  = false  -- Debug messages for when a frame is updated visually
EnemyFrames.DebugEnabled.TargetScan     = false  -- Debug messages for actively trying to target units to scan them

function EnemyFrames.Print(msg, r, g, b)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff8040EnemyFrames:|r " .. msg, r, g, b)
end

function EnemyFrames.PrintError(msg)
    EnemyFrames.Print("Error: " .. msg, 1.0, 0.0, 0.0)
end

function EnemyFrames.PrintDebug(msg, level)
    if EnemyFrames.DebugEnabled[level] == true then
        EnemyFrames.DebugChatFrame:AddMessage("|cffff8040EnemyFrames:|r DEBUG: " .. msg, 0.0, 1.0, 0.0)
    end
end

function EnemyFrames.HookedUIErrorsFrameOnEvent(event, msg)
    if EnemyFrames.HideUnknownUnitError == true and msg == EnemyFrames.UnknownUnitError then
        return
    end
    EnemyFrames.OriginalUIErrorsFrameOnEvent(event, msg)
end

-- Keep track of EFC in WSG
function EnemyFrames.ParseFlagEvent(msg)
    local myfaction = UnitFactionGroup("player")
    local spos, epos, faction, pname

    -- Flag picked up
    spos, epos, faction, pname = string.find(msg, EnemyFrames.FlagPicked)
    if spos ~= nil and faction == myfaction then
        EnemyFrames.PrintDebug("Our flag was picked up by " .. pname, "Flags")
        EnemyFrames.InitEnemyData(pname)
        EnemyFrames.EnemyData[pname].Flag = true
        return
    elseif spos ~= nil then
        return -- Only care about EFC
    end

    -- Flag dropped
    spos, epos, faction, pname = string.find(msg, EnemyFrames.FlagDropped)
    if spos ~= nil and faction == myfaction then
        EnemyFrames.PrintDebug("Our flag was dropped by " .. pname, "Flags")
        EnemyFrames.InitEnemyData(pname)
        EnemyFrames.EnemyData[pname].Flag = false
        return
    elseif spos ~= nil then
        return -- Only care about EFC
    end

    -- Flag Captured
    spos, epos, pname, faction = string.find(msg, EnemyFrames.FlagCaptured)
    if spos ~= nil and faction == myfaction then
        EnemyFrames.PrintDebug("Our flag was captured by " .. pname, "Flags")
        EnemyFrames.InitEnemyData(pname)
        EnemyFrames.EnemyData[pname].Flag = false
        return
    elseif spos ~= nil then
        return -- Only care about EFC
    end

    -- failed to parse this shit (ignore flag return messages)
    if string.find(msg, EnemyFrames.FlagReturn) == nil then
        EnemyFrames.PrintError("Failed to parse " .. event .. ": " .. msg)
    end
end

--[[
Apparently detecting a loading screen is a pain in the ass so we have to detect
PLAYER_ENTERING_WORLD and then wait a few seconds to do GetRealZoneText() because
the zone text does not yet update when the event fires. Bullshit!
If anyone knows a better way I'd gladly hear about it
]]--
function EnemyFrames.VerifyZoneEvent()
    EnemyFrames.PrintDebug("PLAYER_ENTERING_WORLD", "Zone")
    EnemyFrames.ZoneTimer = 5.0
end

function EnemyFrames.VerifyZoneUpdate(delta)
    if EnemyFrames.ZoneTimer == nil then
        return
    end
    
    EnemyFrames.ZoneTimer = EnemyFrames.ZoneTimer - delta
    if EnemyFrames.ZoneTimer <= 0.0 then

        if GetRealZoneText() ~= EnemyFrames.LastZone then 
            EnemyFrames.PrintDebug("We zoned", "Zone")
            EnemyFrames.LastZone = GetRealZoneText()
            EnemyFrames.ResetData()
        else
            EnemyFrames.PrintDebug("We did not zone: " .. GetRealZoneText() .. " == " .. EnemyFrames.LastZone, "Zone")
        end
        EnemyFrames.ZoneTimer = nil
    end
end

-- Handles enemy unit frame clicks and selects the enemy
function EnemyFrames.UnitClickEvent(unit)
    if EnemyFrames.UnitNames[unit:GetName()] then
        TargetByName(EnemyFrames.UnitNames[unit:GetName()], true)
    end
end

-- Removes all player data and restores all unit frames to the default state
function EnemyFrames.ResetData()
    EnemyFrames.EnemyData = {}
    EnemyFrames.UnitNames = {}
    for i = 1, EnemyFrames.MaxDisplayUnits do
        EnemyFrames["EnemyUnit" .. i]:Hide();
    end
end

-- Initialize the enemy unit frames when the addon is first loaded
function EnemyFrames.Init()
    for i = 1, EnemyFrames.MaxDisplayUnits do
        local yoffset = math.mod(i-1, 5) * -39 - 18
        local xoffset = math.floor((i-1) / 5) * 110
        EnemyFrames["EnemyUnit" .. i] = CreateFrame("Button", "EnemyUnit" .. i, EnemyUnits, "EnemyUnitTemplate");
        EnemyFrames["EnemyUnit" .. i]:SetPoint("TOPLEFT", EnemyUnits, "TOPLEFT", xoffset, yoffset);
    end
end

function EnemyFrames.OnEvent(event)
    if event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" or event == "CHAT_MSG_BG_SYSTEM_HORDE" then
        EnemyFrames.ParseFlagEvent(arg1)
    elseif event == "PLAYER_LOGIN" then
        EnemyFrames.Init()
    elseif event == "PLAYER_ENTERING_WORLD" then
        EnemyFrames.VerifyZoneEvent()
    else
        EnemyFrames.PrintError("Unhandled event: " .. event)
    end
end

function EnemyFrames.OnLoad()
    this:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE")
    this:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")
    this:RegisterEvent("PLAYER_LOGIN")
    this:RegisterEvent("PLAYER_ENTERING_WORLD")

    EnemyFrames.OriginalUIErrorsFrameOnEvent = UIErrorsFrame_OnEvent
    UIErrorsFrame_OnEvent = EnemyFrames.HookedUIErrorsFrameOnEvent
end


-- Initialize enemy data ONLY if the data for that player does not yet exist
function EnemyFrames.InitEnemyData(name)
    if EnemyFrames.EnemyData[name] then return end
    
    EnemyFrames.EnemyData[name] = {}
    EnemyFrames.EnemyData[name].Health      = 0
    EnemyFrames.EnemyData[name].HealthMax   = 1
    EnemyFrames.EnemyData[name].Power       = 0
    EnemyFrames.EnemyData[name].PowerMax    = 1
    EnemyFrames.EnemyData[name].PowerType   = 0
    EnemyFrames.EnemyData[name].Healer      = false
    EnemyFrames.EnemyData[name].Flag        = false
    EnemyFrames.EnemyData[name].Class       = "Warrior"
    EnemyFrames.EnemyData[name].Updated     = 0
end

-- Grab data from the specified unit, does nothing if the unit is not an enemy player
function EnemyFrames.GatherUnitData(unit)
    if not UnitExists(unit)
    or not UnitIsEnemy(unit, "player")
    or not UnitIsPlayer(unit)
    then
        return
    end
    EnemyFrames.PrintDebug("Found a useful unit to gather data from: " .. unit, "TargetData")
    
    local name = UnitName(unit)
    EnemyFrames.InitEnemyData(name)
    EnemyFrames.EnemyData[name].Health      = UnitHealth(unit)
    EnemyFrames.EnemyData[name].HealthMax   = UnitHealthMax(unit)
    EnemyFrames.EnemyData[name].Power       = UnitMana(unit)
    EnemyFrames.EnemyData[name].PowerMax    = UnitManaMax(unit)
    EnemyFrames.EnemyData[name].PowerType   = UnitPowerType(unit)
    EnemyFrames.EnemyData[name].Class       = UnitClass(unit)
    EnemyFrames.EnemyData[name].Updated     = time()
    EnemyFrames.EnemyData[name].LastScan    = time()
end

-- loop over the target of target of target of target... etc from any
-- given unit and pass it on to the unit gather function
function EnemyFrames.GatherDataTargets(unit)
    for i = 1,5 do
        unit = unit .. "target"
        EnemyFrames.GatherUnitData(unit)
    end
end

-- Gather enemy data from targets etc
EnemyFrames.GatherDataTimer = 0.25
function EnemyFrames.GatherDataUpdate(delta)
    EnemyFrames.GatherDataTimer = EnemyFrames.GatherDataTimer - delta
    if EnemyFrames.GatherDataTimer <= 0 then
        EnemyFrames.PrintDebug("Starting data gathering from target of target (of target ...)","TargetData")
        EnemyFrames.GatherDataTargets("player")
        for i = 1, 40 do
            if i < 5 then
                EnemyFrames.GatherDataTargets("party" .. i)
            end
            EnemyFrames.GatherDataTargets("raid" .. i)
        end
        EnemyFrames.GatherDataTimer = EnemyFrames.GatherDataTimer + 0.25
    end
end

-- Update all the unit frames that have data attached
EnemyFrames.UnitsUpdateTimer = 0.25
function EnemyFrames.UnitFramesUpdate(delta)
    EnemyFrames.UnitsUpdateTimer = EnemyFrames.UnitsUpdateTimer - delta
    if EnemyFrames.UnitsUpdateTimer <= 0 then
        EnemyFrames.PrintDebug("Going to update unit frames...", "DisplayUpdate")
        table.foreach(EnemyFrames.UnitNames, EnemyFrames.UpdateEnemyFrame)
        EnemyFrames.UnitsUpdateTimer = 0.25
    end
end

-- Update a single unit frame
function EnemyFrames.UpdateEnemyFrame(unit, name)
    local UnitData = EnemyFrames.EnemyData[name]
    EnemyFrames.PrintDebug("Updating" .. unit .. ": " .. name, "DisplayUpdate")

    -- If the frame wasnt scanned for 5 seconds we try to scan it
    if time() - UnitData.LastScan > 5 then
        UnitData.LastScan = time()
        EnemyFrames.TargetScan(name)
    end

    local classcolor = RAID_CLASS_COLORS[string.upper(UnitData.Class)]
    local manacolor = ManaBarColor[UnitData.PowerType]

    getglobal(unit .. "PlayerName"):SetTextColor(classcolor.r, classcolor.g, classcolor.b)
    getglobal(unit .. "Health"):SetMinMaxValues(0, UnitData.HealthMax)
    getglobal(unit .. "Health"):SetValue(UnitData.Health)
    getglobal(unit .. "PlayerName"):SetText(name)
    getglobal(unit .. "Power"):SetStatusBarColor(manacolor.r, manacolor.g, manacolor.b)
    getglobal(unit .. "Power"):SetMinMaxValues(0, UnitData.PowerMax)
    getglobal(unit .. "Power"):SetValue(UnitData.Power)

    -- Flag carriers get to be red
    if UnitData.Flag == true then
        getglobal(unit):SetBackdropColor(1.0, 0.0, 0.0)
    else
        getglobal(unit):SetBackdropColor(0.0, 0.0, 0.0)
    end

    -- Frames that aren't updated get phased out
    if UnitData.Flag == false  and time() - UnitData.Updated > 5 then
        getglobal(unit):SetAlpha(0.3)
    else
        getglobal(unit):SetAlpha(1.0)
    end

    getglobal(unit):Show()
end


-- Decide which unit frames to show out of our data set
-- For now its just a dumb function that takes the first MaxDisplayUnits
EnemyFrames.UnitsDisplayTimer = 5.0
function EnemyFrames.UnitsDisplayUpdate(delta)
    EnemyFrames.UnitsDisplayTimer = EnemyFrames.UnitsDisplayTimer - delta
    if EnemyFrames.UnitsDisplayTimer <= 0 then
        EnemyFrames.PrintDebug("Deciding what units to display", "DisplayUpdate")
        local count = 1
        table.foreach(EnemyFrames.EnemyData, function(name,data)
            if count <= EnemyFrames.MaxDisplayUnits then
                EnemyFrames.UnitNames["EnemyUnit" .. count] = name
                count = count + 1
            end
        end)
        EnemyFrames.UnitsDisplayTimer = EnemyFrames.UnitsDisplayTimer + 5.0
    end
end

-- Target something, scan it, and go back to the original target
function EnemyFrames.TargetScan(name)
    EnemyFrames.HideUnknownUnitError = true
    local curname = nil
    if UnitExists("target") then
        curname = UnitName("target")
        EnemyFrames.PrintDebug("Scanning ... have target " .. curname, "TargetScan")
    end

    if curname and curname == name then
        EnemyFrames.GatherUnitData("target")
        EnemyFrames.HideUnknownUnitError = false
        return
    end
    
    TargetByName(name, true)
    if (curname and curname == UnitName("target"))
    or (not curname and not UnitExists("target"))
    then
        EnemyFrames.PrintDebug("Scan failed for " .. name .. " probably out f range", "TargetScan")
    else 
        EnemyFrames.PrintDebug("Scanned" .. name, "TargetScan")
        EnemyFrames.GatherUnitData("target")
    end
    
    if curname and curname ~= UnitName("target")then
        TargetLastTarget()
    elseif not curname then
        ClearTarget()
    end
    
    EnemyFrames.HideUnknownUnitError = false
end
