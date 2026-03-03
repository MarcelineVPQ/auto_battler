# Auto Battler — Game Design Document

## Overview

**Genre:** Auto-Battler / Roguelike Strategy
**Engine:** Godot 4.x (GDScript)
**Platform:** PC
**Inspiration:** Some of You May Die, Teamfight Tactics, Super Auto Pets

### Elevator Pitch

> Recruit a squad of fantasy heroes, upgrade their stats and abilities, and position them on an open arena to auto-battle increasingly difficult enemy waves across 20 rounds. Supports local profiles and optional ranked PvP against real player squads.

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

### Hero Classes (9 total)

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

Each unit spawns with a **random thematic name** (18 per class) and one of **3 ability variants**, making every unit unique. Abilities are mana-gated: mana charges via regen + per-attack gain, fires when full, then resets.

---

## Upgrade Cards

Purchasable cards applied to heroes via targeting mode.

### Generic Upgrades

| Tier | Cost | Examples |
|------|------|---------|
| Cheap | 2-3g | Corrosive, Exploit Weakness, Toughness, Swift Strikes, Iron Skin, Keen Edge, Nimble, Quickstep, Longshot, Poison Tip |
| Mid | 4-6g | Deadly Focus, Bloodlust, Giant Killer, Arcane Surge, Primed, Living Shield |
| Expensive | 8-10g | Sepsis, Thorns, Vampirism, Berserk, Last Stand, Relentless |
| Rare (round 6+) | 15g | Invincible, Haymaker |

### Hero-Specific Upgrades

| Rarity | Cost | Availability | Examples |
|--------|------|-------------|---------|
| Rare | 12g | Round 5+ | Blood Rage (Grunt), Deadeye (Archer), Phantom Step (Assassin), Fortress (Tank), Soul Rend (Warlock), Hellfire (Warlock), Divine Covenant (Priest), Toxic Mastery (Herbalist), Holy Vanguard (Paladin) |
| Epic | 18g | Round 10+ | Rampage (Grunt), Hawkeye (Archer), Death's Embrace (Assassin), Bastion (Tank), Dark Pact (Warlock), Ascension (Priest), Plague Lord (Herbalist) |

### Rarity Tiers

| Rarity | Color | Availability |
|--------|-------|-------------|
| Normal | Grey | Always |
| Rare | Purple | Round 5+ |
| Epic | Orange | Round 10+ |

---

## Economy

| Mechanic | Value |
|----------|-------|
| Starting gold | 25g |
| Base income | +12g per round (rounds 1-5) |
| Scaling income | +1g additional per round after round 5 (13g at R6, 14g at R7, etc.) |
| Round victory bonus | +2g |
| Interest | 10% on gold stores, up to 5g per round |
| Hero income | +(level - 1)g per hero per round |
| Kill bounties | Gold earned per enemy killed (= their farm cost) |
| Hero sell refund | Full farm cost (e.g., 1-cost → 1g, 2-cost → 2g) |
| Shop refresh | 2g |
| Stat upgrade cost | 2g per point |
| Squad cap | Based on farm count (starts at 5) |

### Income Example

> Round 5, player has 40g saved, won last round, 2 heroes at level 2:
> - Base income: +12g
> - Victory bonus: +2g
> - Interest (10% of 40, capped at 5): +4g
> - Hero income: +2g (2 heroes × 1g each)
> - **Total: +20g** (plus any kill bounties earned during combat)

---

## Lives & Progression

- **Lives:** Start with 5
- **Lose a life** when you lose a round (draws do not cost a life)
- **Life regen:** +1 life every 5 rounds
- **Game over** at 0 lives
- **Total rounds:** 20
- **Gold snapshot:** gold is snapshotted at round start and restored on defeat
- **Autosave:** game state saved after every round; ESC opens save-and-quit overlay

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
| Left click | Select unit / apply upgrade or merge target |
| Left click + drag | Position unit on arena |
| Right click | Cancel upgrade/merge targeting |
| Escape | Cancel targeting / save & quit |
| Click shop card | Buy hero or upgrade |
| X | Sell selected unit |
| F | Freeze / unfreeze shop |

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

- **Battle music** — looping track during combat phase, stops on combat end
- **Class-specific ability sounds** — 6 categories (melee, stealth, ranged, holy, dark, nature) mapped per class
- **Combat SFX** — hit, crit, evade, death, heal, summon, curse sounds
- **UI SFX** — buy, sell, reroll, upgrade, warning, coin, round start, victory, defeat, game over
- Audio pool: 8 concurrent `AudioStreamPlayer` nodes on the SFX bus
- Dedicated music player separate from SFX pool
- Audio generation: `scripts/tools/generate_audio.py` using ElevenLabs API

---

## Milestones

- [x] **Phase 1:** Minimal prototype — arena, units, auto-combat, win/lose
- [x] **Phase 2:** Economy, shop (hero cards + upgrade cards), drag-to-place, prep/battle loop
- [x] **Phase 3:** 20 rounds, lives system, hero leveling/stacking, upgrade slots
- [x] **Phase 4:** Hero abilities/mana, unit detail panel, DPS meter
- [x] **Phase 5:** Art, animations, SFX, audio
- [x] **Phase 6:** Ranked PvP, Nakama backend, leaderboard
- [x] **Phase 7:** Save system, autosave, continue from save
- [x] **Phase 8:** Local profiles, stats tracking
- [ ] **Phase 9:** Hero creator / profile picture integration
- [ ] **Phase 10:** Polish, meta-progression, unlockables

---

## Async PVP / Backend

### Architecture

- **Backend:** [Nakama](https://heroiclabs.com/nakama/) open-source game server (self-hosted via Docker)
- **Client communication:** Raw HTTP REST API (`HTTPRequest` nodes) — no SDK addon
- **Auth:** Device-based anonymous authentication (stable UUID per install)

### Infrastructure

| Service | Image | Port |
|---------|-------|------|
| Nakama | `heroiclabs/nakama:3.21.1` | 7350 (API), 7351 (Console) |
| PostgreSQL | `postgres:15-alpine` | 5432 (internal) |

Start with: `cd nakama && docker compose up -d`

### Server RPCs

| RPC | Purpose |
|-----|---------|
| `find_opponents` | Query ELO leaderboard for players within ±200 rating, return their squad snapshots |
| `record_result` | Atomically update ELO leaderboard + win/loss stats after a match |

### Client Flow

1. **Startup** — `BackendManager` authenticates via device ID, gets session token
2. **Prep phase** — Squad snapshot uploaded to Nakama storage
3. **Wave select** — `find_opponents` RPC fetches real player squads as wave options
4. **Battle end** — `record_result` RPC updates ELO and win/loss in one call
5. **Offline** — Requests queued locally, flushed when connectivity returns

### Key Files

| File | Role |
|------|------|
| `scripts/autoload/profile_manager.gd` | Local profile management (autoload) |
| `scripts/autoload/backend_manager.gd` | Client networking (autoload) |
| `scripts/pvp/elo_calculator.gd` | ELO math (backend-agnostic) |
| `scripts/pvp/opponent_cache.gd` | Offline opponent fallback cache |
| `scripts/pvp/squad_serializer.gd` | Squad ↔ JSON conversion |
| `nakama/data/modules/main.ts` | Server-side RPCs |
| `nakama/docker-compose.yml` | Docker infrastructure |

---

## Open Questions

- _Unlockables / meta-progression between runs?_
- _Hero creator / custom profile pictures?_
- _Additional hero classes?_
- _Boss rounds?_

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
