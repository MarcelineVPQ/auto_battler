# Changelog

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
