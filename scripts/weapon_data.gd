class_name WeaponData
extends Resource

@export var weapon_name: String = "Weapon"
@export_range(0, 999, 1) var attack: int = 1
## Base chance to hit, as a percentage.
@export_range(0, 100, 1, "suffix:%") var precision: int = 95
@export_range(0, 999, 1) var weight: int = 1
@export_range(0, 100, 1, "suffix:%") var crit: int = 0
