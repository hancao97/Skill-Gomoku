extends Node3D

signal assembled
signal contacted
signal cell_landed(cell:Vector2i)
signal finished

const Rules=preload("res://scripts/rules.gd")
const MODEL=preload("res://assets/models/white_stone.glb")
const STEP:=.46
const FLOOR:=.669
const ASSEMBLY_TIME:=1.70
const CONTACT_TIME:=3.08
const END_TIME:=4.25
var source:=Vector3(-4.76,-.37,2.78)
var elapsed:=0.0
var phase:="gather"
var pieces:Array[Dictionary]=[]
var pearl:StandardMaterial3D
var radiance:OmniLight3D
var did_assemble:=false
var did_contact:=false
var did_finish:=false

static func board_point(cell:Vector2i) -> Vector3:
	return Vector3((cell.x-7)*STEP,FLOOR,(cell.y-7)*STEP)

static func height_for(cell:Vector2i) -> float:
	if cell.y<=8:
		# A raised wrist and rounded palm give the mosaic an actual hand volume.
		return 1.65+float(8-cell.y)*.12+.18*sin(float(cell.x-5)*.44)
	if cell.x<=5:
		return lerpf(1.6,.82,float(cell.y-8)/5.0)
	# Three curled fingers sit higher than the extended index; gaps stay visible.
	return 1.60+.20*sin(float(cell.y-8)*1.2)

func _ready() -> void:
	name="DivineHandMosaic"
	set_meta("stone_color",Rules.WHITE)
	pearl=StandardMaterial3D.new()
	pearl.albedo_color=Color(.94,.94,.94)
	pearl.metallic=.12
	pearl.roughness=.23
	pearl.emission_enabled=true
	pearl.emission=Color(.45,.45,.45)
	pearl.emission_energy_multiplier=.035
	var cells:=Rules.divine_hand_cells()
	for i in cells.size():
		var cell:Vector2i=cells[i]
		_add_piece(cell,Vector3.ZERO,true,i)
		# A staggered underside on wrist and palm makes the hand sculptural.
		if cell.y>=2 and cell.y<=8 and cell.x>=7 and (cell.x+cell.y)%2==0:
			_add_piece(cell,Vector3(.13,-.20,.10),false,i+53)
	radiance=OmniLight3D.new()
	radiance.position=Vector3(0,3.7,0)
	radiance.light_color=Color(.97,.98,1.0)
	radiance.light_energy=.20
	radiance.omni_range=7.0
	add_child(radiance)
	_update_pieces()

func _add_piece(cell:Vector2i, offset:Vector3, primary:bool, index:int) -> void:
	var node:Node3D=MODEL.instantiate()
	add_child(node)
	for mesh:MeshInstance3D in node.find_children("*","MeshInstance3D"):
		mesh.material_override=pearl
	var target:=board_point(cell)+Vector3.UP*height_for(cell)+offset
	var seed_angle:=float(index)*2.39996
	var start:=source+Vector3(cos(seed_angle)*.09,.14+float(index%5)*.025,sin(seed_angle)*.09)
	var bend:=start.lerp(target,.50)+Vector3(cos(seed_angle)*.65,2.2+float(index%4)*.22,sin(seed_angle)*.72)
	pieces.append({"node":node,"cell":cell,"pose":target,"start":start,"bend":bend,
		"primary":primary,"delay":float(index%13)*.026,"angle":seed_angle,"landed":false})

func _process(delta:float) -> void:
	if did_finish:return
	elapsed+=delta
	if elapsed>=ASSEMBLY_TIME and not did_assemble:
		did_assemble=true
		phase="pose"
		assembled.emit()
	if elapsed>=CONTACT_TIME and not did_contact:
		did_contact=true
		phase="imprint"
		contacted.emit()
	_update_pieces()
	pearl.emission_energy_multiplier=.035+.045*sin(clampf(elapsed/CONTACT_TIME,0,1)*PI)
	radiance.light_energy=.20+.35*exp(-pow((elapsed-CONTACT_TIME)/.15,2))
	if elapsed>=END_TIME:
		did_finish=true
		phase="finished"
		finished.emit()

func _pressed_pose(piece:Dictionary) -> Vector3:
	var pose:Vector3=piece.pose
	var p:Vector2i=piece.cell
	var index_finger:=p.x<=5 and p.y>=9
	# Only the long index performs the pointing strike; the other fingers stay curled.
	if index_finger:pose.y-=.82*float(p.y-8)/5.0
	else:pose.y-=.16
	return pose

func _update_pieces() -> void:
	for piece in pieces:
		var node:Node3D=piece.node
		var cell:Vector2i=piece.cell
		var pose:Vector3=piece.pose
		var scale_value:=1.05 if piece.primary else .90
		if elapsed<ASSEMBLY_TIME:
			var t:=clampf((elapsed-.12-piece.delay)/1.22,0,1)
			var ease:=smoothstep(0,1,t)
			var a:Vector3=piece.start.lerp(piece.bend,ease)
			var b:Vector3=piece.bend.lerp(pose,ease)
			node.position=a.lerp(b,ease)
			node.rotation=Vector3(sin(piece.angle)*(1-ease)*2.3,piece.angle+(1-ease)*5.0,cos(piece.angle)*(1-ease)*1.7)
			node.scale=Vector3.ONE*scale_value*smoothstep(0,.20,t)
		elif elapsed<CONTACT_TIME:
			var lift:=sin(clampf((elapsed-2.28)/.45,0,1)*PI)*.30
			var press:=pow(clampf((elapsed-2.72)/.36,0,1),3)
			node.position=pose.lerp(_pressed_pose(piece),press)+Vector3.UP*lift
			node.rotation.x=.28 if cell.x<=5 and cell.y>=9 else -.12
			node.scale=Vector3.ONE*scale_value
		else:
			var delay:=Vector2(cell-Rules.HAND_TIP).length()*.027
			var t:=clampf((elapsed-CONTACT_TIME-delay)/.53,0,1)
			node.position=_pressed_pose(piece).lerp(board_point(cell),t*t)
			node.scale=Vector3.ONE*scale_value*(1.0 if piece.primary else 1-t)
			if t>=1 and not piece.landed:
				piece.landed=true
				node.hide()
				if piece.primary:cell_landed.emit(cell)
