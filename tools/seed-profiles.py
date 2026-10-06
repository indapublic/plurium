#!/usr/bin/env python3
"""Names test profiles in /tmp/chromium-test/Local State (browser must be closed).

Profiles: Default=Alpha, "Profile 1"=Bravo, "Profile 2"=Charlie, "Profile 3"=Delta.
Open one with: plurium/tools/run-test.sh --profile-directory="Profile 1"
Each profile also gets its own theme color (browser.theme.user_color2).
Pass --restore to also set "Continue where you left off" in every profile.
"""
import json
import os
import sys

USER_DATA_DIR = os.environ.get("USER_DATA_DIR", "/tmp/chromium-test")
PROFILES = {"Default": "Alpha", "Profile 1": "Bravo", "Profile 2": "Charlie",
            "Profile 3": "Delta"}
# Per-profile theme colors ("Customize Chromium > Color"), as SkColor ARGB.
COLORS = {"Default": 0xFF1A73E8, "Profile 1": 0xFFD93025,
          "Profile 2": 0xFF188038, "Profile 3": 0xFFF9AB00}


def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        return {}


def save(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f)


def main():
    local_state_path = os.path.join(USER_DATA_DIR, "Local State")
    local_state = load(local_state_path)
    profile_prefs = local_state.setdefault("profile", {})
    # Open the last used profiles on startup instead of the profile picker.
    profile_prefs["show_picker_on_startup"] = False
    cache = profile_prefs.setdefault("info_cache", {})
    for directory, name in PROFILES.items():
        entry = cache.setdefault(directory, {})
        entry["name"] = name
        entry["is_using_default_name"] = False
    save(local_state_path, local_state)

    for directory in PROFILES:
        prefs_path = os.path.join(USER_DATA_DIR, directory, "Preferences")
        prefs = load(prefs_path)
        color = COLORS[directory]
        prefs.setdefault("browser", {}).setdefault("theme", {})["user_color2"] = (
            color - 2**32 if color >= 2**31 else color)
        if "--restore" in sys.argv:
            prefs.setdefault("session", {})["restore_on_startup"] = 1
        save(prefs_path, prefs)
    print("profiles:", ", ".join(f"{d}={n}" for d, n in PROFILES.items()))


if __name__ == "__main__":
    main()
