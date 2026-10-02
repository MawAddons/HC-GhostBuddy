local B = HCGhostBuddy
local function yes(value) return value == 1 or value == true end

function B:ValidGUID(value)
    if type(value) == "string" and string.find(value, "^0x%x+$")
        and not string.find(value, "^0x0+$") then return string.lower(value) end
end

function B:GUID(unit)
    if GetUnitGUID then
        local ok, guid = pcall(GetUnitGUID, unit)
        if ok then return self:ValidGUID(guid) end
    end
    if UnitExists then
        local _, guid = UnitExists(unit)
        return self:ValidGUID(guid)
    end
end

function B:Field(unit, key)
    if not GetUnitField then return end
    local ok, value = pcall(GetUnitField, unit, key)
    if ok then return value end
end

function B:Owner(unit)
    local player = self:GUID("player")
    local summon = self:ValidGUID(self:Field(unit, "summonedBy"))
    local creator = self:ValidGUID(self:Field(unit, "createdBy"))
    if player and (summon or creator) then return summon == player or creator == player end
    if UnitIsUnit and yes(UnitIsUnit(unit, "pet")) then return true end
    -- Stock-client fallback: an exact owner line, never just the creature name.
    if not GetUnitField then
        local playerName = UnitName("player")
        if playerName then
            for _, line in ipairs(self:TooltipLines("unit", unit)) do
                if line == playerName .. "'s Minion" or line == playerName .. "'s Guardian"
                    or line == playerName .. "'s Pet" then return true end
            end
        end
    end
    return nil
end

function B:Matches(id, unit)
    if not UnitExists or not UnitExists(unit) or not yes(UnitIsFriend("player", unit)) then return false end
    local profile = self.profiles[id]
    local name = UnitName(unit)
    if name == profile.unitName then return true end
    if profile.unitNames then
        for _, validName in ipairs(profile.unitNames) do if name == validName then return true end end
    end
    return profile.spellID and self:Field(unit, "createdBySpell") == profile.spellID
end

function B:Bind(id, unit, manual)
    local state = self.states[id]
    if not state or state.demo or self:Remaining(id) <= 0 or not self:Matches(id, unit) then return false end
    local owner = self:Owner(unit)
    if owner == false or (owner ~= true and not manual) then return false end
    local guid = self:GUID(unit)
    if state.guid and guid and state.guid ~= guid then return false end
    state.guid, state.unit, state.manual = guid, unit, manual or state.manual
    state.boundAt = GetTime()
    self:PetDB(id).guid = guid
    return true
end

function B:FindBuddy(unit)
    if not unit or not UnitExists or not UnitExists(unit) then return end
    local guid = self:GUID(unit)
    for id, state in pairs(self.states) do
        if not state.demo and self:Remaining(id) > 0 then
            if state.guid and guid == state.guid and self:Matches(id, unit) then
                state.unit = unit
                return id
            elseif not state.guid and self:Bind(id, unit) then return id
            -- On an unmodified client a manually selected token is only trusted
            -- while it is still visibly the selected summon. It cannot be retained
            -- as a permanent identity after the target changes.
            elseif not guid and state.manual and state.unit == unit and self:Matches(id, unit) then return id end
        end
    end
end

function B:RaiseDanger(id, kind)
    local state = self.states[id]
    if not state or state.demo or self:Remaining(id) <= 0 then return end
    local now = GetTime()
    local rank = kind == "LOW HP" and 2 or 1
    if state.danger == "LOW HP" and kind ~= "LOW HP" and (state.dangerUntil or 0) > now then
        -- Keep the more urgent label visible while the enemy still targets it.
    else state.danger, state.dangerUntil = kind, now + 2 end
    if not self.DB.alerts then return end
    if state.lastAlert and now - state.lastAlert < 6 and rank <= (state.lastRank or 0) then return end
    state.lastAlert, state.lastRank = now, rank
    local suffix = kind == "AGGRO" and " has AGGRO!" or (kind == "LOW HP" and " has LOW HP!" or " is taking damage!")
    self:ShowAlert(self:DisplayName(id) .. suffix)
end

function B:CheckEnemy(unit)
    if not UnitExists or not UnitExists(unit) or not yes(UnitCanAttack("player", unit)) then return end
    if UnitAffectingCombat and not yes(UnitAffectingCombat(unit)) then return end
    local target = self:ValidGUID(self:Field(unit, "target")) or (unit .. "target")
    local id = self:FindBuddy(target)
    if id then self:RaiseDanger(id, "AGGRO") end
end

function B:ObserveUnit(unit)
    if not unit or not next(self.states) or not UnitExists or not UnitExists(unit) then return end
    self:FindBuddy(unit)
    self:CheckEnemy(unit)
    local guid = self:GUID(unit)
    if guid and yes(UnitCanAttack("player", unit)) then
        -- Bounded cache of recently visible opponents, refreshed by unit events.
        local count = 0
        for key, expiry in pairs(self.enemies) do
            if expiry < GetTime() then self.enemies[key] = nil else count = count + 1 end
        end
        if self.enemies[guid] or count < 128 then self.enemies[guid] = GetTime() + 10 end
    end
end

function B:Incoming(target, attacker, damage, direct)
    if not next(self.states) then return end
    local id = self:FindBuddy(target)
    if not id then return end
    self:ObserveUnit(attacker)
    if direct then self:RaiseDanger(id, "AGGRO")
    elseif tonumber(damage) and tonumber(damage) > 0 then self:RaiseDanger(id, "HURT") end
    self:ReadVitals(id)
end

function B:ReadVitals(id)
    local state = self.states[id]
    if not state or state.demo or self:Remaining(id) <= 0 then return end
    state.hpAt, state.manaAt = nil, nil
    local unit = state.guid or state.unit
    if not unit or not UnitExists(unit) or not self:Matches(id, unit) then return end
    if not state.guid and self:Owner(unit) ~= true and not state.manual then return end

    -- Vanilla UnitMana also returns rage/focus/energy: only label actual mana.
    -- Read it independently, since one resource can be unavailable while the
    -- other still has a valid observation.
    local powerType = UnitPowerType and UnitPowerType(unit)
    if powerType == 0 then
        local mana = tonumber((self:Field(unit, "power1"))) or (UnitMana and tonumber((UnitMana(unit))))
        local maxMana = tonumber((self:Field(unit, "maxPower1"))) or (UnitManaMax and tonumber((UnitManaMax(unit))))
        if maxMana and maxMana > 0 then
            state.hasMana = true
            if mana and mana >= 0 then
                state.mana, state.maxMana, state.manaAt = math.min(mana, maxMana), maxMana, GetTime()
            end
        elseif maxMana == 0 then state.hasMana = nil end
    elseif powerType ~= nil then state.hasMana = nil end

    local hp = tonumber((self:Field(unit, "health"))) or (UnitHealth and tonumber((UnitHealth(unit))))
    local maxHP = tonumber((self:Field(unit, "maxHealth"))) or (UnitHealthMax and tonumber((UnitHealthMax(unit))))
    if not hp or not maxHP or maxHP <= 0 then return end
    state.hp, state.maxHP, state.hpAt = math.max(0, math.min(hp, maxHP)), maxHP, GetTime()
    if hp <= 0 then
        if self.DB.alerts then self:ShowAlert(self:DisplayName(id) .. " died.") end
        self:Clear(id, true)
    elseif hp / maxHP <= 0.4 then self:RaiseDanger(id, "LOW HP") end
end

function B:PollUnits()
    if not next(self.states) then self.enemies = {}; return end
    local units = { "pet", "target", "mouseover", "targettarget", "pettarget" }
    for i = 1, 4 do table.insert(units, "party" .. i .. "target"); table.insert(units, "party" .. i .. "targettarget") end
    if GetNumRaidMembers then
        for i = 1, GetNumRaidMembers() do table.insert(units, "raid" .. i .. "target") end
    end
    for _, unit in ipairs(units) do self:ObserveUnit(unit) end
    local summon = self:ValidGUID(self:Field("player", "summon"))
    if summon then self:ObserveUnit(summon) end
    for id, state in pairs(self.states) do
        if not state.demo then
            if state.guid then
                self:CheckEnemy(self:ValidGUID(self:Field(state.guid, "target")) or (state.guid .. "target"))
            end
            self:ReadVitals(id)
        end
    end
    for guid, expiry in pairs(self.enemies) do
        if expiry < GetTime() then self.enemies[guid] = nil else self:CheckEnemy(guid) end
    end
    -- Optional GUIDs on nameplates help discovery before the first hit.
    if (self.enhanced or SUPERWOW_VERSION) and WorldFrame and GetTime() >= (self.nextPlates or 0) then
        self.nextPlates = GetTime() + 0.5
        local children = { WorldFrame:GetChildren() }
        for _, frame in ipairs(children) do
            if frame:IsShown() then
                local ok, guid = pcall(frame.GetName, frame, 1)
                guid = ok and self:ValidGUID(guid)
                if guid then self:ObserveUnit(guid) end
            end
        end
    end
end

function B:EnableEvents()
    self.enhanced = type(GetUnitField) == "function" and type(GetUnitGUID) == "function"
    if not self.enhanced then return end
    -- Enable only the event streams used here. Never turn streams off, since
    -- other addons may also consume them. Older builds may lack some CVars.
    if GetCVar and SetCVar then
        for _, name in ipairs({ "NP_EnableSpellGoEvents", "NP_EnableAutoAttackEvents", "NP_EnableSpellStartEvents" }) do
            local ok, current = pcall(GetCVar, name)
            if ok and current and current ~= "1" then pcall(SetCVar, name, "1") end
        end
    end
    for _, name in ipairs({ "SPELL_GO_SELF", "SPELL_START_OTHER", "AUTO_ATTACK_OTHER", "SPELL_DAMAGE_EVENT_OTHER",
        "UNIT_HEALTH_GUID", "UNIT_FLAGS_GUID", "UNIT_NAME_UPDATE_GUID", "UNIT_PET_GUID" }) do
        pcall(self.events.RegisterEvent, self.events, name)
    end
end
