local B = HCGhostBuddy

function B:ApplyPosition()
    self.anchor:ClearAllPoints()
    self.anchor:SetPoint("CENTER", UIParent, "CENTER", self.DB.x, self.DB.y)
end

function B:CreateAnchor()
    local anchor = CreateFrame("Frame", "HCGhostBuddyAnchor", UIParent)
    self.anchor = anchor
    anchor:SetWidth(44); anchor:SetHeight(44)
    anchor:SetMovable(true); anchor:SetClampedToScreen(true)
    self:ApplyPosition()
    local alert = CreateFrame("Frame", "HCGhostBuddyAlert", UIParent)
    self.alert = alert
    alert:SetFrameStrata("DIALOG")
    alert:SetWidth(620); alert:SetHeight(50)
    alert:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
    alert.text = alert:CreateFontString(nil, "OVERLAY")
    alert.text:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
    alert.text:SetPoint("CENTER", alert, "CENTER", 0, 0)
    alert.text:SetTextColor(1, 0.25, 0.15)
    alert:Hide()
end

function B:ShowAlert(message, test)
    if not test and not self.DB.alerts then return end
    self.alert.text:SetText(message)
    self.alert.untilTime = GetTime() + 4
    self.alert:Show()
    self:Print("|cffff6655" .. message .. "|r")
    if self.DB.sound and PlaySound and (test or GetTime() >= (self.nextSound or 0)) then
        PlaySound("RaidWarning")
        self.nextSound = GetTime() + 1
    end
end

function B:TargetBuddy(id)
    local state = self.states[id]
    if not state or state.demo then return end
    if state.guid and UnitExists(state.guid) then TargetUnit(state.guid)
    elseif state.unit and self:Matches(id, state.unit) then TargetUnit(state.unit)
    else TargetByName(self.profiles[id].unitName, true) end
end

local function resourceBar(frame, name, relative, offset)
    local bar = CreateFrame("StatusBar", frame:GetName() .. name, frame)
    bar:SetPoint("TOP", relative, "BOTTOM", 0, offset)
    bar:SetHeight(13)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar.background = bar:CreateTexture(nil, "BACKGROUND")
    bar.background:SetTexture(0.06, 0.07, 0.09, 0.95)
    bar.background:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    bar.background:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    bar.text = bar:CreateFontString(nil, "OVERLAY")
    bar.text:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    bar.text:SetTextColor(1, 1, 1)
    return bar
end

local function setResource(bar, current, maximum, r, g, b, unknown)
    bar:SetStatusBarColor(r, g, b)
    bar:SetMinMaxValues(0, maximum or 1)
    bar:SetValue(current or 0)
    bar.text:SetText(current and (math.floor(current) .. " / " .. math.floor(maximum)) or unknown)
end

function B:RefreshVitals(frame, state, size)
    local width = math.max(88, size)
    frame.health:SetWidth(width); frame.mana:SetWidth(width)
    if not state or state.demo then
        -- Clearly marked samples belong to preview/TEST mode only.
        setResource(frame.health, 80, 100, 0.2, 0.8, 0.3)
        setResource(frame.mana, 60, 100, 0.2, 0.5, 1)
        frame.mana:Show()
        return
    end
    local hp = state.hpAt and GetTime() - state.hpAt < 1 and state.hp
    local low = hp and state.maxHP and hp / state.maxHP <= 0.4
    setResource(frame.health, hp, hp and state.maxHP, low and 0.95 or 0.2, low and 0.2 or 0.8, 0.3, "HP --")
    if state.hasMana then
        local mana = state.manaAt and GetTime() - state.manaAt < 1 and state.mana
        setResource(frame.mana, mana, mana and state.maxMana, 0.2, 0.5, 1, "Mana --")
        frame.mana:Show()
    else frame.mana:Hide() end
end

function B:CreateIcon(id)
    local frame = CreateFrame("Button", "HCGhostBuddyIcon" .. id, self.anchor)
    self.frames[id] = frame
    frame:SetFrameStrata("MEDIUM")
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    frame:SetBackdropColor(0.025, 0.07, 0.10, 0.95)
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    frame.icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    frame.shade = frame:CreateTexture(nil, "OVERLAY")
    frame.shade:SetTexture(0, 0.025, 0.05, 0.85)
    frame.shade:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 4, 4)
    frame.shade:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    frame.timer = frame:CreateFontString(nil, "OVERLAY")
    frame.timer:SetPoint("BOTTOM", frame, "BOTTOM", 0, 5)
    frame.name = frame:CreateFontString(nil, "OVERLAY")
    frame.name:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    frame.name:SetPoint("BOTTOM", frame, "TOP", 0, 4)
    frame.name:SetTextColor(0.75, 0.95, 1)
    frame.label = frame:CreateFontString(nil, "OVERLAY")
    frame.label:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    frame.label:SetPoint("TOP", frame, "TOP", 0, -5)
    frame.label:SetTextColor(1, 0.7, 0.2)
    frame.health = resourceBar(frame, "Health", frame, -3)
    frame.mana = resourceBar(frame, "Mana", frame.health, -2)
    frame:SetScript("OnDragStart", function()
        if not B.DB.locked or IsShiftKeyDown() then
            frame.dragging = true
            B.anchor:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function()
        if not frame.dragging then return end
        B.anchor:StopMovingOrSizing()
        frame.dragging, frame.dragStoppedAt = nil, GetTime()
        local x, y = B.anchor:GetCenter()
        local px, py = UIParent:GetCenter()
        B.DB.x, B.DB.y = x - px, y - py
        B:ApplyPosition()
    end)
    frame:SetScript("OnClick", function()
        if frame.dragStoppedAt and GetTime() - frame.dragStoppedAt < 0.3 then return end
        if arg1 == "RightButton" then
            B.selected, B.DB.selected = id, id
            B:Print("Selected " .. B:DisplayName(id) .. ". Rename with /hcg name Your Name.")
        else B:TargetBuddy(id) end
    end)
    frame:SetScript("OnEnter", function()
        local profile, state = B.profiles[id], B.states[id]
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
        GameTooltip:SetText(B.COLORED_NAME, 1, 1, 1)
        GameTooltip:AddLine("MawAddons", 0.72, 0.75, 0.80)
        GameTooltip:AddLine(B:DisplayName(id) .. " (" .. profile.unitName .. ")", 1, 1, 1)
        GameTooltip:AddLine(profile.itemName, 0.7, 0.9, 0.7)
        GameTooltip:AddLine(state and (state.demo and "TEST countdown" or "Estimated remaining: " .. B:FormatTime(B:Remaining(id)))
            or "Preview - use the summon item to start.", 1, 1, 1)
        if state and not state.demo then
            GameTooltip:AddLine(state.guid and "Bound to a specific summon." or "Awaiting summon identification: target or hover your buddy.", 1, 0.8, 0.4)
            if state.hpAt and GetTime() - state.hpAt < 1 then
                GameTooltip:AddLine("Health: " .. state.hp .. " / " .. state.maxHP, 0.7, 1, 0.7)
            else GameTooltip:AddLine("Health: unavailable (HP --).", 0.7, 0.7, 0.7) end
            if state.hasMana then
                if state.manaAt and GetTime() - state.manaAt < 1 then
                    GameTooltip:AddLine("Mana: " .. state.mana .. " / " .. state.maxMana, 0.5, 0.7, 1)
                else GameTooltip:AddLine("Mana: unavailable (Mana --).", 0.7, 0.7, 0.7) end
            end
        else
            GameTooltip:AddLine("Sample health/mana bars; not live summon values.", 1, 0.8, 0.4)
        end
        GameTooltip:AddLine("Click: target. Right-click: select for naming.", 0.55, 0.95, 1)
        GameTooltip:AddLine("Shift-drag: move. /hcg help: commands.", 0.55, 0.95, 1)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame:SetScript("OnHide", function()
        if frame.dragging then frame:GetScript("OnDragStop")() end
        if GameTooltip:IsOwned(frame) then GameTooltip:Hide() end
    end)
    frame:Hide()
    return frame
end

function B:Refresh()
    if not self.anchor then return end
    if self.alert.untilTime and GetTime() >= self.alert.untilTime then self.alert:Hide() end
    local index, size = 0, self.DB.size
    for _, id in ipairs(self:OrderedIDs()) do
        local remaining = self:Remaining(id)
        if self.states[id] and remaining <= 0 then self:Clear(id) end
        local state = self.states[id]
        local visible = self:Enabled(id) and (state or self.preview)
        local frame = self.frames[id]
        if visible then
            frame = frame or self:CreateIcon(id)
            frame:SetWidth(size); frame:SetHeight(size)
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", self.anchor, "CENTER", index * math.max(100, size + 20), 0)
            frame.name:SetWidth(math.max(96, size + 16)); frame.name:SetHeight(28)
            frame.timer:SetFont("Fonts\\FRIZQT__.TTF", math.max(10, math.floor(size * 0.29)), "OUTLINE")
            frame.shade:SetHeight(math.max(14, math.floor(size * 0.36)))
            frame.icon:SetTexture(self.profiles[id].icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            frame.name:SetText(self:DisplayName(id))
            frame.timer:SetText(self:FormatTime(state and remaining or self.profiles[id].duration))
            local danger = state and state.dangerUntil and state.dangerUntil > GetTime() and state.danger
            frame.label:SetText(not state and "DEMO" or (state.demo and "TEST" or danger or ""))
            self:RefreshVitals(frame, state, size)
            frame:SetAlpha(1)
            if danger or (state and remaining <= 30) then
                frame.timer:SetTextColor(1, 0.35, 0.25); frame:SetBackdropBorderColor(1, 0.3, 0.2, 1)
                frame:SetAlpha(0.8 + 0.2 * math.sin(GetTime() * 5))
            elseif state and remaining <= 60 then
                frame.timer:SetTextColor(1, 0.8, 0.25); frame:SetBackdropBorderColor(1, 0.7, 0.2, 1)
            else
                frame.timer:SetTextColor(0.8, 1, 1); frame:SetBackdropBorderColor(0.45, 0.9, 1, 1)
            end
            frame:Show()
            index = index + 1
        elseif frame then frame:Hide() end
    end
end
