# FloatingCombatTextXI

**Version**: 1.0  
**Author**: Oxos

---

## Overview

**FloatingCombatTextXI** is an addon for Final Fantasy XI that logs and displays player damage from combat logs as floating text. It provides a visual display of melee, weapon skill, and spell damage, with distinct notifications for critical hits and misses. The addon splits floating combat text into different sections for melee attacks, weapon skills, and spell casting, providing players with a clean and concise view of their combat performance.

Derived from ActionParse from at0mos to debug action packets!

---

## Features

- **Melee Attack Damage**: Displays white text for normal melee damage and differentiates critical hits with a "(Crit)" suffix.
- **Weapon Skill Damage**: Displays yellow text with a clear "Weaponskill" prefix for weapon skill damage.
- **Spell Damage**: Displays blue text for spell-based damage.
- **Critical Hits and Misses**: Automatically detects critical hits and misses, appending the appropriate suffix to the damage text.

---

## Installation

1. Download the `FloatingCombatTextXI` addon.
2. Extract the files into your Ashita addon folder:  
   `Ashita/addons/FloatingCombatTextXI/`.
3. (Optional) To use a custom font, place your `.ttf` or `.otf` font file in the same folder and modify the `font_path` in the script to point to the font file.

---

## Usage

1. Launch **Ashita** and load the addon:
   ```bash
   /addon load FloatingCombatTextXI


