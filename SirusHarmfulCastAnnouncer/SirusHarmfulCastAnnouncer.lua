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
    configWindow = nil,
}

local channelOrder = { "AUTO", "SAY", "PARTY", "RAID" }

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

local function CreateLabel(parent, text, anchor, x, y)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint(anchor, x, y)
    label:SetText(text)
    return label
end

local function CreateConfigWindow()
    local config = CreateFrame("Frame", "SHCAConfigWindow", UIParent)
    config:SetSize(360, 280)
    config:SetPoint("CENTER")
    config:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    config:EnableMouse(true)
    config:SetMovable(true)
    config:RegisterForDrag("LeftButton")
    config:SetScript("OnDragStart", config.StartMoving)
    config:SetScript("OnDragStop", config.StopMovingOrSizing)
    config:Hide()

    local title = config:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText("Sirus Harmful Cast Announcer")

    local closeButton = CreateFrame("Button", nil, config, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, -5)

    local enabledCheck = CreateFrame("CheckButton", "SHCAConfigEnabledCheck", config, "UICheckButtonTemplate")
    enabledCheck:SetPoint("TOPLEFT", 16, -44)
    _G[enabledCheck:GetName() .. "Text"]:SetText("Включить аддон")

    local rwCheck = CreateFrame("CheckButton", "SHCAConfigRWCheck", config, "UICheckButtonTemplate")
    rwCheck:SetPoint("TOPLEFT", enabledCheck, "BOTTOMLEFT", 0, -8)
    _G[rwCheck:GetName() .. "Text"]:SetText("Центральное предупреждение")

    local soundCheck = CreateFrame("CheckButton", "SHCAConfigSoundCheck", config, "UICheckButtonTemplate")
    soundCheck:SetPoint("TOPLEFT", rwCheck, "BOTTOMLEFT", 0, -8)
    _G[soundCheck:GetName() .. "Text"]:SetText("Звуковой сигнал")

    CreateLabel(config, "Канал анонса:", "TOPLEFT", 16, -142)

    local channelButton = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
    channelButton:SetSize(110, 22)
    channelButton:SetPoint("TOPLEFT", 16, -162)

    CreateLabel(config, "Антиспам (сек):", "TOPLEFT", 16, -194)

    local throttleSlider = CreateFrame("Slider", "SHCAThrottleSlider", config, "OptionsSliderTemplate")
    throttleSlider:SetPoint("TOPLEFT", 10, -212)
    throttleSlider:SetWidth(220)
    throttleSlider:SetMinMaxValues(0, 5)
    throttleSlider:SetValueStep(0.1)
    throttleSlider:SetObeyStepOnDrag(true)
    _G[throttleSlider:GetName() .. "Low"]:SetText("0")
    _G[throttleSlider:GetName() .. "High"]:SetText("5")

    local throttleValue = config:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    throttleValue:SetPoint("LEFT", throttleSlider, "RIGHT", 8, 0)

    CreateLabel(config, "Звук (Sound\\...):", "TOPLEFT", 190, -44)

    local soundEditBox = CreateFrame("EditBox", nil, config, "InputBoxTemplate")
    soundEditBox:SetSize(150, 20)
    soundEditBox:SetPoint("TOPLEFT", 190, -62)
    soundEditBox:SetAutoFocus(false)

    local testSoundButton = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
    testSoundButton:SetSize(150, 22)
    testSoundButton:SetPoint("TOPLEFT", 190, -92)
    testSoundButton:SetText("Проверить звук")

    enabledCheck:SetScript("OnClick", function(self)
        SHCA_DB.enabled = self:GetChecked() and true or false
    end)

    rwCheck:SetScript("OnClick", function(self)
        SHCA_DB.useRaidWarningFrame = self:GetChecked() and true or false
    end)

    soundCheck:SetScript("OnClick", function(self)
        SHCA_DB.useSound = self:GetChecked() and true or false
    end)

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

    throttleSlider:SetScript("OnValueChanged", function(_, value)
        local rounded = math.floor((value * 10) + 0.5) / 10
        SHCA_DB.throttleSeconds = rounded
        throttleValue:SetText(string.format("%.1f", rounded))
    end)

    channelButton:SetScript("OnClick", function(self)
        local nextIndex = 1
        for i, value in ipairs(channelOrder) do
            if value == SHCA_DB.channel then
                nextIndex = i + 1
                break
            end
        end
        if nextIndex > #channelOrder then
            nextIndex = 1
        end
        SHCA_DB.channel = channelOrder[nextIndex]
        self:SetText(SHCA_DB.channel)
    end)

    testSoundButton:SetScript("OnClick", function()
        if PlaySoundFile then
            PlaySoundFile(SHCA_DB.soundPath)
        end
    end)

    config:SetScript("OnShow", function()
        enabledCheck:SetChecked(SHCA_DB.enabled)
        rwCheck:SetChecked(SHCA_DB.useRaidWarningFrame)
        soundCheck:SetChecked(SHCA_DB.useSound)
        channelButton:SetText(SHCA_DB.channel)
        throttleSlider:SetValue(SHCA_DB.throttleSeconds)
        throttleValue:SetText(string.format("%.1f", SHCA_DB.throttleSeconds))
        soundEditBox:SetText(SHCA_DB.soundPath)
    end)

    state.configWindow = config
end

local function ToggleConfigWindow()
    if not state.configWindow then
        return
    end

    if state.configWindow:IsShown() then
        state.configWindow:Hide()
    else
        state.configWindow:Show()
    end
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
    print("  /shca config - открыть/закрыть окно настроек")
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
        ToggleConfigWindow()
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
        CreateConfigWindow()
        print("|cffff4040Sirus Harmful Cast Announcer|r загружен. /shca")
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        HandleCastStart(CombatLogGetCurrentEventInfo())
    end
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
