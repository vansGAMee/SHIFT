class_name Props
extends RefCounted

# Small, deliberately faceted props. All art is generated here; no external model files.
static var _materials: Dictionary = {}

static func book(parent: Node3D, at: Vector3) -> Node3D:
	var root = Node3D.new()
	root.name = "ChildhoodBook"
	root.position = at
	parent.add_child(root)
	var cover = _mat("book_cloth",Color("633b35"))
	var paper = _mat("book_paper",Color("e5d5ad"))
	var edge = _mat("book_edges",Color("ac9977"))
	_box(root,Vector3(0,0.01,0),Vector3(0.045,0.065,0.52),cover)
	for side in [-1,1]:
		var leaf = Node3D.new()
		root.add_child(leaf)
		leaf.rotation.z = side * 0.07
		_box(leaf,Vector3(side*0.18,0,0),Vector3(0.36,0.026,0.52),cover)
		_box(leaf,Vector3(side*0.18,0.031,0),Vector3(0.335,0.045,0.49),paper)
		for y in [0.016,0.029,0.042]:
			_box(leaf,Vector3(side*0.18,y,0.247),Vector3(0.327,0.003,0.002),edge)
		if side == -1:
			var title = Label3D.new()
			title.text = "СКАЗКИ\n\nнашей горы"
			title.font = preload("res://assets/fonts/regular.ttf")
			title.font_size = 28
			title.pixel_size = 0.0012
			title.modulate = Color("544233")
			title.outline_size = 0
			title.shaded = true
			title.rotation.x = -PI/2
			title.position = Vector3(-0.18,0.057,-0.02)
			leaf.add_child(title)
		else:
			# A real forked spruce drawing on the right page, matching the dialogue.
			var ink = _mat("book_ink",Color("374b3c"))
			_beam(leaf,Vector3(0.18,0.059,0.17),Vector3(0.18,0.059,-0.01),0.004,ink)
			for branch in [-1,1]:
				var tip = Vector3(0.18+branch*0.055,0.059,-0.17)
				_beam(leaf,Vector3(0.18,0.059,0.04),tip,0.004,ink)
				for i in range(4):
					var z = -0.12+i*0.045
					for twig in [-1,1]:
						_beam(leaf,Vector3(tip.x,0.059,z-0.035),Vector3(tip.x+twig*(0.025+i*0.008),0.059,z+0.03),0.003,ink)
	_box(root,Vector3(-0.035,0.06,0.22),Vector3(0.018,0.006,0.17),_mat("book_ribbon",Color("9f4d3c")))
	return root

static func _mat(key: String, colour: Color, metallic: float = 0.0, roughness: float = 0.82) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.metallic = metallic
	material.roughness = roughness
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var image := Image.create(32, 32, false, Image.FORMAT_RGB8)
	var random := RandomNumberGenerator.new()
	random.seed = key.hash()
	for y in range(32):
		for x in range(32):
			var brightness := random.randf_range(0.79, 1.14)
			if key=="book_paper": brightness=random.randf_range(0.97,1.02)
			elif key.begins_with("wood"):
				brightness = 0.83 + 0.18 * sin(float(x) * 0.92 + sin(float(y) * 0.19)) + random.randf_range(-0.08, 0.08)
			elif key.begins_with("sleeve"):
				brightness = 0.91 + float((x + y) % 2) * 0.09 + random.randf_range(-0.04, 0.04)
			image.set_pixel(x, y, Color(brightness, brightness, brightness))
	material.albedo_texture = ImageTexture.create_from_image(image)
	_materials[key] = material
	return material

static func _emissive(colour: Color, energy: float = 1.8) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour.darkened(0.18)
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = energy
	material.roughness = 0.3
	return material

static func _box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance

static func _cylinder(parent: Node3D, at: Vector3, radius: float, length: float, material: Material, direction: Vector3 = Vector3.UP, ends: float = -1.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if ends < 0.0 else ends
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 10
	mesh.rings = 1
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	if direction.normalized().dot(Vector3.UP) < -0.999:
		instance.rotation.x = PI
	elif absf(direction.normalized().dot(Vector3.UP)) < 0.999:
		instance.quaternion = Quaternion(Vector3.UP, direction.normalized())
	return instance

static func _beam(parent: Node3D, start: Vector3, finish: Vector3, radius: float, material: Material) -> MeshInstance3D:
	return _cylinder(parent, (start + finish) * 0.5, radius, start.distance_to(finish), material, (finish - start).normalized())

# A tapered, eight-sided stock. Flat triangles make the grain catch the sunset.
static func _stock(parent: Node3D, sections: Array, material: Material) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for section in sections:
		var w: float = section.x
		var h: float = section.y
		var z: float = section.z
		var cy: float = section.w
		for i in range(8):
			var angle := float(i) * TAU / 8.0 + PI / 8.0
			vertices.append(Vector3(cos(angle) * w, sin(angle) * h + cy, z))
			uvs.append(Vector2(float(i) / 8.0, z * 1.8))
			normals.append(Vector3(cos(angle), sin(angle), 0.0))
	for s in range(sections.size() - 1):
		for i in range(8):
			var a := s * 8 + i
			var b := s * 8 + (i + 1) % 8
			var c := (s + 1) * 8 + (i + 1) % 8
			var d := (s + 1) * 8 + i
			indices.append_array(PackedInt32Array([a, c, b, a, d, c]))
	for i in range(1, 7):
		indices.append_array(PackedInt32Array([0, i, i + 1]))
		var last := (sections.size() - 1) * 8
		indices.append_array(PackedInt32Array([last, last + i + 1, last + i]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance

static func rifle(parent: Node3D, with_hands: bool = true) -> Node3D:
	var root := Node3D.new()
	root.name = "OldRifle"
	parent.add_child(root)
	var wood := _mat("wood_walnut", Color("70472e"), 0.0, 0.76)
	var wood_light := _mat("wood_foregrip", Color("62442e"), 0.0, 0.78)
	var steel := _mat("steel_barrel", Color("393c3d"), 0.68, 0.52)
	var edge := _mat("steel_edges", Color("666763"), 0.73, 0.49)
	var dark := _mat("steel_dark", Color("171d20"), 0.4, 0.72)
	var brass := _mat("brass_old", Color("8f794b"), 0.6, 0.67)
	var skin := _mat("skin", Color("ae8b6e"), 0.0, 0.96)
	var skin_shadow := _mat("skin_shadow", Color("99735c"), 0.0, 0.98)
	var sleeve := _mat("sleeve_charcoal", Color("252b2c"), 0.0, 1.0)
	var cuff := _mat("sleeve_cuff", Color("171d20"), 0.0, 1.0)
	# The rifle is inert during play: it is a story object, not a combat system.
	_stock(root, [Vector4(0.025,0.026,-0.20,-0.023), Vector4(0.044,0.049,0.02,-0.04), Vector4(0.034,0.047,0.20,-0.058), Vector4(0.058,0.10,0.45,-0.042)], wood)
	_stock(root, [Vector4(0.031,0.023,-0.57,-0.029), Vector4(0.043,0.035,-0.37,-0.028), Vector4(0.042,0.038,-0.12,-0.026)], wood_light)
	_box(root, Vector3(0,-0.042,0.455), Vector3(0.107,0.182,0.017), dark).rotation.x = -0.06
	_box(root, Vector3(0,-0.038,0.44), Vector3(0.114,0.006,0.02), brass)
	_box(root, Vector3(0,0.017,-0.055), Vector3(0.068,0.055,0.27), steel)
	_box(root, Vector3(0,0.049,-0.05), Vector3(0.038,0.009,0.24), edge)
	_cylinder(root, Vector3(0,0.043,-0.463), 0.018,0.687,steel,Vector3.FORWARD)
	_cylinder(root, Vector3(0,0.041,-0.808), 0.020,0.012,edge,Vector3.FORWARD)
	_cylinder(root, Vector3(0,0.041,-0.816), 0.013,0.002,dark,Vector3.FORWARD)
	_cylinder(root, Vector3(0,0.015,-0.16), 0.024,0.05,dark,Vector3.FORWARD)
	for z in [-0.49, -0.21]:
		_box(root, Vector3(0,-0.005,z), Vector3(0.086,0.047,0.016), steel)
	_box(root, Vector3(0,0.072,-0.745),Vector3(0.012,0.043,0.021),dark)
	_box(root, Vector3(0,0.065,-0.19),Vector3(0.045,0.014,0.023),dark)
	_box(root, Vector3(0,0.074,-0.19),Vector3(0.008,0.009,0.008),edge)
	# Bolt and rubbed brass details break up the receiver silhouette.
	var bolt := Node3D.new()
	bolt.name = "Bolt"
	root.add_child(bolt)
	_cylinder(bolt,Vector3(0,0.040,0.031),0.021,0.13,edge,Vector3.FORWARD)
	_beam(bolt,Vector3(0.028,0.023,0.04),Vector3(0.077,-0.013,0.065),0.007,edge)
	_cylinder(bolt,Vector3(0.08,-0.016,0.067),0.012,0.015,dark)
	_box(root,Vector3(0.035,0.018,-0.07),Vector3(0.002,0.023,0.076),dark)
	for z in [0.13,0.35,-0.35]:
		_cylinder(root, Vector3(0.045,-0.033,z),0.006,0.005,edge,Vector3.RIGHT)
	# Trigger guard is deliberately indistinct and is never an interaction target.
	_beam(root,Vector3(-0.022,-0.068,-0.035),Vector3(-0.024,-0.105,0.025),0.004,dark)
	_beam(root,Vector3(-0.024,-0.105,0.025),Vector3(-0.02,-0.085,0.09),0.004,dark)
	# Two relaxed hands and textured jacket sleeves anchor the view to a person.
	var reload_hand := Node3D.new()
	reload_hand.name = "ReloadHand"
	reload_hand.visible = with_hands
	root.add_child(reload_hand)
	_beam(reload_hand,Vector3(0.29,-0.30,0.54),Vector3(0.13,-0.14,0.20),0.089,sleeve)
	_cylinder(reload_hand,Vector3(0.12,-0.131,0.17),0.066,0.072,cuff,Vector3(-0.38,0.3,-0.8))
	_box(reload_hand,Vector3(0.072,-0.081,0.128),Vector3(0.083,0.09,0.117),skin).rotation = Vector3(-0.20,-0.20,-0.15)
	for i in range(4):
		_box(reload_hand,Vector3(0.018,-0.091,0.09 + i*0.023),Vector3(0.035,0.045,0.017),skin_shadow).rotation.z=-0.12
	_box(reload_hand,Vector3(0.043,-0.014,0.106),Vector3(0.056,0.034,0.077),skin).rotation.z=-0.42
	var left_hand := Node3D.new()
	left_hand.name = "LeftHand"
	left_hand.visible = with_hands
	root.add_child(left_hand)
	_beam(left_hand,Vector3(-0.36,-0.27,0.44),Vector3(-0.13,-0.15,-0.23),0.09,sleeve)
	_cylinder(left_hand,Vector3(-0.112,-0.128,-0.264),0.067,0.064,cuff,Vector3(0.3,0.2,-0.9))
	_box(left_hand,Vector3(-0.068,-0.078,-0.31),Vector3(0.082,0.064,0.144),skin).rotation.z=-0.15
	for i in range(4):
		_box(left_hand,Vector3(-0.003,-0.060,-0.359+i*0.025),Vector3(0.038,0.043,0.019),skin).rotation.z=-0.22
	_box(left_hand,Vector3(-0.068,-0.02,-0.329),Vector3(0.031,0.046,0.080),skin_shadow).rotation.x=-0.27
	var muzzle := Marker3D.new()
	muzzle.name = "Barrel"
	muzzle.position = Vector3(0,0.041,-0.822)
	root.add_child(muzzle)
	return root

static func legs(parent: Node3D) -> Node3D:
	# Camera-relative relaxed legs, on the grass rather than standing below the eye.
	var root := Node3D.new()
	root.name = "RestingLegs"
	parent.add_child(root)
	var cloth := _mat("sleeve_trousers",Color("323638"),0.0,1.0)
	var seams := _mat("sleeve_trouser_seams",Color("454746"),0.0,1.0)
	var boots := _mat("boots",Color("252925"),0.0,0.95)
	var soles := _mat("soles",Color("181e1a"),0.0,1.0)
	for side in [-1.0,1.0]:
		var hip := Vector3(side*0.20,-0.62,0.17)
		var knee := Vector3(side*0.42,-0.38,-0.62)
		var ankle := Vector3(side*0.33,-0.66,-1.40)
		_beam(root,hip,knee,0.20,cloth)
		_beam(root,knee,ankle,0.145,cloth)
		var kneecap := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.19
		sphere.height = 0.31
		sphere.radial_segments = 10
		sphere.rings = 4
		kneecap.mesh = sphere
		kneecap.position = knee
		kneecap.material_override = cloth
		root.add_child(kneecap)
		_beam(root,knee+Vector3(side*.14,.04,0),ankle+Vector3(side*.1,.02,0),0.006,seams)
		_box(root,ankle+Vector3(0,-.015,-.12),Vector3(.23,.24,.39),boots).rotation.x = 0.10
		_box(root,ankle+Vector3(0,-.14,-.12),Vector3(.24,.045,.41),soles)
	return root

static func _screws(parent: Node3D, panel: Vector3, width: float, height: float) -> void:
	var steel := _mat("screws", Color("77796f"),0.65,0.6)
	var dark := _mat("screwslots",Color("22292a"),0.0,0.8)
	for x in [-width/2.0 + 0.045, width/2.0 - 0.045]:
		for y in [-height/2.0 + 0.045, height/2.0 - 0.045]:
			_cylinder(parent,panel+Vector3(x,y,0),0.014,0.009,steel,Vector3.BACK)
			_box(parent,panel+Vector3(x,y,0.006),Vector3(0.017,0.003,0.002),dark)

static func _label(parent: Node3D, text: String, at: Vector3, size: float = 0.0018) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 36
	label.pixel_size = size
	label.position = at
	label.modulate = Color("c0bea6")
	label.outline_size = 0
	label.no_depth_test = false
	parent.add_child(label)
	return label

static func device(parent: Node3D, kind: String, at: Vector3) -> Dictionary:
	# Never silently turn an unknown story prop into a console.
	if kind not in ["ammo","lock","generator","source","bridge_console","door_console","shift_tool"]:
		push_error("Unknown device kind: "+kind)
		return {}
	var root := Node3D.new()
	root.name = kind.to_pascal_case()
	root.position = at
	parent.add_child(root)
	var enamel := _mat("enamel_olive",Color("414b42"),0.26,0.83)
	var iron := _mat("iron_prop",Color("353e3d"),0.51,0.76)
	var black := _mat("rubber_prop",Color("161e20"),0.0,0.95)
	var steel := _mat("edge_prop",Color("75796e"),0.52,0.62)
	var rust := _mat("rust_prop",Color("6e4c37"),0.1,0.95)
	var brass := _mat("brass_prop",Color("a58d54"),0.55,0.75)
	var inactive := _emissive(Color("644d31"),0.25)
	var lamp: MeshInstance3D
	var moving := Node3D.new()
	moving.name = "Mechanism"
	root.add_child(moving)
	if kind == "ammo":
		# One symbolic round, echoed between the grass and Pandora's box.
		_cylinder(root,Vector3(0,0.055,0),0.045,0.22,_mat("shell_red",Color("934a3a")),Vector3.FORWARD)
		_cylinder(root,Vector3(0,0.055,0.1),0.048,0.035,brass,Vector3.FORWARD)
	elif kind == "lock":
		_box(root,Vector3(0,0.05,0.01),Vector3(0.2,0.30,0.075),iron)
		_box(root,Vector3(0,0.048,0.055),Vector3(0.16,0.25,0.02),rust)
		for x in [-0.06,0.06]:
			_beam(root,Vector3(x,0.16,0),Vector3(x,0.27,0),0.018,steel)
		_beam(root,Vector3(-0.06,0.27,0),Vector3(0.06,0.27,0),0.018,steel)
		_cylinder(root,Vector3(0,0.07,0.071),0.023,0.005,black,Vector3.BACK)
		_box(root,Vector3(0,0.046,0.075),Vector3(0.012,0.042,0.005),black)
		lamp = _box(root,Vector3(0,-0.03,0.075),Vector3(0.035,0.015,0.005),inactive)
	elif kind == "generator":
		_box(root,Vector3(0,0.08,0),Vector3(1.17,0.16,0.86),iron)
		_box(root,Vector3(0,0.69,0),Vector3(1.0,1.1,0.7),enamel)
		_box(root,Vector3(-0.3,0.77,0.373),Vector3(0.3,0.7,0.04),iron)
		for y in range(8):
			_box(root,Vector3(-0.3,0.49+y*0.073,0.4),Vector3(0.25,0.023,0.023),black)
		_box(root,Vector3(0.20,0.90,0.38),Vector3(0.40,0.38,0.04),black)
		lamp = _box(root,Vector3(0.2,0.98,0.408),Vector3(0.23,0.10,0.012),inactive)
		_cylinder(root,Vector3(0.2,0.80,0.413),0.04,0.017,steel,Vector3.BACK)
		_label(root,"ПИТАНИЕ",Vector3(0,1.34,0.36),0.0018)
		_label(root,"G — 02",Vector3(0.15,0.42,0.361),0.0011)
		for x in [-0.39,0.39]:
			_beam(root,Vector3(x,1.24,-0.18),Vector3(x,1.43,-0.18),0.035,iron)
		_beam(root,Vector3(-0.39,1.43,-0.18),Vector3(0.39,1.43,-0.18),0.035,iron)
		_screws(root,Vector3(0.20,0.90,0.414),0.40,0.38)
		_beam(root,Vector3(0.48,0.45,0),Vector3(0.67,0.18,-0.20),0.034,black)
		_beam(root,Vector3(0.67,0.18,-0.20),Vector3(0.7,0.07,-0.57),0.034,black)
	else:
		var is_source := kind == "source"
		var base_mat := rust if is_source else enamel
		_box(root,Vector3(0,0.06,0),Vector3(0.72,0.12,0.65),iron)
		_box(root,Vector3(0,0.5,-0.035),Vector3(0.59,0.86,0.43),base_mat)
		var face := _box(root,Vector3(0,0.95,0),Vector3(0.73,0.14,0.62),iron)
		face.rotation.x = 0.15
		_box(root,Vector3(0,1.065,-0.21),Vector3(0.65,0.31,0.12),base_mat)
		_box(root,Vector3(0,1.08,-0.141),Vector3(0.50,0.18,0.025),black)
		lamp = _box(root,Vector3(0,1.08,-0.122),Vector3(0.36,0.085,0.018),inactive)
		_screws(root,Vector3(0,1.08,-0.118),0.5,0.18)
		_box(root,Vector3(0,0.97,0.13),Vector3(0.19,0.017,0.24),black)
		moving.position = Vector3(0,0.98,0.12)
		_cylinder(moving,Vector3(0,0,0),0.043,0.17,steel,Vector3.RIGHT)
		_beam(moving,Vector3.ZERO,Vector3(0,0.20,0.08),0.019,steel)
		_cylinder(moving,Vector3(0,0.22,0.09),0.044,0.14,black,Vector3.RIGHT)
		_box(root,Vector3(0,0.72,0.187),Vector3(0.35,0.14,0.012),black)
		var title := "РЫЧАГ" if is_source else ("МОСТ" if kind == "bridge_console" else "КОНТУР")
		if kind == "shift_tool":
			title = "СДВИГ"
		_label(root,title,Vector3(0,0.73,0.199),0.0008)
		for x in [-0.23,0.23]:
			for y in [0.25,0.53]:
				_cylinder(root,Vector3(x,y,0.189),0.014,0.012,steel,Vector3.BACK)
		for y in range(4):
			_box(root,Vector3(0,0.28+y*0.05,0.185),Vector3(0.26,0.013,0.012),black)
		_beam(root,Vector3(0.30,0.31,-0.03),Vector3(0.45,0.08,-0.1),0.026,black)
		if is_source:
			for x in [-0.15,0.15]:
				_cylinder(root,Vector3(x,0.91,-0.09),0.04,0.09,brass)
	if kind == "lock":
		# The mounting origin is floor-relative like other devices; the padlock hangs on the jamb.
		for child in root.get_children():
			if child is Node3D: child.position.y += 1.08
	return {"node": root, "lamp": lamp, "moving": moving}
