extends Node2D

const COLUMNS: int = 14
const ROWS: int = 10
const HEX_SIZE: float = 48.0
const UNIT_RADIUS: float = HEX_SIZE * 0.47
const CharacterDefinition = preload("res://scripts/character_data.gd")
const WeaponDefinition = preload("res://scripts/weapon_data.gd")
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]

# Each unit owns its movement budget, position, and facing independently.
class Unit:
	extends RefCounted
	var number: int
	var hex: Vector2i
	var position: Vector2
	var max_movement: int
	var movement: int
	var facing: int
	var enemy: bool
	var unit_name: String
	var character: CharacterDefinition
	var portrait: Texture2D
	var max_hp: int
	var hp: int
	var attack_range: int
	var furie: int
	var vaillance: int
	var dexterite: int
	var equipped_weapon: WeaponDefinition
	var actions_done: bool = false

	func _init(id: int, cell: Vector2i, definition: CharacterDefinition, is_enemy: bool) -> void:
		number = id
		hex = cell
		character = definition
		max_movement = definition.movement
		movement = max_movement
		enemy = is_enemy
		facing = 3 if enemy else 0
		unit_name = definition.character_name
		portrait = definition.portrait
		max_hp = definition.puissance
		hp = max_hp
		attack_range = definition.attack_range
		furie = definition.furie
		vaillance = definition.vaillance
		dexterite = definition.dexterite
		equipped_weapon = definition.equipped_weapon

	func attack_damage() -> int:
		return furie + (equipped_weapon.attack if equipped_weapon != null else 0)

	func effective_weight() -> int:
		if equipped_weapon == null or vaillance > equipped_weapon.weight:
			return 0
		return equipped_weapon.weight

	func priority() -> int:
		return dexterite - effective_weight()


class Strike:
	var attacker: Unit
	var target: Unit
	var damage: int
	var hit_chance: int
	var crit_chance: int
	var is_counter: bool

	func _init(source: Unit, defender: Unit, rear: bool, counter: bool) -> void:
		attacker = source
		target = defender
		is_counter = counter
		var weapon_accuracy: int = source.equipped_weapon.precision if source.equipped_weapon != null else 100
		var weapon_crit: int = source.equipped_weapon.crit if source.equipped_weapon != null else 0
		var accuracy: int = source.dexterite + floori(source.character.elan / 2.0) + weapon_accuracy
		accuracy += 10 if rear else 0
		hit_chance = clampi(accuracy - defender.priority() - source.effective_weight(), 0, 100)
		damage = maxi(0, source.attack_damage() + (1 if rear else 0) - defender.vaillance)
		var critical: int = floori(source.character.temperance / 2.0) + weapon_crit
		crit_chance = clampi(critical - floori(defender.character.temperance / 2.0), 0, 100)


class Exchange:
	var opening: Strike
	var counter: Strike
	var counter_eligible: bool
	var follow_up: bool
	var strikes: Array[Strike] = []


var cells: Dictionary[Vector2i, bool] = {}
var players: Array[Unit] = []
var enemies: Array[Unit] = []
var selected_unit: Unit = null
var inspected_enemy: Unit = null
var enemy_movement_tiles: Dictionary[Vector2i, int] = {}
var enemy_attack_tiles: Dictionary[Vector2i, bool] = {}
var player_turn: bool = true
var turn_number: int = 1
var moving: bool = false
var choosing_facing: bool = false
var reachable: Dictionary[Vector2i, int] = {}
var ally_attack_tiles: Dictionary[Vector2i, bool] = {}
var preview_path: Array[Vector2i] = []
var attack_targets: Dictionary[Vector2i, bool] = {}
var preview_target: Unit = null:
	set(value):
		preview_target = value
		_update_battle_forecast()
var hovered_unit: Unit = null
var hit_unit: Unit = null
var hit_damage: int = 0
var attack_hit: bool = false
var critical_hit: bool = false
var counter_strike: bool = false
var battle_over: bool = false
@onready var instructions: Label = $"../HUD/Controls/Instructions"
@onready var end_turn_button: Button = $"../HUD/Controls/EndTurn"
@onready var info_panel: PanelContainer = $"../HUD/Controls/UnitInfo"
@onready var portrait: TextureRect = $"../HUD/Controls/UnitInfo/Margin/Row/Portrait"
@onready var info_name: Label = $"../HUD/Controls/UnitInfo/Margin/Row/Details/Name"
@onready var hp_bar: ProgressBar = $"../HUD/Controls/UnitInfo/Margin/Row/Details/HPBar"
@onready var hp_text: Label = $"../HUD/Controls/UnitInfo/Margin/Row/Details/HPText"
@onready var weapon_text: Label = $"../HUD/Controls/UnitInfo/Margin/Row/Details/WeaponText"
@onready var forecast_panel: PanelContainer = $"../HUD/Controls/BattleForecast"
@onready var forecast_comparison: GridContainer = $"../HUD/Controls/BattleForecast/Margin/Details/Comparison"
@onready var forecast_order: HBoxContainer = $"../HUD/Controls/BattleForecast/Margin/Details/Order"
@onready var forecast_counter_note: Label = $"../HUD/Controls/BattleForecast/Margin/Details/CounterNote"


func _ready() -> void:
	for row in range(ROWS):
		for column in range(COLUMNS):
			cells[Vector2i(column - floori(row / 2.0), row)] = true
	var starting_rows: Array[int] = [2, 4, 5, 7, 8]
	for index in range(starting_rows.size()):
		var row: int = starting_rows[index]
		var offset: int = floori(row / 2.0)
		var number: int = index + 1
		var blue: CharacterDefinition = load("res://characters/blue_%d.tres" % number)
		var red: CharacterDefinition = load("res://characters/red_%d.tres" % number)
		players.append(Unit.new(number, Vector2i(4 - offset, row), blue, false))
		enemies.append(Unit.new(number, Vector2i(8 - offset, row), red, true))
	for unit in players + enemies:
		unit.position = hex_to_pixel(unit.hex)
	end_turn_button.pressed.connect(end_turn)
	get_viewport().size_changed.connect(_resize_board)
	_resize_board()
	_update_status()
	_update_info_panel()


func _unit_at(hex: Vector2i) -> Unit:
	for unit in players + enemies:
		if unit.hex == hex:
			return unit
	return null


func _update_info_panel() -> void:
	var unit: Unit = hovered_unit if hovered_unit != null else selected_unit
	if unit == null:
		unit = inspected_enemy
	info_panel.visible = unit != null
	if unit == null:
		return
	portrait.texture = unit.portrait
	info_name.text = unit.unit_name
	hp_bar.max_value = unit.max_hp
	hp_bar.value = unit.hp
	hp_text.text = "%d / %d HP" % [unit.hp, unit.max_hp]
	var weapon_name: String = unit.equipped_weapon.weapon_name if unit.equipped_weapon != null else "Unarmed"
	if unit.equipped_weapon != null:
		weapon_name += " · Weight %d" % unit.equipped_weapon.weight
	weapon_text.text = "%s\nFurie %d · Vaillance %d\nDextérité %d · Priority %d\nPuissance %d\nElan %d · Tempérance %d\n%d base damage · Range %d" % [
		weapon_name, unit.furie, unit.vaillance, unit.dexterite, unit.priority(), unit.max_hp,
		unit.character.elan, unit.character.temperance, unit.attack_damage(), unit.attack_range
	]
	if unit.effective_weight() > 0:
		weapon_text.text += "\nWeight penalty %d" % unit.effective_weight()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hex: Vector2i = pixel_to_hex(to_local(event.position))
		hovered_unit = _unit_at(hex)
		_update_info_panel()
		_update_preview(hex)


func _is_occupied(hex: Vector2i, except_unit: Unit = null) -> bool:
	for unit in players + enemies:
		if unit != except_unit and unit.hex == hex:
			return true
	return false


func _update_movement_range() -> void:
	reachable.clear()
	ally_attack_tiles.clear()
	attack_targets.clear()
	if selected_unit == null or selected_unit.actions_done:
		queue_redraw()
		return
	reachable = _movement_costs(selected_unit)
	ally_attack_tiles = _attack_tiles(selected_unit, reachable)
	for enemy in enemies:
		if not _attack_route(selected_unit, enemy).is_empty():
			attack_targets[enemy.hex] = true
	queue_redraw()


func _movement_costs(unit: Unit) -> Dictionary[Vector2i, int]:
	var costs: Dictionary[Vector2i, int] = {unit.hex: 0}
	var frontier: Array[Vector2i] = [unit.hex]
	var index: int = 0
	while index < frontier.size():
		var current: Vector2i = frontier[index]
		index += 1
		if costs[current] >= unit.movement or unit.actions_done:
			continue
		for direction in DIRECTIONS:
			var neighbor: Vector2i = current + direction
			if cells.has(neighbor) and not _is_occupied(neighbor, unit) and not costs.has(neighbor):
				costs[neighbor] = costs[current] + 1
				frontier.append(neighbor)
	return costs


func _attack_tiles(unit: Unit, origins: Dictionary[Vector2i, int]) -> Dictionary[Vector2i, bool]:
	var tiles: Dictionary[Vector2i, bool] = {}
	if unit.actions_done:
		return tiles
	for origin: Vector2i in origins:
		for cell: Vector2i in cells:
			var distance: int = _hex_distance(origin, cell)
			var occupant: Unit = _unit_at(cell)
			if distance > 0 and distance <= unit.attack_range and (occupant == null or occupant.enemy != unit.enemy):
				tiles[cell] = true
	return tiles


func _inspect_enemy(enemy: Unit) -> void:
	_clear_selection()
	inspected_enemy = enemy
	enemy_movement_tiles = _movement_costs(enemy)
	enemy_attack_tiles = _attack_tiles(enemy, enemy_movement_tiles)
	_update_info_panel()
	_update_status()
	queue_redraw()


func _update_status() -> void:
	end_turn_button.disabled = moving or not player_turn or battle_over
	if battle_over:
		instructions.text = "Victory!" if enemies.is_empty() else "Defeat!"
		return
	if not player_turn:
		instructions.text = "Turn %d · Enemy turn" % turn_number
		return
	var instruction: String = "Click a blue unit to select it. End Turn when ready."
	if moving:
		instruction = "Moving…"
	elif choosing_facing:
		instruction = "%s: click to confirm facing, or click an enemy in range to attack." % selected_unit.unit_name
	elif selected_unit != null and selected_unit.actions_done:
		instruction = "%s has finished all actions this turn." % selected_unit.unit_name
	elif selected_unit != null:
		instruction = "%s · Blue: movement · Orange: attack reach · Click a hex or marked enemy." % selected_unit.unit_name
	elif inspected_enemy != null:
		instruction = "%s · Red hexes: movement · Orange hexes: attack reach" % inspected_enemy.unit_name
	var budgets: PackedStringArray = []
	for unit in players:
		budgets.append("Blue %d: %s" % [unit.number, "done" if unit.actions_done else "%d / %d" % [unit.movement, unit.max_movement]])
	instructions.text = "Turn %d · Your turn · %s\n%s" % [turn_number, " · ".join(budgets), instruction]


func _update_battle_forecast() -> void:
	forecast_panel.visible = preview_target != null and selected_unit != null
	if not forecast_panel.visible:
		return
	var attack_hex: Vector2i = selected_unit.hex if preview_path.is_empty() else preview_path[-1]
	var exchange: Exchange = _plan_exchange(selected_unit, preview_target, attack_hex)
	_set_forecast_column("Ally", exchange.opening, true)
	_set_forecast_column("Enemy", exchange.counter, exchange.counter_eligible)

	for index in range(forecast_order.get_child_count()):
		var slot: PanelContainer = forecast_order.get_child(index)
		slot.visible = index < exchange.strikes.size()
		if not slot.visible:
			continue
		var strike: Strike = exchange.strikes[index]
		var action: String = "Attack"
		if strike.is_counter:
			action = "Counter"
		elif index == exchange.strikes.size() - 1 and exchange.follow_up:
			action = "Follow-up"
		var side: String = "Red" if strike.attacker.enemy else "Blue"
		var step: Label = slot.get_node("Step")
		step.text = "%d  %s %d\n%s" % [index + 1, side, strike.attacker.number, action]
		step.modulate = Color("ff9090") if strike.attacker.enemy else Color("6bc2ff")

	forecast_counter_note.visible = not exchange.counter_eligible
	if forecast_counter_note.visible:
		var out_of_range: bool = _hex_distance(preview_target.hex, attack_hex) > preview_target.attack_range
		forecast_counter_note.text = "No counter · Out of range" if out_of_range else "No counter · Stat threshold not met"


func _set_forecast_column(column: String, strike: Strike, can_strike: bool) -> void:
	var name_label: Label = forecast_comparison.get_node("Name" + column)
	var damage_label: Label = forecast_comparison.get_node("Damage" + column)
	var hit_label: Label = forecast_comparison.get_node("Hit" + column)
	var crit_label: Label = forecast_comparison.get_node("Crit" + column)
	name_label.text = strike.attacker.unit_name
	damage_label.text = str(strike.damage) if can_strike else "—"
	hit_label.text = "%d%%" % strike.hit_chance if can_strike else "—"
	crit_label.text = "%d%%" % strike.crit_chance if can_strike else "—"


func _update_preview(target: Vector2i) -> void:
	preview_path.clear()
	var hovered_target: Unit = null
	if player_turn and selected_unit != null and not selected_unit.actions_done and not moving:
		var enemy: Unit = _unit_at(target)
		if enemy != null and enemy.enemy:
			var route: Array[Vector2i] = _attack_route(selected_unit, enemy)
			if not route.is_empty():
				preview_path = route.slice(1)
				hovered_target = enemy
		elif not choosing_facing and reachable.has(target) and target != selected_unit.hex:
			preview_path = find_path(target)
	preview_target = hovered_target
	queue_redraw()


func _resize_board() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var board_size := Vector2(
		HEX_SIZE * sqrt(3.0) * (COLUMNS + 0.5),
		HEX_SIZE * (2.0 + 1.5 * (ROWS - 1))
	)
	var zoom: float = minf(viewport_size.x / board_size.x, viewport_size.y / board_size.y)
	scale = Vector2.ONE * zoom
	position = (viewport_size - board_size * zoom) / 2.0 + Vector2(
		HEX_SIZE * sqrt(3.0) / 2.0, HEX_SIZE
	) * zoom


func hex_to_pixel(hex: Vector2i) -> Vector2:
	return Vector2(
		HEX_SIZE * sqrt(3.0) * (hex.x + hex.y / 2.0),
		HEX_SIZE * 1.5 * hex.y
	)


func pixel_to_hex(pixel: Vector2) -> Vector2i:
	var local: Vector2 = pixel / HEX_SIZE
	var q: float = sqrt(3.0) / 3.0 * local.x - local.y / 3.0
	var r: float = 2.0 / 3.0 * local.y
	var s: float = -q - r
	var rounded_q: int = roundi(q)
	var rounded_r: int = roundi(r)
	var rounded_s: int = roundi(s)
	if absf(rounded_q - q) > absf(rounded_r - r) and absf(rounded_q - q) > absf(rounded_s - s):
		rounded_q = -rounded_r - rounded_s
	elif absf(rounded_r - r) > absf(rounded_s - s):
		rounded_r = -rounded_q - rounded_s
	return Vector2i(rounded_q, rounded_r)


func _draw() -> void:
	for hex: Vector2i in cells:
		var corners := PackedVector2Array()
		for corner in range(6):
			var angle: float = deg_to_rad(60.0 * corner - 30.0)
			corners.append(hex_to_pixel(hex) + Vector2.from_angle(angle) * HEX_SIZE)
		var fill := Color("293b43")
		if enemy_attack_tiles.has(hex):
			fill = Color("926033")
		if enemy_movement_tiles.has(hex):
			fill = Color("87464a")
		if not moving and ally_attack_tiles.has(hex):
			fill = Color("926033")
		if selected_unit != null and not moving and not choosing_facing and reachable.has(hex):
			fill = Color("356b87")
		if preview_path.has(hex):
			fill = Color("6a8050")
		if not moving and attack_targets.has(hex):
			fill = Color("87464a")
		draw_colored_polygon(corners, fill)
		corners.append(corners[0])
		draw_polyline(corners, Color("66818a"), 1.5, true)
	if not preview_path.is_empty() and selected_unit != null:
		var points := PackedVector2Array([selected_unit.position])
		for step in preview_path:
			points.append(hex_to_pixel(step))
		draw_polyline(points, Color("ffe39a"), 4.0, true)
		draw_circle(points[-1], 7.0, Color("ffe39a"), true, -1.0, true)
	for unit in players + enemies:
		_draw_unit(unit)
	if preview_target != null:
		draw_arc(preview_target.position, UNIT_RADIUS + 9.0, 0.0, TAU, 48, Color("ffad79"), 4.0, true)
	if hit_unit != null:
		var result: String = "-%d" % hit_damage if attack_hit else "Miss"
		if attack_hit and hit_damage == 0:
			result = "Blocked"
		if critical_hit and hit_damage > 0:
			result = "Critical · " + result
		if counter_strike:
			result = "Counter · " + result
		var font: Font = ThemeDB.fallback_font
		var width: float = font.get_string_size(result, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		draw_string(font, hit_unit.position + Vector2(-width / 2.0, -UNIT_RADIUS - 20), result, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("ffcf9c"))


func _draw_unit(unit: Unit) -> void:
	var color := Color("ef6262") if unit.enemy else Color("65baff")
	if not unit.enemy and unit.movement == 0:
		color = Color("477fa8")
	if unit.actions_done:
		color = color.darkened(0.25)
	if unit == hit_unit and attack_hit:
		color = Color.WHITE
	if unit == selected_unit or unit == inspected_enemy:
		draw_arc(unit.position, UNIT_RADIUS + 5.0, 0.0, TAU, 48, Color("ffe39a"), 3.0, true)
	draw_circle(unit.position, UNIT_RADIUS, color, true, -1.0, true)
	draw_arc(unit.position, UNIT_RADIUS, 0.0, TAU, 32, Color.WHITE, 2.0, true)
	var number: String = str(unit.number)
	var text_size: Vector2 = ThemeDB.fallback_font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	draw_string(ThemeDB.fallback_font, unit.position + Vector2(-text_size.x / 2.0, 8.0), number, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	if choosing_facing and unit == selected_unit:
		for direction in range(6):
			var offset: Vector2 = Vector2.from_angle(-direction * PI / 3.0) * (UNIT_RADIUS + 15.0)
			draw_circle(unit.position + offset, 3.0, Color(1.0, 0.89, 0.60, 0.4), true, -1.0, true)
	var forward: Vector2 = Vector2.from_angle(-unit.facing * PI / 3.0)
	var side: Vector2 = forward.orthogonal() * 7.0
	var base: Vector2 = unit.position + forward * (UNIT_RADIUS - 3.0)
	draw_colored_polygon(PackedVector2Array([
		unit.position + forward * (UNIT_RADIUS + 13.0), base + side, base - side
	]), Color.WHITE if unit.enemy else Color("ffe39a"))


func _facing_toward(from: Vector2, toward: Vector2, fallback: int) -> int:
	var offset: Vector2 = toward - from
	if offset.length_squared() < 16.0:
		return fallback
	return posmod(roundi(-offset.angle() / (PI / 3.0)), 6)


func _aim_at(cursor: Vector2) -> void:
	if not choosing_facing or selected_unit == null or selected_unit.actions_done:
		return
	selected_unit.facing = _facing_toward(selected_unit.position, cursor, selected_unit.facing)
	queue_redraw()


func _confirm_facing() -> void:
	if not choosing_facing or moving or not player_turn:
		return
	_clear_selection()
	_update_status()


func _clear_selection() -> void:
	choosing_facing = false
	selected_unit = null
	inspected_enemy = null
	enemy_movement_tiles.clear()
	enemy_attack_tiles.clear()
	reachable.clear()
	ally_attack_tiles.clear()
	preview_path.clear()
	attack_targets.clear()
	preview_target = null
	_update_info_panel()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		end_turn()
		return
	# UI gets clicks first, allowing End Turn during an optional facing adjustment.
	if choosing_facing:
		if event is InputEventMouseMotion:
			_aim_at(to_local(event.position))
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var enemy: Unit = _unit_at(pixel_to_hex(to_local(event.position)))
			if enemy != null and enemy.enemy:
				if not _attack_route(selected_unit, enemy).is_empty():
					attack_unit(enemy)
				else:
					_inspect_enemy(enemy)
				return
			_aim_at(to_local(event.position))
			_confirm_facing()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_click(pixel_to_hex(to_local(event.position)))


func _handle_click(target: Vector2i) -> void:
	if moving or choosing_facing or not player_turn or battle_over:
		return
	for unit in players:
		if unit.hex == target:
			_clear_selection()
			selected_unit = unit
			choosing_facing = unit.movement == 0 and not unit.actions_done
			preview_path.clear()
			preview_target = null
			_update_movement_range()
			_update_status()
			_update_info_panel()
			return
	var target_unit: Unit = _unit_at(target)
	if target_unit != null and target_unit.enemy:
		if selected_unit != null and not _attack_route(selected_unit, target_unit).is_empty():
			attack_unit(target_unit)
		else:
			_inspect_enemy(target_unit)
		return
	if selected_unit != null and reachable.has(target):
		move_unit(target)
	else:
		_clear_selection()
		_update_status()


func find_path(target: Vector2i) -> Array[Vector2i]:
	if selected_unit == null:
		return []
	return _find_path(selected_unit.hex, target, selected_unit)


func _find_path(start: Vector2i, target: Vector2i, mover: Unit) -> Array[Vector2i]:
	var frontier: Array[Vector2i] = [start]
	var previous: Dictionary[Vector2i, Vector2i] = {start: start}
	var index: int = 0
	while index < frontier.size():
		var current: Vector2i = frontier[index]
		index += 1
		if current == target:
			break
		for direction in DIRECTIONS:
			var neighbor: Vector2i = current + direction
			if cells.has(neighbor) and not _is_occupied(neighbor, mover) and not previous.has(neighbor):
				previous[neighbor] = current
				frontier.append(neighbor)
	var path: Array[Vector2i] = []
	if not previous.has(target):
		return path
	var current: Vector2i = target
	while current != start:
		path.append(current)
		current = previous[current]
	path.reverse()
	return path


func _set_unit_position(value: Vector2, unit: Unit) -> void:
	unit.position = value
	queue_redraw()


func _animate_path(unit: Unit, path: Array[Vector2i], duration: float) -> void:
	for step in path:
		unit.facing = _facing_toward(unit.position, hex_to_pixel(step), unit.facing)
		var tween: Tween = create_tween()
		tween.tween_method(_set_unit_position.bind(unit), unit.position, hex_to_pixel(step), duration)
		await tween.finished
		unit.hex = step


func move_unit(target: Vector2i) -> void:
	if moving or choosing_facing or not player_turn or selected_unit == null or selected_unit.actions_done or battle_over:
		return
	var path: Array[Vector2i] = find_path(target)
	if path.is_empty() or path.size() > selected_unit.movement:
		return
	moving = true
	var unit: Unit = selected_unit
	unit.movement = 0
	reachable.clear()
	preview_path.clear()
	attack_targets.clear()
	preview_target = null
	_update_status()
	queue_redraw()
	await _animate_path(unit, path, 0.12)
	moving = false
	_clear_selection()
	_update_status()


func _attack_route(attacker: Unit, target: Unit) -> Array[Vector2i]:
	# Include the starting cell so an adjacent attack has a valid zero-move route.
	if attacker == null or target == null or attacker.actions_done or attacker.enemy == target.enemy or target.hp <= 0:
		return []
	if _hex_distance(attacker.hex, target.hex) <= attacker.attack_range:
		return [attacker.hex]
	var costs: Dictionary[Vector2i, int] = _movement_costs(attacker)
	var best_cost: int = attacker.movement + 1
	var best_cell: Vector2i = attacker.hex
	for destination: Vector2i in costs:
		var distance: int = _hex_distance(destination, target.hex)
		if distance > 0 and distance <= attacker.attack_range and costs[destination] < best_cost:
			best_cell = destination
			best_cost = costs[destination]
	if best_cost > attacker.movement:
		return []
	var route: Array[Vector2i] = [attacker.hex]
	route.append_array(_find_path(attacker.hex, best_cell, attacker))
	return route


func attack_unit(target: Unit) -> void:
	if moving or not player_turn or battle_over or selected_unit == null or not enemies.has(target):
		return
	var attacker: Unit = selected_unit
	var route: Array[Vector2i] = _attack_route(attacker, target)
	if route.is_empty():
		return
	choosing_facing = false
	moving = true
	attacker.movement = 0
	reachable.clear()
	attack_targets.clear()
	preview_path.clear()
	preview_target = null
	_update_status()
	queue_redraw()
	await _animate_path(attacker, route.slice(1), 0.12)
	await _resolve_attack(attacker, target)
	moving = false
	_clear_selection()
	_update_status()


func _plan_exchange(attacker: Unit, defender: Unit, attack_hex: Vector2i) -> Exchange:
	var exchange := Exchange.new()
	var defender_direction: int = _facing_toward(hex_to_pixel(defender.hex), hex_to_pixel(attack_hex), defender.facing)
	var rear: bool = defender_direction == (defender.facing + 3) % 6
	exchange.opening = Strike.new(attacker, defender, rear, false)
	# The initiator faces the defender during the exchange, exposing no rear to the counter.
	exchange.counter = Strike.new(defender, attacker, false, true)
	var counter_score: int = defender.vaillance + defender.character.elan - attacker.character.temperance
	exchange.counter_eligible = counter_score > 0 and _hex_distance(defender.hex, attack_hex) <= defender.attack_range
	exchange.follow_up = attacker.furie - attacker.effective_weight() - defender.character.temperance > 0
	var defender_first: bool = exchange.counter_eligible and defender.priority() > attacker.priority()
	if defender_first:
		exchange.strikes.append(exchange.counter)
	exchange.strikes.append(exchange.opening)
	if exchange.counter_eligible and not defender_first:
		exchange.strikes.append(exchange.counter)
	if exchange.follow_up:
		exchange.strikes.append(exchange.opening)
	return exchange


func _resolve_attack(attacker: Unit, target: Unit) -> void:
	var exchange: Exchange = _plan_exchange(attacker, target, attacker.hex)
	attacker.facing = _facing_toward(attacker.position, target.position, attacker.facing)
	attacker.actions_done = true
	attacker.movement = 0
	for index in range(exchange.strikes.size()):
		if index > 0:
			await get_tree().create_timer(0.12).timeout
		await _resolve_strike(exchange.strikes[index])
		if attacker.hp == 0 or target.hp == 0:
			break


func _resolve_strike(strike: Strike) -> void:
	var target: Unit = strike.target
	attack_hit = randi_range(1, 100) <= strike.hit_chance
	critical_hit = attack_hit and randi_range(1, 100) <= strike.crit_chance
	var damage: int = strike.damage * (2 if critical_hit else 1)
	hit_damage = mini(target.hp, damage) if attack_hit else 0
	target.hp -= hit_damage
	hit_unit = target
	counter_strike = strike.is_counter
	_update_info_panel()
	queue_redraw()
	await get_tree().create_timer(0.28).timeout
	hit_unit = null
	counter_strike = false
	if target.hp == 0:
		players.erase(target)
		enemies.erase(target)
		if hovered_unit == target:
			hovered_unit = null
		if selected_unit == target:
			_clear_selection()
		battle_over = players.is_empty() or enemies.is_empty()
	_update_info_panel()
	queue_redraw()


func _enemy_path(enemy: Unit) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	var found: bool = false
	# Approach a free hex within this character's attack range.
	for player in players:
		if _hex_distance(enemy.hex, player.hex) <= enemy.attack_range:
			return []
		for target: Vector2i in cells:
			var distance: int = _hex_distance(target, player.hex)
			if distance == 0 or distance > enemy.attack_range or _is_occupied(target, enemy):
				continue
			var path: Array[Vector2i] = _find_path(enemy.hex, target, enemy)
			if not path.is_empty() and (not found or path.size() < best.size()):
				best = path
				found = true
	return best


func end_turn() -> void:
	if moving or not player_turn or battle_over:
		return
	_clear_selection()
	player_turn = false
	moving = true
	_update_status()
	await get_tree().create_timer(0.25).timeout
	# A counter can remove the acting enemy from the live roster.
	for enemy in enemies.duplicate():
		if players.is_empty():
			break
		var path: Array[Vector2i] = _enemy_path(enemy)
		await _animate_path(enemy, path.slice(0, enemy.max_movement), 0.18)
		enemy.movement = 0
		var closest: Unit = players[0]
		for player in players:
			if _hex_distance(enemy.hex, player.hex) < _hex_distance(enemy.hex, closest.hex):
				closest = player
		enemy.facing = _facing_toward(enemy.position, closest.position, enemy.facing)
		if _hex_distance(enemy.hex, closest.hex) <= enemy.attack_range:
			await _resolve_attack(enemy, closest)
		else:
			enemy.actions_done = true
		queue_redraw()
		if battle_over:
			break
	if battle_over:
		moving = false
		_update_status()
		return
	turn_number += 1
	for unit in players + enemies:
		unit.movement = unit.max_movement
		unit.actions_done = false
	moving = false
	player_turn = true
	_update_status()
	queue_redraw()


func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var difference: Vector2i = a - b
	return maxi(maxi(absi(difference.x), absi(difference.y)), absi(difference.x + difference.y))
