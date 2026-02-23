local addonName = ...
local frame = CreateFrame("Frame")

local defaults = {
    enabled = true,
    useRaidWarningFrame = true,
    useSound = true,
    soundPath = "Sound\\Interface\\RaidWarning.ogg",
    channel = "AUTO",
    throttleSeconds = 1.5,
    showSpellID = false,
    announceOnlyInGroup = false,
    lockWindow = false,
    theme = "DEFAULT",
    useElvUISkin = true,
}

local state = {
    lastAnnounceAt = {},
    configWindow = nil,
    controls = {},
}

local channelOrder = { "AUTO", "SAY", "PARTY", "RAID" }
local themeOrder = { "DEFAULT", "DARK", "CLASS" }

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

local function IsGrouped()
    return UnitInRaid("player") or UnitInParty("player")
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

local function PlayConfiguredSound()
    if SHCA_DB.useSound and PlaySoundFile then
        PlaySoundFile(SHCA_DB.soundPath)
    end
end

local function SafeSendChatMessage(message)
    local channel = ResolveChannel()
    local ok = pcall(SendChatMessage, message, channel)
    if not ok and channel ~= "SAY" then
        SendChatMessage(message, "SAY")
    end
end

local function Announce(message)
    if SHCA_DB.useRaidWarningFrame and RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, message, ChatTypeInfo["RAID_WARNING"])
    end

    PlayConfiguredSound()
    SafeSendChatMessage(message)
end

local function SetCheckButtonText(checkButton, text)
    local label = _G[checkButton:GetName() .. "Text"]
    if label then
        label:SetText(text)
    end
end

local function IsElvUIAvailable()
    return _G.ElvUI and type(_G.ElvUI) == "table" and _G.ElvUI[1] and _G.ElvUI[1].Skins
end

local function ApplyTheme()
    if not state.configWindow or not state.controls then
        return
    end

    local backdropR, backdropG, backdropB = 0.06, 0.06, 0.07
    local sectionR, sectionG, sectionB = 0.03, 0.03, 0.03

    if SHCA_DB.theme == "DARK" then
        backdropR, backdropG, backdropB = 0.02, 0.02, 0.02
        sectionR, sectionG, sectionB = 0.01, 0.01, 0.01
    elseif SHCA_DB.theme == "CLASS" then
        local _, class = UnitClass("player")
        local color = class and RAID_CLASS_COLORS[class]
        if color then
            backdropR = color.r * 0.25
            backdropG = color.g * 0.25
            backdropB = color.b * 0.25
            sectionR = color.r * 0.15
            sectionG = color.g * 0.15
            sectionB = color.b * 0.15
        end
    end

    state.configWindow:SetBackdropColor(backdropR, backdropG, backdropB, 0.92)

    local sections = state.controls.sections or {}
    for _, section in ipairs(sections) do
        section:SetBackdropColor(sectionR, sectionG, sectionB, 0.85)
    end

    if state.controls.themeButton then
        state.controls.themeButton:SetText(SHCA_DB.theme)
    end

    if SHCA_DB.useElvUISkin and IsElvUIAvailable() then
        local S = _G.ElvUI[1].Skins
        if not state.controls.elvSkinApplied then
            if S.HandleCloseButton then
                S:HandleCloseButton(state.controls.closeButton)
            end
            if S.HandleButton then
                S:HandleButton(state.controls.channelButton)
                S:HandleButton(state.controls.themeButton)
                S:HandleButton(state.controls.testSoundButton)
                S:HandleButton(state.controls.testMessageButton)
                S:HandleButton(state.controls.resetPosButton)
            end
            if S.HandleEditBox then
                S:HandleEditBox(state.controls.soundEditBox)
            end
            if S.HandleSliderFrame then
                S:HandleSliderFrame(state.controls.throttleSlider)
            end
            state.controls.elvSkinApplied = true
        end
    end
end

local function ApplyLockState()
    if not state.configWindow then
        return
    end

    if SHCA_DB.lockWindow then
        state.configWindow:SetAlpha(0.95)
    else
        state.configWindow:SetAlpha(1)
    end
end
local function CreateSection(parent, title, x, y, width, height)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(width, height)
    box:SetPoint("TOPLEFT", x, y)
    box:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    box:SetBackdropColor(0.03, 0.03, 0.03, 0.85)

    local label = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", 10, -8)
    label:SetText(title)
    box._shcaLabel = label

    return box
end

local function RefreshConfigWindow()
    if not state.configWindow then
        return
    end

    local c = state.controls
    c.enabledCheck:SetChecked(SHCA_DB.enabled)
    c.rwCheck:SetChecked(SHCA_DB.useRaidWarningFrame)
    c.soundCheck:SetChecked(SHCA_DB.useSound)
    c.spellIDCheck:SetChecked(SHCA_DB.showSpellID)
    c.groupOnlyCheck:SetChecked(SHCA_DB.announceOnlyInGroup)
    c.lockWindowCheck:SetChecked(SHCA_DB.lockWindow)
    c.elvuiCheck:SetChecked(SHCA_DB.useElvUISkin)
    c.soundEditBox:SetText(SHCA_DB.soundPath)
    c.channelButton:SetText(SHCA_DB.channel)
    c.throttleSlider:SetValue(SHCA_DB.throttleSeconds)
    c.throttleValue:SetText(string.format("%.1f сек", SHCA_DB.throttleSeconds))
    ApplyLockState()
    ApplyTheme()
end

local function CreateConfigWindow()
    if state.configWindow then
        return
    end

    local config = CreateFrame("Frame", "SHCAConfigWindow", UIParent)
    config:SetSize(470, 355)
    config:SetPoint("CENTER")
    config:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    config:EnableMouse(true)
    config:SetFrameStrata("DIALOG")
    config:SetToplevel(true)
    config:SetMovable(true)
    config:RegisterForDrag("LeftButton")
    config:SetScript("OnDragStart", function(self)
        if SHCA_DB.lockWindow then
            return
        end
        self:StartMoving()
    end)
    config:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    config:Hide()

    local title = config:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("Sirus Harmful Cast Announcer")

    local subtitle = config:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -4)
    subtitle:SetText("Быстрые и гибкие настройки анонса враждебных кастов")

    local closeButton = CreateFrame("Button", nil, config, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, -5)

    local leftSection = CreateSection(config, "Основное", 12, -54, 216, 208)
    local rightSection = CreateSection(config, "Звук и чат", 242, -54, 216, 208)
    local bottomSection = CreateSection(config, "Сервис", 12, -270, 446, 72)

    local enabledCheck = CreateFrame("CheckButton", "SHCAConfigEnabledCheck", leftSection, "UICheckButtonTemplate")
    enabledCheck:SetPoint("TOPLEFT", 10, -28)
    SetCheckButtonText(enabledCheck, "Включить аддон")

    local rwCheck = CreateFrame("CheckButton", "SHCAConfigRWCheck", leftSection, "UICheckButtonTemplate")
    rwCheck:SetPoint("TOPLEFT", enabledCheck, "BOTTOMLEFT", 0, -6)
    SetCheckButtonText(rwCheck, "Показывать в центре экрана")

    local spellIDCheck = CreateFrame("CheckButton", "SHCAConfigSpellIDCheck", leftSection, "UICheckButtonTemplate")
    spellIDCheck:SetPoint("TOPLEFT", rwCheck, "BOTTOMLEFT", 0, -6)
    SetCheckButtonText(spellIDCheck, "Добавлять SpellID в текст")

    local groupOnlyCheck = CreateFrame("CheckButton", "SHCAConfigGroupOnlyCheck", leftSection, "UICheckButtonTemplate")
    groupOnlyCheck:SetPoint("TOPLEFT", spellIDCheck, "BOTTOMLEFT", 0, -6)
    SetCheckButtonText(groupOnlyCheck, "Анонс только в группе/рейде")

    local lockWindowCheck = CreateFrame("CheckButton", "SHCAConfigLockCheck", leftSection, "UICheckButtonTemplate")
    lockWindowCheck:SetPoint("TOPLEFT", groupOnlyCheck, "BOTTOMLEFT", 0, -6)
    SetCheckButtonText(lockWindowCheck, "Закрепить окно настроек")

    local channelLabel = rightSection:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    channelLabel:SetPoint("TOPLEFT", 10, -30)
    channelLabel:SetText("Канал анонса:")

    local channelButton = CreateFrame("Button", nil, rightSection, "UIPanelButtonTemplate")
    channelButton:SetSize(120, 22)
    channelButton:SetPoint("TOPLEFT", channelLabel, "BOTTOMLEFT", 0, -6)

    local throttleLabel = rightSection:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    throttleLabel:SetPoint("TOPLEFT", channelButton, "BOTTOMLEFT", 0, -16)
    throttleLabel:SetText("Антиспам:")

    local throttleSlider = CreateFrame("Slider", "SHCAThrottleSlider", rightSection, "OptionsSliderTemplate")
    throttleSlider:SetPoint("TOPLEFT", throttleLabel, "BOTTOMLEFT", -6, -10)
    throttleSlider:SetWidth(160)
    throttleSlider:SetMinMaxValues(0, 5)
    throttleSlider:SetValueStep(0.1)
    throttleSlider:SetObeyStepOnDrag(true)
    _G[throttleSlider:GetName() .. "Low"]:SetText("0")
    _G[throttleSlider:GetName() .. "High"]:SetText("5")

    local throttleValue = rightSection:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    throttleValue:SetPoint("LEFT", throttleSlider, "RIGHT", 6, 0)

    local soundCheck = CreateFrame("CheckButton", "SHCAConfigSoundCheck", rightSection, "UICheckButtonTemplate")
    soundCheck:SetPoint("TOPLEFT", throttleSlider, "BOTTOMLEFT", 0, -14)
    SetCheckButtonText(soundCheck, "Звуковой сигнал")

    local themeLabel = rightSection:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    themeLabel:SetPoint("TOPLEFT", soundCheck, "BOTTOMLEFT", 8, -8)
    themeLabel:SetText("Тема:")

    local themeButton = CreateFrame("Button", nil, rightSection, "UIPanelButtonTemplate")
    themeButton:SetSize(100, 22)
    themeButton:SetPoint("LEFT", themeLabel, "RIGHT", 10, 0)

    local elvuiCheck = CreateFrame("CheckButton", "SHCAConfigElvUICheck", rightSection, "UICheckButtonTemplate")
    elvuiCheck:SetPoint("TOPLEFT", themeLabel, "BOTTOMLEFT", -8, -4)
    SetCheckButtonText(elvuiCheck, "Использовать ElvUI скин (если доступен)")

    local soundEditBox = CreateFrame("EditBox", nil, rightSection, "InputBoxTemplate")
    soundEditBox:SetSize(180, 20)
    soundEditBox:SetPoint("TOPLEFT", elvuiCheck, "BOTTOMLEFT", 8, -6)
    soundEditBox:SetAutoFocus(false)

    local testSoundButton = CreateFrame("Button", nil, rightSection, "UIPanelButtonTemplate")
    testSoundButton:SetSize(110, 22)
    testSoundButton:SetPoint("TOPLEFT", soundEditBox, "BOTTOMLEFT", -2, -8)
    testSoundButton:SetText("Тест звука")

    local statusText = bottomSection:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    statusText:SetPoint("TOPLEFT", 12, -28)
    statusText:SetText("/shca config - показать/скрыть это окно")

    local testMessageButton = CreateFrame("Button", nil, bottomSection, "UIPanelButtonTemplate")
    testMessageButton:SetSize(120, 24)
    testMessageButton:SetPoint("TOPRIGHT", -12, -22)
    testMessageButton:SetText("Тест анонса")

    local resetPosButton = CreateFrame("Button", nil, bottomSection, "UIPanelButtonTemplate")
    resetPosButton:SetSize(120, 24)
    resetPosButton:SetPoint("RIGHT", testMessageButton, "LEFT", -8, 0)
    resetPosButton:SetText("Сбросить позицию")

    enabledCheck:SetScript("OnClick", function(self)
        SHCA_DB.enabled = self:GetChecked() and true or false
    end)

    rwCheck:SetScript("OnClick", function(self)
        SHCA_DB.useRaidWarningFrame = self:GetChecked() and true or false
    end)

    spellIDCheck:SetScript("OnClick", function(self)
        SHCA_DB.showSpellID = self:GetChecked() and true or false
    end)

    groupOnlyCheck:SetScript("OnClick", function(self)
        SHCA_DB.announceOnlyInGroup = self:GetChecked() and true or false
    end)

    lockWindowCheck:SetScript("OnClick", function(self)
        SHCA_DB.lockWindow = self:GetChecked() and true or false
        ApplyLockState()
        if SHCA_DB.lockWindow then
            statusText:SetText("Окно закреплено (перетаскивание выключено).")
        else
            statusText:SetText("Окно разблокировано (можно перетаскивать).")
        end
    end)

    soundCheck:SetScript("OnClick", function(self)
        SHCA_DB.useSound = self:GetChecked() and true or false
    end)

    themeButton:SetScript("OnClick", function(self)
        local nextIndex = 1
        for i, value in ipairs(themeOrder) do
            if value == SHCA_DB.theme then
                nextIndex = i + 1
                break
            end
        end
        if nextIndex > #themeOrder then
            nextIndex = 1
        end
        SHCA_DB.theme = themeOrder[nextIndex]
        self:SetText(SHCA_DB.theme)
        ApplyTheme()
        statusText:SetText("Тема изменена: " .. SHCA_DB.theme)
    end)

    elvuiCheck:SetScript("OnClick", function(self)
        SHCA_DB.useElvUISkin = self:GetChecked() and true or false
        if not SHCA_DB.useElvUISkin then
            state.controls.elvSkinApplied = false
        end
        ApplyTheme()
        statusText:SetText("ElvUI-скин: " .. tostring(SHCA_DB.useElvUISkin))
    end)

    soundEditBox:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        if text and text ~= "" then
            SHCA_DB.soundPath = text
            statusText:SetText("Путь звука сохранен.")
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
        throttleValue:SetText(string.format("%.1f сек", rounded))
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
        PlayConfiguredSound()
        statusText:SetText("Звуковой тест выполнен.")
    end)

    testMessageButton:SetScript("OnClick", function()
        local message = "|cffff4040[CAST]|r Тестовый моб начинает каст: |cffffff00Огненная стрела|r"
        Announce(message)
        statusText:SetText("Тестовый анонс отправлен.")
    end)

    resetPosButton:SetScript("OnClick", function()
        config:ClearAllPoints()
        config:SetPoint("CENTER")
        statusText:SetText("Позиция окна сброшена в центр.")
    end)

    config:SetScript("OnShow", function()
        statusText:SetText("/shca config - показать/скрыть это окно")
        RefreshConfigWindow()
    end)

    state.controls = {
        enabledCheck = enabledCheck,
        rwCheck = rwCheck,
        soundCheck = soundCheck,
        spellIDCheck = spellIDCheck,
        groupOnlyCheck = groupOnlyCheck,
        lockWindowCheck = lockWindowCheck,
        elvuiCheck = elvuiCheck,
        soundEditBox = soundEditBox,
        channelButton = channelButton,
        themeButton = themeButton,
        throttleSlider = throttleSlider,
        throttleValue = throttleValue,
        testSoundButton = testSoundButton,
        testMessageButton = testMessageButton,
        resetPosButton = resetPosButton,
        closeButton = closeButton,
        sections = { leftSection, rightSection, bottomSection },
        elvSkinApplied = false,
    }

    state.configWindow = config
end

local function ToggleConfigWindow()
    if not state.configWindow then
        CreateConfigWindow()
    end

    if not state.configWindow then
        print("|cffff4040" .. addonName .. "|r: не удалось создать окно настроек.")
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

    if eventType ~= "SPELL_CAST_START" or not SHCA_DB.enabled then
        return
    end

    if bit.band(sourceFlags or 0, COMBATLOG_OBJECT_REACTION_HOSTILE) == 0 then
        return
    end

    if SHCA_DB.announceOnlyInGroup and not IsGrouped() then
        return
    end

    if IsDuplicateAnnouncement(sourceGUID, spellID) then
        return
    end

    local sourceText = sourceName or "Неизвестный"
    local spellText = spellName or ("SpellID " .. tostring(spellID or "?"))
    if SHCA_DB.showSpellID and spellID then
        spellText = spellText .. " |cffaaaaaa(" .. tostring(spellID) .. ")|r"
    end

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
    print("  /shca spellid on|off - добавлять ID заклинания")
    print("  /shca grouponly on|off - анонс только в группе")
    print("  /shca resetpos - сброс позиции окна")
    print("  /shca theme default|dark|class - тема окна")
    print("  /shca elvui on|off - ElvUI скин")
    print("  /shca test - тестовый анонс")
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
    print("SpellID в тексте: " .. tostring(SHCA_DB.showSpellID))
    print("Только в группе: " .. tostring(SHCA_DB.announceOnlyInGroup))
    print("Тема: " .. tostring(SHCA_DB.theme) .. ", ElvUI скин: " .. tostring(SHCA_DB.useElvUISkin))
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
    elseif command == "spellid" and (arg == "on" or arg == "off") then
        SHCA_DB.showSpellID = (arg == "on")
        print("SpellID в тексте: " .. arg)
    elseif command == "grouponly" and (arg == "on" or arg == "off") then
        SHCA_DB.announceOnlyInGroup = (arg == "on")
        print("Анонс только в группе: " .. arg)
    elseif command == "theme" and (arg == "default" or arg == "dark" or arg == "class") then
        SHCA_DB.theme = string.upper(arg)
        ApplyTheme()
        print("Тема окна: " .. SHCA_DB.theme)
    elseif command == "elvui" and (arg == "on" or arg == "off") then
        SHCA_DB.useElvUISkin = (arg == "on")
        if not SHCA_DB.useElvUISkin and state.controls then
            state.controls.elvSkinApplied = false
        end
        ApplyTheme()
        print("ElvUI-скин: " .. arg)
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
    elseif command == "test" then
        Announce("|cffff4040[CAST]|r Тестовый моб начинает каст: |cffffff00Огненная стрела|r")
    elseif command == "resetpos" then
        if not state.configWindow then
            CreateConfigWindow()
        end
        if state.configWindow then
            state.configWindow:ClearAllPoints()
            state.configWindow:SetPoint("CENTER")
            print("Позиция окна сброшена в центр.")
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
        print("|cffff4040Sirus Harmful Cast Announcer|r загружен. /shca")
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        HandleCastStart(CombatLogGetCurrentEventInfo())
    end
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
