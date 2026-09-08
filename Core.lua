HCGhostBuddy = {}
local Buddy = HCGhostBuddy

Buddy.DURATION = 600
Buddy.ITEM_ID = 5332
Buddy.ITEM_COOLDOWN = 3600
Buddy.VERSION = "1.0.1"
Buddy.COLORED_NAME = "|cffb8c0ccHC|r |cffa335eeGhost Buddy|r"

function Buddy:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage(self.COLORED_NAME .. ": " .. message)
end

function Buddy:FormatTime(seconds)
    seconds = math.max(0, math.ceil(seconds))
    local minutes = math.floor(seconds / 60)
    return string.format("%d:%02d", minutes, seconds - minutes * 60)
end

function Buddy:Remaining()
    return math.max(0, (self.endTime or 0) - GetTime())
end

function Buddy:IsFigurine(link)
    local _, _, id = string.find(link or "", "item:(%d+)")
    return tonumber(id) == self.ITEM_ID
end

function Buddy:ObserveCooldown(start, duration, enabled)
    -- The pictured reusable trinket has a one-hour cooldown. Matching that
    -- duration excludes the GCD, equip delay and short shared trinket lockouts.
    if type(start) ~= "number" or type(duration) ~= "number" or enabled ~= 1 then return end
    if math.abs(duration - self.ITEM_COOLDOWN) > 5 then return end
    local age = GetTime() - start
    if age < 0 or age >= self.DURATION then return end
    if self.lastCooldownStart and math.abs(self.lastCooldownStart - start) < 1 then return end
    self.lastCooldownStart = start

    -- Use the item's actual start time, including when loading partway through
    -- a summon. Repeated cooldown events must never restart the ten minutes.
    local usedAt = time() - age
    if self.DB.dismissedUse and math.abs(self.DB.dismissedUse - usedAt) < 3 then return end
    self.demo = nil
    self.usedAt = usedAt
    self.endTime = start + self.DURATION
    self.DB.usedAt = usedAt
    self.DB.expiresAt = usedAt + self.DURATION
    self.DB.dismissedUse = nil
end

function Buddy:Scan()
    if not self.DB then return end
    local slot
    for slot = 13, 14 do
        if self:IsFigurine(GetInventoryItemLink("player", slot)) then
            self:ObserveCooldown(GetInventoryItemCooldown("player", slot))
        end
    end
end

function Buddy:Clear()
    if not self.demo and self.usedAt then self.DB.dismissedUse = self.usedAt end
    self.endTime = nil
    self.usedAt = nil
    self.demo = nil
    self.preview = nil
    self.DB.expiresAt = nil
    self.DB.usedAt = nil
    self:Refresh()
end

function Buddy:Initialize()
    if self.DB then return end
    if type(HCGhostBuddyDB) ~= "table" then HCGhostBuddyDB = {} end
    self.DB = HCGhostBuddyDB
    local db = self.DB
    db.size = math.max(28, math.min(96, tonumber(db.size) or 44))
    db.x = tonumber(db.x) or 110
    db.y = tonumber(db.y) or -100
    if db.locked == nil then db.locked = true end
    db.dismissedUse = tonumber(db.dismissedUse)
    db.expiresAt = tonumber(db.expiresAt)
    db.usedAt = tonumber(db.usedAt)
    if db.expiresAt and db.expiresAt > time() and db.expiresAt <= time() + self.DURATION then
        self.endTime = GetTime() + db.expiresAt - time()
        self.usedAt = db.usedAt or (db.expiresAt - self.DURATION)
    else
        db.expiresAt = nil
        db.usedAt = nil
    end
    self:CreateIcon()
    self:Scan()
    self:Refresh()
    self:Print("Ready. /hcg previews the icon; Shift-drag moves it. /hcg help for options.")
end

function Buddy:Command(message)
    if not self.DB then return end
    message = string.lower(message or "")
    local _, _, command, value = string.find(message, "^%s*(%S*)%s*(.-)%s*$")
    if command == "" or command == "show" then
        self.preview = not self.preview
        self:Print(self.preview and "Preview on. Shift-drag the icon to move it; /hcg hides the preview." or "Preview off. The icon appears automatically during a summon.")
    elseif command == "test" then
        if self:Remaining() > 0 and not self.demo then
            self:Print("A summon timer is already running: " .. self:FormatTime(self:Remaining()) .. ".")
            return
        end
        self.demo = true
        self.preview = nil
        self.endTime = GetTime() + self.DURATION
        self:Print("Test countdown started. /hcg clear ends it. No trinket was used.")
    elseif command == "clear" then
        self:Clear()
        self:Print("Timer cleared. The next trinket use will start it again.")
    elseif command == "lock" then
        self.DB.locked = true
        self.preview = nil
        self:Print("Position locked. Shift-drag still works.")
    elseif command == "unlock" then
        self.DB.locked = false
        self.preview = true
        self:Print("Drag the icon to move it. /hcg lock finishes positioning.")
    elseif command == "size" then
        local size = tonumber(value)
        if not size or size < 28 or size > 96 then
            self:Print("Use /hcg size 44 (28-96 pixels).")
            return
        end
        self.DB.size = size
        self:ApplyPosition()
    elseif command == "reset" then
        self.DB.size = 44
        self.DB.x = 110
        self.DB.y = -100
        self.DB.locked = true
        self.preview = true
        self:ApplyPosition()
        self:Print("Icon position and size reset. Shift-drag to move it; /hcg hides the preview.")
    elseif command == "status" then
        local remaining = self:Remaining()
        if remaining > 0 then
            self:Print((self.demo and "Test: " or "Estimated summon time: ") .. self:FormatTime(remaining))
        else
            self:Print("No active summon timer.")
        end
    else
        self:Print("/hcg: preview; /hcg test: test countdown; /hcg clear: clear timer.")
        self:Print("/hcg lock or unlock; /hcg size 44; /hcg reset; /hcg status.")
    end
    self:Refresh()
end

local events = CreateFrame("Frame", "HCGhostBuddyEvents")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("BAG_UPDATE_COOLDOWN")
events:RegisterEvent("UNIT_INVENTORY_CHANGED")
events:RegisterEvent("PLAYER_DEAD")
events:SetScript("OnEvent", function()
    -- Vanilla 1.12 supplies event arguments as globals, not function arguments.
    if event == "ADDON_LOADED" and arg1 == "HC-GhostBuddy" then
        Buddy:Initialize()
    elseif event == "PLAYER_LOGIN" then
        Buddy:Initialize()
    elseif Buddy.DB then
        if event == "PLAYER_DEAD" then
            Buddy:Clear()
        elseif event == "PLAYER_ENTERING_WORLD" or event == "BAG_UPDATE_COOLDOWN"
            or (event == "UNIT_INVENTORY_CHANGED" and arg1 == "player") then
            Buddy:Scan()
            Buddy:Refresh()
        end
    end
end)

-- Keep the watcher separate from the icon: hidden frames do not get OnUpdate.
local elapsed = 0
events:SetScript("OnUpdate", function()
    if not Buddy.DB then return end
    elapsed = elapsed + (arg1 or 0)
    if elapsed < 0.2 then return end
    elapsed = 0
    Buddy:Scan()
    Buddy:Refresh()
end)

SLASH_HCGHOSTBUDDY1 = "/hcg"
SLASH_HCGHOSTBUDDY2 = "/ghostbuddy"
SlashCmdList["HCGHOSTBUDDY"] = function(message) Buddy:Command(message) end
