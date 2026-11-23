class_name CharacterData
extends Resource
## One resource represents one unique character. Battle state is stored separately.

const WeaponDefinition = preload("res://scripts/weapon_data.gd")

@export var character_name: String = "Character"
@export var portrait: Texture2D
@export var equipped_weapon: WeaponDefinition

@export_group("Stats")
@export_range(0, 99, 1) var movement: int = 3
## Each point grants 1 max HP.
@export_range(1, 999, 1) var puissance: int = 10
@export_range(1, 99, 1) var attack_range: int = 1
## Adds to damage and helps qualify for a follow-up strike.
@export_range(0, 999, 1) var furie: int = 1
## Reduces incoming damage. Exceed the weapon's Weight to ignore it in combat.
@export_range(0, 999, 1) var vaillance: int = 0
## Adds to accuracy and priority.
@export_range(0, 999, 1) var dexterite: int = 0
@export_range(0, 999, 1) var elan: int = 1
## Affects criticals and makes opponents less likely to qualify for counters and follow-ups.
@export_range(0, 999, 1) var temperance: int = 0


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
