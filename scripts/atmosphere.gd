extends Node3D

var camera: Camera3D
var environment: Environment
var rain: MultiMeshInstance3D
var rain_audio: AudioStreamPlayer
var music: AudioStreamPlayer
var light: SpotLight3D
var rain_amount := 1.0
var rain_level := -14.0
var music_level := -29.0
var duck_motion: Tween
var settings_motion: Tween
var rain_gain := 0.0
var music_gain := 0.0
var duck_amount := 0.0

func _ready() -> void:
	var sanctuary: Node3D = load("res://assets/models/sanctuary.glb").instantiate()
	add_child(sanctuary)
	_prepare_materials(sanctuary)
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#254e46")
	environment.background_energy_multiplier = 0.6
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#a2cbb8")
	environment.ambient_light_energy = 0.32
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#355c58")
	sky_material.sky_horizon_color = Color("#a4bdae")
	sky_material.ground_bottom_color = Color("#132a21")
	sky_material.ground_horizon_color = Color("#829c87")
	sky_material.sky_energy_multiplier = .5
	environment.sky = Sky.new()
	environment.sky.sky_material = sky_material
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.1
	environment.glow_enabled = true
	environment.glow_intensity = .65
	environment.glow_bloom = .05
	environment.ssao_enabled = true
	environment.ssao_radius = .45
	environment.ssao_intensity = .9
	environment.fog_enabled = true
	environment.fog_light_color = Color("#30584b")
	environment.fog_density = .0035
	environment.fog_height = .5
	environment.fog_height_density = .026
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = .006
	environment.volumetric_fog_albedo = Color("#749b88")
	environment.volumetric_fog_emission = Color("#152b25")
	environment.volumetric_fog_emission_energy = .14
	environment.volumetric_fog_length = 60
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-49,-27,-10)
	sun.light_color = Color("#eeeff5")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 32
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.light_angular_distance = 2.0
	add_child(sun)
	light = SpotLight3D.new()
	light.position = Vector3(-3,9,3)
	light.light_color = Color("#ffe0a4")
	light.light_energy = 3.2
	light.spot_range = 19
	light.spot_angle = 47
	light.spot_attenuation = 1.5
	light.shadow_enabled = false
	add_child(light)
	light.look_at(Vector3(0,.4,0))
	var fill := OmniLight3D.new()
	fill.position = Vector3(3,4,-5)
	fill.light_color = Color("#c9d2e8")
	fill.light_energy = .8
	fill.omni_range = 12
	add_child(fill)
	for x in [-5.28,5.28]:
		var lantern := OmniLight3D.new()
		lantern.position = Vector3(x,.87,-3.6)
		lantern.light_color = Color("#ffb95d")
		lantern.light_energy = 3.1
		lantern.omni_range = 4.0
		lantern.omni_attenuation = 1.15
		add_child(lantern)
	camera = Camera3D.new()
	camera.fov = 43
	camera.near = .1
	camera.far = 110
	add_child(camera)
	set_camera(false)
	camera.current = true
	_make_rain()
	_make_ripples()
	rain_audio = _loop_audio("v2/rain")
	music = _loop_audio("forest_harmonics")

func _prepare_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var m := node as MeshInstance3D
		if m.name.begins_with("Moss_Cap"):
			m.hide()
		if m.name.begins_with("Board_Surface"):
			var wet := ShaderMaterial.new()
			wet.shader = preload("res://shaders/wet_wood.gdshader")
			wet.set_shader_parameter("grain",preload("res://assets/textures/maple.png"))
			m.material_override = wet
		for index in m.mesh.get_surface_count():
			var mat := m.get_active_material(index)
			if mat is StandardMaterial3D:
				if "Leaf" in mat.resource_name:
					var leaves := ShaderMaterial.new()
					leaves.shader = preload("res://shaders/leaves.gdshader")
					leaves.set_shader_parameter("leaf_color",mat.albedo_color)
					m.set_surface_override_material(index,leaves)
				elif mat.resource_name in ["River_Rock","Rain_Slate","Pine_Bark","Forest_Floor"]:
					var surface := ShaderMaterial.new()
					surface.shader = preload("res://shaders/forest_surface.gdshader")
					surface.set_shader_parameter("base_color",mat.albedo_color)
					surface.set_shader_parameter("moss",.8 if mat.resource_name in ["River_Rock","Forest_Floor"] else 0.0)
					surface.set_shader_parameter("wood",1.0 if mat.resource_name == "Pine_Bark" else 0.0)
					m.set_surface_override_material(index,surface)
	for child in node.get_children():
		_prepare_materials(child)

func set_camera(playing: bool, animate: bool = false) -> void:
	var destination := Vector3(-1.8,11.4,10.2) if playing else Vector3(-2.5,8.6,13.2)
	var target := Vector3(-1.8,.35,0) if playing else Vector3(-2.5,.45,-.3)
	if animate:
		var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(camera,"position",destination,1.5)
		var probe := Node3D.new()
		add_child(probe)
		probe.position = destination
		probe.look_at(target)
		tween.tween_property(camera,"rotation",probe.rotation,1.5)
		probe.queue_free()
	else:
		camera.position = destination
		camera.look_at(target)

func _make_rain() -> void:
	rain = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(.014,.68)
	mm.mesh = quad
	mm.instance_count = 2600
	var rng := RandomNumberGenerator.new()
	rng.seed = 717
	for i in mm.instance_count:
		var x := rng.randf_range(-17,17)
		var z := rng.randf_range(-22,12)
		var bottom := .69 if absf(x)<4.1 and absf(z)<4.1 else -.3
		mm.set_instance_transform(i,Transform3D(Basis.from_euler(Vector3(0,0,-.055)),Vector3(x,bottom,z)))
		mm.set_instance_custom_data(i,Color(rng.randf(),rng.randf_range(.45,1),0,0))
	rain.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/rain.gdshader")
	rain.material_override = mat
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain.custom_aabb = AABB(Vector3(-20,-1,-24),Vector3(40,20,42))
	add_child(rain)

func _make_ripples() -> void:
	var ripple := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var plane := PlaneMesh.new()
	plane.size = Vector2(.48,.48)
	mm.mesh = plane
	mm.instance_count = 90
	var rng := RandomNumberGenerator.new()
	rng.seed = 143
	for i in mm.instance_count:
		var size := rng.randf_range(.6,1.25)
		mm.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),Vector3(rng.randf_range(-3.83,3.83),.669,rng.randf_range(-3.83,3.83))))
		mm.set_instance_custom_data(i,Color(rng.randf(),0,0,0))
	ripple.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/ripple.gdshader")
	ripple.material_override = mat
	ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ripple)

func _loop_audio(name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var path := "res://assets/audio/"+name+(".ogg" if name=="v2/rain" else ".wav")
	var stream: AudioStream = load(path).duplicate()
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
	player.stream = stream
	player.bus = &"Rain" if name=="v2/rain" else &"Music"
	# Start silent until saved preferences have been applied.
	player.volume_linear = 0.0
	add_child(player)
	player.play()
	return player

func settings(sound: bool, ambience: bool, full_quality: bool) -> void:
	if settings_motion and settings_motion.is_running():settings_motion.kill()
	settings_motion=create_tween().set_parallel()
	settings_motion.tween_property(self,"rain_gain",1.0 if sound else 0.0,.18)
	settings_motion.tween_property(self,"music_gain",1.0 if ambience else 0.0,.24)
	rain.multimesh.visible_instance_count = 2600 if full_quality else 1300
	environment.volumetric_fog_enabled = full_quality
	environment.ssao_enabled = full_quality

func duck(strength: float) -> void:
	if duck_motion and duck_motion.is_running():duck_motion.kill()
	duck_motion=create_tween()
	duck_motion.tween_property(self,"duck_amount",maxf(duck_amount,clampf(strength,0,1)),.04)
	duck_motion.tween_interval(.08+strength*.30)
	duck_motion.tween_property(self,"duck_amount",0.0,.5+strength*.5)

func _process(_delta: float) -> void:
	# Independent gain factors prevent a duck's recovery from undoing the mute setting.
	# Stream volumes are interpolated by the audio mixer between render frames.
	if is_instance_valid(rain_audio):rain_audio.volume_linear=db_to_linear(rain_level-duck_amount*9)*rain_gain
	if is_instance_valid(music):music.volume_linear=db_to_linear(music_level-duck_amount*8)*music_gain
