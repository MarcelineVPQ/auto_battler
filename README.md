# Auto Battler

A roguelike auto-battler built with Godot 4.x and GDScript. Recruit heroes, apply upgrades, position your squad, and survive 20 rounds of escalating enemy waves.

Inspired by [Some of You May Die](https://store.steampowered.com/app/4124920/Some_of_You_May_Die/), Teamfight Tactics, and Super Auto Pets.

## How to Play

1. **Wave Select** — Pick one of 3 enemy wave options, each showing composition and unit count
2. **Prep Phase** — Buy heroes and upgrades from the shop, drag units to position them
3. **Battle** — Press Ready; units auto-fight the enemy wave
4. **Result** — Win to earn gold, lose to lose a life. Squad carries over to the next round
5. **Survive 20 rounds** to win

## Heroes

| Class | Cost | Role |
|-------|:----:|------|
| Warlock | 1g | Ranged caster, curse/reflect |
| Priest | 1g | Support, armor buff, double strike |
| Grunt | 1g | Fast melee brawler, high attack speed |
| Tank | 2g | Frontline, high HP and armor |
| Archer | 2g | Long-range DPS, high crit |
| Herbalist | 3g | Ranged support, skill procs |
| Assassin | 3g | Glass cannon, evasion + crit burst |

## Key Mechanics

- **Merging** — Drag a duplicate hero onto another of the same class for +25% all stats (up to 4x)
- **Stat Upgrades** — Click "+" buttons in the info panel to boost individual stats with gold
- **Shop Upgrades** — Buy upgrade cards, then click a hero to apply (targeting mode with crosshair cursor). Right-click to cancel and get a refund
- **Re-roll** — Spend 2g to refresh the shop
- **Interest** — Earn 10% on saved gold (up to 5g/round)

## Controls

| Input | Action |
|-------|--------|
| Left click | Select unit / apply upgrade target |
| Left drag | Reposition unit on arena |
| Right click | Cancel upgrade targeting |
| Escape | Cancel upgrade targeting |
| Click shop card | Buy hero or upgrade |

## Project Structure

```
scripts/
  autoload/game_manager.gd   — Game state, economy, phase management
  board/board.gd              — Arena rendering, unit management, grid
  data/unit_data.gd           — UnitData resource schema
  unit/unit.gd                — Unit stats, combat, merging
  unit/combat_system.gd       — Auto-combat tick loop
  main.gd                     — Game flow, shop, UI, input handling
resources/units/              — .tres files for each hero class
scenes/                       — .tscn scene files
```

## Requirements

- Godot 4.x

## Running

Open the project in Godot Editor and press F5, or run from CLI:

```bash
godot --path . --main-scene scenes/main.tscn
```
