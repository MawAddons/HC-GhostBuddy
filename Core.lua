local B = HCGhostBuddy

function B:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage(self.COLORED_NAME .. ": " .. message)
end

function B:FormatTime(seconds)
    seconds = math.max(0, math.ceil(seconds))
    local minutes = math.floor(seconds / 60)
    return string.format("%d:%02d", minutes, seconds - minutes * 60)
end

function B:Remaining(id)
    local state = self.states[id or self.selected]
    return state and math.max(0, state.endTime - GetTime()) or 0
end

function B:DisplayName(id)
    local name = self:PetDB(id).name
    return name and name ~= "" and name or self.profiles[id].unitName
end

function B:CleanName(value)
    value = string.gsub(value or "", "[|%c]", "")
    value = string.gsub(string.gsub(value, "^%s+", ""), "%s+$", "")
    local result, count = "", 0
    -- Keep UTF-8 characters intact, including Danish names.
    for character in string.gfind(value, "[%z\1-\127\194-\244][\128-\191]*") do
        if count == 24 then break end
        result, count = result .. character, count + 1
    end
    return result
end

function B:Start(id, age, demo)
    if not self:Enabled(id) then return end
    local profile, db = self.profiles[id], self:PetDB(id)
    age = age or 0
    if age < 0 or age >= profile.duration then return end
    local usedAt = time() - age
    if not demo and tonumber(db.dismissedUse) and math.abs(db.dismissedUse - usedAt) < 3 then return end
    local previous = self.states[id]
    if previous and not previous.demo and not demo and math.abs(previous.usedAt - usedAt) < 3 then return previous end
    local state = { endTime = GetTime() + profile.duration - age, usedAt = usedAt, demo = demo }
    self.states[id] = state
    if not demo then
        db.usedAt, db.expiresAt, db.dismissedUse, db.guid = usedAt, usedAt + profile.duration, nil, nil
    end
    return state
end

function B:ObserveCooldown(id, start, duration, enabled)
    local profile = self.profiles[id]
    if not self:Enabled(id) or not profile.cooldown or profile.cooldown <= 120 then return end
    if type(start) ~= "number" or type(duration) ~= "number" or enabled ~= 1 then return end
    if math.abs(duration - profile.cooldown) > 5 then return end
    local age = GetTime() - start
    if age < 0 or age >= profile.duration then return end
    self.cooldownStarts = self.cooldownStarts or {}
    if self.cooldownStarts[id] and math.abs(self.cooldownStarts[id] - start) < 1 then return end
    self.cooldownStarts[id] = start
    self:Start(id, age)
end

function B:ScanCooldowns()
    for slot = 13, 14 do
        local id = self:ItemID(GetInventoryItemLink("player", slot))
        if self:Enabled(id) then self:ObserveCooldown(id, GetInventoryItemCooldown("player", slot)) end
    end
end

function B:SuccessfulCast(itemID, spellID, casterGUID)
    local playerGUID = self:GUID("player")
    casterGUID = self:ValidGUID(casterGUID)
    if casterGUID and playerGUID and casterGUID ~= playerGUID then return end
    itemID = tonumber(itemID)
    if itemID and itemID > 0 then
        if self:Enabled(itemID) then self:Start(itemID, 0) end
        return
    end
    for id, profile in pairs(self.profiles) do
        if spellID and profile.spellID == tonumber(spellID) and self:Enabled(id) then self:Start(id, 0) end
    end
end

function B:Clear(id, dismiss)
    id = id or self.selected
    local state, db = self.states[id], self:PetDB(id)
    if dismiss and state and not state.demo then db.dismissedUse = state.usedAt end
    self.states[id] = nil
    db.usedAt, db.expiresAt, db.guid = nil, nil, nil
end

function B:Initialize()
    if self.DB then return end
    if type(HCGhostBuddyDB) ~= "table" then HCGhostBuddyDB = {} end
    local db = HCGhostBuddyDB
    self.DB = db
    for _, key in ipairs({ "pets", "custom", "ignored" }) do
        if type(db[key]) ~= "table" then db[key] = {} end
    end
    if db.schema ~= 2 then
        local pet = self:PetDB(5332)
        pet.name = self:CleanName(db.buddyName or "")
        pet.usedAt, pet.expiresAt, pet.dismissedUse = tonumber(db.usedAt), tonumber(db.expiresAt), tonumber(db.dismissedUse)
        db.usedAt, db.expiresAt, db.dismissedUse, db.buddyName = nil, nil, nil, nil
        db.schema = 2
    end
    db.size = math.max(28, math.min(96, tonumber(db.size) or 44))
    db.x, db.y = tonumber(db.x) or 110, tonumber(db.y) or -100
    if db.locked == nil then db.locked = true end
    if db.alerts == nil then db.alerts = true end
    if db.sound == nil then db.sound = true end
    self:SetupProfiles()
    self.selected = self.profiles[db.selected] and db.selected or 5332
    for id, profile in pairs(self.profiles) do
        local pet = self:PetDB(id)
        local remaining = (tonumber(pet.expiresAt) or 0) - time()
        if self:Enabled(id) and remaining > 0 and remaining <= profile.duration then
            self.states[id] = { endTime = GetTime() + remaining,
                usedAt = tonumber(pet.usedAt) or (pet.expiresAt - profile.duration), guid = pet.guid }
        else pet.usedAt, pet.expiresAt, pet.guid = nil, nil, nil end
    end
    self:CreateAnchor()
    self:EnableEvents()
    self:DiscoverItems()
    self:ScanCooldowns()
    self:Refresh()
    self:Print("Ready. /hcg help for names, summons and alerts.")
end

function B:Command(message)
    if not self.DB then return end
    local _, _, command, value = string.find(message or "", "^%s*(%S*)%s*(.-)%s*$")
    command, value = string.lower(command or ""), value or ""
    local id = self:Resolve(value) or self.selected
    if command == "" or command == "show" then self.preview = not self.preview
    elseif command == "select" then
        local chosen = self:Resolve(value)
        if not chosen then self:Print("Use /hcg select timberling, saber or an item ID."); return end
        self.selected, self.DB.selected = chosen, chosen
        self:Print("Selected " .. self:DisplayName(chosen) .. ".")
    elseif command == "name" then
        local _, _, first, rest = string.find(value, "^(%S+)%s+(.+)$")
        local chosen = first and self:Resolve(first)
        if chosen then id, value = chosen, rest end
        value = self:CleanName(value)
        if string.lower(value) == "off" or string.lower(value) == "clear" then value = "" end
        self:PetDB(id).name = value
        self:Print(self.profiles[id].unitName .. ": " .. (value ~= "" and value or "default name") .. ".")
    elseif command == "test" then
        if self.states[id] and not self.states[id].demo then self:Print("A real timer is already running for this summon."); return end
        self:Start(id, 0, true)
        self.preview = nil
        self:Print("TEST: " .. self:DisplayName(id) .. " - " .. self:FormatTime(self.profiles[id].duration) .. ".")
    elseif command == "alarmtest" then self:ShowAlert("TEST: " .. self:DisplayName(id) .. " has AGGRO!", true)
    elseif command == "clear" then
        if string.lower(value) == "all" then
            for key in pairs(self.profiles) do self:Clear(key, true) end
        else self:Clear(id, true) end
        self.preview = nil
    elseif command == "bind" then
        if self:Bind(id, "target", true) then self:Print("Bound " .. self:DisplayName(id) .. " to your selected unit.")
        else self:Print("Target your friendly summon while its timer runs, then /hcg bind timberling (or saber).") end
    elseif command == "alerts" or command == "sound" then
        value = string.lower(value)
        if value ~= "on" and value ~= "off" then self:Print("Use /hcg " .. command .. " on or off."); return end
        self.DB[command] = value == "on"
        self:Print(command .. " " .. value .. ".")
    elseif command == "lock" or command == "unlock" then
        self.DB.locked, self.preview = command == "lock", command == "unlock"
    elseif command == "size" then
        local size = tonumber(value)
        if not size or size < 28 or size > 96 then self:Print("Use /hcg size 44 (28-96 pixels)."); return end
        self.DB.size = size
    elseif command == "reset" then
        self.DB.size, self.DB.x, self.DB.y, self.DB.locked, self.preview = 44, 110, -100, true, true
        self:ApplyPosition()
    elseif command == "add" then
        local _, _, item, minutes, cooldown, name = string.find(value, "^(%d+)%s+(%d+%.?%d*)%s+(%d+%.?%d*)%s+(.+)$")
        item, minutes, cooldown = tonumber(item), tonumber(minutes), tonumber(cooldown)
        if not item or item < 1 or not minutes or minutes <= 0 or minutes > 1440
            or not cooldown or cooldown <= 2 or cooldown > 1440 or self.excluded[item] then
            self:Print("Use /hcg add ITEM_ID DURATION_MIN COOLDOWN_MIN Exact Summon Name (combat guardians only).")
            return
        end
        name = string.gsub(name or "", "[|%c]", "")
        name = string.gsub(string.gsub(name, "^%s+", ""), "%s+$", "")
        if name == "" or string.len(name) > 96 or string.lower(name) == "worg pup" then return end
        self.profiles[item] = { unitName = name, itemName = "Item " .. item, duration = minutes * 60,
            cooldown = cooldown * 60, icon = "Interface\\Icons\\INV_Misc_QuestionMark" }
        self.DB.custom[item] = self:CopyProfile(self.profiles[item])
        self.DB.ignored[item] = nil
        self:PetDB(item)
        self:Print("Registered " .. name .. ". Equip the trinket to load its icon and spell data.")
    elseif command == "ignore" or command == "enable" then
        id = self:Resolve(value)
        if not id then self:Print("Choose a summon alias or registered item ID."); return end
        self.DB.ignored[id] = command == "ignore" or nil
        if command == "ignore" then self:Clear(id, true) end
    elseif command == "list" or command == "status" then
        for _, key in ipairs(self:OrderedIDs()) do
            local state = self.states[key]
            local mode = not self:Enabled(key) and "ignored" or (state and (state.demo and "TEST" or "active") or "idle")
            self:Print(key .. " " .. self:DisplayName(key) .. ": " .. mode .. ", " .. self:FormatTime(self:Remaining(key))
                .. (state and (state.guid and ", bound" or ", not yet bound") or ""))
        end
        self:Print(self.enhanced and "Owner/HP monitoring available (Nampower)." or "Limited monitoring: target your summon and /hcg bind; full owner/HP monitoring needs Nampower.")
    else
        self:Print("/hcg: preview; Shift-drag: move; click: target; right-click: select summon.")
        self:Print("/hcg name timberling Birk; /hcg name saber Spooky; /hcg select timberling")
        self:Print("/hcg test timberling; /hcg alarmtest; /hcg clear timberling (or all)")
        self:Print("/hcg alerts on/off; /hcg sound on/off; /hcg bind timberling; /hcg list")
        self:Print("/hcg add ITEM_ID DURATION_MIN COOLDOWN_MIN Exact Summon Name; /hcg ignore ITEM_ID")
        self:Print("/hcg lock; /hcg unlock; /hcg size 44; /hcg reset")
    end
    self:Refresh()
end

function B:OrderedIDs()
    local result = {}
    for id in pairs(self.profiles) do table.insert(result, id) end
    table.sort(result, function(a, b)
        if a == b then return false end
        if a == 5332 then return true end
        if b == 5332 then return false end
        return a < b
    end)
    return result
end
