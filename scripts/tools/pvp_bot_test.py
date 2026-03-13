#!/usr/bin/env python3
"""
PvP Bot Test Script — Creates bot accounts on Nakama with realistic squads.

Each bot authenticates via device auth, simulates the game economy through
several rounds of buying heroes/farms, then uploads a squad snapshot and
ELO rating so real players can find opponents to fight.

Usage:
    python3 scripts/tools/pvp_bot_test.py              # 10 bots, default settings
    python3 scripts/tools/pvp_bot_test.py --bots 20     # 20 bots
    python3 scripts/tools/pvp_bot_test.py --host 1.2.3.4 --port 7350
"""

import argparse
import base64
import json
import math
import random
import sys
import uuid
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError

# ── Economy Constants (from GameManager) ──────────────────────────────

STARTING_GOLD = 25
STARTING_FARMS = 5
BASE_FARM_COST = 1
BASE_INCOME = 12
INCOME_SCALE_ROUND = 7
VICTORY_BONUS = 2
INTEREST_RATE = 0.10
MAX_INTEREST = 5

# ── Unit Definitions (from .tres files) ──────────────────────────────

UNITS = {
    "Grunt": {
        "farm_cost": 1, "pop_cost": 1,
        "max_hp": 130, "damage": 7, "attacks_per_second": 1.1,
        "attack_range": 80.0, "ability_range": 120.0, "move_speed": 55.0,
        "armor": 15, "evasion": 0.0, "crit_chance": 5.0,
        "skill_proc_chance": 3.0, "max_mana": 15,
        "mana_cost_per_attack": 4, "mana_regen_per_second": 1.0,
    },
    "Priest": {
        "farm_cost": 1, "pop_cost": 1,
        "max_hp": 65, "damage": 4, "attacks_per_second": 1.0,
        "attack_range": 180.0, "ability_range": 250.0, "move_speed": 50.0,
        "armor": 0, "evasion": 5.0, "crit_chance": 2.0,
        "skill_proc_chance": 5.0, "max_mana": 25,
        "mana_cost_per_attack": 6, "mana_regen_per_second": 2.5,
    },
    "Archer": {
        "farm_cost": 2, "pop_cost": 3,
        "max_hp": 55, "damage": 11, "attacks_per_second": 0.8,
        "attack_range": 280.0, "ability_range": 280.0, "move_speed": 35.0,
        "armor": 0, "evasion": 0.0, "crit_chance": 8.0,
        "skill_proc_chance": 5.0, "max_mana": 16,
        "mana_cost_per_attack": 4, "mana_regen_per_second": 1.5,
    },
    "Tank": {
        "farm_cost": 2, "pop_cost": 2,
        "max_hp": 200, "damage": 8, "attacks_per_second": 0.6,
        "attack_range": 80.0, "ability_range": 150.0, "move_speed": 30.0,
        "armor": 40, "evasion": 0.0, "crit_chance": 3.0,
        "skill_proc_chance": 3.0, "max_mana": 18,
        "mana_cost_per_attack": 4, "mana_regen_per_second": 1.0,
    },
    "Paladin": {
        "farm_cost": 2, "pop_cost": 2,
        "max_hp": 150, "damage": 6, "attacks_per_second": 0.8,
        "attack_range": 80.0, "ability_range": 200.0, "move_speed": 40.0,
        "armor": 20, "evasion": 0.0, "crit_chance": 3.0,
        "skill_proc_chance": 3.0, "max_mana": 20,
        "mana_cost_per_attack": 4, "mana_regen_per_second": 1.5,
    },
    "Warlock": {
        "farm_cost": 2, "pop_cost": 2,
        "max_hp": 50, "damage": 12, "attacks_per_second": 0.5,
        "attack_range": 220.0, "ability_range": 180.0, "move_speed": 40.0,
        "armor": 0, "evasion": 0.0, "crit_chance": 5.0,
        "skill_proc_chance": 5.0, "max_mana": 20,
        "mana_cost_per_attack": 8, "mana_regen_per_second": 2.0,
    },
    "Herbalist": {
        "farm_cost": 3, "pop_cost": 1,
        "max_hp": 90, "damage": 10, "attacks_per_second": 0.7,
        "attack_range": 180.0, "ability_range": 200.0, "move_speed": 35.0,
        "armor": 5, "evasion": 0.0, "crit_chance": 8.0,
        "skill_proc_chance": 10.0, "max_mana": 22,
        "mana_cost_per_attack": 5, "mana_regen_per_second": 2.0,
    },
    "Assassin": {
        "farm_cost": 3, "pop_cost": 3,
        "max_hp": 60, "damage": 12, "attacks_per_second": 0.9,
        "attack_range": 100.0, "ability_range": 100.0, "move_speed": 60.0,
        "armor": 0, "evasion": 15.0, "crit_chance": 12.0,
        "skill_proc_chance": 10.0, "max_mana": 14,
        "mana_cost_per_attack": 5, "mana_regen_per_second": 1.0,
    },
    "Summoner": {
        "farm_cost": 4, "pop_cost": 4,
        "max_hp": 50, "damage": 0, "attacks_per_second": 0.2,
        "attack_range": 0.0, "ability_range": 200.0, "move_speed": 25.0,
        "armor": 0, "evasion": 0.0, "crit_chance": 0.0,
        "skill_proc_chance": 0.0, "max_mana": 20,
        "mana_cost_per_attack": 0, "mana_regen_per_second": 1.5,
    },
}

# ── Hero Variant Data (from hero_variants.gd) ────────────────────────

NAME_POOLS = {
    "Warlock": ["Garalt", "Mordith", "Vexara", "Thane", "Noctis", "Zareth"],
    "Priest": ["Helena", "Amara", "Solene", "Briseia", "Theron", "Luciel"],
    "Tank": ["Dorian", "Bulvar", "Ironhide", "Magnus", "Hector", "Brant"],
    "Herbalist": ["Sage", "Willow", "Briar", "Fern", "Thistle", "Rowan"],
    "Grunt": ["Korg", "Grok", "Thud", "Borak", "Ruk", "Varn"],
    "Archer": ["Lyra", "Aelin", "Faelyn", "Sera", "Ithrin", "Veyra"],
    "Assassin": ["Shade", "Whisper", "Nyx", "Veil", "Dusk", "Sable"],
    "Summoner": ["Nyx", "Elara", "Omen", "Riven", "Azura", "Conjura"],
    "Paladin": ["Cedric", "Aldric", "Gavriel", "Lucan", "Seraphel", "Orin"],
}

ABILITY_VARIANTS = {
    "Warlock": [
        {"key": "warlock_soulfire", "name": "Soulfire", "desc": "Deal dmg x2.0 to all enemies in range"},
        {"key": "warlock_drain", "name": "Soul Drain", "desc": "Steal HP from nearest enemy (dmg x2.0 as heal + damage)"},
        {"key": "warlock_bolt", "name": "Shadow Bolt", "desc": "Heavy single-target nuke (dmg x4.0 to nearest)"},
    ],
    "Priest": [
        {"key": "priest_heal", "name": "Holy Armor", "desc": "Heal all allies for dmg x5.0"},
        {"key": "priest_shield", "name": "Divine Shield", "desc": "Weakest ally gains +50% max HP as temporary armor"},
        {"key": "priest_purify", "name": "Purify", "desc": "Lowest-HP ally: heal for dmg x10.0, remove crit vulnerability"},
    ],
    "Tank": [
        {"key": "tank_bash", "name": "Shield Bash", "desc": "Deal armor + damage to nearest enemy"},
        {"key": "tank_taunt", "name": "Taunt", "desc": "Enemies in 150px forced to target this unit, gain +15 armor"},
        {"key": "tank_fortify", "name": "Fortify", "desc": "Gain armor equal to 50% max HP, reduce move speed to 0 for 1 tick"},
    ],
    "Herbalist": [
        {"key": "herbalist_poison", "name": "Magic Potions", "desc": "Poison all enemies for dmg x0.5"},
        {"key": "herbalist_regen", "name": "Rejuvenation", "desc": "Heal all allies for dmg x2.0"},
        {"key": "herbalist_burst", "name": "Noxious Burst", "desc": "Enemies within 150px take dmg x2.0"},
    ],
    "Grunt": [
        {"key": "grunt_frenzy", "name": "Frenzy", "desc": "Attack speed x1.3 permanently"},
        {"key": "grunt_warcry", "name": "War Cry", "desc": "All allies gain +3 damage permanently"},
        {"key": "grunt_cleave", "name": "Cleave", "desc": "Hit all enemies within 100px for dmg x1.5"},
    ],
    "Archer": [
        {"key": "archer_volley", "name": "Volley", "desc": "Hit all enemies for dmg x0.6"},
        {"key": "archer_pierce", "name": "Piercing Shot", "desc": "Single target dmg x3.0, ignores armor"},
        {"key": "archer_mark", "name": "Marked Target", "desc": "Nearest enemy takes +30% more damage from all sources"},
    ],
    "Assassin": [
        {"key": "assassin_shadow", "name": "Shadowstrike", "desc": "+50% crit chance on next hit"},
        {"key": "assassin_poison", "name": "Poison Blade", "desc": "Next 3 attacks deal bonus dmg x0.8 each"},
        {"key": "assassin_vanish", "name": "Vanish", "desc": "+80% evasion for 3 seconds + guaranteed crit on next hit"},
    ],
    "Summoner": [
        {"key": "summoner_archer", "name": "Raise Skeleton", "desc": "Summon a skeleton archer minion"},
        {"key": "summoner_guardian", "name": "Raise Guardian", "desc": "Summon a fortified skeleton (+HP, +armor per round)"},
        {"key": "summoner_familiar", "name": "Raise Revenant", "desc": "Summon a deadly skeleton (+dmg, +crit per round)"},
    ],
    "Paladin": [
        {"key": "paladin_aegis", "name": "Holy Aegis", "desc": "Restore armor + damage buff to allies"},
        {"key": "paladin_smite", "name": "Smite", "desc": "Deal (dmg + armor) x2.0 to nearest enemy, heal self for 50%"},
        {"key": "paladin_consecrate", "name": "Consecrate", "desc": "Deal dmg x1.5 to enemies within 120px, heal allies in range"},
    ],
}

# ── Bot Strategies ────────────────────────────────────────────────────

STRATEGIES = {
    "zerg": {
        "weights": {"Grunt": 5, "Priest": 3, "Archer": 1},
        "desc": "Many cheap 1-cost units",
    },
    "bruiser": {
        "weights": {"Tank": 4, "Grunt": 3, "Paladin": 2},
        "desc": "Tanks + Grunts, heavy armor",
    },
    "caster": {
        "weights": {"Priest": 3, "Warlock": 3, "Herbalist": 3},
        "desc": "Priests, Warlocks, Herbalists",
    },
    "balanced": {
        "weights": {"Grunt": 2, "Priest": 2, "Archer": 2, "Tank": 2, "Warlock": 1, "Herbalist": 1, "Paladin": 1, "Assassin": 1},
        "desc": "Random mix",
    },
    "elite": {
        "weights": {"Paladin": 3, "Summoner": 3, "Assassin": 2, "Warlock": 2},
        "desc": "Fewer expensive units with upgrades",
    },
}

# ── Grid Positions (player half: x 30-450, y 30-450, snapped to 60px) ─

GRID_POSITIONS = []
for _gx in range(30, 451, 60):
    for _gy in range(30, 451, 60):
        GRID_POSITIONS.append((_gx, _gy))


# ── Nakama API Helpers ────────────────────────────────────────────────

def nakama_request(base_url, method, path, body=None, token=None, server_key=None):
    """Make an HTTP request to the Nakama REST API."""
    url = f"{base_url}{path}"
    headers = {"Content-Type": "application/json"}

    if token:
        headers["Authorization"] = f"Bearer {token}"
    elif server_key:
        encoded = base64.b64encode(f"{server_key}:".encode()).decode()
        headers["Authorization"] = f"Basic {encoded}"

    data = json.dumps(body).encode() if body else None
    req = Request(url, data=data, headers=headers, method=method)

    try:
        with urlopen(req) as resp:
            return json.loads(resp.read().decode())
    except HTTPError as e:
        error_body = e.read().decode() if e.fp else ""
        print(f"  HTTP {e.code}: {error_body[:200]}", file=sys.stderr)
        raise
    except URLError as e:
        print(f"  Connection error: {e.reason}", file=sys.stderr)
        raise


BOT_NAMES = [
    "Ironjaw", "Grimwald", "Ashara", "Thornveil", "Stormfist",
    "Duskbane", "Silverleaf", "Emberclaw", "Nighthollow", "Boulderfist",
    "Mistwalker", "Bonecrusher", "Starweaver", "Frostbite", "Cinderheart",
    "Ravencrest", "Steelgaze", "Moonwhisper", "Darkforge", "Wildthorn",
    "Blazefury", "Doomhammer", "Jadescale", "Shadowmend", "Runeblade",
    "Voidcaller", "Goldmane", "Ironfang", "Crystalvow", "Hellscream",
]


def authenticate_bot(base_url, server_key, device_id, display_name):
    """Authenticate a bot via device auth, set username, returns session token."""
    data = nakama_request(
        base_url, "POST",
        "/v2/account/authenticate/device?create=true",
        body={"id": device_id},
        server_key=server_key,
    )
    token = data["token"]
    # Set the bot's display name as its Nakama username
    try:
        nakama_request(
            base_url, "PUT", "/v2/account",
            body={"username": display_name},
            token=token,
        )
    except Exception:
        # Username taken — try with suffix
        try:
            nakama_request(
                base_url, "PUT", "/v2/account",
                body={"username": f"{display_name}_{device_id[-4:]}"},
                token=token,
            )
        except Exception:
            pass  # Keep auto-generated name
    # Re-authenticate to get a fresh JWT with the updated username
    data = nakama_request(
        base_url, "POST",
        "/v2/account/authenticate/device?create=true",
        body={"id": device_id},
        server_key=server_key,
    )
    return data["token"]


def upload_squad(base_url, token, squad_json, round_num, player_name, rating):
    """Upload a squad snapshot to Nakama storage."""
    total_dps = sum(
        u.get("stats", {}).get("damage", 0) * u.get("stats", {}).get("attacks_per_second", 0.5)
        for u in squad_json
    )
    nakama_request(
        base_url, "PUT", "/v2/storage",
        body={
            "objects": [{
                "collection": "squad_snapshots",
                "key": "current",
                "value": json.dumps({
                    "player_name": player_name,
                    "round_number": round_num,
                    "rating_at_time": rating,
                    "squad_json": squad_json,
                    "squad_size": len(squad_json),
                    "total_dps": round(total_dps, 2),
                }),
                "permission_read": 2,
                "permission_write": 1,
            }],
        },
        token=token,
    )


def set_rating(base_url, token, rating, wins, losses):
    """Set a bot's ELO rating and win/loss record via record_result RPC."""
    # Submit wins
    for _ in range(wins):
        nakama_request(
            base_url, "POST", "/v2/rpc/record_result",
            body=json.dumps({"new_rating": rating, "won": True}),
            token=token,
        )
    # Submit losses
    for _ in range(losses):
        nakama_request(
            base_url, "POST", "/v2/rpc/record_result",
            body=json.dumps({"new_rating": rating, "won": False}),
            token=token,
        )
    # Final rating write (in case wins+losses is 0)
    if wins == 0 and losses == 0:
        nakama_request(
            base_url, "POST", "/v2/rpc/record_result",
            body=json.dumps({"new_rating": rating, "won": True}),
            token=token,
        )


# ── Economy Simulation ────────────────────────────────────────────────

def simulate_economy(num_rounds):
    """Simulate the game economy for N rounds, returning final state."""
    gold = STARTING_GOLD
    farms = STARTING_FARMS
    farm_purchases = 0
    last_round_won = False

    for r in range(1, num_rounds + 1):
        if r > 1:
            # Calculate income
            if r <= INCOME_SCALE_ROUND:
                income = BASE_INCOME
            else:
                income = BASE_INCOME + (r - INCOME_SCALE_ROUND)
            if last_round_won:
                income += VICTORY_BONUS
            interest = min(int(gold * INTEREST_RATE), MAX_INTEREST)
            income += interest
            gold += income

        # Randomly decide if we won this round (70% win rate for bots)
        last_round_won = random.random() < 0.7

    return {
        "gold": gold,
        "farms": farms,
        "farm_purchases": farm_purchases,
        "round": num_rounds,
    }


def pick_weighted(weights):
    """Pick a random unit class from weighted dict."""
    classes = list(weights.keys())
    w = [weights[c] for c in classes]
    return random.choices(classes, weights=w, k=1)[0]


def build_squad(strategy_name, gold_budget, farms_budget):
    """Build a squad given a strategy, gold budget, and farm budget."""
    strategy = STRATEGIES[strategy_name]
    weights = strategy["weights"]

    squad = []
    gold = gold_budget
    farms_remaining = farms_budget
    pop_used = 0
    positions_used = set()
    available_positions = list(GRID_POSITIONS)
    random.shuffle(available_positions)

    # Buy farms first (spend ~20% of gold on farms)
    farm_gold = int(gold * random.uniform(0.05, 0.25))
    farm_purchases = 0
    while farm_gold > 0:
        cost = BASE_FARM_COST + farm_purchases // 3
        if farm_gold >= cost:
            farm_gold -= cost
            gold -= cost
            farms_remaining += 1
            farm_purchases += 1
        else:
            break

    # Buy units until we run out of gold or farms
    max_attempts = 50
    attempts = 0
    while gold > 0 and farms_remaining > 0 and available_positions and attempts < max_attempts:
        unit_class = pick_weighted(weights)
        unit = UNITS[unit_class]

        if unit["farm_cost"] > gold or unit["pop_cost"] > farms_remaining:
            attempts += 1
            continue

        attempts = 0
        gold -= unit["farm_cost"]
        farms_remaining -= unit["pop_cost"]
        pop_used += unit["pop_cost"]

        pos = available_positions.pop()
        positions_used.add(pos)

        # Pick random variant
        display_name = random.choice(NAME_POOLS.get(unit_class, [unit_class]))
        ability = random.choice(ABILITY_VARIANTS.get(unit_class, [{"key": "", "name": "", "desc": ""}]))

        # Level: mostly 1, sometimes 2 for late-game bots
        level = 1
        xp = 0
        if gold_budget > 60 and random.random() < 0.3:
            level = 2
            xp = random.randint(0, 2)

        squad.append(build_unit_entry(unit_class, unit, pos, display_name, ability, level, xp))

    return squad


def build_unit_entry(unit_class, base_stats, pos, display_name, ability, level, xp):
    """Build a single squad entry matching SquadSerializer.squad_to_json() format."""
    # Scale stats by level
    level_mult = 1.0 + (level - 1) * 0.15

    stats = {
        "damage": round(base_stats["damage"] * level_mult, 1),
        "max_hp": round(base_stats["max_hp"] * level_mult, 1),
        "attacks_per_second": base_stats["attacks_per_second"],
        "attack_range": base_stats["attack_range"],
        "ability_range": base_stats["ability_range"],
        "move_speed": base_stats["move_speed"],
        "armor": round(base_stats["armor"] * level_mult, 1),
        "max_armor": round(base_stats["armor"] * level_mult, 1),
        "evasion": base_stats["evasion"],
        "crit_chance": base_stats["crit_chance"],
        "skill_proc_chance": base_stats["skill_proc_chance"],
        "max_mana": base_stats["max_mana"],
        "mana_cost_per_attack": base_stats["mana_cost_per_attack"],
        "mana_regen_per_second": base_stats["mana_regen_per_second"],
        "hp_regen_per_second": 0.0,
    }

    return {
        "unit_class": unit_class,
        "position": {"x": pos[0], "y": pos[1]},
        "level": level,
        "xp": xp,
        "display_name": display_name,
        "ability_key": ability["key"],
        "instance_ability_name": ability["name"],
        "instance_ability_desc": ability["desc"],
        "necromancy_stacks": 0,
        "primed": False,
        "poison_power": 0,
        "thorns_slow": False,
        "lifesteal_pct": 0.0,
        "last_stand": False,
        "relentless": False,
        "sepsis_spread": 0,
        "living_shield_max": 0,
        "invincible_max": 0,
        "haymaker_counter": 0,
        "legion_master": False,
        "stats": stats,
        "applied_upgrades": [],
    }


# ── Main ──────────────────────────────────────────────────────────────

def create_bot(base_url, server_key, bot_index, target_rating=None):
    """Create a single bot: auth, build squad, upload, set rating."""
    device_id = f"pvp-bot-{bot_index:04d}-{uuid.uuid4().hex[:8]}"
    bot_name = BOT_NAMES[(bot_index - 1) % len(BOT_NAMES)]

    # 1. Authenticate
    print(f"  [{bot_index}] Authenticating {bot_name}...")
    token = authenticate_bot(base_url, server_key, device_id, bot_name)

    # 2. Simulate economy (random 5-15 rounds)
    num_rounds = random.randint(5, 15)
    econ = simulate_economy(num_rounds)

    # 3. Pick strategy
    strategy_name = random.choice(list(STRATEGIES.keys()))

    # 4. Build squad
    squad = build_squad(strategy_name, econ["gold"], econ["farms"])
    if not squad:
        print(f"  [{bot_index}] Warning: empty squad, skipping")
        return False

    # 5. Pick rating
    if target_rating is None:
        # Spread bots across the rating spectrum: 600-1400
        target_rating = random.randint(600, 1400)

    # Generate plausible win/loss record for the rating
    if target_rating > 1000:
        games = random.randint(3, 15)
        win_pct = 0.5 + (target_rating - 1000) / 1000.0
        win_pct = min(win_pct, 0.85)
        wins = max(1, int(games * win_pct))
        losses = games - wins
    else:
        games = random.randint(3, 15)
        win_pct = 0.5 - (1000 - target_rating) / 1000.0
        win_pct = max(win_pct, 0.15)
        wins = max(0, int(games * win_pct))
        losses = games - wins

    # 6. Upload squad
    print(f"  [{bot_index}] Uploading squad: {len(squad)} units, strategy={strategy_name}, round={econ['round']}")
    upload_squad(base_url, token, squad, econ["round"], bot_name, target_rating)

    # 7. Set rating
    print(f"  [{bot_index}] Setting rating: {target_rating} (W:{wins} L:{losses})")
    set_rating(base_url, token, target_rating, wins, losses)

    print(f"  [{bot_index}] Done: {bot_name} — rating {target_rating}, {len(squad)} units ({strategy_name})")
    return True


def main():
    parser = argparse.ArgumentParser(description="Create PvP bot accounts on Nakama")
    parser.add_argument("--bots", type=int, default=10, help="Number of bots to create (default: 10)")
    parser.add_argument("--host", type=str, default="127.0.0.1", help="Nakama host (default: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=7350, help="Nakama port (default: 7350)")
    parser.add_argument("--server-key", type=str, default="defaultkey", help="Nakama server key (default: defaultkey)")
    parser.add_argument("--ssl", action="store_true", help="Use HTTPS")
    parser.add_argument("--min-rating", type=int, default=600, help="Minimum bot rating (default: 600)")
    parser.add_argument("--max-rating", type=int, default=1400, help="Maximum bot rating (default: 1400)")
    args = parser.parse_args()

    scheme = "https" if args.ssl else "http"
    base_url = f"{scheme}://{args.host}:{args.port}"

    print(f"PvP Bot Test — Creating {args.bots} bots on {base_url}")
    print(f"Rating range: {args.min_rating} - {args.max_rating}")
    print()

    # Spread ratings evenly across the range
    success = 0
    for i in range(args.bots):
        # Evenly distribute ratings with some jitter
        if args.bots > 1:
            base_rating = args.min_rating + int((args.max_rating - args.min_rating) * i / (args.bots - 1))
        else:
            base_rating = (args.min_rating + args.max_rating) // 2
        jitter = random.randint(-30, 30)
        rating = max(args.min_rating, min(args.max_rating, base_rating + jitter))

        try:
            if create_bot(base_url, args.server_key, i + 1, rating):
                success += 1
        except Exception as e:
            print(f"  [{i + 1}] FAILED: {e}", file=sys.stderr)

    print()
    print(f"Done: {success}/{args.bots} bots created successfully.")
    if success > 0:
        print(f"Check Nakama console at http://{args.host}:7351 to verify.")


if __name__ == "__main__":
    main()
