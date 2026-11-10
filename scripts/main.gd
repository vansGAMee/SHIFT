extends Node

const Art = preload("res://scripts/world_art.gd")
const Prop = preload("res://scripts/props.gd")
const Sound = preload("res://scripts/soundscape.gd")
const HUD = preload("res://scripts/hud.gd")
const SAVE_PATH = "user://journey.cfg"

var viewport: SubViewport
var display: TextureRect
var world: Node3D
var player: CharacterBody3D
var camera: Camera3D
var gun: Node3D
var gun_pivot: Node3D
var audio: Node
var ui: CanvasLayer
var language := "en"
var localizer: Node
var stage := "menu"
var checkpoint := "prologue"
var paused := false
var busy := false
var states := {}
var selected: Array[String] = []
var devices := {}
var door_roots := {}
var used_shift := false
var target := ""
var inspection := false
var inspect_rotation := Vector2.ZERO
var inspect_roll := 0.0
var inspect_zoom := 0.0
var reload_busy := false
var loaded_round := false
var has_rifle := false
var ground_rifle: Node3D
var inspected := 0.0
var scene_time := 0.0
var walk_time := 0.0
var foot_time := 0.0
var yaw := 0.0
var pitch := 0.0
var has_ammo := false
var lock_open := false
var bridge: Node3D
var bridge_shape: CollisionShape3D
var source_anim: Node3D
var extra_level: Node
var narrative: Node
var story_active := false
var memory_yaw := 0.0
var memory_pitch := 0.0
var reduced_flashes := false
var no_chase := false
var streamer_mode := false
var reset_pending := false
var early_cue := false
var early_second: Node3D
var early_threat_time := 0.0
var master_volume := 0.85
var music_volume := 0.38
var ambience_volume := 0.75
var sensitivity := 0.0022
var quality := 1
var sway := true
var show_fps := false
var automating := false
var automation_session := false
var journey_started := false
var fps_samples: Array[float] = []

func _ready():
	var args = OS.get_cmdline_user_args()
	automation_session = automation_session or "--test" in args or "--startup-test" in args or "--extra-test" in args or "--campaign-test" in args or "--prop-audit" in args or "--release-test" in args
	for arg in args:
		if arg.begins_with("--capture="): automation_session = true
	automating = automating or automation_session
	get_tree().auto_accept_quit = false
	load_settings()
	viewport = SubViewport.new()
	viewport.size = Vector2i(640,360)
	viewport.own_world_3d = true
	viewport.positional_shadow_atlas_size = 2048
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.audio_listener_enable_3d = true
	viewport.physics_object_picking = false
	add_child(viewport)
	display = TextureRect.new()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var screen_shader = preload("res://assets/textures/atmosphere.gdshader")
	var screen_mat = ShaderMaterial.new()
	screen_mat.shader = screen_shader
	display.material = screen_mat
	add_child(display)
	audio = Sound.new()
	add_child(audio)
	audio.set_master(master_volume)
	audio.set_music(music_volume)
	audio.set_ambience(ambience_volume)
	ui = HUD.new(self)
	add_child(ui)
	narrative = preload("res://scripts/narrative.gd").new()
	narrative.game = self
	add_child(narrative)
	localizer=preload("res://scripts/localization.gd").new()
	localizer.game=self
	add_child(localizer)
	audio.streamer_mode = streamer_mode
	set_quality(quality)
	display.material.set_shader_parameter("calm",reduced_flashes)
	build_scene("menu")
	ui.menu_continue.disabled = not has_saved_journey()
	await ui.fade_to(0.0,1.2)
	if "--test" in args:
		automating = true
		call_deferred("run_tests")
	if "--startup-test" in args:
		var startup_runner = load("res://tests/startup.gd").new()
		add_child(startup_runner)
		startup_runner.call_deferred("run",self)
	if "--extra-test" in args:
		var extra_runner = load("res://tests/extra_levels.gd").new()
		add_child(extra_runner)
		extra_runner.call_deferred("run",self)
	if "--campaign-test" in args:
		var runner = load("res://tests/campaign.gd").new()
		add_child(runner)
		runner.call_deferred("run",self)
	if "--prop-audit" in args:
		var prop_runner=load("res://tests/prop_audit.gd").new()
		add_child(prop_runner)
		prop_runner.call_deferred("run",self)
	if "--release-test" in args:
		var release_runner=load("res://tests/release_features.gd").new()
		add_child(release_runner)
		release_runner.call_deferred("run",self)
	if "--new-game" in args:
		new_game()
	for arg in args:
		if arg.begins_with("--capture="):
			automating = true
			call_deferred("capture_scene",arg.trim_prefix("--capture="))

func build_scene(next_stage: String):
	narrative.enter_stage()
	extra_level = null
	reset_pending = false
	early_cue = false
	early_threat_time = 0.0
	early_second = null
	if world:
		viewport.remove_child(world)
		world.queue_free()
	world = Node3D.new()
	viewport.add_child(world)
	stage = next_stage
	ground_rifle = null
	has_rifle = stage not in ["menu","prologue"]
	states.clear()
	devices.clear()
	door_roots.clear()
	selected.clear()
	target = ""
	used_shift = false
	inspection = false
	inspect_rotation = Vector2.ZERO
	inspect_roll = 0.0
	inspect_zoom = 0.0
	reload_busy = false
	inspected = 0.0
	scene_time = 0.0
	lock_open = false
	bridge = null
	bridge_shape = null
	source_anim = null
	paused = false
	var mountain = stage in ["menu", "prologue", "finale"]
	if mountain:
		Art.mountain(world)
	elif stage == "chamber1":
		Art.chamber(world,1)
	elif stage in ["chamber2", "escape"]:
		Art.chamber(world,2)
	create_player(mountain)
	if stage == "chamber1":
		states = {"source":false,"door":false}
		add_device("source","source",Vector3(-3,0,-5))
		create_door("door",-15.0)
		add_marker("door",Vector3(2.1,1.4,-14.6),Vector3(0.75,1.0,0.25))
		wall_text("НАКОПИТЕЛЬ",Vector3(-3,1.65,-5.05),0.026)
		wall_text("01  /  ПЕРЕНОС",Vector3(0,3.5,-14.7),0.037)
		wall_text("Два состояния.\nОдин обмен.",Vector3(3.5,2.05,-10.1),0.022)
		add_diagram(1)
		ui.chapter_title("I  ·  Пробуждение")
		ui.announce("Где-то за стеной гудит воздух.",4)
	elif stage in ["chamber2","escape"]:
		states = {"generator":true,"bridge":false,"exit":false}
		add_device("generator","generator",Vector3(-5,0,-5))
		create_door("gate",-10.0)
		set_door("gate",true,false)
		add_device("bridge","bridge_console",Vector3(1.25,0,-10.52))
		# The relay is a second access point to the SAME generator state.
		add_device("generator","door_console",Vector3(-1.25,0,-10.52),"relay")
		wall_text("РЕЛЕ ГЕНЕРАТОРА",Vector3(-1.25,1.65,-10.55),0.013)
		wall_text("МОСТ",Vector3(1.25,1.65,-10.55),0.020)
		make_bridge()
		create_door("exit",-23.0)
		add_device("lock","lock",Vector3(1.75,0,-22.2))
		var childhood_book = Prop.book(world,Vector3(-2.3,1.04,-18.0))
		devices["memory_book"] = {"node": childhood_book}
		add_marker("memory_book",Vector3(-2.3,1.09,-18),Vector3(0.76,0.15,0.56))
		Art.box(world,Vector3(-2.3,0.97,-18),Vector3(1.25,0.12,0.85),metal(Color("595449")),true)
		for side in [-1,1]:
			Art.box(world,Vector3(-2.3+side*0.48,0.46,-18),Vector3(0.08,0.92,0.64),metal(Color("363e3e")),true)
		var lamp_metal=metal(Color("343b3a"))
		Art.pipe(world,Vector3(-2.75,1.04,-18.25),Vector3(-2.75,1.9,-18.25),0.018,lamp_metal)
		Art.pipe(world,Vector3(-2.75,1.9,-18.25),Vector3(-2.3,1.9,-18.15),0.018,lamp_metal)
		Art.box(world,Vector3(-2.3,1.9,-18.15),Vector3(0.34,0.08,0.2),lamp_metal)
		Art.box(world,Vector3(-2.3,1.855,-18.15),Vector3(0.24,0.012,0.12),Art.flat(Color("c5ad7d"),0.35))
		var pool = OmniLight3D.new()
		pool.position = Vector3(-2.3,1.82,-18.15)
		pool.light_color = Color("ffc180")
		pool.light_energy = 0.12
		pool.omni_range = 1.8
		world.add_child(pool)
		wall_text("02  /  ОБРАТНАЯ СВЯЗЬ",Vector3(0,3.65,-9.75),0.031)
		wall_text("ПОКА РАБОТАЕТ ГЕНЕРАТОР — ШЛЮЗ ОТКРЫТ",Vector3(0,3.08,-9.72),0.016)
		wall_text("ПУТЬ НАЗАД / ПУТЬ ВПЕРЁД",Vector3(0,2.9,-22.72),0.022)
		add_diagram(2)
		ui.chapter_title("II  ·  По другую сторону")
		ui.announce("Один источник. Два пути.",4)
		if stage == "escape":
			states.generator = false
			states.bridge = true
			used_shift = true
			player.position = Vector3(0,0.1,-19)
			update_states(false)
	elif stage in ["chamber3","chamber4"]:
		extra_level = load("res://scripts/extra_levels.gd").new()
		extra_level.game = self
		world.add_child(extra_level)
		extra_level.build(3 if stage=="chamber3" else 4)
	elif stage.begins_with("chamber") and int(stage.trim_prefix("chamber")) in range(5,15):
		extra_level = preload("res://scripts/campaign.gd").new()
		extra_level.game = self
		world.add_child(extra_level)
		extra_level.build(int(stage.trim_prefix("chamber")))
	elif stage == "prologue":
		ground_rifle = Prop.rifle(world,false)
		ground_rifle.position = Vector3(0.95,0.04,3.45)
		ground_rifle.rotation = Vector3(0,-0.35,1.38)
		ground_rifle.scale = Vector3.ONE * 1.4
		add_marker("rifle",Vector3(0.95,0.12,3.45),Vector3(1.0,0.4,1.9))
		devices["ground_ammo"]=Prop.device(world,"ammo",Vector3(0.65,0.04,4.4))
		add_marker("ground_ammo",Vector3(0.65,0.12,4.4),Vector3(0.22,0.16,0.27))
		Prop._box(world,Vector3(-0.55,0.06,4.1),Vector3(0.4,0.07,0.55),metal(Color("97795b")))
		ui.chapter_title("До тишины")
		ui.announce("Ветер в елях. Справа, в траве, знакомое дерево приклада.",6)
	elif stage == "finale":
		ui.chapter_title("")
		call_deferred("ending")
	if stage in ["chamber1","chamber2","chamber3","chamber4"]:
		add_early_motifs()
	if stage != "menu":
		ui.menu.hide()
		ui.credit_panel.hide()
		ui.pause_panel.hide()
		ui.set_gameplay(stage != "finale")
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if not automating else Input.MOUSE_MODE_VISIBLE
	else:
		ui.menu.show()
		ui.menu_continue.disabled = not has_saved_journey()
		ui.credit_panel.hide()
		ui.pause_panel.hide()
		ui.settings.hide()
		ui.set_gameplay(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		ui.menu_new.grab_focus()
	audio.set_scene("mountain" if stage == "prologue" else "finale" if stage == "finale" else "menu" if stage == "menu" else "interior")
	if stage != "menu":
		checkpoint = stage
		save_progress()
	update_states(false)
	player.reset_physics_interpolation()

func create_player(mountain: bool):
	player = CharacterBody3D.new()
	player.position = Vector3(0,0.05,3.0) if not mountain else Vector3(0,0,5)
	player.collision_layer = 4
	player.collision_mask = 1
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.24
	capsule.height = 1.55
	shape.shape = capsule
	shape.position.y = 0.79
	player.add_child(shape)
	world.add_child(player)
	camera = Camera3D.new()
	camera.position.y = 0.78 if mountain else 1.64
	camera.fov = 73
	camera.near = 0.035
	camera.far = 1500
	player.add_child(camera)
	camera.top_level = true
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.global_position = player.global_position + Vector3(0,0.78 if mountain else 1.64,0)
	camera.current = true
	yaw = 0
	pitch = -0.045 if mountain else 0
	camera.rotation.x = pitch
	gun_pivot = Node3D.new()
	camera.add_child(gun_pivot)
	gun = Prop.rifle(gun_pivot)
	gun.position = Vector3.ZERO
	gun_pivot.position = Vector3(0.20,-0.35,-0.64)
	gun.scale = Vector3.ONE*0.91
	gun.rotation = Vector3(0.04,-0.09,-0.04)
	gun_pivot.visible = has_rifle
	if mountain and stage != "menu":
		var resting_legs = Prop.legs(world)
		resting_legs.position = camera.global_position
	var prop_light = OmniLight3D.new()
	prop_light.position = Vector3(-0.2,0.1,-0.3)
	prop_light.light_color = Color("dac6b0")
	prop_light.light_energy = 0.12
	prop_light.omni_range = 1.3
	camera.add_child(prop_light)

func metal(color: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m

func add_device(id: String, kind: String, pos: Vector3, alias: String = ""):
	var prop = Prop.device(world,kind,pos)
	devices[id if alias == "" else alias] = prop
	if id in states:
		var mark = Label3D.new()
		mark.text="⇄"
		mark.font=preload("res://assets/fonts/mono.ttf")
		mark.pixel_size=0.005
		mark.position=Vector3(0,1.6,0.2)
		mark.outline_size=0
		prop.node.add_child(mark)
		prop["selection_mark"]=mark
	var focus = Vector3(0,0.85,0)
	var size = Vector3(0.95,1.7,0.65)
	if kind=="ammo": focus=Vector3(0,0.055,0); size=Vector3(0.16,0.12,0.30)
	if kind=="lock": focus=Vector3(0,1.20,0.04); size=Vector3(0.25,0.40,0.17)
	prop["focus"]=focus
	add_marker(id,pos+focus,size)

func add_marker(id: String, pos: Vector3, size: Vector3):
	var body = StaticBody3D.new()
	body.position = pos
	body.collision_layer = 2
	body.collision_mask = 0
	body.set_meta("item",id)
	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	collision.shape = box_shape
	body.add_child(collision)
	world.add_child(body)

func create_door(id: String, z: float):
	var root = Node3D.new()
	root.position = Vector3(0,0,z)
	world.add_child(root)
	var slab = Node3D.new()
	root.add_child(slab)
	var dark = metal(Color("363a37"))
	Art.box(slab,Vector3(0,1.7,0),Vector3(2.98,3.4,0.33),dark)
	for x in [-0.72,0.72]:
		Art.box(slab,Vector3(x,1.75,0.19),Vector3(1.15,2.7,0.12),metal(Color("4d5048")))
		for h in [0.65,2.7]:
			var brace = Art.box(slab,Vector3(x,h,0.27),Vector3(1.18,0.13,0.11),dark)
			brace.rotation.z = 0.25 if x<0 else -0.25
	Art.box(slab,Vector3(0,1.7,0.26),Vector3(0.07,3.4,0.1),metal(Color("252b2a")))
	Art.box(root,Vector3(0,3.55,0),Vector3(3.5,0.28,0.6),dark)
	for x in [-1.64,1.64]:
		Art.box(root,Vector3(x,1.7,0),Vector3(0.26,3.7,0.6),dark)
	for i in range(12):
		var mark = Art.box(root,Vector3(-1.43+i*0.26,3.55,0.315),Vector3(0.14,0.26,0.015),metal(Color("aa8b42") if i%2==0 else Color("222926")))
		mark.rotation.z = -0.3
	var body = StaticBody3D.new()
	body.collision_layer = 1
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(3,3.4,0.4)
	col.shape = box
	col.position.y = 1.7
	body.add_child(col)
	root.add_child(body)
	var lamp_mat = metal(Color("ba6043"))
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color("b45235")
	var lamp = Art.box(root,Vector3(0,3.3,0.25),Vector3(0.30,0.09,0.04),lamp_mat)
	door_roots[id] = {"node":root,"slab":slab,"shape":col,"lamp":lamp,"open":false}
	if id == "door":
		add_marker(id,Vector3(0,1.7,z+0.25),Vector3(2.8,3.2,0.3))
	if id == "exit":
		# A real walkable black passage beyond the final door.
		Art.box(world,Vector3(0,-0.2,z-5),Vector3(3.0,0.4,11),metal(Color.BLACK),true)
		for side in [-1.7,1.7]:
			Art.box(world,Vector3(side,2,z-5),Vector3(0.4,4.5,11),metal(Color.BLACK),true)

func set_door(id: String, opened: bool, animate: bool = true):
	if not door_roots.has(id): return
	var d = door_roots[id]
	if d.open == opened: return
	d.open = opened
	d.shape.set_deferred("disabled",opened)
	var height = 3.55 if opened else 0.0
	if animate:
		create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(d.slab,"position:y",height,1.35)
		audio.play_cue("door")
	else:
		d.slab.position.y = height
	var m = d.lamp.material_override.duplicate()
	m.albedo_color = Color("b9cb9b") if opened else Color("ba6043")
	m.emission = m.albedo_color
	d.lamp.material_override = m

func make_bridge():
	bridge = Node3D.new()
	bridge.position = Vector3(0,-3.2,-13)
	world.add_child(bridge)
	Art.box(bridge,Vector3.ZERO,Vector3(2.5,0.20,4.3),metal(Color("4f564e")))
	for z in range(-2,3):
		Art.box(bridge,Vector3(0,0.12,z*0.8),Vector3(2.4,0.04,0.13),metal(Color("737668")))
	for side in [-1.21,1.21]:
		Art.box(bridge,Vector3(side,0.15,0),Vector3(0.07,0.12,4.3),metal(Color("b39552")))
	var body = StaticBody3D.new()
	body.collision_layer = 1
	bridge_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(2.5,0.2,4.3)
	bridge_shape.shape = box
	bridge_shape.disabled = true
	body.add_child(bridge_shape)
	bridge.add_child(body)

func wall_text(value: String, pos: Vector3, pixel_size: float):
	var l = Label3D.new()
	l.text = value
	l.font = preload("res://assets/fonts/mono.ttf")
	l.font_size = 32
	l.pixel_size = pixel_size * 0.25
	l.position = pos
	l.modulate = Color("b5b9a3")
	l.outline_size = 0
	l.no_depth_test = false
	l.shaded = false
	world.add_child(l)

func add_diagram(level: int):
	if level == 1:
		wall_text("E   ○ → ●       SHIFT       ● ⇄ ○",Vector3(0,2.2,-14.70),0.018)
	else:
		wall_text("ГЕНЕРАТОР ● ─── ШЛЮЗ ●\n                       МОСТ ○\n\nСостояния можно обменять.\nРеле за шлюзом — тот же генератор.",Vector3(4.0,2.25,-8.6),0.014)

func update_states(animate: bool = true):
	for key in devices:
		var id = "generator" if key == "relay" else key
		if not states.has(id): continue
		var item = devices[key]
		var active: bool = states[id]
		if item.get("lamp"):
			var lamp_material = metal(Color("c4dbaa") if active else Color("96523a"))
			lamp_material.emission_enabled = true
			lamp_material.emission = lamp_material.albedo_color * (1.1 if active else 0.38)
			item.lamp.material_override = lamp_material
		if item.get("moving"):
			item.moving.rotation.x = -0.48 if active else 0.35
	if stage == "chamber1":
		set_door("door",states.get("door",false),animate)
	elif stage in ["chamber2","escape"]:
		set_door("gate",states.get("generator",true),animate)
		if bridge:
			var is_up: bool = states.get("bridge",false)
			var h = -0.12 if is_up else -3.2
			if animate:
				create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(bridge,"position:y",h,1.6)
			else: bridge.position.y = h
			bridge_shape.set_deferred("disabled",not is_up)
		set_door("exit",lock_open,animate)
	if extra_level:
		extra_level.after_shift()

func get_target() -> String:
	var from = camera.global_position
	var query = PhysicsRayQueryParameters3D.create(from,from-camera.global_transform.basis.z*24,3)
	var hit = camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.collider.has_meta("item"):
		var id: String = hit.collider.get_meta("item")
		if devices.has(id) and not devices[id].node.is_visible_in_tree(): return ""
		if (id=="rifle" and has_rifle) or (id=="lock" and lock_open): return ""
		return id
	return ""

func distance_to(id: String) -> float:
	for key in devices:
		if key == id or (id=="generator" and key=="relay"):
			if player.global_position.distance_to(devices[key].node.global_position)<2.5: return 1.0
	return 100.0

func select_item(id: String):
	if busy or paused or story_active: return
	if id not in states:
		if id != "": ui.announce("SHIFT соединяет только контуры с индикаторами.",2.5)
		return
	if used_shift:
		ui.announce("Обмен уже совершён.  R — повторить помещение.",3)
		return
	if selected.has(id): selected.erase(id)
	else:
		if selected.size() >= 2: selected.pop_front()
		selected.append(id)
	audio.play_cue("select")

func perform_shift() -> bool:
	if used_shift or selected.size()!=2 or busy or paused or story_active: return false
	if selected[0] not in states or selected[1] not in states or selected[0]==selected[1]: return false
	var a: String = selected[0]
	var b: String = selected[1]
	if states[a] == states[b]:
		ui.announce("Одинаковые состояния. Пока нечего переносить.",3)
		audio.play_cue("error")
		return false
	# Atomic swap: outputs recompute only after BOTH values have changed.
	var state_a: bool = states[a]
	states[a] = states[b]
	states[b] = state_a
	used_shift = true
	selected.clear()
	update_states()
	ui.shift_flash()
	audio.play_cue("shift")
	if extra_level:
		pass
	elif stage == "chamber1":
		ui.announce("То, что было закрыто, может открыться.",4)
	elif player.position.z > -10:
		ui.announce("Шлюз закрылся раньше, чем вы прошли.  R — повторить.",5)
	else:
		ui.announce("Иногда путь появляется, когда отпускаешь прежний.",4)
	return true

func interact(id: String):
	if stage == "prologue":
		if id=="ground_ammo":
			ui.announce("Патрон лежит рядом с ружьём. Холодный металл среди травы.",4)
			return
		if scene_time>8 and id!="rifle":
			transition_to("chamber1",2.0)
			return
		if not has_rifle:
			if id == "rifle": pickup_rifle()
			else: ui.announce("Ружьё лежит справа, в траве.",3)
		elif scene_time > 8:
			transition_to("chamber1",2.0)
		return
	if busy or paused or story_active: return
	if extra_level and extra_level.interact(id): return
	if id == "memory_book" and distance_to(id)<2.5:
		ui.announce("Знакомая обложка. На раскрытой странице — рисунок раздвоенной ели.",5)
		return
	if id == "source" and distance_to(id)<2.5 and not used_shift:
		states.source = not states.source
		audio.play_cue("lever")
		update_states()
	elif id == "ammo" and distance_to(id)<2.5 and not has_ammo:
		has_ammo = true
		devices.ammo.node.hide()
		audio.play_cue("pickup")
		ui.announce("Один патрон. Дерево приклада ещё хранит тепло.",4)
	elif id == "lock" and distance_to(id)<2.5:
		if not used_shift or not states.get("bridge",false): return
		if not lock_open: open_final_lock()

func open_final_lock():
	if busy: return
	busy = true
	ui.prompt.text = ""
	var t = create_tween()
	t.tween_property(gun_pivot,"rotation:z",-0.3,0.22)
	t.tween_property(gun_pivot,"rotation:z",0.18,0.15)
	await t.finished
	audio.play_cue("crack")
	lock_open = true
	if devices.has("lock"):
		devices.lock.node.rotation.z = -0.3
	update_states()
	create_tween().tween_property(gun_pivot,"rotation:z",0.0,0.5)
	busy = false
	ui.announce("За дверью нет ни света, ни эха.",4)

func reload_rifle():
	ui.announce("Ружьё — часть воспоминания. Здесь оно не поможет решить головоломку.",3)

func pickup_rifle():
	if has_rifle or reload_busy: return
	has_rifle = true
	reload_busy = true
	ground_rifle.hide()
	gun_pivot.show()
	gun_pivot.position = Vector3(0.45,-0.95,-0.72)
	audio.play_cue("pickup")
	var lift = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	lift.tween_property(gun_pivot,"position",Vector3(0.20,-0.35,-0.64),0.85)
	await lift.finished
	reload_busy = false
	ui.announce("Тяжесть знакома.  F — рассмотреть.",3)

func _unhandled_input(event: InputEvent):
	if automating: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F11:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
			return
		if event.physical_keycode == KEY_F3:
			show_fps = not show_fps
			return
		if event.physical_keycode == KEY_ESCAPE:
			if ui.settings.visible: ui.settings.hide(); save_settings()
			elif reset_pending: ui.cancel_reset()
			elif stage != "menu" and stage != "finale" and not busy: toggle_pause()
			return
	if stage == "menu" or paused or busy or reload_busy or ui.settings.visible or stage == "finale": return
	if story_active:
		if event is InputEventKey and event.pressed and event.physical_keycode==KEY_ENTER: narrative.skip_repeat()
		return
	if event is InputEventMouseMotion:
		if inspection:
			inspect_rotation += event.relative*0.006
			inspect_rotation = inspect_rotation.clamp(Vector2(-0.85,-1.25),Vector2(1.15,1.25))
		else:
			yaw -= event.relative.x*sensitivity
			pitch = clampf(pitch-event.relative.y*sensitivity,-1.20,1.15)
			if stage == "prologue": yaw=clampf(yaw,-1.35,1.35)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not inspection:
			select_item(target)
		if event.pressed and inspection:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP: inspect_roll += 0.13
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: inspect_roll -= 0.13
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and stage == "prologue" and not inspection and has_rifle:
			inspection = true
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E:
				if inspection and stage != "prologue": inspection = false
				else: interact(target)
			KEY_F:
				if has_rifle:
					inspection = not inspection
					if inspection and inspect_rotation.length()<0.1: inspect_rotation = Vector2(0.65,-0.22)
			KEY_Z:
				if inspection: inspect_zoom = 0.12 if inspect_zoom==0.0 else 0.0
			KEY_SHIFT, KEY_SPACE: perform_shift()
			KEY_Q: selected.clear()
			KEY_R:
				if stage.begins_with("chamber") or stage=="escape": ui.request_reset()

func _physics_process(delta: float):
	if not player or busy or paused or story_active or ui.settings.visible or reload_busy or stage in ["menu","prologue","finale"]: return
	var direction = Vector2.ZERO
	if not automating and not inspection:
		direction.x = float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A))
		direction.y = float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))
	direction = direction.normalized()
	var wish = player.global_transform.basis*Vector3(direction.x,0,direction.y)*2.65
	player.velocity.x = move_toward(player.velocity.x,wish.x,delta*15)
	player.velocity.z = move_toward(player.velocity.z,wish.z,delta*15)
	if not player.is_on_floor(): player.velocity.y -= 14*delta
	else: player.velocity.y = -0.5
	player.move_and_slide()
	if direction.length() > 0.1 and player.is_on_floor():
		walk_time += delta*7
		foot_time += delta
		if foot_time > 0.52:
			foot_time = 0
			audio.play_cue("step")
	else: foot_time = 0.3
	if player.position.y < -2.2:
		player.position = Vector3(0,0.15,-9 if not used_shift else -10.5)
		if extra_level and extra_level.has_method("state_label"):
			player.position=Vector3(0,0.15,-9)
		player.velocity = Vector3.ZERO
		player.reset_physics_interpolation()
		ui.announce("Под ногами пустота. Нужен мост.",3)
	if stage == "chamber1" and states.get("door",false) and player.position.z < -14.2:
		transition_to("chamber2",1.3)
	if stage in ["chamber2","escape"] and lock_open and player.position.z < -24.8:
		transition_to("chamber3",1.6)

func _process(delta: float):
	if not ui or not camera: return
	if show_fps:
		ui.fps.text = "%d fps  ·  %d draws" % [Engine.get_frames_per_second(),RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)]
	else: ui.fps.text = ""
	if automating and delta>0: fps_samples.append(delta)
	if paused or busy or ui.settings.visible: return
	scene_time += delta
	if not early_cue and stage in ["chamber1","chamber2","chamber3","chamber4"] and used_shift:
		early_cue=true
		match stage:
			"chamber1": ui.announce("Сквозь гул пробивается ветер. Тот же, что на горе.",5)
			"chamber2": ui.announce("За шлюзом горит одинокая лампа.",5)
			"chamber3": audio.play_cue("memory"); ui.announce("За стеной — три ноты и чей-то смех. Почти знакомый.",5)
			"chamber4":
				if early_second: early_second.show()
				audio.play_cue("second_step")
				ui.announce("В конце прохода кто-то стоит. На миг свет пропадает.",5)
	if early_second and early_second.visible:
		early_threat_time+=delta
		if early_threat_time>3: early_second.hide()
	if extra_level:
		extra_level.process_level(delta)
	if stage == "menu":
		player.rotation.y = sin(scene_time*0.06)*0.09
		camera.rotation.x = -0.045+sin(scene_time*0.07)*0.012
		camera.rotation.y = player.rotation.y
		return
	if stage == "finale": return
	if not automating and not inspection:
		yaw += (float(Input.is_physical_key_pressed(KEY_LEFT))-float(Input.is_physical_key_pressed(KEY_RIGHT)))*delta*1.25
		pitch = clampf(pitch+(float(Input.is_physical_key_pressed(KEY_UP))-float(Input.is_physical_key_pressed(KEY_DOWN)))*delta,-1.2,1.15)
	if story_active:
		yaw=lerp_angle(yaw,memory_yaw,1-exp(-delta*2.5))
		pitch=lerpf(pitch,memory_pitch,1-exp(-delta*2.5))
	player.rotation.y = yaw
	camera.rotation.x = pitch
	camera.rotation.y = yaw
	var mountain = stage == "prologue"
	var bob = sin(walk_time)*0.018 if sway and not mountain else 0.0
	camera.global_position = player.get_global_transform_interpolated().origin + Vector3(0,(0.78 if mountain else 1.64)+bob,0)
	var inspect_target = Vector3(inspect_rotation.x,inspect_rotation.y,inspect_roll-0.1) if inspection else Vector3.ZERO
	if not reload_busy:
		gun_pivot.rotation = gun_pivot.rotation.lerp(inspect_target,1-exp(-delta*9))
		var gun_position = Vector3(0.08,-0.28,-0.66+inspect_zoom) if inspection else Vector3(0.20,-0.35+sin(scene_time*1.3)*0.004,-0.64)
		gun_pivot.position = gun_pivot.position.lerp(gun_position,1-exp(-delta*8))
	if inspection:
		inspected += delta
		ui.cross.hide()
		ui.budget.text = ""
		ui.pair.text = ""
		ui.help.text = "F — опустить    Мышь — поворот    Колесо — наклон    Z — приблизить    "
		ui.prompt.text = ("Один патрон — из шкатулки Пандоры" if has_ammo else "Патронник пуст. Знакомые рукава, знакомые руки.")
		if mountain and scene_time>8: ui.prompt.text += "\nE — закрыть глаза"
		return
	if mountain:
		target = get_target()
		ui.budget.text = ""
		ui.cross.hide()
		ui.help.text = "Мышь — осмотреться    Esc — пауза"
		if not has_rifle:
			ui.prompt.text = "E — осмотреть патрон" if target=="ground_ammo" else "E — поднять ружьё" if target == "rifle" else "Ружьё и патрон лежат справа, в траве"
			if scene_time>8: ui.prompt.text += "\nE — закрыть глаза"
			ui.cross.visible = target in ["rifle","ground_ammo"]
		else:
			ui.prompt.text = "F / ЛКМ — рассмотреть ружьё" if scene_time<8 else "F — рассмотреть ружьё     E — закрыть глаза"
		ui.pair.text = ""
		return
	target = get_target()
	for key in devices:
		var item=devices[key]
		if not item.has("selection_mark"): continue
		var id="generator" if key=="relay" else "ventilator" if key=="ventilator_relay" else key
		var slot=selected.find(id)
		item.selection_mark.modulate=Color("87cfe2") if slot==0 else Color("e5b583") if slot==1 else Color("a4b2a7")
		item.selection_mark.text="[ ⇄ ]" if slot>=0 else "⇄"
	ui.cross.show()
	ui.cross.modulate = Color("d9c090") if target!="" else Color(0.85,0.85,0.8,0.5)
	ui.budget.text = "SHIFT   %s / 1" % ("0" if used_shift else "1")
	ui.help.text = "WASD — идти    ПКМ — выбрать    Shift — обменять    R — повторить    Esc — пауза" if scene_time<22 else "Esc — пауза"
	var text_value = ""
	if target in states:
		text_value = item_name(target)+"  ·  "+(extra_level.state_label(target) if extra_level and extra_level.has_method("state_label") else ("включено" if states[target] else "выключено"))
		if not used_shift: text_value += "\nПКМ — "+("снять выбор" if target in selected else "выбрать контур")
		if target == "source" and distance_to(target)<2.5 and not used_shift: text_value += "     E — переключить"
	elif target == "memory_book":
		text_value = "Детская книга\nE — рассмотреть" if distance_to(target)<2.5 else "Знакомая обложка"
	elif target == "ammo" and not has_ammo:
		text_value = "Патрон\nE — забрать" if distance_to(target)<2.5 else "Что-то осталось на столе"
	elif target == "lock" and not lock_open:
		text_value = "Старый замок\nE — сбить прикладом" if distance_to(target)<2.5 else "Заперто изнутри"
	if extra_level:
		var custom_prompt: String = extra_level.prompt_for(target)
		if not custom_prompt.is_empty(): text_value = custom_prompt
	ui.prompt.text = text_value
	var items: Array[String] = []
	for id in selected: items.append(item_name(id)+("  ●" if states[id] else "  ○"))
	ui.pair.text = "    ⇄    ".join(items)
	if selected.size()==2:
		ui.pair.text += "\nПосле обмена: "+item_name(selected[0])+" "+("●" if states[selected[1]] else "○")+" · "+item_name(selected[1])+" "+("●" if states[selected[0]] else "○")+"\nShift / пробел — подтвердить"
	if story_active:
		ui.prompt.text = ""
		ui.help.text = "Воспоминание · Esc — пауза"+(" · Enter — пропустить повтор" if narrative.flags.get(narrative.current,false) else "")

func item_name(id: String) -> String:
	if extra_level:
		var custom_name: String = extra_level.get_item_name(id)
		if not custom_name.is_empty(): return custom_name
	return {"source":"Накопитель","door":"Дверь","generator":"Генератор","bridge":"Мост","exit":"Выход"}.get(id,id)

func new_game():
	audio.reset_journey_music()
	narrative.flags.clear()
	narrative.secrets.clear()
	journey_started = true
	has_ammo = false
	loaded_round = false
	has_rifle = false
	transition_to("prologue",1.0)

func resume_saved():
	if not has_saved_journey():
		new_game()
		return
	audio.reset_journey_music()
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH)==OK:
		journey_started = true
		has_ammo = cfg.get_value("journey","ammo",false) if cfg.get_value("journey","format_version",0)==3 else false
		narrative.flags = cfg.get_value("journey","story",{})
		narrative.secrets = cfg.get_value("journey","secrets",{})
		transition_to(cfg.get_value("journey","stage","prologue"),0.8)

func transition_to(next_stage: String, seconds: float):
	if busy: return
	busy = true
	ui.prompt.text = ""
	ui.pair.text = ""
	if next_stage == "finale": audio.set_scene("void")
	else: audio.play_cue("transition")
	await ui.fade_to(1.0,seconds)
	build_scene(next_stage)
	await get_tree().process_frame
	busy = false
	await ui.fade_to(0.0,2.1 if next_stage=="finale" else 1.0)

func restart_chapter():
	if busy: return
	ui.pause_panel.hide()
	ui.settings.hide()
	paused = false
	transition_to(checkpoint,0.45)

func toggle_pause():
	paused = not paused
	ui.pause_panel.visible = paused
	if paused: ui.pause_panel.move_to_front()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED

func show_menu():
	busy = false
	build_scene("menu")
	ui.fade.color.a = 0

func save_progress():
	if automating or automation_session or not journey_started: return
	var cfg = ConfigFile.new()
	cfg.set_value("journey","format_version",3)
	cfg.set_value("journey","started",true)
	cfg.set_value("journey","stage",checkpoint)
	cfg.set_value("journey","ammo",has_ammo)
	cfg.set_value("journey","story",narrative.flags)
	cfg.set_value("journey","secrets",narrative.secrets)
	var temporary = SAVE_PATH+".tmp"
	if cfg.save(temporary)==OK:
		DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(SAVE_PATH))

func has_saved_journey() -> bool:
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK: return false
	if cfg.get_value("journey","format_version",0) not in [2,3]: return false
	if not cfg.get_value("journey","started",false): return false
	var saved_stage: String=cfg.get_value("journey","stage","")
	return saved_stage in ["prologue","escape","finale"] or saved_stage in chamber_stages()

func load_settings():
	var cfg = ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK: return
	language=cfg.get_value("interface","language","en")
	if language not in ["en","ru"]: language="en"
	master_volume = cfg.get_value("audio","master",master_volume)
	music_volume = cfg.get_value("audio","music",music_volume)
	ambience_volume = cfg.get_value("audio","ambience",ambience_volume)
	sensitivity = cfg.get_value("input","sensitivity",sensitivity)
	sway = cfg.get_value("video","sway",sway)
	reduced_flashes=cfg.get_value("video","reduced_flashes",false)
	no_chase=cfg.get_value("accessibility","no_chase",false)
	streamer_mode=cfg.get_value("audio","streamer",false)
	quality = cfg.get_value("video","quality",quality)

func save_settings():
	if automating or automation_session: return
	var cfg = ConfigFile.new()
	cfg.set_value("interface","language",language)
	cfg.set_value("audio","master",master_volume)
	cfg.set_value("audio","music",music_volume)
	cfg.set_value("audio","ambience",ambience_volume)
	cfg.set_value("input","sensitivity",sensitivity)
	cfg.set_value("video","sway",sway)
	cfg.set_value("video","reduced_flashes",reduced_flashes)
	cfg.set_value("accessibility","no_chase",no_chase)
	cfg.set_value("audio","streamer",streamer_mode)
	cfg.set_value("video","quality",quality)
	cfg.save("user://settings.cfg")

func set_language(value: String):
	language=value if value in ["en","ru"] else "en"
	if localizer: localizer.refresh()
	save_settings()

func set_quality(value: int):
	quality = clampi(value,0,2)
	if viewport: viewport.size = [Vector2i(480,270),Vector2i(640,360),Vector2i(960,540)][quality]

func ending():
	busy = true
	ui.set_gameplay(false)
	await get_tree().create_timer(3.1).timeout
	ui.subtitle.show()
	ui.subtitle.text="Я всё ещё здесь."
	await get_tree().create_timer(2.0).timeout
	if stage != "finale": return
	var t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(gun_pivot,"rotation",Vector3(1.02,-0.2,-0.16),1.7)
	t.parallel().tween_property(camera,"rotation:x",0.22,1.7)
	await t.finished
	await get_tree().create_timer(0.6).timeout
	audio.play_cue("shot")
	var recoil = create_tween()
	recoil.tween_property(gun_pivot,"rotation:x",1.15,0.08)
	recoil.tween_property(gun_pivot,"rotation:x",1.02,0.8)
	await get_tree().create_timer(2.4).timeout
	await ui.fade_to(1.0,2.0)
	audio.set_scene("credits")
	ui.subtitle.text=""
	narrative.flags.endingCompleted=true
	save_progress()
	ui.credit_panel.show()
	ui.credit_panel.move_to_front()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	busy = false

func capture_scene(which: String):
	build_scene("prologue" if which=="mountain" else "chamber2" if which=="book" else "menu" if which in ["settings","credits"] else which)
	if which=="settings": ui.show_settings()
	if which=="credits": ui.menu.hide(); ui.credit_panel.show()
	ui.fade.color.a = 0
	if which=="chamber1": player.position=Vector3(3,0.1,1); yaw=0.19
	if which=="chamber2": player.position=Vector3(3,0.1,0); yaw=0.12
	if which=="book": player.position=Vector3(-2.3,0.05,-16.65); yaw=0; pitch=-0.42
	await get_tree().create_timer(3.0).timeout
	var path = "res://builds/"+which+".png" if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join(which+".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE ",path," FPS ",Engine.get_frames_per_second()," DRAWS ",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	quit_game()

func chamber_stages() -> Array[String]:
	var result: Array[String]=[]
	for i in range(1,15): result.append("chamber"+str(i))
	return result

func _notification(what: int):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and not automating and not paused and stage not in ["menu","finale"]: toggle_pause()
	if what == NOTIFICATION_WM_CLOSE_REQUEST: quit_game()

func quit_game(code: int = 0):
	busy = true
	paused = true
	if audio:
		for child in audio.get_children():
			if child is AudioStreamPlayer:
				child.stop()
				child.stream = null
		audio.queue_free()
		audio = null
	Prop._materials.clear()
	# AudioServer releases playback references on its mixing thread. A wall-clock
	# drain also works in accelerated fixed-FPS validation and movie capture.
	var drain_until=Time.get_ticks_msec()+220
	while Time.get_ticks_msec()<drain_until: await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(code)

func run_tests():
	var runner = load("res://tests/integration.gd").new()
	add_child(runner)
	await runner.run(self)

func add_early_motifs():
	var tree_at=Vector3(3.5,1.2,-10.05) if stage=="chamber1" else Vector3(3.5,1.2,-20)
	for i in range(4):
		Art.pipe(world,tree_at+Vector3(0,i*0.2,0),tree_at+Vector3(-0.38+i*0.07,(i-1)*0.2,0),0.014,Art.flat(Color("b3b08a")))
		Art.pipe(world,tree_at+Vector3(0,i*0.2,0),tree_at+Vector3(0.38-i*0.07,(i-1)*0.2,0),0.014,Art.flat(Color("b3b08a")))
	Art.pipe(world,tree_at,tree_at+Vector3(0,0.9,0),0.015,Art.flat(Color("b3b08a")))
	if stage=="chamber4":
		early_second=Node3D.new()
		world.add_child(early_second)
		early_second.position=Vector3(0,0,-31)
		Art.box(early_second,Vector3(0,1.1,0),Vector3(0.6,0.85,0.3),Art.flat(Color("151c23")))
		Art.box(early_second,Vector3(0,1.7,0),Vector3(0.3,0.38,0.3),Art.flat(Color("0b131c")))
		for side in [-1,1]: Art.box(early_second,Vector3(side*0.18,0.4,0),Vector3(0.22,0.8,0.3),Art.flat(Color("141a21")))
		early_second.hide()
