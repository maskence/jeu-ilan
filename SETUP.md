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

In Godot's **FileSystem** panel, open a character resource under
`res://characters/`. Each file has its own name, portrait, equipped weapon,
attack range, and stats. The current test battle has five units per side.
To start a new character from a level-1 preset, duplicate a resource from
`res://characters/presets/`, then edit the copy in the **Inspector**.

Puissance sets max HP. Dextérité and effective weapon Weight determine
priority. Vaillance ignores Weight only when it exceeds the weapon's Weight.
An in-range defender can counter when its Vaillance plus Elan exceeds the
initiator's Tempérance. A higher-priority defender counters first. The
initiator qualifies for a follow-up when Furie exceeds the sum of effective
Weight and defender Tempérance.

The Battle Forecast shows attack order, damage, hit chance, and crit chance.
Rear attacks gain 10 hit and 1 damage. Criticals double damage after Vaillance.
Edit weapon ATK, precision, Weight, and Crit in `res://weapons/`.
Save the resource after editing, then stop and restart the game to apply it.

Current HP, remaining movement, facing, and spent actions are separate battle
state; playing the game does not change the character's saved resource.

## Exporting

When packaging a build, install the matching export templates through
**Editor → Manage Export Templates**. They are not required to develop or run
the game inside Godot.
