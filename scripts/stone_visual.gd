extends Node3D

# Keep the logical anchor on the grid while centering the visible stone on it.
# Preview, placement and animated stones all use this same presentation.
var model:Node3D
var model_center:=Vector3.ZERO
var model_origin:=Vector3.ZERO
var previous_transform:=Transform3D.IDENTITY
var previous_camera:=Transform3D.IDENTITY
var aligned:=false

func _init(scene:PackedScene) -> void:
	model=scene.instantiate()
	add_child(model)
	model.owner=self

func _ready() -> void:
	model_origin=model.position
	var bounds:=AABB()
	var first:=true
	for mesh:MeshInstance3D in model.find_children("*","MeshInstance3D"):
		var box:AABB=global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
		bounds=box if first else bounds.merge(box)
		first=false
	model_center=bounds.get_center()
	align_visual()

func _process(_delta:float) -> void:
	align_visual()

func align_visual() -> void:
	if not is_visible_in_tree():return
	var camera:=get_viewport().get_camera_3d()
	if camera==null:return
	var camera_transform:=camera.get_camera_transform()
	if aligned and global_transform==previous_transform and camera_transform==previous_camera:return
	previous_transform=global_transform
	previous_camera=camera_transform
	aligned=true
	var ray:=global_position-camera_transform.origin
	if camera.projection==Camera3D.PROJECTION_ORTHOGONAL:ray=-camera_transform.basis.z
	ray=global_basis.inverse()*ray
	if absf(ray.y)<.0001:return
	# Slide only the visual child along its local board plane, preserving contact
	# height and the parent's grid position, scale, rotation and animation path.
	model.position=model_origin+ray*(model_center.y/ray.y)-model_center
