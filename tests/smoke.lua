-- Standalone regression tests. Run from the repository or E:/wowaddons.
local probe = io.open("HC-GhostBuddy/Profiles.lua", "r")
local prefix = probe and "HC-GhostBuddy/" or ""
if probe then probe:close() end
local env, checks, B
checks = 0
local function check(value, message)
    if not value then error(message, 2) end
    checks = checks + 1
end
local function near(a, b) return math.abs(a - b) < 0.01 end
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = copy(v) end
    return result
end
local function unit(token)
    if not token then return end
    if env.units[token] then return env.units[token] end
    for _, u in pairs(env.units) do if u.guid == token then return u end end
    if string.sub(token, -6) == "target" then
        local base = unit(string.sub(token, 1, -7))
        if base then return unit(base.target) end
    end
end
function GetTime() return env.uptime end
function time() return env.wall end
function IsShiftKeyDown() return env.shift end
function GetInventoryItemLink(_, slot)
    local item = env.equipment[slot]
    return item and "|Hitem:" .. item.id .. ":0|h[Item]|h"
end
function GetInventoryItemCooldown(_, slot)
    local item = env.equipment[slot] or {}
    return item.start or 0, item.duration or 0, item.enabled == nil and 1 or item.enabled
end
function GetInventoryItemTexture(_, slot) return "test-icon" end
function GetContainerNumSlots(bag) return 0 end
function UnitExists(token) return unit(token) and 1 end
function UnitName(token) local u = unit(token); return u and u.name end
function UnitIsFriend(_, token) local u = unit(token); return u and u.friendly and 1 end
function UnitCanAttack(_, token) local u = unit(token); return u and not u.friendly and 1 end
function UnitAffectingCombat(token) local u = unit(token); return u and u.combat and 1 end
function UnitIsUnit(a, b) return unit(a) and unit(a) == unit(b) and 1 end
function UnitHealth(token) return unit(token) and unit(token).health end
function UnitHealthMax(token) return unit(token) and unit(token).maxHealth end
function GetNumRaidMembers() return 0 end
function TargetUnit(token) env.targeted = token end
function TargetByName(name) env.targeted = name end
function PlaySound(name) table.insert(env.sounds, name) end
function GetCVar(name) return env.cvars[name] end
function SetCVar(name, value) env.cvars[name] = value end
function getglobal(name) return _G[name] end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) table.insert(env.messages, message) end }

local function widget(name)
    local w = { name = name, shown = true, scripts = {}, events = {}, lines = {} }
    function w:GetName(guid) return guid and self.guid or self.name end
    function w:GetChildren() return unpack(self.children or {}) end
    function w:SetWidth(n) self.width = n end
    function w:SetHeight(n) self.height = n end
    function w:SetFrameStrata(n) end
    function w:SetMovable(n) end
    function w:SetClampedToScreen(n) end
    function w:EnableMouse(n) end
    function w:RegisterForDrag(n) end
    function w:RegisterForClicks(a, b) end
    function w:SetBackdrop(n) end
    function w:SetBackdropColor(r, g, b, a) end
    function w:SetBackdropBorderColor(r, g, b, a) self.border = { r, g, b, a } end
    function w:SetTexture(n, g, b, a) self.texture = n end
    function w:SetTexCoord(a, b, c, d) end
    function w:SetPoint(p, parent, rp, x, y) self.point = { p, parent, rp, x or 0, y or 0 } end
    function w:ClearAllPoints() self.point = nil end
    function w:GetCenter()
        if self.cx then return self.cx, self.cy end
        if self.point then
            local x, y = self.point[2]:GetCenter()
            return x + self.point[4], y + self.point[5]
        end
        return 960, 540
    end
    function w:StartMoving() self.moving = true end
    function w:StopMovingOrSizing() self.moving = false end
    function w:SetFont(path, n, flags) self.font = n end
    function w:SetText(n) self.text = n end
    function w:GetText() return self.text end
    function w:SetTextColor(r, g, b) self.color = { r, g, b } end
    function w:SetAlpha(n) self.alpha = n end
    function w:Show() self.shown = true end
    function w:Hide()
        local was = self.shown
        self.shown = false
        if was and self.scripts.OnHide then self.scripts.OnHide() end
    end
    function w:IsShown() return self.shown end
    function w:RegisterEvent(n) self.events[n] = true end
    function w:SetScript(n, f) self.scripts[n] = f end
    function w:GetScript(n) return self.scripts[n] end
    function w:CreateTexture() return widget() end
    function w:CreateFontString() return widget() end
    function w:SetOwner(owner, anchor) self.owner = owner end
    function w:IsOwned(owner) return self.owner == owner end
    function w:AddLine(line) table.insert(self.lines, line) end
    function w:ClearLines() self.lines = {} end
    function w:NumLines() return table.getn(self.lines) end
    function w:loadLines(lines)
        self.lines = lines or {}
        for i, text in ipairs(self.lines) do
            local f = widget(); f:SetText(text)
            _G[self.name .. "TextLeft" .. i] = f
        end
    end
    function w:SetInventoryItem(_, slot) self:loadLines(env.equipment[slot] and env.equipment[slot].tooltip) end
    function w:SetBagItem(a, b) self:loadLines({}) end
    function w:SetUnit(token) self:loadLines(unit(token) and unit(token).tooltip) end
    return w
end
function CreateFrame(kind, name, parent, template)
    check(kind == "Frame" or kind == "Button" or kind == "GameTooltip", "Unexpected modern UI frame type")
    local w = widget(name)
    if name then _G[name] = w end
    return w
end

local function fire(name, a, b, c, d)
    event, arg1, arg2, arg3, arg4 = name, a, b, c, d
    B.events.scripts.OnEvent()
    event, arg1, arg2, arg3, arg4 = nil, nil, nil, nil, nil
end
local function tick(seconds)
    env.uptime, env.wall = env.uptime + seconds, env.wall + seconds
    arg1 = seconds; B.events.scripts.OnUpdate(); arg1 = nil
end
local function load(saved, enhanced, keepEnvironment)
    if not keepEnvironment then
        env = { uptime = 1000, wall = 2000000000, equipment = {}, units = {}, sounds = {}, messages = {}, stats = {},
            cvars = { NP_EnableSpellGoEvents = "0", NP_EnableAutoAttackEvents = "0", NP_EnableSpellStartEvents = "0" } }
        env.units.player = { guid = "0x0000000000000001", name = "Pod", friendly = true }
    end
    GetUnitGUID, GetUnitField, GetItemStats = nil, nil, nil
    if enhanced then
        GetUnitGUID = function(token) local u = unit(token); return u and u.guid end
        GetUnitField = function(token, key) local u = unit(token); return u and u[key] end
        GetItemStats = function(id, forceCopy) return env.stats[id] end
    end
    UIParent, GameTooltip, WorldFrame = widget("UIParent"), widget("GameTooltip"), widget("WorldFrame")
    HCGhostBuddyDB, SlashCmdList = copy(saved), {}
    for _, name in ipairs({ "Profiles", "Core", "Monitor", "UI", "Events" }) do dofile(prefix .. name .. ".lua") end
    B = HCGhostBuddy
    fire("ADDON_LOADED", "UnrelatedAddon")
    check(not B.DB, "Unrelated addon initialized Buddy")
    fire("ADDON_LOADED", "HC-GhostBuddy")
    return B
end
local function timber(owner, token)
    env.units[token or "target"] = { guid = "0xf13000000df20001", name = "Cleansed Timberling", friendly = true,
        summonedBy = owner or env.units.player.guid, health = 64, maxHealth = 64, level = 7 }
    return env.units[token or "target"]
end

load(nil, true)
check(B.profiles[5218].duration == 1200 and B.profiles[5332].duration == 600, "Default durations")
check(B.profiles[5218].cooldown == 1800, "Timberling must use the user's 30-minute cooldown")
check(B:FormatTime(1200) == "20:00" and B:FormatTime(59.2) == "1:00", "Clock formatting")
check(not next(B.states), "Idle addon starts a fictional summon")
check(env.cvars.NP_EnableSpellGoEvents == "1" and env.cvars.NP_EnableAutoAttackEvents == "1", "Required event streams not enabled")
B:Command(""); check(B.frames[5218]:IsShown() and B.frames[5332]:IsShown(), "Multi-pet preview")
B:Command(""); check(not B.frames[5218]:IsShown(), "Preview toggle")
B:Command("name timberling Birk")
B:Command("name saber Spooky")
check(B:DisplayName(5218) == "Birk" and B:DisplayName(5332) == "Spooky", "Independent names")
B:Command("select timberling"); B:Command("name Lille Træ")
check(B:DisplayName(5218) == "Lille Træ", "Selected name / Danish UTF-8")
check(not string.find(B:CleanName("|cffff0000Bad|r"), "|", 1, true), "Name markup was not sanitized")
fire("SPELL_GO_SELF", 5218, 999, env.units.player.guid)
check(B:Remaining(5218) == 1200 and B.frames[5218].timer.text == "20:00", "Timberling successful use")
local originalExpiry = B.states[5218].endTime
fire("SPELL_GO_SELF", 5218, 999, env.units.player.guid)
check(B.states[5218].endTime == originalExpiry, "Duplicate cast restarted duration")
B:Command("test timberling"); check(not B.states[5218].demo, "Test overwrote real summon")
fire("SPELL_GO_SELF", 5332, 6084, env.units.player.guid)
tick(60)
check(near(B:Remaining(5218), 1140) and near(B:Remaining(5332), 540), "Concurrent timers interfere")
B:Command("clear saber")
check(not B.states[5332] and B.states[5218], "Clear one deleted other summon")

-- Owner verification, exact click targeting, and pre-damage aggro.
local t = timber("0x0000000000000002")
fire("UPDATE_MOUSEOVER_UNIT")
fire("PLAYER_TARGET_CHANGED")
check(not B.states[5218].guid, "Other player's Timberling was bound")
B:Command("bind timberling")
check(not B.states[5218].guid, "Manual binding overrode a known other owner")
t.summonedBy = env.units.player.guid
fire("PLAYER_TARGET_CHANGED")
check(B.states[5218].guid == t.guid, "Own Timberling not identified")
B:TargetBuddy(5218); check(env.targeted == t.guid, "Click did not use exact guardian GUID")
env.units.enemy = { guid = "0xf130000000000010", name = "Bear", friendly = false, combat = true, target = t.guid }
local enemy = env.units.enemy
env.units.target = enemy
env.units.buddy = t
fire("UNIT_FLAGS_GUID", enemy.guid)
check(B.alert:IsShown() and string.find(B.alert.text.text, "AGGRO", 1, true), "Enemy target did not warn before a hit")
check(table.getn(env.sounds) == 1, "Aggro sound missing")
tick(0.2); fire("AUTO_ATTACK_OTHER", enemy.guid, t.guid, 10)
check(table.getn(env.sounds) == 1, "Alert spam on repeated attacks")
tick(1.1); t.health = 20
tick(0.2)
check(string.find(B.alert.text.text, "LOW HP", 1, true), "Low-health escalation suppressed")
check(B.frames[5218].health.text == "32% HP", "HP percentage incorrect")
check(table.getn(env.sounds) == 2, "Low HP did not produce an escalation sound")
B:Command("sound off"); tick(7)
check(table.getn(env.sounds) == 2, "Sound setting ignored")
B:Command("alerts off"); tick(5)
check(not B.alert:IsShown(), "Alert setting ignored")
B:Command("alerts on"); t.health = 0; tick(0.2)
check(not B.states[5218] and B:PetDB(5218).dismissedUse, "Known death did not clear and suppress timer")

-- Cast failures, shared cooldowns, cooldown recovery and duplicate evidence.
load(nil, true)
env.equipment[13] = { id = 5332, start = env.uptime, duration = 30 }
fire("BAG_UPDATE_COOLDOWN")
check(not B.states[5332], "Equip/shared cooldown caused false summon")
fire("SPELL_FAILED_SELF", 5218)
check(not B.states[5218], "Failed use caused a timer")
fire("SPELL_GO_SELF", 5218, 111, "0x0000000000000002")
check(not B.states[5218], "Another player's cast started a timer")
env.units.player.guid = "0x000000000000a12f"
fire("SPELL_GO_SELF", 5218, 111, "0x000000000000A12F")
check(B:Remaining(5218) == 1200, "GUID casing rejected the player's successful cast")
B:Clear(5218)
env.equipment[14] = { id = 5218, start = env.uptime - 300, duration = 1800 }
fire("BAG_UPDATE_COOLDOWN")
check(B:Remaining(5218) == 900, "30-minute Timberling cooldown did not recover 15 minutes of summon time")
env.equipment[13].duration = 3600
fire("BAG_UPDATE_COOLDOWN")
tick(120)
check(near(B:Remaining(5332), 480), "Cooldown recovery used remaining item cooldown")
local saved = copy(B.DB)
env.wall = env.wall + 30; env.uptime = 20
env.equipment[13].start = env.uptime - 150
load(saved, true, true)
check(near(B:Remaining(5332), 450), "Reload/offline-time recovery")
B:Command("clear saber"); tick(1)
saved = copy(B.DB); load(saved, true, true)
check(not B.states[5332], "Cleared timer resurrected after reload")
tick(3600); env.equipment[13].start = env.uptime; tick(0.2)
check(B:Remaining(5332) > 599, "Next valid summon stayed suppressed")
fire("SPELL_GO_SELF", 5218, 111, env.units.player.guid)
fire("PLAYER_DEAD")
check(not next(B.states), "Player death left active guardians")

-- Old 1.1.0 data migration retains exact old custom name and time.
load({ buddyName = "Spøgelset", usedAt = 1999999800, expiresAt = 2000000400,
    size = 64, x = 250, y = -160, locked = false }, true)
check(B:DisplayName(5332) == "Spøgelset" and B:Remaining(5332) == 400, "Legacy migration lost name/time")
check(B.DB.size == 64 and B.DB.x == 250 and B.DB.y == -160 and not B.DB.locked, "Migration lost layout")
B:Command("test timberling"); tick(1201)
check(not next(B.states), "Timers do not expire independently")
B:Command("test timberling"); saved = copy(B.DB); load(saved, true, true)
check(not B.states[5218], "Test timer was persisted as a real guardian")

-- Learn only finite combat guardians; never infer a combat pet from its name.
load(nil, true)
env.equipment[13] = { id = 10822, tooltip = { "Dark Whelpling", "Use: Right Click to summon and dismiss your whelpling." } }
B:DiscoverItems(); check(not B.profiles[10822], "Vanity Dark Whelpling was included")
env.equipment[14] = { id = 12264, tooltip = { "Worg Pup", "Use: Summons a Worg Pup to fight for you for 20 min." } }
B:DiscoverItems(); check(not B.profiles[12264], "Excluded Worg Pup was included")
env.equipment[13] = { id = 90001, start = env.uptime, duration = 3600,
    tooltip = { "Whelp Trinket", "Use: Summons a Dark Whelpling to fight for you for 15 min. CD: 60.0 min" } }
B:DiscoverItems(); B:ScanCooldowns()
check(B.profiles[90001].duration == 900 and B:Remaining(90001) == 900, "Combat trinket discovery / parsed cooldown")
B:Command("name 90001 Ember"); check(B:DisplayName(90001) == "Ember", "Custom guardian naming")
B:Command("ignore 90001"); B:ScanCooldowns(); check(not B.states[90001], "Ignored summon started")
B:Command("add 90002 12 45 Little Guardian")
check(B.profiles[90002].duration == 720 and B.profiles[90002].cooldown == 2700, "Manual profile")
B:Command("add 90004 2 60 Arcanite Mechanical Dragonling")
check(B.profiles[90004].unitName == "Arcanite Mechanical Dragonling", "Long NPC name was truncated")
B:Command("add 12264 20 60 Worg Pup"); check(not B.profiles[12264], "Manual Worg exclusion")
B:Command("add 90003 0 60 Broken"); check(not B.profiles[90003], "Invalid duration accepted")
saved = copy(B.DB); load(saved, true, true)
check(B.profiles[90002].duration == 720 and B:DisplayName(90001) == "Ember", "Custom profiles/names lost on reload")

-- Use server-provided item spell/cooldown metadata and keep duration separate.
env.stats[5218] = { spellID = { 5780 }, spellTrigger = { 0 }, spellCooldown = { 7200000 } }
env.equipment[14] = { id = 5218, tooltip = { "Cleansed Timberling Heart" }, start = env.uptime, duration = 7200 }
B:DiscoverItems(); B:ScanCooldowns()
check(B.profiles[5218].cooldown == 7200 and B:Remaining(5218) == 1200, "Server cooldown metadata")
B:Clear(5218); env.uptime = env.uptime + 10; env.wall = env.wall + 10
fire("SPELL_GO_SELF", 0, 5780, env.units.player.guid)
check(B:Remaining(5218) == 1200, "Cast spell-ID fallback without item ID")

-- Damaging spells warn without claiming definite aggro; hostile casts warn early.
t = timber(); fire("PLAYER_TARGET_CHANGED")
env.units.enemy = { guid = "0xf130000000000010", name = "Mage", friendly = false, combat = true }
fire("SPELL_DAMAGE_EVENT_OTHER", t.guid, env.units.enemy.guid, 100, 1)
check(string.find(B.alert.text.text, "taking damage", 1, true), "Spell damage warning")
tick(7); fire("SPELL_START_OTHER", 0, 100, env.units.enemy.guid, t.guid)
check(string.find(B.alert.text.text, "AGGRO", 1, true), "Pre-impact hostile spell warning")
env.units.friend = { guid = "0x0000000000000009", name = "Healer", friendly = true }
tick(7); local alertTime = B.alert.untilTime
fire("SPELL_START_OTHER", 0, 100, env.units.friend.guid, t.guid)
check(B.alert.untilTime == alertTime, "Friendly heal produced an aggro warning")
env.units.target = nil; env.units.hiddenBuddy = nil
tick(2)
check(B:Remaining(5218) > 0 and B.frames[5218].health.text == "", "Out of range was treated as death / stale HP displayed")

-- Stock API mode still loads, detects cooldowns, and avoids same-name ownership guesses.
load(nil, false)
env.equipment[13] = { id = 5332, start = env.uptime, duration = 3600 }
tick(0.2); check(B:Remaining(5332) > 599, "Stock 1.12 cooldown fallback")
env.units.target = { name = "Ghost Saber", friendly = true, health = 100, maxHealth = 100 }
fire("PLAYER_TARGET_CHANGED")
check(not B.states[5332].unit, "Stock client guessed ownership from same name")
env.units.target.tooltip = { "Ghost Saber", "Pod's Minion" }
fire("PLAYER_TARGET_CHANGED")
check(B.states[5332].unit == "target", "Stock owner-tooltip fallback")
env.units.target = { name = "Other creature", friendly = true, health = 1, maxHealth = 100 }
tick(0.2); check(not B.alert:IsShown(), "Reused target token triggered low HP")
B:Command("unlock"); local frame = B.frames[5332]
frame.scripts.OnDragStart(); check(B.anchor.moving, "Unlocked drag failed")
B.anchor.cx, B.anchor.cy = 1200, 650
frame.scripts.OnDragStop()
check(B.DB.x == 240 and B.DB.y == 110 and not B.anchor.moving, "Drag position was not saved")
B:Command("size 64"); check(frame.width == 64, "Resize failed")
B:Command("size 999"); check(frame.width == 64, "Invalid size accepted")
B:Command("reset"); check(B.DB.x == 110 and B.DB.size == 44, "Position reset failed")
B:Command("lock"); frame.scripts.OnDragStart(); check(not B.anchor.moving, "Locked drag moved")
env.shift = true; frame.scripts.OnDragStart(); check(B.anchor.moving, "Shift drag failed")
B:Command("clear all"); check(not B.anchor.moving, "Hidden frame kept dragging")
B:Command("alarmtest"); check(B.alert:IsShown() and table.getn(env.sounds) > 0, "Alarm test failed")
tick(5); check(not B.alert:IsShown(), "Alarm banner stuck visible")
print("HC Ghost Buddy: " .. checks .. " checks passed.")
