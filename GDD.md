# Auto Battler — Game Design Document

## Overview

**Genre:** Auto-Battler / Roguelike Strategy
**Engine:** Godot 4.x (GDScript)
**Platform:** PC
**Inspiration:** Some of You May Die, Teamfight Tactics, Super Auto Pets

### Elevator Pitch

> _[Describe your game in 1-2 sentences.]_

---

## Core Loop

1. **Wave Select** — Choose from 3 enemy wave options (composition, unit count, strategy)
2. **Prep Phase** — Buy heroes/upgrades from the shop bar, drag-and-drop to position on arena
3. **Battle Phase** — Press "Ready", units auto-fight the enemy wave
4. **Result** — Win or lose; losing costs a life. Earn income, advance to next round
5. **Repeat** — 20 rounds of escalating difficulty

### Key Flow Details

- Board starts **empty** — player builds their squad by purchasing heroes from the shop
- Squad **persists** between rounds — purchased heroes carry over (restored to full HP)
- Shop shows **2 hero cards + 4 upgrade cards** each round (randomized from pool)
- Player can **re-roll** the shop for 2g to get new options
- Upgrades apply to the **currently selected** hero on the board

---

## Arena

- **Open field** — no grid, units placed freely via drag-and-drop
- **Orientation:** left-to-right (player units LEFT, enemies RIGHT)
- **Player half:** left side of the arena
- **Enemy half:** right side of the arena
- **Drag-to-place:** during PREP phase, drag player units to position them strategically
- **Perspective:** slight top-down/isometric pixel art battlefield
- **Background:** grassy field with decorative stone pillars

---

## Units (Heroes)

### Stats

| Stat | Description | Purchasable |
|------|-------------|:-----------:|
| Damage | Base damage dealt per attack | Yes (2g) |
| Attacks Per Second | Attack rate | Yes (2g) |
| Ability Cooldown | Time between ability casts | No (display only) |
| Health | Hit points — unit dies at 0 | Yes (2g) |
| Mana | Resource pool for casting abilities | Yes (2g) |
| Armor | Flat damage reduction | No (gained from upgrades/abilities) |
| Evasion | Chance to dodge attacks (%) | Yes (2g) |
| Attack Range | Circular radius in pixels (e.g., 500) | Yes (2g) |
| Move Speed | Movement speed in pixels/sec (e.g., 15) | Yes (2g) |
| Critical Hit Chance | Chance for attacks to crit (%) | Yes (2g) |
| Skill Proc Chance | Chance for skill to trigger on attack (%) | Yes (2g) |

Other stats (not shown in upgrade panel):
- **Farm Cost** — gold cost to purchase hero from shop
- **Mana Cost Per Attack** — mana consumed each attack
- **Mana Regen Per Second** — passive mana recovery rate

### Stat Upgrades

- Each upgradeable stat has a **"+" button** in the hero detail panel
- Costs **2 gold** per stat point
- Can be purchased during prep phase while the hero is selected
- Allows fine-tuning individual heroes beyond their base class stats

### Hero Stacking (Merging)

- Drag a **duplicate hero** (same class) onto an existing one to **merge** them
- Merged hero gets **+25% to all stats** (damage, HP, atk speed, range, etc.)
- The consumed hero is removed — does not count toward squad cap
- Can stack multiple times for compounding bonuses
- Upgrades applied before merge are included in the 25% boost

### Upgrade Slots

- Each hero has upgrade slots (e.g., 0/2)
- Upgrade cards are purchased from the shop and applied to a hero
- Stacking identical upgrades creates compounding effects

### Hero Classes

| Class | Farm Cost | Ability | Skill | Boosted Stats |
|-------|:---------:|---------|-------|---------------|
| Warlock | 1 | Vulnerable Curse | Reflect | Ability Speed |
| Priest | 1 | Holy Armor | Double Strike | Mana |
| Tank | 2 | Shield Bash | — | Attack Range, Attack Speed |
| Herbalist | 3 | Magic Potions | — | Damage, Damage |
| _TBD_ | | | | |
| _TBD_ | | | | |

Each class has:
- **Ability** — active skill tied to mana and ability cooldown
- **Skill** — passive or triggered effect (not all classes have one)
- **Boosted stats** — one or two stats the class naturally excels at (can be the same stat twice for double scaling)

---

## Upgrade Cards

Purchasable cards applied to heroes to modify their behavior.

| Upgrade | Cost | Rarity | Effect |
|---------|------|--------|--------|
| Corrosive | 2 | Normal | Reduces armor per hit; can make armor go negative |
| Exploit Weakness | 2 | Normal | Deal bonus damage to enemies with 0 or negative armor |
| Revenge | 2 | Normal | On death: deal damage to killer |
| Deadly Focus | 5 | Normal | One-time boost to crit when under 50% HP |
| Sepsis | 8 | Normal | On crit: multiply existing poison stacks on target |
| Nearly Fatal | 15 | Rare | Upon crit, trigger kill events |
| Extra Hero Slot | _TBD_ | Rare | Adds +1 hero card to the shop (3 heroes + 3 upgrades) |
| _TBD_ | | | |

- Duplicate upgrade cards can appear in the same shop roll
- Stacking identical upgrades on a hero compounds their effect
- **Extra Hero Slot** (late-game rare): after a certain number of rounds, this card can appear — buying it permanently changes the shop to show 3 hero cards + 3 upgrade cards instead of 2+4

### Rarity Tiers

| Rarity | Cost Range | Availability |
|--------|-----------|-------------|
| Normal | 2-8g | Common in shop |
| Rare | 15g | Less frequent, powerful effects |
| _TBD_ | | |
| _TBD_ | | |

---

## Economy

| Mechanic | Value |
|----------|-------|
| Starting gold | 8 |
| Base income | +12g per round (rounds 1-7) |
| Scaling income | +1g additional per round after round 7 (13g at R8, 14g at R9, etc.) |
| Round victory bonus | +2g |
| Interest | 10% on gold stores, up to 5g per round |
| Hero sell refund | Full farm cost (e.g., 1-cost → 1g, 2-cost → 2g) |
| Shop refresh | _TBD_ |
| Stat upgrade cost | 2g per point |
| Squad cap | Starts at ~3, max 6 |

### Income Example

> Round 5, player has 40g saved, won last round:
> - Base income: +12g
> - Victory bonus: +2g
> - Interest (10% of 40, capped at 5): +4g
> - **Total: +18g**

---

## Lives & Progression

- **Lives:** Start with a small number (e.g., 4)
- **Lose a life** when you lose a round
- **Game over** at 0 lives
- **Total rounds:** 20
- **Unit cap:** limited squad size (e.g., 3/6), increases over time

### Round Structure

| Round | Encounter | Notes |
|-------|-----------|-------|
| 1-5 | Early waves | Easing in, simple enemies |
| 6-10 | Mid waves | Enemies gain abilities |
| 11-15 | Late waves | Tougher compositions |
| 16-20 | Final waves | Boss-tier difficulty |

---

## Controls

| Input | Action |
|-------|--------|
| Left click | Select unit (shows detail panel + attack range circle) |
| Left click + drag | Position unit on arena |
| Click shop card | Buy hero or upgrade |
| Number keys (1-6) | Quick-select shop slots |
| X | _TBD_ (sell / discard) |
| F | _TBD_ (freeze shop) |
| Space | Ready (start battle) |

---

## UI Layout

```
+---------------------------------------------------------------+
| [Menu] [Round Info] [DPS] [Speed: 1x]       Round 0/20       |
|                                                               |
|                                                               |
|              +-------------------------+                      |
|              |                         |                      |
|              |      Open Arena         |                      |
|              |   (enemy units top,     |                      |
|              |    player units bottom) |                      |
|              |                         |                      |
|              +-------------------------+                      |
|                                                               |
| +-----+-----+--------+--------+--------+--------+ +---------+|
| |Hero |Hero | Upgrade| Upgrade| Upgrade| Upgrade| |Lives: 4 ||
| |Card |Card | Card   | Card   | Card   | Card   | |Gold: 8  ||
| | 1   | 2   |  3     |  4     |  5     |  6     | |Cap: 3/6 ||
| +-----+-----+--------+--------+--------+--------+ |[Ready]  ||
|                                                    +---------+|
+---------------------------------------------------------------+
```

### Unit Detail Panel (on select)

Appears on the right side when clicking a hero:

```
+---------------------+
| [Hero Portrait]     |
|                     |
| Name                |
| Class        Level  |
|           xp X / X  |
| [Stats] [Upgrades]  |
| [Sell: X gold]      |
|                     |
| Ability: ...        |
| Skill: ...          |
| Boosted: ...        |
|                     |
| Farm cost: X        |
| Mana cost/atk: X    |
| Mana regen/s: X     |
|                     |
| [+2g] Damage       X |
| [+2g] Atk/Sec      X |
|       Ability CD    X |
| [+2g] Health     X/X |
| [+2g] Mana       X/X |
|       Armor         X |
| [+2g] Evasion     X% |
| [+2g] Atk Range    X |
| [+2g] Move Speed   X |
| [+2g] Crit Chance  X% |
| [+2g] Skill Proc   X% |
+---------------------+
```

---

## Visual Style

> Pixel art, colorful fantasy setting. Bright greens and blues for the outdoor
> arena, warm earth tones for the battle field. Units are small pixel sprites
> with distinct silhouettes per class. UI uses parchment/wood-framed panels.
> Lighthearted tone with comedic gore (pixel blood).

---

## Audio

> _[Describe music and SFX direction.]_

---

## Milestones

- [x] **Phase 1:** Minimal prototype — arena, units, auto-combat, win/lose
- [ ] **Phase 2:** Economy, shop (hero cards + upgrade cards), drag-to-place, prep/battle loop
- [ ] **Phase 3:** 20 rounds, lives system, hero leveling/stacking, upgrade slots
- [ ] **Phase 4:** Hero abilities/mana, unit detail panel, DPS meter, speed control
- [ ] **Phase 5:** Art, animations, SFX, polish

---

## Open Questions

- _How many hero classes total?_
- _How many upgrade cards in the full pool?_
- _What rarity tiers beyond Normal?_
- _Status effect system (poison, curse, etc.) — how do stacks work?_
- _Online PvP or PvE only?_
- _Unlockables / meta-progression between runs?_

---

## Notes

**Reference game:** [Some of You May Die](https://store.steampowered.com/app/4124920/Some_of_You_May_Die/)

Key takeaways from reference:
- Arena is open (no grid), units free-placed
- Shop has both hero cards and upgrade cards in the same row
- Heroes level up by buying duplicates (stacking), not merging 3→1
- Upgrade cards attach to heroes (slot-based)
- Upgrades compound when stacked (e.g., double poison = multiply effect)
- Lives system (small number like 4) instead of large HP pool
- 20-round structure
- Attack range shown as a visible circle on the arena
- Stat upgrades are purchasable with gold (+Damage, +Attacks/Sec, etc.)
