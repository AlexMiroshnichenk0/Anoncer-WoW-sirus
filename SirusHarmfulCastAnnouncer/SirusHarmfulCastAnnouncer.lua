local addonName = ...
local frame = CreateFrame("Frame")

local defaults = {
    enabled = true,
    useRaidWarningFrame = true,
    channel = "AUTO",
    throttleSeconds = 1.5,
}

local state = {
    lastAnnounceAt = {},
}

local function MergeDefaults(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            target[key] = target[key] or {}
            MergeDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function IsHostileUnitByGUID(guid)
    if not guid then
        return false
    end

    local candidateUnits = {
        "target",
        "focus",
        "mouseover",
        "arena1", "arena2", "arena3", "arena4", "arena5",
        "boss1", "boss2", "boss3", "boss4", "boss5",
    }

    for _, unit in ipairs(candidateUnits) do
        if UnitExists(unit) and UnitGUID(unit) == guid and UnitCanAttack("player", unit) then
            return true
        end
    end

    local _, _, _, _, _, npcID = strsplit("-", guid)
    return npcID ~= nil
end

local function IsDuplicateAnnouncement(sourceGUID, spellID)
    local key = tostring(sourceGUID) .. ":" .. tostring(spellID)
    local now = GetTime()
    local previous = state.lastAnnounceAt[key]

    if previous and (now - previous) < SHCA_DB.throttleSeconds then
        return true
    end

    state.lastAnnounceAt[key] = now
    return false
end

local function ResolveChannel()
    if SHCA_DB.channel ~= "AUTO" then
        return SHCA_DB.channel
    end

    if UnitInRaid("player") then
        return "RAID"
    end

    if UnitInParty("player") then
        return "PARTY"
    end

    return "SAY"
end

local function Announce(message)
    if SHCA_DB.useRaidWarningFrame and RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, message, ChatTypeInfo["RAID_WARNING"])
    end

    SendChatMessage(message, ResolveChannel())
end

local function HandleCastStart(...)
    local _, eventType, _, sourceGUID, sourceName, sourceFlags, _, _, _, _, _, spellID, spellName = ...

    if eventType ~= "SPELL_CAST_START" then
        return
    end

    if not SHCA_DB.enabled then
        return
    end

    if bit.band(sourceFlags or 0, COMBATLOG_OBJECT_REACTION_HOSTILE) == 0 then
        return
    end

    if not IsHostileUnitByGUID(sourceGUID) then
        return
    end

    if IsDuplicateAnnouncement(sourceGUID, spellID) then
        return
    end

    local sourceText = sourceName or "Неизвестный"
    local spellText = spellName or ("SpellID " .. tostring(spellID or "?"))
    local message = string.format("|cffff4040[CAST]|r %s начинает каст: |cffffff00%s|r", sourceText, spellText)

    Announce(message)
end

local function PrintUsage()
    print("|cffff4040" .. addonName .. "|r команды:")
    print("  /shca on - включить")
    print("  /shca off - выключить")
    print("  /shca rw on|off - показывать предупреждение в центре")
    print("  /shca channel auto|say|party|raid - канал анонса")
    print("  /shca throttle <секунды> - антиспам")
    print("  /shca status - текущие настройки")
end

local function PrintStatus()
    print(string.format("|cffff4040%s|r: enabled=%s, rw=%s, channel=%s, throttle=%.1f",
        addonName,
        tostring(SHCA_DB.enabled),
        tostring(SHCA_DB.useRaidWarningFrame),
        SHCA_DB.channel,
        SHCA_DB.throttleSeconds
    ))
end

SLASH_SHCA1 = "/shca"
SlashCmdList.SHCA = function(msg)
    local command, arg = string.match((msg or ""), "^(%S*)%s*(.-)$")
    command = string.lower(command or "")
    arg = string.lower(arg or "")

    if command == "on" then
        SHCA_DB.enabled = true
        print("Sirus Harmful Cast Announcer включен.")
    elseif command == "off" then
        SHCA_DB.enabled = false
        print("Sirus Harmful Cast Announcer выключен.")
    elseif command == "rw" and (arg == "on" or arg == "off") then
        SHCA_DB.useRaidWarningFrame = (arg == "on")
        print("Центральное предупреждение: " .. arg)
    elseif command == "channel" and (arg == "auto" or arg == "say" or arg == "party" or arg == "raid") then
        SHCA_DB.channel = string.upper(arg)
        print("Канал анонса: " .. SHCA_DB.channel)
    elseif command == "throttle" then
        local seconds = tonumber(arg)
        if seconds and seconds >= 0 then
            SHCA_DB.throttleSeconds = seconds
            print("Антиспам: " .. string.format("%.1f", seconds) .. " сек.")
        else
            print("Укажите корректное значение, например: /shca throttle 1.5")
        end
    elseif command == "status" then
        PrintStatus()
    else
        PrintUsage()
    end
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedName = ...
        if loadedName ~= addonName then
            return
        end

        SHCA_DB = SHCA_DB or {}
        MergeDefaults(SHCA_DB, defaults)
        print("|cffff4040Sirus Harmful Cast Announcer|r загружен. /shca")
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        HandleCastStart(CombatLogGetCurrentEventInfo())
    end
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
