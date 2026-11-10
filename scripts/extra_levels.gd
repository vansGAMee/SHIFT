extends Node
## Two self-contained rooms. Mechanical controls remain binary; white sockets
## carry the only two electrical states that SHIFT can exchange in each room.

const Art = preload("res://scripts/world_art.gd")
var game: Node
var level := 3
var relay_bits: Array[bool] = [false,false,false,false,false]
const INITIAL_SENSORS = [true,true,true,false,true,false]
var valves: Array[bool] = [false,true,true,true]
var sensor_lamps: Array[MeshInstance3D] = []
var mechanical: Dictionary = {}
var route_label: Label3D
var status_label: Label3D
var fixture_lights: Array[Light3D] = []
var fixture_tubes: Array[MeshInstance3D] = []
var warning_lamps: Array[MeshInstance3D] = []
var hazard_clock := 0.0
var exposure := 0.0
var warned := false
var room_time := 0.0
var retreat_busy := false
var current_route := "loop"
var _last_warning_cycle := -1

func build(which: int):
	level = which
	base_room(8.0 if level==3 else 9.0,-24.0 if level==3 else -28.0)
	if level == 3: build_archive()
	else: build_pressure()
	after_shift()

func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	return Art.flat(color,glow)

func box(pos: Vector3, size: Vector3, mat: Material, solid: bool = false) -> MeshInstance3D:
	return Art.box(game.world,pos,size,mat,solid)

func text(value: String, pos: Vector3, scale_v: float = 0.0045, color: Color = Color("c6c5ac")) -> Label3D:
	var label = Label3D.new()
	label.text = value
	label.font = preload("res://assets/fonts/mono.ttf")
	label.font_size = 32
	label.pixel_size = scale_v
	label.position = pos
	label.modulate = color
	label.outline_size = 0
	label.shaded = false
	game.world.add_child(label)
	return label

func base_room(width: float, north: float):
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101419") if level==3 else Color("121815")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9eabb6") if level==3 else Color("aeb6a1")
	env.ambient_light_energy = 0.075
	env.fog_enabled = true
	env.fog_density = 0.008
	env.fog_light_color = Color("18202a") if level==3 else Color("23241b")
	var world_env = WorldEnvironment.new()
	world_env.environment = env
	game.world.add_child(world_env)
	var concrete = Art.mat("concrete",Color("92948b"),0.6)
	var floor_mat = Art.mat("floor",Color("a2a294"),0.5)
	var steel = Art.mat("metal",Color("787e78"),0.8)
	var stripe = Art.mat("green",Color("6b7f78") if level==3 else Color("858169"),0.7)
	var dark = material(Color("252c2d"))
	var hazard = Art.mat("hazard",Color("ab9b68"),1.0)
	var depth = 4.0-north
	box(Vector3(0,-0.2,(north+4)*0.5),Vector3(width*2,0.4,depth),floor_mat,true)
	box(Vector3(0,5.1,(north+4)*0.5),Vector3(width*2+0.5,0.3,depth+0.5),steel)
	box(Vector3(0,2.5,4.2),Vector3(width*2+0.5,5,0.4),concrete,true)
	for side in [-1,1]:
		box(Vector3(side*(width+0.2),2.5,(north+4)*0.5),Vector3(0.4,5,depth+0.8),concrete,true)
		box(Vector3(side*(width+1.5)*0.5,2.5,north-0.2),Vector3(width-1.5,5,0.4),concrete,true)
		box(Vector3(side*(width-0.03),1.6,(north+4)*0.5),Vector3(0.04,0.4,depth),stripe)
		box(Vector3(side*(width-0.05),0.16,(north+4)*0.5),Vector3(0.1,0.3,depth),steel)
		Art.pipe(game.world,Vector3(side*(width-0.35),3.85,3.8),Vector3(side*(width-0.35),3.85,north+0.5),0.1,steel)
		Art.pipe(game.world,Vector3(side*(width-0.35),4.18,3.8),Vector3(side*(width-0.35),4.18,north+0.5),0.065,material(Color("5a4b3e")))
	box(Vector3(0,4.35,north-0.2),Vector3(3,1.3,0.4),concrete,true)
	for z in [-1.0,-7.0,-13.0,-19.0]:
		box(Vector3(0,4.85,z),Vector3(width*2,0.3,0.3),steel)
		for side in [-1,1]:
			box(Vector3(side*(width-0.15),2.5,z),Vector3(0.3,5,0.32),steel,true)
		make_fixture(Vector3((-1 if int(-z)%2==0 else 1)*2.2,4.62,z),Color("c4dac5") if level==3 else Color("d5d7ab"))
	# Ceiling cables, a readable route in the floor, and maintenance recesses.
	for side in [-1,1]:
		box(Vector3(side*1.7,0.012,(north+4)*0.5),Vector3(0.065,0.022,depth-0.5),hazard)
		for z in [-4.0,-15.0]:
			box(Vector3(side*(width-0.15),2.5,z),Vector3(0.12,1.4,2.4),dark)
			for i in range(7):
				box(Vector3(side*(width-0.24),2.0+i*0.15,z),Vector3(0.13,0.04,2.2),steel)
	box(Vector3(0,-0.2,north-1.2),Vector3(3,0.4,2.5),floor_mat,true)

func make_fixture(at: Vector3, color: Color):
	box(at,Vector3(2.2,0.17,0.8),material(Color("252d2b")))
	for tube in [-1,0,1]:
		var mesh = box(at+Vector3(0,-0.11,tube*0.22),Vector3(1.95,0.04,0.1),material(color,1.2))
		fixture_tubes.append(mesh)
	var lamp = Art.downlight(game.world,at+Vector3(0,-0.35,0),color,0.72,8.5)
	fixture_lights.append(lamp)

func build_archive():
	game.states = {"archive_cell":false,"archive_door":false}
	game.add_device("archive_cell","generator",Vector3(-5.8,0,-17.0))
	game.create_door("archive_door",-24.0)
	game.add_marker("archive_door",Vector3(0,1.7,-23.75),Vector3(2.8,3.2,0.32))
	text("03 / ПРОТИВОФАЗА",Vector3(0,3.8,-23.7),0.008)
	text("НАКОПИТЕЛЬ",Vector3(-5.8,1.9,-17.05),0.005)
	# The relay bank is a real cabinet. Walk around either side after balancing it.
	var cabinet = Art.mat("metal",Color("555f62"),0.7)
	box(Vector3(0,1.6,-18.4),Vector3(10.6,3.2,0.55),cabinet,true)
	box(Vector3(0,0.18,-18.05),Vector3(11.0,0.36,1.0),cabinet,true)
	for i in range(6):
		var x = -4.1+float(i)*1.64
		box(Vector3(x,2.62,-18.05),Vector3(0.82,0.68,0.12),material(Color("20282b")))
		var lamp = box(Vector3(x,2.62,-17.97),Vector3(0.53,0.40,0.06),material(Color("aa7950"),0.8))
		sensor_lamps.append(lamp)
		text(str(i+1),Vector3(x,3.13,-17.99),0.007)
	status_label = text("",Vector3(0,1.7,-18.0),0.0051)
	text("Пять рычагов. Каждый меняет два соседних датчика.\nПогасите все шесть: накопитель получит питание.\nБелые рамки — контуры для SHIFT.",Vector3(0,0.92,-18.0),0.0041)
	for i in range(5):
		var id = "relay_"+char(97+i)
		var at = Vector3(-5.0+float(i)*2.5,0,-8.0)
		make_mechanical(id,at,char(65+i),str(i+1)+" + "+str(i+2))
		# Each wire splits to the exact pair of neighboring sensors it changes.
		var wire = material(Color("8a7652"))
		var first_x = -4.1+float(i)*1.64
		Art.pipe(game.world,at+Vector3(0,1.25,-0.2),at+Vector3(0,3.55+float(i)*0.14,-0.2),0.025,wire)
		Art.pipe(game.world,at+Vector3(0,3.55+float(i)*0.14,-0.2),Vector3(first_x+0.82,3.55+float(i)*0.14,-17.9),0.025,wire)
		Art.pipe(game.world,Vector3(first_x,3.45,-17.9),Vector3(first_x+1.64,3.45,-17.9),0.027,wire)
		for x in [first_x,first_x+1.64]:
			Art.pipe(game.world,Vector3(x,3.45,-17.9),Vector3(x,2.94,-17.9),0.027,wire)
	# Archival cases and an amber work light distinguish the room from the first two.
	for side in [-1,1]:
		for z in [-3.0,-11.0,-21.0]:
			box(Vector3(side*7.2,1.3,z),Vector3(1.0,2.6,1.4),cabinet,true)
			for h in [0.4,0.9,1.4,1.9,2.4]:
				box(Vector3(side*7.2,h,z+0.72),Vector3(0.8,0.03,0.04),material(Color("303b3f")))
	Art.light(game.world,Vector3(-5.4,2.7,-16),Color("e8b377"),1.4,5.0)
	game.ui.chapter_title("III  ·  Противофаза")
	game.ui.announce("Провода продолжаются там, где взгляд уже теряется.",4)

func make_mechanical(id: String, at: Vector3, title: String, subtitle: String):
	game.add_device(id,"source",at)
	mechanical[id] = game.devices[id]
	# Manual handles have a brass plate and dark, non-emissive face. They are not sockets.
	var dev = mechanical[id]
	if dev.get("lamp"):
		dev.lamp.material_override = material(Color("686457"))
	text(title,at+Vector3(0,1.73,0.02),0.008,Color("d6b67d"))
	text(subtitle,at+Vector3(0,1.48,0.04),0.0043,Color("a9b5ab"))

func sensors() -> Array[bool]:
	var result: Array[bool] = []
	for i in range(6): result.append(INITIAL_SENSORS[i])
	for i in range(5):
		if relay_bits[i]:
			result[i] = not result[i]
			result[i+1] = not result[i+1]
	return result

func balanced() -> bool:
	for active in sensors():
		if active: return false
	return true

func build_pressure():
	game.states = {"ventilator":true,"release":false}
	game.add_device("ventilator","generator",Vector3(-3.2,0,-1.5))
	game.add_device("ventilator","door_console",Vector3(-2.0,0,-24.0),"ventilator_relay")
	game.add_device("release","door_console",Vector3(2.0,0,-24.0))
	game.create_door("exit",-28.0)
	game.add_device("lock","lock",Vector3(1.75,0,-27.2))
	text("04 / ТИХОЕ ДАВЛЕНИЕ",Vector3(0,3.9,-27.7),0.008)
	text("ВЕНТИЛЯЦИЯ",Vector3(-2,1.8,-24.0),0.0048)
	text("ПРИВОД ВЫХОДА",Vector3(2,1.8,-24.0),0.0048)
	var positions = [Vector3(-6.0,0,-5),Vector3(6.0,0,-9),Vector3(-6.0,0,-16),Vector3(6.0,0,-20)]
	var outputs = ["0 → B    1 → C", "0 → D    1 → A", "0 → B    1 → ПОЛ", "0 → БАК  1 → C"]
	for i in range(4):
		var id = "valve_"+char(97+i)
		make_mechanical(id,positions[i],char(65+i),outputs[i])
		# Safe alcoves are physical recesses bounded by heavy machinery, not magic zones.
		var side = -1.0 if positions[i].x<0 else 1.0
		for offset in [-1.45,1.45]:
			box(positions[i]+Vector3(side*0.3,0.8,offset),Vector3(3.4,1.6,0.45),Art.mat("metal",Color("5c6158"),0.8),true)
		box(positions[i]+Vector3(side*0.4,2.45,0),Vector3(3.7,0.12,3.4),material(Color("343c35")))
		Art.light(game.world,positions[i]+Vector3(0,2.1,0.5),Color("b5c5a6"),0.6,3.6)
		text("НИША",positions[i]+Vector3(0,2.15,0.1),0.0035,Color("a4b58e"))
	# Cooler C and the reservoir are visibly separate objects joined by solid pipes.
	var steel = Art.mat("metal",Color("71776a"),0.8)
	box(Vector3(-7.8,1.5,-16),Vector3(1.6,3.0,1.8),steel,true)
	for i in range(9):
		box(Vector3(-7.8,0.3+i*0.3,-15.04),Vector3(1.4,0.10,0.12),material(Color("354946")))
	text("C / ОХЛАДИТЕЛЬ",Vector3(-7.7,3.25,-15.03),0.0043,Color("9ebbb3"))
	var tank = Art.cylinder(game.world,Vector3(6.4,1.6,-25),0.9,3.2,steel,0.9,12)
	text("РЕЗЕРВУАР",Vector3(6.4,3.45,-24.05),0.0046)
	var copper = material(Color("806a46"))
	var paths = [[0,1],[0,2],[1,3],[1,0],[2,1],[3,2]]
	for i in range(paths.size()):
		var a: Vector3 = positions[paths[i][0]]+Vector3(0,3.1+float(i%3)*0.23,0)
		var b: Vector3 = positions[paths[i][1]]+Vector3(0,3.1+float(i%3)*0.23,0)
		var mid = Vector3(a.x,a.y,b.z)
		Art.pipe(game.world,a,mid,0.045,copper)
		Art.pipe(game.world,mid,b,0.045,copper)
	Art.pipe(game.world,positions[3]+Vector3(0,3.1,0),Vector3(6.4,3.1,-25),0.065,copper)
	# A central floor manifold shows where an incorrectly routed hot exhaust goes.
	for z in [-4.0,-8.0,-12.0,-16.0,-20.0,-24.0]:
		box(Vector3(0,0.018,z),Vector3(5.8,0.03,0.65),material(Color("282d29")))
		for i in range(12):
			box(Vector3(-2.65+i*0.48,0.04,z),Vector3(0.07,0.04,0.58),steel)
		var lamp = box(Vector3(3.4,0.09,z),Vector3(0.11,0.06,0.65),material(Color("52644a"),0.3))
		warning_lamps.append(lamp)
	# A lit schematic can be read safely before the player commits the single SHIFT.
	box(Vector3(0,2.45,-3.3),Vector3(6.6,2.4,0.25),material(Color("27302c")))
	text("Пар должен пройти ОХЛАДИТЕЛЬ C, затем попасть в БАК.\nA: 0 → B / 1 → C       B: 0 → D / 1 → A\nC: 0 → B / 1 → ПОЛ     D: 0 → БАК / 1 → C\n\nВентиляция удерживает жар. Ниши у стен безопасны.\nПривод выхода откроется от перенесённого питания.",Vector3(0,2.5,-3.14),0.00425)
	status_label = text("",Vector3(0,1.25,-3.12),0.0048)
	route_label = text("",Vector3(0,2.6,-25.7),0.0049)
	Art.light(game.world,Vector3(0,3.2,-2),Color("dacb9c"),1.0,5)
	# The only collectible round belongs to Pandora in room 13.
	game.ui.chapter_title("IV  ·  Тихое давление")
	game.ui.announce("Лампы гаснут чуть раньше, чем слышен щелчок.",4)

func route() -> String:
	var node := 0
	var seen: Array[int] = []
	var cooled := false
	for step in range(8):
		if node in seen: return "loop"
		seen.append(node)
		match node:
			0: node = 2 if valves[0] else 1
			1: node = 0 if valves[1] else 3
			2:
				cooled = true
				if valves[2]: return "room"
				node = 1
			3:
				if not valves[3]: return "cooled" if cooled else "hot_tank"
				node = 2
	return "loop"

func route_path() -> String:
	var path: Array[String] = []
	var node := 0
	var visited: Array[int] = []
	for i in range(8):
		path.append(char(65+node))
		if node in visited:
			path.append("КРУГ")
			break
		visited.append(node)
		match node:
			0: node = 2 if valves[0] else 1
			1: node = 0 if valves[1] else 3
			2:
				if valves[2]:
					path.append("ПОЛ")
					break
				node = 1
			3:
				if not valves[3]:
					path.append("БАК")
					break
				node = 2
	return " → ".join(path)

func after_shift():
	if level == 3:
		var values = sensors()
		for i in range(sensor_lamps.size()):
			sensor_lamps[i].material_override = material(Color("c88a55") if values[i] else Color("27383b"),0.8 if values[i] else 0)
		for i in range(5): update_handle("relay_"+char(97+i),relay_bits[i])
		var stable = balanced()
		status_label.text = "ВСЕ ДАТЧИКИ ПОГАШЕНЫ / можно зарядить накопитель" if stable else "ПОГАСИТЬ ШЕСТЬ ДАТЧИКОВ / рычаги меняют соседнюю пару"
		game.set_door("archive_door",game.states.get("archive_door",false) and stable)
	else:
		for i in range(4): update_handle("valve_"+char(97+i),valves[i])
		current_route = route()
		var description = {"loop":"Давление возвращается по кругу", "room":"Горячий пар направлен в пол", "hot_tank":"Пар в баке, но охладитель обойдён", "cooled":"Охладитель → бак. Давление безопасно."}[current_route]
		status_label.text = description
		route_label.text = route_path()+"\n"+description
		if game.devices.has("ventilator_relay"):
			var lamp = game.devices.ventilator_relay.get("lamp")
			if lamp: lamp.material_override = material(Color("b8c99b") if game.states.ventilator else Color("8a543c"),0.8)
		game.set_door("exit",game.lock_open and game.states.get("release",false))
		if not game.states.ventilator and current_route!="cooled" and not warned:
			warned = true
			hazard_clock = 0.0
			game.audio.play_cue("power_drop")
			game.ui.announce("Вентиляция умолкла. Решётки пола медленно нагреваются. Ниши у стен — прохладные.",6)

func update_handle(id: String, active: bool):
	if not mechanical.has(id): return
	var item = mechanical[id]
	if item.get("moving"): item.moving.rotation.x = -0.48 if active else 0.35
	if item.get("lamp"):
		item.lamp.material_override = material(Color("a99468") if active else Color("4e5048"))

func interact(id: String) -> bool:
	if level == 3:
		if id.begins_with("relay_"):
			if game.distance_to(id)>2.5: return true
			if game.used_shift:
				game.ui.announce("После переноса механические реле зафиксированы.",3)
				return true
			var index = id.unicode_at(id.length()-1)-97
			if index in range(5):
				relay_bits[index] = not relay_bits[index]
				game.audio.play_cue("lever")
				after_shift()
			return true
		if id == "archive_cell":
			if game.distance_to(id)>2.5: return true
			if game.used_shift: return true
			if balanced():
				game.states.archive_cell = true
				game.audio.play_cue("pickup")
				game.update_states()
				game.ui.announce("Заряд удерживается. Осталось перенести его на привод двери.",4)
			else: game.ui.announce("Накопитель не принимает заряд, пока хоть один датчик горит.",4)
			return true
	else:
		if id.begins_with("valve_"):
			if game.distance_to(id)>2.5: return true
			var index = id.unicode_at(id.length()-1)-97
			if index in range(4):
				valves[index] = not valves[index]
				game.audio.play_cue("lever")
				after_shift()
			return true
		if id == "lock":
			if game.distance_to(id)>2.5: return true
			if not game.states.release:
				game.ui.announce("Электрозасов удерживает дверь. Приводу выхода нужно питание.",4)
			elif current_route!="cooled":
				game.ui.announce("Блокировка давления. Пар должен пройти охладитель C и попасть в бак.",4)
			elif not game.lock_open: game.open_final_lock()
			return true
	return false

func prompt_for(id: String) -> String:
	if level==3:
		if id.begins_with("relay_"):
			var i = id.unicode_at(id.length()-1)-97
			if i in range(5):
				return "Механическое реле "+char(65+i)+" · датчики "+str(i+1)+" и "+str(i+2)+"\n"+("E — переключить (сейчас "+("1" if relay_bits[i] else "0")+")" if game.distance_to(id)<2.5 else "Подойдите ближе")
		if id=="archive_cell": return "Накопитель\nE — зарядить после балансировки     ПКМ — контур SHIFT"
	else:
		if id.begins_with("valve_"):
			var i = id.unicode_at(id.length()-1)-97
			if i in range(4): return "Развилка "+char(65+i)+" · положение "+("1" if valves[i] else "0")+"\n"+("E — перевести клапан" if game.distance_to(id)<2.5 else "Подойдите ближе")
		if id=="lock" and not game.lock_open: return "Замок и блокировка давления\nE — открыть после подготовки контура"
	return ""

func get_item_name(id: String) -> String:
	return {"archive_cell":"Накопитель", "archive_door":"Привод двери", "ventilator":"Вентиляция", "release":"Привод выхода"}.get(id,"")

func in_hot_zone(pos: Vector3) -> bool:
	return absf(pos.x)<4.2 and pos.z < -3.5 and pos.z > -24.5

func process_level(delta: float):
	room_time += delta
	if level==3:
		if game.states.get("archive_door",false) and balanced() and game.player.position.z < -24.55:
			game.transition_to("chamber4",1.2)
		return
	# Slow, uneven fluorescent breathing rather than rapid flashes.
	for i in range(fixture_lights.size()):
		var dim = 0.82+0.13*sin(room_time*0.75+float(i)*1.7)
		if not game.reduced_flashes and fmod(room_time+float(i)*2.1,11.0)>9.8: dim *= 0.5
		fixture_lights[i].light_energy = 0.72*dim
	var dangerous = not game.states.get("ventilator",true) and current_route!="cooled"
	if dangerous:
		hazard_clock += delta
		# Four seconds to understand the change; pulses themselves have a long lead-in.
		var cycle = fmod(maxf(0,hazard_clock-4.0),12.0)
		var phase_active = hazard_clock>4.0 and cycle>5.0 and cycle<9.0
		var phase_warning = hazard_clock>4.0 and cycle>2.0 and cycle<=5.0
		var cycle_index = int(maxf(0,hazard_clock-4.0)/12.0)
		if phase_warning and cycle_index!=_last_warning_cycle:
			_last_warning_cycle = cycle_index
			game.audio.play_cue("pressure_warning")
		var danger_gain = 0.6 if phase_active else 0.3 if phase_warning else 0.12
		if game.audio.has_method("set_danger"): game.audio.set_danger(danger_gain)
		var color = Color("b5703d") if phase_active else Color("938254") if phase_warning else Color("4b5b44")
		for mesh in warning_lamps: mesh.material_override = material(color,0.4)
		if phase_active and in_hot_zone(game.player.position): exposure += delta
		else: exposure = maxf(0,exposure-delta*2)
		if exposure>2.2 and not retreat_busy: retreat_to_refuge()
	else:
		exposure = maxf(0,exposure-delta*3)
		if game.audio.has_method("set_danger"): game.audio.set_danger(0.0)
		for mesh in warning_lamps: mesh.material_override = material(Color("4b6452"),0.2)
	if game.lock_open and game.states.get("release",false) and game.player.position.z < -29.8:
		game.audio.set_scene("void")
		game.transition_to("chamber5",1.8)

func retreat_to_refuge():
	retreat_busy = true
	exposure = 0.0
	var pos: Vector3 = game.player.position
	var side = -1.0 if pos.x<=0 else 1.0
	var safe_z = -5.0 if side<0 else -9.0
	if pos.z < -12: safe_z = -16.0 if side<0 else -20.0
	game.player.position = Vector3(side*5.0,0.08,safe_z)
	game.player.velocity = Vector3.ZERO
	game.player.reset_physics_interpolation()
	game.audio.play_cue("pressure_release")
	game.ui.announce("Горячий воздух заставляет отступить в нишу. Сначала охладитель C, затем бак.",5)
	get_tree().create_timer(1.0).timeout.connect(func(): retreat_busy=false)
