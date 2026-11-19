class_name CharacterData
extends Resource
## One resource represents one unique character. Battle state is stored separately.

const WeaponDefinition = preload("res://scripts/weapon_data.gd")

@export var character_name: String = "Character"
@export var portrait: Texture2D
@export var equipped_weapon: WeaponDefinition

@export_group("Stats")
@export_range(0, 99, 1) var movement: int = 3
## Each point grants 1 max HP and 1 percentage point of avoidance.
@export_range(1, 999, 1) var puissance: int = 10
@export_range(1, 99, 1) var attack_range: int = 1
## Adds to damage per strike. Exceed the weapon's Weight to strike twice.
@export_range(0, 999, 1) var furie: int = 1
## Reduces incoming damage per hit. Falling below the weapon's Weight applies Weight Penalty.
@export_range(0, 999, 1) var vaillance: int = 0
## Adds 5 percentage points to hit chance per point.
@export_range(0, 999, 1) var dexterite: int = 0


func _set(property: StringName, value: Variant) -> bool:
	# Load older character resources with their original stat values.
	match property:
		&"damage":
			furie = int(value)
		&"max_hp":
			puissance = int(value)
		_:
			return false
	return true
