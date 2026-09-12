extends Node3D

signal impact(strength: float)
signal thunder_struck
const LightningStrike=preload("res://scripts/lightning_strike.gd")
const StoneRecoil=preload("res://scripts/stone_recoil.gd")
const INK := Color("#08090f")
const SILVER := Color("#f4f7ff")
const CUES := {
	"stone_01": preload("res://assets/audio/v2/stone_01.wav"),
	"stone_02": preload("res://assets/audio/v2/stone_02.wav"),
	"stone_03": preload("res://assets/audio/v2/stone_03.wav"),
	"bow_draw": preload("res://assets/audio/v2/bow_draw.wav"),
	"bow_release": preload("res://assets/audio/v2/bow_release.wav"),
	"charge": preload("res://assets/audio/v2/charge.wav"),
	"impact": preload("res://assets/audio/v2/impact.wav"),
	"moon_rise": preload("res://assets/audio/v2/moon_rise.wav"),
	"moon_impact": preload("res://assets/audio/v2/moon_impact.wav"),
	"cosmos_impact": preload("res://assets/audio/v2/cosmos_impact.wav"),
	"cosmos_descent": preload("res://assets/audio/v2/cosmos_descent.wav"),
	"thunder_01": preload("res://assets/audio/v2/thunder_01.wav"),
	"thunder_02": preload("res://assets/audio/v2/thunder_02.wav"),
	"victory": preload("res://assets/audio/v2/victory.wav"),
	"hand_gather": preload("res://assets/audio/v2/hand_gather.wav"),
	"hand_point": preload("res://assets/audio/v2/hand_point.wav"),
	"hand_impact": preload("res://assets/audio/v2/hand_impact.wav"),
}
const GESTURE_LOOPS := {
	"bow_draw": Vector2(.50,1.14),
	"charge": Vector2(1.68,2.48),
}
var sound_enabled := true
var visuals_enabled := true
var volume_db := 0.0
var noise: NoiseTexture2D
var rng := RandomNumberGenerator.new()
var auras: Array[WeakRef] = []
var sample_index := 0
var thunder_index := 0
var thunder_voice: AudioStreamPlayer
var storm_release: SceneTreeTimer

func _ready() -> void:
	rng.seed = 947201
	var generator := FastNoiseLite.new()
	generator.seed = 82341
	generator.frequency = .025
	generator.fractal_octaves = 4
	noise = NoiseTexture2D.new()
	noise.width = 256
	noise.height = 256
	noise.seamless = true
	noise.noise = generator

func sound(cue: String, db: float = -4.0, pitch: float = 1.0) -> AudioStreamPlayer:
	if not sound_enabled:
		return null
	var player := AudioStreamPlayer.new()
	player.stream = CUES[cue]
	if GESTURE_LOOPS.has(cue):
		var stream:AudioStreamWAV=CUES[cue].duplicate()
		var region:Vector2=GESTURE_LOOPS[cue]
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin=roundi(region.x*stream.mix_rate)
		stream.loop_end=roundi(region.y*stream.mix_rate)
		player.stream=stream
	player.bus = &"Thunder" if cue.begins_with("thunder_") else &"Effects"
	player.volume_db = db+volume_db
	player.pitch_scale = pitch
	add_child(player)
	player.finished.connect(player.queue_free)
	# Godot ramps stopped streams in the audio mixer. Let that block finish before
	# starting a skill, including when the previous rumble was cancelled mid-wave.
	if storm_release and storm_release.time_left > 0 and not cue.begins_with("stone_") and not cue.begins_with("thunder_"):
		_play_after_storm(player, storm_release)
	else:
		player.play()
	return player

func _play_after_storm(player: AudioStreamPlayer, gate: SceneTreeTimer) -> void:
	await gate.timeout
	if is_instance_valid(player) and not player.is_queued_for_deletion() and not player.has_meta("releasing") and sound_enabled:
		player.play()

func release_sound(player: AudioStreamPlayer, seconds: float = .045) -> void:
	if not is_instance_valid(player) or player.is_queued_for_deletion() or player.has_meta("releasing"):return
	player.set_meta("releasing", true)
	if seconds <= 0 or not player.playing:
		# stop() uses the engine's sample-interpolated ramp, preserving skill exclusivity.
		player.stop()
		player.queue_free()
		return
	var release := player.create_tween()
	release.tween_property(player, "volume_linear", 0.0, seconds)
	release.tween_callback(player.stop)
	release.tween_callback(player.queue_free)

func set_sound_enabled(enabled: bool) -> void:
	sound_enabled = enabled
	if not enabled:
		for child in get_children():
			if child is AudioStreamPlayer:release_sound(child)

func set_visuals_enabled(enabled: bool) -> void:
	visuals_enabled=enabled
	if enabled:return
	clear_lightning()
	for child in get_children():
		if child is Node3D:child.queue_free()
	for reference in auras:
		var aura=reference.get_ref()
		if is_instance_valid(aura):
			aura.get_parent().remove_meta("aura")
			aura.queue_free()
	auras.clear()

func stone_impact() -> void:
	sample_index = (sample_index+1) % 3
	sound("stone_%02d"%(sample_index+1),-3.5)
	impact.emit(.18)

func smoke(where: Vector3, color: int, size: float = 1.0, burst: bool = false, count: int = 22, life: float = 1.1) -> GPUParticles3D:
	var emitter := GPUParticles3D.new()
	emitter.amount = count
	emitter.lifetime = life
	emitter.one_shot = burst
	emitter.explosiveness = .96 if burst else 0.0
	emitter.randomness = .42
	emitter.local_coords = false
	emitter.visibility_aabb = AABB(Vector3.ONE*-8,Vector3.ONE*16)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = .12*size
	process.direction = Vector3.UP
	process.spread = 105.0 if burst else 27.0
	process.initial_velocity_min = (.4 if burst else .11)*size
	process.initial_velocity_max = (1.5 if burst else .40)*size
	process.gravity = Vector3(0,.08,0)
	process.scale_min = .28*size
	process.scale_max = .65*size
	process.angular_velocity_min = -25
	process.angular_velocity_max = 25
	emitter.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/ink_smoke.gdshader")
	material.set_shader_parameter("smoke_noise",noise)
	material.set_shader_parameter("white_stone",color==2)
	quad.material = material
	emitter.draw_pass_1 = quad
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(emitter)
	emitter.position = where
	emitter.emitting = true
	if burst:
		get_tree().create_timer(life+.25).timeout.connect(emitter.queue_free)
	return emitter

func bind_aura(stone: Node3D, color: int) -> void:
	if not visuals_enabled or stone.has_meta("aura"):
		return
	stone.set_meta("aura",true)
	var aura := smoke(stone.global_position+Vector3.UP*.07,color,.85,false,11 if color==1 else 6,1.1)
	aura.reparent(stone)
	aura.name = "InkPresence" if color==1 else "SilverPresence"
	aura.set_meta("stone_color",color)
	auras.append(weakref(aura))
	while auras.size() > 24:
		var previous = auras.pop_front().get_ref()
		if is_instance_valid(previous): previous.queue_free()

func placement(stone: Node3D, color: int, empowered: bool, storm: bool = false, opponents: Array[Node3D] = []) -> void:
	empowered=empowered and visuals_enabled
	var end := stone.position
	stone.position.y += .68 if empowered else .13
	var drop := create_tween()
	drop.tween_property(stone,"position",end,.20 if empowered else .095).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await drop.finished
	stone_impact()
	if not empowered:
		return
	smoke(end+Vector3.UP*.06,color,1.0,true,24 if color==1 else 15,.72)
	bind_aura(stone,color)
	if color==2:
		glint(end+Vector3.UP*.24,.62,.35)
	var settle := create_tween()
	stone.scale = Vector3(1.04,.90,1.04)
	settle.tween_property(stone,"scale",Vector3.ONE,.10)
	if storm:
		if not opponents.is_empty():
			var recoil:=StoneRecoil.new()
			recoil.origin=end
			recoil.targets=opponents
			add_child(recoil)
			# A single, quiet landing sound for the group avoids a stack of 100 clacks.
			recoil.landed.connect(func():sound("stone_02",-16.0))
			var front:=wave(end,color,15.0,.50)
			front.material_override.set_shader_parameter("strength",.60 if color==1 else .32)
		var strike:=lightning(end,color)
		await strike.finished

func lightning(where:Vector3, color:int, audible:bool=true, thunder_db:float=-9.0) -> Node3D:
	var strike:=LightningStrike.new()
	strike.position=where
	strike.color=color
	strike.seed_value=rng.randi()
	add_child(strike)
	if audible:
		# Keep thunder tails from accumulating across rapid moves.
		if is_instance_valid(thunder_voice):
			release_sound(thunder_voice,.12)
		thunder_index=(thunder_index+1)%2
		thunder_voice=sound("thunder_%02d"%(thunder_index+1),thunder_db)
		if is_instance_valid(thunder_voice):thunder_voice.set_meta("placement_thunder",true)
		impact.emit(.55)
		thunder_struck.emit()
	return strike

func clear_lightning() -> void:
	# Include fading voices, not just the most recent thunder, and stop light immediately.
	for child in get_children():
		if child is LightningStrike:
			child.cancel()
		elif child is StoneRecoil:
			child.cancel()
		elif child is AudioStreamPlayer and child.has_meta("placement_thunder"):
			if child.playing:storm_release=get_tree().create_timer(.045)
			# Also stop voices already being faded by a later strike.
			child.stop()
			child.queue_free()
	thunder_voice=null

func glint(where:Vector3, size:float=.8, duration:float=.5) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*size
	node.mesh=quad
	var mat:=ShaderMaterial.new()
	mat.shader=preload("res://shaders/silver_glint.gdshader")
	node.material_override=mat
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.position=where
	var tween:=node.create_tween()
	tween.tween_method(func(v:float):mat.set_shader_parameter("strength",v),1.0,0.0,duration)
	tween.tween_callback(node.queue_free)
	return node

func wave(where:Vector3, color:int, diameter:float, duration:float) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	var plane:=PlaneMesh.new()
	plane.size=Vector2.ONE*diameter
	node.mesh=plane
	var mat:=ShaderMaterial.new()
	mat.shader=preload("res://shaders/impact_wave.gdshader")
	mat.set_shader_parameter("grain",noise)
	mat.set_shader_parameter("white_stone",color==2)
	node.material_override=mat
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.position=where+Vector3.UP*.018
	var tween:=node.create_tween()
	tween.tween_method(func(v:float):mat.set_shader_parameter("progress",v),0.0,1.0,duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(node.queue_free)
	return node

func ribbon(points:Array[Vector3], width:float, color:Color, upright:bool=false) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	var vertices:=PackedVector3Array()
	var uvs:=PackedVector2Array()
	for i in points.size():
		var t:=float(i)/maxi(points.size()-1,1)
		var tangent:=points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]
		var side:=Vector3.UP if upright else Vector3(-tangent.z,0,tangent.x).normalized()
		var taper:=.18+.82*pow(sin(t*PI),.4)
		vertices.append(points[i]-side*width*taper*.5)
		vertices.append(points[i]+side*width*taper*.5)
		uvs.append(Vector2(0,t));uvs.append(Vector2(1,t))
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP,arrays)
	node.mesh=mesh
	var material:=ShaderMaterial.new()
	material.shader=preload("res://shaders/brush_trail.gdshader")
	material.set_shader_parameter("grain",noise)
	material.set_shader_parameter("ink",color)
	node.material_override=material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func fade(node:Node3D, duration:float=.45) -> void:
	if not is_instance_valid(node):return
	if node is MeshInstance3D and node.material_override is ShaderMaterial:
		var material:ShaderMaterial=node.material_override
		var tween:=node.create_tween()
		tween.tween_method(func(v:float):material.set_shader_parameter("strength",v),1.0,0.0,duration)
		tween.tween_callback(node.queue_free)
	else:
		get_tree().create_timer(duration).timeout.connect(node.queue_free)

func slashes(where:Vector3, color:int, radius:float=3.0, count:int=9) -> void:
	for i in count:
		var angle:=TAU*float(i)/count+rng.randf_range(-.14,.14)
		var vector:=Vector3(cos(angle),0,sin(angle))
		var points:Array[Vector3]=[]
		for j in 8:
			var t:=float(j)/7
			points.append(where+vector*(.18+t*radius)+Vector3(0,.12+sin(t*PI)*.16,0))
		var stroke:=ribbon(points,.13+rng.randf()*.12,INK if color==1 else SILVER)
		fade(stroke,.45+rng.randf()*.3)

func moon_disk(where:Vector3) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	var plane:=PlaneMesh.new()
	plane.size=Vector2(3.1,3.1)
	node.mesh=plane
	var material:=ShaderMaterial.new()
	material.shader=preload("res://shaders/moon_disk.gdshader")
	node.material_override=material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.position=where
	return node

func clear_transients() -> void:
	clear_lightning()
	for child in get_children():
		if child is AudioStreamPlayer:release_sound(child)
		else:child.queue_free()
	auras.clear()
