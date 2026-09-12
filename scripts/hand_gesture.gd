extends RefCounted

# Hand-only study of reference frames 67, 70, 71, 72, 74, 78 and 80.
# Coordinates describe the 284 x 366 source, not an image used by the game.
# The final pointing pose is repeated with a deeper press for the game impact.
const KEYS := [
	[0.00, Vector2(190,210), .30, .95],
	[0.20, Vector2(189,201), .20, .72],
	[0.43, Vector2(171,208), .08, .30],
	[0.63, Vector2(167,220), -.08, .06],
	[0.82, Vector2(168,220), .00, .00],
	[1.15, Vector2(171,217), .02, .03],
	[1.43, Vector2(190,218), .29, .83],
	[1.75, Vector2(176,210), .08, .24],
	[2.12, Vector2(168,220), .00, .00],
	[2.40, Vector2(168,220), .00, .00],
]
const ROOT := Vector2(168,220)
const PALM := [Vector2(164,215), Vector2(170,215), Vector2(178,221),
	Vector2(176,233), Vector2(172,246), Vector2(165,251), Vector2(154,252),
	Vector2(142,249), Vector2(139,244), Vector2(142,237), Vector2(151,228)]
const BASES := [Vector2(141,246),Vector2(150,247),Vector2(159,246),Vector2(167,244)]
const TIPS := [Vector2(126,266),Vector2(148,263),Vector2(157,262),Vector2(165,260)]
const RADII := [2.7,3.0,2.8,2.5]

static func pose(seconds:float) -> Dictionary:
	var left:int=0
	while left<KEYS.size()-2 and seconds>KEYS[left+1][0]:left+=1
	var a:Array=KEYS[left]
	var b:Array=KEYS[left+1]
	var t:=smoothstep(0,1,clampf((seconds-a[0])/(b[0]-a[0]),0,1))
	return {"root":a[1].lerp(b[1],t),"angle":lerpf(a[2],b[2],t),
		"curl":lerpf(a[3],b[3],t),"press":pow(smoothstep(2.12,2.40,seconds),2)}

static func transform_point(p:Vector2, state:Dictionary) -> Vector2:
	return (p-ROOT).rotated(state.angle)+state.root

static func finger_point(finger:int, t:float, curl:float) -> Vector2:
	var base:Vector2=BASES[finger]
	var tip:Vector2=TIPS[finger]
	var bend:Vector2=base.lerp(tip,.53)+Vector2(-.9,.8)
	if finger==0:
		# The index unfolds independently; the other three remain softly bent.
		tip=tip.lerp(base+Vector2(2.8,7.5),curl)
		bend=bend.lerp(base+Vector2(-2.0,7.0),curl)
	else:
		tip+=Vector2(.6,-1.7)*curl
	var a:=base.lerp(bend,t)
	var b:=bend.lerp(tip,t)
	return a.lerp(b,t)

static func finger_outline(finger:int, curl:float) -> PackedVector2Array:
	var left:=PackedVector2Array()
	var right:=PackedVector2Array()
	for i in 13:
		var t:=float(i)/12.0
		var center:=finger_point(finger,t,curl)
		var direction:=(finger_point(finger,minf(1,t+.01),curl)-finger_point(finger,maxf(0,t-.01),curl)).normalized()
		var side:=Vector2(-direction.y,direction.x)
		var radius:float=RADII[finger]*lerpf(1.0,.64,t)
		left.append(center+side*radius)
		right.append(center-side*radius)
	var tip:=finger_point(finger,1,curl)
	var end_direction:=(tip-finger_point(finger,.98,curl)).normalized()
	var side:=Vector2(-end_direction.y,end_direction.x)
	for i in range(1,8):
		var angle:=float(i)*PI/8.0
		left.append(tip+(side*cos(angle)+end_direction*sin(angle))*RADII[finger]*.64)
	right.reverse()
	left.append_array(right)
	return left

static func outline(state:Dictionary) -> PackedVector2Array:
	var shape:=PackedVector2Array(PALM)
	for iteration in 2:
		var rounded:=PackedVector2Array()
		for i in shape.size():
			var a:=shape[i]
			var b:=shape[(i+1)%shape.size()]
			rounded.append(a.lerp(b,.20))
			rounded.append(a.lerp(b,.80))
		shape=rounded
	for finger in 4:
		var merged:=Geometry2D.merge_polygons(shape,finger_outline(finger,state.curl))
		if not merged.is_empty():shape=merged[0]
	for i in shape.size():shape[i]=transform_point(shape[i],state)
	return shape

static func world(p:Vector2, state:Dictionary) -> Vector3:
	var local:Vector2=(p-state.root).rotated(-state.angle)+ROOT
	var depth:=clampf((local.y-215.0)/51.0,0,1)
	var index_weight:=(1.0-smoothstep(129,144,local.x))*smoothstep(247,265,local.y)
	var height:=2.75-(local.y-215)*.022
	# A gently domed palm and raised knuckles give the hand depth.
	var palm_dome:=exp(-pow((local.x-158)/12.0,2)-pow((local.y-236)/13.0,2))*.20
	height+=palm_dome+state.curl*depth*.34
	for finger in range(1,4):
		var base:Vector2=BASES[finger]
		var tip:Vector2=TIPS[finger]
		if local.y>base.y and absf(local.x-base.x)<3.2:
			var bend_t:=clampf((local.y-base.y)/(tip.y-base.y),0,1)
			height+=.42*sin(bend_t*PI)
	height-=state.press*lerpf(.25,1.628,index_weight)
	return Vector3((p.x-149.0)*.1,.669+maxf(0,height),(p.y-238.4)*.1)

static func stone_site(site:Dictionary, state:Dictionary) -> Vector3:
	var local:Vector2=site.at
	if site.finger>=0:
		var finger:int=site.finger
		var t:float=site.t
		var center:=finger_point(finger,t,state.curl)
		var direction:=(finger_point(finger,minf(1,t+.02),state.curl)-finger_point(finger,maxf(0,t-.02),state.curl)).normalized()
		local=center+Vector2(-direction.y,direction.x)*site.offset
	return world(transform_point(local,state),state)-Vector3.UP*float(site.get("layer",0.0))

static func sites() -> Array[Dictionary]:
	var result:Array[Dictionary]=[]
	var palm:=PackedVector2Array(PALM)
	# Pack along the rounded palm rather than the board grid.
	for row in 11:
		for column in 13:
			var p:=Vector2(136+column*3.3+float(row%2)*1.65,216+row*3.05)
			if Geometry2D.is_point_in_polygon(p,palm):
				var edge:=INF
				for i in palm.size():
					edge=minf(edge,p.distance_to(Geometry2D.get_closest_point_to_segment(p,palm[i],palm[(i+1)%palm.size()])))
				if edge<1.25:continue
				result.append({"at":p,"finger":-1,"t":0.0,"offset":0.0,"layer":0.0})
				if row%2==0 and column%2==0:
					result.append({"at":p+Vector2(.7,.7),"finger":-1,"t":0.0,"offset":0.0,"layer":.20})
	for finger in 4:
		for row in 6:
			var t:=.15+float(row)*.165
			result.append({"at":finger_point(finger,t,0),"finger":finger,"t":t,"offset":.25 if row%2==0 else -.25,"layer":0.0})
	return result
