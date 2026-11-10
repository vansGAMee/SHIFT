extends RefCounted
## Story objects are separate from electrical consoles and own their ray targets.
const Art = preload("res://scripts/world_art.gd")
const Prop = preload("res://scripts/props.gd")
const TITLES = ["Фотография «Наше место»", "Детская книга", "Фотография с сестрой", "Экран наблюдения", "Рисунок на дверном стекле", "Больничный браслет", "План лабиринта", "Красная нить", "Записка о Пандоре", "Рисунок на бетоне"]

static func caption(parent: Node3D, value: String, at: Vector3, size := 0.0009, flat := false):
	var label = Prop._label(parent,value,at,size)
	label.modulate = Color("514a3e")
	label.shaded = true
	if flat: label.rotation.x = -PI/2
	return label

static func spruce(parent: Node3D, at: Vector3, scale_v := 1.0):
	var ink = Art.flat(Color("344c43"))
	Art.pipe(parent,at+Vector3(0,-0.16,0)*scale_v,at,0.006*scale_v,ink)
	for side in [-1,1]:
		var x = side*0.055
		Art.pipe(parent,at+Vector3(0,-0.04,0)*scale_v,at+Vector3(x,0.19,0)*scale_v,0.005*scale_v,ink)
		for i in range(4):
			for twig in [-1,1]:
				Art.pipe(parent,at+Vector3(x,0.16-i*0.05,0)*scale_v,at+Vector3(x+twig*(0.035+i*0.012),0.10-i*0.05,0)*scale_v,0.004*scale_v,ink)

static func picture(parent: Node3D, people := true):
	Art.box(parent,Vector3.ZERO,Vector3(0.68,0.46,0.025),Art.flat(Color("c2b796")))
	Art.box(parent,Vector3(0,0.025,0.016),Vector3(0.61,0.35,0.006),Art.flat(Color("666779")))
	Art.box(parent,Vector3(0,-0.09,0.023),Vector3(0.61,0.12,0.006),Art.flat(Color("354746")))
	spruce(parent,Vector3(-0.16,0.015,0.03),0.75)
	if people:
		for i in range(2):
			var h = 0.10+i*0.04
			var x = 0.09+i*0.10
			Art.box(parent,Vector3(x,-0.06+h*0.4,0.034),Vector3(0.055,h,0.006),Art.flat(Color("313a48")))
			Art.box(parent,Vector3(x,-0.06+h,0.034),Vector3(0.04,0.04,0.006),Art.flat(Color("ac8d72")))
	caption(parent,"НАШЕ МЕСТО",Vector3(0,-0.191,0.025),0.00065)

static func create(game: Node, level: int, at: Vector3) -> Dictionary:
	var root = Node3D.new()
	root.name = "MemoryObject"+str(level)
	root.position = at
	game.world.add_child(root)
	var surface = Art.mat("metal",Color("464b4d"))
	var paper = Art.flat(Color("c8bd9c"))
	var focus = Vector3(0,1.12,0)
	var size = Vector3(0.8,0.30,0.6)
	if level not in [9,14]:
		# Table or stool, never a misleading electrical pedestal.
		var height = 0.76 if level==7 else 0.94
		Art.box(root,Vector3(0,height,0),Vector3(1.05,0.09,0.72),surface,true)
		for x in [-0.43,0.43]:
			for z in [-0.27,0.27]: Art.box(root,Vector3(x,height*0.5,z),Vector3(0.055,height,0.055),surface)
	match level:
		5,7:
			var photo = Node3D.new()
			root.add_child(photo)
			photo.position = Vector3(0,1.10 if level==5 else 0.92,0)
			photo.rotation.x = -0.55
			picture(photo)
			focus = photo.position
			size = Vector3(0.72,0.45,0.35)
		6:
			Prop.book(root,Vector3(0,1,0))
			caption(root,"SHIFT  ○ ⇄ ●",Vector3(-0.18,1.08,0.16),0.00065,true)
			focus = Vector3(0,1.06,0)
			size = Vector3(0.76,0.15,0.56)
		8:
			Art.box(root,Vector3(0,1.3,0),Vector3(0.92,0.66,0.38),surface)
			var screen = Node3D.new()
			root.add_child(screen)
			screen.position = Vector3(0,1.33,0.2)
			picture(screen,false)
			caption(root,"11:59",Vector3(0.22,1.16,0.23),0.0007).modulate=Color("b2cbb9")
			focus = Vector3(0,1.33,0.23)
			size = Vector3(0.7,0.45,0.08)
		9:
			Art.box(root,Vector3(0,1.2,-0.08),Vector3(1.15,2.4,0.14),surface,true)
			Art.box(root,Vector3(0,1.55,0.005),Vector3(0.9,1.25,0.03),Art.flat(Color("354950")))
			for side in [-1,1]:
				Art.cylinder(root,Vector3(side*0.20,1.78,0.05),0.06,0.03,paper).rotation.x=PI/2
				Art.pipe(root,Vector3(side*0.20,1.70,0.05),Vector3(side*0.20,1.35,0.05),0.012,paper)
				for limb in [-1,1]:
					Art.pipe(root,Vector3(side*0.20,1.35,0.05),Vector3(side*0.20+limb*0.08,1.16,0.05),0.012,paper)
					Art.pipe(root,Vector3(side*0.20,1.61,0.05),Vector3(side*0.20+limb*0.10,1.44,0.05),0.012,paper)
			caption(root,"ОРФЕЙ / ЭВРИДИКА",Vector3(0,2.05,0.05),0.001).modulate=Color("b8b094")
			focus=Vector3(0,1.6,0.08)
			size=Vector3(0.85,1.1,0.08)
		10:
			var band = MeshInstance3D.new()
			var ring = TorusMesh.new()
			ring.inner_radius=0.10
			ring.outer_radius=0.14
			band.mesh=ring
			band.material_override=paper
			band.position=Vector3(0,1.04,0)
			root.add_child(band)
			Art.box(root,Vector3(0,1.055,0.12),Vector3(0.25,0.035,0.085),paper)
			caption(root,"ПАЛАТА 07",Vector3(0,1.075,0.12),0.00045,true)
			focus=Vector3(0,1.04,0.04)
			size=Vector3(0.34,0.13,0.35)
		11,13:
			Art.box(root,Vector3(0,1,0),Vector3(0.65,0.01,0.46),paper)
			if level==13: caption(root,"У ПАНДОРЫ\nОСТАЛАСЬ\nНАДЕЖДА",Vector3(0,1.01,0),0.001,true)
			else:
				var ink=Art.flat(Color("3f4852"))
				for i in range(5):
					var x=-0.25+i*0.11
					Art.box(root,Vector3(x,1.012,(-0.03 if i%2==0 else 0.04)),Vector3(0.012,0.004,0.26),ink)
					Art.box(root,Vector3(x+0.04,1.012,(-0.16 if i%2==0 else 0.17)),Vector3(0.09,0.004,0.012),ink)
				caption(root,"ВЫХОД ↑",Vector3(0,1.018,-0.20),0.00065,true)
			focus=Vector3(0,1.02,0)
			size=Vector3(0.68,0.10,0.48)
		12:
			var thread=Art.flat(Color("a34d45"))
			Art.cylinder(root,Vector3(0,1.1,0),0.13,0.2,thread)
			for y in [1.0,1.2]: Art.cylinder(root,Vector3(0,y,0),0.18,0.025,surface)
			Art.pipe(root,Vector3(0.1,1.08,0),Vector3(1,1.08,-0.4),0.012,thread)
			Art.pipe(root,Vector3(1,1.08,-0.4),Vector3(1.8,1.08,-0.4),0.012,thread)
			focus=Vector3(0,1.1,0)
			size=Vector3(0.4,0.25,0.4)
		14:
			Art.box(root,Vector3(0,0.7,0),Vector3(0.95,1.4,0.15),Art.mat("concrete",Color("87908c")),true)
			spruce(root,Vector3(0,0.8,0.09),2.5)
			focus=Vector3(0,0.8,0.12)
			size=Vector3(0.8,1.05,0.08)
	game.add_marker("secret",at+focus,size)
	Art.light(game.world,at+focus+Vector3(0,0.6,0.35),Color("b6a17e"),0.45,1.8)
	return {"node":root,"focus":focus,"title":TITLES[level-5]}
