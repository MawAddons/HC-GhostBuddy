# HC Ghost Buddy 1.2.0

Named combat guardians, summon timers, and danger alerts for **WoW 1.12.1 / OctoWoW**. Part of the **MawAddons HC suite**, with the same silver HC and purple addon title.

Each active summon gets its own small icon, nickname, countdown, and observed HP percentage. Your previous Ghost Saber name, position, size, and running timer migrate automatically.

| Item | Guardian | Lifetime | Item cooldown |
| --- | --- | --- | --- |
| Glowing Cat Figurine (5332) | Ghost Saber | 10 minutes | 60 minutes |
| Cleansed Timberling Heart (5218) | Cleansed Timberling | 20 minutes | 30 minutes |

These defaults match the reusable trinkets reported on this server. When available, the client item record supplies its actual on-use spell and cooldown. Lifetime and item cooldown are separate: Timberling displays **20:00**, even though its item takes 30 minutes to become ready again.

## Install and use

Extract `HC-GhostBuddy-1.2.0.zip` into `Interface\AddOns`, replacing the previous `HC-GhostBuddy` files. The final path should be `Interface\AddOns\HC-GhostBuddy\HC-GhostBuddy.toc`. Restart WoW after updating because this version adds Lua files to the TOC.

Use your trinkets normally. Successful Nampower item-cast events start the appropriate timer; matching equipped-item cooldowns provide a fallback and recover a timer already in progress. Failed casts, equip delays, and short shared cooldowns do not start a timer. Equipping two summon trinkets lets their timers run independently. Unequipping an item after detection does not stop its timer.

Name your buddies:

```text
/hcg name timberling Birk
/hcg name saber Spooky
```

These are addon display names; they do not rename the creature on the server. Danish characters are supported. Use `off` instead of a nickname to restore the default creature name.

Type `/hcg` to toggle a positioning preview. **Shift-drag** an icon to move the row. **Left-click** an active icon to target its guardian; a known GUID targets the exact creature. **Right-click** an icon selects it for commands such as `/hcg name My Buddy`.

## Aggro and health alerts

Alerts and sound default to on. A red banner, flashing icon, and raid-warning sound warn when:

- An observed enemy in combat targets the guardian, or begins a targeted hostile cast at it: **AGGRO**.
- A melee attack targets it, including a missed attack: **AGGRO**.
- It receives spell damage: **taking damage**, since area damage alone does not prove aggro.
- Its observed health reaches **40% or less**: **LOW HP**.

Repeated alerts for the same guardian are throttled to six seconds; low health can escalate sooner. Confirmed death clears that guardian's timer. Player death clears all timers. HP is hidden when its last observation is more than a second old.

Full monitoring uses **Nampower**, already present in the referenced OctoWoW installation. The addon reads GUIDs and `summonedBy` / `createdBy` to identify your guardian. Other players' same-name guardians are rejected. Unit events, visible nameplates, your target/mouseover, group targets, and the guardian's opponent provide observations. If an active icon has not bound to the summon yet, target or hover your buddy once. `/hcg status` shows whether a specific guardian has been bound.

Without Nampower, cooldown timers still work. Owner text on a visible unit tooltip can identify a guardian; `/hcg bind timberling` explicitly binds your currently selected friendly summon. This fallback has limited observation coverage. A bare creature-name match is insufficient for automatic ownership detection.

**Limits:** this is not a complete threat table. An unseen enemy or out-of-range unit may not be observable, so an early warning cannot be guaranteed. Incoming attacks can warn only once the server reports them. Absence/out-of-range is not treated as death. A timer surviving a relog does not prove the guardian survived it. `/hcg clear timberling` dismisses a timer if the summon disappears early.

The addon enables Nampower's spell-go, spell-start, and auto-attack event CVars when available. It never changes your target, uses items, or casts spells automatically; targeting happens only on your click.

## More summon trinkets

Equipped trinkets are automatically registered when their **English tooltip explicitly says they summon a creature to fight for/protect you for a finite number of minutes or seconds**. Their spell/cooldown metadata comes from the client when available. Unclear descriptions require a manual profile:

```text
/hcg add ITEM_ID DURATION_MIN COOLDOWN_MIN Exact Creature Name
```

Use the real item ID, lifetime, cooldown, and creature name from your server. Then give it a nickname with `/hcg name ITEM_ID Nickname`. Exact creature names may be longer than nicknames. Saved profiles are per character.

**Worg Pup is excluded.** Ordinary non-combat companions, including the normal Dark Whelpling item, are not automatically tracked. A server-specific fighting Dark Whelpling can be learned from its combat-summon tooltip or registered with the command above; its duration is not guessed. This model tracks one guardian per item; multi-creature effects are not tracked as separate individuals.

## Commands

| Command | Action |
| --- | --- |
| `/hcg` or `/ghostbuddy` | Toggle preview; active summons stay visible. |
| `/hcg name timberling Birk` | Name Timberling independently. Use `saber` for Ghost Saber. |
| `/hcg select timberling` | Choose the default guardian for commands without an alias. |
| `/hcg test timberling` | Run a 20-minute TEST timer without using the item. |
| `/hcg test saber` | Run a 10-minute TEST timer. |
| `/hcg alarmtest` | Preview the alert banner and sound. |
| `/hcg clear timberling` | Clear just Timberling; the same cooldown will not restart it. |
| `/hcg clear all` | Clear every timer. |
| `/hcg alerts on` / `off` | Enable or disable alert banners and sounds. |
| `/hcg sound on` / `off` | Toggle sound while keeping visual alerts. |
| `/hcg bind timberling` | Explicitly bind your selected friendly guardian. |
| `/hcg list` or `/hcg status` | Show profiles, timer state, and monitoring availability. |
| `/hcg ignore ITEM_ID` / `/hcg enable ITEM_ID` | Disable or re-enable a registered profile. |
| `/hcg unlock` / `/hcg lock` | Allow ordinary dragging or require Shift-drag. |
| `/hcg size 44` | Set icon size from 28 to 96 pixels. |
| `/hcg reset` | Restore default row position and icon size. |
| `/hcg help` | Show command help. |

Real timestamps, individual names, custom profiles, and settings persist per character in `HCGhostBuddyDB`. Test timers are never saved.

## Validation

Run `lua tests/smoke.lua` from this repository with Lua 5.1 (the addon itself uses Lua 5.0-compatible syntax). The tests simulate vanilla event globals, UI frames, item cooldowns, and Nampower ownership/health/attack data. Coverage includes migration, independent timers, the 30-minute Timberling cooldown, duplicate and failed casts, recovery after reload, rejection of other owners, alerts before damage, low-health escalation, mute/throttling, death and out-of-range handling, custom profiles, companion exclusion, and stock-client fallback.

Live acceptance check: restart WoW, run `/hcg test timberling` and `/hcg alarmtest`, then check `/hcg status` after a real use. Verify binding by targeting your Timberling and check that clicking its icon selects that exact unit. Aggro/HP behavior still needs verification with the running server; simulated tests do not prove every server event is available.

API references: [Nampower functions](https://github.com/brues-code/nampower/blob/main/SCRIPTS.md), [unit fields](https://github.com/brues-code/nampower/blob/main/UNIT_FIELDS.md), and [native event arguments](https://github.com/brues-code/nampower/blob/main/EVENTS.md).
