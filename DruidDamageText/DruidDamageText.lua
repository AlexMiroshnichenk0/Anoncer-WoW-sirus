local addonName = ...

local DruidDamageText = CreateFrame("Frame")
DruidDamageText:RegisterEvent("ADDON_LOADED")
DruidDamageText:RegisterEvent("PLAYER_LOGIN")
DruidDamageText:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

local defaults = {
  fontSize = 38,
  critFontSize = 52,
  spellFontSize = 16,
  yOffset = -120,
  riseDistance = 90,
  duration = 0.95,
}

local normalColor = {1, 1, 1}
local critColor = {1.0, 0.52, 0.0}

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

local function createTextFrame()
  local frame = CreateFrame("Frame", nil, UIParent)
  frame:SetSize(300, 120)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, defaults.yOffset)

  frame.text = frame:CreateFontString(nil, "OVERLAY")
  frame.text:SetPoint("CENTER", 0, 10)
  frame.text:SetFont("Fonts\\FRIZQT__.TTF", defaults.fontSize, "OUTLINE")

  frame.spellText = frame:CreateFontString(nil, "OVERLAY")
  frame.spellText:SetPoint("TOP", frame.text, "BOTTOM", 0, -2)
  frame.spellText:SetFont("Fonts\\FRIZQT__.TTF", defaults.spellFontSize, "OUTLINE")

  frame.elapsed = 0
  frame.duration = defaults.duration
  frame.startX = 0
  frame.startY = defaults.yOffset
  frame.driftX = 0

  frame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    local progress = self.elapsed / self.duration

    if progress >= 1 then
      self:Hide()
      return
    end

    local smooth = 1 - ((1 - progress) * (1 - progress))
    local x = self.startX + (self.driftX * smooth)
    local y = self.startY + (smooth * (DruidDamageTextDB.riseDistance or defaults.riseDistance))

    self:SetPoint("CENTER", UIParent, "CENTER", x, y)
    self.text:SetAlpha(1 - progress)
    self.spellText:SetAlpha(1 - (progress * 1.05))
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

local function showDamage(amount, isCrit, spellName)
  local frame = getReusableFrame()
  local damageR, damageG, damageB = unpack(isCrit and critColor or normalColor)

  frame.elapsed = 0
  frame.startX = math.random(-70, 70)
  frame.startY = DruidDamageTextDB.yOffset or defaults.yOffset
  frame.driftX = math.random(-20, 20)
  frame:SetPoint("CENTER", UIParent, "CENTER", frame.startX, frame.startY)

  local fontSize = isCrit and (DruidDamageTextDB.critFontSize or defaults.critFontSize) or (DruidDamageTextDB.fontSize or defaults.fontSize)
  frame.text:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
  frame.text:SetText(formatNumber(amount))
  frame.text:SetTextColor(damageR, damageG, damageB, 1)
  frame.text:SetAlpha(1)

  frame.spellText:SetText(spellName or "")
  frame.spellText:SetTextColor(0.86, 0.95, 1, 0.95)

  if isCrit then
    frame.text:SetShadowOffset(2, -2)
    frame.text:SetShadowColor(0, 0, 0, 1)
  else
    frame.text:SetShadowOffset(1, -1)
    frame.text:SetShadowColor(0, 0, 0, 0.8)
  end

  frame:Show()
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

  local _, subevent, _, sourceGUID, _, _, _, _, _, _, _, spellId, spellName, _, amount, _, _, _, _, _, critical = CombatLogGetCurrentEventInfo()
  if sourceGUID ~= UnitGUID("player") then
    return
  end

  local damage, isCrit, shownSpell

  if subevent == "SWING_DAMAGE" then
    damage, _, _, _, _, _, _, _, isCrit = select(12, CombatLogGetCurrentEventInfo())
    shownSpell = "Атака"
  elseif subevent == "SPELL_DAMAGE" or subevent == "RANGE_DAMAGE" then
    damage = amount
    isCrit = critical
    shownSpell = spellName or (spellId and tostring(spellId)) or ""
  end

  if damage and damage > 0 then
    showDamage(damage, isCrit, shownSpell)
  end
end)
