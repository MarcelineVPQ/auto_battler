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

Each hero spawns with a **random thematic name** and one of **3 ability variants** per class, making every unit unique.

| Class | Cost | Role | Ability Variants |
|-------|:----:|------|-----------------|
| Warlock | 1g | Ranged caster | Vulnerable Curse, Soul Drain, Shadow Bolt |
| Priest | 1g | Support | Holy Armor, Divine Shield, Purify |
| Grunt | 1g | Fast melee brawler | Frenzy, War Cry, Cleave |
| Tank | 2g | Frontline | Shield Bash, Taunt, Fortify |
| Archer | 2g | Long-range DPS | Volley, Piercing Shot, Marked Target |
| Herbalist | 3g | Ranged support | Magic Potions, Rejuvenation, Noxious Burst |
| Assassin | 3g | Glass cannon | Shadowstrike, Poison Blade, Vanish |
| Summoner | 4g | Spawns minions | Raise Skeleton, Raise Guardian, Raise Revenant |
| Paladin | 4g | Holy frontline | Holy Aegis, Smite, Consecrate |

## Key Mechanics

- **XP & Leveling** — Buy a duplicate hero to auto-feed 1 XP (hold Shift for a separate copy). 4 XP per level with big stat boosts on level-up
- **Upgrade Slots** — Each hero gets level + 1 upgrade card slots
- **Mana & Abilities** — Mana charges via regen + attacks; abilities fire when full. Each unit gets a random ability variant from its class pool
- **Stat Upgrades** — Click "+" buttons in the info panel to boost individual stats with gold
- **Shop Upgrades** — Buy upgrade cards, then click a hero to apply (targeting mode with crosshair cursor). Right-click to cancel and get a refund
- **Rarity Tiers** — Normal (always), Rare/purple (round 5+), Epic/orange (round 10+). Hero-specific rare/epic buffs require matching class
- **Sell** — Select a hero and press X to sell for its base cost
- **Freeze** — Press F to lock the shop so it carries over to the next round
- **Re-roll** — Spend 2g to refresh the shop
- **Interest** — Earn 10% on saved gold (up to 5g/round)
- **Range-Aware Movement** — Ranged units hold position at their attack range instead of rushing into melee

## Controls

| Input | Action |
|-------|--------|
| Left click | Select unit / apply upgrade target |
| Left drag | Reposition unit on arena |
| Right click | Cancel upgrade targeting |
| Escape | Cancel upgrade targeting |
| X | Sell selected unit |
| F | Freeze / unfreeze shop |
| Click shop card | Buy hero or upgrade |

## Project Structure

```
scripts/
  autoload/game_manager.gd   — Game state, economy, phase management
  board/board.gd              — Arena rendering, unit management, grid
  data/unit_data.gd           — UnitData resource schema
  data/hero_variants.gd       — Name pools and ability variants per class
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
