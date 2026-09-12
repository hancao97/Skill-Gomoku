extends Node3D

const JADE := Color("#68ead3")
const GOLD := Color("#ffd286")
const MOON := Color("#bee7ff")
var sound_enabled := true
var rng := RandomNumberGenerator.new()
var last_placement_sample := -1

func _ready() -> void:
	rng.seed = 7346

func sound(name: String, volume: float = -8) -> void:
	if not sound_enabled:
		return
	var player := AudioStreamPlayer.new()
	player.stream = load("res://assets/audio/"+name+".wav")
	player.volume_db = volume
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func stone_impact() -> void:
	# Real Yunzi-on-wood recordings: no musical pitch shift or added chime.
	var sample_index := (last_placement_sample + rng.randi_range(1,4)) % 5
	last_placement_sample = sample_index
	sound("stone_%02d" % (sample_index+1),-3.0)

func glow_material(color: Color, energy: float = 2.5) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = false
	return mat

func ring(where: Vector3, size: float, color: Color, duration: float = 1.2, ornate: bool = false, rainbow: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size,size)
	node.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/ring.gdshader")
	mat.set_shader_parameter("tint",color)
	mat.set_shader_parameter("ornate",1.0 if ornate else 0.0)
	mat.set_shader_parameter("rainbow",1.0 if rainbow else 0.0)
	mat.set_shader_parameter("strength",1.0)
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.position = where
	node.scale = Vector3.ONE * .3
	if duration > 0:
		var tween := create_tween().set_parallel()
		tween.tween_property(node,"scale",Vector3.ONE,duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_method(func(value: float):mat.set_shader_parameter("strength",value),1.0,0.0,duration).set_delay(duration*.15)
		tween.chain().tween_callback(node.queue_free)
	else:
		node.scale = Vector3.ONE
	return node

func soul(where: Vector3, color: Color, size: float = .32, rainbow: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = size
	sphere.height = size * 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	node.mesh = sphere
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/soul.gdshader")
	mat.set_shader_parameter("tint",color)
	mat.set_shader_parameter("rainbow",1.0 if rainbow else 0.0)
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.position = where
	return node

func sparks(where: Vector3, color: Color, count: int = 22, spread: float = 1.0, duration: float = .85) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = .018
	mesh.height = .08
	mesh.radial_segments = 6
	mesh.rings = 3
	for i in count:
		var node := MeshInstance3D.new()
		node.mesh = mesh
		var mat := glow_material(color)
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		node.position = where
		var phi := rng.randf_range(0,TAU)
		var end := where + Vector3(cos(phi)*spread, rng.randf_range(.2,1.0)*spread,sin(phi)*spread)*rng.randf_range(.3,1.0)
		node.look_at(end,Vector3.FORWARD)
		var tween := create_tween().set_parallel()
		tween.tween_property(node,"position",end,duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(node,"scale",Vector3.ONE*.05,duration)
		tween.tween_property(mat,"albedo_color:a",0.0,duration)
		tween.chain().tween_callback(node.queue_free)

func line(points: Array[Vector3], color: Color, radius: float = .012) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var mat := glow_material(color,2.8)
	for i in range(points.size()-1):
		var a := points[i]
		var b := points[i+1]
		if a.distance_to(b) < .001:
			continue
		var node := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = radius
		cylinder.bottom_radius = radius
		cylinder.height = a.distance_to(b)
		cylinder.radial_segments = 8
		node.mesh = cylinder
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)
		node.position = (a+b)*.5
		node.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	return root

func dissolve(node: Node3D, duration: float = .5) -> void:
	if not is_instance_valid(node):
		return
	var tween := create_tween()
	tween.tween_property(node,"scale",Vector3.ONE*.001,duration).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(node.queue_free)

func placement(node: Node3D, color: int, empowered: bool) -> void:
	var end := node.position
	if not empowered:
		node.position.y += .16
		var drop := create_tween()
		drop.tween_property(node,"position",end,.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await drop.finished
		stone_impact()
		return
	var tint := JADE if color == 1 else MOON
	node.position.y += 2.4
	node.scale = Vector3.ONE * .4
	var aura := soul(node.position+Vector3.UP*.1,tint,.29)
	var tween := create_tween().set_parallel()
	tween.tween_property(node,"position",end,.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(node,"scale",Vector3.ONE,.32)
	tween.tween_property(aura,"position",end+Vector3.UP*.1,.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	stone_impact()
	ring(end+Vector3.UP*.014,1.65,tint,.95,true)
	ring(end+Vector3.UP*.016,.95,GOLD if color == 1 else MOON,.7)
	sparks(end+Vector3.UP*.1,tint,18,.7)
	dissolve(aura,.45)

func pulse_stone(node: Node3D, tint: Color) -> void:
	var tween := create_tween()
	tween.tween_property(node,"scale",Vector3.ONE*1.18,.14)
	tween.tween_property(node,"scale",Vector3.ONE,.23)
	ring(node.position+Vector3.UP*.016,1.1,tint,.7)

func moon_disk(where: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.6,2.6)
	node.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/moon_disk.gdshader")
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.position = where
	return node

func victory_path(points: Array[Vector3], color: Color) -> void:
	if points.size() < 2:
		return
	var stroke := line([points.front()+Vector3.UP*.2,points.back()+Vector3.UP*.2],color,.033)
	dissolve(stroke,3.2)
	for p in points:
		ring(p+Vector3.UP*.014,1.5,color,2.0,true)
		sparks(p+Vector3.UP*.2,color,10,.9,1.4)
