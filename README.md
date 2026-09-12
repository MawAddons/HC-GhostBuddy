# HC Ghost Buddy 1.1.0

Part of the **MawAddons HC suite**. The addon list, chat prefix, and tooltip use the same silver **HC** and purple **Ghost Buddy** name styling as the other HC addons. The matching title prefix groups it with the other HC entries in the addon list.

A small, ghostly blue saber icon that counts down **10:00 to 0:00** when you use **Glowing Cat Figurine**. Built for the **WoW 1.12.1 / Turtle WoW** client and the reusable, 60-minute-cooldown trinket in the reference screenshot.

## Install

1. Extract `HC-GhostBuddy-1.1.0.zip` into your WoW `Interface\AddOns` directory, replacing the existing `HC-GhostBuddy` files if updating.
2. Check the path is `Interface\AddOns\HC-GhostBuddy\HC-GhostBuddy.toc`.
3. Restart the game if it was open when you added the folder, then enable **HC Ghost Buddy** on the character screen.

## Use

Equip Glowing Cat Figurine in either trinket slot and use it normally, including through an action button or macro. The icon appears near the center of the screen and counts down the saber's 10-minute duration. It turns amber in the last minute, pulses red in the final 30 seconds, and hides when the timer expires.

Type `/hcg` to preview the icon. **Hold Shift and drag** to position it, then type `/hcg` again to finish. The default size is 44 pixels. The icon uses the client's built-in white saber artwork with a cyan tint and border; no other addons or downloaded textures are required.

Left-click the icon to target your nearby **Ghost Saber**. Give it a custom display name above the timer with `/hcg name Spooky`; use `/hcg name off` to hide the name.

| Command | Action |
| --- | --- |
| `/hcg` or `/ghostbuddy` | Toggle the positioning preview. An active summon stays visible. |
| `/hcg test` | Run a 10-minute test countdown marked TEST without using the item. |
| `/hcg clear` | Clear the timer, for example if the saber dies early. |
| `/hcg unlock` | Show the icon and allow ordinary dragging. |
| `/hcg lock` | Finish positioning and require Shift to drag. |
| `/hcg size 44` | Set icon size from 28 to 96 pixels. |
| `/hcg name Spooky` | Show a custom name above the icon; `name off` clears it. |
| `/hcg reset` | Restore default position and size, then show a preview. |
| `/hcg status` | Print the current timer status. |
| `/hcg help` | Show commands. |

Position, size, and real summon timestamps are saved separately per character. An active timer continues through `/reload` or relogging with elapsed offline time deducted. Test countdowns are not saved. Unequipping the figurine after detection does not stop the running countdown.

## Detection and limits

The addon watches item **5332** in equipment slots 13 and 14. It uses the start timestamp of the item's **3,600-second cooldown** to derive the 600-second summon expiry. Short equip delays, global cooldowns, shared trinket lockouts, and failed uses do not start a timer. It can also recover the remaining time when first enabled while the figurine is equipped and its summon is less than ten minutes old.

This is an elapsed-duration estimate. The 1.12 client does not reliably expose this guardian as your controllable pet, so early guardian death, dismissal, or disappearance during zoning is not automatically detected. Use `/hcg clear` in that case; the same cooldown will not restart the cleared timer. Player death clears the timer automatically. A relogged timer does not prove that the guardian survived the relog.

This build targets the reusable trinket shown in the screenshot, not the consumable version of the item on official Classic/retail clients.

References: [Turtle WoW item 5332](https://database.turtle-wow.org/?item=5332) and [Blizzard's 1.12.1 equipment cooldown implementation](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/master/1.12.1/FrameXML/PaperDollFrame.lua).

## Verification

The automated checks in `tests/ghost_buddy_smoke.lua` cover both trinket slots, cooldown filtering, countdown expiry, repeated events, reload recovery, clearing, saved positions, and preview/test behavior using a simulated 1.12 UI. A live client check is still needed: use `/hcg test`, then verify automatic detection on your next real figurine use.
