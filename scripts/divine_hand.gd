extends Node3D

signal assembled
signal pointing
signal contacted
signal cell_landed(cell:Vector2i)
signal finished

const Rules=preload("res://scripts/rules.gd")
const Gesture=preload("res://scripts/hand_gesture.gd")
const MODEL=preload("res://assets/models/white_stone.glb")
const CONTOUR=preload("res://shaders/hand_contour.gdshader")
const STEP:=.46
const FLOOR:=.669
const ASSEMBLY_TIME:=1.70
const POINT_TIME:=2.72
const CONTACT_TIME:=4.10
const END_TIME:=5.32
var source:=Vector3(-4.76,-.37,2.78)
var elapsed:=0.0
var phase:="gather"
var pieces:Array[Dictionary]=[]
var pearl:StandardMaterial3D
var radiance:OmniLight3D
var mosaic:MultiMeshInstance3D
var model_transform:=Transform3D.IDENTITY
var contour_mesh:=ImmediateMesh.new()
var membrane_mesh:=ImmediateMesh.new()
var contour_material:ShaderMaterial
var membrane_material:ShaderMaterial
var contour:MeshInstance3D
var membrane:MeshInstance3D
var current_outline:=PackedVector2Array()
var index_tip:=Vector3.ZERO
var did_assemble:=false
var did_point:=false
var did_contact:=false
var did_finish:=false

static func board_point(cell:Vector2i) -> Vector3:
	return Vector3((cell.x-7)*STEP,FLOOR,(cell.y-7)*STEP)

func _ready() -> void:
	name="DivineHandGesture"
	set_meta("stone_color",Rules.WHITE)
	pearl=StandardMaterial3D.new()
	pearl.albedo_color=Color(.94,.94,.94)
	pearl.metallic=.16
	pearl.roughness=.26
	pearl.emission_enabled=true
	pearl.emission=Color(.45,.45,.45)
	pearl.emission_energy_multiplier=.035
	pearl.vertex_color_use_as_albedo=true
	_make_mosaic()
	_make_contour()
	radiance=OmniLight3D.new()
	radiance.position=Vector3(0,4,0)
	radiance.light_color=Color(.98,.98,.98)
	radiance.light_energy=.25
	radiance.omni_range=7.0
	add_child(radiance)
	_update_pieces()

func _make_mosaic() -> void:
	var prototype:Node3D=MODEL.instantiate()
	add_child(prototype)
	var mesh:MeshInstance3D=prototype.find_children("*","MeshInstance3D")[0]
	model_transform=mesh.transform
	# Center the pearls on the gesture surface, independent of the GLB floor origin.
	model_transform.origin-=model_transform.basis*mesh.mesh.get_aabb().get_center()
	mosaic=MultiMeshInstance3D.new()
	mosaic.multimesh=MultiMesh.new()
	mosaic.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	mosaic.multimesh.use_colors=true
	mosaic.multimesh.mesh=mesh.mesh
	mosaic.material_override=pearl
	mosaic.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mosaic)
	prototype.queue_free()
	var sites:=Gesture.sites()
	var available:Array[Vector2i]=Rules.divine_hand_cells()
	var final_state:=Gesture.pose(2.40)
	# Nearby pearls become the footprint; the remainder dissolve without adding cells.
	var assignment:Dictionary={}
	for cell in available:
		var best:=-1
		var distance:=INF
		for i in sites.size():
			if assignment.has(i):continue
			var at:=Gesture.stone_site(sites[i],final_state)
			var d:=Vector2(at.x,at.z).distance_squared_to(Vector2(board_point(cell).x,board_point(cell).z))
			if d<distance:distance=d;best=i
		assignment[best]=cell
	for i in sites.size():
		var angle:=float(i)*2.39996
		var start:=source+Vector3(cos(angle)*.09,.14+float(i%5)*.025,sin(angle)*.09)
		pieces.append({"site":sites[i],"cell":assignment.get(i,Vector2i(-1,-1)),
			"start":start,"angle":angle,"delay":float(i%13)*.022,"landed":false,
			"position":start,"primary":assignment.has(i)})
	mosaic.multimesh.instance_count=pieces.size()
	for i in pieces.size():
		var shade:=.69 if pieces[i].site.layer>0 else lerpf(.91,1.0,float(i%5)/4)
		mosaic.multimesh.set_instance_color(i,Color(shade,shade,shade))
	mosaic.custom_aabb=AABB(Vector3(-7,-1,-6),Vector3(14,10,13))

func _make_contour() -> void:
	contour_material=ShaderMaterial.new()
	contour_material.shader=CONTOUR
	membrane_material=ShaderMaterial.new()
	membrane_material.shader=CONTOUR
	membrane_material.set_shader_parameter("membrane",true)
	contour=MeshInstance3D.new()
	contour.name="SilverHandOutline"
	contour.mesh=contour_mesh
	contour.material_override=contour_material
	contour.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(contour)
	membrane=MeshInstance3D.new()
	membrane.name="TranslucentPalm"
	membrane.mesh=membrane_mesh
	membrane.material_override=membrane_material
	membrane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(membrane)

func _process(delta:float) -> void:
	if did_finish:return
	elapsed+=delta
	_update_pieces()
	if elapsed>=ASSEMBLY_TIME and not did_assemble:
		did_assemble=true;phase="pose";assembled.emit()
	if elapsed>=POINT_TIME and not did_point:
		did_point=true;pointing.emit()
	if elapsed>=CONTACT_TIME and not did_contact:
		did_contact=true;phase="imprint";contacted.emit()
	pearl.emission_energy_multiplier=.035+.045*sin(clampf(elapsed/CONTACT_TIME,0,1)*PI)
	radiance.light_energy=.25+.35*exp(-pow((elapsed-CONTACT_TIME)/.15,2))
	if elapsed>=END_TIME:
		did_finish=true;phase="finished";finished.emit()

func _update_pieces() -> void:
	var state:=Gesture.pose(clampf(elapsed-ASSEMBLY_TIME,0,2.40))
	var index_2d:=Gesture.transform_point(Gesture.finger_point(0,1,state.curl),state)
	index_tip=Gesture.world(index_2d,state)
	for i in pieces.size():
		var piece:Dictionary=pieces[i]
		var target:=Gesture.stone_site(piece.site,state)
		var at:Vector3=target
		var scale_value:=.66 if piece.site.finger<0 else .63
		var rotation:=Vector3(-.12,0,0)
		if piece.site.finger>0:rotation.x+=.52*sin(piece.site.t*PI)
		if elapsed<ASSEMBLY_TIME:
			var t:=clampf((elapsed-.12-piece.delay)/1.22,0,1)
			var ease:=smoothstep(0,1,t)
			var bend:Vector3=piece.start.lerp(target,.50)+Vector3(cos(piece.angle)*.65,2.2+float(i%4)*.15,sin(piece.angle)*.60)
			at=piece.start.lerp(bend,ease).lerp(bend.lerp(target,ease),ease)
			rotation=Vector3(sin(piece.angle)*(1-ease)*2.3,piece.angle+(1-ease)*5,cos(piece.angle)*(1-ease)*1.7)
			scale_value*=smoothstep(0,.20,t)
		elif elapsed>=CONTACT_TIME:
			var cell:Vector2i=piece.cell
			var delay:float=Vector2(cell-Rules.HAND_TIP).length()*.027 if piece.primary else float(i%7)*.023
			var t:=clampf((elapsed-CONTACT_TIME-delay)/.57,0,1)
			if piece.primary:
				at=target.lerp(board_point(cell)+Vector3.UP*.07,t*t)
				scale_value=lerpf(scale_value,1.0,t)
			else:
				at=target+Vector3.UP*(.4*t)
				scale_value*=1.0-t
			if t>=1 and not piece.landed:
				piece.landed=true
				if piece.primary:cell_landed.emit(cell)
			if piece.landed:scale_value=0
		piece.position=at
		var transform:=Transform3D(Basis.from_euler(rotation).scaled(Vector3.ONE*maxf(.00001,scale_value)),at)
		mosaic.multimesh.set_instance_transform(i,transform*model_transform)
	_update_contour(state)

func _update_contour(state:Dictionary) -> void:
	var alpha:=smoothstep(.98,1.62,elapsed)*(1.0-smoothstep(CONTACT_TIME+.06,CONTACT_TIME+.50,elapsed))
	contour.visible=alpha>.001
	membrane.visible=contour.visible
	if not contour.visible:return
	contour_material.set_shader_parameter("opacity",alpha*.75)
	membrane_material.set_shader_parameter("opacity",alpha)
	current_outline=Gesture.outline(state)
	contour_mesh.clear_surfaces()
	membrane_mesh.clear_surfaces()
	var triangles:=Geometry2D.triangulate_polygon(current_outline)
	if triangles.is_empty():return
	membrane_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in triangles:
		membrane_mesh.surface_add_vertex(Gesture.world(current_outline[index],state)-Vector3.UP*.065)
	membrane_mesh.surface_end()
	contour_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in current_outline.size():
		var p:=Gesture.world(current_outline[i],state)
		var q:=Gesture.world(current_outline[(i+1)%current_outline.size()],state)
		_stroke(p,q,.019)
	# Cuff and short knuckle folds make the anatomy readable without a solid glove.
	for crease in [
		[Vector2(165,220),Vector2(170,222),Vector2(176,224)],
		[Vector2(144,243),Vector2(147,241),Vector2(151,242)],
		[Vector2(153,241),Vector2(156,239),Vector2(160,240)],
		[Vector2(162,239),Vector2(165,238),Vector2(168,239)]]:
		for i in crease.size()-1:
			var a:=Gesture.world(Gesture.transform_point(crease[i],state),state)+Vector3.UP*.08
			var b:=Gesture.world(Gesture.transform_point(crease[i+1],state),state)+Vector3.UP*.08
			_stroke(a,b,.013)
	contour_mesh.surface_end()

func _stroke(p:Vector3, q:Vector3, width:float) -> void:
	var side:=(q-p).cross(Vector3.UP).normalized()*width
	for vertex in [p-side,p+side,q+side,p-side,q+side,q-side]:
		contour_mesh.surface_add_vertex(vertex)
