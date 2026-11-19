# Development setup

Use **Godot 4.7.2 Standard** with **GDScript**. Both collaborators should use
the same engine version.

## This machine (Linux x86_64)

The official portable editor lives in `.tools/godot/` (excluded from Git).
The launcher also keeps editor settings, caches, and development saves there.
From this directory, open this project in the editor with:

```sh
./godot.sh
```

Press **F5** in the editor to run the game and **F8** to stop it.
Close and rerun the game to see code changes.

To run the game directly without opening the editor:

```sh
./godot.sh --path .
```

Git is already installed. Godot includes its own script editor; no .NET SDK or
external code editor is required for GDScript.

## Ilan's machine

Download **Godot 4.7.2 Standard** for the appropriate operating system from
[the official archive](https://godotengine.org/download/archive/4.7.2-stable/).
Install Git as well to share the project. The local `.tools/` directory is not
shared through Git; each developer installs the editor separately.

## Editing individual characters

In Godot's **FileSystem** panel, open `res://characters/` and click a `.tres`
file: `blue_1`, `blue_2`, `red_1`, `red_2`, or `red_3`. Each file represents
one unique character. The **Inspector** exposes its name, portrait, movement,
Puissance, attack range, Furie, Vaillance, and Dexterite. Expand **Stats** to see
the numeric fields. Each point of Dexterite adds 5 precision. Each point of
Puissance grants 1 max HP and subtracts 1 percentage point from an opponent's
hit chance. The final chance is capped between 0% and 100%.
Edit weapon Weight on the weapon resource under `res://weapons/`. Each strike
deals Furie plus weapon ATK on a hit. Furie above the equipped weapon's Weight
grants a second strike in the same attack action.
The target's Vaillance reduces each hit's damage to a minimum of zero.
A character has Weight Penalty when their Vaillance falls below their equipped
weapon's Weight. The penalty currently appears in the unit panel.
Save the resource after editing, then stop and restart the game to apply it.

Current HP, remaining movement, facing, and spent actions are separate battle
state; playing the game does not change the character's saved resource.

## Exporting

When packaging a build, install the matching export templates through
**Editor → Manage Export Templates**. They are not required to develop or run
the game inside Godot.
