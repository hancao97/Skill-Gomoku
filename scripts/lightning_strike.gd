extends Node3D

signal finished
var color := 1
var seed_value := 0
var age := 0.0
var material: ShaderMaterial
var light: OmniLight3D
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	name="LightningStrike"
	set_meta("stone_color",color)
	rng.seed=seed_value
	material=ShaderMaterial.new()
	material.shader=preload("res://shaders/lightning.gdshader")
	material.set_shader_parameter("white_stone",color==2)
	material.set_shader_parameter("reveal",0.0)
	var stem:Array[Vector3]=[]
	var origin:=Vector3(rng.randf_range(-.55,.55),4.7,rng.randf_range(-.32,.32))
	for i in 23:
		var t:=float(i)/22
		var point:=origin.lerp(Vector3(0,.18,0),t)
		if i>0 and i<22:
			point.x+=rng.randf_range(-.19,.19)
			point.z+=rng.randf_range(-.13,.13)
		stem.append(point)
	_add_bolt(stem,.34 if color==1 else .105)
	for index in [4,8,12,16]:
		var from:=stem[index]
		var tip:=from+Vector3(rng.randf_range(-1.1,1.1),-rng.randf_range(.55,1.35),rng.randf_range(-.4,.4))
		_add_bolt(_jagged(from,tip,9),.085 if color==1 else .042)
	# Short forks crawl away from the actual contact point, then die out.
	for i in 6:
		var angle:=float(i)*TAU/6+rng.randf_range(-.2,.2)
		var tip:=Vector3(cos(angle),.04,sin(angle))*rng.randf_range(.55,1.0)
		var points:=_jagged(Vector3(0,.08,0),tip,9)
		for j in points.size():points[j].y=.06+sin(float(j)/8*PI)*.10
		_add_bolt(points,.050 if color==1 else .032)
	light=OmniLight3D.new()
	light.position=Vector3(0,.65,0)
	light.light_color=Color("#b9b9b9") if color==1 else Color("#f5f7ff")
	light.light_energy=0
	light.omni_range=4.5
	light.omni_attenuation=1.5
	light.shadow_enabled=false
	add_child(light)

func _jagged(from:Vector3, to:Vector3, count:int) -> Array[Vector3]:
	var points:Array[Vector3]=[]
	for i in count:
		var t:=float(i)/(count-1)
		var point:=from.lerp(to,t)
		if i>0 and i<count-1:
			point+=Vector3(rng.randf_range(-.10,.10),rng.randf_range(-.05,.05),rng.randf_range(-.10,.10))
		points.append(point)
	return points

func _add_bolt(points:Array[Vector3], width:float) -> void:
	var vertices:=PackedVector3Array()
	var uvs:=PackedVector2Array()
	var camera:=get_viewport().get_camera_3d()
	var eye:=to_local(camera.global_position)
	for i in points.size():
		var t:=float(i)/(points.size()-1)
		var tangent:=points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]
		var side:=tangent.cross(eye-points[i]).normalized()
		var radius:=width*(1.0-t*.55)*.5
		vertices.append(points[i]-side*radius)
		vertices.append(points[i]+side*radius)
		uvs.append(Vector2(0,t));uvs.append(Vector2(1,t))
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP,arrays)
	var bolt:=MeshInstance3D.new()
	bolt.mesh=mesh
	bolt.material_override=material
	bolt.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bolt)

func _process(delta:float) -> void:
	age+=delta
	# A fast leader, return stroke, then one shorter afterstroke with a soft decay.
	var envelope:=1.0-smoothstep(.11,.25,age)
	envelope=maxf(envelope,(1.0-smoothstep(.28,.46,age))*smoothstep(.22,.245,age)*.72)
	material.set_shader_parameter("reveal",minf(1.1,age/.035))
	material.set_shader_parameter("strength",envelope)
	light.light_energy=envelope*(0.0 if color==1 else 3.6)
	if age>=.50:
		cancel()

func cancel() -> void:
	if is_queued_for_deletion():return
	set_process(false)
	hide()
	light.light_energy=0.0
	queue_free()
	finished.emit()
