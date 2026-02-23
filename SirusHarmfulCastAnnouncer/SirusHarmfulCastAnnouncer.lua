local addonName = ...
local frame = CreateFrame("Frame")

local defaults = {
    enabled = true,
    useRaidWarningFrame = true,
    useSound = true,
    soundPath = "Sound\\Interface\\RaidWarning.ogg",
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

    if SHCA_DB.useSound and PlaySoundFile then
        PlaySoundFile(SHCA_DB.soundPath)
    end

    SendChatMessage(message, ResolveChannel())
end

local function CreateOptionsPanel()
    local panel = CreateFrame("Frame", "SHCAOptionsPanel", InterfaceOptionsFramePanelContainer)
    panel.name = "Sirus Harmful Cast Announcer"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Sirus Harmful Cast Announcer")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Настройки анонса враждебных кастов")

    local enabledCheck = CreateFrame("CheckButton", "SHCAEnabledCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    enabledCheck:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", -2, -16)
    _G[enabledCheck:GetName() .. "Text"]:SetText("Включить аддон")
    enabledCheck:SetScript("OnClick", function(self)
        SHCA_DB.enabled = self:GetChecked() and true or false
    end)

    local rwCheck = CreateFrame("CheckButton", "SHCARWCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    rwCheck:SetPoint("TOPLEFT", enabledCheck, "BOTTOMLEFT", 0, -6)
    _G[rwCheck:GetName() .. "Text"]:SetText("Показывать предупреждение в центре")
    rwCheck:SetScript("OnClick", function(self)
        SHCA_DB.useRaidWarningFrame = self:GetChecked() and true or false
    end)

    local soundCheck = CreateFrame("CheckButton", "SHCASoundCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    soundCheck:SetPoint("TOPLEFT", rwCheck, "BOTTOMLEFT", 0, -6)
    _G[soundCheck:GetName() .. "Text"]:SetText("Проигрывать звуковой сигнал")
    soundCheck:SetScript("OnClick", function(self)
        SHCA_DB.useSound = self:GetChecked() and true or false
    end)

    local soundLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    soundLabel:SetPoint("TOPLEFT", soundCheck, "BOTTOMLEFT", 2, -16)
    soundLabel:SetText("Путь к звуку (Sound\\...):")

    local soundEditBox = CreateFrame("EditBox", "SHCASoundPathEditBox", panel, "InputBoxTemplate")
    soundEditBox:SetSize(350, 24)
    soundEditBox:SetPoint("TOPLEFT", soundLabel, "BOTTOMLEFT", 0, -8)
    soundEditBox:SetAutoFocus(false)
    soundEditBox:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        if text and text ~= "" then
            SHCA_DB.soundPath = text
        end
        self:ClearFocus()
    end)
    soundEditBox:SetScript("OnEscapePressed", function(self)
        self:SetText(SHCA_DB.soundPath)
        self:ClearFocus()
    end)

    local throttleSlider = CreateFrame("Slider", "SHCAThrottleSlider", panel, "OptionsSliderTemplate")
    throttleSlider:SetWidth(260)
    throttleSlider:SetPoint("TOPLEFT", soundEditBox, "BOTTOMLEFT", 8, -28)
    throttleSlider:SetMinMaxValues(0, 5)
    throttleSlider:SetValueStep(0.1)
    throttleSlider:SetObeyStepOnDrag(true)
    _G[throttleSlider:GetName() .. "Low"]:SetText("0")
    _G[throttleSlider:GetName() .. "High"]:SetText("5")

    local throttleText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    throttleText:SetPoint("BOTTOM", throttleSlider, "TOP", 0, 4)

    throttleSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = math.floor((value * 10) + 0.5) / 10
        SHCA_DB.throttleSeconds = rounded
        throttleText:SetText("Антиспам: " .. string.format("%.1f", rounded) .. " сек")
    end)

    local channelLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    channelLabel:SetPoint("TOPLEFT", throttleSlider, "BOTTOMLEFT", -8, -26)
    channelLabel:SetText("Канал анонса:")

    local channelDropDown = CreateFrame("Frame", "SHCAChannelDropDown", panel, "UIDropDownMenuTemplate")
    channelDropDown:SetPoint("TOPLEFT", channelLabel, "BOTTOMLEFT", -16, -6)

    UIDropDownMenu_SetWidth(channelDropDown, 140)
    UIDropDownMenu_Initialize(channelDropDown, function(self, level)
        local channels = {
            { text = "AUTO", value = "AUTO" },
            { text = "SAY", value = "SAY" },
            { text = "PARTY", value = "PARTY" },
            { text = "RAID", value = "RAID" },
        }

        for _, entry in ipairs(channels) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = entry.text
            info.value = entry.value
            info.func = function()
                SHCA_DB.channel = entry.value
                UIDropDownMenu_SetSelectedValue(channelDropDown, entry.value)
            end
            info.checked = (SHCA_DB.channel == entry.value)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    panel:SetScript("OnShow", function()
        enabledCheck:SetChecked(SHCA_DB.enabled)
        rwCheck:SetChecked(SHCA_DB.useRaidWarningFrame)
        soundCheck:SetChecked(SHCA_DB.useSound)
        soundEditBox:SetText(SHCA_DB.soundPath)
        throttleSlider:SetValue(SHCA_DB.throttleSeconds)
        throttleText:SetText("Антиспам: " .. string.format("%.1f", SHCA_DB.throttleSeconds) .. " сек")
        UIDropDownMenu_SetSelectedValue(channelDropDown, SHCA_DB.channel)
        UIDropDownMenu_SetText(channelDropDown, SHCA_DB.channel)
    end)

    InterfaceOptions_AddCategory(panel)
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
    print("  /shca sound on|off - включить/выключить звук")
    print("  /shca soundfile <путь> - путь к звуковому файлу")
    print("  /shca channel auto|say|party|raid - канал анонса")
    print("  /shca throttle <секунды> - антиспам")
    print("  /shca config - открыть окно настроек")
    print("  /shca status - текущие настройки")
end

local function PrintStatus()
    print(string.format("|cffff4040%s|r: enabled=%s, rw=%s, sound=%s, channel=%s, throttle=%.1f",
        addonName,
        tostring(SHCA_DB.enabled),
        tostring(SHCA_DB.useRaidWarningFrame),
        tostring(SHCA_DB.useSound),
        SHCA_DB.channel,
        SHCA_DB.throttleSeconds
    ))
    print("Путь звука: " .. SHCA_DB.soundPath)
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
    elseif command == "sound" and (arg == "on" or arg == "off") then
        SHCA_DB.useSound = (arg == "on")
        print("Звуковое оповещение: " .. arg)
    elseif command == "soundfile" and arg ~= "" then
        SHCA_DB.soundPath = msg:match("^%S+%s+(.+)$") or SHCA_DB.soundPath
        print("Путь к звуку: " .. SHCA_DB.soundPath)
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
    elseif command == "config" then
        InterfaceOptionsFrame_OpenToCategory("Sirus Harmful Cast Announcer")
        InterfaceOptionsFrame_OpenToCategory("Sirus Harmful Cast Announcer")
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
        CreateOptionsPanel()
        print("|cffff4040Sirus Harmful Cast Announcer|r загружен. /shca")
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        HandleCastStart(CombatLogGetCurrentEventInfo())
    end
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
