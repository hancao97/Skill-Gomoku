extends Node3D

var progress := 0.0
var rays: MeshInstance3D
var material: ShaderMaterial
var light: OmniLight3D

func _ready() -> void:
	name="GatheringLight"
	rays=MeshInstance3D.new()
	var quad:=QuadMesh.new()
	quad.size=Vector2.ONE*10.5
	rays.mesh=quad
	rays.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material=ShaderMaterial.new()
	material.shader=preload("res://shaders/charge_rays.gdshader")
	rays.material_override=material
	add_child(rays)
	light=OmniLight3D.new()
	light.light_color=Color("#dfe6ff")
	light.light_energy=0.0
	light.omni_range=4.0
	light.omni_attenuation=1.8
	light.shadow_enabled=false
	add_child(light)
	set_charge(0.0)

func set_charge(value:float) -> void:
	progress=clampf(value,0.0,1.0)
	material.set_shader_parameter("charge",progress)
	light.light_energy=progress*progress*7.0

func cancel() -> void:
	hide()
	light.light_energy=0.0
	queue_free()
