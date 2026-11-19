# Ilan — Hex Prototype

A turn-based tactics prototype on a hex grid, built with Godot and GDScript.

1. Clone this repository.
2. Install [Godot 4.7.2 Standard](https://godotengine.org/download/archive/4.7.2-stable/).
3. In the Godot Project Manager, choose **Import** and select `project.godot`.
4. Open the project and press **F5** to play.

Select an ally to see its movement and attack reach. Hover over a reachable
enemy for the battle forecast, then click to attack. Use **End Turn** when your
team is ready.

- Edit character stats and equipment in the Inspector using the files in `characters/`.
- Edit weapon stats using the files in `weapons/`.
- The prototype's board size and starting positions are in `scripts/hex_board.gd`. Open `main.tscn` to edit the scene and HUD.

See [SETUP.md](SETUP.md) for more on the character stats and the local launcher.
