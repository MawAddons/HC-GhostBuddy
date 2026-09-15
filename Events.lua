local B = HCGhostBuddy
local frame = CreateFrame("Frame", "HCGhostBuddyEvents")
B.events = frame
for _, name in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "BAG_UPDATE_COOLDOWN",
    "BAG_UPDATE", "UNIT_INVENTORY_CHANGED", "PLAYER_DEAD", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT" }) do
    frame:RegisterEvent(name)
end
frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "HC-GhostBuddy" then B:Initialize()
    elseif event == "PLAYER_LOGIN" then B:Initialize()
    elseif B.DB then
        if event == "PLAYER_DEAD" then
            for id in pairs(B.profiles) do B:Clear(id, true) end
            B.preview = nil
        elseif event == "SPELL_GO_SELF" then B:SuccessfulCast(arg1, arg2, arg3)
        elseif event == "AUTO_ATTACK_OTHER" then B:Incoming(arg2, arg1, arg3, true)
        elseif event == "SPELL_DAMAGE_EVENT_OTHER" then B:Incoming(arg1, arg2, arg4)
        elseif event == "SPELL_START_OTHER" then
            -- The enemy's targeted cast can warn before damage lands.
            local hostile = arg3 and UnitCanAttack and UnitCanAttack("player", arg3)
            if arg4 and (hostile == true or hostile == 1) then B:Incoming(arg4, arg3, 0, true) end
        elseif string.find(event, "_GUID$", 1) then B:ObserveUnit(arg1)
        elseif event == "PLAYER_TARGET_CHANGED" then
            for _, state in pairs(B.states) do
                if not state.guid then state.manual, state.unit, state.hpAt = nil, nil, nil end
            end
            B:ObserveUnit("target"); B:ObserveUnit("targettarget")
        elseif event == "UPDATE_MOUSEOVER_UNIT" then B:ObserveUnit("mouseover")
        elseif event == "BAG_UPDATE_COOLDOWN" then B:ScanCooldowns()
        elseif event == "PLAYER_ENTERING_WORLD" or event == "BAG_UPDATE"
            or (event == "UNIT_INVENTORY_CHANGED" and arg1 == "player") then B.itemsDirty = true end
        B:Refresh()
    end
end)

-- A separate always-shown watcher keeps tracking while every icon is hidden.
local elapsed = 0
frame:SetScript("OnUpdate", function()
    if not B.DB then return end
    elapsed = elapsed + (arg1 or 0)
    if elapsed < 0.2 then return end
    elapsed = 0
    if B.itemsDirty or GetTime() >= (B.nextItems or 0) then
        B.itemsDirty = nil
        B.nextItems = GetTime() + 5
        B:DiscoverItems()
    end
    B:ScanCooldowns()
    B:PollUnits()
    B:Refresh()
end)
SLASH_HCGHOSTBUDDY1 = "/hcg"
SLASH_HCGHOSTBUDDY2 = "/ghostbuddy"
SlashCmdList["HCGHOSTBUDDY"] = function(message) B:Command(message) end
