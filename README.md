# Auto Battler

A roguelike auto-battler built with Godot 4.x and GDScript. Recruit heroes, apply upgrades, position your squad, and survive 20 rounds of escalating enemy waves. Supports local profiles and optional ranked PvP via a Nakama backend.

Inspired by [Some of You May Die](https://store.steampowered.com/app/4124920/Some_of_You_May_Die/), Teamfight Tactics, and Super Auto Pets.

## How to Play

1. **Select Profile** — Pick or create a profile from the main menu dropdown
2. **Wave Select** — Pick one of 3 enemy wave options, each showing composition and unit count
3. **Prep Phase** — Buy heroes and upgrades from the shop, drag units to position them
4. **Battle** — Press Ready; units auto-fight the enemy wave
5. **Result** — Win to earn gold + kill bounties, lose to lose a life. Squad carries over
6. **Survive 20 rounds** to win

Your game is **autosaved** after every round. Press **Escape** to save and quit mid-run, then continue from the main menu.

## Game Modes

- **Single Player** — Fight AI-generated enemy waves
- **Ranked PvP** — Fight real player squads fetched from the Nakama backend. Requires a running Nakama server

## Heroes

Each hero spawns with a **random thematic name** (18 per class) and one of **3 ability variants**, making every unit unique.

| Class | Cost | Role | Ability Variants |
|-------|:----:|------|-----------------|
| Warlock | 1g | Ranged caster | Soulfire, Soul Drain, Shadow Bolt |
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
- **Kill Bounties** — Earn gold for each enemy killed based on their farm cost
- **Hero Income** — Leveled heroes generate passive income (level - 1 gold per hero per round)
- **Sell** — Select a hero and press X to sell for its base cost
- **Freeze** — Press F to lock the shop so it carries over to the next round
- **Re-roll** — Spend 2g to refresh the shop
- **Interest** — Earn 10% on saved gold (up to 5g/round)
- **Combat Timer** — 60-second combat limit; draws result in no life lost

## Profiles

Multiple people can play on the same machine with independent profiles. Each profile has its own:
- Save game and settings
- Win/loss stats and highest round reached
- Backend auth credentials (for ranked PvP)

Create profiles from the main menu using the "+" button. Profile data is stored under `user://profiles/<id>/`.

## Controls

| Input | Action |
|-------|--------|
| Left click | Select unit / apply upgrade target |
| Left drag | Reposition unit on arena |
| Right click | Cancel upgrade/merge targeting |
| Escape | Cancel targeting / save & quit |
| X | Sell selected unit |
| F | Freeze / unfreeze shop |
| Click shop card | Buy hero or upgrade |

## Project Structure

```
scripts/
  autoload/profile_manager.gd  — Local profile management and migration
  autoload/game_manager.gd     — Game state, economy, save system
  autoload/audio_manager.gd    — SFX pool and music player
  autoload/settings_manager.gd — Audio/graphics/auxiliary settings
  autoload/backend_manager.gd  — Nakama auth, PvP matchmaking, leaderboard
  board/board.gd               — Arena rendering, unit management, grid
  data/unit_data.gd            — UnitData resource schema
  data/hero_variants.gd        — Name pools and ability variants per class
  unit/unit.gd                 — Unit stats, combat, merging
  unit/combat_system.gd        — Auto-combat tick loop
  menu/main_menu.gd            — Main menu with profiles, settings, leaderboard
  pvp/                         — Opponent cache, ELO calculator, squad serializer
  main.gd                      — Game flow, shop, UI, input handling
resources/units/               — .tres files for each hero class
scenes/                        — .tscn scene files
nakama/                        — Nakama server modules (TypeScript)
```

## Requirements

- Godot 4.x
- (Optional) Nakama server for ranked PvP — see `nakama/` directory

## Running

Open the project in Godot Editor and press F5, or run from CLI:

```bash
godot --path . --main-scene scenes/menu/main_menu.tscn
```
