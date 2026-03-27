extends Node2D

# ============================================================
# ROAD DASH — Motorcycle Combat Racing (Road Rash-inspired)
# All rendering is procedural via _draw(). No image assets needed.
# Controls: Arrow/WASD = steer/gas/brake, Z/X = punch left/right
# Touch controls available for mobile browsers.
# ============================================================

# ---- SCREEN ----
var SW: float = 1280.0
var SH: float = 720.0

# ---- ROAD GEOMETRY ----
const SEGMENT_LENGTH := 200.0
const RUMBLE_LENGTH := 3
const ROAD_WIDTH := 2000.0
const LANES := 3
const DRAW_DISTANCE := 300
const FIELD_OF_VIEW := 100.0
const CAMERA_HEIGHT := 1000.0
var camera_depth: float = 0.84

# ---- PHYSICS ----
const MAX_SPEED := 15000.0
const ACCEL := 12000.0
const BRAKE_DECEL := 24000.0
const NATURAL_DECEL := 5000.0
const OFF_ROAD_DECEL := 18000.0
const OFF_ROAD_MAX := 5000.0
const CENTRIFUGAL := 0.3
const STEER_SPEED := 3.0

# ---- COLORS ----
var COL_SKY_TOP := Color(0.10, 0.45, 0.90)
var COL_SKY_BOT := Color(0.55, 0.78, 1.00)
var COL_FOG := Color(0.68, 0.80, 0.92)
var COL_GRASS_L := Color(0.16, 0.64, 0.16)
var COL_GRASS_D := Color(0.11, 0.54, 0.11)
var COL_ROAD_L := Color(0.42, 0.42, 0.42)
var COL_ROAD_D := Color(0.38, 0.38, 0.38)
var COL_RUMBLE_L := Color(0.90, 0.10, 0.10)
var COL_RUMBLE_D := Color(0.95, 0.95, 0.95)
var COL_LANE := Color(0.92, 0.92, 0.92)
var COL_FINISH := Color(0.1, 0.1, 0.1)
var PLAYER_COLOR := Color(0.20, 0.35, 0.90)
var OPP_COLORS: Array[Color] = [
	Color(0.90, 0.20, 0.20), Color(0.15, 0.80, 0.15),
	Color(0.90, 0.85, 0.15), Color(0.85, 0.20, 0.85),
	Color(0.15, 0.85, 0.85),
]
var OPP_NAMES: Array[String] = ["Viper", "Slash", "Hawk", "Blaze", "Storm"]

# ---- ENUMS ----
enum St { MENU, COUNTDOWN, RACING, CRASHED, RESULTS, SHOP }

# ---- ROAD DATA ----
var segments: Array = []
var track_length: float = 0.0

# ---- GAME STATE ----
var state: int = St.MENU
var current_level: int = 1
var money: int = 0
var bike_speed_lvl: int = 0
var bike_accel_lvl: int = 0
var bike_armor_lvl: int = 0

# ---- PLAYER ----
var player_z: float = 0.0
var player_x: float = 0.0
var player_speed: float = 0.0
var player_health: float = 100.0
var player_max_health: float = 100.0
var punch_timer: float = 0.0
var punch_side: int = 0
var crash_timer: float = 0.0
var race_time: float = 0.0
var finish_position: int = 0
var race_finished: bool = false

# ---- OPPONENTS ----
var opponents: Array = []

# ---- CAMERA ----
var camera_y: float = 0.0

# ---- COUNTDOWN ----
var countdown_timer: float = 0.0

# ---- MENU ANIMATION ----
var menu_scroll: float = 0.0
var menu_selected: int = 0

# ---- SHOP ----
var shop_selected: int = 0

# ---- TOUCH ----
var touch_map: Dictionary = {}
var touch_left: bool = false
var touch_right: bool = false
var touch_gas: bool = false
var touch_brake: bool = false
var touch_punch_l: bool = false
var touch_punch_r: bool = false

# ---- PROJECTION CACHE (reused each frame) ----
var proj_x: PackedFloat64Array = []
var proj_y: PackedFloat64Array = []
var proj_w: PackedFloat64Array = []
var proj_scale: PackedFloat64Array = []
var proj_idx: PackedInt32Array = []
var proj_curve: PackedFloat64Array = []
var proj_valid: Array = []  # bool flags

# ============================================================
# LIFECYCLE
# ============================================================

func _ready():
	camera_depth = 1.0 / tan(deg_to_rad(FIELD_OF_VIEW / 2.0))
	_resize_proj_cache()
	generate_road(1)

func _resize_proj_cache():
	proj_x.resize(DRAW_DISTANCE)
	proj_y.resize(DRAW_DISTANCE)
	proj_w.resize(DRAW_DISTANCE)
	proj_scale.resize(DRAW_DISTANCE)
	proj_idx.resize(DRAW_DISTANCE)
	proj_curve.resize(DRAW_DISTANCE)
	proj_valid.resize(DRAW_DISTANCE)

func _process(delta: float):
	var vp := get_viewport_rect().size
	SW = vp.x; SH = vp.y
	match state:
		St.MENU:      _process_menu(delta)
		St.COUNTDOWN: _process_countdown(delta)
		St.RACING:    _process_racing(delta)
		St.CRASHED:   _process_crashed(delta)
		St.RESULTS:   _process_results(delta)
		St.SHOP:      _process_shop(delta)
	queue_redraw()

func _draw():
	match state:
		St.MENU:
			_draw_menu()
		St.COUNTDOWN:
			_draw_game()
			_draw_countdown()
		St.RACING:
			_draw_game()
		St.CRASHED:
			_draw_game()
			_draw_crash_overlay()
		St.RESULTS:
			_draw_results()
		St.SHOP:
			_draw_shop()

func _input(event: InputEvent):
	if state == St.MENU:
		_input_menu(event)
	elif state == St.RACING or state == St.COUNTDOWN:
		_input_game(event)
	elif state == St.RESULTS:
		_input_results(event)
	elif state == St.SHOP:
		_input_shop(event)
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)

# ============================================================
# ROAD GENERATION
# ============================================================

func _add_seg(curve_val: float, y_val: float):
	segments.append({
		"z": segments.size() * SEGMENT_LENGTH,
		"y": y_val,
		"curve": curve_val,
		"sprite": 0,
		"sprite_x": 0.0,
	})

func _add_straight(count: int):
	var ly: float = 0.0 if segments.is_empty() else segments.back().y
	for i in range(count):
		_add_seg(0.0, ly)

func _add_curve(count: int, curve: float):
	var ly: float = 0.0 if segments.is_empty() else segments.back().y
	for i in range(count):
		var t := float(i) / float(count)
		_add_seg(curve * sin(t * PI), ly)

func _add_hill(count: int, height: float):
	var sy: float = 0.0 if segments.is_empty() else segments.back().y
	for i in range(count):
		var t := float(i) / float(count)
		_add_seg(0.0, sy + height * ((-cos(t * PI) + 1.0) / 2.0))

func _add_hill_curve(count: int, curve: float, height: float):
	var sy: float = 0.0 if segments.is_empty() else segments.back().y
	for i in range(count):
		var t := float(i) / float(count)
		_add_seg(curve * sin(t * PI), sy + height * ((-cos(t * PI) + 1.0) / 2.0))

func generate_road(level: int):
	segments.clear()
	var ci := 1.0 + level * 0.25
	var hi := 15.0 + level * 5.0

	_add_straight(25)
	_add_curve(35, 2.0 * ci)
	_add_hill(25, hi)
	_add_straight(15)
	_add_curve(35, -2.5 * ci)
	_add_hill(20, -hi)
	_add_straight(20)
	_add_hill_curve(30, 3.0 * ci, hi * 1.2)
	_add_hill_curve(30, -4.0 * ci, -hi)
	_add_straight(25)
	# S-curves
	_add_curve(25, 3.5 * ci)
	_add_curve(25, -4.0 * ci)
	_add_curve(25, 3.0 * ci)
	_add_straight(20)
	# Mountain pass
	_add_hill(30, hi * 1.5)
	_add_curve(20, -3.0 * ci)
	_add_hill(30, -hi * 1.5)
	_add_straight(15)
	# Twisty
	for k in range(5):
		var d := 1.0 if k % 2 == 0 else -1.0
		_add_curve(18, d * (2.5 + k * 0.4) * ci)
	_add_hill(15, -hi * 0.5)
	_add_straight(30)
	# Pad to at least 1200 segments
	while segments.size() < 1200:
		_add_straight(20)
		_add_curve(20, ci * 2.0)
		_add_hill(20, hi * 0.8)

	# Add scenery sprites
	for i in range(segments.size()):
		if i % 4 == 0:
			segments[i].sprite = (i / 4) % 3 + 1
			segments[i].sprite_x = (1.3 + fmod(float(i) * 0.37, 0.8)) * (1.0 if i % 8 < 4 else -1.0)

	track_length = float(segments.size()) * SEGMENT_LENGTH

# ============================================================
# RACE SETUP
# ============================================================

func _start_race():
	player_z = 0.0
	player_x = 0.0
	player_speed = 0.0
	player_health = 100.0 + bike_armor_lvl * 20.0
	player_max_health = player_health
	punch_timer = 0.0
	punch_side = 0
	crash_timer = 0.0
	race_time = 0.0
	race_finished = false
	finish_position = 0

	opponents.clear()
	for i in range(5):
		opponents.append({
			"z": 800.0 + i * 600.0,
			"x": randf_range(-0.7, 0.7),
			"speed": 0.0,
			"max_speed": MAX_SPEED * randf_range(0.65, 0.92) * (1.0 + current_level * 0.03),
			"health": 80.0 + current_level * 5.0,
			"max_health": 80.0 + current_level * 5.0,
			"color": OPP_COLORS[i],
			"name": OPP_NAMES[i],
			"target_x": randf_range(-0.6, 0.6),
			"crashed": false,
			"crash_timer": 0.0,
			"punch_timer": 0.0,
			"punch_side": 0,
			"finished": false,
		})

	countdown_timer = 3.5
	state = St.COUNTDOWN

# ============================================================
# PROCESS: MENU
# ============================================================

func _process_menu(delta: float):
	menu_scroll += 3000.0 * delta
	if menu_scroll > track_length:
		menu_scroll -= track_length

func _input_menu(event: InputEvent):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			generate_road(current_level)
			_start_race()
	if event is InputEventScreenTouch and event.pressed:
		generate_road(current_level)
		_start_race()

# ============================================================
# PROCESS: COUNTDOWN
# ============================================================

func _process_countdown(delta: float):
	countdown_timer -= delta
	if countdown_timer <= 0.0:
		state = St.RACING

# ============================================================
# PROCESS: RACING
# ============================================================

func _process_racing(delta: float):
	race_time += delta
	_update_player(delta)
	_update_opponents(delta)
	_handle_combat(delta)
	_check_finish()

func _update_player(delta: float):
	# Input
	var steer := 0.0
	if Input.is_action_pressed("steer_left") or touch_left:
		steer -= 1.0
	if Input.is_action_pressed("steer_right") or touch_right:
		steer += 1.0
	var gas := 0.0
	if Input.is_action_pressed("accelerate") or touch_gas:
		gas = 1.0
	if Input.is_action_pressed("brake") or touch_brake:
		gas = -1.0

	# Speed
	var eff_max := MAX_SPEED * (1.0 + bike_speed_lvl * 0.06)
	var eff_acc := ACCEL * (1.0 + bike_accel_lvl * 0.10)
	if gas > 0:
		player_speed += eff_acc * delta
	elif gas < 0:
		player_speed -= BRAKE_DECEL * delta
	else:
		player_speed -= NATURAL_DECEL * delta
	# Off-road
	if absf(player_x) > 1.0:
		player_speed -= OFF_ROAD_DECEL * delta
		eff_max = minf(eff_max, OFF_ROAD_MAX)
	player_speed = clampf(player_speed, 0.0, eff_max)

	# Steering
	var steer_str := STEER_SPEED * (player_speed / maxf(eff_max, 1.0))
	player_x += steer * steer_str * delta

	# Centrifugal force from road curve
	var seg_i := _seg_index(player_z)
	var seg_curve: float = segments[seg_i].curve
	player_x -= seg_curve * CENTRIFUGAL * (player_speed / maxf(eff_max, 1.0)) * delta

	player_x = clampf(player_x, -2.5, 2.5)

	# Move
	player_z += player_speed * delta

	# Camera
	camera_y = _find_y(player_z) + CAMERA_HEIGHT

	# Punch timer
	if punch_timer > 0.0:
		punch_timer -= delta
		if punch_timer <= 0.0:
			punch_side = 0

func _update_opponents(delta: float):
	for opp in opponents:
		if opp.crashed:
			opp.crash_timer -= delta
			if opp.crash_timer <= 0.0:
				opp.crashed = false
				opp.health = opp.max_health * 0.4
				opp.speed = opp.max_speed * 0.4
			continue
		if opp.finished:
			opp.speed = maxf(opp.speed - NATURAL_DECEL * delta, 0.0)
			opp.z += opp.speed * delta
			continue

		var target_spd: float = opp.max_speed
		var si := _seg_index(opp.z)
		var sc: float = absf(segments[si].curve)
		if sc > 1.0:
			target_spd *= maxf(0.5, 1.0 - sc * 0.06)
		if opp.speed < target_spd:
			opp.speed += ACCEL * 0.5 * delta
		else:
			opp.speed -= NATURAL_DECEL * 0.5 * delta
		opp.speed = clampf(opp.speed, 0.0, opp.max_speed)
		opp.z += opp.speed * delta

		# Finish check for opponent
		if opp.z >= track_length and not opp.finished:
			opp.finished = true

		# Lateral drift
		opp.x = move_toward(opp.x, opp.target_x, 0.6 * delta)
		if randi() % 180 == 0:
			opp.target_x = randf_range(-0.7, 0.7)

		# AI punch
		if opp.punch_timer > 0.0:
			opp.punch_timer -= delta
			if opp.punch_timer <= 0.0:
				opp.punch_side = 0
		var dz := absf(opp.z - player_z)
		if dz < SEGMENT_LENGTH * 3.0:
			var dx := opp.x - player_x
			if absf(dx) < 0.5 and randi() % 120 == 0:
				opp.punch_side = -1 if dx > 0 else 1
				opp.punch_timer = 0.3
				if absf(dx) < 0.35:
					player_health -= 4.0
					if player_health <= 0.0:
						_crash_player()

func _handle_combat(delta: float):
	if punch_timer > 0.0:
		return
	var did_punch := false
	if Input.is_action_just_pressed("punch_left") or touch_punch_l:
		punch_side = -1; punch_timer = 0.35; did_punch = true
		touch_punch_l = false
	elif Input.is_action_just_pressed("punch_right") or touch_punch_r:
		punch_side = 1; punch_timer = 0.35; did_punch = true
		touch_punch_r = false
	if not did_punch:
		return
	for opp in opponents:
		if opp.crashed:
			continue
		var dz := absf(opp.z - player_z)
		if dz > SEGMENT_LENGTH * 3.5:
			continue
		var dx := opp.x - player_x
		if punch_side == -1 and dx > -0.55 and dx < -0.05:
			_hit_opponent(opp)
		elif punch_side == 1 and dx > 0.05 and dx < 0.55:
			_hit_opponent(opp)

	# Player-opponent body collision
	for opp in opponents:
		if opp.crashed:
			continue
		var dz := absf(opp.z - player_z)
		if dz < SEGMENT_LENGTH * 1.5:
			var dx := absf(opp.x - player_x)
			if dx < 0.25:
				if opp.x < player_x:
					player_x += 0.05; opp.x -= 0.05
				else:
					player_x -= 0.05; opp.x += 0.05
				player_speed *= 0.97
				opp.speed *= 0.97

func _hit_opponent(opp: Dictionary):
	opp.health -= 25.0
	opp.x += punch_side * 0.35
	if opp.health <= 0.0:
		opp.crashed = true
		opp.crash_timer = 3.0
		opp.speed = 0.0

func _crash_player():
	state = St.CRASHED
	crash_timer = 2.5
	player_speed = 0.0

func _check_finish():
	if player_z >= track_length and not race_finished:
		race_finished = true
		finish_position = _get_position()
		state = St.RESULTS
		# Earnings
		var earnings := [0, 600, 400, 250, 150, 80, 50]
		money += earnings[clampi(finish_position, 1, 6)]

# ============================================================
# PROCESS: CRASHED
# ============================================================

func _process_crashed(delta: float):
	crash_timer -= delta
	_update_opponents(delta)
	if crash_timer <= 0.0:
		player_health = player_max_health * 0.4
		player_speed = 0.0
		state = St.RACING

# ============================================================
# PROCESS: RESULTS / SHOP
# ============================================================

func _process_results(_d: float):
	pass

func _input_results(event: InputEvent):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			state = St.SHOP
			shop_selected = 0
	if event is InputEventScreenTouch and event.pressed:
		state = St.SHOP
		shop_selected = 0

func _process_shop(_d: float):
	pass

func _input_shop(event: InputEvent):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP, KEY_W:
				shop_selected = (shop_selected - 1) % 4
				if shop_selected < 0: shop_selected = 3
			KEY_DOWN, KEY_S:
				shop_selected = (shop_selected + 1) % 4
			KEY_SPACE, KEY_ENTER:
				_shop_buy()
	if event is InputEventScreenTouch and event.pressed:
		var y_ratio: float = event.position.y / SH
		if y_ratio > 0.3 and y_ratio < 0.85:
			shop_selected = clampi(int((y_ratio - 0.3) / 0.14), 0, 3)
			_shop_buy()

func _shop_buy():
	if shop_selected == 3:
		# Next Race
		current_level += 1
		generate_road(current_level)
		_start_race()
		return
	var costs := [150 * (bike_speed_lvl + 1), 120 * (bike_accel_lvl + 1), 100 * (bike_armor_lvl + 1)]
	var cost: int = costs[shop_selected]
	if money >= cost:
		money -= cost
		match shop_selected:
			0: bike_speed_lvl += 1
			1: bike_accel_lvl += 1
			2: bike_armor_lvl += 1

func _input_game(event: InputEvent):
	pass  # Handled via Input.is_action_pressed in _update_player

# ============================================================
# RENDERING — GAME
# ============================================================

func _draw_game():
	_draw_sky()
	_compute_projections()
	_draw_road_pass()
	_draw_sprite_pass()
	_draw_player_sprite()
	_draw_hud()
	_draw_touch_controls()

func _draw_sky():
	var band := maxf(SH * 0.55, 1.0)
	for i in range(int(band)):
		var t := float(i) / band
		draw_line(Vector2(0, i), Vector2(SW, i), COL_SKY_TOP.lerp(COL_SKY_BOT, t))
	# Ground fill below horizon
	draw_rect(Rect2(0, band, SW, SH - band), COL_GRASS_D)

func _compute_projections():
	var num_seg := segments.size()
	var base_idx := _seg_index(player_z)
	var base_offset := fmod(player_z, SEGMENT_LENGTH)
	var cam_x := player_x * ROAD_WIDTH
	var x_acc := 0.0
	var dx_acc := 0.0

	for n in range(DRAW_DISTANCE):
		var rel_z := float(n) * SEGMENT_LENGTH - base_offset + SEGMENT_LENGTH
		var idx := (base_idx + n) % num_seg
		var seg: Dictionary = segments[idx]

		if rel_z < 1.0:
			proj_valid[n] = false
			x_acc += dx_acc
			dx_acc += seg.curve
			continue

		var sc := camera_depth / rel_z
		proj_x[n] = SW / 2.0 + sc * (x_acc - cam_x) * SW / 2.0
		proj_y[n] = SH / 2.0 - sc * (seg.y - camera_y) * SH / 2.0
		proj_w[n] = sc * ROAD_WIDTH * SW / 2.0
		proj_scale[n] = sc
		proj_idx[n] = idx
		proj_curve[n] = x_acc
		proj_valid[n] = true

		x_acc += dx_acc
		dx_acc += seg.curve

func _draw_road_pass():
	var max_y := SH
	for n in range(1, DRAW_DISTANCE):
		if not proj_valid[n] or not proj_valid[n - 1]:
			continue
		var py_far: float = proj_y[n]
		var py_near: float = proj_y[n - 1]
		if py_far >= max_y:
			continue
		# Clamp near to screen bottom
		py_near = minf(py_near, SH)

		var px_far: float = proj_x[n]
		var pw_far: float = proj_w[n]
		var px_near: float = proj_x[n - 1]
		var pw_near: float = proj_w[n - 1]
		var idx: int = proj_idx[n]
		var is_dark := ((idx / RUMBLE_LENGTH) % 2) == 0
		var fog := clampf(float(n) / float(DRAW_DISTANCE) * 1.2, 0.0, 1.0)

		# Grass
		var gc: Color = (COL_GRASS_D if is_dark else COL_GRASS_L).lerp(COL_FOG, fog)
		draw_polygon(
			PackedVector2Array([Vector2(0, py_far), Vector2(SW, py_far),
				Vector2(SW, py_near), Vector2(0, py_near)]),
			PackedColorArray([gc]))

		# Rumble strips
		var rw_far := pw_far * 1.12
		var rw_near := pw_near * 1.12
		var rc: Color = (COL_RUMBLE_L if is_dark else COL_RUMBLE_D).lerp(COL_FOG, fog)
		# Left rumble
		draw_polygon(
			PackedVector2Array([
				Vector2(px_far - rw_far, py_far), Vector2(px_far - pw_far, py_far),
				Vector2(px_near - pw_near, py_near), Vector2(px_near - rw_near, py_near)]),
			PackedColorArray([rc]))
		# Right rumble
		draw_polygon(
			PackedVector2Array([
				Vector2(px_far + pw_far, py_far), Vector2(px_far + rw_far, py_far),
				Vector2(px_near + rw_near, py_near), Vector2(px_near + pw_near, py_near)]),
			PackedColorArray([rc]))

		# Road surface
		var road_c: Color = (COL_ROAD_D if is_dark else COL_ROAD_L).lerp(COL_FOG, fog)
		# Finish line marker
		if idx >= segments.size() - 5:
			road_c = COL_FINISH if is_dark else Color.WHITE
		draw_polygon(
			PackedVector2Array([
				Vector2(px_far - pw_far, py_far), Vector2(px_far + pw_far, py_far),
				Vector2(px_near + pw_near, py_near), Vector2(px_near - pw_near, py_near)]),
			PackedColorArray([road_c]))

		# Lane markings (only on light segments)
		if not is_dark and fog < 0.8:
			var lw_far := maxf(pw_far * 0.015, 0.5)
			var lw_near := maxf(pw_near * 0.015, 0.5)
			for lane_i in range(1, LANES):
				var lf := float(lane_i) / float(LANES)
				var lx_far := px_far - pw_far + 2.0 * pw_far * lf
				var lx_near := px_near - pw_near + 2.0 * pw_near * lf
				draw_polygon(
					PackedVector2Array([
						Vector2(lx_far - lw_far, py_far), Vector2(lx_far + lw_far, py_far),
						Vector2(lx_near + lw_near, py_near), Vector2(lx_near - lw_near, py_near)]),
					PackedColorArray([COL_LANE.lerp(COL_FOG, fog)]))

		max_y = minf(max_y, py_far)

func _draw_sprite_pass():
	# Draw roadside scenery and vehicles far-to-near
	for n in range(DRAW_DISTANCE - 1, 0, -1):
		if not proj_valid[n]:
			continue
		var sc: float = proj_scale[n]
		var px: float = proj_x[n]
		var py: float = proj_y[n]
		var pw: float = proj_w[n]
		var idx: int = proj_idx[n]
		var seg: Dictionary = segments[idx]
		var fog := clampf(float(n) / float(DRAW_DISTANCE) * 1.3, 0.0, 1.0)
		if fog > 0.95:
			continue

		# Roadside scenery
		if seg.sprite > 0:
			var sx: float = px + seg.sprite_x * pw * 1.5
			_draw_scenery_sprite(sx, py, sc, seg.sprite, fog)

		# Vehicles (opponents)
		for opp in opponents:
			var opp_seg := _seg_index(opp.z)
			if opp_seg == idx:
				var opp_sx := px + opp.x * pw
				var opp_sc := sc
				var ps := opp.punch_side if opp.punch_timer > 0.0 else 0
				if not opp.crashed:
					_draw_vehicle(opp_sx, py, opp_sc, opp.color, fog, ps)
				else:
					_draw_crashed_vehicle(opp_sx, py, opp_sc, opp.color, fog)

func _draw_scenery_sprite(sx: float, sy: float, sc: float, kind: int, fog: float):
	var s := sc * 6000.0
	if s < 1.5:
		return
	match kind:
		1: # Tree
			var trunk_c := Color(0.45, 0.28, 0.12).lerp(COL_FOG, fog)
			var leaf_c := Color(0.12, 0.50, 0.12).lerp(COL_FOG, fog)
			draw_rect(Rect2(sx - s * 1.5, sy - s * 18, s * 3, s * 18), trunk_c)
			draw_polygon(
				PackedVector2Array([
					Vector2(sx - s * 10, sy - s * 18),
					Vector2(sx + s * 10, sy - s * 18),
					Vector2(sx, sy - s * 42)]),
				PackedColorArray([leaf_c]))
		2: # Post
			var pc := Color(0.85, 0.85, 0.85).lerp(COL_FOG, fog)
			draw_rect(Rect2(sx - s * 0.8, sy - s * 22, s * 1.6, s * 22), pc)
			draw_rect(Rect2(sx - s * 4, sy - s * 22, s * 8, s * 3), Color(0.9, 0.1, 0.1).lerp(COL_FOG, fog))
		3: # Bush
			var bc := Color(0.18, 0.48, 0.18).lerp(COL_FOG, fog)
			draw_circle(Vector2(sx, sy - s * 5), s * 7, bc)

func _draw_vehicle(sx: float, sy: float, sc: float, col: Color, fog: float, ps: int):
	var s := sc * 5000.0
	if s < 1.0:
		return
	var c := col.lerp(COL_FOG, fog)
	var dark := c.darkened(0.3)
	# Bike body
	draw_rect(Rect2(sx - s * 5, sy - s * 8, s * 10, s * 8), dark)
	# Wheels
	draw_circle(Vector2(sx - s * 4, sy), maxf(s * 3, 1), Color(0.15, 0.15, 0.15).lerp(COL_FOG, fog))
	draw_circle(Vector2(sx + s * 4, sy), maxf(s * 3, 1), Color(0.15, 0.15, 0.15).lerp(COL_FOG, fog))
	# Rider
	draw_rect(Rect2(sx - s * 3.5, sy - s * 18, s * 7, s * 10), c)
	draw_circle(Vector2(sx, sy - s * 22), maxf(s * 4, 1), c.lightened(0.15))
	# Punch arm
	if ps != 0:
		var arm_end := sx + ps * s * 14
		draw_line(Vector2(sx, sy - s * 14), Vector2(arm_end, sy - s * 14),
			Color.WHITE.lerp(COL_FOG, fog), maxf(s * 1.5, 1))

func _draw_crashed_vehicle(sx: float, sy: float, sc: float, col: Color, fog: float):
	var s := sc * 5000.0
	if s < 1.0:
		return
	var c := col.darkened(0.4).lerp(COL_FOG, fog)
	# Tilted bike on the ground
	draw_polygon(
		PackedVector2Array([
			Vector2(sx - s * 8, sy), Vector2(sx + s * 8, sy),
			Vector2(sx + s * 5, sy - s * 4), Vector2(sx - s * 5, sy - s * 4)]),
		PackedColorArray([c]))

func _draw_player_sprite():
	var px := SW / 2.0
	var py := SH * 0.82
	var lean: float = player_x * 0.15

	# Shadow
	draw_ellipse_approx(Vector2(px, py + 15), 35, 8, Color(0, 0, 0, 0.25))

	# Bike body
	draw_rect(Rect2(px - 28, py - 8, 56, 22), PLAYER_COLOR.darkened(0.35))
	# Wheels
	draw_circle(Vector2(px - 22, py + 14), 14, Color(0.12, 0.12, 0.12))
	draw_circle(Vector2(px + 22, py + 14), 14, Color(0.12, 0.12, 0.12))
	draw_circle(Vector2(px - 22, py + 14), 10, Color(0.3, 0.3, 0.3))
	draw_circle(Vector2(px + 22, py + 14), 10, Color(0.3, 0.3, 0.3))
	# Rider body (leans with steering)
	var bx := px + lean * 25
	draw_rect(Rect2(bx - 16, py - 48, 32, 40), PLAYER_COLOR)
	# Helmet
	draw_circle(Vector2(bx, py - 58), 14, Color(0.85, 0.18, 0.18))
	# Visor
	draw_rect(Rect2(bx - 10, py - 62, 20, 6), Color(0.15, 0.15, 0.15))

	# Punch animation
	if punch_timer > 0.0:
		var arm_end := bx + punch_side * 55
		var arm_y := py - 35
		draw_line(Vector2(bx, arm_y), Vector2(arm_end, arm_y), PLAYER_COLOR.darkened(0.1), 5)
		draw_circle(Vector2(arm_end, arm_y), 7, Color(0.92, 0.78, 0.62))

	# Speed lines at high speed
	var speed_ratio := player_speed / MAX_SPEED
	if speed_ratio > 0.6:
		var alpha := (speed_ratio - 0.6) * 2.5
		for i in range(6):
			var lx := randf_range(0, SW)
			var ly := randf_range(SH * 0.5, SH * 0.9)
			var length := randf_range(30, 80) * speed_ratio
			draw_line(Vector2(lx, ly), Vector2(lx - length, ly),
				Color(1, 1, 1, alpha * 0.3), 1.5)

func draw_ellipse_approx(center: Vector2, rx: float, ry: float, col: Color):
	var pts := PackedVector2Array()
	for i in range(12):
		var a := float(i) / 12.0 * TAU
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polygon(pts, PackedColorArray([col]))

# ============================================================
# HUD
# ============================================================

func _draw_hud():
	var font := ThemeDB.fallback_font
	var speed_kmh := int(player_speed / MAX_SPEED * 280)
	var pos := _get_position()

	# Semi-transparent HUD background
	draw_rect(Rect2(10, 8, 220, 100), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(SW - 230, 8, 220, 100), Color(0, 0, 0, 0.45))

	# Speed
	draw_string(font, Vector2(20, 38), str(speed_kmh) + " km/h", HORIZONTAL_ALIGNMENT_LEFT, 200, 24, Color.WHITE)
	# Position
	var pos_str := str(pos) + _ordinal(pos) + " / " + str(opponents.size() + 1)
	draw_string(font, Vector2(20, 68), pos_str, HORIZONTAL_ALIGNMENT_LEFT, 200, 22, Color.YELLOW)
	# Time
	var mins := int(race_time) / 60
	var secs := int(race_time) % 60
	var ms := int(fmod(race_time, 1.0) * 100)
	draw_string(font, Vector2(20, 96), "%d:%02d.%02d" % [mins, secs, ms], HORIZONTAL_ALIGNMENT_LEFT, 200, 20, Color.WHITE)

	# Level
	draw_string(font, Vector2(SW - 220, 38), "Level " + str(current_level), HORIZONTAL_ALIGNMENT_LEFT, 200, 22, Color.WHITE)
	# Distance
	var dist_pct := clampf(player_z / track_length * 100.0, 0.0, 100.0)
	draw_string(font, Vector2(SW - 220, 64), "Distance: " + str(int(dist_pct)) + "%", HORIZONTAL_ALIGNMENT_LEFT, 200, 20, Color.WHITE)
	# Money
	draw_string(font, Vector2(SW - 220, 90), "$" + str(money), HORIZONTAL_ALIGNMENT_LEFT, 200, 20, Color.GREEN)

	# Health bar
	var hb_x := SW / 2.0 - 100
	var hb_y := 14.0
	var hb_w := 200.0
	var hb_h := 20.0
	draw_rect(Rect2(hb_x - 2, hb_y - 2, hb_w + 4, hb_h + 4), Color(0, 0, 0, 0.5))
	var hp_ratio := clampf(player_health / player_max_health, 0.0, 1.0)
	var hp_color := Color.GREEN if hp_ratio > 0.5 else (Color.YELLOW if hp_ratio > 0.25 else Color.RED)
	draw_rect(Rect2(hb_x, hb_y, hb_w * hp_ratio, hb_h), hp_color)
	draw_string(font, Vector2(hb_x, hb_y + 16), "HP", HORIZONTAL_ALIGNMENT_CENTER, hb_w, 14, Color.WHITE)

	# Minimap (distance bar)
	var mm_y := 42.0
	draw_rect(Rect2(hb_x, mm_y, hb_w, 6), Color(0.3, 0.3, 0.3, 0.6))
	draw_rect(Rect2(hb_x, mm_y, hb_w * clampf(player_z / track_length, 0, 1), 6), Color.WHITE)
	for opp in opponents:
		var ox := hb_x + hb_w * clampf(opp.z / track_length, 0, 1)
		draw_rect(Rect2(ox - 2, mm_y - 1, 4, 8), opp.color)

func _ordinal(n: int) -> String:
	if n == 1: return "st"
	if n == 2: return "nd"
	if n == 3: return "rd"
	return "th"

# ============================================================
# MENUS
# ============================================================

func _draw_menu():
	# Animated road background
	var save_z := player_z
	var save_y := camera_y
	player_z = menu_scroll
	camera_y = _find_y(menu_scroll) + CAMERA_HEIGHT
	player_x = sin(menu_scroll * 0.0003) * 0.5
	_draw_sky()
	_compute_projections()
	_draw_road_pass()
	_draw_sprite_pass()
	player_z = save_z
	camera_y = save_y
	player_x = 0

	# Overlay
	draw_rect(Rect2(0, 0, SW, SH), Color(0, 0, 0, 0.45))

	var font := ThemeDB.fallback_font
	var cx := SW / 2.0

	# Title
	_draw_text_bold(Vector2(0, SH * 0.28), "ROAD DASH", 64, Color(1.0, 0.85, 0.1))

	# Subtitle
	draw_string(font, Vector2(0, SH * 0.40), "Motorcycle Combat Racing",
		HORIZONTAL_ALIGNMENT_CENTER, SW, 24, Color(0.9, 0.9, 0.9))

	# Start prompt (blink)
	if fmod(menu_scroll * 0.001, 1.5) < 1.0:
		draw_string(font, Vector2(0, SH * 0.58), "Press SPACE or Tap to Start",
			HORIZONTAL_ALIGNMENT_CENTER, SW, 28, Color.WHITE)

	# Controls help
	draw_string(font, Vector2(0, SH * 0.74), "Arrow Keys / WASD = Steer & Gas/Brake",
		HORIZONTAL_ALIGNMENT_CENTER, SW, 18, Color(0.7, 0.7, 0.7))
	draw_string(font, Vector2(0, SH * 0.80), "Z = Punch Left   X = Punch Right",
		HORIZONTAL_ALIGNMENT_CENTER, SW, 18, Color(0.7, 0.7, 0.7))

func _draw_countdown():
	var font := ThemeDB.fallback_font
	var num := ceili(countdown_timer)
	var text := str(num) if num > 0 else "GO!"
	var col := Color.YELLOW if num > 0 else Color.GREEN
	var sz := 72 if num > 0 else 80
	_draw_text_bold(Vector2(0, SH * 0.45), text, sz, col)

func _draw_crash_overlay():
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, SH * 0.35, SW, SH * 0.15), Color(0.6, 0, 0, 0.6))
	_draw_text_bold(Vector2(0, SH * 0.45), "CRASHED!", 52, Color.WHITE)
	draw_string(font, Vector2(0, SH * 0.52), "Recovering...",
		HORIZONTAL_ALIGNMENT_CENTER, SW, 22, Color(0.9, 0.9, 0.9))

func _draw_results():
	draw_rect(Rect2(0, 0, SW, SH), Color(0.05, 0.05, 0.15))
	var font := ThemeDB.fallback_font

	_draw_text_bold(Vector2(0, SH * 0.15), "RACE COMPLETE", 52, Color(0.3, 0.9, 0.3))

	var pos_text := str(finish_position) + _ordinal(finish_position) + " Place"
	var pos_col := Color.GOLD if finish_position == 1 else (Color.SILVER if finish_position <= 3 else Color.WHITE)
	_draw_text_bold(Vector2(0, SH * 0.30), pos_text, 44, pos_col)

	var mins := int(race_time) / 60
	var secs := int(race_time) % 60
	draw_string(font, Vector2(0, SH * 0.42), "Time: %d:%02d" % [mins, secs],
		HORIZONTAL_ALIGNMENT_CENTER, SW, 28, Color.WHITE)

	var earnings := [0, 600, 400, 250, 150, 80, 50]
	var earned := earnings[clampi(finish_position, 1, 6)]
	draw_string(font, Vector2(0, SH * 0.52), "Earned: $" + str(earned),
		HORIZONTAL_ALIGNMENT_CENTER, SW, 28, Color.GREEN)

	draw_string(font, Vector2(0, SH * 0.62), "Total: $" + str(money),
		HORIZONTAL_ALIGNMENT_CENTER, SW, 24, Color(0.7, 0.9, 0.7))

	if fmod(race_time + Time.get_ticks_msec() * 0.001, 1.5) < 1.0:
		draw_string(font, Vector2(0, SH * 0.78), "Press SPACE or Tap to continue",
			HORIZONTAL_ALIGNMENT_CENTER, SW, 24, Color.WHITE)

func _draw_shop():
	draw_rect(Rect2(0, 0, SW, SH), Color(0.08, 0.06, 0.18))
	var font := ThemeDB.fallback_font

	_draw_text_bold(Vector2(0, SH * 0.10), "BIKE SHOP", 48, Color(0.9, 0.7, 0.2))
	draw_string(font, Vector2(0, SH * 0.20), "Money: $" + str(money),
		HORIZONTAL_ALIGNMENT_CENTER, SW, 26, Color.GREEN)

	var items := [
		["Speed Lv." + str(bike_speed_lvl), "$" + str(150 * (bike_speed_lvl + 1)), bike_speed_lvl],
		["Accel Lv." + str(bike_accel_lvl), "$" + str(120 * (bike_accel_lvl + 1)), bike_accel_lvl],
		["Armor Lv." + str(bike_armor_lvl), "$" + str(100 * (bike_armor_lvl + 1)), bike_armor_lvl],
		[">> Next Race (Level " + str(current_level + 1) + ") >>", "", -1],
	]

	for i in range(items.size()):
		var iy := SH * (0.32 + i * 0.14)
		var selected := i == shop_selected
		var bg_col := Color(0.3, 0.3, 0.6, 0.5) if selected else Color(0.15, 0.15, 0.3, 0.4)
		draw_rect(Rect2(SW * 0.2, iy - 20, SW * 0.6, 45), bg_col)
		if selected:
			draw_rect(Rect2(SW * 0.2, iy - 20, 4, 45), Color.YELLOW)
		var tc := Color.WHITE if selected else Color(0.65, 0.65, 0.65)
		draw_string(font, Vector2(SW * 0.25, iy + 8), items[i][0], HORIZONTAL_ALIGNMENT_LEFT, SW * 0.4, 22, tc)
		if items[i][1] != "":
			draw_string(font, Vector2(SW * 0.55, iy + 8), items[i][1], HORIZONTAL_ALIGNMENT_RIGHT, SW * 0.2, 22, Color.YELLOW if selected else Color(0.6, 0.6, 0.3))
		# Level bars
		if items[i][2] >= 0:
			var bar_x := SW * 0.25
			var bar_y := iy + 16
			for j in range(10):
				var bc := Color(0.2, 0.7, 0.2) if j < items[i][2] else Color(0.2, 0.2, 0.2)
				draw_rect(Rect2(bar_x + j * 22, bar_y, 18, 8), bc)

	draw_string(font, Vector2(0, SH * 0.90), "Up/Down = Select   Space/Enter = Buy",
		HORIZONTAL_ALIGNMENT_CENTER, SW, 18, Color(0.5, 0.5, 0.5))

# ============================================================
# TOUCH INPUT
# ============================================================

func _handle_touch(event: InputEventScreenTouch):
	if event.pressed:
		var btn := _get_touch_button(event.position)
		if btn != "":
			touch_map[event.index] = btn
		_refresh_touch()
	else:
		touch_map.erase(event.index)
		_refresh_touch()

func _handle_drag(event: InputEventScreenDrag):
	var btn := _get_touch_button(event.position)
	if btn != "":
		touch_map[event.index] = btn
	else:
		touch_map.erase(event.index)
	_refresh_touch()

func _get_touch_button(pos: Vector2) -> String:
	var rx := pos.x / SW
	var ry := pos.y / SH
	# Left zone: steering
	if rx < 0.25 and ry > 0.7:
		return "left" if rx < 0.125 else "right"
	# Right zone: gas/brake
	if rx > 0.75 and ry > 0.7:
		return "gas" if ry < 0.85 else "brake"
	# Middle zone: punch
	if ry > 0.5 and ry < 0.72:
		if rx < 0.2:
			return "punch_l"
		elif rx > 0.8:
			return "punch_r"
	return ""

func _refresh_touch():
	touch_left = false; touch_right = false
	touch_gas = false; touch_brake = false
	touch_punch_l = false; touch_punch_r = false
	for btn in touch_map.values():
		match btn:
			"left": touch_left = true
			"right": touch_right = true
			"gas": touch_gas = true
			"brake": touch_brake = true
			"punch_l": touch_punch_l = true
			"punch_r": touch_punch_r = true

func _draw_touch_controls():
	# Only show on touch devices (check if we've ever received a touch)
	if touch_map.is_empty() and not _has_touch_capability():
		return

	var alpha := 0.25
	var font := ThemeDB.fallback_font

	# Left zone
	var lx := SW * 0.0; var ly := SH * 0.72
	draw_rect(Rect2(lx, ly, SW * 0.125, SH * 0.28), Color(1, 1, 1, alpha if not touch_left else alpha * 2))
	draw_string(font, Vector2(lx + 10, ly + 40), "<", HORIZONTAL_ALIGNMENT_LEFT, 80, 36, Color(1, 1, 1, 0.6))
	draw_rect(Rect2(SW * 0.125, ly, SW * 0.125, SH * 0.28), Color(1, 1, 1, alpha if not touch_right else alpha * 2))
	draw_string(font, Vector2(SW * 0.125 + 10, ly + 40), ">", HORIZONTAL_ALIGNMENT_LEFT, 80, 36, Color(1, 1, 1, 0.6))

	# Right zone
	var rx_start := SW * 0.75
	draw_rect(Rect2(rx_start, SH * 0.70, SW * 0.25, SH * 0.15), Color(0, 1, 0, alpha if not touch_gas else alpha * 2))
	draw_string(font, Vector2(rx_start + 20, SH * 0.80), "GAS", HORIZONTAL_ALIGNMENT_LEFT, 100, 22, Color(1, 1, 1, 0.6))
	draw_rect(Rect2(rx_start, SH * 0.85, SW * 0.25, SH * 0.15), Color(1, 0, 0, alpha if not touch_brake else alpha * 2))
	draw_string(font, Vector2(rx_start + 20, SH * 0.95), "BRK", HORIZONTAL_ALIGNMENT_LEFT, 100, 22, Color(1, 1, 1, 0.6))

	# Punch zones
	draw_rect(Rect2(0, SH * 0.52, SW * 0.15, SH * 0.16), Color(1, 0.5, 0, alpha))
	draw_string(font, Vector2(8, SH * 0.62), "Z", HORIZONTAL_ALIGNMENT_LEFT, 60, 28, Color(1, 1, 1, 0.5))
	draw_rect(Rect2(SW * 0.85, SH * 0.52, SW * 0.15, SH * 0.16), Color(1, 0.5, 0, alpha))
	draw_string(font, Vector2(SW * 0.85 + 8, SH * 0.62), "X", HORIZONTAL_ALIGNMENT_LEFT, 60, 28, Color(1, 1, 1, 0.5))

var _touch_detected := false
func _has_touch_capability() -> bool:
	if _touch_detected:
		return true
	if not touch_map.is_empty():
		_touch_detected = true
	return _touch_detected

# ============================================================
# UTILITIES
# ============================================================

func _seg_index(z: float) -> int:
	var idx := int(z / SEGMENT_LENGTH) % segments.size()
	if idx < 0:
		idx += segments.size()
	return idx

func _find_y(z: float) -> float:
	if segments.is_empty():
		return 0.0
	var idx := _seg_index(z)
	var next := (idx + 1) % segments.size()
	var t := fmod(z, SEGMENT_LENGTH) / SEGMENT_LENGTH
	return lerpf(segments[idx].y, segments[next].y, t)

func _get_position() -> int:
	var pos := 1
	for opp in opponents:
		if opp.z > player_z:
			pos += 1
	return pos

func _draw_text_bold(pos: Vector2, text: String, sz: int, col: Color):
	var font := ThemeDB.fallback_font
	var shadow := col.darkened(0.6)
	for off in [Vector2(-2, -2), Vector2(2, -2), Vector2(-2, 2), Vector2(2, 2)]:
		draw_string(font, pos + off, text, HORIZONTAL_ALIGNMENT_CENTER, SW, sz, shadow)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, SW, sz, col)
