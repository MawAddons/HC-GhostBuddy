HCGhostBuddy = {
    VERSION = "1.2.0", COLORED_NAME = "|cffb8c0ccHC|r |cffa335eeGhost Buddy|r",
    states = {}, frames = {}, profiles = {}, enemies = {},
    aliases = { saber = 5332, ghost = 5332, timberling = 5218, timber = 5218 },
}
local B = HCGhostBuddy
B.defaults = {
    [5332] = { itemName = "Glowing Cat Figurine", unitName = "Ghost Saber", duration = 600,
        cooldown = 3600, icon = "Interface\\Icons\\Ability_Mount_WhiteTiger", spellID = 6084 },
    [5218] = { itemName = "Cleansed Timberling Heart", unitName = "Cleansed Timberling", duration = 1200,
        cooldown = 1800, icon = "Interface\\Icons\\Spell_Nature_NatureTouchGrow" },
}
-- Worg Pup is a companion, not a combat guardian.
B.excluded = { [12264] = true }

function B:ItemID(link)
    local _, _, id = string.find(link or "", "item:(%d+)")
    return tonumber(id) or tonumber(link)
end

function B:Resolve(value)
    local id = self.aliases[string.lower(value or "")] or tonumber(value)
    if id and self.profiles[id] then return id end
end

function B:CopyProfile(source)
    local result = {}
    for key, value in pairs(source) do result[key] = value end
    return result
end

function B:PetDB(id)
    if type(self.DB.pets[id]) ~= "table" then self.DB.pets[id] = {} end
    return self.DB.pets[id]
end

function B:SetupProfiles()
    for id, profile in pairs(self.defaults) do self.profiles[id] = self:CopyProfile(profile) end
    for id, profile in pairs(self.DB.custom) do
        if type(id) == "number" and not self.excluded[id] and type(profile) == "table"
            and type(profile.unitName) == "string" and type(profile.duration) == "number"
            and profile.duration > 0 and profile.duration <= 86400 then
            self.profiles[id] = self:CopyProfile(profile)
        end
    end
    for id in pairs(self.profiles) do self:PetDB(id) end
end

function B:Enabled(id)
    return id and self.profiles[id] and not self.excluded[id] and not self.DB.ignored[id]
end

function B:TooltipLines(kind, a, b)
    if not self.scanner then
        self.scanner = CreateFrame("GameTooltip", "HCGhostBuddyScanner", UIParent, "GameTooltipTemplate")
    end
    local tip = self.scanner
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    tip:ClearLines()
    if kind == "inventory" then tip:SetInventoryItem("player", a)
    elseif kind == "bag" then tip:SetBagItem(a, b)
    elseif kind == "unit" then tip:SetUnit(a) end
    local lines = {}
    for i = 1, tip:NumLines() do
        local line = getglobal("HCGhostBuddyScannerTextLeft" .. i)
        if line and line:GetText() then table.insert(lines, line:GetText()) end
    end
    tip:Hide()
    return lines
end

function B:ParseSummon(lines)
    -- Only explicit English combat-summon text with a duration is learned.
    for _, text in ipairs(lines) do
        local lower = string.lower(text)
        if string.find(lower, "summons ", 1, true)
            and (string.find(lower, "fight for you", 1, true) or string.find(lower, "protect you", 1, true)) then
            local _, _, name = string.find(text, "[Ss]ummons an? (.-) to ")
            local _, _, minutes = string.find(lower, "for (%d+%.?%d*) min")
            local _, _, seconds = string.find(lower, "for (%d+%.?%d*) sec")
            local duration = minutes and tonumber(minutes) * 60 or tonumber(seconds)
            if name and duration and duration > 0 and duration <= 86400 then return name, duration end
        end
    end
end

function B:LearnItem(id, kind, a, b)
    if not id or self.excluded[id] or self.DB.ignored[id] then return end
    local lines = self:TooltipLines(kind, a, b)
    local profile = self.profiles[id]
    if not profile and kind == "inventory" then
        local name, duration = self:ParseSummon(lines)
        if name and string.lower(name) ~= "worg pup" then
            profile = { itemName = lines[1] or tostring(id), unitName = name, duration = duration,
                icon = GetInventoryItemTexture("player", a) or "Interface\\Icons\\INV_Misc_QuestionMark" }
            self.profiles[id] = profile
            self.DB.custom[id] = self:CopyProfile(profile)
            self:PetDB(id)
            self:Print("Added combat summon: " .. name .. " (" .. self:FormatTime(duration) .. ").")
        end
    end
    if not profile then return end
    if not self.defaults[id] and kind == "inventory" then
        profile.icon = GetInventoryItemTexture("player", a) or profile.icon
    end
    -- Item record arrays are copied: Nampower otherwise reuses their tables.
    if GetItemStats then
        local ok, stats = pcall(GetItemStats, id, 1)
        if ok and type(stats) == "table" and type(stats.spellID) == "table" then
            for i = 1, 5 do
                if stats.spellID[i] and stats.spellID[i] > 0 and stats.spellTrigger and stats.spellTrigger[i] == 0 then
                    profile.spellID = stats.spellID[i]
                    local cooldown = stats.spellCooldown and tonumber(stats.spellCooldown[i])
                    if cooldown and cooldown > 120000 then profile.cooldown = cooldown / 1000 end
                    break
                end
            end
        end
    end
    if not profile.cooldown then
        for _, line in ipairs(lines) do
            local lower = string.lower(line)
            local _, _, minutes = string.find(lower, "cd:%s*(%d+%.?%d*)%s*min")
            if not minutes then _, _, minutes = string.find(lower, "(%d+%.?%d*)%s*min cooldown") end
            if minutes and tonumber(minutes) > 2 then profile.cooldown = tonumber(minutes) * 60; break end
        end
    end
    if self.DB.custom[id] then self.DB.custom[id] = self:CopyProfile(profile) end
end

function B:DiscoverItems()
    for slot = 13, 14 do
        self:LearnItem(self:ItemID(GetInventoryItemLink("player", slot)), "inventory", slot)
    end
    if GetContainerNumSlots then
        for bag = 0, 4 do
            for slot = 1, GetContainerNumSlots(bag) or 0 do
                local id = self:ItemID(GetContainerItemLink(bag, slot))
                if self:Enabled(id) then self:LearnItem(id, "bag", bag, slot) end
            end
        end
    end
end
