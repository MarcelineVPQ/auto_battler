# Changelog

## v0.7.0 — Random Names & Ability Variants per Hero Class

### Random Hero Names
- Every spawned unit now receives a **random thematic name** from a pool of 6 per class
- Names persist across rounds via squad save/restore
- Combat log, info panel, and name labels all display the unique name

### Ability Variants (3 per class, 27 total)
Each unit is randomly assigned one of 3 ability variants when spawned:

- **Warlock** — Vulnerable Curse (AoE crit vulnerability), Soul Drain (lifesteal single target), Shadow Bolt (heavy nuke)
- **Priest** — Holy Armor (AoE heal), Divine Shield (armor to weakest ally), Purify (big heal + cleanse on lowest HP ally)
- **Tank** — Shield Bash (armor+dmg hit), Taunt (pull nearby enemies + gain armor), Fortify (massive armor gain, rooted)
- **Herbalist** — Magic Potions (AoE poison), Rejuvenation (AoE heal), Noxious Burst (AoE damage in 150px)
- **Grunt** — Frenzy (attack speed buff), War Cry (all allies +3 damage), Cleave (AoE melee in 100px)
- **Archer** — Volley (AoE reduced damage), Piercing Shot (single target, ignores armor), Marked Target (enemy takes +30% damage)
- **Assassin** — Shadowstrike (+50% crit), Poison Blade (bonus damage buff), Vanish (+80% evasion + guaranteed crit)
- **Summoner** — Summon Archer (spawns archer), Summon Guardian (spawns tank minion), Arcane Familiar (spawns warlock minion)
- **Paladin** — Holy Aegis (armor restore + damage buff), Smite (heavy damage + self heal), Consecrate (AoE damage + AoE heal)

### Shop Preview
- Selecting a hero card in the shop now shows all possible ability variants for that class
- Per-instance ability name and description shown in the unit info panel

### Paladin (new in heroes table)
- Added Paladin to the README heroes table with all 3 ability variants

### Bug Fix
- Fixed integer division in farm cost calculation for type safety

---

## v0.6.0 — Color-Coded Shop, Tiered Rare/Epic Buffs, Range-Aware Movement

### Rarity Color Coding
- Shop upgrade cards are now tinted by rarity: **purple** for Rare, **orange** for Epic
- Normal cards remain untinted

### Tiered Rarity Unlocks
- **Rare** upgrades only appear in the shop from **round 5+**
- **Epic** upgrades only appear in the shop from **round 10+**

### Hero-Specific Rare Buffs (12g, round 5+)
- **Blood Rage** (Grunt) — +5 dmg, +0.2 atk/s
- **Deadeye** (Archer) — +8 dmg, +80 range
- **Phantom Step** (Assassin) — +10% evade, +10% crit
- **Fortress** (Tank) — +5 armor, +40 HP
- **Soul Rend** (Warlock) — +8 dmg, +3 max mana
- **Divine Covenant** (Priest) — +30 HP, +3 max mana
- **Toxic Mastery** (Herbalist) — +5 dmg, +5% skill proc

### Hero-Specific Epic Buffs (18g, round 10+)
- **Rampage** (Grunt) — +10 dmg, +0.3 atk/s, +20 HP
- **Hawkeye** (Archer) — +12 dmg, +120 range, +8% crit
- **Death's Embrace** (Assassin) — +15% evade, +15% crit, +5 dmg
- **Bastion** (Tank) — +8 armor, +60 HP, +2 dmg
- **Dark Pact** (Warlock) — +15 dmg, +5 max mana
- **Ascension** (Priest) — +50 HP, +5 max mana, +5 dmg
- **Plague Lord** (Herbalist) — +10 dmg, +8% skill proc, +3 armor

### Class Restriction
- Hero-specific upgrades can only be applied to the matching class
- Card text shows "(Class only)" restriction

### Range-Aware Movement
- Ranged units (Archer, Warlock, etc.) now stop at their attack range instead of rushing into melee
- Melee units still close to attack range normally

---

## v0.5.0 — Mana Bar, Ability System, Primed Rework

### Mana System
- Blue mana bar on every unit (above armor/health bars)
- Mana starts at 0 each battle, charges via passive regen + per-attack gain
- Abilities fire when mana is full, then mana resets to 0

### Class Abilities
- **Priest** — Heals all allied units for 2.5x damage
- **Warlock** — Damage surges (1.5x permanent buff)
- **Herbalist** — Poisons all enemies for 0.5x damage
- **Archer** — Volley hits all enemies for 0.4x damage
- **Grunt** — Frenzy: +30% attack speed
- **Tank** — Shield Bash: +2 armor
- **Assassin** — Shadowstrike: +50% crit chance

### Primed Rework
- Primed upgrade now starts the hero with full mana so ability fires on the first tick

### Unit Scaling
- Base scale reduced (0.4 to 0.22) with gentler growth (0.03/level) and hard cap at 0.45
- Magic users get larger mana pools and faster regen; melee heroes charge abilities slower

---

## v0.4.0 — Hero Icons, Attack Effects, Combat Log, Auto-Merge Shop

### Visual Overhaul
- 8 distinct SVG class icons with team-colored rings replacing placeholder sprites
- Projectile effects: arrow, magic bolt, holy bolt, poison glob fly from attacker to target
- Melee slash effects: sword arc (Grunt/Tank), X-slash (Assassin) at target position

### Battle UI
- Tug-of-war army strength bar showing relative HP
- Scrolling color-coded combat log with hit/crit/evade/kill/summon events

### Auto-Merge Shop
- Buying a hero you already own auto-feeds 1 XP (hold Shift to spawn a second copy)

### Balance Pass
- Summoner attack rate 0.3 to 0.2, summoned archers at 60% stats with halved power scaling
- Necromancy capped at 3 stacks (15% per stack, cost 12g)
- Tuned assassin, warlock, tank, grunt, herbalist stats

---

## v0.3.0 — XP/Level-Up, Summoner Class, Armor Bar

### XP-Based Leveling
- Replaced merge system with XP leveling: 4 XP per level, small stat boost per XP, large boost on level-up
- No max level

### Upgrade Card Slots
- Upgrade slots gated by level (level + 1 slots)

### Summoner Class (4g)
- New hero: spawns archers instead of attacking
- Summoned archers scale with summoner's XP, level, and stat purchases
- Necromancy upgrade: summoned archers inherit a percentage of the summoner's bonus stats

### Armor Bar
- Armor bar UI displayed on all units
- Armor purchasable for all heroes

### Economy
- Premium stat pricing tiers for evasion, crit, and skill proc
- XP, level, and necromancy stacks persist across rounds

---

## v0.2.0 — Expanded Upgrades, Sell & Freeze

### Upgrade Pool Expansion (30 total, up from 7)
- **Cheap (2-3g):** Swift Strikes, Iron Skin, Keen Edge, Nimble, Quickstep, Longshot, Vitality, Poison Tip
- **Mid (4-6g):** Bloodlust, Eagle Eye, Adrenaline, Giant Killer, Arcane Surge, Primed, Fortify
- **Expensive (8-12g):** Thorns, Vampirism, Berserk, Last Stand, Relentless
- **Rare (15g):** Invincible, Haymaker, Sniper
- All stat types now have at least one upgrade at multiple price tiers

### Sell Units
- Press **X** or click the **Sell** button to sell the selected player hero
- Refunds the hero's base farm cost in gold
- Blocked during upgrade targeting and outside prep phase

### Freeze Shop
- Press **F** or click the **Freeze** button to lock the current shop
- Frozen shop carries over to the next round instead of re-rolling
- Button turns blue and reads "Unfreeze" when active; press again to toggle off
- Freeze resets after the shop is preserved (one-round hold)

---

## v0.1.0 — Initial Release

### Core Systems
- Arena with player/enemy halves, drag-and-drop unit positioning with snap-to-grid
- Auto-combat system with attack timers, armor reduction, evasion rolls, and critical hits
- 20-round structure with escalating enemy difficulty and level scaling
- Lives system (lose a life per defeat, game over at 0)
- Economy: base income, victory bonus, interest on gold savings
- Shop with 2 hero cards + 4 upgrade cards, re-roll for 2g
- Wave select screen: choose from 3 randomized enemy compositions
- Squad persistence between rounds (stats, merges, upgrades carry over)

### Hero Classes (7 total)
- **Warlock** (1g) — Ranged caster with Vulnerable Curse ability and Reflect skill
- **Priest** (1g) — Support with Holy Armor ability and Double Strike skill
- **Tank** (2g) — Frontline bruiser with Shield Bash, high HP and armor
- **Herbalist** (3g) — Ranged support with Magic Potions, high skill proc chance
- **Grunt** (1g) — Fast melee brawler, highest attack speed (1.2/s), quick movement
- **Archer** (2g) — Pure ranged DPS, longest range (280), high crit chance
- **Assassin** (3g) — Glass cannon with 20% evasion, 15% crit, fastest unit (60 speed)

### Hero Progression
- Hero merging: drag duplicate class onto existing hero for +25% all stats (up to 4 merges)
- Per-stat upgrades purchasable from the info panel with escalating gold costs
- Shop upgrade cards (Corrosive, Exploit Weakness, Toughness, Deadly Focus, Revenge, Sepsis, Nearly Fatal)

### Upgrade Targeting System
- Clicking an upgrade card in the shop enters targeting mode (crosshair cursor)
- Green rings highlight valid player units on the board
- Left-click a player unit to apply the upgrade
- Right-click or Escape cancels targeting and refunds gold
- Applied upgrades listed in the unit info panel under "Upgrades" section
- Shop and Ready button blocked during targeting to prevent accidental actions

### Wave Strategies (8 types)
- Frontline Defense, Glass Cannon, Arcane Assault, Holy Guard, Poison Swarm, Balanced Army, Blitz Rush, Sniper Nest

### UI
- Side panel with Lives, Gold, Squad count, and Ready button
- Info panel showing full unit stats, upgrade buttons, applied upgrades, abilities
- Attack range circle visualized when selecting a unit
- Grid dots shown during unit drag for positioning guidance
