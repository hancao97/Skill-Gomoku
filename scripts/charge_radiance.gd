extends Node3D

var progress := 0.0
var rays: MeshInstance3D
var material: ShaderMaterial
var light: OmniLight3D

func _ready() -> void:
	name="GatheringInk"
	set_meta("stone_color",1)
	rays=MeshInstance3D.new()
	var quad:=QuadMesh.new()
	quad.size=Vector2.ONE*8.2
	rays.mesh=quad
	rays.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material=ShaderMaterial.new()
	material.shader=preload("res://shaders/charge_rays.gdshader")
	rays.material_override=material
	add_child(rays)
	light=OmniLight3D.new()
	# A small neutral reflection defines obsidian, never a white flood.
	light.light_color=Color("#b9b9b9")
	light.light_energy=0.0
	light.omni_range=1.2
	light.omni_attenuation=1.8
	light.shadow_enabled=false
	add_child(light)
	set_charge(0.0)

func set_charge(value:float) -> void:
	progress=clampf(value,0.0,1.0)
	material.set_shader_parameter("charge",progress)
	light.light_energy=progress*progress*.32

func cancel() -> void:
	hide()
	light.light_energy=0.0
	queue_free()
