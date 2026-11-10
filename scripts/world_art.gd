class_name WorldArt
extends RefCounted

static func mat(name: String, tint: Color = Color.WHITE, scale: float = 1.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = tint
	if not name.is_empty():
		m.albedo_texture = load("res://assets/textures/" + name + ".png")
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 0.96
	if name in ["concrete", "floor", "metal", "green"]:
		m.normal_enabled = true
		m.normal_texture = load("res://assets/textures/" + name + "_normal.png")
		m.normal_scale = 0.65
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	if name == "floor": m.roughness = 0.66
	if name == "metal":
		m.metallic = 0.35
		m.roughness = 0.58
	if name == "green": m.roughness = 0.48
	return m

static func flat(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var m = mat("", color)
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m

static func box(parent: Node3D, pos: Vector3, size: Vector3, material: Material, collision: bool = false) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = material
	n.position = pos
	parent.add_child(n)
	if collision:
		var body = StaticBody3D.new()
		var shape = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
		n.add_child(body)
	return n

static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, material: Material, top: float = -1.0, sides: int = 8) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	var m = CylinderMesh.new()
	m.bottom_radius = radius
	m.top_radius = radius if top < 0.0 else top
	m.height = height
	m.radial_segments = sides
	n.mesh = m
	n.material_override = material
	n.position = pos
	parent.add_child(n)
	return n

static func pipe(parent: Node3D, start: Vector3, end: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var n = cylinder(parent, (start + end) * 0.5, radius, maxf(0.001,start.distance_to(end)), material)
	if start.distance_squared_to(end)<0.000001: return n
	var direction = (end-start).normalized()
	if absf(direction.dot(Vector3.UP)) < 0.999:
		n.quaternion = Quaternion(Vector3.UP, direction)
	return n

static func light(parent: Node3D, pos: Vector3, color: Color, energy: float, radius: float) -> OmniLight3D:
	var l = OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy * 0.4
	l.omni_range = radius
	l.omni_attenuation = 1.2
	l.shadow_enabled = false
	parent.add_child(l)
	return l

static func downlight(parent: Node3D, pos: Vector3, color: Color, energy: float, radius: float) -> SpotLight3D:
	var lamp = SpotLight3D.new()
	lamp.position = pos
	lamp.rotation.x = -PI / 2.0
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.spot_range = radius
	lamp.spot_angle = 52.0
	lamp.spot_attenuation = 1.25
	lamp.spot_angle_attenuation = 0.45
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.035
	lamp.shadow_normal_bias = 0.6
	parent.add_child(lamp)
	return lamp

static func service_beacon(parent: Node3D, pos: Vector3):
	box(parent,pos,Vector3(0.32,0.48,0.18),flat(Color("20252c")))
	box(parent,pos+Vector3(0,0,0.11),Vector3(0.12,0.27,0.07),flat(Color("ed4c35"),2.4))
	light(parent,pos+Vector3(0,0,0.3),Color("ed503c"),1.2,4.5)

static func sign_text(parent: Node3D, text: String, pos: Vector3, size: int = 42, color: Color = Color(0.63,0.65,0.51)) -> Label3D:
	var n = Label3D.new()
	n.text = text
	n.position = pos
	n.font_size = size
	n.pixel_size = 0.005
	n.modulate = color
	n.outline_size = 0
	n.no_depth_test = false
	parent.add_child(n)
	return n

static func ground_height(x: float, z: float) -> float:
	var slope = maxf(-z - 5.0, 0.0) * 0.38
	var side = maxf(absf(x) - 5.0, 0.0) * 0.21
	return -0.18 - slope - side + sin(x*0.23)*sin(z*0.26)*0.18

static func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal = (b-a).cross(c-a).normalized()
	for v in [a,b,c]:
		st.set_color(color)
		st.set_normal(normal)
		st.set_uv(Vector2(v.x*0.25,v.z*0.25))
		st.add_vertex(v)

static func mesh_node(parent: Node3D, st: SurfaceTool, material: Material) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	n.mesh = st.commit()
	n.material_override = material
	parent.add_child(n)
	return n

static func mountain(parent: Node3D) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = 217991
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://assets/textures/sunset.gdshader")
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_energy_multiplier = 0.65
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45,0.47,0.59)
	env.ambient_light_energy = 0.28
	env.fog_enabled = true
	env.fog_light_color = Color(0.34,0.29,0.37)
	env.fog_light_energy = 0.6
	env.fog_density = 0.0015
	env.fog_sky_affect = 0.0
	var world = WorldEnvironment.new()
	world.environment = env
	parent.add_child(world)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-12,-26,0)
	sun.light_color = Color(1.0,0.65,0.46)
	sun.light_energy = 0.40
	sun.shadow_enabled = false
	parent.add_child(sun)
	# A low, tangible headland. Its distant sides fall away into the forest.
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in range(42):
		for ix in range(42):
			var x = float(ix)-21.0
			var z = float(iz)-29.0
			var a = Vector3(x,ground_height(x,z),z)
			var b = Vector3(x+1,ground_height(x+1,z),z)
			var c = Vector3(x,ground_height(x,z+1),z+1)
			var d = Vector3(x+1,ground_height(x+1,z+1),z+1)
			var tint = Color(0.88,0.87,0.73).darkened(rng.randf_range(0.0,0.11))
			triangle(st,a,c,b,tint)
			triangle(st,b,c,d,tint)
	var ground_mat = mat("grass_ground",Color.WHITE,0.8)
	ground_mat.vertex_color_use_as_albedo = true
	ground_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ground = mesh_node(parent,st,ground_mat)
	ground.create_trimesh_collision()
	# Six independently modelled silhouettes. Atmospheric perspective is part of their palette.
	var ridge_st = SurfaceTool.new()
	ridge_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ridge_colors = [Color("32343e"),Color("3c3948"),Color("514354"),Color("665164"),Color("795b6e"),Color("8b6676")]
	for layer in range(6):
		var depth = [48.0,85.0,145.0,240.0,390.0,620.0][layer]
		for i in range(100):
			var x = (float(i)-50.0)*depth*0.045
			var nx = x+depth*0.045
			var y = ridge_height(x,depth,layer)
			var ny = ridge_height(nx,depth,layer)
			var a = Vector3(x,y,-depth)
			var b = Vector3(nx,ny,-depth)
			var c = Vector3(x,-40,-depth+12)
			var d = Vector3(nx,-40,-depth+12)
			triangle(ridge_st,a,b,c,ridge_colors[layer])
			triangle(ridge_st,b,d,c,ridge_colors[layer].darkened(0.02))
	var ridge_material = flat(Color.WHITE)
	ridge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ridge_material.vertex_color_use_as_albedo = true
	ridge_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_node(parent,ridge_st,ridge_material)
	# All the valley conifers share one mesh and one draw call.
	var forest_st = SurfaceTool.new()
	forest_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(620):
		var z = rng.randf_range(-95,-18)
		var x = rng.randf_range(-90,90)
		if absf(x) < 6 and z > -33: continue
		var base = Vector3(x,-4.6-maxf(-z-20,0.0)*0.05,z)
		var h = rng.randf_range(1.7,5.1)
		pine_mesh(forest_st,base,h,Color(0.13,0.18,0.16).lightened(rng.randf_range(0.0,0.08)),rng)
	var forest_material = flat(Color.WHITE)
	forest_material.vertex_color_use_as_albedo = true
	forest_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_node(parent,forest_st,forest_material)
	# Close conifers enclose the headland. Their world-space clearing follows
	# the sunset, so the distant valley remains visible between dark trunks.
	var near_forest = SurfaceTool.new()
	near_forest.begin(Mesh.PRIMITIVE_TRIANGLES)
	var near_needles = SurfaceTool.new()
	near_needles.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1,1]:
		for i in range(11):
			var z = -5.5-float(i)*2.65+rng.randf_range(-1.1,1.1)
			var x = -rng.randf_range(7.5,17.0) if side<0 else (5.0-z)*.32+rng.randf_range(8.5,14.0)
			var pos = Vector3(x,ground_height(x,z),z)
			var h = rng.randf_range(8.0,12.5)
			bough_tree_mesh(near_needles,pos,h,rng)
			trunk_mesh(near_forest,pos,h*.72,h*.035,Color(.15,.115,.085))
	for i in range(9):
		var x = -15.0+float(i)*3.7+rng.randf_range(-.7,.7)
		var z = rng.randf_range(10,19)
		var pos = Vector3(x,ground_height(x,z),z)
		var h = rng.randf_range(8.5,13.0)
		bough_tree_mesh(near_needles,pos,h,rng)
		trunk_mesh(near_forest,pos,h*.72,h*.035,Color(.15,.115,.085))
	mesh_node(parent,near_forest,forest_material)
	# The old spruce is close enough to look up into the hanging branches.
	var bark = mat("bark",Color(0.8,0.69,0.55),1.2)
	var tree_base = Vector3(-3.35,ground_height(-3.35,0.0),0.0)
	cylinder(parent,tree_base+Vector3(0,4.6,0),0.46,9.2,bark,0.13,9)
	var crown_st = SurfaceTool.new()
	crown_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tier in range(11):
		var h = 2.3+float(tier)*.59
		var radius = 3.2*(1.0-float(tier)/13.0)
		for arm in range(10):
			var angle = float(arm)/10*TAU+float(tier)*1.91
			var direction = Vector3(cos(angle),-.25,sin(angle)).normalized()
			var start_pos = tree_base+Vector3(0,h,0)
			var end_pos = start_pos+direction*radius
			pipe(parent,start_pos,end_pos,.025,bark)
			for spray in range(3):
				var frac = float(spray)/3.0
				var center = start_pos.lerp(end_pos,frac)
				var half_w = (1.0-frac)*.55+.14
				var length_v = direction*(radius*(1.0-frac))
				var side = Vector3(-direction.z,0,direction.x)*half_w
				needle_quad(crown_st,center-side,center+side,center+length_v+side*.16,center+length_v-side*.16,Color(0.8,0.85,0.65))
				needle_quad(crown_st,center-Vector3.UP*half_w,center+Vector3.UP*half_w,center+length_v+Vector3.UP*half_w*.12,center+length_v-Vector3.UP*half_w*.12,Color(0.8,0.85,0.65))
	var needle_mat = mat("",Color(.55,.65,.59))
	needle_mat.albedo_texture = load("res://assets/textures/spruce_bough.png")
	needle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	needle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	needle_mat.alpha_scissor_threshold = .4
	needle_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_node(parent,crown_st,needle_mat)
	var distant_needles = needle_mat.duplicate()
	distant_needles.albedo_color = Color(.30,.39,.35)
	mesh_node(parent,near_needles,distant_needles)
	for i in range(6):
		var angle = float(i)*TAU/6.0
		var end = tree_base+Vector3(cos(angle)*1.2,0.10,sin(angle)*1.2)
		pipe(parent,tree_base+Vector3(0,0.6,0),end,0.10,bark)
	# Grass is pixel cutout geometry, gently moving in world space.
	var grass_mesh = QuadMesh.new()
	grass_mesh.size = Vector2(0.43,0.36)
	var grass_mat = ShaderMaterial.new()
	grass_mat.shader = load("res://assets/textures/grass.gdshader")
	grass_mat.set_shader_parameter("tex",load("res://assets/textures/grass_blades.png"))
	grass_mesh.material = grass_mat
	var grass_multi = MultiMesh.new()
	grass_multi.transform_format = MultiMesh.TRANSFORM_3D
	grass_multi.use_colors = true
	grass_multi.mesh = grass_mesh
	grass_multi.instance_count = 6400
	for i in range(6400):
		var x = rng.randf_range(-18,18)
		var z = rng.randf_range(-21,11)
		var scale_v = rng.randf_range(0.6,1.25)
		# Short, pressed grass keeps the nearby story prop readable when looking down.
		if Vector2(x-0.95,z-3.45).length()<1.0: scale_v *= 0.15
		var transform = Transform3D(Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(Vector3.ONE*scale_v),Vector3(x,ground_height(x,z)+0.17*scale_v,z))
		grass_multi.set_instance_transform(i,transform)
		grass_multi.set_instance_color(i,Color(0.72,0.83,0.78).darkened(rng.randf_range(0,0.25)))
	var grass = MultiMeshInstance3D.new()
	grass.multimesh = grass_multi
	parent.add_child(grass)
	var rock_mat = mat("rock",Color(0.66,0.65,0.68),1.2)
	for i in range(20):
		var x = rng.randf_range(-13,13)
		var z = rng.randf_range(-15,8)
		if absf(x)<1.5 and z>0: continue
		var stone = MeshInstance3D.new()
		var rock = SphereMesh.new()
		rock.radial_segments = 7
		rock.rings = 3
		rock.radius = rng.randf_range(0.27,0.65)
		rock.height = rock.radius*1.4
		stone.mesh = rock
		stone.material_override = rock_mat
		stone.position = Vector3(x,ground_height(x,z)+rock.radius*0.18,z)
		stone.scale = Vector3(1.3,0.7,1.0)
		stone.rotation_degrees = Vector3(10,rng.randf_range(0,360),8)
		parent.add_child(stone)
	# A few faded wildflowers, small enough to discover at the edge of vision.
	var flower_st = SurfaceTool.new()
	flower_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(110):
		var x = rng.randf_range(-10,10)
		var z = rng.randf_range(-12,6)
		var pos = Vector3(x,ground_height(x,z)+rng.randf_range(0.20,0.4),z)
		var color = Color("ac655c") if i%3 else Color("c9af74")
		triangle(flower_st,pos+Vector3(-.055,0,0),pos+Vector3(.055,0,0),pos+Vector3(0,.10,0),color)
		triangle(flower_st,pos+Vector3(0,0,-.055),pos+Vector3(0,0,.055),pos+Vector3(0,.10,0),color)
	mesh_node(parent,flower_st,forest_material)
	return {"environment":world,"sun":sun,"grass":grass}

static func bough_tree_mesh(st: SurfaceTool, pos: Vector3, height: float, rng: RandomNumberGenerator) -> void:
	for tier in range(10):
		var y = height*(.15+float(tier)*.08)
		var radius = height*(.30-float(tier)*.027)
		for arm in range(8):
			var angle = float(arm)/8.0*TAU+float(tier)*1.71+rng.randf_range(-.14,.14)
			var direction = Vector3(cos(angle),-.28,sin(angle)).normalized()
			var start_pos = pos+Vector3(0,y,0)
			var length_v = direction*radius
			var side = Vector3(-direction.z,0,direction.x)*radius*.26
			needle_quad(st,start_pos-side,start_pos+side,start_pos+length_v+side*.12,start_pos+length_v-side*.12,Color.WHITE)
			var vertical = Vector3.UP*radius*.25
			needle_quad(st,start_pos-vertical,start_pos+vertical,start_pos+length_v+vertical*.12,start_pos+length_v-vertical*.12,Color.WHITE)

static func trunk_mesh(st: SurfaceTool, pos: Vector3, height: float, radius: float, color: Color) -> void:
	for i in range(7):
		var angle_a = float(i)/7.0*TAU
		var angle_b = float(i+1)/7.0*TAU
		var a = pos+Vector3(cos(angle_a)*radius,0,sin(angle_a)*radius)
		var b = pos+Vector3(cos(angle_b)*radius,0,sin(angle_b)*radius)
		var c = pos+Vector3(cos(angle_a)*radius*.4,height,sin(angle_a)*radius*.4)
		var d = pos+Vector3(cos(angle_b)*radius*.4,height,sin(angle_b)*radius*.4)
		triangle(st,a,b,c,color)
		triangle(st,b,d,c,color)

static func ridge_height(x: float, depth: float, layer: int) -> float:
	var wave = sin(x/depth*3.5+layer*1.7)*0.027 + sin(x/depth*8.0-layer)*0.015 + sin(x/depth*19.0+layer*2.1)*0.008 + sin(x/depth*42.0+layer)*.003
	var valley = exp(-pow((x/depth-.32)*3.5,2.0))*.065
	return depth * (0.085+float(layer)*.014+wave-valley) - 3.5

static func needle_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	var vertices = [a,b,c,a,c,d]
	var uvs = [Vector2(0,0),Vector2(0,1),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(1,0)]
	for i in range(6):
		st.set_normal(Vector3.UP)
		st.set_color(color)
		st.set_uv(uvs[i])
		st.add_vertex(vertices[i])

static func pine_mesh(st: SurfaceTool, base: Vector3, height: float, color: Color, rng: RandomNumberGenerator, sides: int = 6) -> void:
	for tier in range(5):
		var f = float(tier)/5.0
		var bottom = base+Vector3(0,height*(0.12+f*0.66),0)
		var top = base+Vector3(0,height*(0.56+f*0.44),0)
		var radius = height*(0.28-f*0.22)
		var phase = float(tier)*0.8
		for j in range(sides):
			var a = float(j)/sides*TAU+phase
			var b = float(j+1)/sides*TAU+phase
			var p1 = bottom+Vector3(cos(a)*radius,rng.randf_range(-.08,.08)*height,sin(a)*radius)
			var p2 = bottom+Vector3(cos(b)*radius,rng.randf_range(-.08,.08)*height,sin(b)*radius)
			triangle(st,top,p2,p1,color.darkened(rng.randf_range(0,0.22)))

static func chamber(parent: Node3D, level: int) -> Dictionary:
	var w = 6.0 if level == 1 else 8.0
	var south = 3.0 if level == 1 else 4.0
	var north = -15.0 if level == 1 else -23.0
	var height = 4.5 if level == 1 else 5.0
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101614")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8898b2")
	env.ambient_light_energy = 0.075
	env.fog_enabled = true
	env.fog_light_color = Color(0.09,0.13,0.12)
	env.fog_density = 0.009 if level == 2 else 0.005
	var world = WorldEnvironment.new()
	world.environment = env
	parent.add_child(world)
	var concrete = mat("concrete",Color(0.71,0.73,0.65),0.7)
	var metal = mat("metal",Color(0.57,0.60,0.55),0.85)
	var green = mat("green",Color(0.70,0.83,0.66),0.75)
	var floor_mat = mat("floor",Color(0.83,0.85,0.75),0.5)
	var rust = mat("bark",Color(0.43,0.29,0.22),1.0)
	var dark = flat(Color("232c27"))
	var hazard = mat("hazard",Color(0.90,0.85,0.67),1.5)
	var lamp_mat = flat(Color("e1ebbb"),1.8)
	var warm_mat = flat(Color("e0ab65"),1.5)
	# Solid walls, with a real north opening and textured, repeated floor tiles.
	box(parent,Vector3(-w-.18,height*.5,(north+south)*.5),Vector3(.36,height,south-north+.7),concrete,true)
	box(parent,Vector3(w+.18,height*.5,(north+south)*.5),Vector3(.36,height,south-north+.7),concrete,true)
	box(parent,Vector3(0,height*.5,south+.18),Vector3(w*2+.7,height,.36),concrete,true)
	for side in [-1,1]:
		box(parent,Vector3(side*(w+1.5)*.5,height*.5,north-.18),Vector3(w-1.5,height,.36),concrete,true)
	box(parent,Vector3(0,height-.4,north-.18),Vector3(3,0.8,.36),concrete,true)
	box(parent,Vector3(0,height+.15,(north+south)*.5),Vector3(w*2+.5,.3,south-north+.5),metal)
	if level == 1:
		box(parent,Vector3(0,-.2,(north+south)*.5),Vector3(w*2,.4,south-north),floor_mat,true)
	else:
		box(parent,Vector3(0,-.2,(south-11.0)*.5),Vector3(w*2,.4,south+11.0),floor_mat,true)
		box(parent,Vector3(0,-.2,(north-15.0)*.5),Vector3(w*2,.4,-north-15.0),floor_mat,true)
		box(parent,Vector3(0,-4,-13),Vector3(w*2,.3,4),dark)
		for edge_z in [-11.0,-15.0]:
			box(parent,Vector3(0,-.15,edge_z),Vector3(w*2,.3,.22),hazard)
			for side in [-1,1]:
				var rail_length = w-1.6
				box(parent,Vector3(side*(w+1.6)*.5,.95,edge_z),Vector3(rail_length,.09,.09),metal,true)
				box(parent,Vector3(side*(w+1.6)*.5,.46,edge_z),Vector3(rail_length,.06,.06),metal)
				for rx in [2.0,4.7,7.6]:
					box(parent,Vector3(side*rx,.49,edge_z),Vector3(.09,1.04,.09),metal)
		# The gate is the only way across the transverse bulkhead.
		for side in [-1,1]:
			box(parent,Vector3(side*(w+1.6)*.5,height*.5,-10),Vector3(w-1.6,height,.38),concrete,true)
			box(parent,Vector3(side*(w+1.6)*.5,1.65,-9.79),Vector3(w-1.6,.5,.05),green)
			box(parent,Vector3(side*1.75,2.1,-9.72),Vector3(.18,4.2,.25),hazard)
		box(parent,Vector3(0,4.3,-10),Vector3(3.2,1.4,.38),metal,true)
		for px in [-6.0,-4.0,4.0,6.0]:
			pipe(parent,Vector3(px,-2,-11),Vector3(px,-2,-15),.14,rust)
		light(parent,Vector3(-5,-2,-13),Color(.25,.48,.38),1.4,6.0)
		light(parent,Vector3(5,-2,-13),Color(.25,.48,.38),1.4,6.0)
	# Green enamel stripe: continuous until it meets the doorway.
	for side in [-1,1]:
		box(parent,Vector3(side*(w-.015),1.65,(north+south)*.5),Vector3(.035,.52,south-north),green)
		box(parent,Vector3(side*(w+1.5)*.5,1.65,north+.015),Vector3(w-1.5,.52,.04),green)
		box(parent,Vector3(side*(w-.08),.12,(north+south)*.5),Vector3(.12,.24,south-north),metal)
	box(parent,Vector3(0,1.65,south-.015),Vector3(w*2,.52,.04),green)
	# Rhythmic pillars and ceiling beams catch the overhead light.
	var beam_z = -1.0
	while beam_z > north+1.0:
		for side in [-1,1]:
			box(parent,Vector3(side*(w-.12),height*.5,beam_z),Vector3(.28,height,.30),metal,true)
			box(parent,Vector3(side*(w-.28),height-.28,beam_z),Vector3(.60,.20,.65),metal)
		box(parent,Vector3(0,height-.14,beam_z),Vector3(w*2,.23,.28),metal)
		beam_z -= 4.0
	# Fluorescent fixtures have three individual glowing tubes and a dark ballast.
	var lamp_zs = [-1.8,-7.0,-12.0] if level == 1 else [-1.0,-6.6,-16.0,-21.0]
	for z in lamp_zs:
		var lamp_x = -1.0 if level == 1 else (2.5 if z > -10 else -2.5)
		box(parent,Vector3(lamp_x,height-.25,z),Vector3(2.25,.18,.85),dark)
		for tube in [-1,0,1]:
			box(parent,Vector3(lamp_x,height-.36,z+tube*.23),Vector3(1.96,.045,.10),lamp_mat)
		downlight(parent,Vector3(lamp_x,height-.65,z),Color("a9c3c5"),0.72,8.5)
	service_beacon(parent,Vector3(-w+1.0,3.15,north+0.3))
	# One warm service lamp balances the green light and directs the eye deeper.
	box(parent,Vector3(w-.09,2.7,north+4),Vector3(.2,.75,.38),dark)
	box(parent,Vector3(w-.23,2.7,north+4),Vector3(.08,.52,.24),warm_mat)
	light(parent,Vector3(w-.6,2.7,north+4),Color(1.0,.59,.29),1.3,6)
	# Four continuous utility lines, fewer pieces than decorative tiling.
	for side in [-1,1]:
		for offset in [0.0,0.24]:
			pipe(parent,Vector3(side*(w-.36),3.65+offset,south-.2),Vector3(side*(w-.36),3.65+offset,north+.8),.065,rust if offset == 0.0 else metal)
		for z in [-2.0,-8.0,north+2.0]:
			box(parent,Vector3(side*(w-.36),3.77,z),Vector3(.21,.56,.08),metal)
	# Door opening, with bolts and a worn hazard lintel. The moving leaves belong to gameplay.
	for side in [-1,1]:
		box(parent,Vector3(side*1.66,1.90,north+.04),Vector3(.25,3.8,.42),metal)
		box(parent,Vector3(side*1.48,1.9,north+.28),Vector3(.09,3.75,.045),hazard)
		for y in [.35,1.25,2.15,3.05]:
			box(parent,Vector3(side*1.68,y,north+.29),Vector3(.065,.065,.04),flat(Color("a8a38d")))
	box(parent,Vector3(0,3.84,north+.08),Vector3(3.57,.32,.45),hazard)
	# Wall vent. A dark cavity behind real slats, no expensive transparency.
	var vent_z = -8.5 if level == 1 else -3.0
	box(parent,Vector3(-w+.03,2.65,vent_z),Vector3(.08,1.15,2.2),dark)
	for i in range(7):
		box(parent,Vector3(-w+.10,2.17+i*.15,vent_z),Vector3(.13,.055,2.06),metal)
	for z in [vent_z-1.13,vent_z+1.13]:
		box(parent,Vector3(-w+.12,2.65,z),Vector3(.13,1.27,.09),rust)
	# A shallow observation window on the other side: glass without reflections.
	var window_z = -9.5 if level == 1 else -18.7
	box(parent,Vector3(w-.03,2.2,window_z),Vector3(.08,1.35,3.4),dark)
	box(parent,Vector3(w-.10,2.2,window_z),Vector3(.09,.045,3.4),metal)
	for zz in [window_z-1.7,window_z,window_z+1.7]:
		box(parent,Vector3(w-.12,2.2,zz),Vector3(.12,1.46,.08),metal)
	for yy in [1.49,2.91]:
		box(parent,Vector3(w-.12,yy,window_z),Vector3(.12,.08,3.55),metal)
	# Thin mineral trails and broken plaster stay on surfaces, never block the route.
	var stain = mat("concrete",Color(0.37,0.33,0.23),2.0)
	for i in range(10):
		var side = -1 if i%2 == 0 else 1
		var z = south-2.0-float(i)*1.72
		box(parent,Vector3(side*(w-.025),2.38,z),Vector3(.012,.9+float(i%3)*.15,.055+float(i%2)*.045),stain)
	# Small maintenance details around the threshold behind the player.
	for side in [-1,1]:
		box(parent,Vector3(side*(w-1.0),.25,south-.6),Vector3(1.0,.5,.65),metal,true)
		box(parent,Vector3(side*(w-1.0),.52,south-.6),Vector3(.8,.035,.48),hazard)
	if level == 1:
		sign_text(parent,"01",Vector3(-4.4,3.15,north+.22),106,Color("b9c3a5"))
		var plate = box(parent,Vector3(-w+.04,1.75,-2.0),Vector3(.07,.65,1.6),dark)
		var side_sign = sign_text(parent,"СОСТОЯНИЕ\n0  /  1",Vector3(-w+.10,1.75,-2.0),28)
		side_sign.rotation.y = PI/2
	else:
		sign_text(parent,"02",Vector3(-5.7,3.3,-9.76),106,Color("b9c3a5"))
		sign_text(parent,"ВЫХОД",Vector3(0,4.35,north+.24),42,Color("d0c3a1"))
		# Suspended cables curve over the bridge, making the void legible.
		for side in [-1,1]:
			for seg in range(8):
				var za = -10.7-float(seg)*.56
				var zb = za-.56
				var ya = 3.5-sin(float(seg)/8*PI)*.9
				var yb = 3.5-sin(float(seg+1)/8*PI)*.9
				pipe(parent,Vector3(side*2.4,ya,za),Vector3(side*2.4,yb,zb),.035,dark)
	return {"environment":world,"width":w,"north":north}
