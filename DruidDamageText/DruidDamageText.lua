local addonName = ...

local DruidDamageText = CreateFrame("Frame")
DruidDamageText:RegisterEvent("ADDON_LOADED")
DruidDamageText:RegisterEvent("PLAYER_LOGIN")
DruidDamageText:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

local defaults = {
  color = "orange",
  fontSize = 38,
  critFontSize = 48,
  yOffset = -120,
}

local colors = {
  orange = {1.0, 0.52, 0.0},
  yellow = {1.0, 0.92, 0.35},
}

local activeAnimations = {}
local classFilename = ""

local function formatNumber(value)
  if value >= 1000000 then
    return string.format("%.1fm", value / 1000000)
  elseif value >= 1000 then
    return string.format("%.1fk", value / 1000)
  end

  return tostring(value)
end

local function getColor()
  local selected = DruidDamageTextDB and DruidDamageTextDB.color or defaults.color
  return unpack(colors[selected] or colors.orange)
end

local function createTextFrame()
  local frame = CreateFrame("Frame", nil, UIParent)
  frame:SetSize(260, 120)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, defaults.yOffset)

  frame.text = frame:CreateFontString(nil, "OVERLAY")
  frame.text:SetPoint("CENTER")
  frame.text:SetFont("Fonts\\FRIZQT__.TTF", defaults.fontSize, "OUTLINE")

  frame.elapsed = 0
  frame.duration = 0.95
  frame.startY = defaults.yOffset

  frame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    local progress = self.elapsed / self.duration

    if progress >= 1 then
      self:Hide()
      return
    end

    local y = self.startY + (progress * 75)
    self:SetPoint("CENTER", UIParent, "CENTER", 0, y)
    self.text:SetAlpha(1 - progress)
  end)

  return frame
end

local function getReusableFrame()
  for _, frame in ipairs(activeAnimations) do
    if not frame:IsShown() then
      return frame
    end
  end

  local frame = createTextFrame()
  table.insert(activeAnimations, frame)
  return frame
end

local function showDamage(amount, isCrit)
  local frame = getReusableFrame()
  local r, g, b = getColor()

  frame.elapsed = 0
  frame.startY = DruidDamageTextDB.yOffset or defaults.yOffset
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, frame.startY)

  local fontSize = isCrit and (DruidDamageTextDB.critFontSize or defaults.critFontSize) or (DruidDamageTextDB.fontSize or defaults.fontSize)
  frame.text:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
  frame.text:SetText(formatNumber(amount))
  frame.text:SetTextColor(r, g, b, 1)
  frame.text:SetAlpha(1)

  if isCrit then
    frame.text:SetShadowOffset(2, -2)
    frame.text:SetShadowColor(0, 0, 0, 0.95)
  else
    frame.text:SetShadowOffset(1, -1)
    frame.text:SetShadowColor(0, 0, 0, 0.7)
  end

  frame:Show()
end

local function printHelp()
  print("|cff76c0ffDruidDamageText|r: /dmgcolor orange | yellow")
end

SLASH_DRUIDDAMAGETEXT1 = "/dmgcolor"
SlashCmdList.DRUIDDAMAGETEXT = function(msg)
  msg = string.lower(strtrim(msg or ""))

  if colors[msg] then
    DruidDamageTextDB.color = msg
    print(string.format("|cff76c0ffDruidDamageText|r: color set to %s.", msg))
  else
    printHelp()
  end
end

DruidDamageText:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    local loadedAddon = ...
    if loadedAddon ~= addonName then
      return
    end

    DruidDamageTextDB = DruidDamageTextDB or {}
    for key, value in pairs(defaults) do
      if DruidDamageTextDB[key] == nil then
        DruidDamageTextDB[key] = value
      end
    end

    return
  end

  if event == "PLAYER_LOGIN" then
    classFilename = select(2, UnitClass("player"))
    return
  end

  if event ~= "COMBAT_LOG_EVENT_UNFILTERED" or classFilename ~= "DRUID" then
    return
  end

  local _, subevent, _, sourceGUID = CombatLogGetCurrentEventInfo()
  if sourceGUID ~= UnitGUID("player") then
    return
  end

  local damage, isCrit

  if subevent == "SWING_DAMAGE" then
    damage, _, _, _, _, _, _, _, isCrit = select(12, CombatLogGetCurrentEventInfo())
  elseif subevent == "SPELL_DAMAGE" or subevent == "RANGE_DAMAGE" then
    damage, _, _, _, _, _, _, _, isCrit = select(15, CombatLogGetCurrentEventInfo())
  end

  if damage and damage > 0 then
    showDamage(damage, isCrit)
  end
end)
