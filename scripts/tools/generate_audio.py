#!/usr/bin/env python3
"""
Generate missing sound effects and battle music using the ElevenLabs API.

Usage:
    export ELEVENLABS_API_KEY="your-api-key"
    python3 scripts/tools/generate_audio.py

Options:
    --sfx-only      Only generate missing sound effects
    --music-only    Only generate battle music
    --force         Regenerate even if file already exists
"""

import os
import sys
import time
import argparse
import requests

API_KEY = os.environ.get("ELEVENLABS_API_KEY", "")
SFX_URL = "https://api.elevenlabs.io/v1/sound-generation"
MUSIC_URL = "https://api.elevenlabs.io/v1/music"
AUDIO_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")

HEADERS = {
    "xi-api-key": API_KEY,
    "Content-Type": "application/json",
}

# ── Missing SFX definitions ──────────────────────────────────────────────────
# Each entry: (filename, prompt, duration_seconds, prompt_influence)

SFX_DEFS = [
    (
        "ability_melee.mp3",
        "Short powerful melee sword slash attack with a metallic swoosh, "
        "fantasy game combat sound effect",
        1.5,
        0.4,
    ),
    (
        "ability_stealth.mp3",
        "Quick shadowy stealth vanish sound, dark whoosh with a subtle magical "
        "shimmer, rogue assassin disappearing, game sound effect",
        1.5,
        0.4,
    ),
    (
        "ability_ranged.mp3",
        "Arrow being released from a bow with a sharp twang and whoosh through "
        "the air, fantasy archer ability game sound effect",
        1.5,
        0.4,
    ),
    (
        "ability_holy.mp3",
        "Bright radiant holy spell cast with angelic chime and warm golden light "
        "shimmer, paladin healing ability, fantasy game sound effect",
        2.0,
        0.4,
    ),
    (
        "ability_dark.mp3",
        "Dark sinister warlock spell cast with deep rumbling bass and eerie "
        "whispers, shadow magic curse, fantasy game sound effect",
        2.0,
        0.4,
    ),
    (
        "ability_nature.mp3",
        "Nature magic spell with rustling leaves and gentle wind chime, druid "
        "herbalist casting a growth spell, fantasy game sound effect",
        2.0,
        0.4,
    ),
    (
        "coin.mp3",
        "Satisfying heavy gold coin thunk and metallic cling, a thick gold coin "
        "landing on a wooden table with a rich resonant ring, weighty and rewarding, "
        "fantasy RPG loot reward sound effect",
        1.0,
        0.5,
    ),
]

# ── Battle music definition ──────────────────────────────────────────────────

BATTLE_MUSIC_PROMPT = (
    "Epic fantasy auto-battler combat music. Driving orchestral percussion with "
    "war drums, aggressive brass fanfares, and tense string ostinatos. Dark medieval "
    "battle atmosphere with heroic undertones. Fast-paced 140 BPM, minor key. "
    "Think epic tavern brawl meets army clash. Loop-friendly ending."
)
BATTLE_MUSIC_DURATION_MS = 60000  # 60 seconds
BATTLE_MUSIC_FILE = "battle_music.mp3"


def generate_sfx(filename: str, prompt: str, duration: float, influence: float, force: bool = False) -> bool:
    """Generate a single sound effect and save to assets/audio/."""
    filepath = os.path.join(AUDIO_DIR, filename)

    if os.path.exists(filepath) and not force:
        print(f"  SKIP  {filename} (already exists)")
        return True

    print(f"  GEN   {filename} — \"{prompt[:60]}...\"")

    body = {
        "text": prompt,
        "duration_seconds": duration,
        "prompt_influence": influence,
    }

    try:
        resp = requests.post(SFX_URL, headers=HEADERS, json=body, timeout=60)
        resp.raise_for_status()
    except requests.RequestException as e:
        print(f"  FAIL  {filename} — {e}")
        return False

    with open(filepath, "wb") as f:
        f.write(resp.content)

    size_kb = len(resp.content) / 1024
    print(f"  OK    {filename} ({size_kb:.1f} KB)")
    return True


def generate_music(force: bool = False) -> bool:
    """Generate battle music and save to assets/audio/."""
    filepath = os.path.join(AUDIO_DIR, BATTLE_MUSIC_FILE)

    if os.path.exists(filepath) and not force:
        print(f"  SKIP  {BATTLE_MUSIC_FILE} (already exists)")
        return True

    print(f"  GEN   {BATTLE_MUSIC_FILE} — battle music ({BATTLE_MUSIC_DURATION_MS // 1000}s)")

    body = {
        "prompt": BATTLE_MUSIC_PROMPT,
        "music_length_ms": BATTLE_MUSIC_DURATION_MS,
        "model_id": "music_v1",
        "force_instrumental": True,
    }

    try:
        resp = requests.post(MUSIC_URL, headers=HEADERS, json=body, timeout=300)
        resp.raise_for_status()
    except requests.RequestException as e:
        print(f"  FAIL  {BATTLE_MUSIC_FILE} — {e}")
        return False

    with open(filepath, "wb") as f:
        f.write(resp.content)

    size_kb = len(resp.content) / 1024
    print(f"  OK    {BATTLE_MUSIC_FILE} ({size_kb:.1f} KB)")
    return True


def main():
    parser = argparse.ArgumentParser(description="Generate missing audio via ElevenLabs API")
    parser.add_argument("--sfx-only", action="store_true", help="Only generate SFX")
    parser.add_argument("--music-only", action="store_true", help="Only generate music")
    parser.add_argument("--force", action="store_true", help="Regenerate existing files")
    args = parser.parse_args()

    if not API_KEY:
        print("ERROR: Set ELEVENLABS_API_KEY environment variable")
        print("  export ELEVENLABS_API_KEY=\"your-api-key\"")
        sys.exit(1)

    os.makedirs(AUDIO_DIR, exist_ok=True)

    do_sfx = not args.music_only
    do_music = not args.sfx_only

    success = 0
    failed = 0
    skipped = 0

    if do_sfx:
        print("\n=== Generating missing sound effects ===\n")
        for filename, prompt, duration, influence in SFX_DEFS:
            filepath = os.path.join(AUDIO_DIR, filename)
            if os.path.exists(filepath) and not args.force:
                skipped += 1
                print(f"  SKIP  {filename}")
                continue
            if generate_sfx(filename, prompt, duration, influence, args.force):
                success += 1
            else:
                failed += 1
            # Rate limiting — small delay between requests
            time.sleep(1)

    if do_music:
        print("\n=== Generating battle music ===\n")
        filepath = os.path.join(AUDIO_DIR, BATTLE_MUSIC_FILE)
        if os.path.exists(filepath) and not args.force:
            skipped += 1
            print(f"  SKIP  {BATTLE_MUSIC_FILE}")
        elif generate_music(args.force):
            success += 1
        else:
            failed += 1

    print(f"\n=== Done: {success} generated, {skipped} skipped, {failed} failed ===\n")

    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
