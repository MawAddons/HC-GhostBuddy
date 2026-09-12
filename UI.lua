local Buddy = HCGhostBuddy

function Buddy:ApplyPosition()
    local frame = self.frame
    frame:SetWidth(self.DB.size)
    frame:SetHeight(self.DB.size)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", self.DB.x, self.DB.y)
    frame.timer:SetFont("Fonts\\FRIZQT__.TTF", math.max(10, math.floor(self.DB.size * 0.29)), "OUTLINE")
    frame.shade:SetHeight(math.max(14, math.floor(self.DB.size * 0.36)))
end

function Buddy:CreateIcon()
    local frame = CreateFrame("Button", "HCGhostBuddyIcon", UIParent)
    self.frame = frame
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:RegisterForClicks("LeftButtonUp")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.025, 0.07, 0.10, 0.95)
    frame:SetBackdropBorderColor(0.45, 0.90, 1.0, 1)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    icon:SetTexture("Interface\\Icons\\Ability_Mount_WhiteTiger")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon:SetVertexColor(0.65, 0.95, 1.0, 1)

    local shade = frame:CreateTexture(nil, "OVERLAY")
    frame.shade = shade
    shade:SetTexture(0, 0.025, 0.05, 0.85)
    shade:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 4, 4)
    shade:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    shade:SetHeight(16)

    local timer = frame:CreateFontString(nil, "OVERLAY")
    frame.timer = timer
    timer:SetPoint("BOTTOM", frame, "BOTTOM", 0, 5)
    timer:SetTextColor(0.80, 1, 1)

    local testLabel = frame:CreateFontString(nil, "OVERLAY")
    frame.testLabel = testLabel
    testLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    testLabel:SetPoint("TOP", frame, "TOP", 0, -5)
    testLabel:SetTextColor(1, 0.85, 0.30)
    testLabel:SetText("TEST")
    testLabel:Hide()

    local buddyName = frame:CreateFontString(nil, "OVERLAY")
    frame.buddyName = buddyName
    buddyName:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    buddyName:SetPoint("BOTTOM", frame, "TOP", 0, 4)
    buddyName:SetTextColor(0.75, 0.95, 1.0)
    buddyName:Hide()

    frame:SetScript("OnDragStart", function()
        if not Buddy.DB.locked or IsShiftKeyDown() then
            frame.dragging = true
            frame:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function()
        if not frame.dragging then return end
        frame:StopMovingOrSizing()
        frame.dragging = nil
        frame.wasDragged = true
        local x, y = frame:GetCenter()
        local parentX, parentY = UIParent:GetCenter()
        Buddy.DB.x = x - parentX
        Buddy.DB.y = y - parentY
        Buddy:ApplyPosition()
    end)
    frame:SetScript("OnClick", function()
        if frame.wasDragged then frame.wasDragged = nil; return end
        if TargetByName then
            TargetByName(Buddy.SABER_NAME, true)
        end
    end)
    frame:SetScript("OnEnter", function()
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
        GameTooltip:SetText(Buddy.COLORED_NAME, 1, 1, 1)
        GameTooltip:AddLine("MawAddons", 0.72, 0.75, 0.80)
        if Buddy.demo then
            GameTooltip:AddLine("Test countdown - no summon was triggered.", 1, 0.85, 0.3)
        elseif Buddy:Remaining() > 0 then
            GameTooltip:AddLine("Ghost Saber: " .. Buddy:FormatTime(Buddy:Remaining()) .. " remaining", 1, 1, 1)
        else
            GameTooltip:AddLine("Preview - use Glowing Cat Figurine to start.", 1, 1, 1)
        end
        GameTooltip:AddLine("10-minute duration estimate; ends early if the saber dies.", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("/hcg clear clears an early death or dismissal.", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Shift-drag: move.  /hcg help: options.", 0.55, 0.95, 1)
        GameTooltip:AddLine("Click: target your Ghost Saber.", 0.55, 0.95, 1)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame:SetScript("OnHide", function()
        if frame.dragging then
            frame:GetScript("OnDragStop")()
        end
        if GameTooltip:IsOwned(frame) then GameTooltip:Hide() end
    end)
    self:ApplyPosition()
    frame:Hide()
end

function Buddy:Refresh()
    if not self.frame then return end
    local remaining = self:Remaining()
    if remaining == 0 and self.endTime then
        self.endTime = nil
        self.usedAt = nil
        self.demo = nil
        self.DB.expiresAt = nil
        self.DB.usedAt = nil
    end
    local frame = self.frame
    if remaining <= 0 and not self.preview then frame:Hide(); return end
    frame.timer:SetText(self:FormatTime(remaining > 0 and remaining or self.DURATION))
    if self.DB.buddyName and self.DB.buddyName ~= "" then
        frame.buddyName:SetText(self.DB.buddyName)
        frame.buddyName:Show()
    else
        frame.buddyName:Hide()
    end
    if self.demo then frame.testLabel:Show() else frame.testLabel:Hide() end
    frame:SetAlpha(1)
    if remaining > 0 and remaining <= 30 then
        frame.timer:SetTextColor(1, 0.35, 0.25)
        frame:SetBackdropBorderColor(1, 0.3, 0.2, 1)
        frame:SetAlpha(0.8 + 0.2 * math.sin(GetTime() * 5))
    elseif remaining > 0 and remaining <= 60 then
        frame.timer:SetTextColor(1, 0.8, 0.25)
        frame:SetBackdropBorderColor(1, 0.7, 0.2, 1)
    else
        frame.timer:SetTextColor(0.80, 1, 1)
        frame:SetBackdropBorderColor(0.45, 0.90, 1.0, 1)
    end
    frame:Show()
end
