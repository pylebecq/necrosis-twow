# Necrosis TurtleWoW 🐢

This is fork of version 1.5.2a of the Necrosis LdC addon for Turtle WoW server.

## Changes

### Oct 11, 2025

- Fix a repeating error being displayed when using a Soulstone, Spellstone, or Healthstone, when graphical timers are enabled

### Oct 10, 2025

- Fully removed support for French and German languages.

### Sep 24, 2025

- Drastically reduced memory allocation in the Necrosis_OnUpdate function.

### Sep 18, 2025

- Updated the Spellstone button:
	- When there is a Spellstone in the player's bags, the button will use it.
	- When there is no Spellstone in the player's bags, the button will create one.
- Using a Healthstone or a Spellstone will now add a cooldown timer for both Healthstone and Spellstone since they share their cooldown since Turtle WoW 1.18.
- Changed the Healthstone and Spellstone timer duration to 2 minutes (down from 3 minutes).

### Sep 17, 2025

- Fixed the error being displayed every second as soon as the player learn the Demonic Sacrifice.

### Aug 24, 2025

- Updated the name of the addon in the TOC file to mention it is specific to TurtleWoW.
- Updated the Firestone button:
	- When there is a Firestone in the player's bags, the button will use it.
	- When there is no Firestone in the player's bags, the button will create one.

### Feb 9, 2025

- Updated shard counting and Fel Domination CD tracking.

### May 14, 2024

- Removed init dialog options. English is now the only supported language.
