extends Node
## Rooms 5–14. Binary SHIFT states are separate from manual preparation and
## narrative flags. Every route has physical geometry and a restart snapshot.
const Art = preload("res://scripts/world_art.gd")
const Prop = preload("res://scripts/props.gd")
const Memories = preload("res://scripts/memory_props.gd")
const TITLES = ["Нарцисс · Не то отражение","Прометей · Цена огня","Мидас · Плата за удобство","Кассандра · Завтра","Орфей · Не успел","Лета · Слова, которых не было","Дедал · Автор лабиринта","Мойры · Нельзя обменять вчера","Пандора · То, что осталось","Гефест · Сломать правило"]
const NAMES = [["projector","shutter"],["furnace","span"],["press","lift"],["monitor","span"],["beacon","span"],["archive_light","partition"],["drive","stairs"],["loom","platform"],["lamp","casket"],["relief","rupture"]]
const LABELS = [["Проектор","Ставня"],["Печь","Мост"],["Зажим","Подъёмник"],["Экран предсказания","Мост"],["Музыкальный маяк","Мост"],["Свет архива","Перегородка"],["Привод стен","Лестница"],["Станок","Платформа"],["Светильник","Замок шкатулки"],["Отвод давления","Контур у стены"]]
const STATES = [["погашен","светит"],["закрыта","открыта"],["выключена","работает"],["убран","разложен"],["разжат","сжат"],["остановлен","активен"]]
const BEAT_IDS = ["sisterIntroduced","shiftOriginKnown","illnessKnown","promiseHeard","emptyWard","lossConfirmed","labyrinthKnown","regretHeard","secondRevealed"]
const SECRETS = ["На фото: «Наше место». Та же раздвоенная ель.","На полях книги: два кружка и детское слово SHIFT.","Фотография на табурете. Вы с сестрой на горе.","На экране — гора. Секундная стрелка почти не движется.","На дверном стекле — Орфей и Эвридика. Рисунок из вашей книги.","Больничный браслет сестры. Всё то время я говорил: «позже».","План лабиринта. Узнаваемый почерк сестры.","Красная нить уходит в стену. За ней слышен ветер.","«А у Пандоры осталось что?» — «Надежда».","На обороте бетонной стены — детский рисунок ели."]
var game: Node
var level := 5
var manual: Dictionary = {}
var parts: Dictionary = {}
var lamps: Array[Light3D] = []
var floor_path: Node3D
var path_shapes: Array[CollisionShape3D] = []
var wall_shapes: Array[CollisionShape3D] = []
var fragments: Array[MeshInstance3D] = []
var second: Node3D
var memory: Node3D
var state_text: Label3D
var room_time := 0.0
var solved := false
var beat_started := false
var beat_done := false
var chase := false
var chase_delay := 0.0
var chase_step := 0.0
var caught := false
var blast_clock := -1.0
var wall_broken := false
var phase_locked := false
var phase_open := false
var preview_time := 0.0
var posture := 0.0
var path_active := false
var vision_clock := -1.0

func box(pos: Vector3, size: Vector3, mat: Material, solid := false, parent: Node3D = null) -> MeshInstance3D:
	return Art.box(parent if parent else game.world,pos,size,mat,solid)

func text(value: String, pos: Vector3, scale_v := 0.005, color := Color("c4c7bf"), parent: Node3D = null) -> Label3D:
	var label = Label3D.new()
	label.text = value
	label.font = preload("res://assets/fonts/mono.ttf")
	label.font_size = 32
	label.pixel_size = scale_v
	label.position = pos
	label.modulate = color
	label.outline_size = 0
	(parent if parent else game.world).add_child(label)
	return label

func build(which: int):
	level = which
	var ids = NAMES[level-5]
	game.states = {ids[0]:true,ids[1]:false}
	base_room()
	var source_at = Vector3(-4,0,-6)
	var sink_at = Vector3(3.6,0,-8)
	if level==13: sink_at = Vector3(2.5,0,-10)
	if level==14: source_at=Vector3(-4,0,-9); sink_at=Vector3(4,0,-9)
	game.add_device(ids[0],"generator",source_at)
	game.add_device(ids[1],"door_console",sink_at)
	Art.light(game.world,source_at+Vector3(0,2.1,0.7),Color("81bcb4"),1.1,4.5)
	Art.light(game.world,sink_at+Vector3(0,2.1,0.7),Color("ba9c7c"),0.9,4.5)
	for i in range(2):
		text(LABELS[level-5][i],(source_at if i==0 else sink_at)+Vector3(0,1.85,0.05),0.0045)
	if level!=14:
		game.create_door("route",-22)
		text("%02d / %s" % [level,TITLES[level-5].to_upper()],Vector3(0,3.8,-21.7),0.006)
	state_text = text("",Vector3(0,2.8,-7.4),0.0047)
	match level:
		5: build_mirrors()
		6: build_furnace()
		7: build_midas()
		8: build_cassandra()
		9: build_orpheus()
		10: build_lethe()
		11: build_daedalus()
		12: build_moirai()
		13: build_pandora()
		14: build_hephaestus()
	add_secret()
	second = silhouette(game.world,Vector3(0,0,1.5),1.0)
	second.hide()
	game.narrative.finished.connect(on_memory_finished)
	game.narrative.line_changed.connect(on_memory_line)
	game.ui.chapter_title("%02d  ·  %s" % [level,TITLES[level-5]])
	game.ui.announce(goal_text(),6)
	if level==13 and game.has_ammo:
		game.states.lamp = false
		game.states.casket = true
		game.used_shift = true
		manual["path"] = true
		beat_done = game.narrative.flags.get("secondRevealed",false)
		beat_started = beat_done
	after_shift()

func base_room():
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("080b11")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("7a8eab")
	env.ambient_light_energy = 0.085
	env.fog_enabled = true
	env.fog_density = 0.016
	env.fog_light_color = Color("111921")
	var environment = WorldEnvironment.new()
	environment.environment = env
	game.world.add_child(environment)
	var wall = Art.mat("concrete",Color("83898d"),0.7)
	var steel = Art.mat("metal",Color("454c50"),0.7)
	var ground = Art.mat("floor",Color("7c8382"),0.6)
	var width = 9.0 if level==14 else 7.0
	var has_pit = level in [6,7,8,9,11,12]
	if has_pit:
		box(Vector3(0,-0.2,-2.5),Vector3(width*2,0.4,17),ground,true)
		box(Vector3(0,-0.2,-20),Vector3(width*2,0.4,10),ground,true)
		box(Vector3(0,-3.8,-13),Vector3(width*2,0.4,4),Art.flat(Color("070c10")),true)
	else: box(Vector3(0,-0.2,-9.5),Vector3(width*2,0.4,31),ground,true)
	box(Vector3(0,5.1,-9),Vector3(width*2+0.4,0.3,30),steel)
	box(Vector3(0,2.5,5.7),Vector3(width*2+0.4,5,0.4),wall,true)
	for s in [-1,1]:
		box(Vector3(s*(width+0.2),2.5,-9.5),Vector3(0.4,5,31),wall,true)
		box(Vector3(s*(width+1.5)*0.5,2.5,-22.2),Vector3(width-1.5,5,0.4),wall,true)
		Art.pipe(game.world,Vector3(s*(width-0.3),4,4),Vector3(s*(width-0.3),4,-22),0.09,steel)
		box(Vector3(s*1.36,0.015,-9),Vector3(0.05,0.02,28),Art.flat(Color("7b9687"),0.12))
	box(Vector3(0,4.25,-22.2),Vector3(3,1.5,0.4),wall,true)
	box(Vector3(0,-0.2,-26),Vector3(3,0.4,10),ground,true)
	for s in [-1,1]: box(Vector3(s*1.7,2,-26),Vector3(0.4,4,10),Art.flat(Color("080b12")),true)
	for z in [0,-8,-18]:
		box(Vector3(0,4.8,z),Vector3(width*2,0.3,0.3),steel)
		box(Vector3(-2.3,4.65,z),Vector3(2.2,0.1,0.45),Art.flat(Color("93b6b7"),0.65))
		lamps.append(Art.downlight(game.world,Vector3(-2.3,4.25,z),Color("adcdd6"),0.72,9))
	Art.service_beacon(game.world,Vector3(width-1.0,3.5,-21.85))
	# Repeated, almost still clock. It never becomes a puzzle or a required clue.
	box(Vector3(5,3.2,-21.9),Vector3(0.85,0.85,0.12),Art.flat(Color("253339")))
	text("11:59",Vector3(5,3.2,-21.8),0.004,Color("a0ad9a"))

func control(id: String, at: Vector3, caption: String):
	game.add_device(id,"source",at)
	manual[id] = false
	game.devices[id].lamp.material_override = Art.flat(Color("85765b"))
	text(caption,at+Vector3(0,1.9,0.03),0.0042,Color("d2b583"))

func build_path(bent := false):
	floor_path = Node3D.new()
	game.world.add_child(floor_path)
	if level==11:
		# Folded stair sections share continuous ramp colliders: no jump or tiny step.
		for i in range(2):
			var ramp=box(Vector3(0,0.2,-11.6-i*2.2),Vector3(2.7,0.15,2.27),Art.mat("metal",Color("71817a")),true,floor_path)
			ramp.rotation.x=0.245 if i==0 else -0.245
			path_shapes.append(ramp.get_child(0).get_child(0))
		for i in range(8):
			var h=(i if i<4 else 7-i)*0.13
			box(Vector3(0,h+0.02,-10.65-i*0.56),Vector3(2.7,0.12,0.55),Art.flat(Color("8a8b72")),false,floor_path)
		floor_path.position.y=-3
		return
	if level in [7,12]:
		var deck=box(Vector3(0,-0.11,-13),Vector3(2.9,0.22,4.6),Art.mat("metal",Color("727e75")),true,floor_path)
		path_shapes.append(deck.get_child(0).get_child(0))
		for side in [-1,1]:
			for z in [-10.8,-15.2]:
				Art.pipe(floor_path,Vector3(side*1.4,0,z),Vector3(side*1.4,4.3,z),0.04,Art.flat(Color("a29d86")))
		floor_path.position.y=-3
		return
	for i in range(3):
		var x = (-0.7 if i==1 else 0.0) if bent else 0.0
		var z = -11.45-i*1.35
		var slab = box(Vector3(x,-0.11,z),Vector3(2.7,0.22,1.65),Art.mat("metal",Color("627b78")),true,floor_path)
		path_shapes.append(slab.get_child(0).get_child(0))
		for side in [-1,1]:
			Art.pipe(floor_path,Vector3(x+side*1.25,0.1,z-0.75),Vector3(x+side*1.25,0.9,z-0.75),0.035,Art.flat(Color("82988a")))
			Art.pipe(floor_path,Vector3(x+side*1.25,0.9,z-0.75),Vector3(x+side*1.25,0.9,z+0.75),0.035,Art.flat(Color("82988a")))
	floor_path.position.y = -3

func build_mirrors():
	for x in [-4.8,0,4.8]:
		box(Vector3(x,2.3,-18.7),Vector3(3.3,3.6,0.22),Art.mat("metal",Color("8a9fa5")),true)
		box(Vector3(x,2.3,-18.55),Vector3(3,3.3,0.02),Art.flat(Color("152732"),0.15))
	parts.frame = box(Vector3(0,1.5,-8.7),Vector3(3.3,3,0.25),Art.mat("metal",Color("526873")),true)
	control("frame",Vector3(-2.6,0,-7.5),"РАМКА А / Б")
	text("Поверните рамку.\nВ отражении — не настоящее.",Vector3(0,3.8,-8.4),0.005)
	memory = memory_picture(Vector3(0,0,-18.3))
	memory.hide()

func build_furnace():
	build_path()
	box(Vector3(-5,1.7,-10),Vector3(3,3.4,3),Art.mat("metal",Color("554e4a")),true)
	parts.fire = box(Vector3(-5,1.5,-8.4),Vector3(2.4,1.8,0.02),Art.flat(Color("d1743d"),1.2))
	parts.heat = Art.light(game.world,Vector3(-4,2.5,-8),Color("d67943"),2.0,8)
	for x in [-5.8,-4.2]:
		for y in range(9): Art.cylinder(game.world,Vector3(x,3+y*0.2,-9),0.075,0.16,Art.flat(Color("333b40")))
	control("screen",Vector3(3.7,0,-5),"ЗАЩИТНЫЙ ЭКРАН")
	parts.screen = box(Vector3(-3.2,2.7,-9.7),Vector3(0.15,1.8,3),Art.flat(Color("697579")))
	text("Сначала закройте экран.\nПар скроет мост, но не причинит вреда.",Vector3(0,3.6,-10.7),0.0045)
	parts.steam = box(Vector3(0,1.5,-12.5),Vector3(3,2.8,0.05),Art.flat(Color(0.38,0.45,0.48,0.22)))
	parts.steam.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	parts.steam.hide()
	text("●   ⇄   ○",Vector3(0,2.6,-20),0.018,Color("c4b58f"))
	text("НАША ИГРА",Vector3(0,1.7,-20),0.006,Color("a1a78c"))

func build_midas():
	build_path()
	for s in [-1,1]:
		box(Vector3(s*5,2.5,-7),Vector3(2.4,4,0.2),Art.mat("metal",Color("a08b4b")))
		for finger in range(5): box(Vector3(s*5-0.6+finger*0.3,2.9,-6.82),Vector3(0.18,0.7+0.18*sin(finger),0.08),Art.flat(Color("b8a464")))
	control("cargo",Vector3(3.5,0,-5),"ЯЩИК → НИША")
	parts.cargo = box(Vector3(0,0.5,-9),Vector3(1.1,1,1.1),Art.mat("metal",Color("a68c53")),true)
	box(Vector3(2.7,0.025,-9),Vector3(1.5,0.05,1.5),Art.flat(Color("b8ad69"),0.2))
	text("Ящик удержит свободный путь.\nСдвиньте его в светлую нишу.",Vector3(0,3.7,-9.5),0.0048)
	for side in [-1,1]:
		parts["clamp_"+str(side)]=box(Vector3(side*1.8,1.1,-12.5),Vector3(0.35,2.2,0.8),Art.mat("metal",Color("ab9151")))
	ward(Vector3(-4.7,0,-18))

func build_cassandra():
	build_path(true)
	control("preview",Vector3(-2,0,-5),"СМОТРЕТЬ СХЕМУ")
	box(Vector3(-3.7,2.6,-6.3),Vector3(3.4,2.2,0.4),Art.flat(Color("252e38")))
	parts.preview = text("I ━┓\n   II ━┓\n       III ━ ВЫХОД",Vector3(-3.7,2.6,-6.05),0.006,Color("8bd4ba"))
	for x in [2,4]: box(Vector3(x,2.2,-19),Vector3(1.5,1.3,0.2),Art.flat(Color("14252b"),0.1))
	phone(Vector3(0,0,-18))
	text("Схему можно повторить.\nПоручни останутся, когда экран погаснет.",Vector3(0,3.8,-9),0.0048)

func build_orpheus():
	build_path(true)
	control("listen",Vector3(-2,0,-5),"СЛУШАТЬ МАЯК")
	for i in range(6):
		box(Vector3(-1.15,0.06,-10.5-i),Vector3(0.1,0.1,0.3),Art.flat(Color("a4c4ab"),0.6))
	ward(Vector3(0,0,-18))
	text("ПАЛАТА  /  ТИХО",Vector3(0,3.4,-17),0.005)
	text("Маяк погаснет. Держитесь поручня.",Vector3(0,3.8,-9),0.0048)
	parts.behind = box(Vector3(0,2,4.6),Vector3(3.3,4,0.3),Art.flat(Color("28383c")),true)
	parts.behind.hide()
	parts.behind.get_child(0).get_child(0).disabled = true

func build_lethe():
	for side in [-1,1]:
		var id = "rack_a" if side==-1 else "rack_b"
		control(id,Vector3(side*5,0,-6.5),"РЯД "+("А" if side==-1 else "Б"))
		var rack = Node3D.new()
		rack.position = Vector3(side*2.4,0,-11)
		game.world.add_child(rack)
		for h in [0.15,0.9,1.65,2.4]: box(Vector3(0,h,0),Vector3(4.7,0.1,1.1),Art.mat("metal",Color("57616a")),true,rack)
		for x in [-2.2,2.2]: box(Vector3(x,1.3,0),Vector3(0.12,2.7,1.1),Art.flat(Color("2d404a")),true,rack)
		parts[id] = rack
		for j in range(10): box(Vector3(-1.9+j*0.4,1.15,0),Vector3(0.25,0.4,0.7),Art.flat(Color("8c8975")),false,rack)
	box(Vector3(0,0.025,-9),Vector3(13,0.02,24),Art.flat(Color("18333c")))
	for z in [-7,-10,-13]: box(Vector3(0,0.05,z),Vector3(1.1,0.02,0.15),Art.flat(Color("aac1a9"),0.15))
	box(Vector3(0,0.45,-19),Vector3(3.2,0.15,0.8),Art.flat(Color("596268")),true)
	book(Vector3(0.5,0.57,-19))
	text("Оба ряда — по меткам вдоль прохода.",Vector3(0,3.7,-9),0.0048)

func build_daedalus():
	build_path()
	control("phase",Vector3(3.8,0,-5),"ЗАФИКСИРОВАТЬ ПРОХОД")
	for side in [-1,1]:
		parts["moving_"+str(side)] = box(Vector3(side*1.6,1.8,-9.5),Vector3(3,3.6,0.4),Art.mat("concrete",Color("7a7771")),true)
	box(Vector3(1.5,4.94,-15),Vector3(4,0.01,0.8),Art.flat(Color("ca8c7d"),0.7))
	text("Когда стены разойдутся, удержите рычаг.\nSHIFT остановит привод и разложит лестницу.",Vector3(0,3.9,-8.8),0.0048)
	for z in range(8):
		box(Vector3(-5.7,0.07,-13-z*0.6),Vector3(1.4,0.05,0.04),Art.flat(Color("c3b68a")))
	book(Vector3(3,0.12,-18))
	parts.pages=Node3D.new()
	game.world.add_child(parts.pages)
	box(Vector3(0,2.4,-21.6),Vector3(12,4.5,0.02),Art.flat(Color("b6aa8b"),0.12),false,parts.pages)
	text("НАША ИГРА  /  SHIFT",Vector3(0,3.8,-21.55),0.012,Color("55584d"),parts.pages)
	text("Два состояния. Один обмен.\n\nА что, если исправить миф?\n\nНарцисс  ·  Прометей  ·  Мидас\nКассандра  ·  Орфей  ·  Лета\nДедал  ·  Мойры  ·  Пандора  ·  Гефест",Vector3(0,2,-21.55),0.006,Color("55584d"),parts.pages)
	parts.pages.hide()

func build_moirai():
	build_path()
	control("thread",Vector3(3.8,0,-5),"НИТЬ → ВЕРХНИЙ ПАЗ")
	for x in [-4,0,4]:
		var spool = Art.cylinder(game.world,Vector3(x,3.5,-9),0.8,0.8,Art.mat("metal",Color("6e686b")),0.8,12)
		spool.rotation.z=PI*0.5
		Art.pipe(game.world,Vector3(x,3.5,-9),Vector3(x,0.2,-17),0.025,Art.flat(Color("b1b5a1")))
		text("│",Vector3(x,2.8,-21.8),0.035,Color("333847"))
	parts.thread = box(Vector3(2.8,1.2,-8),Vector3(1.1,0.09,0.09),Art.flat(Color("c77765"),0.5))
	box(Vector3(2.8,2.5,-8),Vector3(1.3,0.07,0.12),Art.flat(Color("cfba92"),0.3))
	phone(Vector3(0,0,-18))
	text("Верхний паз удержит трос.\nПосле обмена станок остановится.",Vector3(0,3.9,-8.8),0.0048)

func build_pandora():
	control("path",Vector3(3.6,0,-5),"ОСМОТРЕТЬ ЛИНИЮ К ШЛЮЗУ")
	box(Vector3(0,0.5,-10),Vector3(1.7,1,1.2),Art.mat("concrete",Color("83837a")),true)
	box(Vector3(0,1.2,-10),Vector3(1.1,0.4,0.75),Art.mat("metal",Color("746955")))
	parts.lid = Node3D.new()
	parts.lid.position = Vector3(0,1.43,-10.35)
	game.world.add_child(parts.lid)
	box(Vector3(0,0,0.35),Vector3(1.18,0.1,0.8),Art.mat("metal",Color("887d69")),false,parts.lid)
	game.add_device("pandora_ammo","ammo",Vector3(0,1.26,-10))
	game.devices.pandora_ammo.node.hide()
	text("Свет погаснет. Линия останется.",Vector3(0,3.5,-9.8),0.0048)

func build_hephaestus():
	control("shelter",Vector3(5,0,-5),"ОСМОТРЕТЬ УКРЫТИЕ")
	text("14 / ГЕФЕСТ  ·  СЛОМАТЬ ПРАВИЛО",Vector3(0,4.2,-21.7),0.007)
	text("ДВЕРЬ НЕ ВЕДЁТ НАРУЖУ",Vector3(-5,2.6,-21.7),0.0045,Color("b38772"))
	box(Vector3(-5,1.5,-21.9),Vector3(2.2,3,0.2),Art.mat("metal",Color("41494c")),true)
	text("ВЫХОД ↑",Vector3(-5,3.3,-21.7),0.0045)
	box(Vector3(5,0.5,-5.5),Vector3(3.8,1,0.4),Art.mat("metal",Color("606e73")),true)
	for side in [-1,1]:
		for y in [1.8,3.1]:
			Art.pipe(game.world,Vector3(side*7,y,2),Vector3(side*7,y,-20),0.3,Art.mat("metal",Color("574e47")))
			Art.pipe(game.world,Vector3(side*7,y,-20),Vector3(side*1.5,y,-21.7),0.22,Art.flat(Color("6b6254")))
	for x in range(5):
		for y in range(4):
			var f = box(Vector3(-1.2+x*0.6,0.45+y*0.9,-22),Vector3(0.59,0.87,0.48),Art.mat("concrete",Color("8f8880")),true)
			fragments.append(f)
			wall_shapes.append(f.get_child(0).get_child(0))
	for i in range(7):
		var crack=box(Vector3(-1.1+i*0.35,1.3+sin(i)*0.8,-21.74),Vector3(0.035,0.8,0.015),Art.flat(Color("bd9b74"),0.6))
		crack.rotation.z=sin(i*2)*0.7
	text("Трубы сходятся у треснувшей стены.\nОсмотрите укрытие. Обменяйте два контура.",Vector3(0,3.3,-8),0.0048)

func book(at: Vector3):
	Prop.book(game.world,at)

func phone(at: Vector3):
	box(at+Vector3(0,0.4,0),Vector3(1.2,0.8,0.65),Art.flat(Color("484f52")),true)
	var shell=Art.flat(Color("818a82"))
	var dark=Art.flat(Color("242c32"))
	box(at+Vector3(0,0.89,0),Vector3(0.48,0.15,0.36),shell)
	for x in [-0.17,0.17]: box(at+Vector3(x,1.03,-0.09),Vector3(0.13,0.1,0.16),dark)
	box(at+Vector3(0,1.065,-0.09),Vector3(0.32,0.055,0.09),dark)
	for x in range(3):
		for z in range(3): box(at+Vector3(-0.06+x*0.06,0.976,0.02+z*0.045),Vector3(0.04,0.015,0.03),dark)
	for i in range(8): Art.pipe(game.world,at+Vector3(-0.22,0.99-i*0.035,-0.1+sin(i)*0.025),at+Vector3(-0.22,0.955-i*0.035,-0.1+sin(i+1)*0.025),0.008,dark)

func ward(at: Vector3):
	box(at+Vector3(0,0.65,0),Vector3(1.6,0.15,2.3),Art.flat(Color("9bafa9")),true)
	box(at+Vector3(0,0.78,-0.75),Vector3(1.25,0.18,0.5),Art.flat(Color("c0c7b9")))
	for s in [-1,1]: Art.pipe(game.world,at+Vector3(s*0.8,0,-1),at+Vector3(s*0.8,1.4,-1),0.04,Art.flat(Color("657b80")))
	box(at+Vector3(1.5,1.5,0),Vector3(0.05,3,2.5),Art.flat(Color("839a94")))
	book(at+Vector3(-1.2,0.4,0.3))

func silhouette(parent: Node3D, at: Vector3, height: float) -> Node3D:
	var root = Node3D.new()
	parent.add_child(root)
	root.position = at
	root.scale = Vector3.ONE*height
	var sleeve = Prop._mat("sleeve_charcoal",Color("252b2c"))
	box(Vector3(0,1.12,0),Vector3(0.54,0.7,0.3),sleeve,false,root)
	box(Vector3(0,1.65,0),Vector3(0.31,0.38,0.3),Art.flat(Color("151e26")),false,root)
	for s in [-1,1]:
		box(Vector3(s*0.15,0.43,0),Vector3(0.21,0.77,0.27),Prop._mat("sleeve_trousers",Color("323638")),false,root)
		box(Vector3(s*0.36,1.02,0),Vector3(0.18,0.72,0.24),sleeve,false,root)
		box(Vector3(s*0.36,0.62,0),Vector3(0.15,0.18,0.18),Prop._mat("skin",Color("b49d85")),false,root)
	return root

func memory_picture(at: Vector3) -> Node3D:
	var root=Node3D.new()
	game.world.add_child(root)
	root.position=at
	box(Vector3(0,1.9,-0.1),Vector3(3,3,0.01),Art.flat(Color("654e62"),0.2),false,root)
	for i in range(4):
		var crown = Art.cylinder(root,Vector3(-0.8,1.4+i*0.4,0),0.75-i*0.14,0.9,Art.flat(Color("243b3c")),0,6)
		crown.rotation.z=0.07
	box(Vector3(-0.8,0.7,0),Vector3(0.12,1.3,0.1),Art.flat(Color("927361")),false,root)
	silhouette(root,Vector3(0.2,0,0.1),0.62)
	silhouette(root,Vector3(1,0,0.1),0.93)
	book(at+Vector3(0.6,0.6,0.3))
	return root

func add_secret():
	var at=Vector3(5.2,0,-18.5) if level!=14 else Vector3(2.3,0,-20)
	game.devices["secret"]=Memories.create(game,level,at)

func goal_text() -> String:
	return ["Повернуть рамку. Открыть ставню единственным обменом.","Закрыть защитный экран. Обменять состояния печи и моста.","Поставить ящик в нишу. Освободить подъёмник.","Просмотреть схему. Затем обменять экран и мост.","Прослушать маяк. Погасить его, чтобы разложить мост.","Повернуть оба ряда по меткам. Обменять свет и перегородку.","Зафиксировать открытый проход. Обменять привод и лестницу.","Закрепить нить в верхнем пазу. Обменять станок и платформу.","Осмотреть путь. Обменять свет и замок шкатулки.","Выход за стеной. Осмотреть укрытие и обменять два контура."][level-5]

func prepared() -> bool:
	match level:
		5: return manual.frame
		6: return true # Steam is a readable, safe consequence of missing preparation.
		7: return manual.cargo
		8: return manual.preview
		9: return manual.listen
		10: return manual.rack_a and manual.rack_b
		11: return manual.phase and phase_locked
		12: return manual.thread
		13: return manual.path
		14: return manual.shelter
	return false

func after_shift():
	var ids = NAMES[level-5]
	solved = game.used_shift and not game.states[ids[0]] and game.states[ids[1]] and prepared()
	if level!=14: game.set_door("route",solved and (level!=13 or game.has_ammo))
	if floor_path:
		if solved and not path_active:
			create_tween().set_trans(Tween.TRANS_SINE).tween_property(floor_path,"position:y",0.0,1.0)
		elif not solved: floor_path.position.y=-3
		path_active=solved
		for c in path_shapes: c.set_deferred("disabled",not solved)
	if level==5 and memory: memory.visible=solved
	if level==6:
		parts.fire.visible=game.states.furnace
		parts.heat.light_energy=0.8 if game.states.furnace else 0.05
		parts.steam.visible=solved and not manual.screen
	if level==7:
		for side in [-1,1]: parts["clamp_"+str(side)].rotation.z=side*1.1 if solved else 0.0
	if level==8: parts.preview.visible=game.states.monitor
	if level==13:
		parts.lid.rotation.x=-1.4 if game.states.casket else 0
		game.devices.pandora_ammo.node.visible=solved and not game.has_ammo
	if level==14 and solved and blast_clock<0 and not wall_broken:
		blast_clock=0
		game.audio.play_cue("pressure_warning")
		game.ui.announce("Стена дрожит. Отойдите к укрытию. Скоро появится проход.",6)
	if game.used_shift and not solved:
		game.ui.announce("Состояния обменялись, но путь не подготовлен. R — повторить комнату.",5)
	state_text.text = "СВЯЗИ РАЗОМКНУТЫ · состояния удерживаются" if solved else "Сначала подготовьте путь · E — ручное действие"
	if solved:
		for lamp in lamps: lamp.light_color=Color("728fab")

func interact(id: String) -> bool:
	if id=="secret":
		if game.distance_to(id)<2.5: game.narrative.find_secret(str(level),SECRETS[level-5])
		return true
	if id=="pandora_ammo":
		if solved and not game.has_ammo and game.distance_to(id)<2.5:
			game.has_ammo=true
			game.audio.play_cue("pickup")
			game.ui.announce("Один патрон. Тот же холодный металл, что в траве под елью.",5)
			after_shift()
			game.save_progress()
		return true
	if id not in manual: return false
	if game.distance_to(id)>2.5: return true
	if game.used_shift and id!="screen":
		game.ui.announce("После SHIFT положения удерживаются. R — повторить комнату.",3)
		return true
	if id=="phase" and not phase_open:
		game.ui.announce("Подождите, пока стены разойдутся. Рычаг удержит открытый проход.",4)
		return true
	manual[id]=not manual[id]
	game.audio.play_cue("lever")
	match id:
		"frame": parts.frame.rotation.y=PI*0.5 if manual.frame else 0
		"screen": parts.screen.position.y=1.4 if manual.screen else 2.7
		"cargo": parts.cargo.position.x=2.7 if manual.cargo else 0
		"preview":
			manual.preview=true
			preview_time=3
			game.ui.announce("Схема: первый пролёт — влево — к дальней двери. Поручень непрерывен.",4)
		"listen":
			manual.listen=true
			game.audio.play_cue("memory")
			game.ui.announce("Три ноты. Световая дорожка повторяет изгиб поручня.",4)
		"rack_a","rack_b": parts[id].rotation.y=PI*0.5 if manual[id] else 0
		"phase": phase_locked=manual.phase
		"thread": parts.thread.position.y=2.5 if manual.thread else 1.2
		"path": game.ui.announce("Светлая линия ведёт от шкатулки прямо к шлюзу.",4)
		"shelter": game.ui.announce("За ограждением видно всю стену. Трубы уходят в её трещины.",4)
	game.devices[id].lamp.material_override=Art.flat(Color("b1b99a") if manual[id] else Color("85765b"),0.2)
	after_shift()
	return true

func prompt_for(id: String) -> String:
	if id=="secret": return game.devices.secret.title+"\nE — рассмотреть" if game.distance_to(id)<2.5 else game.devices.secret.title
	if id=="pandora_ammo": return "Один патрон\nE — забрать" if solved and not game.has_ammo else ""
	if id in manual:
		return "Ручной механизм · "+("установлен" if manual[id] else "исходное положение")+"\n"+("E — осмотреть" if id in ["path","shelter","preview","listen"] else "E — перевести") if game.distance_to(id)<2.5 else "Ручной механизм · подойдите ближе"
	return ""

func get_item_name(id: String) -> String:
	var ids=NAMES[level-5]
	return "Пульт: "+LABELS[level-5][ids.find(id)] if id in ids else ""

func state_label(id: String) -> String:
	var active: bool=game.states.get(id,false)
	var descriptions={"projector":["погашен","светит"],"shutter":["закрыта","открыта"],"furnace":["выключена","работает"],"span":["убран","разложен"],"press":["разжат","сжат"],"lift":["остановлен","поднят"],"monitor":["погашен","показывает схему"],"beacon":["погашен","звучит"],"archive_light":["погашен","включён"],"partition":["закрыта","открыта"],"drive":["остановлен","работает"],"stairs":["сложена","разложена"],"loom":["остановлен","тянет нить"],"platform":["опущена","поднята"],"lamp":["погашен","горит"],"casket":["заперт","отперт"],"relief":["неактивен","активен"],"rupture":["неактивен","активен"]}
	return descriptions.get(id,["выключено","включено"])[1 if active else 0]

func process_level(delta: float):
	if game.ui.settings.visible: return
	room_time+=delta
	if vision_clock>0:
		vision_clock-=delta
		if vision_clock<=0: game.ui.mountain_memory.hide()
	if level==13 and game.story_active and posture<0:
		second.rotation.x=move_toward(second.rotation.x,posture,delta*0.5)
	if game.story_active: return
	for i in range(lamps.size()):
		var breath=0.83+0.12*sin(room_time*0.7+i*1.9)
		lamps[i].light_energy=breath*(0.5 if solved else 0.72)
	if level==11 and not phase_locked:
		phase_open=fmod(room_time,7.0)>3.0
		for side in [-1,1]: parts["moving_"+str(side)].position.x=side*(4.3 if phase_open else 1.6)
		state_text.text="ПРОХОД ОТКРЫТ · зафиксируйте рычаг" if phase_open else "ПРОХОД ЗАКРЫТ · дождитесь движения стен"
	if preview_time>0:
		preview_time-=delta
		parts.preview.modulate=Color("dcdfad") if int(preview_time*2)%2==0 else Color("8bd4ba")
	if level==14 and not wall_broken:
		chase_step+=delta
		if chase_step>1.7 and room_time>5:
			chase_step=0
			game.audio.play_cue("second_step")
	if not solved: return
	if level==14:
		process_blast(delta)
		if wall_broken and game.player.position.z<-25: game.transition_to("finale",3.2)
		return
	if not beat_started and game.player.position.z<-15.8 and (level!=13 or game.has_ammo):
		start_memory()
	if level==13 and chase: process_chase(delta)
	if beat_done and game.player.position.z<-23.5:
		game.transition_to("chamber"+str(level+1),1.5)

func start_memory():
	beat_started=true
	if level==13: game.audio.cut_music(8.0)
	var focus=Vector3(0,1.6,-20)
	if level==7: focus=Vector3(-4.7,1,-18)
	if level in [8,12]: focus=Vector3(0,0.9,-18)
	var direction: Vector3=(focus-game.camera.global_position).normalized()
	game.memory_yaw=atan2(-direction.x,-direction.z)
	game.memory_pitch=asin(direction.y)
	if level==11: parts.pages.show()
	if level in [7,8,9,10,11,12,13]:
		second.position=Vector3(0,0,-19.4)
		if level==7: second.position=Vector3(4.4,0,-19)
		if level==8: second.position=Vector3(3.5,0,-20)
		if level==9: second.position=Vector3(0,0,-12.5)
		if level in [11,12]: second.position=Vector3(-4,0,-19)
		second.visible=true
	if level==8: game.audio.play_cue("ring")
	if level==9:
		parts.behind.show()
		parts.behind.get_child(0).get_child(0).set_deferred("disabled",false)
	if level==12:
		game.audio.play_cue("door")
		box(Vector3(-5,1.6,-15.8),Vector3(2,3.2,0.25),Art.flat(Color("2c373d")),true)
	game.narrative.play(BEAT_IDS[level-5])

func on_memory_finished(id: String):
	if level>13 or id!=BEAT_IDS[level-5]: return
	beat_done=true
	if level==13:
		posture=0
		second.rotation=Vector3.ZERO
		second.position=Vector3(0,0,-8)
		second.show()
		chase_delay=3.0
		chase=not game.no_chase
		game.ui.announce("Шлюз впереди открыт. За спиной — ваши собственные шаги.",5)
	elif level in [6,7,8,9,10,11,12]:
		game.audio.play_cue("second_step")
		second.hide()
		if level==8:
			game.audio.play_cue("power_drop")
			lamps.back().hide()
	if memory: memory.hide()
	if level==11: parts.pages.hide()
	game.save_progress()

func process_chase(delta: float):
	if game.no_chase or not game.selected.is_empty(): return
	chase_delay-=delta
	if chase_delay>0: return
	var direction: Vector3=game.player.position-second.position
	direction.y=0
	second.position+=direction.normalized()*delta*0.85
	chase_step+=delta
	if chase_step>0.85:
		chase_step=0
		game.audio.play_cue("second_step")
	if direction.length()<0.8:
		chase=false
		caught=true
		second.hide()
		game.player.position=Vector3(0,0.08,-18)
		game.player.velocity=Vector3.ZERO
		game.player.reset_physics_interpolation()
		game.ui.shift_flash()
		game.ui.announce("Снова здесь. Шкатулка открыта. Путь вперёд остался.",5)

func process_blast(delta: float):
	if wall_broken: return
	blast_clock+=delta
	game.audio.set_danger(minf(0.8,blast_clock/10))
	for lamp in lamps: lamp.light_color=Color("b66a54")
	if blast_clock<6.5: return
	wall_broken=true
	game.narrative.flags.wallBroken=true
	game.audio.play_cue("wall_break")
	game.audio.reveal_wind()
	game.ui.shift_flash()
	for c in wall_shapes: c.set_deferred("disabled",true)
	for i in range(fragments.size()):
		var f=fragments[i]
		var t=create_tween().set_parallel()
		t.tween_property(f,"position",f.position+Vector3((-1 if i%2==0 else 1)*(2.4+i%3),-3.5,-1.6),1.0+(i%4)*0.15)
		t.tween_property(f,"rotation",Vector3(i*0.2,i*0.3,i*0.1),1.5)
	var rng=RandomNumberGenerator.new()
	rng.seed=1414
	for i in range(14):
		var dust_mat=Art.flat(Color(0.39,0.4,0.41,0.25))
		dust_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		dust_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		var dust=Art.cylinder(game.world,Vector3(rng.randf_range(-1.4,1.4),rng.randf_range(.2,3.5),-21.6),0.35,0.6,dust_mat,0.2,6)
		var puff=create_tween().set_parallel()
		puff.tween_property(dust,"scale",Vector3.ONE*3,2.3)
		puff.tween_property(dust,"position",dust.position+Vector3(rng.randf_range(-1,1),0.8,1),2.3)
		puff.tween_property(dust_mat,"albedo_color:a",0.0,2.3)
	game.ui.announce("Стена исчезла. За проломом — ветер. Идите.",6)
	game.save_progress()

func on_memory_line(id: String,line_index: int):
	if id=="secondRevealed":
		if line_index==1:
			posture=-0.75
		if line_index==2:
			game.ui.mountain_memory.show()
			vision_clock=2.5 if game.reduced_flashes else 0.65
			game.audio.reveal_wind()
		if line_index==3: game.ui.mountain_memory.hide()
