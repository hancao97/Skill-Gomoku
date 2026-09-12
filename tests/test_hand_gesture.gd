extends SceneTree

const Gesture=preload("res://scripts/hand_gesture.gd")
const Hand=preload("res://scripts/divine_hand.gd")
const Rules=preload("res://scripts/rules.gd")
var checks:=0
var failures:Array[String]=[]

func check(value:bool, detail:String) -> void:
	checks+=1
	if not value:failures.append(detail);push_error(detail)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var valid_outline:=true
	var connected_fingers:=true
	var finite_sites:=true
	var sites:=Gesture.sites()
	# Check all interpolated poses, including curled/extended transitions where
	# overlapping fingers could split the contour or produce invalid triangles.
	for frame in 145:
		var state:=Gesture.pose(float(frame)/60)
		var outline:=Gesture.outline(state)
		valid_outline=valid_outline and Geometry2D.triangulate_polygon(outline).size()>0
		for finger in 4:
			var tip:=Gesture.transform_point(Gesture.finger_point(finger,.92,state.curl),state)
			connected_fingers=connected_fingers and Geometry2D.is_point_in_polygon(tip,outline)
		for site in sites:
			var point:=Gesture.stone_site(site,state)
			finite_sites=finite_sites and point.is_finite() and point.y>=.65
	check(valid_outline,"Every interpolated outline triangulates")
	check(connected_fingers,"All four visible fingers stay joined to one palm through the complete gesture")
	check(finite_sites,"All pearls remain finite and above the board during the gesture")
	var extended:=Gesture.pose(.82)
	var curled:=Gesture.pose(0)
	var base:Vector2=Gesture.BASES[0]
	check(Gesture.finger_point(0,1,extended.curl).distance_to(base)>Gesture.finger_point(0,1,curled.curl).distance_to(base)*2,"Index unfolds independently of wrist travel")
	var hand:=Hand.new()
	root.add_child(hand)
	hand.set_process(false)
	var landed:Array[Vector2i]=[]
	var events:Array[String]=[]
	hand.cell_landed.connect(func(cell:Vector2i):landed.append(cell))
	hand.assembled.connect(func():events.append("assembled"))
	hand.pointing.connect(func():events.append("pointing"))
	hand.contacted.connect(func():events.append("contacted"))
	hand.finished.connect(func():events.append("finished"))
	for frame in 340:hand._process(1.0/60.0)
	check(events==["assembled","pointing","contacted","finished"],"Performance signals fire once and in order")
	var expected:=Rules.divine_hand_cells()
	check(landed.size()==expected.size() and expected.all(func(cell:Vector2i):return landed.count(cell)==1),"Each of the 65 footprint cells receives exactly one visible landing")
	check(hand.pieces.all(func(piece:Dictionary):return piece.landed),"Additional sculptural pearls dissolve at the end")
	check(hand.index_tip.distance_to(Hand.board_point(Rules.HAND_TIP))<.015,"Contact animation ends on the logical pointing intersection")
	check(not hand.contour.visible and not hand.membrane.visible,"Hand contour fully dissolves after contact")
	# Low frame rates may cross several phase boundaries at once; no awaits may hang.
	var skipped:=Hand.new()
	root.add_child(skipped)
	skipped.set_process(false)
	var skipped_events:Array[String]=[]
	skipped.assembled.connect(func():skipped_events.append("assembled"))
	skipped.pointing.connect(func():skipped_events.append("pointing"))
	skipped.contacted.connect(func():skipped_events.append("contacted"))
	skipped.finished.connect(func():skipped_events.append("finished"))
	skipped._process(6.0)
	check(skipped_events==events,"Crossing all phases in one frame still delivers every signal")
	print("HAND GESTURE: ",checks," checks; ",failures.size()," failures; ",sites.size()," pearls; 145 sampled poses")
	hand.free();skipped.free()
	quit(0 if failures.is_empty() else 1)
